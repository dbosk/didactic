#!/usr/bin/env python3
"""Checks on the test PDFs, so that a wrong layout fails `make`.

Building a test only shows that LaTeX didn't stop.  The expectations in the
headers of the test files are checked here instead, from the words and their
positions in the PDF (pdftotext -bbox, pdfinfo) and from the log.  Any engine
will do.

    python3 test-check.py test-marginfloat test-marginfloat-slides

prints a PASS or FAIL line per check and exits non-zero if a check fails, if a
test is unknown, or if a test ran no check at all.  A missing PDF or a missing
pdftotext is an exception, which also exits non-zero.
"""
import html
import re
import subprocess
import sys


class Check:
    """One test: its PDF, its log and the checks that have run on them."""

    def __init__(self, name):
        self.name = name
        self.checks = self.failed = 0
        out = subprocess.run(
            ["pdftotext", "-bbox", name + ".pdf", "-"],
            check=True, capture_output=True, text=True).stdout
        self.pages = []
        for page in re.findall(r"<page .*?</page>", out, re.S):
            self.pages.append([
                {"text": html.unescape(t), "page": len(self.pages) + 1,
                 "xmin": float(a), "ymin": float(b),
                 "xmax": float(c), "ymax": float(d)}
                for a, b, c, d, t in re.findall(
                    r'<word xMin="([\d.]+)" yMin="([\d.]+)" '
                    r'xMax="([\d.]+)" yMax="([\d.]+)">(.*?)</word>', page)])
        with open(name + ".log", encoding="latin-1") as log:
            # TeX folds log lines at 79 columns; unfold them for greps.
            self.log = re.sub(r"(?m)^(.{79})\n", r"\1", log.read())

    def ok(self, condition, what):
        self.checks += 1
        self.failed += not condition
        print(f"{'PASS' if condition else 'FAIL'} {self.name}: {what}")
        return condition

    def words(self, start):
        """All the words that start with start: names may carry punctuation."""
        return [w for p in self.pages for w in p if w["text"].startswith(start)]

    def one(self, start):
        """The one word that starts with start; a dummy, failing, otherwise."""
        found = self.words(start)
        if len(found) == 1:
            return found[0]
        self.ok(False, f"{start} occurs once, not {len(found)} times")
        return {"text": start, "page": 0, "xmin": -1e4, "ymin": -1e4,
                "xmax": -1e4, "ymax": -1e4}

    def absent(self, start):
        self.ok(not self.words(start), f"{start} is not in the PDF")

    def num_pages(self, n):
        self.ok(len(self.pages) == n, f"{n} page(s), has {len(self.pages)}")

    def order_warnings(self):
        """The warnings from didactic about the order of float numbers, as
        (counter, number, page, counter's other number, other page)."""
        return re.findall(
            r"Package didactic Warning: (\S+) (\S+) on page (\S+) comes after "
            r"\S+ (\S+) on page (\S+):", self.log)

    def clean_log(self, order=()):
        """No errors, undefined references or requests for another run, and no
        warnings about the order of float numbers but the expected ones."""
        found = self.order_warnings()
        self.ok(found == list(order),
                f"warnings about the order: {found}, expected {list(order)}")
        for pattern in (r"^! ", r"Reference `.*' on page .* undefined",
                        r"There were undefined references",
                        r"Rerun to get", r"may have changed\. Rerun"):
            self.ok(not re.search(pattern, self.log, re.M),
                    f"log has no /{pattern}/")

    def in_log(self, pattern, expected=True):
        found = re.search(pattern, self.log) is not None
        self.ok(found == expected,
                f"log {'has' if expected else 'has no'} /{pattern}/")

    def same_line(self, a, b):
        return a["page"] == b["page"] and abs(a["ymin"] - b["ymin"]) < 2

    def line_of(self, word):
        """The words of word's line, left to right, up to the margin."""
        line = sorted((w for w in self.pages[word["page"] - 1]
                       if self.same_line(w, word)), key=lambda w: w["xmin"])
        i = line.index(word)
        start = end = i
        while start > 0 and self.gap(line[start - 1], line[start]) < 20:
            start -= 1
        while end + 1 < len(line) and self.gap(line[end], line[end + 1]) < 20:
            end += 1
        return line[start:end + 1]

    def has_text(self, text):
        """The words of text follow each other somewhere in the PDF."""
        want = text.split()
        for page in self.pages:
            got = [w["text"] for w in page]
            if any(got[i:i + len(want)] == want
                   for i in range(len(got) - len(want) + 1)):
                self.ok(True, f"has \"{text}\"")
                return
        self.ok(False, f"has \"{text}\"")

    def gap(self, a, b):
        return b["xmin"] - a["xmax"]

    def one_space(self, a, b):
        """a and b are on one line, one space apart like the rest of the line."""
        a, b = self.one(a), self.one(b)
        if not self.ok(self.same_line(a, b),
                       f"{a['text']} and {b['text']} are on one line"):
            return
        line = self.line_of(a)
        gaps = sorted(self.gap(x, y) for x, y in zip(line, line[1:])
                      if x is not a)
        if not self.ok(len(gaps) >= 2, f"{a['text']}'s line has spaces to compare"):
            return
        space = gaps[len(gaps) // 2]
        self.ok(abs(self.gap(a, b) - space) < 0.5,
                f"{a['text']} {b['text']}: gap {self.gap(a, b):.2f}pt, "
                f"a space on that line is {space:.2f}pt")

    def in_margin(self, word, text_word):
        """word is to the right of the text block that text_word is in."""
        word, text_word = self.one(word), self.one(text_word)
        self.ok(word["xmin"] > text_word["xmax"],
                f"{word['text']} is in the margin, beside {text_word['text']}")

    def above(self, a, b):
        """a comes before b: on an earlier page or higher on the same one."""
        a, b = self.one(a), self.one(b)
        self.ok((a["page"], a["ymin"]) < (b["page"], b["ymin"]) and
                not self.same_line(a, b),
                f"{a['text']} (p{a['page']}) is above {b['text']} (p{b['page']})")


def marginfloat(c):
    """test-marginfloat.tex; the numbers are those of its header."""
    c.num_pages(1)                                   # no \FloatBlock page break
    c.clean_log()
    # beamerarticle is loaded before didactic here, and titles still run in.
    c.ok(c.same_line(c.one("waits"), c.one("PENDINGANCHOR")),
         "the frame title runs in with PENDINGANCHOR")
    c.has_text("Figure 1: PENDINGCAP,")              # 1
    c.above("REFS", "PENDINGCAP")
    c.in_margin("beside", "PENDINGANCHOR")           # 2
    c.has_text("Figure 2: A picture beside its text.")
    c.above("NOTEABOVE", "beside")
    c.in_margin("MTABCAP", "SPACEA")                 # 3
    c.has_text("Table 1: MTABCAP,")
    cap, cell = c.words("Table")[-1], c.one("TABCELL")
    c.ok(0 <= cell["xmin"] - cap["xmin"] < 7,        # \tabcolsep, no more
         f"TABCELL is not indented: {cell['xmin'] - cap['xmin']:.1f}pt")
    c.one_space("SPACEA", "SPACEB")                  # 4
    c.has_text("REFS Figure 1, Figure 2 and Table 1.")  # 5


def marginfloat_slides(c):
    """test-marginfloat-slides.tex; the numbers are those of its header."""
    c.num_pages(4)
    c.clean_log()
    c.ok(c.one("PENDINGCAP")["page"] == 1, "PENDINGCAP is on slide 1")  # 1
    c.above("PENDINGANCHOR", "PENDINGCAP")
    c.ok(c.one("beside")["page"] == 2, "the figure is on slide 2")      # 2
    c.has_text("Figure: A picture beside its text.")
    c.ok(c.one("SPACEA")["page"] == 3, "the table is on slide 3")       # 3
    c.has_text("Table: MTABCAP,")
    c.above("SPACEA", "MTABCAP")
    c.above("MTABCAP", "TABCELL")
    c.above("TABCELL", "SPACEB")
    c.has_text("REFS Figure 1, Figure 2 and Table 1.")                  # 4


def marginfloat_cases(c):
    """test-marginfloat-cases.tex; the numbers are those of its header."""
    c.clean_log()
    def level(float_word, para_word):
        return c.one(float_word)["ymin"] - c.one(para_word)["ymin"]
    # 1  not raised: level with the paragraph, whatever the type of float
    for kind, para in (("OFFSETFIG", "PARAFIG"), ("OFFSETTAB", "PARATAB")):
        c.ok(0 <= level(kind, para) < 4,
             f"{kind} is level with {para}: {level(kind, para):.1f}pt")
    # 2  the optional argument still raises it, by 1.2ex
    c.ok(level("OFFSETARG", "PARAARG") < -1,
         f"[-1.2ex] raises OFFSETARG: {level('OFFSETARG', 'PARAARG'):.1f}pt")
    # 3  a space before the float, and none left over from an earlier \label
    c.one_space("GAPA", "GAPB")
    # 4  no space before the float, though a \label just left one: one space
    c.one_space("NOSPA", "NOSPB")
    # 5  a space before it, none after it
    c.one_space("BEFA", "BEFB")
    # 6  no space on either side: one word
    c.ok(len(c.words("JOINAJOINB")) == 1, "JOINA and JOINB make one word")


def marginfloat_beside(c):
    """test-marginfloat-order.tex, case 1."""
    c.clean_log(order=[("figure", "0.2", "2", "0.3", "1")])
    c.ok(c.one("MARGINAFTER")["page"] < c.one("ORDINARY")["page"],
         "the margin figure stays beside its text, before ORDINARY")
    c.in_margin("MARGINAFTER", "TEXTAFTER")


def marginfloat_inorder(c):
    """test-marginfloat-order.tex, case 2."""
    c.clean_log()
    c.above("ORDINARY", "MARGINAFTER")


def marginfloat_samepar(c):
    """test-marginfloat-samepar.tex."""
    c.clean_log(order=[("figure", "0.1", "2", "0.2", "1")])
    c.ok(c.one("MARGINAL")["page"] == 1, "the margin figure is on page 1")
    c.ok(c.one("ORDINARY")["page"] == 2, "the ordinary figure is on page 2")


def marginfloat_moved(c):
    """test-marginfloat-moved.tex."""
    c.clean_log(order=[("figure", "0.1", "2", "0.2", "1")])
    c.ok(c.one("MOVED")["page"] == 2, "marginfix moved MOVED to page 2")
    c.ok(c.one("STAYS")["page"] == 1, "STAYS is on page 1")


def marginfloat_chapters(c):
    """test-marginfloat-chapters.tex."""
    late, early = c.one("FIGLATE"), c.one("EARLY")
    c.ok(late["page"] > early["page"], "FIGLATE is on a later page than EARLY")
    c.clean_log(order=[("figure", "1.1", "2", "1.2", "1")])
    c.has_text("Figure 2.1: TWOA")
    with open(c.name + ".aux", encoding="latin-1") as aux:
        # Only floats are recorded: chapters go to the ToC and have counters too.
        records = aux.read()
    c.ok("floatrec{figure}" in records and "floatrec{chapter}" not in records,
         "the .aux records the figures and not the chapters")
    c.ok(c.one("TABLELATE")["page"] > c.one("TABMARGIN")["page"],
         "TABLELATE is on a later page than TABMARGIN")


def marginfloat_kinds(c):
    """test-marginfloat-kinds.tex."""
    found = c.order_warnings()
    c.ok(found == [("figure", "0.1", "2", "0.2", "1"),
                   ("listing", "1", "4", "2", "3"),
                   ("table", "0.1", "6", "0.2", "5")],
         f"warnings about the order: {found}")


def marginfloat_article(c):
    """test-marginfloat-article.tex."""
    found = c.order_warnings()
    c.ok(found == [("figure", "1", "2", "2", "1"),
                   ("floatone", "1", "4", "2", "3"),
                   ("table", "1", "6", "2", "5")],
         f"warnings about the order: {found}")


def marginfloat_include(c):
    """test-marginfloat-include.tex; the numbers are those of its header."""
    c.absent("AONE")                                 # the chapter is left out
    late, early = c.one("BLATE"), c.one("BEARLY")
    c.ok(late["page"] > early["page"], "BLATE is on a later page than BEARLY")
    c.clean_log(order=[("figure", "2.2", "7", "2.3", "6")])  # 1, 2


def marginfloat_include_all(c):
    """test-marginfloat-include-all.tex: all chapters, the same warning."""
    c.has_text("Figure 1.1: AONE")
    c.clean_log(order=[("figure", "2.2", "7", "2.3", "6")])


def warnings(c):
    """The warnings from didactic in the log, each on one line."""
    found = re.findall(r"Package didactic Warning: (.*?)\n\n", c.log, re.S)
    return [re.sub(r"\s*\n\(didactic\)\s+", " ", w) for w in found]


def keep_results(c, tag):
    """Which line each case is on, and the warnings naming a line."""
    return {n: int(l) for n, l in
            re.findall(tag + r" case (\w+) line (\d+)", c.log)}


def keep_leadin(c):
    """test-keep-leadin.tex: warnings against the pages of the labels."""
    lines = keep_results(c, "leadin")
    pages = {n: (int(a), int(b)) for n, a, b in re.findall(
        r"leadin result (\w+) lead=(\d+)\s+first=(\d+)", c.log)}
    c.ok(len(pages) >= 24 and set(pages) == set(lines),
         f"results for all cases: {sorted(set(pages) ^ set(lines))}, "
         f"{len(pages)} of them")
    # What is asked for, or isn't a lead-in: different pages, and no warning.
    asked = {"g", "x", "y", "t", "o"}
    # Cases where the lead-in and the first line must be parted; if a change of
    # layout parts them no more, the case tests nothing, and that should show.
    for n in (list("mnfhsbruljipw") + ["fr", "ee", "pc"]
              + (["k"] if "k" in pages else [])):
        c.ok(pages[n][0] < pages[n][1], f"case {n} is on two pages: {pages[n]}")
    for n in asked:
        c.ok(pages[n][0] < pages[n][1], f"case {n} is on two pages: {pages[n]}")
    for n in ("c", "a", "d", "q", "e", "z", "v", "qb", "fs", "hh", "vz"):
        c.ok(pages[n][0] == pages[n][1], f"case {n} is on one page: {pages[n]}")
    found = {}
    for w in warnings(c):
        if "apart from what leads" in w:
            m = re.search(r"starts page (\d+).*input line (\d+)", w)
            found[int(m.group(2))] = int(m.group(1))
    for n, line in sorted(lines.items()):
        parted = pages[n][0] < pages[n][1] and n not in asked
        c.ok((line in found) == parted,
             f"case {n}, line {line}, pages {pages[n]}: "
             f"{'a' if line in found else 'no'} warning")
        if parted and line in found:
            c.ok(found[line] == pages[n][1],
                 f"case {n} names page {found[line]}, it is on {pages[n][1]}")
    c.ok(not set(found) - set(lines.values()),
         f"no warning elsewhere: {sorted(set(found) - set(lines.values()))}")


def keep_leadin_off(c):
    """test-keep-leadin-off.tex: nothing of this from what was turned off."""
    pages = re.findall(r"leadin result (\w+) lead=(\d+)\s+first=(\d+)", c.log)
    c.ok(any(int(a) < int(b) for _, a, b in pages),
         "some lead-in and listing are on different pages")
    w = [w for w in warnings(c) if "apart from what leads" in w]
    c.ok(not w, f"no warning about a lead-in: {w}")


def keep_overfull(c):
    """test-keep-overfull.tex: the warning names the line and the full page."""
    lines = keep_results(c, "overfull")
    pages = {n: int(p) for n, p in
             re.findall(r"overfull result (\w+) page=(\d+)", c.log)}
    found = {}
    for w in warnings(c):
        if "doesn't fit" in w:
            m = re.search(r"page (\d+) is overfull.*input line (\d+)", w)
            c.ok(m, f"names a page and a line: {w}")
            if m:
                found[int(m.group(2))] = int(m.group(1))
    for n in "veltpf":
        c.ok(lines[n] in found, f"case {n}, line {lines[n]}, warns")
        c.ok(found.get(lines[n]) == pages[n],
             f"case {n} names page {found.get(lines[n])}, it is on {pages[n]}")
    c.ok(lines["c"] not in found, "the control doesn't warn")
    # A pair's page can run off the paper without TeX's message, so at least.
    n = len(re.findall(r"Overfull \\vbox", c.log))
    c.ok(n >= 4 and n <= len(found), f"{n} overfull pages, {len(found)} warnings")


def keep_twocol(c):
    """test-keep-twocol.tex; a page isn't shipped out after the first column."""
    lines = keep_results(c, "twocol")
    w = [x for x in warnings(c) if "apart from what leads" in x]
    c.ok(any(f"input line {lines['m']}" in x for x in w), f"case m warns: {w}")
    c.ok(not any(f"input line {lines['c']}" in x for x in w), "case c doesn't")
    c.ok(c.one("LEADM")["xmin"] < 200 and c.one("LISTM")["xmin"] > 200,
         "LISTM starts the second column, away from LEADM")


def keep_noweb(c, overfull=True):
    """test-keep-noweb.tex and -break: warnings against the pages of the words.

    With the limit of keepmaxgap, in -break, no page is overfull: the tie is released.
    """
    lines = keep_results(c, "noweb")
    c.ok(len(lines) == 14, f"14 cases, has {len(lines)}")
    apart, full = {}, {}
    for w in warnings(c):
        m = re.search(r"input line (\d+)", w)
        if "apart from what leads" in w:
            apart[int(m.group(1))] = int(re.search(r"starts page (\d+)", w).group(1))
        elif "doesn't fit" in w:
            full[int(m.group(1))] = w
    asked = {"g", "y"}
    for n, line in sorted(lines.items()):
        lead, code = c.one("LEAD" + n.upper()), c.one("CODE" + n.upper())
        two = lead["page"] < code["page"]
        if n in "mnfsuh" or n in asked:
            c.ok(two, f"case {n} is on two pages")
        if n in "qare":
            c.ok(not two, f"case {n} is on one page")
        if n in "tc":
            continue
        c.ok((line in apart) == (two and n not in asked),
             f"case {n}, line {line}: {'a' if line in apart else 'no'} warning")
        if line in apart:
            c.ok(apart[line] == code["page"],
                 f"case {n} names page {apart[line]}, it is on {code['page']}")
    w = [x for x in warnings(c) if "in multicols" in x]
    c.ok(len(w) == 1 and f"input line {lines['c']}" in w[0], f"case c warns: {w}")
    c.ok(set(full) == ({lines["t"]} if overfull else set()),
         f"only case t, and only without the limit, doesn't fit: {sorted(full)}")
    c.ok(not set(apart) - set(lines.values()), "no warning elsewhere")


def keep_once(c):
    """test-keep-once.tex; see its header."""
    lines = keep_results(c, "once")
    c.ok(set(lines) == set("vpnwmgi"), f"seven cases, has {sorted(lines)}")
    w = warnings(c)
    c.ok(not [x for x in w if "apart from what leads" in x],
         f"nothing warns a second time: {w}")
    for n, line in lines.items():
        lead, code = c.one("LEAD" + n.upper()), c.one("CODE" + n.upper())
        c.ok(lead["page"] < code["page"], f"case {n} is on two pages")
        here = [x for x in w if "goes to the next page" in x
                and f"test-keep-once, line {line} " in x]
        c.ok(len(here) == 1, f"case {n}, line {line}, warns once: {w}")
    c.ok(len([x for x in w if "goes to the next page" in x]) == len(lines),
         f"no warning elsewhere: {w}")
    totals = {k: float(v) for k, v in re.findall(r"once total (\w+) ([\d.]+)pt", c.log)}
    a, b = totals["a1"] - totals["a0"], totals["b1"] - totals["b0"]
    c.ok(abs(a - b) < 0.01, f"the same space before the list: {a:.2f}pt and {b:.2f}pt")
    c.ok(c.one("LEADB")["page"] == c.one("ITEMB")["page"], "case B is on one page")


def keep_multicol(c):
    """test-keep-multicol.tex; see its header."""
    lines = keep_results(c, "multicol")
    c.ok(not re.search(r"Overfull \\vbox", c.log), "no Overfull \\vbox")
    w = [x for x in warnings(c) if "multicols" in x]
    for n in "abp":
        c.ok(any(f"input line {lines[n]}" in x for x in w),
             f"case {n}, line {lines[n]}, warns")
    c.ok(len(w) == 3, f"three warnings about multicols, has {len(w)}: {w}")
    for lead, first in (("LEADA", "alpha"), ("LEADB", "beta")):
        # In its own column, it's above it with no stretch; in the next one, it's
        # at the top of it.
        a, b = c.one(lead), c.words(first)[0]
        gap = b["ymin"] - a["ymax"]
        if abs(a["xmin"] - b["xmin"]) < 50:
            c.ok(-1 < gap < 40, f"{lead} is right above its listing: {gap:.0f}pt")
        else:
            c.ok(b["ymin"] < a["ymin"], f"{first} starts the next column")
    c.ok(len(c.words("gamma")) == 20, "the listing after the columns is there")
    gam = c.words("gamma")
    c.ok(gam[0]["page"] == gam[-1]["page"], "the one after them is kept")


def marginfloat_hidden(c):
    """test-marginfloat-hidden.tex; the numbers are those of its header."""
    c.clean_log()                                    # 1
    for word in ("HIDDENPAR", "HIDDENV", "HIDDENTAB", "HIDDENTEXT"):  # 2
        c.absent(word)
    c.in_margin("VISIBLE", "VISTEXT")                # 3
    c.has_text("Figure 1: VISIBLE")
    c.has_text("Table 1: TABVISIBLE")


def frametitle(c):
    """test-frametitle.tex; the numbers are those of its header."""
    c.num_pages(1)
    c.clean_log()
    c.ok(c.same_line(c.one("TITLEA"), c.one("TEXTA")),    # 1
         "TITLEA and TEXTA are on one line")
    c.has_text("TITLEB \u2013 SUBB TEXTB,")               # 2
    c.has_text("TITLEC \u2013 SUBC")                      # 3
    c.above("TITLEC", "ITEMC")
    c.ok(c.one("TEXTD")["xmin"] > c.one("TITLEA")["xmin"],  # 4, indented
         "TEXTD starts a paragraph of its own")
    c.above("TITLEE", "PROSEF")                           # 5
    c.has_text("Figure 0.1: FIGE,")
    c.above("TITLEG", "EXAMPLEG")                         # 6
    c.ok(c.same_line(c.one("BLOCKI"), c.one("TEXTI")),    # 7
         "BLOCKI and TEXTI are on one line")
    c.above("ALERTJ", "ITEMJ")
    c.ok(c.one("TEXTK")["xmin"] == c.one("TITLEA")["xmin"],
         "TEXTK starts without an indent, with no title")
    c.ok(c.one("TEXTH")["xmin"] > c.one("TITLEA")["xmin"],  # 8
         "TEXTH has no heading in front of it")
    c.absent("SLIDEONLY")


def blocks_nested(c):
    """test-block-nested.tex: titles of blocks in blocks."""
    c.clean_log()
    c.has_text("OUTERONE")
    c.has_text("INNERONE TEXTONE")
    c.above("OUTERONE", "INNERONE")
    c.absent("INNERTWO INNERTWO")
    c.ok(len(c.words("INNERONE")) == 1, "the inner title is there once")
    c.ok(c.same_line(c.one("ALERTTWO"), c.one("TEXTTWO")),
         "a block after a frame title has its title run in")
    c.above("FRAMETWO", "ALERTTWO")


def frametitle_slides(c):
    """test-frametitle-slides.tex: the frames as beamer makes them."""
    c.num_pages(8)
    c.clean_log()
    c.absent("PROSEF")
    c.above("TITLEA", "TEXTA")
    c.above("TITLEB", "SUBB")
    c.above("SUBB", "TEXTB")
    c.above("TITLEC", "SUBC")
    c.above("SUBC", "ITEMC")
    c.above("TITLEE", "FIGE")
    c.above("TITLEG", "EXAMPLEG")
    c.above("SLIDEONLY", "TEXTH")
    c.has_text("Figure: FIGE,")


def frametitle_overlay(c):
    """test-frametitle-overlay.tex; the numbers are those of its header."""
    c.num_pages(1)
    c.clean_log()
    c.above("OVERA", "OVERB")                        # 1
    c.has_text("OVERB TEXTOVER")
    c.above("ONLYA", "ONLYB")                        # 2
    c.has_text("ONLYB TEXTONLY")
    plain, empty = c.one("PLAINPARA"), c.one("TEXTEMPTY")  # 3
    c.ok(abs(plain["xmin"] - empty["xmin"]) < 0.5,
         f"TEXTEMPTY starts like a paragraph: {empty['xmin'] - plain['xmin']:.1f}pt")
    c.has_text("SUBONLY TEXTSUBONLY")                # 4
    c.absent("\u2013")


def frametitle_floats(c):
    """test-frametitle-floats.tex; the numbers are those of its header."""
    c.num_pages(2)
    c.clean_log()
    c.above("TITLEH", "FIGH")                        # 1
    c.above("TITLEBIGH", "FIGBIGH")                  # 2
    c.above("TITLETAB", "TABH")                      # 3
    c.above("TITLETEXT", "FIGT")                     # 4
    c.above("FIGT", "TEXTT")
    c.ok(c.same_line(c.one("FLOATPROSE"), c.one("PROSEAFTER")),  # 5
         "FLOATPROSE still runs in with PROSEAFTER")
    c.above("TITLESTARFIG", "FIGSTAR")               # 6
    c.above("TITLESTARTAB", "TABSTAR")


def frametitle_boxes(c):
    """test-frametitle-boxes.tex; the numbers are those of its header."""
    c.clean_log()
    for title, first in (("TIMG", "A"), ("TCENTRE", "B"), ("TPLAIN", "TABWORD"),   # 1
                         ("TTABS", "TABSWORD"), ("TTABX", "TABXWORD"),
                         ("TTIKZ", "TIKZWORD"), ("TMINI", "MINIWORD"),
                         ("TCOLS", "COLWORD"), ("TBYTEXT", "BYTEXTWORD"),
                         ("TMINTED", "print")):
        title_word = c.one(title)
        below = [w for w in c.pages[title_word["page"] - 1]
                 if w["text"].split("(")[0] == first]
        c.ok(any(w["ymin"] >= title_word["ymax"] - 1 for w in below),
             f"{title} is on a line of its own, above {first}")
    heading = max(c.words("Contents"), key=lambda w: w["ymax"] - w["ymin"])
    toc_title = c.one("TTOC")
    c.ok((toc_title["page"], toc_title["ymax"] - 1) <= (heading["page"], heading["ymin"]),
         "TTOC is on a line of its own, above the heading Contents")
    c.ok(abs(c.one("TCENTRE")["xmin"] - c.one("TIMG")["xmin"]) < 0.5,  # 2
         "TCENTRE is flush left, like TIMG")
    c.absent("THIDDEN")                              # 3
    c.absent("currentsection")
    c.ok(c.same_line(c.one("TFBOX"), c.one("FBOXWORD")),  # 4
         "TFBOX and FBOXWORD are on one line")
    c.ok(c.same_line(c.one("PROSEHEAD"), c.one("PROSETAB")),  # 5
         "PROSEHEAD and PROSETAB are on one line")


def frametitle_end(c):
    """test-frametitle-end.tex; the numbers are those of its header."""
    c.num_pages(1)
    c.clean_log()
    c.above("TENVEMPTY", "PROSEA")                   # 1
    c.above("TCMDEMPTY", "PROSEB")
    c.above("TENVNOTE", "PROSEC")                    # 2
    c.above("TCMDNOTE", "PROSED")
    c.ok(c.same_line(c.one("TCMDTEXT"), c.one("TEXTCMD")),  # 3
         "TCMDTEXT runs in with TEXTCMD")
    indent = c.one("PROSEA")["xmin"]                 # 4
    for word in "PROSEB", "PROSEC", "PROSED", "PROSEE":
        c.ok(abs(c.one(word)["xmin"] - indent) < 0.5,
             f"{word} starts like an ordinary paragraph")
    c.absent("THIDENV")                              # 5
    c.absent("THICMD")
    c.ok(c.same_line(c.one("TAFTER"), c.one("TEXTAFTER")),
         "TAFTER runs in with TEXTAFTER")
    c.one("TWICE")                                   # 6


def frametitle_template(c):
    """test-frametitle-template.tex and -template-after.tex."""
    c.num_pages(1)
    c.clean_log()
    c.has_text("USERTEMPLATE TITLETPL")
    c.above("TITLETPL", "TEXTTPL")


def frametitle_noarticle(c):
    """test-frametitle-noarticle.tex."""
    c.num_pages(1)
    c.clean_log()
    c.above("TITLENOA", "TEXTNOA")
    c.above("TITLESUB", "SUBNOA")
    c.above("SUBNOA", "TEXTSUB")
    c.absent("\u2013")


def frametitle_article(c):
    """test-frametitle-article.tex."""
    c.num_pages(1)
    c.clean_log()
    c.has_text("TITLEART TEXTART")
    c.has_text("TITLESUBART \u2013 SUBART TEXTSUBART")
    c.above("TITLELIST", "ITEMART")
    c.above("TITLEIMG", "FIGIMG")


CHECKS = {
    "test-marginfloat": marginfloat,
    "test-marginfloat-slides": marginfloat_slides,
    "test-marginfloat-cases": marginfloat_cases,
    "test-marginfloat-order": marginfloat_beside,
    "test-marginfloat-inorder": marginfloat_inorder,
    "test-marginfloat-samepar": marginfloat_samepar,
    "test-marginfloat-moved": marginfloat_moved,
    "test-marginfloat-chapters": marginfloat_chapters,
    "test-marginfloat-kinds": marginfloat_kinds,
    "test-marginfloat-article": marginfloat_article,
    "test-marginfloat-hidden": marginfloat_hidden,
    "test-keep-leadin": keep_leadin,
    "test-keep-leadin-off": keep_leadin_off,
    "test-keep-overfull": keep_overfull,
    "test-keep-multicol": keep_multicol,
    "test-keep-once": keep_once,
    "test-keep-twocol": keep_twocol,
    "test-keep-noweb": keep_noweb,
    "test-keep-noweb-break": lambda c: keep_noweb(c, overfull=False),
    "test-frametitle": frametitle,
    "test-block-nested": blocks_nested,
    "test-frametitle-slides": frametitle_slides,
    "test-frametitle-overlay": frametitle_overlay,
    "test-frametitle-floats": frametitle_floats,
    "test-frametitle-boxes": frametitle_boxes,
    "test-frametitle-end": frametitle_end,
    "test-frametitle-template": frametitle_template,
    "test-frametitle-template-after": frametitle_template,
    "test-frametitle-noarticle": frametitle_noarticle,
    "test-frametitle-article": frametitle_article,
    "test-marginfloat-include": marginfloat_include,
    "test-marginfloat-include-all": marginfloat_include_all,
}


def main(names):
    if not names:
        print("FAIL no tests given")
        return 1
    failed = 0
    for name in names:
        if name not in CHECKS:
            print(f"FAIL {name}: no checks for this test")
            failed += 1
            continue
        c = Check(name)
        CHECKS[name](c)
        if not c.checks:
            print(f"FAIL {name}: ran no checks")
            failed += 1
        failed += c.failed
        print(f"{name}: {c.checks} checks, {c.failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
