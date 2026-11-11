#!/bin/bash
# Run the cases of test-noteplace.tex and check each by its outcome
# (test-noteplace.py): where the note NOTEY goes, and what that does to a heading
# and to a paragraph's first and last lines.  These are the cases of
# test-yieldkeep (fix-68), whose checks read marginfix's log lines; the intent of
# each is kept, the checks are the PDF, the labels and the warnings.
#
# Each job runs until its .aux file stops changing (at most $MAXRUNS runs, 8);
# a job that doesn't settle, or has an error, fails, as does a run that takes
# more than $TEXTIMEOUT seconds (120): a layout that never ends.  Runs to settle are a
# requirement: each job is built again with noteoverflow=carry (\testfloor, job
# <job>-floor), which moves no note for a page that ends early, and may take at
# most one run more than that floor.  $ENGINE (pdflatex), $CASES
# (names to run; all by default) and $PRE (TeX code put before the document, say
# to load another implementation) can be set; RECHECK=1 checks the jobs there are
# again without building them.  Run from the repository after make didactic.sty.
#
# From test-yieldkeep's rows, what changed besides the checks: the cases that
# expected the page to end early ("yield") now expect the note on its callout's
# page (kept), and those that expected the note held with a warning ("hold") a
# heading with its first line and the note on its page or warned, which a page
# that ends before the heading also satisfies.  headingoff expected the page to
# end under the heading (keepafterheading=0); LaTeX's own \nobreak after a heading
# still forbids that, so it expects the heading with its first line.  hboxlines
# expects the note kept, not FIRSTLINE with the heading: three lines follow the
# heading.  clubzero expected a lone first line with a warning in a document
# that forbids it; now it must not be left.  longtable checked that no warning
# blamed a heading wrongly, in the fork's words; now only the outcome.  The
# option noteyieldmaxgap is gone: a page ends early for a note within
# keepmaxgap, the rows set that.
#
# A page ends early for a note only if no heading and no list or listing that a
# lead-in leads into has started on it (see the rows ref*): these expected the
# note kept and now expect it carried with a warning (warned):
#   runin       a run-in heading starts the paragraph of the callout;
#   theorem     the head of a theorem is a heading to the keep rules;
#   hboxlines   a heading on the page, above the lines in boxes;
#   headfoot    a heading on the page, the note in its first paragraph;
#   laterpara   a heading on the page, the note in its second paragraph.
# headshipped stays kept: its heading is on the page before.
job=test-noteplace
status=0
# $MARGINFIX: a directory with the marginfix.sty to test against, put first on
# TEXINPUTS (say TeX Live's, $(kpsewhich -var-value TEXMFDIST)/tex/latex/marginfix,
# or a build of another branch); unset, the one found.
[ -n "$MARGINFIX" ] && export TEXINPUTS="$(cd "$MARGINFIX" && pwd)//:$TEXINPUTS"
ENGINE=${ENGINE:-pdflatex}
MAXRUNS=${MAXRUNS:-8}
TEXTIMEOUT=${TEXTIMEOUT:-120}
run() { # <job> <case> <room> <options> <definitions>
  timeout "$TEXTIMEOUT" $ENGINE -shell-escape -interaction=nonstopmode -jobname="$1" \
    "${PRE}$5\\def\\testcase{$2}\\def\\testroom{$3}\\def\\testoptions{$4}\\input{$job}" \
    > /dev/null 2>&1
  # a run that never ends fails as an error
  [ $? = 124 ] && printf "\n! the run took more than %s s\n" "$TEXTIMEOUT" >> "$1.log"
  return 0
}
settle() { # as run; sets $settled and $runs
  settled=no
  for runs in $(seq 1 "$MAXRUNS"); do
    [ -f "$1.aux" ] && cp "$1.aux" "$1.aux.old"
    run "$@"
    if [ -f "$1.aux.old" ] && cmp -s "$1.aux" "$1.aux.old" \
       && ! grep -q 'Rerun to get\|may have changed' "$1.log"; then
      settled=yes; return
    fi
  done
}
# check <name> <case> <room> <options> <expect> [<definitions>]: expect is a
# comma-separated list for test-noteplace.py.
check() {
  name=$1; j=$job-$name
  [ -z "$CASES" ] || case " $CASES " in *" $name "*) ;; *) return;; esac
  floor=-
  if [ -n "$RECHECK" ]; then settled=yes; runs=-; else
    rm -f "$j-floor.aux"
    settle "$j-floor" "$2" "$3" "$4" "\\def\\testfloor{}$6"
    floor=$runs
    rm -f "$j.aux" "$j.pdf"
    settle "$j" "$2" "$3" "$4" "$6"
  fi
  errors=$(grep -c '^!' "$j.log")
  if [ "$settled$errors" != yes0 ]; then
    echo "didactic noteplace test: $name FAIL (settled: $settled after $runs runs, errors: $errors)"
    status=1; return
  fi
  if [ "$floor" != - ] && [ "$runs" -gt $((floor + 1)) ]; then
    echo "didactic noteplace test: $name FAIL ($runs runs, floor $floor)"
    status=1; return
  fi
  if res=$(python3 test-noteplace.py "$j" "$5"); then
    echo "didactic noteplace test: $name PASS ($runs runs, floor $floor) $res"
  else
    echo "didactic noteplace test: $name FAIL ($runs runs) $res"; status=1
  fi
}
# What every case wants unless it says otherwise: NOTEY on its callout's page or a
# warning (warned), and any first or last line left alone at the break named by a
# warning (lonewarn): in these documents no line is left alone but by what is done
# for the note, since without it the case's text fits on the first page.
W=warned,lonewarn
# A heading must not be parted from its first line; the note goes on with a
# warning if it can't stay.
check heading heading 7 '' "$W,together"
check stacked stacked 9 '' "$W,together"
check headlist headlist 7 '' "$W,together"
check headthm headthm 7 '' "$W,together"
check withother withother 8 '' "$W,together"
check tallheading tallheading 11 '' "$W,together"
check second second 9 '' "$W,together"
check vertical vertical 7 '' "$W,together"
check runintwo runintwo 7 '' "$W,together"
# The limit on how much of a page may be left short for a note.
check headingzero heading 7 'keepmaxgap=0' "$W,together,limitwarn"
# With keepafterheading=0 LaTeX's own \nobreak after a heading still holds.
check headingoff heading 7 'keepafterheading=0' "$W,together"
# A lone first or last line the document allows may be left for the note, with a
# warning; one it forbids may not.
check tallclub tallclub 4 '' "kept,lonewarn"
check tallwidow tallwidow 8 '' "kept,lonewarn"
check tallmiddle tallmiddle 9 '' "kept,lonewarn"
check club club 4 '' "kept,lonewarn"
check widow widow 7 '' "kept,lonewarn"
check clubforbid clubforbid 4 '' "$W,noclub"
check widowforbid widowforbid 7 '' "$W,nowidow"
check clubzero clubforbid 4 'keepmaxgap=0' "$W,noclub,limitwarn"
# The limit for a note on the last lines of a page (footcheck's lastlimit and
# limit): ending the page before THIRD leaves two lines empty, more than
# keepmaxgap=1 allows, so the note goes on, with a warning naming the limit; at
# keepmaxgap=2 the page may end there.  The tall note leaves less than a line of
# the margin free, so NOTEY fits beside no line of page 1.  \raggedbottom shows
# the empty lines at the foot of the page, where gap=N reads them; with a flush
# bottom they would be spread between the lines.
L4='\def\testpre{\raggedbottom}\def\testtall{.985}\def\testbody{FIRSTLINE\newline SECOND\newline THIRD\yieldnote{}\newline FOURTH \filler}'
check lastlimit x 4 'keepmaxgap=1' "$W,limitwarn,gap=1" "$L4"
check lastroom x 4 'keepmaxgap=2' "kept,lonewarn,gap=2" "$L4"
# Notes already decided whose lines an early end takes back: A is set beside
# LINEA, B (a footnote too tall for the margin left) at the foot, and then NOTEY,
# on the page's last line, fits neither in the margin nor (not a footnote) at
# the foot.  The paragraph can't break, so the page ends before LINEA, taking
# the three lines back: A, B's copy for the foot and NOTEY go with them to the
# next page, each beside or under its line there, or with a warning.
DEC='\def\testtall{.1}\def\testbody{{\interlinepenalty=10000 \clubpenalty=10000 \widowpenalty=10000 \noindent FIRSTLINE LINEA\label{c-a}\marginpar{\label{n-a}A}\newline LINEB\label{c-b}\footnote{\label{n-b}B \filler}\newline LINEC\yieldnote[\par\rule{1pt}{2\baselineskip}]\par}}'
check decided x 3 '' "kept,pairs,lonewarn" "$DEC"
# A note that fits, called out on a line that TeX's own page break then takes
# to the next page: the paragraph can't break, and when its last line doesn't
# fit, all of it goes, after the note was called out.  The note goes with its
# line; marginfix 1.2 alone sets it on the page before, beside nothing.
MOVED='\def\testtall{.1}\def\testbody{{\interlinepenalty=10000 \noindent FIRSTLINE\newline SECOND\newline THIRD\yieldnote{}\newline FOURTH\par}}'
# Page 1 has another callout (TALL, at its top) in linemoves; in linemovesalone
# it has none, so that a mark from the special output for NOTEY, in the page
# so far, is the last mark the page build could take for page 1's own.
check linemoves x 3 '' kept "$MOVED"
ALONE='\def\testfirst{\noindent x text\par\noindent\rule{1cm}{\dimexpr\textheight-\testroom\baselineskip-1\baselineskip}\par}'
check linemovesalone x 3 '' kept "$ALONE${MOVED#\\def\\testtall{.1\}}"
# Two callouts in the paragraph that moves: the special output for the second
# reads a page so far that holds the mark of the first.
TWO='\def\testbody{{\interlinepenalty=10000 \noindent FIRSTLINE\newline SECOND\yieldnote{}\newline THIRD\marginpar{\label{n-b}OTHER}\label{c-b}\newline FOURTH\par}}'
check linemovestwo x 3 '' kept,pairs "$ALONE$TWO"
# The same in two columns, where a column, not a page, is made at a time (the
# paragraph goes to the second column of page 1; the row caught lineno, which
# replaces \@makecol in two columns, so that a reading there lost every note);
# and with a page of floats between the page of the callouts and the page their
# lines go to, where no column is made at all.
check linemovestwocol x 3 '' kept,pairs "\\def\\testclass{article}\\def\\testclassopt{a4paper,twocolumn}$ALONE$TWO"
FP='\def\testpre{\renewcommand\floatpagefraction{.1}}'
FIG='\begin{figure}[p]\rule{1cm}{.8\textheight}\caption{FLOATPAGE}\end{figure}'
check linemovesfloat x 3 '' kept,pairs "$FP$ALONE${TWO/testbody\{/testbody\{$FIG}"
# A column whose marks can't be read by splitting it: glue that shrinks
# without limit, put there in the output routine (document text can't),
# before didactic reads.  The reading falls back to \botmarks, with a warning
# naming the page.
SHRINKOUT='\def\testshrinkout{}'
check readfallback x 3 '' "warned,callwarn" "$SHRINKOUT\\def\\testtall{.1}\\def\\testbody{FIRSTLINE\\yieldnote{} \\filler}"
# Who gets the warning that a note is set on another page than its callout:
# every such note once, whoever moved it, but the rest of a note marginfix
# cut (it continues a note set on its page) and a deferrable note, which is
# marginfix's to move (its own notice in the mode warn).  tallcut: a note
# taller than the margin, called out low on the page, which marginfix moves
# whole to the next page (too little room to cut it there): one warning;
# deferrable: a deferrable note in the mode split that moves for the note
# after it: marginfix's notice, none of didactic's.
TALLCUT='\def\testtall{.1}\def\testbody{FIRSTLINE\marginpar{\label{n-a}TALLCUT\par\rule{1pt}{1.3\textheight}}\label{c-a} \filler\par}'
check tallcut x 9 '' "pairs,exactwarn" "$TALLCUT"
DEFER='\def\testtall{.1}\def\testbody{FIRSTLINE\marginpar{\label{n-d1}\marginnotedeferrable DEFER\par\rule{1pt}{.6\textheight}}\label{c-d1} \oneline\ more\marginpar{\label{n-b}PLAIN\par\rule{1pt}{.3\textheight}}\label{c-b} \filler\par}'
check deferrable x 9 'notepriority=split' "exactwarn" "$DEFER"
# In two columns foot works as break: silently with the default, with a
# warning when a passage asks for foot (the option's case is in
# test-noteoverflow-foot, twofoot).
TWOC='\def\testclass{article}\def\testclassopt{a4paper,twocolumn}\def\testtall{.1}'
check twodefault x 7 '' "nofootwarn" "$TWOC\def\testbody{FIRSTLINE\yieldnote{} \filler\par}"
check twopassage x 7 '' "footwarn" "$TWOC\def\testbody{{\marginnoteoverflow{foot} FIRSTLINE\yieldnote{} \filler\par}}"
# Nothing in the way: the note stays with its line.
check runin runin 4 '' "$W"
check theorem theorem 4 '' "$W"
check middle middle 9 '' kept,lonewarn
# The rest of a split note doesn't stop the note after it.
check split split 4 '' "continued"

