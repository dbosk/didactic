#!/usr/bin/env python3
"""Every patch didactic makes must say when it fails.

Reads didactic.dtx (or the file given), takes the code (the lines between
\\begin{macrocode} and \\end{macrocode}), and finds each call of \\patchcmd,
\\apptocmd, \\pretocmd and their xpatch kin (\\xpatchcmd, \\xapptocmd,
\\xpretocmd).  Its failure branch, the last argument, must warn or take a
fallback: one that is empty, or only \\relax, fails the test, since a patch
that doesn't take then goes unnoticed (review 5's last look: the \\apptocmd of
\\MFX@copyclass, refused by etoolbox from inside a macro, never took, and
nothing said so).  Exit 1 and the calls' lines if any; exit 0 and "PASS" with
the number of calls otherwise.

Usage: test-patches.py [FILE]      check FILE (didactic.dtx by default)
       test-patches.py selftest    the checker's rules on made-up code
"""
import re
import sys

ARGS = {"patchcmd": 5, "apptocmd": 4, "pretocmd": 4}


def code_of(text):
    """The code lines with their line numbers, comments taken off."""
    out, inside = [], False
    for n, line in enumerate(text.split("\n"), 1):
        if line.startswith("%    \\begin{macrocode}"):
            inside = True
            continue
        if line.startswith("%    \\end{macrocode}"):
            inside = False
            continue
        if inside:
            out.append((n, re.sub(r"(?<!\\)%.*", "", line)))
    return out


def arg(s, i):
    """The argument at s[i:] (after spaces): a group's contents, a control
    sequence or one character; and the index after it."""
    while i < len(s) and s[i] in " \n\t":
        i += 1
    if i >= len(s):
        return None, i
    if s[i] == "{":
        depth, j = 0, i
        while j < len(s):
            if s[j] == "\\":
                j += 2
                continue
            if s[j] == "{":
                depth += 1
            elif s[j] == "}":
                depth -= 1
                if depth == 0:
                    return s[i + 1:j], j + 1
            j += 1
        return None, len(s)
    if s[i] == "\\":
        m = re.match(r"\\([A-Za-z@]+|.)", s[i:], re.S)
        if m is None:
            return None, len(s)
        return m[0], i + len(m[0])
    return s[i], i + 1


def check(text):
    lines = code_of(text)
    joined, starts = "", []
    for n, l in lines:
        starts.append((len(joined), n))
        joined += l + "\n"

    def lineno(pos):
        n = 0
        for p, ln in starts:
            if p > pos:
                break
            n = ln
        return n

    calls, bad = 0, []
    for m in re.finditer(r"\\x?(patchcmd|apptocmd|pretocmd)(?![A-Za-z@])", joined):
        i, args = m.end(), []
        for _ in range(ARGS[m[1]]):
            a, i = arg(joined, i)
            args.append(a)
        calls += 1
        target = (args[0] or "?").strip()
        if any(a is None for a in args):
            # an argument that can't be read (an unbalanced group, the end of the
            # code): a FAIL that says so, not a pass and not a traceback
            bad.append((lineno(m.start()), m[0], target, "its arguments can't be read"))
        elif (args[-1] or "").strip() in ("", "\\relax"):
            bad.append((lineno(m.start()), m[0], target, "has an empty failure branch"))
    return calls, bad


def selftest():
    """The checker on made-up code, each rule from both sides."""
    def dtx(code, doc=""):
        return doc + "%    \\begin{macrocode}\n" + code + "\n%    \\end{macrocode}\n"
    cases = [
        ("a patch with a warning in its failure branch passes",
         dtx("\\patchcmd\\x{a}{b}{}{\\warn}"), 1, 0),
        ("an empty failure branch fails",
         dtx("\\patchcmd\\x{a}{b}{}{}"), 1, 1),
        ("one that is only \\relax fails",
         dtx("\\apptocmd\\x{a}{}{ \\relax }"), 1, 1),
        ("a call spread over lines, with comments at their ends, is read",
         dtx("\\patchcmd{\\x}%\n  {a}%\n  {b}{}%\n  {\\warn}%"), 1, 0),
        ("a nested group in the failure branch is one argument",
         dtx("\\pretocmd\\x{a}{}{\\iftrue{\\warn{x}}\\fi}"), 1, 0),
        ("an xpatch call counts",
         dtx("\\xpatchcmd\\x{a}{b}{}{}"), 1, 1),
        ("a call in a comment of the code doesn't count",
         dtx("\\relax % \\patchcmd\\x{a}{b}{}{}"), 0, 0),
        ("a call in the documentation doesn't count",
         dtx("\\relax", doc="% |\\patchcmd\\x{a}{b}{}{}|\n"), 0, 0),
        ("arguments that can't be read fail, said so",
         dtx("\\patchcmd\\x{a}{b}{}{\\warn"), 1, 1),
    ]
    bad = 0
    for what, text, ncalls, nbad in cases:
        calls, found = check(text)
        good = calls == ncalls and len(found) == nbad
        bad += not good
        print(f"didactic patches selftest: {'PASS' if good else 'FAIL'} {what}"
              + ("" if good else f": {calls} calls, {found}"))
    return 1 if bad else 0


def main():
    if sys.argv[1:2] == ["selftest"]:
        return selftest()
    path = sys.argv[1] if len(sys.argv) > 1 else "didactic.dtx"
    calls, bad = check(open(path, encoding="utf-8").read())
    if bad:
        for n, cmd, target, why in bad:
            print(f"didactic patches test: FAIL {path}:{n}: {cmd} of {target} {why}")
        print(f"didactic patches test: {len(bad)} of {calls} patches say nothing when they fail")
        return 1
    print(f"didactic patches test: PASS ({calls} patches, each says when it fails)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
