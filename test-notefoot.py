#!/usr/bin/env python3
"""Check a settled build of test-notefoot.tex by its outcome.

Usage: test-notefoot.py JOB [CHECK...]

Reads JOB.aux (the labels m-N at each \\fn's mark and n-N in its note, and their
saved positions), JOB.log (warnings, the document's own notefoot-rule lines and
INSIDE/MK line) and JOB.pdf (pages); nothing the mechanism logs.  Always:

- every note has its labels, once each (a note set twice writes them twice);
- every note away from its mark's page is named by a warning (that a margin note
  is set on another page than its callout, or that multicol set a footnote at
  the foot of another page than its mark's), at least as many as notes away.

CHECKs:
  foot        some notes are at the foot: their saved position is in the text
              column;
  nofoot      none is;
  beside      no note is away from its mark's page;
  order       on each page, the notes at the foot are in the order of their
              marks;
  rules       no page has more than one \\footnoterule;
  counter     a counter stepped in each note is stepped once per note
              (INSIDE= equals MK=), and no label is multiply defined;
  nodest      no warning of hyperref's about a link target;
  floatsonly  no page "contains only floats";
  works=W     a warning of didactic's has W (that foot works as carry);
  pagesge=J   at least as many pages as job J;
  nofalse     no more warnings than notes away (when every margin note is one
              with labels);
  nooverfull  no page too full for its output (an overfull \\vbox while
              \\output is active: material below the text block);
  nooverlap   no two words of a page on top of each other (pdftotext -bbox);
  notplain=N  N footnotes found not plain (didactic's information); none if not
              given;
  held=N      N floats held back for the margin notes on their page (didactic's
              information, "The float ending at ... waits");
  away=N      exactly N notes away from their marks' pages;
  reasons     every warning that a note is set on a later page gives a reason;
  nocantread  no warning of didactic's that the callouts of a page can't be read
              (marginfix's own may be there);
  noover      no warning that a note runs past the foot of the margin;
  nofootwhy   no warning says a note fits "nor at the foot" (for a job whose notes
              away are plain margin notes, which can't go there).
Prints a line per job, PASS or FAIL with what failed; exit status 1 on FAIL.
"""
import re
import subprocess
import sys

job, checks = sys.argv[1], sys.argv[2:]
aux = open(f"{job}.aux", errors="replace").read()
log = open(f"{job}.log", errors="replace").read()
# a multicol from outside TeX Live's tools (an old copy in a texmf tree) tests
# nothing of what users have
OLDMC = [m for m in re.findall(r"\(([^ ()]*multicol\.sty)", log.replace("\n", ""))
         if "texmf-dist/tex/latex/tools/" not in m]
joined = re.sub(r"\n\((?:didactic|marginfix|hyperref)\) *", " ", log).replace("\n", "")


