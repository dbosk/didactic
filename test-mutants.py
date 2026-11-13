#!/usr/bin/env python3
"""Check that the tests catch deliberate breaks of didactic.dtx (see test-mutants.txt).

    test-mutants.py [--jobs N] [--timeout SECONDS] [--dir DIR] [--list] [LABEL ...]

Each mutant is applied to a copy of the tracked files, in a directory of its own that
is removed afterwards, so the working tree isn't touched and only the results stay.
First the tests of each group in use run on the code as it is, and they must pass, or
every mutant would look killed.  A build that fails for another reason, such as a full
disk, is an ERROR and not a kill.

Exit status: 0 every mutant did what test-mutants.txt says it does, 1 otherwise.
"""
import argparse
import concurrent.futures
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
BATCH = os.path.join(HERE, "test-mutants.txt")
FLAGS = "LATEXFLAGS=-shell-escape -interaction=nonstopmode"
RULES = ["test-keep-heading", "test-keep-nogap", "test-keep-style", "test-keep-columns",
         "test-keep-guard", "test-keep-pagereset", "test-keep-nofiles", "test-keep-box",
         "test-keep-addvspace", "test-keep-club", "test-keep-club-article",
         "test-keep-breakcode-late", "test-keep-filbreak", "test-keep-flush", "test-keep",
         "test-keep-once", "test-keep-enumitem", "test-keep-include", "test-keep-nofiles0"]
KEEP = ["test-keep", "test-keep-tall", "test-keep-tall100", "test-keep-chain", "test-keep-huge",
        "test-keep-blank", "test-keep-leadin", "test-keep-leadin-off", "test-keep-overfull",
        "test-keep-multicol", "test-keep-twocol", "test-keep-once", "test-keep-first",
        "test-keep-noweb", "test-keep-noweb-break"]
# group: documents to build, test-check.py names, sweep variants
GROUPS = {
    "include": (["test-marginfloat-samepar", "test-marginfloat-include"],
                ["test-marginfloat-samepar", "test-marginfloat-include",
                 "test-marginfloat-include-all"], []),
    "title": (["test-frametitle-floats", "test-frametitle-boxes"],
              ["test-frametitle-floats", "test-frametitle-boxes"], []),
    "format": (["test-format"], [], []),
    "keep": (KEEP, ["test-keep-leadin", "test-keep-leadin-off", "test-keep-overfull",
                    "test-keep-multicol", "test-keep-twocol", "test-keep-once", "test-keep-first",
                    "test-keep-noweb", "test-keep-noweb-break"], []),
    "noweb": (["test-keep-noweb", "test-keep-noweb-break"],
              ["test-keep-noweb", "test-keep-noweb-break"], []),
    "parted": (["test-keep-parted"], ["test-keep-parted"], []),
    "rules": (RULES, ["test-keep-once", "test-keep-enumitem"], ["m", "s", "k", "m3", "c", "k3", "a"]),
    "biburl": (["test-biburl"], [], []),
    "footcite": (["test-noteoverflow-foot"], [], []),
    "noteplace": (["test-noteplace"], [], []),
}
# targets that are no PDF of their own; they choose their engines themselves
PHONY = {"test-biburl", "test-noteoverflow-foot", "test-noteplace"}
# the job of a phony target that the group runs ($CASES of its script)
CASES = {"footcite": "default", "noteplace": "rsvsidecap rsvblock mcolblock rsvsidebefore heldtop heldsecond"}
# All with pdflatex, for speed, but the frame titles with the Makefile's xelatex:
# test-frametitle-boxes reads a letter inside a picture, whose box in pdftotext's output
# depends on the engine.
BROKEN = re.compile(r"No space left|Disk quota|I can't write on file")


