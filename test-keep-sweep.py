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
      Unless plain LaTeX does it by leaving a last line alone at the top of the next
      page, which the widow penalty of 10000 forbids, or with a first line alone at
      the foot, at a cost lower than our 1000 (article's own club penalty is 150).
  D6  A listing's lead-in goes along only within keepmaxgap; parted, there's a warning.
      What it leaves empty on the page is the room less the lines that stay.
  D8  Every warning says what the page does, and no move past the limit is silent:
      a heading that moves with more room than the limit warns, and no other does;
      "only n of its lines" is the number of lines on the page; a listing that
      "starts the next page" does.
"""
import re
import sys

LIMIT = 5.0     # keepmaxgap, default
ROOMS = [q / 2 for q in range(2, 29)]

MIMIC = (r"\usepackage[T1]{fontenc}\usepackage[osf,sc]{mathpazo}"
         r"\usepackage[scaled=0.90]{helvet}\usepackage[scaled=0.85]{beramono}"
         r"\setlrmarginsandblock{23mm}{60.2mm}{*}"
         r"\setulmarginsandblock{30mm}{48.5mm}{*}\checkandfixthelayout"
         r"\setsecnumdepth{subsection}\nouppercaseheads")
MEMOIR = r"\documentclass[a4paper,10pt,oneside,oldfontcommands]{memoir}"
ARTICLE = r"\documentclass[a4paper,10pt]{article}"
NOWEB = r"\usepackage{noweb}"
BREAKCODE = r"\noweboptions{breakcode}"
DIDACTIC = r"\usepackage[marginparmargin=outer]{didactic}"
SLOPPY = r"\setlength{\topskip}{1.6\topskip}\checkandfixthelayout\sloppybottom"
VARIANTS = {
    "m": MEMOIR + NOWEB + DIDACTIC + BREAKCODE,
    "mp": MEMOIR + MIMIC + NOWEB + BREAKCODE + r"\usepackage{fancyvrb}",
    "a": ARTICLE + NOWEB + DIDACTIC + BREAKCODE,
    "ap": ARTICLE + NOWEB + BREAKCODE + r"\usepackage{fancyvrb}",
    "s": MEMOIR + NOWEB + DIDACTIC + BREAKCODE + SLOPPY,
    "sp": MEMOIR + MIMIC + NOWEB + BREAKCODE + r"\usepackage{fancyvrb}" + SLOPPY,
    "s3": MEMOIR + NOWEB + DIDACTIC.replace("outer", "outer,keepafterheading=3")
          + BREAKCODE + SLOPPY,
}

def para(k, n, name="L"):
    """A paragraph of n lines, each with a label."""
    return "\\\\\n".join(rf"{name}{i}\label{{{name}{i}X{k}}}" for i in range(1, n + 1))


def items(k, n, lines):
    out = [r"\begin{itemize}"]
    for i in range(n):
        out.append(r"\item " + para(k, lines, f"I{i}x"))
    out.append(r"\end{itemize}")
    return "\n".join(out)


def verbatim(k, n=5):
    return "\n".join([r"\begin{Verbatim}[commandchars=\\\{\}]"]
                     + [rf"code{i}\label{{C{i}X{k}}}" for i in range(1, n + 1)]
                     + [r"\end{Verbatim}"])


HEADER = r"\nwenddocs{}\nwbegincode{2}\moddef{name}\endmoddef\nwstartdeflinemarkup\nwenddeflinemarkup"
END = r"\nwnotused{name}\nwendcode{}\nwbegindocs{3}\nwdocspar"


def chunk(k):
    "A native chunk."
    return "\n".join([HEADER] + [rf"code{i}\label{{C{i}X{k}}}" for i in range(1, 6)] + [END])


def wovenchunk(k):
    "A chunk with its code set by a list of fancyvrb, as the minted weave gives."
    return "\n".join([HEADER, verbatim(k), END])


def pair(k):
    "Code side by side: unbreakable, and it decides at its end."
    return "\n".join([r"\begin{didacticpair}{2}",
                      rf"\rule{{1pt}}{{8\baselineskip}}C1\label{{C1X{k}}} & right",
                      r"\end{didacticpair}"])


def heading(k):
    return rf"\section{{Head}}\label{{HX{k}}}"


TAIL = "\n\nAfter.\n"
CASES = {
    # heading + paragraphs, directly
    "s": lambda k: heading(k) + "\n" + para(k, 16) + TAIL,
    "ss": lambda k: heading(k) + rf"\subsection{{Sub}}\label{{BX{k}}}" + "\n" + para(k, 16) + TAIL,
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
    "hw1": lambda k: heading(k) + "\n" + para(k, 1, "P") + "\n\n" + wovenchunk(k) + TAIL,
    "hw3": lambda k: heading(k) + "\n" + para(k, 3, "P") + "\n\n" + wovenchunk(k) + TAIL,
    "w3": lambda k: para(k, 3, "P") + "\n\n" + wovenchunk(k) + TAIL,
    # code side by side, with didactic only
    "hj1": lambda k: heading(k) + "\n" + para(k, 1, "P") + "\n\n" + pair(k) + TAIL,
    "j3": lambda k: para(k, 3, "P") + "\n\n" + pair(k) + TAIL,
    # a listing right under a heading
    "hv": lambda k: heading(k) + "\n" + verbatim(k) + TAIL,
    "hw": lambda k: heading(k) + "\n" + wovenchunk(k) + TAIL,
}
LISTINGS = {"hv1", "hv2", "hv3", "v1", "v3", "v8", "hn1", "hn3", "n3", "hw1", "hw3", "w3",
            "hj1", "j3"}
NOHEADING = {"v1", "v3", "v8", "n3", "w3", "j3"}


def gen(variant):
    out = [VARIANTS[variant], r"\makeatletter", r"""\newcommand\roomfor[3]{%
  \clearpage\typeout{CASE #1}%
  \noindent\mbox{}R\label{RX#1}\par
  \vspace*{\dimexpr\pagegoal-\pagetotal-#2\baselineskip\relax}\par
  \typeout{ROOM #1 \the\dimexpr\pagegoal-\pagetotal\relax\space\the\baselineskip}}""",
           r"\makeatother", r"\begin{document}"]
    for name, body in CASES.items():
        for r in ROOMS:
            k = f"{name}Q{int(2 * r)}"
            out.append(f"% CASE {k}")
            out.append(rf"\roomfor{{{k}}}{{{r:g}}}{{}}")
            if variant.endswith("p") and name in ("hj1", "j3"):
                continue    # no such thing without didactic
            out.append(body(k))
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
        self.warn = {}
        for m in re.finditer(
                r"Package didactic Warning: (.*(?:\n\(didactic\).*)*)", log):
            text = re.sub(r"\n\(didactic\)\s*", " ", m[1])
            n = re.search(r"on input line (\d+)|, line (\d+)", text)
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


    def widow(self, case):
        "Does a paragraph of this case leave its last line alone on the next page?"
        for lab, page in self.page.items():
            m = re.fullmatch(r"(.*?)(\d+)X" + case, lab)
            if m and int(m[2]) > 1:
                before = self.page.get(f"{m[1]}{int(m[2]) - 1}X{case}")
                after = self.page.get(f"{m[1]}{int(m[2]) + 1}X{case}")
                if after is None and before is not None and before < page:
                    return True
        return False


    def club(self, case):
        "Does a paragraph of this case leave its first line alone on the page?"
        for lab, page in self.page.items():
            m = re.fullmatch(r"(.*?)1X" + case, lab)
            if m:
                after = self.page.get(f"{m[1]}2X{case}")
                if after is not None and after > page:
                    return True
        return False


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
        if first != h:
            fail(case, f"D2: heading on {h}, first line on {first}")
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
            m = re.search(r"only (\d+) of its lines", w)
            if m and (moved or int(m[1]) != count):
                fail(case, f"D8: says only {m[1]} lines, {count} there, moved={moved}")
            m = re.search(r"Only (\d+) of the", w)
            if m and K <= 2:
                fail(case, f"D8: {w}")
            if m and name in ("s", "ss") and int(m[1]) != count:
                fail(case, f"D8: says only {m[1]} fit, {count} there")
        tall = name in ("t", "c", "hj1")
        if not moved and not tall and count < K and not warns and name not in ("hv", "hw"):
            fail(case, f"D8: {count} lines under the heading, no warning")
        # D4: never fewer than plain LaTeX
        if ref is not None and name not in LISTINGS and not name.startswith("h"):
            pm = ref.on("H", case) > ref.on("R", case)
            pc = ref.lines_under(name, case)
            bad = False
            if not pm and not moved and count < pc:
                bad = True
                text = f"D4: {count} lines under the heading, plain LaTeX has {pc}"
            elif not pm and moved and pc >= K:
                bad = True
                text = f"D4: moved, plain LaTeX keeps {pc} lines"
            elif pm and not moved and count < 2 and name in ("s", "ss", "L"):
                bad = True
                text = f"D4: {count} line under the heading, plain LaTeX moves it"
            if bad and not ref.widow(case) and not ref.club(case):
                fail(case, text)
    # D6
    if name in LISTINGS:
        lead_first = p.on("P1", case)
        n = 1 if name == "v8" else int(name[-1])
        lead_last = p.on(f"P{n}", case)
        code = p.on("C1", case)
        parted = lead_last < code
        says = [w for w in warns if "starts the next page" in w
                or "can't break here" in w]
        if parted and not says:
            fail(case, f"D6: lead-in on {lead_last}, code on {code}, no warning")
        if says and not parted:
            fail(case, f"D8: {says[0][:50]}, but the lead-in is with the code")
        if parted and room <= LIMIT - n and name in NOHEADING:
            fail(case, f"D6: parted at room {room:.1f}, within the limit")
        if name in NOHEADING and lead_first > r and over:
            fail(case, f"D6: lead-in moved at room {room:.1f}")
        if name in NOHEADING and lead_first == r and lead_last > r:
            stay = sum(1 for i in range(1, n + 1) if p.on(f"P{i}", case) == r)
            if room - stay > LIMIT + 0.01:
                fail(case, f"D6: lead-in parted, {stay} lines stay at room {room:.1f}")


def check(variant):
    p = Pages(variant)
    ref = Pages(variant[0] + "p")
    K = 3 if variant.endswith("3") else 2
    n = 0
    for name in CASES:
        for r in ROOMS:
            case = f"{name}Q{int(2 * r)}"
            n += 1
            check_case(p, ref, name, case, K)
    for line in FAILS:
        print(line)
    for w in p.warn.get(None, []):
        print("FAIL: a warning with no place:", w)
        FAILS.append(w)
    want = len(CASES) * len(ROOMS)
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
