#!/usr/bin/env python3
"""Check where the URLs of test-biburl-breaks.pdf break (didactic, #89).

    python3 test-biburl-breaks.py default|on|same|lua
    python3 test-biburl-breaks.py memoir

reads test-biburl-breaks.pdf, or test-biburl-memoir.pdf for memoir, with
pdftotext -bbox, and its .log.  Each page is a case, "CASE <name> <width>" and then a citation or a
bibliography (see test-biburl-breaks.tex).  The words of a page are made into
lines by their baselines, left to right, so a margin note's line and the text's
line beside it don't get in each other's way; the spaces are dropped (url.sty's
stretchable space shows as spaces), the lines joined, and each URL found in the
result: a line that ends inside a URL is a break, and the character before it
says what kind.

default (biburlpenalty off): no URL breaks after a letter or a digit, as with
biblatex alone.  on, same, lua (biburlpenalty=9000), and memoir (the review's
case of a memoir document, with biburlpenalty):
- a URL whose pieces fit doesn't break after a letter or a digit;
- one with a piece wider than the line does (the last resort), but not right
  before a character url.sty breaks after, such as the / that ends the piece:
  biburlpenalty is high, so the line ends one character later, at the / (but
  in the box of width 0, which breaks everywhere);
- none breaks inside https://, or between the two digits of a %-escape;
- in the boxes of width 0, which break wherever they may, there are letter
  breaks (else they would show nothing), and no break where url.sty has none:
  between the slashes of a :// inside the URL, or after a % right after a /;
- the document's own \\UrlLeft and \\UrlRight are still there;
- the log has no Overfull \\hbox.
Every case must be found, with each URL it should have; a line per case, PASS
or FAIL, and the exit status is 1 on any FAIL.
"""
import html
import json
import re
import subprocess
import sys

URLS = {
    "fits": "https://silly.business/2026/11/whyurlsbreak/index.html",
    "long": "https://example.org/pages/abcdefghijklmnopqrstuvwxyz"
            "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqr/index.html",
    "w1": "https://de.wikipedia.org/wiki/Universit%C3%A4tsbibliothek_M%C3%BCnchen",
    "w3": "https://example.org/search?q=very%20long%20query%20with%20many"
          "%20words%20in%20it",
    "w4": "https://example.org/some_file_name_with_many_underscores_in_it.txt",
    "m40": "https://example.org/abcdefghijklmnopqrstuvwxyzabcdefghijklmn/x.html",
    "esc": "https://example.org/p%41q%C3%A4rs/x",
    "arch": "https://ar.org/w/https://e.org/a/%41b",
    "rel1": "http://[2001:db8::1]:8080/a--b/c",
    "rel2": "http://e.org/a/:b",
}
ZERO = ("esc", "arch", "rel1", "rel2")
CUTS = "test-biburl-breaks.cuts"
PARA = ("5.6", "7.2", "8.8")
# characters that url.sty (with biblatex) breaks after, in these URLs
BREAKS = set("/.:?=&_%-")
# the URLs of a case, and whether a piece of each is wider than the line
WIDE = {("long", w) for w in ("3.0cm", "4.5cm", "6.0cm")} | {
    ("m40", "3cm"), ("m40", "m40")} | {(k, "0pt") for k in ZERO}
BIB = {"fits": False, "long": True, "w1": False, "w3": False, "m40": True}


def pages(pdf):
    """Per page, its lines: the words on one baseline, left to right, each
    as (xMin, xMax, word)."""
    out = subprocess.run(["pdftotext", "-bbox", pdf, "-"], capture_output=True,
                         text=True, check=True).stdout
    for page in re.findall(r"<page[^>]*>(.*?)</page>", out, re.S):
        words = [(float(y), float(x0), float(x1), html.unescape(w))
                 for x0, x1, y, w in re.findall(
                     r'<word xMin="([\d.]+)" yMin="[\d.]+" xMax="([\d.]+)" '
                     r'yMax="([\d.]+)">(.*?)</word>', page)]
        words.sort()
        lines, last = [], None
        for y, x0, x1, w in words:
            if last is None or y - last > 2:
                lines.append([])
            lines[-1].append((x0, x1, w))
            last = y
        yield [sorted(line) for line in lines]


def breaks(lines, url, drop=""):
    """The positions in url after which a line ends, or None if url is
    not in the lines.  The characters in drop aren't in the text (OT1's
    roman _ is a rule): url is looked for without them, and a line end
    next to one is taken to come after it."""
    shown = [i for i, c in enumerate(url) if c not in drop]
    text = "".join(lines)
    start = text.find("".join(url[i] for i in shown))
    if start < 0:
        return None
    result, pos = [], 0
    for line in lines:
        pos += len(line)
        if start < pos < start + len(shown):
            result.append(shown[pos - start])
    return result


def scheme(url):
    """The length of the URL's scheme and ://, or 0."""
    end = url.find("://")
    return end + 3 if 0 < end < 10 else 0