def parse(path):
    """The mutants: label, group, what's expected, old, new."""
    mutants = []
    group = expected = None
    block = []
    for line in [*open(path, encoding="utf-8").read().splitlines(), ""]:
        if line.startswith("#:"):
            group = line[2:].strip()
        elif line.startswith("#="):
            expected = line[2:].split()
        elif line.startswith("#"):
            continue
        elif line.strip():
            block.append(line)
        elif block:
            label, _ = block[0].split()
            old = "\n".join(b[2:] for b in block[1:] if b[0] == "-")
            new = "\n".join(b[2:] for b in block[1:] if b[0] == "+")
            mutants.append(dict(label=label, group=group, expected=expected, old=old, new=new))
            block = []
            expected = None
    return mutants


def tracked():
    try:
        out = subprocess.run(["git", "ls-files"], cwd=HERE, capture_output=True, text=True,
                             check=True)
    except (OSError, subprocess.CalledProcessError):
        sys.exit("test-mutants.py copies the files that git tracks, so it needs a git tree")
    return [f for f in out.stdout.splitlines() if os.path.isfile(os.path.join(HERE, f))]


def sh(cmd, cwd, timeout):
    """Status and output of a command; None as status if it didn't end in time."""
    try:
        r = subprocess.run(cmd, cwd=cwd, shell=True, capture_output=True, stdin=subprocess.DEVNULL,
                           timeout=timeout, errors="replace", text=True)
        return r.returncode, r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        return None, ""


def fresh(top, name, files):
    d = os.path.join(top, name)
    os.makedirs(os.path.join(d, "_minted"))
    for f in files:
        os.makedirs(os.path.dirname(os.path.join(d, f)) or d, exist_ok=True)
        shutil.copy(os.path.join(HERE, f), os.path.join(d, f))
    return d


def sweep(variant, d, timeout):
    """A variant of the sweep; (status, output) of its check."""
    gen = (f"python3 test-keep-sweep.py gen {variant} > test-keep-sweep-{variant}.tex; "
           f"for i in 1 2; do pdflatex -shell-escape -interaction=nonstopmode "
           f"test-keep-sweep-{variant} >/dev/null 2>&1; done")
    status, out = sh(gen, d, timeout)
    if status is None:
        return None, ""
    status, out = sh(f"python3 test-keep-sweep.py check {variant}", d, timeout)
    over, _ = sh(f"! grep 'Overfull .vbox' test-keep-sweep-{variant}.log", d, timeout)
    if status == 0 and over != 0:
        return 1, "Overfull 1 failed"
    return status, out


def disk_trouble(d):
    """A full disk truncates files, which looks like any failure, so look for it."""
    try:
        with open(os.path.join(d, "disk-probe"), "wb") as f:
            f.write(bytes(1 << 20))
    except OSError:
        return True
    for name in os.listdir(d):
        if name.endswith(".log"):
            with open(os.path.join(d, name), errors="replace") as f:
                if BROKEN.search(f.read()):
                    return True
    return False


def tests(group, d, timeout):
    """What failed: a list of names, with ERROR in them if the build itself broke."""
    docs, checks, variants = GROUPS[group]
    failed = []
    status, out = sh("latex -interaction=batchmode didactic.ins", d, timeout)
    if status != 0:
        return ["ERROR: didactic.ins"]
    for t in docs:
        engine = "" if group == "title" or t in PHONY else "PDFLATEX=pdflatex"
        target = t if t in PHONY else f"{t}.pdf"
        cases = f"CASES='{CASES[group]}' " if group in CASES else ""
        status, out = sh(f'{cases}make -o didactic.sty {target} "{FLAGS}" {engine}', d, timeout)
        if BROKEN.search(out):
            return ["ERROR: disk"]
        if status != 0:
            failed.append(t if status is not None else f"{t}(hangs)")
    for t in checks:
        status, out = sh(f"python3 test-check.py {t}", d, timeout)
        if status != 0:
            failed.append(f"check-{t}")
    for v in variants:
        status, out = sweep(v, d, timeout)
        if status != 0:
            n = re.search(r"(\d+) failed", out)
            failed.append(f"sweep-{v}:{n[1] if n else '?'}")
    return ["ERROR: disk"] if disk_trouble(d) else failed


