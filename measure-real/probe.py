"""The probe: code added to a copy of didactic.sty, which writes <job>.lp.

P <id> <page>            the last line of a paragraph
L <id> <para> <type> <depth> <afterheading> <page>
                         the first item of an itemize, enumerate or description
G <page> <penalty> <goal> <natural> <baselineskip>
                         a page, with the penalty it broke at

Whatsits written at shipout, like a label, not text extraction.  Traps it avoids:
a whatsit makes a line of an empty paragraph (\\noindent\\par, as noweb has), so it
tests \\lastnodetype; one on the vertical list stops the package's handling of
listing lines (tried: it changed more pages), so it stays in the paragraph; and
\\the\\count0 takes the following space.

Known limit: on two of the documents it still moves some lines between pages, with
the same page count (the whatsit in the paragraph hook does it, not the rest).
Page counts and warnings are therefore read from the noprobe setting, and analyse.py
prints how many pages differ.
analyse.py compares with the noprobe setting.
"""
import re

PROBE = r"""
\newwrite\lp@out \newcount\lp@id \newcount\lp@lid \let\lp@pending\@empty
\def\lp@para{\if@didactic@keep@inbox\else\ifhmode\unskip\ifnum\lastnodetype>\m@ne
  \global\advance\lp@id\@ne
  \edef\lp@x{\write\lp@out{P \the\lp@id\space\noexpand\the\count0 }}\lp@x\fi\fi\fi}
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
    \the\dimexpr\ht0+\dp0\relax\space\the\normalbaselineskip}}\fi}
\AtBeginDocument{\immediate\openout\lp@out=\jobname.lp
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
