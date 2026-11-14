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
# <job>-floor), which places no note but beside its line or on a later page, and
# may take at most one run more than that floor.  $ENGINE (pdflatex), $CASES
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
# option noteyieldmaxgap is gone: the rows set keepmaxgap, which bounds every
# short page.
job=test-noteplace
status=0
# $MARGINFIX: a directory with the marginfix.sty to test against, put first on
# TEXINPUTS (say TeX Live's, $(kpsewhich -var-value TEXMFDIST)/tex/latex/marginfix,
# or a build of another branch); unset, the one found.
# TeX Live's tools (multicol) before anything else but that marginfix: a texmf
# tree may have an older multicol (one machine had noweb's of 1992 first).
TOOLS=$(kpsewhich -var-value=TEXMFDIST)/tex/latex/tools
export TEXINPUTS="$TOOLS:$TEXINPUTS"
[ -n "$MARGINFIX" ] && export TEXINPUTS="$(cd "$MARGINFIX" && pwd)//:$TEXINPUTS"
# Some rows expect another outcome with TeX Live's marginfix 1.2, which lets every
# line with a margin note end a page (see overguard): M12 is set there.
M12=; case "$MARGINFIX" in *texmf-dist/tex/latex/marginfix*) M12=yes;; esac
NOT12=yes; [ -n "$M12" ] && NOT12=
NEEDS15='tallcut deferrable split'
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
# comma-separated list for test-noteplace.py, where error=TEXT declares the one
# LaTeX error the row expects (its text), and no other is allowed.
check() {
  name=$1; j=$job-$name
  [ -z "$CASES" ] || case " $CASES " in *" $name "*) ;; *) return;; esac
  # rows about what marginfix 1.5 and later add (deferrable notes, the split of
  # a tall note): with TeX Live's 1.2 they don't apply
  if [ -n "$M12" ]; then case " $NEEDS15 " in *" $name "*)
    echo "didactic noteplace test: $name SKIP (needs marginfix 1.5 or later)"; return;; esac; fi
  floor=-
  if [ -n "$RECHECK" ]; then settled=yes; runs=-; else
    rm -f "$j-floor.aux"
    settle "$j-floor" "$2" "$3" "$4" "\\def\\testfloor{}$6"
    floor=$runs
    rm -f "$j.aux" "$j.pdf"
    settle "$j" "$2" "$3" "$4" "$6"
  fi
  errors=$(grep -c '^!' "$j.log")
  # error=TEXT in the expectation: that error must be in the log, and no other
  experr=$(printf '%s' "$5" | tr ',' '\n' | sed -n 's/^error=//p')
  if [ -n "$experr" ]; then
    if ! grep -q "^! .*$experr" "$j.log"; then
      echo "didactic noteplace test: $name FAIL (no error '$experr')"
      status=1; return
    fi
    errors=$((errors - $(grep -c "^! .*$experr" "$j.log")))
  fi
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
# Cases that the early end of a page kept, before no page ended early: NOTEY is a
# footnote there now ($YF), with the margin full (the tall note runs over), so
# that it goes to the foot of the page, whole or one line past it.
YF='\def\testyieldfoot{}\def\testtall{.99}'
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
check tallclub tallclub 4 '' "kept,lonewarn" "$YF"
check tallwidow tallwidow 8 '' "kept,lonewarn" "$YF"
check tallmiddle tallmiddle 9 '' "kept,lonewarn" "$YF"
check club club 4 '' "kept,lonewarn" "$YF"
check widow widow 7 '' "kept,lonewarn" "$YF"
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
DEC='\def\testtall{.1}\def\testbody{{\interlinepenalty=10000 \clubpenalty=10000 \widowpenalty=10000 \noindent FIRSTLINE LINEA\label{c-a}\marginpar{A\label{n-a}}\newline LINEB\label{c-b}\footnote{\label{n-b}B \filler}\newline LINEC\yieldnote[\par\rule{1pt}{2\baselineskip}]\par}}'
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
# The note of a line that TeX takes to the top of the next page waits there for
# it, and is set as marginfix sets a note carried to a page: its first line on
# the text's first line (\topskip less the first line's height), here its
# callout's (heldtop; with marginfix's own hold the note's top was at the
# margin's top, \topskip less that height higher, v2.16).  Where the line is the
# page's second, the note still stands on the first text line, a line above its
# callout: a limit, pinned as it is (heldsecond).  The positions are saved in
# the lines themselves (zsavepos after a word), and the note's label after its
# first word, so that the note's box starts with its first line.
HP='\def\testpre{\usepackage{zref-savepos,zref-abspage}\csname zref@addprop\endcsname{savepos}{abspage}}'
HT='\def\testbody{{\interlinepenalty=10000 \noindent FIRSTLINE\zsavepos{fl}\label{callout-y}\zsavepos{cl}\marginpar{NOTEY\zsavepos{nt}\label{note-y}}\newline SECOND\newline THIRD\newline FOURTH\par}}'
check heldtop x 3 '' kept,align=cl:nt "$ALONE$HP$HT"
HS='\def\testbody{{\interlinepenalty=10000 \noindent FIRSTLINE\zsavepos{fl}\newline SECOND\label{callout-y}\zsavepos{cl}\marginpar{NOTEY\zsavepos{nt}\label{note-y}}\newline THIRD\newline FOURTH\par}}'
check heldsecond x 3 '' kept,align=fl:nt "$ALONE$HP$HS"
# Two callouts in the paragraph that moves: the special output for the second
# reads a page so far that holds the mark of the first.
TWO='\def\testbody{{\interlinepenalty=10000 \noindent FIRSTLINE\newline SECOND\yieldnote{}\newline THIRD\marginpar{OTHER\label{n-b}}\label{c-b}\newline FOURTH\par}}'
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
# longtable ends each page it makes with \vss, which shrinks without limit: the
# column is read all the same (that glue is at its end, with no mark after it),
# with no warning, and the notes before, between and after are beside their lines
# (ltcallouts); a column that can't be read, but where no note's place depends on
# the reading, says nothing either (ltnodoubt: the same table, no note on its
# pages, the shrink at the column's top).
LT='\begin{longtable}{l}\endhead '"$(python3 -c "print('row\\\\\\\\ '*150)")"'\end{longtable}'
check ltcallouts x 3 '' "kept,nocallwarn,pairs" "\\def\\testpre{\\usepackage{longtable}}\\def\\testfirst{}\\def\\testbody{FIRSTLINE\\yieldnote{} \\filler\\par $LT AFTER\\label{c-a}\\marginpar{AFTERNOTE\\label{n-a}} \\filler\\par}"
check ltnodoubt x 3 '' "nocallwarn" "$SHRINKOUT\\def\\testpre{\\usepackage{longtable}}\\def\\testfirst{}\\def\\testbody{FIRSTLINE \\filler\\par $LT AFTER \\filler\\par}"
# Who gets the warning that a note is set on another page than its callout:
# every such note once, whoever moved it, but the rest of a note marginfix
# cut (it continues a note set on its page) and a deferrable note, which is
# marginfix's to move (its own notice in the mode warn).  tallcut: a note
# taller than the margin, called out low on the page, which marginfix moves
# whole to the next page (too little room to cut it there): one warning;
# deferrable: a deferrable note in the mode split that moves for the note
# after it: marginfix's notice, none of didactic's.
TALLCUT='\def\testtall{.1}\def\testbody{FIRSTLINE\marginpar{TALLCUT\label{n-a}\par\rule{1pt}{1.3\textheight}}\label{c-a} \filler\par}'
check tallcut x 9 '' "pairs,exactwarn" "$TALLCUT"
DEFER='\def\testtall{.1}\def\testbody{FIRSTLINE\marginpar{\marginnotedeferrable DEFER\label{n-d1}\par\rule{1pt}{.6\textheight}}\label{c-d1} \oneline\ more\marginpar{PLAIN\label{n-b}\par\rule{1pt}{.3\textheight}}\label{c-b} \filler\par}'
check deferrable x 9 'notepriority=split' "exactwarn" "$DEFER"
# In two columns foot works as carry: silently with the default, with a
# warning when a passage asks for foot (the option's case is in
# test-noteoverflow-foot, twofoot).
TWOC='\def\testclass{article}\def\testclassopt{a4paper,twocolumn}\def\testtall{.1}'
check twodefault x 7 '' "nofootwarn" "$TWOC\def\testbody{FIRSTLINE\yieldnote{} \filler\par}"
check twopassage x 7 '' "footwarn" "$TWOC\def\testbody{{\marginnoteoverflow{foot} FIRSTLINE\yieldnote{} \filler\par}}"
# Nothing in the way: the note stays with its line.
check runin runin 4 '' kept,lonewarn "$YF"
check theorem theorem 4 '' kept,lonewarn "$YF"
check middle middle 9 '' kept,lonewarn "$YF"
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
check footinpara x 5 '' "$W" \
  "$T\\def\\testbody{FIRSTLINE\\footnote{FOOTB} \\oneline\\ second \\oneline\\ more words$Y \\filler\\ \\filler}"