# What the walk over the page's lines got wrong on fix-68: these must come out
# right.
Y='\yieldnote[\par\rule{1pt}{.3\textheight}]'
T='\def\testtall{.75}'
L="Now the LASTLINE of the paragraph, with its note$Y."
ART='\def\testclass{article}'
H='\section{HEADINGX} FIRSTLINE\yieldnote{} \filler\ \filler'
check foothead x 7 '' "$W,together" "$ART\\def\\testfootnotefirst{}\\def\\testbody{$H}"
check footlone x 7 '' "$W" \
  "$ART\\def\\testfootnotefirst{}\\def\\testbody{FIRSTLINE \\filler\\ Now the last line of the paragraph, with its note\\yieldnote{}.}"
check noteearlier x 7 '' "$W" \
  "$T\\def\\testbody{FIRSTLINE\\marginpar{SHORT} \\filler\\ $L}"
check footinpara x 5 '' kept,lonewarn \
  "$T\\def\\testbody{FIRSTLINE\\footnote{FOOTB} \\oneline\\ second \\oneline\\ more words$Y \\filler\\ \\filler}"
check headfoot x 10 '' "$W,together" \
  "$T\\def\\testbody{\\section{HEADINGX} FIRSTLINE\\footnote{FOOTB} \\oneline\\ second \\oneline\\ more words$Y \\filler\\ \\filler}"
