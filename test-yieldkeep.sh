#!/bin/bash
# Check test-yieldkeep.tex: a page must not end early for a margin note where
# that parts a heading from the lines it is owed, or leaves a lone line that the
# document forbids; the note is then capped, with a warning that says why.
# A lone line the document allows stays, with a warning.
# Calls pdflatex itself (or $ENGINE, with the cases in $CASES): only there can a
# page end early.  Each job runs until
# its .aux file stops changing and the last run asks for no other.
job=test-yieldkeep
status=0
grep -q 'MFX@fit@peek' "$(kpsewhich marginfix.sty)" || {
  echo "didactic yieldkeep test: FAIL: marginfix is too old, this needs its" \
    "integration branch, https://github.com/dbosk/marginfix"; exit 1; }
ENGINE=${ENGINE:-pdflatex}
run() { # <job> <case> <room> <options> <definitions>
  $ENGINE -shell-escape -interaction=nonstopmode -jobname="$1" \
    "$5\\def\\testcase{$2}\\def\\testroom{$3}\\def\\testoptions{$4}\\input{$job}" \
    > /dev/null
}
settle() { # as run, on the .aux file there is
  settled=no
  for i in 1 2 3 4 5 6 7 8; do
    [ -f "$1.aux" ] && cp "$1.aux" "$1.aux.old"
    run "$@"
    if [ -f "$1.aux.old" ] && cmp -s "$1.aux" "$1.aux.old" \
       && ! grep -q 'may have changed' "$1.log"; then
      settled=yes; return
    fi
  done
}
# check <name> <case> <room> <options> <expect> [<definitions>]: expect is
#   yield       the page ends early for the note, and nothing warns about a line;
#   hold:<word> it doesn't, the note is capped, and didactic's warning has <word>.
#   limit       it doesn't, because of the limit, and the warning says so;
#   parted      the page ends right under the heading;
#   clean       it settles with no errors, and a note was split;
#   warnlone:<word> the page ends early, and a warning has <word>.
check() {
  name=$1; j=$job-$name
  [ -z "$CASES" ] || case " $CASES " in *" $name "*) ;; *) return;; esac
  rm -f "$j.aux" "$j.pdf"
  settle "$j" "$2" "$3" "$4" "$6"
  errors=$(grep -c '^!' "$j.log")
  yields=$(grep -c '^marginfix-yield: page=[0-9]* before' "$j.log")
  capped=$(grep -c '^marginfix-spill: .* capped$' "$j.log")
  unresolved=$(grep -c '^marginfix-spill: .* unresolved$' "$j.log")
  told=$(grep -c 'its page early would\|early for another note' "$j.log")
  limit=$(grep -c 'marginnoteyieldlimit keeps page' "$j.log")
  lone=$(grep -c 'line alone\|tell if that leaves' "$j.log")
  p1=$(pdftotext -f 1 -l 1 "$j.pdf" - 2>/dev/null)
  head1=$(printf '%s\n' "$p1" | grep -c 'HEADINGX')
  first1=$(printf '%s\n' "$p1" | grep -c 'FIRSTLINE')
  state="settled: $settled, errors: $errors, early ends: $yields, capped: $capped,"
  state="$state unresolved: $unresolved, told: $told, limit: $limit, lone: $lone, heading on p1: $head1,"
  state="$state first line on p1: $first1"
  ok=no
  if [ "$settled$errors$unresolved" = yes00 ]; then
    case $5 in
      hold:*)
        grep -q "${5#hold:}" "$j.log" && [ "$yields" = 0 ] && [ "$capped" -gt 0 ] \
          && [ "$first1" -gt 0 ] && [ "$limit" = 0 ] && ok=yes;;
      yield)
        [ "$yields" -gt 0 ] && [ "$capped$told$lone" = 000 ] && ok=yes;;
      limit)
        [ "$yields" = 0 ] && [ "$capped" -gt 0 ] && [ "$limit" = "$capped" ] && ok=yes;;
      parted)
        [ "$yields" -gt 0 ] && [ "$head1" -gt 0 ] && [ "$first1" = 0 ] && ok=yes;;
      clean)
        grep -q 'split at the end of page' "$j.log" && ok=yes;;
      warnlone:*)
        grep -q "${5#warnlone:}" "$j.log" && [ "$yields" -gt 0 ] && ok=yes;;
    esac
  fi
  if [ "$ok" = yes ]; then
    echo "didactic yieldkeep test: $name PASS ($state)"
  else
    echo "didactic yieldkeep test: $name FAIL, wanted $5 ($state)"; status=1
  fi
}
parted='a heading from what follows'
first='first line alone'
last='last line alone'
cant='tell if that leaves'
check heading heading 7 '' "hold:$parted"
check stacked stacked 9 '' "hold:$parted"
check headlist headlist 7 '' "hold:$parted"
check headthm headthm 7 '' "hold:$parted"
check withother withother 8 '' "hold:another note"
check tallheading tallheading 11 '' "hold:$parted"
check tallclub tallclub 4 '' "warnlone:$cant"
check tallwidow tallwidow 8 '' "warnlone:$cant"
check tallmiddle tallmiddle 9 '' "warnlone:$cant"
check second second 9 '' "hold:$parted"
check vertical vertical 7 '' "hold:$parted"
check headingzero heading 7 'noteyieldmaxgap=0' "hold:$parted"
check headingoff heading 7 'keepafterheading=0' parted
check runin runin 4 '' yield
check theorem theorem 4 '' yield
check runintwo runintwo 7 '' "hold:$parted"
check club club 4 '' "warnlone:$first"
check widow widow 7 '' "warnlone:$last"
check clubforbid clubforbid 4 '' "hold:$first"
check widowforbid widowforbid 7 '' "hold:$last"
check clubzero clubforbid 4 'noteyieldmaxgap=0' "warnlone:$first"
check middle middle 9 '' yield
check split split 4 '' clean