check headfoot x 10 '' "$W,together" \
  "$T\\def\\testbody{\\section{HEADINGX} FIRSTLINE\\footnote{FOOTB} \\oneline\\ second \\oneline\\ more words$Y \\filler\\ \\filler}"
check display x 10 '' "$W" \
  '\def\testbody{FIRSTLINE \oneline\ two. \[ x=y \] after DISPLAY \filler\ Now the LASTLINE of the paragraph, with its note\yieldnote{}.}'
check newline x 7 '' "$W" \
  '\def\testbody{FIRSTLINE \\[6pt] \filler\ Now the LASTLINE of the paragraph, with its note\yieldnote{}.}'
check markright x 7 '' "$W" \
  '\def\testbody{FIRSTLINE\markright{M} \filler\ Now the last line of the paragraph, with its note\yieldnote{}.}'
check hboxlines x 9 '' kept,lonewarn \
  "$YF"'\def\testbody{\section{HEADINGX} \hbox{Listing line one}\hbox{Listing line two}\hbox{Listing line three} \par FIRSTLINE\yieldnote{} \filler\ \filler}'
# What is known of a heading ends with its page: a note at the same height on the
# next page is free.
check headshipped x 7 '' kept,lonewarn \
  "$YF"'\def\testbody{\section{HEADINGX} FIRSTLINE \oneline\par\newpage \noindent x\marginpar{TALLB\par\rule{1pt}{.97\textheight}} text\par\noindent\rule{1cm}{\dimexpr\textheight-52pt\relax}\par FIRSTLINE\yieldnote{} \filler\ \filler}'
