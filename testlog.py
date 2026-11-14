#!/usr/bin/env python3
"""Read a TeX log as TeX wrote it, for the tests' checkers.

TeX breaks a line of its log when it reaches 79 (max_print_line), wherever
that falls: inside a word, just before a parenthesis.  A message that is
longer is so on several lines of the file, and a check that reads the file
line by line misses a phrase that a break cuts.  The engines count
differently, as measured (TeX Live 2025):

  pdfTeX   79 bytes; a character of several bytes may be cut;
  XeTeX    79 characters;
  LuaTeX   79 bytes, but a character of n bytes that doesn't fit before the
           79th byte (at n bytes or fewer from it) goes to the next line, so
           the line is shorter.

A line that ends at 79 by itself gets an empty line after it, as TeX breaks
when the 79th is out and then ends the line: so a line of exactly 79 is always
a break, and is joined to the next.  The engine is read from the log's first
line (pdfTeX's rule if none).  A package's message goes on, after
\\MessageBreak, on lines that start with the package's name in parentheses
("(didactic)" and the like).

lines(path)   the log's lines, each of TeX's breaks joined, decoded (UTF-8, a
              byte that isn't replaced), one string;
joined(path)  the same, and each line that goes on with "(didactic)",
              "(marginfix)" or "(hyperref)" joined to the line before it with
              a space: a message per line.

From the command line, with a regular expression of Python's, searched in the
lines of joined():

    python3 testlog.py count PATTERN LOG   the number of lines that match
    python3 testlog.py grep PATTERN LOG    those lines; exit status 1 if none
    python3 testlog.py selftest LOG...     the joiner on test-testlog.tex's logs

The Makefile's checks of the logs use the first two; the checkers in Python
import lines() and joined().
"""
import re
import sys

WRAP = 79
GOESON = re.compile(r"\n\((?:didactic|marginfix|hyperref)\) *")


def lines(path):
    """The log, with TeX's breaks joined."""
    with open(path, "rb") as f:
        data = f.read()
    first = data.split(b"\n", 1)[0]
    if b"XeTeX" in first:
        text = data.decode("utf-8", errors="replace")
        return re.sub(r"(?m)^(.{%d})\n" % WRAP, r"\1", text)
    lua = b"LuaTeX" in first or b"LuaHBTeX" in first
    out, last = [], None
    for line in data.split(b"\n"):
        if last is not None and broken(last, line, lua):
            out[-1] += line
        else:
            out.append(line)
        last = line
    return b"\n".join(out).decode("utf-8", errors="replace")


def broken(line, after, lua):
    """Whether TeX broke the physical line line, after which comes after (bytes)."""
    if len(line) == WRAP:
        return True
    if lua and after and after[0] >= 0xC0:
        size = 2 if after[0] < 0xE0 else 3 if after[0] < 0xF0 else 4
        return len(line) < WRAP <= len(line) + size
    return False


def joined(path):
    """The log as lines(), with each message's lines that go on joined."""
    return GOESON.sub(" ", lines(path))


def matching(pattern, path):
    """The lines of joined(path) that match pattern."""
    rx = re.compile(pattern)
    return [line for line in joined(path).split("\n") if rx.search(line)]


def selftest(path):
    """What test-testlog.tex says, each phrase cut by a break of TeX's."""
    with open(path, "rb") as f:
        physical = [x.decode("utf-8", errors="replace") for x in f.read().split(b"\n")]
    j, ls = joined(path), lines(path)

    def cut(phrase):
        return not any(phrase in x for x in physical)

    found = matching(r"didactic biburl test:.*FAIL", path)
    checks = [
        ("found from the last run, cut by a break",
         len(re.findall(r"found from the last\s+run", j)) == 1
         and cut("found from the last run")),
        ("isn't plain, cut by a break",
         len(re.findall(r"isn't plain", j)) == 1 and cut("isn't plain")),
        ("a line with non-ASCII text, cut in a word",
         "kapitel-översikt.tex:12, in the margin of page 3" in j
         and cut("in the margin of page 3")),
        ("a character of two bytes at the break",
         "at Ölandsbron." in ls and "\ufffd" not in ls and cut("at Ölandsbron.")),
        ("a break just before a parenthesis",
         "Standards, or (CCS) is at the foot of page 4" in j
         and any(x.startswith("(CCS)") for x in physical)),
        ("the words looked for on a message's second line",
         len(matching(r"Package didactic Warning: .*Only 1 of", path)) == 1),
        ("a verdict past the break, matched in its own line only",
         len(found) == 1 and found[0].endswith("FAIL") and cut("label FAIL")),
        ("lines(): a message's lines that go on stay lines of their own",
         "\n(didactic)" in ls and "\n(didactic)" not in j),
        ("a line that ends at 79 by itself stays a line, without TeX's empty one",
         "ENDS AT 79.\nNEXT LINE" in ls),
    ]
    for what, ok in checks:
        print(f"didactic testlog test: {path}: {what} {'PASS' if ok else 'FAIL'}")
    return all(ok for _, ok in checks)


def main(argv):
    if len(argv) == 3 and argv[0] == "count":
        print(len(matching(argv[1], argv[2])))
        return 0
    if len(argv) == 3 and argv[0] == "grep":
        found = matching(argv[1], argv[2])
        for line in found:
            print(line)
        return 0 if found else 1
    if len(argv) >= 2 and argv[0] == "selftest":
        return 0 if all([selftest(p) for p in argv[1:]]) else 1
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
