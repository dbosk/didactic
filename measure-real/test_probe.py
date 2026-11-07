#!/usr/bin/env python3
"""Checks of the probe, which must measure the pages without changing them.

1. A page output inside a small font gets the same unit of a line as the others.
2. The probe moves no line: a document with paragraphs of nothing but two spaces,
   which TeX sets as an empty line, has the same words on each page with and without it.
"""
import argparse, os, re, shutil, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import SETTINGS
from probe import style

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument("--sty", required=True, help="the didactic.sty to use")
sty = os.path.abspath(ap.parse_args().sty)
WORDS = " ".join(["some words to fill the line with text"] * 9)
HEAD = r"""\documentclass[a4paper,10pt,article,oneside]{memoir}
\usepackage{didactic}
\makeatletter
\AtBeginDocument{\output\expandafter{\expandafter\report\the\output}}
\newcommand\report{\ifnum\outputpenalty>-10001 \typeout{SIZE \the\normalbaselineskip}\fi}
\makeatother
\begin{document}
\typeout{TEXT \the\baselineskip}
"""
UNIT = HEAD + "\n\n".join([WORDS] * 14 + [r"{\scriptsize " + "\n\n".join([WORDS] * 90) + r"\par}"]
                          + [WORDS] * 8) + "\n\\end{document}\n"
# A paragraph of nothing but two spaces, as noweb leaves for an empty chunk of text
# (\nwbegindocs's \noindent, then the ends of lines), is an empty line.  A probe that
# took the last space away with \unskip made TeX drop the paragraph instead, so the
# lines after it moved up.  Each paragraph has a number, so a moved line shows as
# other words on a page.
SPACE = HEAD + "\n\n".join(r"Paragraph %d. %s" % (i, WORDS) + ("\n\n\\noindent\\ \\ \\par" if i % 3 == 0 else "")
                           for i in range(150)) + "\n\\end{document}\n"


def run(doc, setting):
    d = tempfile.mkdtemp()
    try:
        os.makedirs(os.path.join(d, "_minted"))
        open(os.path.join(d, "didactic.sty"), "w", errors="replace").write(style(sty, SETTINGS[setting]))
        open(os.path.join(d, "t.tex"), "w").write(doc)
        subprocess.run(["pdflatex", "-shell-escape", "-interaction=nonstopmode", "t.tex"], cwd=d,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL, timeout=300)
        log = open(os.path.join(d, "t.log"), errors="replace").read()
        lp = os.path.join(d, "t.lp")
        lp = open(lp, errors="replace").read() if os.path.exists(lp) else ""
        txt = subprocess.run(["pdftotext", os.path.join(d, "t.pdf"), "-"], capture_output=True, text=True).stdout
        return log, lp, [sorted(p.split()) for p in txt.split("\f")]
    finally:
        shutil.rmtree(d)


fail = False
log, lp, _ = run(UNIT, "current")
text = re.search(r"^TEXT ([\d.]+)pt", log, re.M)[1]
sizes = set(re.findall(r"^SIZE ([\d.]+)pt", log, re.M))
units = {l.split()[5] for l in lp.splitlines() if l.startswith("G ")}
if len(sizes) < 2:
    print(f"FAIL: the test reached no page output in a small font: {sizes}"); fail = True
elif units != {text + "pt"}:
    print(f"FAIL: units {sorted(units)} on pages, where the text's line is {text}pt"); fail = True
else:
    print(f"ok: pages output at sizes {sorted(sizes)} all have the unit {text}pt")

_, _, plain = run(SPACE, "noprobe")
_, lp, probed = run(SPACE, "current")
moved = [i + 1 for i, (p, q) in enumerate(zip(plain, probed)) if p != q] + \
        ([f"{len(plain)} pages against {len(probed)}"] if len(plain) != len(probed) else [])
paras = sum(l.startswith("P ") for l in lp.splitlines())
if len(plain) < 3 or paras < 150:
    print(f"FAIL: the test is too short to show it ({len(plain)} pages, {paras} paragraphs logged)"); fail = True
elif moved:
    print(f"FAIL: the probe moves lines: pages {moved} differ in words from the build without it"); fail = True
else:
    print(f"ok: {len(plain)} pages with the same words with and without the probe, {paras} paragraphs logged")
raise SystemExit(1 if fail else 0)
