#!/usr/bin/env python3
"""Page breaks around headings and listings, room by room, against plain LaTeX.

    python3 test-keep-sweep.py gen VARIANT > test-keep-sweep-VARIANT.tex
    python3 test-keep-sweep.py check VARIANT

`gen` writes a document with each case of CASES at each room from 1 to 14 lines,
with didactic (m memoir, a article, s memoir with \\sloppybottom, s3 that with
keepafterheading=3) or without it (mp, ap, sp: the same fonts and margins, so the
same pages but for what didactic does).  `check` reads the pages from the .aux and the warnings from the .log, of
the variant and its plain reference, and holds them to the rules below; it prints
a FAIL line per broken rule and exits non-zero if any broke or if a case is missing.

No double of anything: the documents are built by LaTeX, with the real packages.
What the rules are, and why, is in the documentation of didactic, the section on
page breaks around headings and listings:

  D2  A heading is never parted from its first paragraph.
  D4  Under a heading that stays there are never fewer lines than plain LaTeX keeps,
      and a heading that plain LaTeX keeps with two lines or more doesn't move.
      The penalties are the class's own, so nothing excuses a difference here.
  D6  A listing's lead-in goes along only within keepmaxgap; parted, there's a warning.
      What it leaves empty on the page, measured in the output routine, is within
      the limit when the lead-in moves, and parted is only what would otherwise
      leave more than that.
  D8  Every warning says what the page does, and no move past the limit is silent:
      a heading that moves with more room than the limit warns, and no other does;
      "only n of its lines" is the number of lines on the page; a listing that
      "goes to the next page" does.
"""
import re
import sys

LIMIT = 5.0     # keepmaxgap, default
ROOMS = [q / 2 for q in range(2, 29)]
FINEROOMS = [q / 4 for q in range(4, 57)]  # where a heading's own spaces decide

MIMIC = (r"\usepackage[T1]{fontenc}\usepackage[osf,sc]{mathpazo}"
         r"\usepackage[scaled=0.90]{helvet}\usepackage[scaled=0.85]{beramono}"
         r"\setlrmarginsandblock{23mm}{60.2mm}{*}"
         r"\setulmarginsandblock{30mm}{48.5mm}{*}\checkandfixthelayout"
         r"\setsecnumdepth{subsection}\nouppercaseheads")
MEMOIR = r"\documentclass[a4paper,10pt,oneside,oldfontcommands]{memoir}"
ARTICLE = r"\documentclass[a4paper,10pt]{article}"
NOWEB = r"\usepackage{noweb}"
BREAKCODE = r"\noweboptions{breakcode}"
AMS = r"\usepackage{amsmath,amssymb,amsthm}"
DIDACTIC = AMS + r"\usepackage[marginparmargin=outer]{didactic}"
BEAMER = r"\usepackage[noamsthm,notheorems]{beamerarticle}"
PLAIN = BEAMER + AMS + r"\newtheorem{example}{Example}\newtheorem{exercise}{Exercise}"
SLOPPY = r"\setlength{\topskip}{1.6\topskip}\checkandfixthelayout\sloppybottom"
VARIANTS = {
    "m": MEMOIR + NOWEB + DIDACTIC + BEAMER + BREAKCODE,
    "mp": MEMOIR + MIMIC + PLAIN + NOWEB + BREAKCODE + r"\usepackage{fancyvrb}",
    "a": ARTICLE + NOWEB + DIDACTIC + BEAMER + BREAKCODE,
    "ap": ARTICLE + PLAIN + NOWEB + BREAKCODE + r"\usepackage{fancyvrb}",
    "s": MEMOIR + NOWEB + DIDACTIC + BEAMER + BREAKCODE + SLOPPY,
    "sp": MEMOIR + MIMIC + PLAIN + NOWEB + BREAKCODE + r"\usepackage{fancyvrb}" + SLOPPY,
    "s3": MEMOIR + NOWEB + DIDACTIC.replace("outer", "outer,keepafterheading=3")
          + BEAMER + BREAKCODE + SLOPPY,
    "e": MEMOIR + NOWEB + DIDACTIC + BEAMER + BREAKCODE + r"\usepackage{enumitem}",
    "ep": MEMOIR + MIMIC + PLAIN + NOWEB + BREAKCODE + r"\usepackage{fancyvrb}\usepackage{enumitem}",
}