check display x 10 '' "$W" \
  '\def\testbody{FIRSTLINE \oneline\ two. \[ x=y \] after DISPLAY \filler\ Now the LASTLINE of the paragraph, with its note\yieldnote{}.}'
check newline x 7 '' "$W" \
  '\def\testbody{FIRSTLINE \\[6pt] \filler\ Now the LASTLINE of the paragraph, with its note\yieldnote{}.}'
check markright x 7 '' "$W" \
  '\def\testbody{FIRSTLINE\markright{M} \filler\ Now the last line of the paragraph, with its note\yieldnote{}.}'
check hboxlines x 9 '' "$W" \
  '\def\testbody{\section{HEADINGX} \hbox{Listing line one}\hbox{Listing line two}\hbox{Listing line three} \par FIRSTLINE\yieldnote{} \filler\ \filler}'
# What is known of a heading ends with its page: a note at the same height on the
# next page is free.
check headshipped x 7 '' kept,lonewarn \
  '\def\testbody{\section{HEADINGX} FIRSTLINE \oneline\par\newpage \noindent x\marginpar{TALLB\par\rule{1pt}{.97\textheight}} text\par\noindent\rule{1cm}{\dimexpr\textheight-52pt\relax}\par FIRSTLINE\yieldnote{} \filler\ \filler}'
