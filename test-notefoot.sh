#!/bin/bash
# Run the cases of test-notefoot.tex and check each by its outcome with
# test-notefoot.py.  These are the cases of marginfix's footcheck (margin-foot
# branch), which checked marginfix's log lines; here the footnotes are didactic's
# and the checks are the labels, saved positions, PDF and warnings.  Each job runs
# until its .aux file stops changing and LaTeX asks for no other run, within the
# runs a case allows; and runs to settle are a requirement: each job is built
# again with noteoverflow=carry (\testfloor, job <job>-floor), which moves no note
# for a page that ends early, and may take at most one run more than that floor.
# $ENGINE (pdflatex), $CASES (job names) and $PRE (TeX code put first, to load
# another implementation, say) can be set; RECHECK=1 checks the jobs there are.
#
# Dropped from footcheck, as they test a mechanism, not an outcome: firstrun (the
# fork's message that the notes haven't settled), local (\marginnoteoverflow in a
# group, marginfix's), lastlimit, footrec, stale and limit (yield records and
# \marginnoteyieldlimit; the limit is keepmaxgap now: test-noteplace's lastlimit
# and lastroom are the limit honoured for a note on the last lines of a page).
src=test-notefoot
status=0
# $MARGINFIX: a directory with the marginfix.sty to test against, put first on
# TEXINPUTS; unset, the one found.
# TeX Live's tools (multicol) before anything else but that marginfix: a texmf
# tree may have an older multicol (one machine had noweb's of 1992 first).
TOOLS=$(kpsewhich -var-value=TEXMFDIST)/tex/latex/tools
export TEXINPUTS="$TOOLS:$TEXINPUTS"
[ -n "$MARGINFIX" ] && export TEXINPUTS="$(cd "$MARGINFIX" && pwd)//:$TEXINPUTS"
ENGINE=${ENGINE:-pdflatex}
TEXTIMEOUT=${TEXTIMEOUT:-120}  # seconds: a run that takes longer never ends
settle() { # <job> <maxruns> <definitions>; sets $settled and $runs
  rm -f "$1.aux"; settled=no
  for runs in $(seq 1 "$2"); do
    [ -f "$1.aux" ] && cp "$1.aux" "$1.aux.old"
    timeout "$TEXTIMEOUT" $ENGINE -shell-escape -interaction=nonstopmode -jobname="$1" \
      "${PRE}$3\\input{$src}" > /dev/null 2>&1
    # a run that never ends fails as an error
    [ $? = 124 ] && printf "\n! the run took more than %s s\n" "$TEXTIMEOUT" >> "$1.log"
    if [ -f "$1.aux.old" ] && cmp -s "$1.aux" "$1.aux.old" \
       && ! grep -q 'Rerun to get\|may have changed' "$1.log"; then
      settled=yes; return
    fi
  done
}
job() { # <name> <maxruns> <definitions> <checks...>
  name=$1 max=$2 defs=$3; shift 3
  [ -z "$CASES" ] || case " $CASES " in *" $name "*) ;; *) return;; esac
  j=$src-$name settled=yes runs=- floor=-
  if [ -z "$RECHECK" ]; then
    settle "$j-floor" "$max" "\\def\\testfloor{}$defs"; floor=$runs
    settle "$j" "$max" "$defs"
  fi
  errors=$(grep -c '^!' "$j.log")
  if [ "$settled$errors" != yes0 ]; then
    echo "didactic notefoot test: $name FAIL (settled within $max runs: $settled, errors: $errors)"
    status=1; return
  fi
  if [ "$floor" != - ] && [ "$runs" -gt $((floor + 1)) ]; then
    echo "didactic notefoot test: $name FAIL ($runs runs, floor $floor)"
    status=1; return
  fi
  if res=$(python3 $src.py "$j" "$@"); then
    echo "didactic notefoot test: $name PASS ($runs runs, floor $floor) $res"
  else
    echo "didactic notefoot test: $name FAIL ($runs runs) $res"; status=1
  fi
}
C='\def\testcase'
job dense 4 "$C{dense}" foot beside nofalse
job carry 4 "$C{dense}\\def\\testoptions{noteoverflow=carry}" nofoot nofalse \
  pagesge=$src-dense