def para(k, n, name="L"):
    """A paragraph of n lines, each with a label."""
    return "\\hspace*{\\fill}\\break\n".join(rf"{name}{i}\label{{{name}{i}X{k}}}" for i in range(1, n + 1))


def items(k, n, lines):
    out = [r"\begin{itemize}"]
    for i in range(n):
        out.append(r"\item " + para(k, lines, f"I{i}x"))
    out.append(r"\end{itemize}")
    return "\n".join(out)


def listof(k, env, n, lines):
    "A list of another kind."
    out = [rf"\begin{{{env}}}"]
    for i in range(n):
        out.append((r"\item[x] " if env == "description" else r"\item ") + para(k, lines, f"I{i}x"))
    out.append(rf"\end{{{env}}}")
    return "\n".join(out)


def nested(k, n):
    "A paragraph of n lines in an item, and a list in that item, which is what it leads into."
    return "\n".join([r"\begin{itemize}", r"\item " + para(k, n, "P"),
                      items(k, 8, 1), r"\item Outer again.", r"\end{itemize}"])


def verbatim(k, n=5):
    return "\n".join([r"\begin{Verbatim}[commandchars=\\\{\}]"]
                     + [rf"code{i}\label{{C{i}X{k}}}" for i in range(1, n + 1)]
                     + [r"\end{Verbatim}"])


HEADER = r"\nwenddocs{}\nwbegincode{2}\moddef{name}\endmoddef\nwstartdeflinemarkup\nwenddeflinemarkup"
END = r"\nwnotused{name}\nwendcode{}\nwbegindocs{3}\nwdocspar"


def chunk(k, n=5, name="C"):
    "A native chunk."
    return "\n".join([HEADER] + [rf"code{i}\label{{{name}{i}X{k}}}" for i in range(1, n + 1)]
                     + [END])


def wovenchunk(k, n=5):
    "A chunk with its code set by a list of fancyvrb, as the minted weave gives."
    return "\n".join([HEADER, verbatim(k, n), END])


def pair(k):
    "Code side by side: unbreakable, and it decides at its end."
    return "\n".join([r"\begin{didacticpair}{2}",
                      rf"\rule{{1pt}}{{8\baselineskip}}C1\label{{C1X{k}}} & right",
                      r"\end{didacticpair}"])


def heading(k):
    # Unnumbered, as an old-style 3 in a number has a depth that shifts the page.
    return rf"\section*{{Head}}\label{{HX{k}}}"


def runin(k):
    "A run-in heading: the title is set with what comes next, and the label with it."
    return rf"\paragraph*{{Head\label{{HX{k}}}}}"


def block(k, env="example"):
    return rf"\begin{{{env}}}[Block\label{{BX{k}}}]"


def frame(k):
    return rf"\begin{{frame}}{{Head\label{{HX{k}}}}}"


TAIL = "\n\nAfter.\n"


def CW(k):
    return chunk(k, 2, "A") + "\n" + para(k, 1, "P") + "\n\n" + wovenchunk(k) + TAIL


