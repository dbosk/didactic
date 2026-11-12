#!/usr/bin/env python3
"""Check a build of test-footreuse-spread.tex by its outcome, from the PDF.

Usage: test-footreuse-spread.py JOB [oneside] [reused] [last=N] [next] [shared]
                                [warned] [reusenamed] [noreusenamed]
                                [notplain=N]

Always: no footnote found not plain (didactic's information) but N declared.

A mark is a number set right after a word, with no space ("spread1"); a note's
number is one set right before a word, with none after another (the folio and
numbers in the text have spaces on both sides).  Under twoside a spread is page 1
alone, then pages 2 and 3, 4 and 5, and so on; oneside, each page is its own.
Checks:
- every mark has a note with its number on its spread (a reusing mark parted from
  its note fails here);
- no spread has two notes with the same number (a note set twice);
- there is at least one mark (the test has run at all);
- reused: some mark has its note on the other page of its spread only (the
  footnote was reused, not set again);
- last=N: the last mark is on page N (the case parts what it means to part);
- next: a mark's note may also be on the next spread (a note carried or waiting
  for the next page, its marks before it, in order), instead of on its own;
- shared: some number has two marks (the second reuses the note);
- warned: the log has a warning that a note is set on a later page or waits;
- reusenamed: such a warning names a mark that reuses the note's number;
- noreusenamed: no warning names one (nothing reuses the note: numbers that
  restart in each chapter are other notes').
Prints one line, PASS or FAIL with what failed; exit status 1 on FAIL.
"""
import re
import subprocess
import sys

job = sys.argv[1]
oneside = "oneside" in sys.argv[2:]
out = subprocess.run(["pdftotext", "-bbox", f"{job}.pdf", "-"], capture_output=True,
                     text=True, check=True).stdout
marks, notes = [], []
for n, page in enumerate(re.findall(r"<page[^>]*>(.*?)</page>", out, re.S), 1):
    words = [(float(x0), float(y0), float(x1), float(y1), w) for x0, y0, x1, y1, w in
             re.findall(r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" '
                        r'yMax="([\d.]+)">([^<]*)</word>', page)]
    for x0, y0, x1, y1, w in words:
        if not w.isdigit():
            continue
        def touching(side):
            for a0, b0, a1, b1, v in words:
                if v != w or (a0, b0) != (x0, y0):
                    gap = x0 - a1 if side == "left" else a0 - x1
                    # On a line with it: the bottoms (a note's number) or the
                    # tops (a raised mark) agree.
                    if (abs(b1 - y1) < 6 or abs(b0 - y0) < 3) and -0.5 <= gap < 1.5:
                        return True
            return False
        if touching("left"):
            marks.append((n, int(w)))
        elif touching("right"):
            notes.append((n, int(w)))


def spread(p):
    if oneside or p == 1:
        return (p,)
    return (p, p + 1) if p % 2 == 0 else (p - 1, p)


fails = []
nxt = "next" in sys.argv[2:]
for p, k in marks:
    if not any((q in spread(p) or (nxt and q in spread(max(spread(p)) + 1))) and j == k
               for q, j in notes):
        fails.append(f"mark {k} on page {p} has no note {k} on its spread")
seen = {}
for q, j in notes:
    key = (spread(q), j)
    if key in seen:
        fails.append(f"note {j} twice on spread {spread(q)} (pages {seen[key]} and {q})")
    seen[key] = q
if not marks:
    fails.append("no marks found")
for a in sys.argv[2:]:
    if a.startswith("last=") and (not marks or marks[-1][0] != int(a[5:])):
        fails.append(f"the last mark isn't on page {a[5:]}")
if "reused" in sys.argv[2:] and not any(
        not any(q == p and j == k for q, j in notes) for p, k in marks):
    fails.append("no mark reuses a note from the other page of its spread")
if "shared" in sys.argv[2:] and not any(sum(1 for p, k in marks if k == j) > 1
                                         for j in set(k for p, k in marks)):
    fails.append("no number has two marks")
if "warned" in sys.argv[2:]:
    log = re.sub(r"\n\(didactic\) *", " ", open(f"{job}.log", errors="replace").read())
    if not re.search(r"is set on page \d+|waits for the foot", log.replace("\n", "")):
        fails.append("no warning that a note is set on a later page or waits")
if "reusenamed" in sys.argv[2:]:
    log = re.sub(r"\n\(didactic\) *", " ", open(f"{job}.log", errors="replace").read())
    if "its number is reused at" not in log.replace("\n", ""):
        fails.append("no warning names a mark that reuses the note's number")
if "noreusenamed" in sys.argv[2:]:
    log = re.sub(r"\n\(didactic\) *", " ", open(f"{job}.log", errors="replace").read())
    if "its number is reused at" in log.replace("\n", ""):
        fails.append("a warning names a mark that reuses another note's number")
# notes the last run placed on another page than their callout without a
# warning, found from its records ("found from the last run"): as many as
# the test declares, foundlast=N, else none; each is a silent case
FOUNDLAST = len(re.findall(r"found from the last\s+run", re.sub(r"\n\(didactic\) *", " ", open(f"{job}.log", errors="replace").read())))
WANTLAST = int(next((a[10:] for a in sys.argv[2:] if a.startswith("foundlast=")), 0))
if FOUNDLAST != WANTLAST:
    fails.append(f"{FOUNDLAST} notes found from the last run, {WANTLAST} declared")
# notes found not plain (didactic's info): as many as the test declares,
# notplain=N, else none; a note found not plain by mistake runs its text
# three times without a warning
NOTPLAIN = len(re.findall(r"isn't plain", re.sub(r"\n\(didactic\) *", " ", open(f"{job}.log", errors="replace").read())))
WANTPLAIN = int(next((a[9:] for a in sys.argv[2:] if a.startswith("notplain=")), 0))
if NOTPLAIN != WANTPLAIN:
    fails.append(f"{NOTPLAIN} notes not plain, {WANTPLAIN} declared")
facts = f"marks {marks}, notes {notes}"
print(("FAIL: " + "; ".join(fails) if fails else "PASS") + " (" + facts + ")")
sys.exit(1 if fails else 0)