check crosspages x 4 '' "$W" \
  '\def\testbody{FIRSTLINE \oneline\ more words\yieldnote{} \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler}'
check laterpara x 9 '' "$W" \
  '\def\testbody{\section{HEADINGX} \filler\par FIRSTLINE\yieldnote{} \filler}'
check onelinepara x 4 '' kept,lonewarn \
  '\def\testbody{FIRSTLINE\yieldnote{}\par \filler}'
check verticaldue x 7 '' "$W,together" \
  '\def\testbody{\section{HEADINGX} FIRSTLINE.\par\yieldnote{}\par SECONDPARA \filler}'

# What deciding by heights got wrong on fix-68 (the review of #68, on #80): none of
# these may end a page under a title or a tie.
B='\yieldnote{} \filler\ \filler'
check listlead x 8 '' "$W,together" \
  "\\def\\testbody{\\section{HEADINGX} One line of lead-in:\\begin{itemize}\\item FIRSTLINE$B\\end{itemize}}"
check listleadart x 8 '' "$W,together" \
  "$ART\\def\\testbody{\\section{HEADINGX} One line of lead-in:\\begin{itemize}\\item FIRSTLINE$B\\end{itemize}}"
check tallsecond x 8 '' "$W,together" \
  "\\def\\testbody{\\section{HEADINGX} A\\rule{0pt}{15pt}\\par FIRSTLINE$B}"