check crosspages x 4 '' "$W" \
  '\def\testbody{FIRSTLINE \oneline\ more words\yieldnote{} \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler}'
check laterpara x 9 '' kept,lonewarn \
  "$YF"'\def\testbody{\section{HEADINGX} \filler\par FIRSTLINE\yieldnote{} \filler}'
check onelinepara x 4 '' kept,lonewarn \
  "$YF"'\def\testbody{FIRSTLINE\yieldnote{}\par \filler}'
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
# A note that misses the foot of the margin by at most two lines stays beside its
# line and runs past the foot of the margin, with a warning (over=N); by more it is
# carried (a margin note has no foot to go to).  The tall note at the top leaves
# about a line and a half of the margin, less the push.
OV='\def\testtall{.95}\def\testbody{FIRSTLINE \filler\ end\yieldnote[\par TWO\par THREE] \filler\par}'
OV1='\def\testtall{.975}\def\testbody{FIRSTLINE \filler\ end\yieldnote{} \filler\par}'
check overone x 9 '' over=1 "$OV1"
check overtwo x 9 '' over=2 "$OV"
# A footnote that misses the foot of the margin by a line or two goes to the foot when
# that holds it whole, without a warning (foot before overhang); a plain margin note
# has no version for the foot and runs over as above.
check footfirst1 x 9 '' "kept,noover,incol=NOTEY" '\def\testyieldfoot{}\def\testtall{.975}\def\testbody{FIRSTLINE \filler\ end\yieldnote{} \filler\par}'
check footfirst2 x 9 '' "kept,noover,incol=NOTEY" '\def\testyieldfoot{}\def\testtall{.95}\def\testbody{FIRSTLINE \filler\ end\yieldnote[\par TWO\par THREE] \filler\par}'
# Where the foot can't hold it whole (half a line of room there), it runs over the
# margin's foot as a plain note does.
check footfirstover x 4.5 '' "kept,over=1" '\def\testyieldfoot{}\def\testtall{.975}\def\testbody{FIRSTLINE \filler\ end\yieldnote{} \filler\ \filler\par}'
check overthree x 9 '' "carried,noover" '\def\testtall{.95}\def\testbody{FIRSTLINE \filler\ end\yieldnote[\par TWO\par THREE\par FOUR\par FIVE] \filler\par}'
# In carry mode (and draft) nothing runs over: the note is carried.
check overcarry x 9 'noteoverflow=carry' "carried,noover" "$OV"
# The allowance is for the column with the callout's line: when TeX's own break
# takes the line to the next page (it may not break between the line and the
# display under it), the note goes with it, and LOWX, three lines called out on
# the line above, is pushed up as ever, not run over (noover-LOWZ).  With TeX
# Live's marginfix 1.2 every line with a margin note may end a page (the kernel's
# penalty after the note, which margin-inrun takes away), so the line stays and
# NOTEY runs over there, as it may, with its warning (over=2 with 1.2).
check overguard x 4 '' "kept,noover-LOWZ${M12:+,over=2}" '\def\testtall{.9}\def\testbody{FIRSTLINE \filler\ more\marginpar{LOWX\par LOWY\par LOWZ} \oneline\ end\yieldnote[\par TWO\par THREE] \[ x = y \] after \filler\par}'
# The note decided to run over (it misses by a little, under A's tall note) goes with
# its line to the next page; there A and it don't fit together, and it is carried on:
# the warning says why, that its line went on (no reason of its own, as it wasn't
# carried where it was decided).
check overmoved x 4 '' "carried,exactwarn,reason=its line went on to page 2 after the note was placed for page 1" '\def\testfirst{\noindent\rule{1cm}{\dimexpr\textheight-2\baselineskip\relax}\par\noindent FIRSTLINE A\marginpar{AAA\par\rule{1pt}{400pt}} end\yieldnote[\par\rule{1pt}{190pt}\par SIX] \[ \begin{matrix} a\\ b\\ c\\ d \end{matrix} \] after \filler\par}'
# A small note after the one that runs over goes no lower: it is carried, not
# set in what is left below the foot.
check overlater x 9 '' "over=2,noover-SMALL" '\def\testtall{.95}\def\testbody{FIRSTLINE \filler\ end\yieldnote[\par TWO\par THREE]\marginpar{SMALL} \filler\par}'
# A float at the top of the page takes margin as well, and the warning says so.
check overfloat x 9 '' over=2 '\def\testtall{.85}\def\testbody{\begin{figure}[t]\rule{1cm}{3\baselineskip}\end{figure}FIRSTLINE \filler\ end\yieldnote[\par TWO\par THREE] \filler\par}'
# A margin float is no note: one that misses the foot of the margin by less than
# two lines is moved on by marginfix as ever, not run over (the decision to run
# over is for notes; a figure below the text block is another thing).
check overmfloat x 9 '' "carried,noover" '\def\testtall{.95}\def\testbody{FIRSTLINE \filler\ end\label{callout-y}\begin{marginfigure}\rule{1cm}{1pt}\caption{FIGX\label{note-y}}\end{marginfigure} \filler\par}'
# A note a little taller than the whole margin, alone at its top, is set whole and
# runs over, not split (marginfix's split of tall notes reads the same height).
check overtall x 9 '' "warned,nocontinued" '\def\testtall{1.01}\def\testbody{FIRSTLINE \filler\ end\yieldnote{} \filler\par}'
# A plain note taller than the margin, which marginfix splits: the split keeps the
# note's paragraph and drops the record at the top of its box, so the record net
# can't see it (a documented limit): no record of where it was printed, no "found
# from the last run" warning, and its first part on its callout's page.  (TeX Live's
# 1.2 doesn't split: it loses such a note, its label with it, and stops with
# "lost some margin notes", which names no note: the record net names it.)
check tallsplit x 3 '' "${NOT12:+kept,continued,recordless=1}${M12:+error=lost some margin notes,lostwarn=test-noteplace.tex,foundlast=1,recordless=1}" '\def\testtall{.1}\def\testbody{FIRSTLINE\yieldnote[\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler\par\filler] \filler\ \filler\par}'
# In two columns a note runs past the foot of its column's margin the same way.
check overtwocol x 9 '' kept,overwarn '\def\testclass{article}\def\testclassopt{a4paper,twocolumn}\def\testtall{.95}\def\testbody{FIRSTLINE end\yieldnote[\par TWO\par THREE] \filler\par}'
# A footnote that fits neither beside its line nor past the foot of the margin
# (the tall note runs over and fills it) goes to the foot of the page whole, or
# whole and one line past the foot; else it is carried, with a warning that
# says it doesn't fit at the foot whole (never split over two pages, #104).  k
# is the room at the foot in lines of the footnote, n its lines (one paragraph,
# broken by \break); with this text k = room - 4 (room 4.5: k = 0, but some
# room).
fn() { # fn <n> [<label> <first word>]: a footnote of n lines LINEA, LINEB, ...
  local l=${2:-note-y} w=${3:-LINE} t='' c=0 i
  for i in A B C D E F G H I J; do
    [ $c -ge $1 ] && break
    [ -n "$t" ] && t="$t\\hfil\\break "
    t="$t$w$i"; c=$((c + 1))
  done
  printf '\\footnote{\\label{%s}%s}' "$l" "$t"
}
fsbody() { # fsbody <footnote> [<after>]: the callout on the third line
  printf '\\def\\testtall{.99}\\def\\testbody{FIRSTLINE \\filler\\ end\\label{callout-y}%s \\filler\\ \\filler\\par}' "$1"
}
WH="reason=where it doesn't fit whole"
check fsk4n3 x 8 '' "kept,at=LINEA:1/LINEC:1,nobelow" "$(fsbody "$(fn 3)")"
check fsk3n5 x 7 '' "carried,$WH,nobelow,nocontinued" "$(fsbody "$(fn 5)")"
check fsk3n4 x 7 '' "kept,at=LINEA:1/LINED:1,below=LINED,footwarnpast" "$(fsbody "$(fn 4)")"
check fsk2n4 x 6 '' "carried,$WH,nobelow" "$(fsbody "$(fn 4)")"
check fsk2n3 x 6 '' "kept,at=LINEA:1/LINEC:1,below=LINEC,footwarnpast" "$(fsbody "$(fn 3)")"
check fsk1n2 x 5 '' "kept,at=LINEA:1/LINEB:1,below=LINEB,footwarnpast" "$(fsbody "$(fn 2)")"
check fsk1n3 x 5 '' "carried,$WH,nobelow" "$(fsbody "$(fn 3)")"
check fsk1n4 x 5 '' "carried,$WH,nobelow" "$(fsbody "$(fn 4)")"
# Five lines in 1.6 lines of room: carried, the reason counting the lines left.
check fsk1n5 x 5.6 '' "carried,$WH,reason=lines left there,nobelow" "$(fsbody '\footnote{\label{note-y}LINEA gy\hfil\break LINEB gy\hfil\break LINEC gy\hfil\break LINED gy\hfil\break LINEE gy}')"
check fsk0n1 x 4.5 '' "kept,at=LINEA:1,below=LINEA,footwarnpast" "$(fsbody "$(fn 1)")"
check fsk0n2 x 4.5 '' "carried,$WH,nobelow" "$(fsbody "$(fn 2)")"
# A later footnote on the page of one that was carried is carried too, after it,
# though it would fit at the foot: the footnotes keep their order (fstwo: called
# out on the same line); one after a footnote that runs past the foot is carried,
# the foot being full (fsspare: five lines in four lines of room, then a
# footnote of one line on the same line).
check fstwo x 6 '' "carried,$WH,reason=the footnotes keep their order,at=LINEA:2/SECA:2,order=LINED<SECA,nobelow" "$(fsbody "$(fn 4)$(fn 2 n-s SEC)")"
check fsspare x 8 '' "kept,at=LINEA:1/LINEE:1/SPAREA:2,below=LINEE,footwarnpast,reason=already runs past the foot" "$(fsbody "$(fn 5)$(fn 1 n-s SPARE)")"
# TeX takes the callout's line to the next page after its footnote went to this
# foot whole (a paragraph that can't break, whose last lines don't fit): the
# footnote goes with the line, and a warning says so (pullok; with marginfix 1.2
# the line stays, see overguard).
check fspull x 5 '' "pullok${NOT12:+,label=callout-y:2}" '\def\testtall{.99}\def\testbody{{\interlinepenalty=10000 \noindent FIRSTLINE\newline SECOND\newline THIRD\label{callout-y}'"$(fn 1)"'\newline FOURTH\newline FIFTH\par}}'
# fsfloat, fstall and fslabel are gone with the split (#104): a rest after a
# page of floats, a rest taller than the next page's foot, a label in a rest.
# In multicol's columns a margin footnote can't be set (the margin isn't beside
# a column there): it becomes an ordinary footnote, at the foot of the page,
# under the columns (mcolfoot).
MC='\def\testpre{\usepackage{multicol}}\def\testtall{.1}'
check mcolfoot x 20 '' "kept,at=MCOLNOTE:1,incol=MCOLNOTE" "$MC"'\def\testbody{\begin{multicols}{2}FIRSTLINE\label{callout-y}\footnote{\label{note-y}MCOLNOTE} \filler\ \filler\end{multicols}}'
# Any other margin note in multicols is lost, as in LaTeX, but with a warning.
check mcolnote x 20 '' "mcolwarn" "$MC"'\def\testbody{\begin{multicols}{2}FIRSTLINE\marginpar{MCOLMARGIN} \filler\ \filler\end{multicols}}'
# What marginfix puts in the margin for itself (\blockmargin, \unblockmargin) is no
# note of the user's: no warning there.
check mcolblock x 20 '' "nomcolwarn" "$MC"'\def\testbody{\begin{multicols}{2}FIRSTLINE \blockmargin\filler\ \unblockmargin\filler\end{multicols}}'
# Room in the margin that is reserved, not taken by notes: a float in the text
# with a side caption (rsvsidecap), and a passage whose text reaches into the
# margin between \blockmargin and \unblockmargin (rsvblock).  A note called out
# after them goes where marginfix finds room, or later with a warning, and never
# over what reserved the room.
NOTEL='NOTEY notea noteb notec noted notee notef noteg noteh notei notej notek notel notem noten noteo notep noteq noter notes'
check rsvsidecap x 30 '' "warned,apart=cap:note" "\\def\\testtall{.1}\\def\\testbody{\\begin{figure}[h]\\begin{sidecaption}{capa capb capc capd cape capf capg caph capi capj capk capl capm capn capo capp capq}\\rule{6cm}{5cm}\\end{sidecaption}\\end{figure}After the figure.\\label{callout-y}\\marginpar{$NOTEL\\label{note-y}} \\filler\\par}"
check rsvblock x 30 '' "warned,apart=WIDE:note" "\\def\\testtall{.1}\\def\\testbody{\\blockmargin\\begin{adjustwidth}{0pt}{-4cm}WIDEA \\filler\\ WIDEB \\filler\\ WIDEC \\filler\\end{adjustwidth}\\unblockmargin Then the note.\\label{callout-y}\\marginpar{$NOTEL\\label{note-y}} \\filler\\par}"
# A float with a side caption after a tall note called out before it on the page:
# the float gives way, so that the note stays beside its line (the float's rule,
# \@didactic@floatroom); without it the float took the margin and the note went on.
check rsvsidebefore x 30 '' "kept,apart=cap:note" "\\def\\testtall{.1}\\def\\testbody{\\noindent FIRSTLINE\\yieldnote[\\par\\rule{1pt}{.7\\textheight}] text.\\par\\filler\\par\\begin{figure}[h]\\begin{sidecaption}{capa capb capc capd cape capf capg caph capi capj capk capl capm capn capo capp}\\rule{6cm}{.35\\textheight}\\end{sidecaption}\\end{figure}After the figure. \\filler\\par}"
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
warm widowforbid warmdrop widow 7 '' widow "$YF"
warm headingoff warmback heading 7 '' heading
warm heading warmmoved heading 12 '' moved
warm moved warmmovedback heading 7 '' movedcold
W2='FIRSTLINE \filler\ Now the last line of the paragraph, with its note\yieldnote{}'
FB='\def\testpre{\AtBeginDocument{\widowpenalty=10000 }}'
check wforbid x 7 '' "$W,nowidow" "$FB\\def\\testbody{$W2.}"
check wfreecold x 7 '' kept,lonewarn "$YF$FB\\def\\testbody{$W2 and \\filler\\ \\filler}"
warm wforbid wfree x 7 '' wfreecold "$YF$FB\\def\\testbody{$W2 and \\filler\\ \\filler}"

