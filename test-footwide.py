#!/usr/bin/env python3
"""Check a build of test-footwide.tex by its outcome, from the PDF and the log.

Usage: test-footwide.py JOB CASE

The text block's left edge is that of the first word on page 1 ("x"), its
right edge the rightmost end of a line of the text (a word taller than a
footnote's) on page 1.  Always: no error in the log; the footnotes found not
plain (didactic's information, "isn't plain: it has ...") are as the case
declares, below, with their reason; NOTEA is at the foot of CALLA's page (in
the text column, below the text), and the note's lines there reach at least
three quarters of the text's width (the width of the text, not the margin's);
where the note has ONCE, the PDF says ONCE1 and no ONCE3 (its counter stepped
once, or was set back), and RUNS1 (the text ran once), or RUNS2 for the notes
that aren't plain, whose version at the foot is the second of three runs.
linewidth: LWA and LWB are more than 60bp apart
(the box of .01\\linewidth is measured where \\linewidth is half as wide as TeX
allows: a limit, pinned).  huge: only that it isn't plain, for a line too
wide.  bs: the margin note's BSLINE (the line after \\) starts at the margin's
edge, from the log's "didactic-margin:" line, within a point.  fnmark: the word
before NOTEA in the margin is the note's own mark, 1.  lang: the words of the note at the foot
that end with a hyphen are those of JOB-ref (the same note set at the foot by
LaTeX, \testlangref).
Prints one line, PASS or FAIL with what failed; exit status 1 on FAIL.
"""
import html
import re
import subprocess
import sys

# case: (why it isn't plain, a regular expression; None: plain), whether it has
# ONCE, whether its place is checked
CASES = {
    "plain": (None, True, True), "cite": (None, False, True), "url": (None, False, True),
    "prepost": (None, False, True), "reuse": (None, False, True),
    "twopar": (None, True, True), "mixed": (None, True, True), "color": (None, True, True),
    "linewidth": (None, True, True),
    "list": ("another width|space of its own", True, True),
    "display": ("another width|space of its own", True, True),
    "parbox": ("too wide", True, True),
    "vspace": ("space of its own between paragraphs|space of its own between lines",
               True, True),
    "huge": ("too wide", False, False),
    "bs": (None, True, False), "fnmark": (None, True, False), "lang": (None, True, True),
}
job, case = sys.argv[1], sys.argv[2]
reason, hasonce, placed = CASES[case]
log = open(f"{job}.log", errors="replace").read()
joined = re.sub(r"\n\(didactic\) *", " ", log).replace("\n", "")
out = subprocess.run(["pdftotext", "-bbox", f"{job}.pdf", "-"], capture_output=True,
                     text=True).stdout
text = subprocess.run(["pdftotext", f"{job}.pdf", "-"], capture_output=True,
                      text=True).stdout.replace("\n", " ")
pages = []
for page in re.findall(r"<page[^>]*>(.*?)</page>", out, re.S):
    pages.append([(float(a), float(b), float(c), float(d), html.unescape(w)) for a, b, c, d, w
                  in re.findall(r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" '
                                r'yMax="([\d.]+)">(.*?)</word>', page)])
fails = []
errors = re.findall(r"^! .*", log, re.M)
if errors:
    fails.append(f"errors: {errors[:2]}")
said = re.findall(r"isn't plain: it has (.*?);", joined)
if "found from the last run" in joined:
    fails.append("a note found from the last run, not warned in it")
if reason is None and said:
    fails.append(f"found not plain: {said}")
elif reason is not None and (len(said) != 1 or not re.search(reason, said[0])):
    fails.append(f"not plain for '{reason}' expected, the log says {said}")


def find(word):
    return [(n, w) for n, ws in enumerate(pages, 1) for w in ws if w[4].startswith(word)]


left = min((w[0] for w in pages[0] if w[4] == "x"), default=0) if pages else 0
body = [w for w in pages[0] if w[3] - w[1] > 8.5] if pages else []
right = max((w[2] for w in body), default=0)
width = right - left
calla, notea = find("CALLA"), find("NOTEA")
if placed and (not calla or not notea):
    fails.append("no CALLA or NOTEA")
elif placed:
    pc, (pn, wn) = calla[0][0], notea[-1]
    if pn != pc:
        fails.append(f"NOTEA on page {pn}, CALLA on {pc}")
    elif not left - 2 <= wn[0] < right:
        fails.append(f"NOTEA not in the text column (x {wn[0]:.1f}, text {left:.1f}..{right:.1f})")
    else:
        lines = [w for w in pages[pn - 1] if w[1] >= wn[1] - 10 and w[3] - w[1] <= 8.5
                 and left - 2 <= w[0] < right]
        reach = max((w[2] for w in lines), default=0) - left
        if reach < .75 * width:
            fails.append(f"the note reaches {reach:.1f} of the text's {width:.1f}")
if hasonce:
    if "ONCE1" not in text:
        fails.append("no ONCE1")
    if "ONCE3" in text:
        fails.append("ONCE3: the counter stepped more than once")
    runs = "RUNS2" if reason else "RUNS1"
    if runs not in text:
        fails.append(f"no {runs}: {re.findall(r'RUNS[0-9]+', text)}")
if case == "linewidth":
    a, b = find("LWA"), find("LWB")
    if not a or not b or b[-1][1][0] - a[-1][1][2] < 60:
        fails.append(f"LWA and LWB not far apart: {a[-1:]} {b[-1:]}")
if case == "bs":
    m = re.search(r"didactic-margin: odd=([\d.]+) even=([\d.]+)", log)
    b = find("BSLINE")
    if not m or not b:
        fails.append("no margin line or no BSLINE")
    else:
        edge = float(m[1]) if b[-1][0] % 2 else float(m[2])
        if abs(b[-1][1][0] - edge) > 1:
            fails.append(f"BSLINE at x {b[-1][1][0]:.1f}, the margin's edge at {edge:.1f}")
if case == "fnmark":
    a = find("NOTEA")
    if not a:
        fails.append("no NOTEA")
    else:
        n, w = a[-1]
        before = [v for v in pages[n - 1] if abs(v[1] - w[1]) < 4 and v[2] <= w[0] + 1]
        mark = max(before, key=lambda v: v[2])[4] if before else None
        if mark != "1":
            fails.append(f"the note's mark is {mark}, not 1")
if case == "lang":
    def hyphenated(j):
        o = subprocess.run(["pdftotext", f"{j}.pdf", "-"], capture_output=True,
                           text=True).stdout
        return [w for w in o.split() if w.endswith("-") and len(w) > 3]
    mine, ref = hyphenated(job), hyphenated(job + "-ref")
    if mine != ref:
        fails.append(f"broken {mine}, LaTeX's footnote {ref}")
print(("FAIL: " + "; ".join(fails)) if fails else "PASS")
sys.exit(1 if fails else 0)