CASES = {
    # heading + paragraphs, directly
    "s": lambda k: heading(k) + "\n" + para(k, 16) + TAIL,
    "ss": lambda k: heading(k) + rf"\subsection*{{Sub}}\label{{BX{k}}}" + "\n" + para(k, 16) + TAIL,
    "p": lambda k: heading(k) + "\n" + para(k, 1, "P") + "\n\n" + para(k, 16) + TAIL,
    # lists
    "pl": lambda k: heading(k) + "\n" + para(k, 1, "P") + "\n" + items(k, 8, 1) + TAIL,
    "pL": lambda k: heading(k) + "\n" + para(k, 1, "P") + "\n" + items(k, 5, 3) + TAIL,
    "l": lambda k: heading(k) + "\n" + items(k, 8, 1) + TAIL,
    "L": lambda k: heading(k) + "\n" + items(k, 5, 3) + TAIL,
    # tall boxes
    "t": lambda k: heading(k) + "\n" + r"\noindent\parbox{\linewidth}{\rule{0pt}{10\baselineskip}"
        + rf"T1\label{{T1X{k}}}" + "}\\par\n" + para(k, 16) + TAIL,
    "c": lambda k: heading(k) + "\n" + r"\begin{center}\parbox{.8\linewidth}{\rule{0pt}{10\baselineskip}"
        + rf"T1\label{{T1X{k}}}" + r"}\end{center}" + "\n" + para(k, 16) + TAIL,
    # a lead-in and a listing, with and without a heading
    "hv1": lambda k: heading(k) + "\n" + para(k, 1, "P") + "\n\n" + verbatim(k) + TAIL,
    "hv2": lambda k: heading(k) + "\n" + para(k, 2, "P") + "\n\n" + verbatim(k) + TAIL,
    "hv3": lambda k: heading(k) + "\n" + para(k, 3, "P") + "\n\n" + verbatim(k) + TAIL,
    "v1": lambda k: para(k, 1, "P") + "\n\n" + verbatim(k) + TAIL,
    "v3": lambda k: para(k, 3, "P") + "\n\n" + verbatim(k) + TAIL,
    "v8": lambda k: para(k, 1, "P") + "\n\n" + verbatim(k, 8) + TAIL,
    "hn1": lambda k: heading(k) + "\n" + para(k, 1, "P") + "\n\n" + chunk(k) + TAIL,
    "hn3": lambda k: heading(k) + "\n" + para(k, 3, "P") + "\n\n" + chunk(k) + TAIL,
    "n3": lambda k: para(k, 3, "P") + "\n\n" + chunk(k) + TAIL,
    # a lead-in after a chunk: the glue between them goes if the page breaks there.
    # Five of them, a tenth of a line apart (OFFSET), to hit the limit within that glue.
    "cw0": CW, "cw1": CW, "cw2": CW, "cw3": CW, "cw4": CW,
    "n6": lambda k: para(k, 6, "P") + "\n\n" + chunk(k) + TAIL,
    "hw1": lambda k: heading(k) + "\n" + para(k, 1, "P") + "\n\n" + wovenchunk(k) + TAIL,
    "hw3": lambda k: heading(k) + "\n" + para(k, 3, "P") + "\n\n" + wovenchunk(k) + TAIL,
    "w3": lambda k: para(k, 3, "P") + "\n\n" + wovenchunk(k) + TAIL,
    # longer than keeplines: it may break, and if it starts the next page it warns too
    "wL1": lambda k: para(k, 1, "P") + "\n\n" + wovenchunk(k, 15) + TAIL,
    "w6": lambda k: para(k, 6, "P") + "\n\n" + wovenchunk(k) + TAIL,
    "v6": lambda k: para(k, 6, "P") + "\n\n" + verbatim(k) + TAIL,
    # code side by side, with didactic only
    "hj1": lambda k: heading(k) + "\n" + para(k, 1, "P") + "\n\n" + pair(k) + TAIL,
    "j3": lambda k: para(k, 3, "P") + "\n\n" + pair(k) + TAIL,
    # a listing right under a heading
    "hv": lambda k: heading(k) + "\n" + verbatim(k) + TAIL,
    "hw": lambda k: heading(k) + "\n" + wovenchunk(k) + TAIL,
    "hn": lambda k: heading(k) + "\n" + chunk(k) + TAIL,
    "hv8": lambda k: heading(k) + "\n" + verbatim(k, 8) + TAIL,
    "hv3l": lambda k: heading(k) + "\n" + verbatim(k, 3) + TAIL,
    # L1: a list stays with what leads into it
    "ll1": lambda k: para(k, 1, "P") + "\n" + items(k, 8, 1) + TAIL,
    "ll2": lambda k: para(k, 2, "P") + "\n" + items(k, 8, 1) + TAIL,
    "ll3": lambda k: para(k, 3, "P") + "\n" + items(k, 8, 1) + TAIL,
    "ll6": lambda k: para(k, 6, "P") + "\n" + items(k, 8, 1) + TAIL,
    "lL1": lambda k: para(k, 1, "P") + "\n" + items(k, 5, 3) + TAIL,
    "lL3": lambda k: para(k, 3, "P") + "\n" + items(k, 5, 3) + TAIL,
    "lE2": lambda k: para(k, 2, "P") + "\n" + listof(k, "enumerate", 8, 1) + TAIL,
    "lD2": lambda k: para(k, 2, "P") + "\n" + listof(k, "description", 8, 1) + TAIL,
    "nN2": lambda k: nested(k, 2) + TAIL,
    "nN3": lambda k: nested(k, 3) + TAIL,
    "fl1": lambda k: frame(k) + "\n" + para(k, 1, "P") + "\n" + items(k, 8, 1) + r"\end{frame}" + TAIL,
    "fl3": lambda k: frame(k) + "\n" + para(k, 3, "P") + "\n" + items(k, 8, 1) + r"\end{frame}" + TAIL,
    "qq3": lambda k: para(k, 3, "P") + "\n" + r"\begin{quote}" + para(k, 8, "Q") + r"\end{quote}" + TAIL,
    # a heading with a figure that lands right here
    "f": lambda k: heading(k) + "\n" + r"\begin{figure}[h]\rule{1pt}{2\baselineskip}\end{figure}"
        + "\n" + para(k, 16) + TAIL,
    # run-in headings, alone and over what puts them on a line of their own
    "r": lambda k: runin(k) + "\n" + para(k, 16) + TAIL,
    "rr": lambda k: runin(k) + rf"\subparagraph*{{Sub\label{{BX{k}}}}}" + "\n" + para(k, 16) + TAIL,
    "ri": lambda k: runin(k) + "\n" + items(k, 8, 1) + TAIL,
    "re": lambda k: runin(k) + "\n" + block(k) + para(k, 16) + r"\end{example}" + TAIL,
    "rv": lambda k: runin(k) + "\n" + verbatim(k) + TAIL,
    "fp": lambda k: frame(k) + "\n" + para(k, 16) + r"\end{frame}" + TAIL,
    "fe": lambda k: frame(k) + "\n" + block(k) + para(k, 16) + r"\end{example}\end{frame}" + TAIL,
    "fx": lambda k: frame(k) + "\n" + block(k, "exercise") + para(k, 16) + r"\end{exercise}\end{frame}" + TAIL,
    "fi": lambda k: frame(k) + "\n" + items(k, 8, 1) + r"\end{frame}" + TAIL,
    "fI": lambda k: frame(k) + "\n" + items(k, 5, 3) + r"\end{frame}" + TAIL,
    # blocks: the heading runs in at the first line, or is alone over a list
    "e": lambda k: rf"\begin{{example}}[Head\label{{HX{k}}}]" + para(k, 16) + r"\end{example}" + TAIL,
    "ei": lambda k: rf"\begin{{example}}[Head\label{{HX{k}}}]" + items(k, 8, 1) + r"\end{example}" + TAIL,
    "eI": lambda k: rf"\begin{{example}}[Head\label{{HX{k}}}]" + items(k, 5, 3) + r"\end{example}" + TAIL,
    "se": lambda k: heading(k) + "\n" + block(k) + para(k, 16) + r"\end{example}" + TAIL,
    # a block of one line: it has no more lines to give
    "e1": lambda k: rf"\begin{{example}}[Head\label{{HX{k}}}]" + para(k, 1) + r"\end{example}"
        + "\n\n" + para(k, 16, "N") + TAIL,
    # a display as the first thing: its lines are lines under the heading
    "d": lambda k: heading(k) + "\n" + r"\[ x = \frac{a}{b} \]" + "\n" + para(k, 16) + TAIL,
    # a tall box in a center, which is one line for TeX, and then a paragraph: no more is due
    "cp": lambda k: heading(k) + "\n" + r"\begin{center}\parbox{.8\linewidth}{\rule{0pt}{3\baselineskip}"
        + rf"T1\label{{T1X{k}}}" + r"}\end{center}" + "\n" + para(k, 16, "N") + TAIL,
}
FINE = {"ll1", "ll2", "ll3", "ll6", "lL1", "lL3", "lE2", "lD2", "nN2", "nN3", "fl1", "fl3", "qq3",
        "d", "wL1", "hv", "hw", "hn", "hv8", "hv3l", "f", "r", "rr", "ri", "re", "rv", "fp", "fe", "fx", "fi", "fI",
        "e", "ei", "eI", "se", "e1", "cp"}