check titlelist x 7 '' "$W,together" \
  "\\def\\testbody{\\paragraph{HEADINGX}\\begin{itemize}\\item FIRSTLINE$B\\end{itemize}}"
check frametitle x 7 '' "$W,together" \
  "\\def\\testbody{\\begin{frame}\\frametitle{HEADINGX}\\begin{itemize}\\item FIRSTLINE$B\\end{itemize}\\end{frame}}"
check frameblock x 7 '' "$W,together" \
  "\\def\\testbody{\\begin{frame}\\frametitle{HEADINGX}\\begin{block}{BLOCKT} FIRSTLINE$B\\end{block}\\end{frame}}"
check blankabove x 10 '' "$W,together" \
  "\\def\\testbody{\\section{HEADINGX}\\vspace{2\\baselineskip} FIRSTLINE$B}"
check laterhead x 8.25 '' "$W,together" \
  "$ART\\def\\testbody{\\section{HEADINGX} FIRSTLINE\\yieldnote{}\\par\\subsection{HEADB} Words \\filler\\ \\filler}"
check laterhead2 x 9 'keepmaxgap=12' "$W,together" \
  "\\def\\testbody{\\section{HEADINGX} FIRSTLINE\\yieldnote{}\\par\\section{HEADB} Words \\filler\\ \\filler}"
M='\noindent x\marginpar{TALL\par\rule{1pt}{.97\textheight}}'
check movedfloat x 7 '' "$W,together" \
  "\\def\\testfirst{$M\\marginpar{TALLB\\par\\rule{1pt}{.2\\textheight}} text\\par\\noindent\\rule{1cm}{\\dimexpr\\textheight-5\\baselineskip\\relax}\\par\\begin{figure}[t]\\rule{1cm}{.84\\textheight}\\end{figure}}\\def\\testbody{\\section{HEADINGX} FIRSTLINE$B}"
check movedzero x 7 'keepmaxgap=0' "$W,together" \
  "\\def\\testfirst{$M\\marginpar{TALLB\\par\\rule{1pt}{.97\\textheight}} text\\par\\noindent\\rule{1cm}{\\dimexpr\\textheight-5\\baselineskip\\relax}\\par}\\def\\testbody{\\section{HEADINGX} FIRSTLINE$B}"
check tallmark x 11 '' "$W,together" \
  "\\def\\testbody{\\section{HEADINGX} \\rule{0pt}{4\\baselineskip} FIRSTLINE\\markright{M}$B}"
check nopagebreak x 5 '' "$W,tied" \
  "\\def\\testbody{Lead LEADIN\\nopagebreak\\par\\nopagebreak FIRSTLINE$B}"