# What the walk over the page's lines got wrong: these must come out right now.
Y='\marginpar{NOTEY\par\rule{1pt}{.3\textheight}}'
T='\def\testtall{.75}'
L="Now the LASTLINE of the paragraph, with its note$Y."
ART='\def\testclass{article}'
H='\section{HEADINGX} FIRSTLINE\yieldnote{} \filler\ \filler'
check foothead x 7 '' "hold:$parted" "$ART\\def\\testfootnotefirst{}\\def\\testbody{$H}"
check footlone x 7 '' "warnlone:$last" \
  "$ART\\def\\testfootnotefirst{}\\def\\testbody{FIRSTLINE \\filler\\ Now the last line of the paragraph, with its note\\yieldnote{}.}"
check noteearlier x 7 '' "warnlone:$last" \
  "$T\\def\\testbody{FIRSTLINE\\marginpar{SHORT} \\filler\\ $L}"
check footinpara x 5 '' yield \
  "$T\\def\\testbody{FIRSTLINE\\footnote{FOOTB} \\oneline\\ second \\oneline\\ more words$Y \\filler\\ \\filler}"
check headfoot x 10 '' yield \
  "$T\\def\\testbody{\\section{HEADINGX} FIRSTLINE\\footnote{FOOTB} \\oneline\\ second \\oneline\\ more words$Y \\filler\\ \\filler}"
check display x 10 '' "warnlone:$cant" \
  '\def\testbody{FIRSTLINE \oneline\ two. \[ x=y \] after DISPLAY \filler\ Now the LASTLINE of the paragraph, with its note\yieldnote{}.}'
check newline x 7 '' "warnlone:$cant" \
  '\def\testbody{FIRSTLINE \\[6pt] \filler\ Now the LASTLINE of the paragraph, with its note\yieldnote{}.}'
check markright x 7 '' "warnlone:$last" \
  '\def\testbody{FIRSTLINE\markright{M} \filler\ Now the last line of the paragraph, with its note\yieldnote{}.}'