def overlaps(j):
    """Pages of JOB.pdf where two words overlap by more than a point both ways."""
    out = subprocess.run(["pdftotext", "-bbox", f"{j}.pdf", "-"], capture_output=True,
                         text=True).stdout
    bad = []
    for n, page in enumerate(re.findall(r"<page[^>]*>(.*?)</page>", out, re.S), 1):
        ws = [tuple(map(float, w)) for w in re.findall(
            r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)"', page)]
        if any(min(a[2], b[2]) - max(a[0], b[0]) > 1 and min(a[3], b[3]) - max(a[1], b[1]) > 1
               for i, a in enumerate(ws) for b in ws[i + 1:]):
            bad.append(n)
    return bad


def pages_of(j):
    out = subprocess.run(["pdfinfo", f"{j}.pdf"], capture_output=True, text=True).stdout
    m = re.search(r"Pages:\s+(\d+)", out)
    return int(m[1]) if m else 0


labels = re.findall(r"\\newlabel\{([mn]-\d+)\}\{\{[^}]*\}\{(\d+)\}", aux)
count = {}
for k, _ in labels:
    count[k] = count.get(k, 0) + 1
page = dict(labels)
pos = {}
for k, props in re.findall(r"\\zref@newlabel\{([mn]-\d+)\}\{(.*)\}$", aux, re.M):
    v = dict(re.findall(r"\\(posx|posy|abspage)\{(-?\d+)\}", props))
    if len(v) == 3:
        pos[k] = (int(v["posx"]), int(v["posy"]), int(v["abspage"]))
geo = re.search(r"notefoot geometry:(.*?)(?:\n\n|\n[^\n]*:)", log, re.S)
geo = {k: int(v) for k, v in re.findall(r"(\w+)=(-?\d+)", geo[1].replace("\n", ""))} if geo else {}
marks = sorted(int(k[2:]) for k in page if k.startswith("m-"))
notes = sorted(int(k[2:]) for k in page if k.startswith("n-"))
away = [n for n in notes if f"m-{n}" in page and page[f"n-{n}"] != page[f"m-{n}"]]


def atfoot(n):
    if f"n-{n}" not in pos or not geo:
        return False
    x, y, p = pos[f"n-{n}"]
    left = geo["odd"] if p % 2 else geo["even"]
    # twoside or not, the text column is where it is on that page: odd pages
    # take oddsidemargin, even ones evensidemargin (the same when oneside).
    return left - 65536 <= x < left + geo["width"]


feet = [n for n in notes if atfoot(n)]
said = len(re.findall(r"[Mm]argin note called out at.{0,160}? on page \d+ is set on (?:page|a later page)|Margin note from .{0,160}? moved from page|"
                      r"A margin note from page|Footnote \d+ in multicols is called out on page \d+", joined))
fails = []
if OLDMC:
    fails.append("multicol.sty from outside TeX Live's tools: %s" % OLDMC[0])
if not notes or marks != notes:
    fails.append(f"{len(marks)} marks, {len(notes)} notes with labels")
twice = sorted(k for k, c in count.items() if c > 1)
if twice:
    fails.append(f"labels written twice: {twice[:6]}")
if said < len(away):
    fails.append(f"{len(away)} notes away, {said} warnings")
# a reason that counts lines left at the foot counts none or more, never less
if re.search(r"\(-\d+ lines left there", joined):
    fails.append("a warning counts fewer than no lines left at the foot")
for c in checks:
    if c == "foot" and not feet:
        fails.append("no note at the foot")
    elif c == "nofoot" and feet:
        fails.append(f"notes at the foot: {feet[:8]}")
    elif c == "beside" and away:
        fails.append(f"notes away from their marks' pages: {away[:8]}")
    elif c == "order":
        bypage = {}
        for n in feet:
            x, y, p = pos[f"n-{n}"]
            bypage.setdefault(p, []).append((-y, n))
        for p, ns in bypage.items():
            seq = [n for _, n in sorted(ns)]
            if seq != sorted(seq):
                fails.append(f"page {p}: notes at the foot in the order {seq}")
    elif c == "rules":
        rules = {}
        for p in re.findall(r"^notefoot-rule: page=(\d+)", log, re.M):
            rules[p] = rules.get(p, 0) + 1
        many = {p: r for p, r in rules.items() if r > 1}
        if many:
            fails.append(f"pages with more than one rule: {many}")
    elif c == "counter":
        m = re.search(r"INSIDE=(\d+) MK=(\d+)", log)
        if not m or m[1] != m[2]:
            fails.append(f"counter stepped as {m[0] if m else 'unknown'}")
        if "multiply defined" in joined:
            fails.append("labels multiply defined")
    elif c == "nodest" and re.search(r"warning \(dest\)|same identifier", joined):
        fails.append("warnings about link targets")
    elif c == "floatsonly" and "contains only floats" in joined:
        fails.append("a page of floats only")
    elif c.startswith("works=") and c[6:] not in joined:
        fails.append(f"no warning with '{c[6:]}'")
    elif c.startswith("pagesge=") and pages_of(job) < pages_of(c[8:]):
        fails.append(f"{pages_of(job)} pages, fewer than {c[8:]}'s {pages_of(c[8:])}")
    elif c == "nofalse" and said > len(away):
        fails.append(f"{said} warnings for {len(away)} notes away")
    elif c == "nooverfull" and re.search(r"Overfull \\vbox[^\n]*while \\output is active", log):
        fails.append("a page overfull in the output routine")
    elif c.startswith("held=") and len(re.findall(
            r"Package didactic Info: The float ending at", log)) != int(c[5:]):
        fails.append(f"{len(re.findall(r'Package didactic Info: The float ending at', log))}"
                     f" floats held, not {c[5:]}")
    elif c.startswith("away=") and len(away) != int(c[5:]):
        fails.append(f"{len(away)} notes away, not {c[5:]}: {away[:8]}")
    elif c == "noover" and re.search(r"runs [\d.]+pt past the foot of the margin", joined):
        fails.append("a warning that a note runs past the foot of the margin")
    elif c == "nofootwhy" and "nor at the foot" in joined:
        fails.append("a plain note's warning names the foot")
    elif c == "nocantread" and "didactic Warning: Can't read the callouts" in joined:
        fails.append("a warning that the callouts of a page can't be read")
    elif c == "reasons" and re.search(r"is set on page \d+\.", joined):
        fails.append("a note set on a later page without a reason")
    elif c == "nooverlap" and overlaps(job):
        fails.append(f"words on top of each other on pages {overlaps(job)}")
# notes the last run placed on another page than their callout without a
# warning, found from its records ("found from the last run"): as many as
# the test declares, foundlast=N, else none; each is a silent case
FOUNDLAST = len(re.findall(r"found from the last\s+run", re.sub(r"\n\(didactic\) *", " ", log)))
WANTLAST = int(next((a[10:] for a in checks if a.startswith("foundlast=")), 0))
if FOUNDLAST != WANTLAST:
    fails.append(f"{FOUNDLAST} notes found from the last run, {WANTLAST} declared")
# notes found not plain (didactic's info): as many as the test declares,
# notplain=N, else none; a note found not plain by mistake runs its text
# three times without a warning
NOTPLAIN = len(re.findall(r"isn't plain", re.sub(r"\n\(didactic\) *", " ", log)))
WANTPLAIN = int(next((a[9:] for a in checks if a.startswith("notplain=")), 0))
if NOTPLAIN != WANTPLAIN:
    fails.append(f"{NOTPLAIN} notes not plain, {WANTPLAIN} declared")
facts = f"{len(notes)} notes, {len(feet)} at the foot, {len(away)} away, {said} warnings"
print(("FAIL: " + "; ".join(fails) if fails else "PASS") + f" ({facts})")
sys.exit(1 if fails else 0)