# A page ends early before a note's line only if nothing the keep rules look
# after has started on it: a note under any kind of heading or after a lead-in
# on its page is carried, with the reason, though the page could end before its
# line (noteoverflow=break and keepmaxgap=100 leave no other reason).  refnone,
# the same text without a heading, ends its page early and keeps the note.
RB='noteoverflow=break,keepmaxgap=100'
K='SECONDPARA \oneline\ more words\yieldnote{} \filler\ \filler'
P3='FIRSTLINE \filler\ \filler\par'
check refnone x 12 "$RB" kept "\\def\\testbody{$P3 $K}"
check refsection x 12 "$RB" carried,keepwhy "\\def\\testbody{\\section{HEADINGX} $P3 $K}"
check refstarred x 12 "$RB" carried,keepwhy "\\def\\testbody{\\section*{HEADINGX} $P3 $K}"
check refrunin x 12 "$RB" carried,keepwhy "\\def\\testbody{\\paragraph{HEADINGX} $P3 $K}"
check refthm x 12 "$RB" carried,keepwhy "\\def\\testbody{\\begin{thmx}$P3\\end{thmx} $K}"
check refframe x 12 "$RB" carried,keepwhy "\\def\\testbody{\\begin{frame}\\frametitle{HEADINGX} $P3 $K\\end{frame}}"
check refblock x 12 "$RB" carried,keepwhy "\\def\\testbody{\\begin{frame}\\begin{block}{BLOCKT} $P3 $K\\end{block}\\end{frame}}"
check reflist x 12 "$RB" carried,keepwhy "\\def\\testbody{FIRSTLINE \\filler\\ Lead-in:\\begin{itemize}\\item ITEMA \\filler\\item $K\\end{itemize}}"
check reflisting listing 12 "$RB" carried,keepwhy "\\def\\testsecond{$K}"
check refchapter x 12 "$RB" carried,keepwhy "\\def\\testfirst{\\chapter{HEADINGX}\\noindent x\\marginpar{TALL\\par\\rule{1pt}{.97\\textheight}} text\\par}\\def\\testbody{$P3 $K}"
# Whether a heading or a lead-in is in a column is decided when the column is
# made, though TeX has read past it by then: a heading whose first lines don't
# fit goes to the next page, where a note under it is carried (headcarry, the
# heading's place noted at its paragraph; headroom, the page ended before the
# heading as it starts, its place not noted), and so
# is a list whose lead-in's tie was let go (leadcarry); a heading that stays on
# its page leaves the next page free, where the page ends early (headstays).
TB='TALLB\par\rule{1pt}{.97\textheight}'
check headcarry x 5 "$RB,keepafterheading=3" carried,keepwhy "\\def\\testbody{\\section{HEADINGX} FIRSTLINE\\marginpar{$TB} \\filler\\ \\filler\\ \\filler\\par $K}"
check headroom x 3 "$RB,keepafterheading=3" carried,keepwhy "\\def\\testbody{\\section{HEADINGX} FIRSTLINE\\marginpar{$TB} \\filler\\ \\filler\\ \\filler\\par $K}"
check leadcarry x 6 "$RB" carried,keepwhy "\\def\\testbody{FIRSTLINE \\filler\\ \\filler\\ Lead-in:\\begin{itemize}\\item ITEMA\\marginpar{$TB} \\filler\\ \\filler\\item $K\\end{itemize}}"
check headstays x 10 "$RB" kept "\\def\\testbody{\\section{HEADINGX} FIRSTLINE \\filler\\ \\filler\\par \\filler\\ \\filler\\ \\filler\\ \\filler\\par X\\marginpar{$TB} \\filler\\par $K}"
# In two columns lineno makes the columns (twocolend); a column made where we
# don't see it counts as one with a heading (colbypass).  Both after a column has
# been made: twocolend in the second column of page 2, where the margin is full.
NP='\def\testfirst{\noindent x\par\clearpage\noindent x\marginpar{TALL\par\rule{1pt}{.97\textheight}} text\par\noindent\rule{1cm}{\dimexpr\textheight-\testroom\baselineskip-1\baselineskip\relax}\par}'
NP2='\def\testfirst{\noindent x\par\clearpage\noindent y\par\newpage\noindent x\marginpar{TALL\par\rule{1pt}{.97\textheight}} text\par\noindent\rule{1cm}{\dimexpr\textheight-\testroom\baselineskip-1\baselineskip\relax}\par}'
check twocolend x 12 "$RB" kept "$NP2\\def\\testclass{article}\\def\\testclassopt{a4paper,twocolumn}\\def\\testbody{$K}"
check colbypass x 12 "$RB" carried,keepwhy "\\makeatletter\\AddToHook{begindocument/end}{\\def\\@didactic@colbuild{}}\\makeatother$NP\\def\\testbody{$P3 $K}"
# The lines a page ends early leaves empty are counted above the notes at its
# foot: a footnote went to the foot (the margin is full), and the page may end
# two lines above the foot's notes to keep NOTEY beside its line (footgap).
check footgap x 14 '' kept "\\def\\testbody{FIRSTLINE\\footnote{FOOTA \\filler\\ \\filler\\ \\filler} \\filler\\par $K}"
# What leads into a list isn't tied by a penalty of 10000: the keep rules warn.
check leadlist x 5 '' "$W,leadwarn" \
  "\\def\\testbody{Lead LEADIN:\\begin{itemize}\\item FIRSTLINE$B\\end{itemize}}"
