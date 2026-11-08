#!/usr/bin/env python3
"""Check where the URLs of test-biburl-breaks.pdf break (didactic, #89).

    python3 test-biburl-breaks.py default|on

reads test-biburl-breaks.pdf (with pdftotext) and test-biburl-breaks.log.
Each page is a case: "CASE <name>", then a citation or a bibliography.  The
script takes the page's lines, drops the spaces in them (url.sty's stretchable
space shows as spaces in pdftotext), joins them and finds each URL in the
result; a line that ends inside a URL is a break, and the character before it
says what kind.

By default (the option off) no URL breaks after a letter or a digit, as with
biblatex alone, not even the long one, which runs into the margin.  With
biburlpenalty (on) a URL whose pieces fit in the line (fits) doesn't either,
no URL breaks inside its scheme and ://, the long one breaks after a letter
in its 70-letter piece (there is no other way to avoid running into the
margin), and the log has no Overfull \\hbox.  Every case must be found, with each URL it should have; it prints a
line per case, PASS or FAIL, and exits 1 on any FAIL.
"""
import re
import subprocess
import sys

URLS = {
    "fits": "https://silly.business/2026/11/whyurlsbreak/index.html",
    "long": "https://example.org/pages/abcdefghijklmnopqrstuvwxyz"
            "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqr/index.html",
}
SCHEME = len("https://")


def breaks(lines, url):
    """The positions in url after which a line ends, or None if url is
    not in the lines."""
    text = "".join(lines)
    start = text.find(url)
    if start < 0:
        return None
    result, pos = [], 0
    for line in lines:
        pos += len(line)
        if start < pos < start + len(url):
            result.append(pos - start)
    return result


def check_url(name, url, cuts, mode):
    """The failures of one URL broken at cuts."""
    fails = []
    letters = [c for c in cuts if url[c - 1].isalnum()]
    if (name == "fits" or mode == "default") and letters:
        fails.append("breaks after a letter or digit")
    if mode == "on":
        if any(0 < c < SCHEME for c in cuts):
            fails.append("breaks inside https://")
        if name == "long" and not letters:
            fails.append("doesn't break in its long piece")
    return fails


def main():
    mode = sys.argv[1]
    text = subprocess.run(["pdftotext", "test-biburl-breaks.pdf", "-"],
                          capture_output=True, text=True, check=True).stdout
    expected = {f"fits {w / 10:.1f}cm" for w in range(30, 61)}
    expected.add("bib 4.5cm")
    expected |= {f"long {w}cm" for w in ("3.0", "4.5", "6.0")}
    seen, failed = set(), False
    for page in text.split("\f"):
        found = re.search(r"CASE\s+(\S+)\s+(\S+)", page)
        if not found:
            continue
        case = f"{found.group(1)} {found.group(2)}"
        seen.add(case)
        lines = [re.sub(r"\s", "", line)
                 for line in page[found.end():].split("\n")]
        lines = [line for line in lines if line]
        names = ["fits", "long"] if case.startswith("bib") else [found.group(1)]
        fails, shown = [], []
        for name in names:
            cuts = breaks(lines, URLS[name])
            if cuts is None:
                fails.append(f"{name}: URL not found")
                continue
            shown.append(" | ".join(URLS[name][a:b] for a, b in
                                    zip([0] + cuts, cuts + [len(URLS[name])])))
            fails += [f"{name}: {f}" for f in
                      check_url(name, URLS[name], cuts, mode)]
        print(f"didactic biburl breaks: {mode} {case}:",
              "FAIL (" + "; ".join(fails) + ")" if fails else "PASS",
              "; ".join(shown))
        failed |= bool(fails)
    for case in sorted(expected - seen):
        print(f"didactic biburl breaks: {mode} {case}: FAIL (case missing)")
        failed = True
    if mode == "on":
        log = open("test-biburl-breaks.log", errors="replace").read()
        overfull = log.count("Overfull \\hbox")
        print(f"didactic biburl breaks: {mode} Overfull \\hbox:",
              "PASS" if overfull == 0 else f"FAIL ({overfull})")
        failed |= overfull > 0
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
