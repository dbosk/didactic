"""The probe: code added to a copy of didactic.sty, which writes <job>.lp.

P <id> <page>            the last line of a paragraph
L <id> <para> <type> <depth> <afterheading> <page>
                         the first item of an itemize, enumerate or description
G <page> <penalty> <goal> <natural> <the text's baselineskip>
                         a page, with the penalty it broke at

Whatsits written at shipout, like a label, not text extraction.  Traps it avoids:
a whatsit makes a line of an empty paragraph (\\noindent\\par, as noweb has), so it
tests \\lastnodetype, under a trailing space; one on the vertical list stops the
package's handling of listing lines (tried: it changed more pages), so it stays in the
paragraph; and \\the\\count0 takes the following space.

The trailing space is taken off to look under it and then put back, before the
paragraph ends.  Left off, it changed pages: a paragraph of nothing but two spaces,
which noweb leaves for an empty chunk of text, is an empty line, and without its last
space TeX dropped it, so the lines after it moved up (78 pages of one literate program,
22 of the paper).  test_probe.py checks that the probe moves no line.

The unit of a line is \\baselineskip at the start of the document: a page can be
output inside a listing's small font, where \\normalbaselineskip is 9.5pt, not 12pt,
and gaps would look a quarter larger.  test_probe.py checks that.

analyse.py compares with the noprobe setting, and prints how many pages differ: none,
since the space is put back.  Page counts and warnings are read from noprobe all the
same.
"""
import re

PROBE = r"""
\newwrite\lp@out \newcount\lp@id \newcount\lp@lid \let\lp@pending\@empty
\newskip\lp@skip
\def\lp@para{\if@didactic@keep@inbox\else\ifhmode
  \ifnum\lastnodetype=11 \lp@skip\lastskip\unskip\lp@write\hskip\lp@skip
  \else\lp@write\fi\fi\fi}
\def\lp@write{\ifnum\lastnodetype>\m@ne
  \global\advance\lp@id\@ne
  \edef\lp@x{\write\lp@out{P \the\lp@id\space\noexpand\the\count0 }}\lp@x\fi}
\def\lp@mark{\ifx\lp@pending\@empty\else
  \if@didactic@keep@inbox\else
    \global\advance\lp@lid\@ne
    \edef\lp@x{\write\lp@out{L \the\lp@lid\space\the\lp@id\space\lp@pending\space
      \the\@listdepth\space\if@nobreak 1\else 0\fi\space\noexpand\the\count0 }}\lp@x
  \fi
  \global\let\lp@pending\@empty\fi}
\AddToHook{para/end}{\lp@para}
\AddToHook{env/itemize/begin}{\gdef\lp@pending{i}}
\AddToHook{env/enumerate/begin}{\gdef\lp@pending{e}}
\AddToHook{env/description/begin}{\gdef\lp@pending{d}}
\def\lp@measure{\ifnum\outputpenalty>-10001 {\setbox0\vbox{\unvcopy255}%
  \immediate\write\lp@out{G \the\count0 \space\the\outputpenalty\space\the\ht255 \space
    \the\dimexpr\ht0+\dp0\relax\space\the\lp@line}}\fi}
\newdimen\lp@line
\AtBeginDocument{\immediate\openout\lp@out=\jobname.lp
  \global\lp@line\baselineskip
  \output\expandafter{\expandafter\lp@measure\the\output}%
  \let\lp@orig@item\@item
  \def\@item[#1]{\lp@orig@item[\lp@mark#1]}}
"""


def style(source, setting):
    """The text of didactic.sty for a setting."""
    s = open(source, errors="replace").read()
    for name, value in setting.get("defaults", {}).items():
        s, n = re.subn(r"\\@didactic@%s=\d+" % name,
                       lambda m: r"\@didactic@%s=%d" % (name, value), s)
        if n != 1:
            raise SystemExit(f"{name}: the default is set {n} times in {source}, expected 1")
    for old, new in setting.get("replace", []):
        if s.count(old) != 1:
            raise SystemExit(f"{old}: found {s.count(old)} times in {source}, expected 1")
        s = s.replace(old, new)
    if setting.get("leadin", True) is False:
        a = "\\@didactic@keepleadintrue\n\\DeclareOptionX{keeplines}"
        if s.count(a) != 1:
            raise SystemExit("keepleadin: can't find its default in " + source)
        s = s.replace(a, "\\@didactic@keepleadinfalse\n\\DeclareOptionX{keeplines}")
    tail = setting.get("tail", "") + "\n"
    for name in re.findall(r"\\let(\\@didactic@[@a-z]+)\\relax", tail):
        if name + "{" not in s:
            raise SystemExit(f"{name} isn't defined in {source}: the setting would do nothing")
    if setting.get("probe", True):
        tail += PROBE
    i = s.rfind(r"\endinput")
    if i < 0:
        raise SystemExit("no \\endinput in " + source)
    return s[:i] + tail + s[i:]
