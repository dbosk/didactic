#!/usr/bin/env python3
"""The rig leaves its prepared copy alone, also for a document built in its own directory.

A document whose last build left its files beside its sources (output = ".", the
default) goes through prepare.py, audit.py and build.py, with settings built two at a
time.  Every setting must give a result, and no file of the prepared copy may change:
build.py copies it by hard links, and LaTeX writing its .aux, .log and .pdf through
them wrote into the copy and into every other setting's build at once.

Also: a file over 40 MB isn't copied, and audit.py notes it; and prepare.py refuses a
root inside its own --work/src, which it would delete before reading.
"""
import argparse, hashlib, json, os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument("--sty", required=True, help="the didactic.sty to use")
sty = os.path.abspath(ap.parse_args().sty)
SETTINGS = ["current", "noprobe", "keep-off", "keepleadin-off"]
WORDS = " ".join(["some words to fill the line with text"] * 9)
DOC = (r"\documentclass[a4paper,10pt,article,oneside]{memoir}" "\n\\usepackage{didactic}\n\\begin{document}\n"
       + "\n\n".join(r"\section{Part %d}" % i + "\n" + "\n\n".join([WORDS] * 6) for i in range(12))
       + "\n\\end{document}\n")


def files(top):
    """Each file below top, with its content's digest and its number of links."""
    out = {}
    for base, _, names in os.walk(top):
        for f in names:
            p = os.path.join(base, f)
            if not os.path.islink(p):
                out[os.path.relpath(p, top)] = (hashlib.md5(open(p, "rb").read()).hexdigest(), os.stat(p).st_nlink)
    return out


def script(name, *args):
    return subprocess.run([sys.executable, os.path.join(HERE, name), "--conf", conf, "--work", work] + list(args),
                          cwd=HERE, capture_output=True, text=True, errors="replace", stdin=subprocess.DEVNULL)


d = tempfile.mkdtemp()
fail = []
try:
    root, work, conf = os.path.join(d, "root"), os.path.join(d, "work"), os.path.join(d, "rig.conf")
    doc = os.path.join(root, "doc")
    os.makedirs(os.path.join(doc, "_minted"))
    shutil.copy(sty, os.path.join(doc, "didactic.sty"))
    open(os.path.join(doc, "t.tex"), "w").write(DOC)
    with open(os.path.join(doc, "video.mp4v"), "wb") as f:  # sparse, but 41 MB to rsync
        f.truncate(41 * 2**20)
    subprocess.run(["pdflatex", "-interaction=nonstopmode", "t.tex"], cwd=doc, capture_output=True,
                   stdin=subprocess.DEVNULL, timeout=300)
    open(conf, "w").write(f"[rig]\nroot = {root}\n\n[small]\nkind = test\ndir = doc\nmain = t\noutput = .\n")
    r = script("prepare.py")
    if r.returncode:
        raise SystemExit("FAIL: prepare.py: " + r.stdout[-500:] + r.stderr[-500:])
    src = os.path.join(work, "src", "small")
    before = files(src)
    r = script("audit.py", "--sty", sty)
    if r.returncode or not r.stdout.rstrip().endswith("\n0 FAIL"):
        fail.append("audit.py: " + r.stdout[-500:] + r.stderr[-300:])
    if os.path.exists(os.path.join(src, "doc", "video.mp4v")) or "NOTE: 1 files over 40 MB" not in r.stdout:
        fail.append("a file over 40 MB was copied, or audit.py doesn't note it: " + r.stdout[-300:])
    r = script("build.py", "--sty", sty, "--tag", "t", "--jobs", "2", *sum((["--setting", s] for s in SETTINGS), []))
    after = files(src)
    changed = sorted(f for f in before if after.get(f, (None,))[0] != before[f][0])
    linked = sorted(f for f, (_, n) in after.items() if n != 1)
    if changed:
        fail.append(f"the build changed the prepared copy: {changed}")
    if linked:
        fail.append(f"files of the prepared copy still linked after the builds: {linked}")
    results = {s: json.load(open(os.path.join(work, "t", s, "small.json"))) for s in SETTINGS
               if os.path.exists(os.path.join(work, "t", s, "small.json"))}
    bad = [s for s in SETTINGS if not results.get(s, {}).get("ok")]
    if bad or r.returncode:
        fail.append(f"no result for {bad}: " + r.stdout[-600:])
    pages = {s: results[s]["pages"] for s in results}
    if len(set(pages.values())) != 1:
        fail.append(f"page counts differ between settings: {pages}")
    # A snapshot used as root with the same --work: refused, and left as it was.
    open(conf, "w").write(f"[rig]\nroot = {src}\n\n[small]\nkind = test\ndir = doc\nmain = t\noutput = .\n")
    r = script("prepare.py")
    if r.returncode == 0 or not os.path.exists(os.path.join(src, "doc", "t.tex")):
        fail.append("prepare.py took a root inside its own --work/src: " + r.stdout[-300:] + r.stderr[-300:])
    if fail:
        print("FAIL: " + "\nFAIL: ".join(fail))
    else:
        print(f"ok: {len(SETTINGS)} settings two at a time, {pages[SETTINGS[0]]} pages each, "
              f"and the {len(before)} files of the prepared copy unchanged and unlinked")
finally:
    shutil.rmtree(d)
raise SystemExit(1 if fail else 0)