def check_url(url, cuts, wide, mode):
    """The failures of one URL broken at cuts."""
    fails = []
    SCHEME = scheme(url)
    letters = [c for c in cuts if url[c - 1].isalnum()]
    if (mode == "default" or not wide) and letters:
        fails.append("breaks after a letter or digit")
    if mode != "default":
        if any(0 < c < SCHEME for c in cuts):
            fails.append("breaks inside https://")
        if any(c >= 2 and url[c - 2] == "%" for c in cuts):
            fails.append("breaks inside a %-escape")
        if wide and not letters:
            fails.append("doesn't break in its wide piece")
        inner = url.find("://", SCHEME)
        if inner > 0 and inner + 2 in cuts:
            fails.append("breaks between the slashes of an inner ://")
        if any(url[c - 2:c] == "/%" for c in cuts):
            fails.append("breaks after a % right after a /")
        if url not in [URLS[k] for k in ZERO] and any(url[c] in BREAKS for c in letters
                                      if c < len(url)):
            fails.append("breaks after a letter right before a place to break")
    return fails


def main():
    mode = sys.argv[1]
    pdf = "test-biburl-memoir.pdf" if mode == "memoir" else "test-biburl-breaks.pdf"
    expected = {f"fits {w / 10:.1f}cm" for w in range(30, 61)}
    expected |= {f"long {w}cm" for w in ("3.0", "4.5", "6.0")}
    expected |= {"w1 3cm", "w1 4cm", "w3 4cm", "w4 4cm", "w4 4.5cm",
                 "w4 4.7cm", "w4 5.5cm", "m40 3cm",
                 "m40 8cm", "m40 9cm", "esc 0pt", "arch 0pt", "outer 4.5cm",
                 "bib 4.5cm"}
    if mode != "default":
        expected.add("margin m40")
    if mode == "memoir":
        expected = {"text m40", "list m40", "margin m40", "mbib m40"}
    if mode != "memoir":
        expected |= {f"{k} 0pt" for k in ZERO} | {f"para {w}cm" for w in PARA}
    seen, failed, zero = set(), False, {}
    for boxes in pages(pdf):
        words = [w for line in boxes for _, _, w in line]
        if words[:1] != ["CASE"] or len(words) < 3:
            continue
        name, width = words[1], words[2]
        case = f"{name} {width}"
        seen.add(case)
        left = boxes[0][0][0]
        boxes[0] = boxes[0][3:]
        boxes = [line for line in boxes if line]
        lines = ["".join(re.sub(r"\s", "", w) for _, _, w in line)
                 for line in boxes]
        fails, shown = [], []
        if name == "para":
            right = left + float(width[:-2]) / 2.54 * 72
            short = [lines[i] for i, line in enumerate(boxes[:-1])
                     if right - line[-1][1] > 8]
            if short:
                fails.append("lines end short: " + ", ".join(short))
        if name == "para":
            todo = [("fits", False)]
        elif name in ("text", "list", "mbib"):
            todo = [("m40", False)]
        elif name == "bib":
            todo = list(BIB.items())
        elif name in ("outer", "margin"):
            todo = [("fits" if name == "outer" else "m40", name == "margin")]
        else:
            todo = [(name, (name, width) in WIDE)]
        for key, wide in todo:
            url = URLS[key]
            cuts = breaks(lines, url, "_" if mode == "same" else "")
            if cuts is None:
                fails.append(f"{key}: URL not found")
                continue
            shown.append(" | ".join(url[a:b] for a, b in
                                    zip([0] + cuts, cuts + [len(url)])))
            fails += [f"{key}: {f}" for f in check_url(url, cuts, wide, mode)]
            if width == "0pt":
                zero[key] = cuts
            if name == "outer" and f"[{url}]" not in "".join(lines):
                fails.append("the document's \\UrlLeft or \\UrlRight is gone")
        print(f"didactic biburl breaks: {mode} {case}:",
              "FAIL (" + "; ".join(fails) + ")" if fails else "PASS",
              "; ".join(shown))
        failed |= bool(fails)
    if mode == "default":
        with open(CUTS, "w") as f:
            json.dump(zero, f)
    elif mode != "memoir":
        try:
            with open(CUTS) as f:
                own = json.load(f)
        except OSError:
            own = {}
        for key in ZERO:
            url, fails = URLS[key], []
            if key not in own or key not in zero:
                fails.append("no breaks of the default mode to compare with")
            else:
                extra = [c for c in zero[key]
                         if not url[c - 1].isalnum() and c not in own[key]]
                lost = [c for c in own[key] if c not in zero[key]
                        and not 0 < c < scheme(url)]
                if extra:
                    fails.append("breaks where url.sty doesn't: " + ", ".join(
                        url[:c] + " |" for c in extra))
                if lost:
                    fails.append("doesn't break where url.sty does: " + ", ".join(
                        url[:c] + " |" for c in lost))
            print(f"didactic biburl breaks: {mode} {key} as url.sty:",
                  "FAIL (" + "; ".join(fails) + ")" if fails else "PASS")
            failed |= bool(fails)
    for case in sorted(expected - seen):
        print(f"didactic biburl breaks: {mode} {case}: FAIL (case missing)")
        failed = True
    if mode != "default":
        log = open(pdf[:-4] + ".log", errors="replace").read()
        overfull = log.count("Overfull \\hbox")
        print(f"didactic biburl breaks: {mode} Overfull \\hbox:",
              "PASS" if overfull == 0 else f"FAIL ({overfull})")
        failed |= overfull > 0
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