# A note made in vertical mode after vertical space keeps the space (sameline
# took it out with the place to break, c3858d1 and b392e04): every line of the
# text (words VGL...) is where it is in the same document without the note
# (\testnonote): after a \vspace (vgapvspace), after the \addvspace at the end of
# an environment, a marginfigure (vgapenv), and a \thanks in a title (vgapthanks).
vgap() { # vgap <name> <body, where \vgnote{...} is the note>
  local name=$1 j=$job-$1
  [ -z "$CASES" ] || case " $CASES " in *" $name "*) ;; *) return;; esac
  local P='\def\testfirst{}\def\testpre{\newcommand\vgnote[1]{\ifdefined\testnonote\else##1\fi}}'
  if [ -z "$RECHECK" ]; then
    rm -f "$j.aux" "$j-ref.aux"
    settle "$j" x 9 '' "$P\\def\\testbody{$2}"; s1=$settled
    settle "$j-ref" x 9 '' "$P\\def\\testnonote{}\\def\\testbody{$2}"
    [ "$s1" = yes ] || settled=no
  else settled=yes; fi
  errors=$(cat "$j.log" "$j-ref.log" | grep -c '^!')
  if [ "$settled$errors" != yes0 ]; then
    echo "didactic noteplace test: $name FAIL (settled: $settled, errors: $errors)"; status=1; return
  fi
  if res=$(python3 - "$j.pdf" "$j-ref.pdf" <<'PY'
import re, subprocess, sys
def lines(pdf):
    out = subprocess.run(["pdftotext", "-bbox", pdf, "-"], capture_output=True, text=True).stdout
    return [(n, w, round(float(y), 1)) for n, pg in enumerate(re.findall(r"<page[^>]*>(.*?)</page>", out, re.S), 1)
            for y, w in re.findall(r'yMin="([\d.]+)"[^>]*>(VGL[A-Z]*)', pg)]
a, b = lines(sys.argv[1]), lines(sys.argv[2])
bad = [(x, y) for x, y in zip(a, b) if x != y]
if not a or len(a) != len(b) or bad:
    print("FAIL: lines moved against the document without the note:", bad[:4] or (len(a), len(b)))
    sys.exit(1)
print("PASS (%d lines where they are without the note)" % len(a))
PY
  ); then echo "didactic noteplace test: $name PASS $res"
  else echo "didactic noteplace test: $name FAIL $res"; status=1; fi
}
vgap vgapvspace '\noindent VGLA \filler\par\vspace{2\baselineskip}\vgnote{\marginpar{VGNOTE}}VGLB \filler\par VGLC \filler\par'
vgap vgapenv '\noindent VGLA \filler\begin{quote}VGLQ \filler\end{quote}\vgnote{\begin{marginfigure}\rule{1cm}{1cm}\caption{VGNFIG}\end{marginfigure}}VGLB \filler\par VGLC \filler\par'
vgap vgapthanks '\title{VGLT\vgnote{\thanks{VGNOTE in the title.}}}\author{VGLAU}\date{VGLD}\maketitle VGLB \filler\par VGLC \filler\par'

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
