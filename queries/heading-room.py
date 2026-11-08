#!/usr/bin/env python3
"""From what room plain LaTeX keeps a heading with its first two lines.

    python3 queries/heading-room.py [DIR]

builds, in DIR (default: a temporary directory), one document per class and
heading, with the heading and a long paragraph after a rig that leaves a given
room, in steps of a hundredth of a line, and prints for each the least room, in
lines of the text, at which the heading stays on the page with two lines under
it.  Below that the heading moves to the next page in plain LaTeX too.  The
documents load didactic with the keep options off, and beamerarticle, as the
notes do, for their fonts and headings; the room is what the rig measures, as in test-keep-sweep.py.  These are
the figures of the paragraph on keepmaxgap in the documentation, and of the row of
keepmaxgap in its table of decisions.  About a minute.
"""
import os, re, subprocess, sys, tempfile

OFF = "keepafterheading=0,keepleadin=false,keepmaxgap=0,keeplines=0,keepends=1"
CONFIGS = [
    ("memoir 10pt, \\section", r"\documentclass[a4paper,10pt,oneside]{memoir}", r"\section*"),
    ("memoir 10pt, \\subsection", r"\documentclass[a4paper,10pt,oneside]{memoir}", r"\subsection*"),
    ("memoir 11pt, \\section", r"\documentclass[a4paper,11pt,oneside]{memoir}", r"\section*"),
    ("article 10pt, \\section", r"\documentclass[a4paper,10pt]{article}", r"\section*"),
]
ROOMS = [r / 100 for r in range(400, 651)]
RIG = r"""\makeatletter
\newcommand\roomfor[2]{%
  \clearpage\noindent\mbox{}R\label{R#1}\par
  \vspace*{\dimexpr\pagegoal-\pagetotal-#2\baselineskip-2\baselineskip\relax}\par
  \noindent A line above.\par
  \noindent And another.\par
  \typeout{ROOM #1 \the\dimexpr\pagegoal-\pagetotal-\pagedepth\relax\space\the\baselineskip}}
\makeatother
"""


def build(d, name, cls, head):
    body = [cls, r"\usepackage{amsmath,amssymb,amsthm}", r"\usepackage[" + OFF + "]{didactic}",
            r"\usepackage[noamsthm,notheorems]{beamerarticle}", RIG, r"\begin{document}"]
    for i, r in enumerate(ROOMS):
        body.append(rf"\roomfor{{{i}}}{{{r}}}")
        body.append(head + rf"{{Head}}\label{{H{i}}}")
        body.append("\\hspace*{\\fill}\\break\n".join(rf"L{j}\label{{L{j}x{i}}}" for j in range(1, 6)))
    body.append(r"\end{document}")
    tex = os.path.join(d, name + ".tex")
    open(tex, "w").write("\n".join(body) + "\n")
    for _ in range(3):
        subprocess.run(["pdflatex", "-interaction=nonstopmode", name + ".tex"], cwd=d,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    log = open(os.path.join(d, name + ".log"), errors="replace").read()
    if re.search(r"^! ", log, re.M):
        sys.exit(f"{name}: LaTeX stopped with an error, see {d}/{name}.log")
    aux = open(os.path.join(d, name + ".aux"), errors="replace").read()
    page = {m[1]: int(m[2]) for m in re.finditer(r"\\newlabel\{([^}]*)\}\{\{[^}]*\}\{(\d+)\}", aux)}
    room = {int(m[1]): float(m[2]) / float(m[3])
            for m in re.finditer(r"^ROOM (\d+) ([\d.]+)pt ([\d.]+)pt", log, re.M)}
    for i in range(len(ROOMS)):
        if page.get(f"H{i}") == page.get(f"R{i}") == page.get(f"L2x{i}"):
            return room[i]
    return None


def main():
    d = sys.argv[1] if len(sys.argv) > 1 else tempfile.mkdtemp()
    os.makedirs(os.path.join(d, "_minted"), exist_ok=True)
    for k, (label, cls, head) in enumerate(CONFIGS):
        r = build(d, f"room{k}", cls, head)
        print(f"{label}: the heading stays with two lines from a room of "
              + (f"{r:.2f} lines" if r is not None else "more than the rooms tried"))
        if k == 0 and r is not None:
            # keepmaxgap=4 lets a heading move only if that leaves at most 4 lines empty
            print(f"  so with keepmaxgap=4 it neither fits nor may move at a room over 4 lines "
                  f"and under {r:.2f}")


if __name__ == "__main__":
    main()