# Without didactic these don't exist, or frames set their titles another way.
DIDACTIC_ONLY = {"hj1", "j3", "fp", "fe", "fx", "fi", "fI", "fl1", "fl3"}
# What comes under a block's heading isn't compared with plain: its style is didactic's.
NOT_COMPARED = DIDACTIC_ONLY | {"e", "ei", "eI", "se", "e1", "cp", "f"}
LISTINGS = {"hv1", "hv2", "hv3", "v1", "v3", "v8", "hn1", "hn3", "n3", "hw1", "hw3", "w3",
            "hj1", "j3", "n6", "w6", "v6", "wL1", "cw0", "cw1", "cw2", "cw3", "cw4",
            "ll1", "ll2", "ll3", "ll6", "lL1", "lL3", "lE2", "lD2", "nN2", "nN3", "fl1", "fl3"}
ITEMLISTS = {"ll1", "ll2", "ll3", "ll6", "lL1", "lL3", "lE2", "lD2", "nN2", "nN3", "fl1", "fl3"}
# L2: a list right under a heading follows LaTeX, so a line is enough.
DIRECTLISTS = {"l", "L", "ri", "fi", "fI", "ei", "eI"}
NOHEADING = {"v1", "v3", "v8", "n3", "w3", "j3", "n6", "w6", "v6", "wL1",
             "ll1", "ll2", "ll3", "ll6", "lL1", "lL3", "lE2", "lD2", "nN2", "nN3", "qq3",
             "cw0", "cw1", "cw2", "cw3", "cw4"}
