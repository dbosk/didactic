#!/usr/bin/env python3
"""A page output inside a small font gets the same unit of a line as the others."""
import argparse, os, re, shutil, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import SETTINGS
from probe import style

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument("--sty", required=True, help="the didactic.sty to use")
sty = os.path.abspath(ap.parse_args().sty)
WORDS = " ".join(["some words to fill the line with text"] * 9)
DOC = r"""\documentclass[a4paper,10pt,article,oneside]{memoir}
\usepackage{didactic}
\makeatletter
\AtBeginDocument{\output\expandafter{\expandafter\report\the\output}}
\newcommand\report{\ifnum\outputpenalty>-10001 \typeout{SIZE \the\normalbaselineskip}\fi}
\makeatother
\begin{document}
\typeout{TEXT \the\baselineskip}
%s
\end{document}
""" % "\n\n".join([WORDS] * 14 + [r"{\scriptsize " + "\n\n".join([WORDS] * 90) + r"\par}"] + [WORDS] * 8)
d = tempfile.mkdtemp()
try:
    os.makedirs(os.path.join(d, "_minted"))
    open(os.path.join(d, "didactic.sty"), "w", errors="replace").write(style(sty, SETTINGS["current"]))
    open(os.path.join(d, "t.tex"), "w").write(DOC)
    subprocess.run(["pdflatex", "-shell-escape", "-interaction=nonstopmode", "t.tex"], cwd=d,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL, timeout=300)
    log = open(os.path.join(d, "t.log"), errors="replace").read()
    text = re.search(r"^TEXT ([\d.]+)pt", log, re.M)[1]
    sizes = set(re.findall(r"^SIZE ([\d.]+)pt", log, re.M))
    units = {l.split()[5] for l in open(os.path.join(d, "t.lp"), errors="replace") if l.startswith("G ")}
    if len(sizes) < 2:
        raise SystemExit(f"FAIL: the test reached no page output in a small font: {sizes}")
    if units != {text + "pt"}:
        raise SystemExit(f"FAIL: units {sorted(units)} on pages, where the text's line is {text}pt")
    print(f"ok: pages output at sizes {sorted(sizes)} all have the unit {text}pt")
finally:
    shutil.rmtree(d)