R='\begin{longtable}{l}\endhead '"$(python3 -c "print('a\\\\\\\\ '*50)")"'\end{longtable}'
check longtable x 7 '' "$W" \
  "\\def\\testpre{\\usepackage{longtable}}\\def\\testfirst{}\\def\\testbody{$M\\marginpar{TALLB\\par\\rule{1pt}{.97\\textheight}} text\\par\\noindent\\rule{1cm}{\\dimexpr\\textheight-9\\baselineskip}\\par\\section{HEADA}$R FIRSTLINE$B}"
check twocolumn x 7 '' "$W,together" \
  "$ART\\def\\testclassopt{a4paper,twocolumn}\\def\\testbody{\\section{HEADINGX} FIRSTLINE\\yieldnote{} \\filler\\ more\\par x\\marginpar{TALLC\\par\\rule{1pt}{.97\\textheight}}\\marginpar{NOTEC} y \\filler}"
check movedcold heading 7 '' "$W,together"
check moved heading 12 '' "$W,together"

# A build started from the .aux file of another must come to what a cold one does:
# warm <from> <job> <case> <room> <options> <cold job> [<definitions>].
warm() {
  [ -z "$CASES" ] || case " $CASES " in *" $2 "*) ;; *) return;; esac
  j=$job-$2; c=$job-$6
  if [ -n "$RECHECK" ]; then settled=yes; else
    cp "$job-$1.aux" "$j.aux"; rm -f "$j.pdf"
    settle "$j" "$3" "$4" "$5" "$7"
  fi
  if [ "$settled" = yes ] \
     && diff <(pdftotext -layout "$j.pdf" -) <(pdftotext -layout "$c.pdf" -) >/dev/null
  then
    echo "didactic noteplace test: $2 PASS (warm from $1, as $6)"
  else
    echo "didactic noteplace test: $2 FAIL (warm from $1, not as $6; settled: $settled)"
    status=1
  fi
}
warm heading warmoff heading 7 'keepafterheading=0' headingoff
warm heading warmzero heading 7 'keepmaxgap=0' headingzero
warm widowforbid warmdrop widow 7 '' widow
warm headingoff warmback heading 7 '' heading
warm heading warmmoved heading 12 '' moved
warm moved warmmovedback heading 7 '' movedcold
W2='FIRSTLINE \filler\ Now the last line of the paragraph, with its note\yieldnote{}'
FB='\def\testpre{\AtBeginDocument{\widowpenalty=10000 }}'
check wforbid x 7 '' "$W,nowidow" "$FB\\def\\testbody{$W2.}"
check wfreecold x 7 '' kept,lonewarn "$FB\\def\\testbody{$W2 and \\filler\\ \\filler}"
warm wforbid wfree x 7 '' wfreecold "$FB\\def\\testbody{$W2 and \\filler\\ \\filler}"

# Under beamer the notes are off: no errors.
if [ -z "$CASES" ] || case " $CASES " in *" slides "*) true;; *) false;; esac; then
  [ -n "$RECHECK" ] || rm -f "$job-slides.aux"
  [ -n "$RECHECK" ] || $ENGINE -shell-escape -interaction=nonstopmode -jobname="$job-slides" "${PRE}\\input{$job-slides}" > /dev/null 2>&1
  errors=$(grep -c '^!' "$job-slides.log")
  if [ "$errors" = 0 ]; then
    echo "didactic noteplace test: slides PASS"
  else
    echo "didactic noteplace test: slides FAIL ($errors errors)"; status=1
  fi
fi
exit $status