AFTERCHUNK = {"cw0", "cw1", "cw2", "cw3", "cw4"}
# Enough to test lists under enumitem.
ENUMITEM_CASES = ITEMLISTS | {"l", "L", "pl", "pL"}


def all_cases(variant="m"):
    for name in CASES:
        if variant[0] == "e" and name not in ENUMITEM_CASES:
            continue
        for r in (FINEROOMS if name in FINE else ROOMS):
            yield name, f"{name}Q{int(4 * r)}", r


def gen(variant):
    out = [VARIANTS[variant], r"\makeatletter", r"""\AtBeginDocument{%
  \output\expandafter{\expandafter\sweepmeasure\the\output}}
\newcommand\sweepmeasure{%
  \ifnum\outputpenalty>-10001
    {\setbox0\vbox{\unvcopy255}%
     \typeout{PAGE \the\c@page\space\the\ht255\space
       \the\dimexpr\ht0+\dp0\relax\space\the\baselineskip}}%
  \fi}
\newcommand\roomfor[3]{%
  \clearpage\typeout{CASE #1}%
  \noindent\mbox{}R\label{RX#1}\par
  \vspace*{\dimexpr\pagegoal-\pagetotal-#2\baselineskip-2\baselineskip\relax}\par
  \noindent A line above, that a page can end after.\par
  \noindent And another, as what is kept with a listing can be the one before.\par
  \typeout{ROOM #1 \the\dimexpr\pagegoal-\pagetotal-\pagedepth\relax\space\the\baselineskip}}""",
           r"\makeatother", r"\begin{document}"]
    for name, k, r in all_cases(variant):
        out.append(f"% CASE {k}")
        extra = int(name[-1]) / 10 if name in AFTERCHUNK else 0
        out.append(rf"\roomfor{{{k}}}{{{r + extra:g}}}{{}}")
        if variant.endswith("p") and name in DIDACTIC_ONLY:
            continue
        out.append(CASES[name](k))
    out += [r"\clearpage\typeout{CASE END}", r"\end{document}"]
    print("\n".join(out))


