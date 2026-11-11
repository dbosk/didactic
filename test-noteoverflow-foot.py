#!/usr/bin/env python3
"""Check the builds of test-noteoverflow-foot.tex (didactic, noteoverflow=foot).

    test-noteoverflow-foot.py check JOB [foot|nofoot] [spill|carried] [away] [warn] [nolabels]
    test-noteoverflow-foot.py same JOB OTHER
    test-noteoverflow-foot.py records JOB OTHER
    test-noteoverflow-foot.py hbox FOOT BREAK REF

check reads JOB.pdf, JOB.log and JOB.aux, the outcome only, whatever the
mechanism (no log line of marginfix's counts; the job has settled when the runner
calls this):
- no LaTeX error, and no warning of hyperref's about a link target;
- any: no check of the foot (in two columns the notes beside the first column
  are within the text block, so the words can't tell);
- foot: some notes are set at the foot: words that only notes have (the titles
  of the works, "footnote") are in the text column, on a page before the end of
  the text (ENDPART); nofoot: none are;
- every citation's footnote on the page of its mark: the zref label at the mark
  (didacticfn@...) and the one in the note (didacticfnnote@...) have the same
  abspage, wherever the note is set, unless away is given (or nolabels:
  footnotereuse=off writes no labels); carried: at least one isn't (the case of
  a note that fits nowhere);
- every note away from its mark is named by a warning (that a margin note is set
  on another page than its callout), at least as many warnings as notes away,
  and no more (each margin note here is a footnote with labels, except the tall
  one of testnowhere, which fits beside its line);
- no page is less than half full, except the last and one whose text ends with
  ENDPART (before \\clearpage): no page ends early to leave half of it empty;
- warn: didactic warns that noteoverflow=foot works as break; otherwise it
  doesn't.
same compares the words of JOB.pdf and OTHER.pdf (pdftotext): the same words,
as many times each, so the citations are the same, full or short, whichever way
their notes are set.  Words are taken without digits (page numbers and the
numbers of the notes, which are on other lines) or hyphens (where lines break
differs).
records compares what biblatex writes to JOB.aux and OTHER.aux about each work
(\abx@aux@... lines: citations, backrefs, citecounter), counted by kind and work:
a copy of a note that isn't printed must add none, wherever its page.
hbox reads the logs of test-noteoverflow-foot-hbox.tex built with foot (FOOT), with
break (BREAK) and with carry (REF, where no copy for the foot is made and TeX speaks
for the only one): the copy of a footnote that isn't printed says nothing,
and the printed one says what TeX would, once, with its place.  Footnotes A (input
line 20) and D (22) are in the margin of page 1 under foot: didactic says what TeX
says in REF, and TeX says nothing more; nothing comes from their foot copies.  Under
break the margin copy is the only one, and TeX speaks for it as in REF.  B (28) and C (30) are at the foot of page 2 under foot (in the margin of
page 3 under break): no line of TeX's names them, and didactic says once that B's
foot copy has an overfull line and C's an underfull one, naming the file, the line
and the page, and nothing of their margin copies.
A line per check, PASS or FAIL; the exit status is 1 on any FAIL.
"""
import collections
import html
import re
import subprocess
import sys

failed = False


def report(name, ok, detail=""):
    global failed
    print(f"didactic noteoverflow foot test: {name}", "PASS" if ok else "FAIL",
          detail)
    failed |= not ok


# Words that only the notes have: the titles and publishers of the works, and the
# plain footnotes' own words.
NOTEWORDS = re.compile(r"^(Journal|Studies|Annals|Proceedings|Invented|footnote|"
                       r"Imaginary|Pretend|Workshop)")


def body(job, log):
    """The words of JOB.pdf in the text column, page by page, as (word, y)."""
    geo = re.search(r"noteoverflow-foot geometry:(.*?)(?:\n\n|\n[^\n]*:)", log, re.S)
    geo = {k: float(v) for k, v in re.findall(r"(\w+)=([\d.]+)", geo[1].replace("\n", ""))}
    out = subprocess.run(["pdftotext", "-bbox", f"{job}.pdf", "-"], capture_output=True,
                         text=True, check=True).stdout
    pages = []
    for n, page in enumerate(re.findall(r"<page[^>]*>(.*?)</page>", out, re.S)):
        left = geo["odd"] if n % 2 == 0 else geo["even"]
        ws = []
        for x0, y0, x1, y1, w in re.findall(r'<word xMin="([\d.]+)" yMin="([\d.]+)" '
                                            r'xMax="([\d.]+)" yMax="([\d.]+)">(.*?)</word>', page):
            x0, y0, x1, y1 = map(float, (x0, y0, x1, y1))
            if (x0 >= left - 2 and x1 <= left + geo["width"] + 2
                    and geo["top"] <= (y0 + y1) / 2 <= geo["top"] + geo["height"]):
                ws.append((html.unescape(w), y1))
        pages.append(ws)
    return pages, geo


