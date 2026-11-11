#!/bin/bash
# Run the cases of test-noteplace.tex and check each by its outcome
# (test-noteplace.py): where the note NOTEY goes, and what that does to a heading
# and to a paragraph's first and last lines.  These are the cases of
# test-yieldkeep (fix-68), whose checks read marginfix's log lines; the intent of
# each is kept, the checks are the PDF, the labels and the warnings.
#
# Each job runs until its .aux file stops changing (at most $MAXRUNS runs, 8);
# a job that doesn't settle, or has an error, fails.  Runs to settle are a
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
# option noteyieldmaxgap is now notemaxgap.
job=test-noteplace
status=0
ENGINE=${ENGINE:-pdflatex}
MAXRUNS=${MAXRUNS:-8}
run() { # <job> <case> <room> <options> <definitions>
  $ENGINE -shell-escape -interaction=nonstopmode -jobname="$1" \
    "${PRE}$5\\def\\testcase{$2}\\def\\testroom{$3}\\def\\testoptions{$4}\\input{$job}" \
    > /dev/null 2>&1
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
check headingzero heading 7 'notemaxgap=0' "$W,together,limitwarn"
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
check clubzero clubforbid 4 'notemaxgap=0' "$W,noclub,limitwarn"
# Nothing in the way: the note stays with its line.
check runin runin 4 '' kept,lonewarn
check theorem theorem 4 '' kept,lonewarn
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
check headfoot x 10 '' "kept,together,lonewarn" \
  "$T\\def\\testbody{\\section{HEADINGX} FIRSTLINE\\footnote{FOOTB} \\oneline\\ second \\oneline\\ more words$Y \\filler\\ \\filler}"
check display x 10 '' "$W" \
  '\def\testbody{FIRSTLINE \oneline\ two. \[ x=y \] after DISPLAY \filler\ Now the LASTLINE of the paragraph, with its note\yieldnote{}.}'
check newline x 7 '' "$W" \
  '\def\testbody{FIRSTLINE \\[6pt] \filler\ Now the LASTLINE of the paragraph, with its note\yieldnote{}.}'
check markright x 7 '' "$W" \
  '\def\testbody{FIRSTLINE\markright{M} \filler\ Now the last line of the paragraph, with its note\yieldnote{}.}'
check hboxlines x 9 '' kept,lonewarn \
  '\def\testbody{\section{HEADINGX} \hbox{Listing line one}\hbox{Listing line two}\hbox{Listing line three} \par FIRSTLINE\yieldnote{} \filler\ \filler}'
# What is known of a heading ends with its page: a note at the same height on the
# next page is free.
check headshipped x 7 '' kept,lonewarn \
  '\def\testbody{\section{HEADINGX} FIRSTLINE \oneline\par\newpage \noindent x\marginpar{TALLB\par\rule{1pt}{.97\textheight}} text\par\noindent\rule{1cm}{\dimexpr\textheight-52pt\relax}\par FIRSTLINE\yieldnote{} \filler\ \filler}'
check crosspages x 4 '' "$W" \
  '\def\testbody{FIRSTLINE \oneline\ more words\yieldnote{} \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler}'
check laterpara x 9 '' kept,lonewarn \
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
check laterhead2 x 9 'notemaxgap=12' "$W,together" \
  "\\def\\testbody{\\section{HEADINGX} FIRSTLINE\\yieldnote{}\\par\\section{HEADB} Words \\filler\\ \\filler}"
M='\noindent x\marginpar{TALL\par\rule{1pt}{.97\textheight}}'
check movedfloat x 7 '' "$W,together" \
  "\\def\\testfirst{$M\\marginpar{TALLB\\par\\rule{1pt}{.2\\textheight}} text\\par\\noindent\\rule{1cm}{\\dimexpr\\textheight-5\\baselineskip\\relax}\\par\\begin{figure}[t]\\rule{1cm}{.84\\textheight}\\end{figure}}\\def\\testbody{\\section{HEADINGX} FIRSTLINE$B}"
check movedzero x 7 'notemaxgap=0' "$W,together" \
  "\\def\\testfirst{$M\\marginpar{TALLB\\par\\rule{1pt}{.97\\textheight}} text\\par\\noindent\\rule{1cm}{\\dimexpr\\textheight-5\\baselineskip\\relax}\\par}\\def\\testbody{\\section{HEADINGX} FIRSTLINE$B}"
check tallmark x 11 '' "$W,together" \
  "\\def\\testbody{\\section{HEADINGX} \\rule{0pt}{4\\baselineskip} FIRSTLINE\\markright{M}$B}"
check nopagebreak x 5 '' "$W,tied" \
  "\\def\\testbody{Lead LEADIN\\nopagebreak\\par\\nopagebreak FIRSTLINE$B}"
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
warm heading warmzero heading 7 'notemaxgap=0' headingzero
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