check hboxlines x 9 '' yield \
  '\def\testbody{\section{HEADINGX} \hbox{Listing line one}\hbox{Listing line two}\hbox{Listing line three} \par FIRSTLINE\yieldnote{} \filler\ \filler}'
# What is known of a heading ends with its page: a note at the same height on the
# next page is free.
check headshipped x 7 '' yield \
  '\def\testbody{\section{HEADINGX} FIRSTLINE \oneline\par\newpage \noindent x\marginpar{TALLB\par\rule{1pt}{.97\textheight}} text\par\noindent\rule{1cm}{\dimexpr\textheight-52pt\relax}\par FIRSTLINE\yieldnote{} \filler\ \filler}'
# Survivors of the review's mutants.
check crosspages x 4 '' "warnlone:$first" \
  '\def\testbody{FIRSTLINE \oneline\ more words\yieldnote{} \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler\ \filler}'
check laterpara x 9 '' yield \
  '\def\testbody{\section{HEADINGX} \filler\par FIRSTLINE\yieldnote{} \filler}'
check onelinepara x 4 '' yield \
  '\def\testbody{FIRSTLINE\yieldnote{}\par \filler}'
check verticaldue x 7 '' "hold:$parted" \
  '\def\testbody{\section{HEADINGX} FIRSTLINE.\par\yieldnote{}\par SECONDPARA \filler}'

# A warm build must come to what a cold one does.  warm <from> <job> <case> <room>
# <options> <cold job> [<definitions>]: settles <job> from the .aux file of <from>
# and compares its log lines of marginfix and its text with those of <cold job>.
warm() {
  [ -z "$CASES" ] || case " $CASES " in *" $2 "*) ;; *) return;; esac
  j=$job-$2; c=$job-$6
  cp "$job-$1.aux" "$j.aux"; rm -f "$j.pdf"
  settle "$j" "$3" "$4" "$5" "$7"
  if [ "$settled" = yes ] \
     && diff <(grep '^marginfix-\(spill\|yield\)' "$j.log") \
             <(grep '^marginfix-\(spill\|yield\)' "$c.log") >/dev/null \
     && diff <(pdftotext -layout "$j.pdf" -) <(pdftotext -layout "$c.pdf" -) >/dev/null \
     && [ "$(grep -c 'its page early would' "$j.log")" = "$(grep -c 'its page early would' "$c.log")" ]
  then
    echo "didactic yieldkeep test: $2 PASS (warm from $1, as $6)"
  else
    echo "didactic yieldkeep test: $2 FAIL (warm from $1, not as $6; settled: $settled)"
    status=1
  fi
}
check moved heading 12 '' limit
check movedcold heading 7 '' "hold:$parted"
warm heading warmoff heading 7 'keepafterheading=0' headingoff
warm heading warmzero heading 7 'noteyieldmaxgap=0' headingzero
warm widowforbid warmdrop widow 7 '' widow
warm headingoff warmback heading 7 '' heading
warm heading warmmoved heading 12 '' moved
warm moved warmmovedback heading 7 '' movedcold

# With a marginfix that can't do this, we say so.
check oldmarginfix heading 7 '' 'warnlone:With this marginfix' \
  '\def\testpre{\expandafter\let\expandafter\testkeep\csname MFX@fit@peek\endcsname \expandafter\let\csname MFX@fit@peek\endcsname\undefined \AtBeginDocument{\expandafter\let\csname MFX@fit@peek\endcsname\testkeep}}'

rm -f "$job-slides.aux"
$ENGINE -shell-escape -interaction=nonstopmode "$job-slides" > /dev/null
errors=$(grep -c '^!' "$job-slides.log")
if [ "$errors" = 0 ]; then
  echo "didactic yieldkeep test: slides PASS"
else
  echo "didactic yieldkeep test: slides FAIL ($errors errors)"; status=1
fi
exit $status