def check(job, want, spill, away_ok, warn, nolabels):
    log = open(f"{job}.log", errors="replace").read()
    aux = open(f"{job}.aux", errors="replace").read()
    joined = re.sub(r"\n\((?:didactic|marginfix)\) *", " ", log).replace("\n", "")
    errors = re.findall(r"^! .*", log, re.M)
    report(f"{job} errors", not errors, " ".join(errors[:2]))
    dest = re.findall(r"warning \(dest\)|same identifier|has been referenced but"
                      r" does not exist", log)
    report(f"{job} link targets", not dest, f"({len(dest)})")
    told = len(re.findall(r"noteoverflow=foot works as", joined))
    report(f"{job} {'warns' if warn else 'quiet'}", told > 0 if warn else told == 0,
           f"({told})")
    pages, geo = body(job, log)
    end = next((n for n, ws in enumerate(pages) if any("ENDPART" in w for w, _ in ws)),
               len(pages) - 1)
    feet = sorted({n + 1 for n, ws in enumerate(pages[:end + 1])
                   for w, _ in ws if NOTEWORDS.match(w)})
    if want != "any":
        report(f"{job} {want}", bool(feet) if want == "foot" else not feet,
               f"(notes in the text column on pages {feet})")
    half = [n + 1 for n, ws in enumerate(pages[:-1])
            if ws and not any("ENDPART" in w for w, _ in ws)
            and max(y for _, y in ws) < geo["top"] + geo["height"] / 2]
    report(f"{job} half-empty", not half, f"(pages {half})")
    pages = {}
    for name, page in re.findall(r"\\zref@newlabel\{(didacticfn(?:note)?@[^}]*)\}"
                                 r"\{[^\n]*?\\abspage\{(\d+)\}", aux):
        pages[name] = int(page)
    marks = {k[len("didacticfn@"):]: v for k, v in pages.items()
             if k.startswith("didacticfn@")}
    notes = {k[len("didacticfnnote@"):]: v for k, v in pages.items()
             if k.startswith("didacticfnnote@")}
    away = [s for s in notes if s in marks and notes[s] != marks[s]]
    report(f"{job} marks", nolabels or (notes and (away_ok or not away)),
           f"({len(notes)} notes, {len(away)} away from their marks)")
    if spill == "carried":
        report(f"{job} carried", nolabels or bool(away), f"({len(away)} away)")
    said = len(re.findall(r"[Mm]argin note called out at.{0,160}? on page \d+ is set on (?:page|a later page)|Margin note from .{0,160}? moved from page|"
                          r"A margin note from page", joined))
    report(f"{job} away named", nolabels or said >= len(away),
           f"({len(away)} away, {said} warnings)")
    report(f"{job} no false warning", nolabels or said <= len(away),
           f"({said} warnings for {len(away)} away)")


def words(pdf, log):
    """The words of each column, page by page, with words broken over lines
    joined: the text and the margin are columns of their own, which pdftotext
    would interleave."""
    m = re.search(r"didactic-margin: odd=([\d.]+) even=([\d.]+) width=([\d.]+)",
                  log)
    odd, even, width = float(m[1]), float(m[2]), float(m[3])
    out = subprocess.run(["pdftotext", "-bbox", pdf, "-"], capture_output=True,
                         text=True, check=True).stdout
    found = collections.Counter()
    for n, page in enumerate(re.findall(r"<page[^>]*>(.*?)</page>", out, re.S)):
        def margin(x):
            return x >= odd - 2 if n % 2 == 0 else x < even + width + 2
        cols = {False: [], True: []}
        for x, y, w in re.findall(r'<word xMin="([\d.]+)" yMin="[\d.]+" '
                                  r'xMax="[\d.]+" yMax="([\d.]+)">(.*?)</word>',
                                  page):
            cols[margin(float(x))].append((float(y), float(x),
                                           html.unescape(w)))
        for col in cols.values():
            lines, last = [], None
            for y, x, w in sorted(col):
                if last is None or y - last > 4:
                    lines.append([])
                lines[-1].append((x, w))
                last = y
            text = "\n".join(" ".join(w for _, w in sorted(line))
                              for line in lines)
            text = re.sub(r"(?<=[-\u2013])\n", "", text)
            text = re.sub(r"(?<=\w)-\n?(?=\w)", "", text)
            found.update(w for w in (re.sub(r"[\d\-]", "", w)
                                     for w in text.split()) if w)
    return found


