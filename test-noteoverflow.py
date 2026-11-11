#!/usr/bin/env python3
"""Check a settled build of a test-noteoverflow* document by its outcome.

Usage: test-noteoverflow.py JOB beside|carried|warned

From the labels each footnote has at its mark (fm-N) and in its note (fn-N), see
test-noteoverflow-contents.tex, and from the warnings of the log; no log line of
marginfix's counts.  Always: every note has both labels, none is multiply
defined, and every note set on another page than its mark is named by a warning
(that a margin note is set on another page than its callout: at least as many
warnings as notes away), and no more warnings than notes away (the documents
have no margin notes but the footnotes, so a warning more names a note that is
on its page, or one twice).  Then:
  beside   no note is set on another page than its mark;
  carried  some notes are (noteoverflow=carry moves them on, with warnings);
  warned   either.
Prints one line, PASS or FAIL with what failed; exit status 1 on FAIL.
"""
import re
import sys

job, mode = sys.argv[1], sys.argv[2]
aux = open(f"{job}.aux", errors="replace").read()
log = open(f"{job}.log", errors="replace").read()
joined = re.sub(r"\n\((?:didactic|marginfix)\) *", " ", log).replace("\n", "")
page = {k: int(v) for k, v in re.findall(r"\\newlabel\{(f[mn]-\d+)\}\{\{[^}]*\}\{(\d+)\}", aux)}
marks = {k[3:]: v for k, v in page.items() if k.startswith("fm-")}
notes = {k[3:]: v for k, v in page.items() if k.startswith("fn-")}
away = sorted((int(n) for n in marks if n in notes and notes[n] != marks[n]))
said = len(re.findall(r"[Mm]argin note called out at.{0,160}? on page \d+ is set on page|Margin note from .{0,160}? moved from page|"
                      r"A margin note from page", joined))
twice = len(re.findall(r"Label `f[mn]-\d+' multiply defined", joined))
fails = []
if not marks or set(marks) != set(notes):
    fails.append(f"{len(marks)} marks, {len(notes)} notes with labels")
if twice:
    fails.append(f"{twice} labels multiply defined")
if said < len(away):
    fails.append(f"{len(away)} notes away from their marks, {said} warnings")
if said > len(away):
    fails.append(f"{said} warnings for {len(away)} notes away")
if mode == "beside" and away:
    fails.append(f"notes away from their marks: {away[:10]}")
if mode == "carried" and not away:
    fails.append("no note carried")
print(("FAIL: " + "; ".join(fails) if fails else "PASS")
      + f" ({len(notes)} notes, {len(away)} away, {said} warnings)")
sys.exit(1 if fails else 0)