job article 4 "$C{dense}\\def\\testclass{article}" foot beside nofalse
# In two columns the notes beside the first column are within the text block,
# so where a note is can't tell foot from margin; foot works as carry there,
# with a warning only when asked for.
job twocol 8 "$C{dense}\\def\\testclassopt{twocolumn}"
job twofoot 8 "$C{dense}\\def\\testclassopt{twocolumn}\\def\\testoptions{noteoverflow=foot}" \
  'works=noteoverflow=foot works as'
# In multicols a footnote goes to the foot of the page, under the columns, as
# multicol sets footnotes; it may put one at the foot of the page before its
# mark's, and then didactic warns, from records of the run before (note 8 here).
job multi 8 "$C{multi}" foot order
job hyper 4 "$C{hyper}" foot beside nodest nofalse
job counter 4 "$C{counter}" foot beside counter nofalse
job nofeet 4 "$C{nofeet}" nofoot beside nofalse
job drift 4 "$C{drift}" beside nofalse
job lastline 4 "$C{lastline}" beside nofalse
for c in botfloat topfloat clear; do job $c 4 "$C{$c}" foot beside nofalse; done
job deferr-defer 4 "$C{deferr}\\def\\testprio{defer}" nofoot beside
job deferr-split 4 "$C{deferr}\\def\\testprio{split}" nofoot beside
job deferr-warn 4 "$C{deferr}\\def\\testprio{warn}" beside
job order 4 "$C{order}" foot beside order nofalse
job minroom 4 "$C{minroom}" nofoot floatsonly
job fnrule 4 "$C{fnrule}" foot rules beside
job fnrule10 4 "$C{fnrule}\\def\\testfnrulelines{10}" foot rules beside
job fnedge 4 "$C{fnedge}" rules beside
job tall 8 "$C{tall}" foot beside nofalse
job gen 4 "$C{gen}" beside
job ownout 8 "$C{ownout}"
# Two notes taller than the room left, and a footnote: settled within the floor
# and one run, each placed or warned about; under XeLaTeX too (review B-1).
job twotall 8 "$C{twotall}"
ENGINE=xelatex job twotall-xe 8 "$C{twotall}"
# A footnote at the foot meets the kernel's special output (review B1, B3, the
# reviewer's reproducers, test-notefoot-reins.tex): it stays at the foot of its
# line's page or is warned about, the foot is counted (no page overfull in the
# output, no words on top of each other), on letter paper, with the number of
# lines before the place that made it go wrong on 8993750 under pdfLaTeX.
R='\def\testclassopt{letterpaper}\def\testN'
job reins 4 "$C{reins}${R}{40}" beside nofalse nooverfull nooverlap
job reinsmix 4 "$C{reinsmix}${R}{39}" nofalse nooverfull nooverlap
job wait 4 "$C{wait}${R}{40}" nofalse nooverfull nooverlap
job mcol3x 4 "$C{mcol3x}${R}{34}" nofalse nooverfull nooverlap
job mcol3 4 "$C{mcol3}${R}{34}" nofalse nooverfull nooverlap
job mcol3n 4 "$C{mcol3n}${R}{34}" nofalse nooverfull nooverlap
job mcol3nm 4 "$C{mcol3n}${R}{34}\\def\\testmulticols{}" nofalse nooverfull nooverlap
# Cases still placed wrong, each said by the net (review P2, P1): the second note of
# a line went on with its mark after a heading (found from the last run, by the
# records), and a rest put back after a later line (said when the next column is
# made).  They stay with these expectations until their layouts are fixed.
job waitsec 4 "$C{waitsec}${R}{36}" nooverfull nooverlap foundlast=1
job rest2 4 "$C{rest2}${R}{40}\\def\\testK{39}" nooverfull nooverlap 'works=reach the foot'
exit $status
