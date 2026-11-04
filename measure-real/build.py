#!/usr/bin/env python3
"""Build documents under settings, save the numbers, then delete the build.

The numbers are saved first, and a build that isn't a result (a LaTeX error, a
quota or full disk, a log cut short, an .aux that doesn't settle) is marked as
such, with its log.  Never run two of these on one work directory and tag.
"""
import concurrent.futures as cf, hashlib, json, os, re, shutil, subprocess
from lib import BAD, PAPER, SETTINGS, args, latex, pages_of, run
from probe import style

a, docs = args(__doc__,
               ("--sty", dict(required=True, help="the didactic.sty to measure")),
               ("--setting", dict(action="append", help="a setting; default all of them")),
               ("--jobs", dict(type=int, default=4)))
wanted = a.setting or ["noprobe", "pair-1000-1001"] + PAPER
for s in wanted:
    if s not in SETTINGS:
        raise SystemExit("no such setting: " + s)


def digest(path):
    return hashlib.md5(open(path, "rb").read()).hexdigest() if os.path.exists(path) else None


def build(d, name):
    res = os.path.join(a.work, a.tag, name)
    top = os.path.join(a.work, "build", a.tag, name, d.name)
    if os.path.exists(top):
        shutil.rmtree(top)
    os.makedirs(top)
    # Hard links save space: one source copy per document.  What LaTeX writes
    # is in the output directory, which is a real copy, or a new file.
    subprocess.run(["cp", "-al", os.path.join(a.work, "src", d.name) + "/.", top + "/"], check=True)
    cwd = os.path.join(top, d.dir)
    out = os.path.join(cwd, d.out)
    if d.out != ".":
        shutil.rmtree(out)
        shutil.copytree(os.path.join(d.src(a.work), d.out), out, symlinks=True)
    sty = os.path.join(cwd, "didactic.sty")
    if os.path.exists(sty):
        os.remove(sty)
    open(sty, "w", errors="replace").write(style(a.sty, SETTINGS[name]))
    aux = os.path.join(out, d.main + ".aux")
    settled, rc, passes = False, None, 0
    for passes in range(1, 7):
        before = digest(aux)
        rc = latex(d, cwd).returncode
        if digest(aux) == before and passes > 1:
            settled = True
            break
    base = os.path.join(out, d.main)
    log = open(base + ".log", errors="replace").read() if os.path.exists(base + ".log") else ""
    loaded = "(./didactic.sty" in log.replace("\n", "")
    # A log that doesn't end with the output line is a run cut short, which
    # counts fewer pages or none: not a short count, no result.
    whole = bool(re.search(r"Output written on", log.replace("\n", "")))
    status = dict(document=d.name, setting=name, engine=d.engine, passes=passes, rc=rc, settled=settled,
                  errors=len(re.findall(r"^!", log, re.M)), bad=bool(BAD.search(log)), loaded=loaded,
                  whole=whole, pages=pages_of(base + ".pdf"))
    status["ok"] = (settled and rc == 0 and not status["errors"] and not status["bad"]
                    and loaded and whole and status["pages"] is not None)
    # The numbers, before anything is deleted.
    shutil.copy(base + ".log", d.result(res, "", ".log"))
    if os.path.exists(base + ".lp"):
        shutil.copy(base + ".lp", d.result(res, "", ".lp"))
    txt = run(["pdftotext", base + ".pdf", "-"]).stdout
    open(d.result(res, "", ".txt"), "w", errors="replace").write(txt)
    json.dump(status, open(d.result(res, "", ".json"), "w"))
    if status["ok"]:
        shutil.rmtree(top)
    return status


with cf.ThreadPoolExecutor(a.jobs) as ex:
    jobs = [ex.submit(build, d, s) for s in wanted for d in docs]
    bad = 0
    for j in cf.as_completed(jobs):
        r = j.result()
        bad += not r["ok"]
        print(f"{r['setting']:18} {r['document']:18} pages={r['pages']} passes={r['passes']}"
              + ("" if r["ok"] else f"  NOT A RESULT: rc={r['rc']} errors={r['errors']} "
                 f"settled={r['settled']} disk={r['bad']} loaded={r['loaded']} whole={r['whole']}"), flush=True)
raise SystemExit(1 if bad else 0)
