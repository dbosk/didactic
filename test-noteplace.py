#!/usr/bin/env python3
"""Check one settled job of test-noteplace.tex by its outcome only.

Usage: test-noteplace.py JOB EXPECT[,EXPECT...]

The checks read the PDF (pdftotext -bbox), the labels of the .aux file and the
warnings of the log, never a mechanism's own log lines, so that they hold for any
implementation.  The text column comes from the line "noteplace geometry:" that
test-noteplace.tex writes to the log.  EXPECT is one of:

  kept        NOTEY is set on the page of its callout.
  warned      NOTEY is on the page of its callout, or a warning names a margin
              note set on another page than its callout.
  together    the heading HEADINGX is on the page of FIRSTLINE.
  tied        LEADIN is on the page of FIRSTLINE (a \\nopagebreak tie).
  leadwarn    if LEADIN isn't on the page of FIRSTLINE, a warning says what goes
              to the next page apart from what leads into it ("What starts at").
  noclub      FIRSTLINE isn't the last line of the text on its page, with its
              paragraph going on on the next page.
  nowidow     the last line of the paragraph ("Now the last line") isn't the first
              line of the text on its page.
  lonewarn    if a first or last line is alone at a page break (club or widow), a
              warning says so ("alone").
  limitwarn   if NOTEY is off its callout's page, a warning names the limit
              (notemaxgap).
  continued   the rest of a split note is marked as continued.
Prints one line, "PASS" or "FAIL" with what failed, and the facts.
"""
import re
import subprocess
import sys

job, expect = sys.argv[1], [e for e in sys.argv[2].split(",") if e]
log = open(job + ".log", errors="replace").read()
aux = open(job + ".aux", errors="replace").read()


def label(name):
    m = re.search(r"\\newlabel\{%s\}\{\{[^}]*\}\{([^}]*)\}" % re.escape(name), aux)
    return m.group(1) if m else None


geo = dict(re.findall(r"(\w+)=([\d.]+)",
                     re.search(r"noteplace geometry:(.*?)(?:\n\n|\n[^\n]*:)", log, re.S).group(1).replace("\n", "")))
geo = {k: float(v) for k, v in geo.items()}
out = subprocess.run(["pdftotext", "-bbox", job + ".pdf", "-"], capture_output=True, text=True,
                     errors="replace").stdout
pages = []
for n, p in enumerate(out.split("<page ")[1:], 1):
    left = geo["odd"] if n % 2 else geo["even"]
    words = []
    for x0, y0, x1, y1, w in re.findall(
            r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">([^<]*)</word>', p):
        x0, y0, x1, y1 = map(float, (x0, y0, x1, y1))
        body = (x0 >= left - 2 and x1 <= left + geo["width"] + 2
                and geo["top"] <= (y0 + y1) / 2 <= geo["top"] + geo["height"])
        words.append((w, x0, (y0 + y1) / 2, body))
    pages.append(words)


def page_of(word):
    for n, ws in enumerate(pages, 1):
        if any(w[0].startswith(word) for w in ws):
            return n
    return None


def lines(n):
    """The body lines of page n, as lists of words, from top to bottom."""
    ls = {}
    for w, x, y, body in pages[n - 1]:
        if body:
            ls.setdefault(round(y), []).append((x, w))
    return [[w for x, w in sorted(v)] for k, v in sorted(ls.items())]


def indented(n):
    """Whether the first body line of page n starts a paragraph (is indented)."""
    left = geo["odd"] if n % 2 else geo["even"]
    xs = [x for w, x, y, body in pages[n - 1]
          if body and round(y) == min(round(y2) for w2, x2, y2, b2 in pages[n - 1] if b2)]
    return bool(xs) and min(xs) > left + 5


def club():
    """FIRSTLINE ends its page, and its paragraph goes on on the next."""
    n = page_of("FIRSTLINE")
    if n is None or n >= len(pages):
        return False
    ls = lines(n)
    return bool(ls) and any(w.startswith("FIRSTLINE") for w in ls[-1]) and not indented(n + 1)


def widow():
    for n in range(1, len(pages) + 1):
        ls = lines(n)
        if ls and " ".join(ls[0]).startswith("Now the last line") and n > 1:
            return True
    return False


facts = {"callout": label("callout-y"), "note": label("note-y"), "pages": len(pages)}
fails = []
off = facts["note"] != facts["callout"]
# The warnings that say a margin note is off its callout's page, read from the
# log with the continuation prefixes taken out: marginfix's ("Margin note called
# out at", "The margin note called out at", "Margin note from ... moved"),
# didactic's for a carried note ("A margin note from page"), and marginfix's log
# line for a note it carries without a warning (integration, whose only notice it
# is: a log line, not a warning, so it counts here only to tell the installed
# build's silence apart from a note that went unnoticed).
joined = re.sub(r"\n\((?:marginfix|didactic)\) *", " ", log).replace("\n", "")
warned = bool(re.search(r"[Mm]argin note called out at|Margin note from .*? moved|"
                        r"A margin note from page", joined))
logged = bool(re.search(r"^marginfix-spill: .*unresolved", log, re.M))
for e in expect:
    if e == "kept" and off:
        fails.append("note-y on page %s, its callout on %s" % (facts["note"], facts["callout"]))
    elif e == "warned" and off and not warned:
        fails.append("note-y off its callout's page (%s, %s) without a warning" % (facts["note"], facts["callout"]))
    elif e == "together" and page_of("HEADINGX") != page_of("FIRSTLINE"):
        fails.append("HEADINGX on page %s, FIRSTLINE on %s" % (page_of("HEADINGX"), page_of("FIRSTLINE")))
    elif e == "tied" and page_of("LEADIN") != page_of("FIRSTLINE"):
        fails.append("LEADIN on page %s, FIRSTLINE on %s" % (page_of("LEADIN"), page_of("FIRSTLINE")))
    elif e == "leadwarn" and page_of("LEADIN") != page_of("FIRSTLINE") \
            and "What starts at" not in joined:
        fails.append("LEADIN parted from FIRSTLINE without a warning")
    elif e == "noclub" and club():
        fails.append("FIRSTLINE alone at the foot of page %s" % page_of("FIRSTLINE"))
    elif e == "nowidow" and widow():
        fails.append("the paragraph's last line alone at the top of a page")
    elif e == "lonewarn" and (club() or widow()) and not re.search(r"alone|What starts at", joined):
        fails.append("a line alone at a page break without a warning")
    elif e == "limitwarn" and off and "notemaxgap" not in joined:
        fails.append("note-y off its page without a warning naming notemaxgap")
    elif e == "continued" and not re.search(r"continued|forts", " ".join(w[0] for ws in pages for w in ws)):
        fails.append("no continued note")
facts["club"], facts["widow"], facts["warned"], facts["logged"] = club(), widow(), warned, logged
print(("FAIL: " + "; ".join(fails) if fails else "PASS") + " " + str(facts))
sys.exit(1 if fails else 0)