def references(top, files, variants, timeout):
    """Plain LaTeX's version of the sweep, which each check compares with."""
    d = fresh(top, "references", files)
    names = {v[0] + "p" for v in variants}
    names |= {v[0] + "q" for v in variants if v[0] in "ams"}
    for v in sorted(names):
        status, out = sh(f"python3 test-keep-sweep.py gen {v} > test-keep-sweep-{v}.tex; "
                         f"for i in 1 2; do pdflatex -shell-escape -interaction=nonstopmode "
                         f"test-keep-sweep-{v} >/dev/null 2>&1; done", d, timeout)
    return d


def run(m, top, files, refs, timeout):
    d = fresh(top, m["label"], files)
    begin = time.time()
    try:
        path = os.path.join(d, "didactic.dtx")
        text = open(path, encoding="utf-8").read()
        with open(path, "w", encoding="utf-8") as f:
            f.write(text.replace(m["old"], m["new"]))
        if GROUPS[m["group"]][2]:
            for name in os.listdir(refs):
                if re.match(r"test-keep-sweep-.[pq]\.(aux|log|tex)$", name):
                    shutil.copy(os.path.join(refs, name), d)
        return m, tests(m["group"], d, timeout), time.time() - begin
    finally:
        shutil.rmtree(d, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--jobs", type=int, default=2)
    ap.add_argument("--timeout", type=int, default=1800, help="for one command")
    ap.add_argument("--dir", default=None, help="where the copies go (default: $TMPDIR)")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("labels", nargs="*")
    a = ap.parse_args()
    mutants = parse(BATCH)
    source = open(os.path.join(HERE, "didactic.dtx"), encoding="utf-8").read()
    bad = [m["label"] for m in mutants if source.count(m["old"]) != 1]
    if bad:
        sys.exit(f"Not exactly once in didactic.dtx: {' '.join(bad)}")
    if a.labels:
        unknown = set(a.labels) - {m["label"] for m in mutants}
        if unknown:
            sys.exit(f"Unknown: {' '.join(sorted(unknown))}")
        mutants = [m for m in mutants if m["label"] in a.labels]
    if a.list:
        for m in mutants:
            print(m["label"], m["group"], m["expected"])
        return 0
    files = tracked()
    top = tempfile.mkdtemp(prefix="didactic-mutants-", dir=a.dir)
    ok = True
    try:
        groups = sorted({m["group"] for m in mutants})
        variants = sorted({v for g in groups for v in GROUPS[g][2]})
        refs = references(top, files, variants, a.timeout) if variants else None
        for g in groups:
            d = fresh(top, f"baseline-{g}", files)
            begin = time.time()
            if GROUPS[g][2]:
                for name in os.listdir(refs):
                    if re.match(r"test-keep-sweep-.[pq]\.(aux|log|tex)$", name):
                        shutil.copy(os.path.join(refs, name), d)
            failed = tests(g, d, a.timeout)
            print(f"baseline {g}: {'green' if not failed else 'RED ' + ' '.join(failed)}"
                  f" ({time.time() - begin:.0f} s)", flush=True)
            shutil.rmtree(d, ignore_errors=True)
            if failed:
                return 1
        with concurrent.futures.ThreadPoolExecutor(a.jobs) as ex:
            jobs = [ex.submit(run, m, top, files, refs, a.timeout) for m in mutants]
            for job in concurrent.futures.as_completed(jobs):
                m, failed, took = job.result()
                if any(f.startswith("ERROR") for f in failed):
                    verdict, match = " ".join(failed), False
                elif failed:
                    verdict = "killed by " + " ".join(failed)
                    # by which tests: how many cases of a sweep fail may vary
                    names = {f.split(":")[0] for f in failed}
                    want = {f.split(":")[0] for f in m["expected"][1:]}
                    match = m["expected"][0] == "killed" and (not want or names == want)
                else:
                    verdict, match = "survived", m["expected"][0] == "survived"
                ok = ok and match
                note = "" if match else " -- EXPECTED " + " ".join(m["expected"] or ["?"])
                print(f"{m['label']} ({m['group']}, {took:.0f} s): {verdict}{note}", flush=True)
    finally:
        shutil.rmtree(top, ignore_errors=True)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