def pages(base):
    with open(base + ".aux", errors="replace") as f:
        aux = f.read()
    return {m[1]: int(m[2]) for m in
            re.finditer(r"\\newlabel\{([^}]*)\}\{\{[^}]*\}\{(\d+)\}", aux)}


def log_text(base):
    """The log, with the lines that TeX wraps at 79 characters joined."""
    out = []
    with open(base + ".log", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if out and len(out[-1]) % 79 == 0 and out[-1] \
                    and not line.startswith("(didactic)"):
                out[-1] = out[-1] + line
                continue
            out.append(line)
    return "\n".join(out)


def case_lines(base):
    """Map the lines of the document to its cases."""
    where = {}
    case = None
    with open(base + ".tex") as f:
        for i, line in enumerate(f, 1):
            m = re.match(r"% CASE (\S+)", line)
            if m:
                case = m[1]
            where[i] = case
    return where


class Pages:
    "What a run of a variant did: pages, rooms and warnings per case."

    def __init__(self, variant):
        base = f"test-keep-sweep-{variant}"
        self.page = pages(base)
        log = log_text(base)
        lines = case_lines(base)
        self.room = {m[1]: float(m[2]) / float(m[3]) for m in re.finditer(
            r"^ROOM (\S+) ([\d.]+)pt ([\d.]+)pt", log, re.M)}
        self.empty = {int(m[1]): (float(m[2]) - float(m[3])) / float(m[4]) for m in re.finditer(
            r"^PAGE (\d+) ([\d.]+)pt\s*([\d.]+)pt\s*([\d.]+)pt", log, re.M)}
        self.warn = {}
        for m in re.finditer(
                r"Package didactic Warning: (.*(?:\n\(didactic\).*)*)", log):
            text = re.sub(r"\n\(didactic\)\s*", " ", m[1])
            n = re.search(r"on input line (\d+)|(?:,| at) line (\d+)", text)
            if not n:
                self.warn.setdefault(None, []).append(text)
                continue
            case = lines.get(int(n[1] or n[2]))
            self.warn.setdefault(case, []).append(text)

    def on(self, label, case):
        return self.page.get(f"{label}X{case}")

    def lines_under(self, name, case):
        "How many lines that we label are on the page of the heading."
        h = self.on("H", case)
        names = [lab for lab in self.page if lab.endswith("X" + case)
                 and re.match(r"(P|L|I\d+x|C|T)\d+X", lab)]
        count = sum(1 for lab in names if self.page[lab] == h)
        if name[:2] in ("hn", "hw") and self.on("C1", case) == h:
            count += 1  # the header of the chunk
        return count


FAILS = []


def fail(case, text):
    FAILS.append(f"FAIL {case}: {text}")


def check_case(p, ref, name, case, K):
    warns = p.warn.get(case, [])
    room = p.room.get(case)
    if room is None:
        fail(case, "no room in the log")
        return
    over = room > LIMIT + 0.01
    r = p.on("R", case)
    if name not in NOHEADING:
        h = p.on("H", case)
        if h is None:
            fail(case, "no heading in the .aux")
            return
        # D2
        first = None
        for lab in ("T1", "P1", "L1", "I0x1", "C1"):
            if p.on(lab, case) is not None:
                first = p.on(lab, case)
                break
        if first != h and not (name == "f" and warns) and name != "d":
            fail(case, f"D2: heading on {h}, first line on {first}")
        if p.on("B", case) is not None and p.on("B", case) != first:
            fail(case, f"D2: inner heading on {p.on('B', case)}, first line on {first}")
        moved = h > r
        says_moved = [w for w in warns if "it moves to the next page" in w]
        # D8: a move past the limit warns, and only that does.
        if moved and over and not says_moved:
            fail(case, f"D8: heading moved at room {room:.1f}, no warning")
        if says_moved and not (moved and over):
            fail(case, f"D8: says it moves, moved={moved}, room {room:.1f}")
        # D8: only n of its lines
        count = p.lines_under(name, case)
        for w in warns:
            m = re.search(r"only (\d+) lines? follows? it", w)
            if m and name not in ("t", "c", "cp", "hj1") and (moved or int(m[1]) != count):
                fail(case, f"D8: says only {m[1]} lines, {count} there, moved={moved}")
            m = re.search(r"Only (\d+) of the", w)
            if m and K <= 2:
                fail(case, f"D8: {w}")
            if m and name in ("s", "ss") and int(m[1]) != count:
                fail(case, f"D8: says only {m[1]} fit, {count} there")
        # R9: past the limit a short listing breaks under its heading, and says so
        if name in ("hv", "hw", "hv8") and over and not moved:
            last = p.on("C8" if name == "hv8" else "C5", case)
            says_breaks = [w for w in warns if "breaks under" in w]
            if p.on("C1", case) == h and last > h and not says_breaks:
                fail(case, "D8: a short listing breaks under its heading, no warning")
            if says_breaks and last == h:
                fail(case, "D8: says it breaks, and it doesn't")
        tall = name in ("t", "c", "hj1", "cp", "d")
        if name == "cp" and K <= 2 and [w for w in warns if "only" in w]:
            fail(case, f"D8: a tall box is lines enough: {warns[0][:50]}")
        if name == "e1" and [w for w in warns if "only" in w]:
            fail(case, f"D8: a block of one line has no more to give: {warns[0][:50]}")
        if name in ("p", "pl", "l") and not moved and count < K and room <= LIMIT - 0.01 \
                and (name == "p"):
            fail(case, f"D1: {count} lines under the heading within the limit")
        if not moved and not tall and name != "e1" and count < K and not warns \
                and name not in ("hv", "hw", "hn", "hv8", "hv3l", "rv") \
                and name not in DIRECTLISTS:
            fail(case, f"D8: {count} lines under the heading, no warning")
        # D4: never fewer than plain LaTeX
        # A lead-in and a listing are left out: the listing is kept whole by
        # keeplines, which plain LaTeX has no idea of, so it has fewer lines by design.
        if ref is not None and name not in LISTINGS and name not in NOT_COMPARED \
                and ref.on("H", case) is not None:
            pm = ref.on("H", case) > ref.on("R", case)
            pc = ref.lines_under(name, case)
            if name in ("hw", "hn"):
                pc -= 1     # the header of a chunk is no code line
            bad = False
            if not pm and not moved and count < pc and name not in ("hv", "hw", "hv8", "hv3l", "rv"):
                bad = True
                text = f"D4: {count} lines under the heading, plain LaTeX has {pc}"
            elif not pm and moved and pc >= K \
                    and name != "hv3l" \
                    and (over or name not in ("hv", "hw", "hv8", "rv")):
                # Within the limit a short listing moves whole: that is keeplines.
                # One of three lines can't have two on each side, so it always moves.
                bad = True
                text = f"D4: moved, plain LaTeX keeps {pc} lines"
            elif pm and not moved and count < 2 and name in ("s", "ss", "L"):
                bad = True
                text = f"D4: {count} line under the heading, plain LaTeX moves it"
            if bad:
                fail(case, text)
    # L1 leaves the breaks between items alone, and other lists than item lists
    if name == "qq3" and p.on("Q1", case) is not None and ref.on("Q1", case) is not None \
            and (p.on("Q1", case) - p.on("R", case)) != (ref.on("Q1", case) - ref.on("R", case)) \
            and p.on("P3", case) == p.on("R", case) and ref.on("P3", case) == ref.on("R", case):
        fail(case, "L1: a quote is no item list, and breaks as plain LaTeX")
    # D6
    if name in LISTINGS:
        lead_first = p.on("P1", case)
        n = 1 if name == "v8" or name in AFTERCHUNK or name == "wL1" else int(name[-1])
        lead_last = p.on(f"P{n}", case)
        code = p.on("I0x1" if name in ITEMLISTS else "C1", case)
        parted = lead_last < code
        says = [w for w in warns if "goes to the next page" in w]
        if parted and not says:
            fail(case, f"D6: lead-in on {lead_last}, code on {code}, no warning")
        if name in AFTERCHUNK and p.on("A1", case) > r:
            return  # the first chunk moved, and what warns is about that
        if says and code <= r:
            fail(case, f"D8: {says[0][:50]}, but it stays")
        moving = n if n <= 3 else 2
        if parted and room - n + moving <= LIMIT - 0.3 and name in NOHEADING | {"fl1", "fl3"} \
                and name not in AFTERCHUNK:
            fail(case, f"D6: parted at room {room:.1f}, within the limit")
        if name in NOHEADING and lead_first > r and over and name not in AFTERCHUNK:
            fail(case, f"D6: lead-in moved at room {room:.1f}")
        if name in NOHEADING and lead_first > r and p.empty.get(r, 0) > LIMIT + 0.01:
            fail(case, f"D6: lead-in moved, {p.empty[r]:.1f} lines empty")
        if name in NOHEADING and lead_first == r and lead_last > r and name not in AFTERCHUNK:
            stay = sum(1 for i in range(1, n + 1) if p.on(f"P{i}", case) == r)
            if room - stay > LIMIT + 0.01:
                fail(case, f"D6: lead-in parted, {stay} lines stay at room {room:.1f}")


def check(variant):
    p = Pages(variant)
    ref = Pages(variant[0] + "p")
    K = 3 if variant.endswith("3") else 2
    n = 0
    for name, case, r in all_cases(variant):
        n += 1
        check_case(p, ref, name, case, K)
    # keepends: a listing that breaks leaves two lines at each end
    twos = sum(1 for name, case, r in all_cases(variant) if name == "wL1"
               and p.on("C2", case) == p.on("R", case) and p.on("C3", case) != p.on("R", case))
    if variant[0] != "e" and not twos:
        print("FAIL: no listing of 15 lines breaks after two")
        FAILS.append("keepends")
    for line in FAILS:
        print(line)
    for w in p.warn.get(None, []):
        print("FAIL: a warning with no place:", w)
        FAILS.append(w)
    want = sum(1 for _ in all_cases(variant))
    if n != want or not p.page:
        print(f"FAIL: {n} cases of {want}")
        return 1
    print(f"{variant}: {n} cases, {len(FAILS)} failed")
    return 1 if FAILS else 0


if __name__ == "__main__":
    if sys.argv[1] == "gen":
        gen(sys.argv[2])
    elif sys.argv[1] == "check":
        sys.exit(check(sys.argv[2]))
    else:
        sys.exit(__doc__)
