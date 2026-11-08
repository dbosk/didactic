#!/usr/bin/env python3
"""How long one LaTeX pass takes with two versions of didactic.sty, and the .aux size.

For each document, and optionally a generated one with many sections: settle the .aux
with each version, then time passes, alternating between the versions, so that another
job's load falls on both.  CPU time is what to compare; wall-clock time shows the load.
Run nothing else of yours meanwhile.
"""
import os, re, resource, shutil, subprocess, time
from lib import args, latex, pages_of, run, workcopy

a, docs = args(__doc__,
               ("--sty", dict(action="append", required=True, help="NAME=PATH, twice")),
               ("--passes", dict(type=int, default=3)),
               ("--generated", dict(type=int, default=0, help="also a document with this many sections")))
stys = dict(x.split("=", 1) for x in a.sty)


class Gen:
    name, engine, out, main, weave, biber = "generated", "pdflatex", ".", "t", "", False


def prepare(d, name):
    top = os.path.join(a.work, "timing", name, d.name)
    if os.path.exists(top):
        shutil.rmtree(top)
    os.makedirs(top)
    if d is Gen:
        body = "\n".join(rf"\section{{Heading {i}}}" + "\nSome text of a line or two to follow it.\n"
                         for i in range(a.generated))
        open(os.path.join(top, "t.tex"), "w").write(
            "\\documentclass[a4paper,10pt,article,oneside]{memoir}\n\\usepackage{didactic}\n"
            "\\begin{document}\n" + body + "\\end{document}\n")
        os.makedirs(os.path.join(top, "_minted"), exist_ok=True)
        cwd = top
    else:
        cwd = workcopy(a.work, d, top)
        aux = os.path.join(cwd, d.out, d.main + ".aux")
        if os.path.exists(aux):  # written by another version
            os.remove(aux)
    s = os.path.join(cwd, "didactic.sty")
    if os.path.exists(s):
        os.remove(s)
    shutil.copy(stys[name], s)
    for _ in range(4):
        latex(d, cwd)
    return cwd, top


def timed(d, cwd):
    load = open("/proc/loadavg").read().split()[0]
    before, t = resource.getrusage(resource.RUSAGE_CHILDREN), time.time()
    latex(d, cwd)
    after, wall = resource.getrusage(resource.RUSAGE_CHILDREN), time.time() - t
    return wall, after.ru_utime + after.ru_stime - before.ru_utime - before.ru_stime, float(load)


print("| document | version | pages | .aux bytes | errors | CPU s, each pass | wall s, each pass | load |")
print("|---|---|---|---|---|---|---|---|")
for d in docs + ([Gen] if a.generated else []):
    cwds = {n: prepare(d, n) for n in stys}
    res = {n: [] for n in stys}
    for _ in range(a.passes):
        for n in stys:
            res[n].append(timed(d, cwds[n][0]))
    for n in stys:
        base = os.path.join(cwds[n][0], d.out, d.main)
        log = open(base + ".log", errors="replace").read()
        print(f"| {d.name} | {n} | {pages_of(base + '.pdf')} | {os.path.getsize(base + '.aux')} | "
              f"{len(re.findall(r'^!', log, re.M))} | {' '.join(f'{r[1]:.1f}' for r in res[n])} | "
              f"{' '.join(f'{r[0]:.1f}' for r in res[n])} | {' '.join(f'{r[2]:.0f}' for r in res[n])} |", flush=True)
        shutil.rmtree(cwds[n][1])