def same(job, other):
    a = words(f"{job}.pdf", open(f"{job}.log", errors="replace").read())
    b = words(f"{other}.pdf", open(f"{other}.log", errors="replace").read())
    diff = (a - b) + (b - a)
    report(f"{job} as {other}", not diff,
           " ".join(sorted(diff))[:200])


def records(job, other):
    def count(j):
        aux = open(f"{j}.aux", errors="replace").read()
        return collections.Counter(re.findall(
            r"\\(abx@aux@\w+)\{(?:\d+|[^}]*)\}\{(src\d+)\}", aux))
    a, b = count(job), count(other)
    diff = (a - b) + (b - a)
    report(f"{job} records as {other}", a and not diff,
           " ".join(f"{k}:{w}" for (k, w) in sorted(diff))[:200])


def unwrapped(path):
    """A log, with the lines TeX broke at 79 characters joined."""
    out = []
    for line in open(path, errors="replace").read().split("\n"):
        if out and len(out[-1]) == 79 and not line.startswith("("):
            out[-1] += line
        else:
            out.append(line)
    return re.sub(r"\n\((?:didactic|marginfix)\) *", " ", "\n".join(out))


def hbox(foot, brk, ref):
    src = "test-noteoverflow-foot-hbox.tex"
    def tex(log, line):
        return sorted(re.findall(r"((?:Over|Under)full \\hbox \([^)]*\)) in paragraph at "
                                 rf"lines {line}--{line}", log))
    def ours(log, line, where):
        return sorted(re.findall(r"Package didactic Warning: ((?:Over|Under)full \\hbox "
                                 r"\([^)]*\)) in the footnote called out at "
                                 rf"{re.escape(src)}:{line}, {where} of page (\d+)", log))
    f, b, r = unwrapped(f"{foot}.log"), unwrapped(f"{brk}.log"), unwrapped(f"{ref}.log")
    for line in (20, 22):
        want = [(w, "1") for w in tex(r, line)]
        got = ours(f, line, "in the margin")
        report(f"{foot} margin note at line {line}: TeX's words, once, from the printed copy",
               bool(want) and got == want and not tex(f, line),
               f"({len(got)} said, {len(want)} by TeX, {len(tex(f, line))} still TeX's)")
    n = sum(len(ours(f, line, "at the foot")) for line in (20, 22))
    report(f"{foot} nothing from the foot copies of notes in the margin", n == 0, f"({n})")
    for line in (20, 22, 28, 30):
        n = len(ours(b, line, "in the margin")) + len(ours(b, line, "at the foot"))
        report(f"{brk} note at line {line}: TeX speaks for the only copy, as without the wrapper",
               bool(tex(r, line)) and tex(b, line) == tex(r, line) and n == 0,
               f"({len(tex(b, line))} against {len(tex(r, line))}, {n} of didactic's)")
    for line, kind in ((28, "Over"), (30, "Under")):
        report(f"{foot} note at the foot at line {line}: no line of TeX's", not tex(f, line),
               " ".join(tex(f, line))[:120])
        got = ours(f, line, "at the foot")
        report(f"{foot} note at the foot at line {line}: one {kind.lower()}full warning, page 2",
               len(got) == 1 and got[0][0].startswith(kind) and got[0][1] == "2", f"({got})")
        n = len(ours(f, line, "in the margin"))
        report(f"{foot} note at the foot at line {line}: nothing from its margin copy", n == 0,
               f"({n})")


if __name__ == "__main__":
    if sys.argv[1] == "check":
        check(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "foot",
              "carried" if "carried" in sys.argv[4:] else "spill" in sys.argv[4:],
              "away" in sys.argv[4:],
              "warn" in sys.argv[4:], "nolabels" in sys.argv[4:])
    elif sys.argv[1] == "hbox":
        hbox(sys.argv[2], sys.argv[3], sys.argv[4])
    elif sys.argv[1] == "records":
        records(sys.argv[2], sys.argv[3])
    else:
        same(sys.argv[2], sys.argv[3])
    sys.exit(1 if failed else 0)
