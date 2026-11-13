#!/bin/bash
# Build test-footreuse-spread.tex in its cases, under article (notes at the foot)
# and memoir (notes in the margin), and check each by its outcome with
# test-footreuse-spread.py.  Each job runs biber after its first run, then runs
# until its .aux file stops changing and LaTeX asks for no other run (at most
# $MAXRUNS, 8: not settling fails).  Runs to settle are a requirement: each job is
# built again with noteoverflow=carry (\testfloor, job <job>-floor), which places
# no note but beside its line or on a later page, and may take at most two runs
# more than that floor, as these rows are about reuse: the number of a reusing mark may change
# a run after the note it reuses moves.  $ENGINE (pdflatex), $CASES (job names) and
# $PRE (TeX code put first, to load another implementation, say) can be set.
src=test-footreuse-spread
status=0
declare -A floors
# $MARGINFIX: a directory with the marginfix.sty to test against, put first on
# TEXINPUTS; unset, the one found.
[ -n "$MARGINFIX" ] && export TEXINPUTS="$(cd "$MARGINFIX" && pwd)//:$TEXINPUTS"
ENGINE=${ENGINE:-pdflatex}
MAXRUNS=${MAXRUNS:-8}
settle() { # <job> <definitions>; sets $settled and $i, the runs
  rm -f "$1.aux" "$1.bbl"
  settled=no
  for i in $(seq 1 "$MAXRUNS"); do
    [ -f "$1.aux" ] && cp "$1.aux" "$1.aux.old"
    $ENGINE -shell-escape -interaction=nonstopmode -jobname="$1" \
      "${PRE}$2\\input{$src}" > /dev/null 2>&1
    [ "$i" = 1 ] && { biber "$1" > /dev/null 2>&1; continue; }
    if cmp -s "$1.aux" "$1.aux.old" && ! grep -q 'Rerun to get\|may have changed' "$1.log"
    then settled=yes; return; fi
  done
}
job() { # <name> <definitions> [<arguments of test-footreuse-spread.py>]
  [ -z "$CASES" ] || case " $CASES " in *" $1 "*) ;; *) return;; esac
  j=$src-$1
  settle "$j-floor" "\\def\\testfloor{}$2"; floor=$i; floors[$1]=$i
  settle "$j" "$2"
  errors=$(grep -c '^!' "$j.log")
  if [ "$settled$errors" != yes0 ]; then
    echo "didactic footreuse spread test: $1 FAIL (settled: $settled, errors: $errors)"
    status=1; return
  fi
  if [ "$i" -gt $((floor + 2)) ]; then
    echo "didactic footreuse spread test: $1 FAIL ($i runs, floor $floor)"
    status=1; return
  fi
  if res=$(python3 $src.py "$j" $3); then
    echo "didactic footreuse spread test: $1 PASS ($i runs, floor $floor) $res"
  else
    echo "didactic footreuse spread test: $1 FAIL ($i runs) $res"; status=1
  fi
}
job same '\def\testcase{same}' reused
job same-memoir '\def\testcase{same}\def\testclass{memoir}' reused
job cross '\def\testcase{cross}'
job cross-memoir '\def\testcase{cross}\def\testclass{memoir}'
# Only at the foot does the tall note take its line along to page 4.
job parted '\def\testcase{parted}' last=4
# A note counts as on the page where it starts: split over pages 3 and 4, it is
# reused on page 3 and set again on page 4.
job splitreuse '\def\testcase{splitreuse}\def\testclass{memoir}'
job splitrest '\def\testcase{splitrest}\def\testclass{memoir}' last=4
# A note that runs past the foot of the margin is on its page: reused there.
job overreuse '\def\testcase{overreuse}\def\testclass{memoir}'
# A note that waits for the next page or is carried there is reused by a
# second citation on its mark's page: both marks before the note, in order.
job waitreuse '\def\testcase{waitreuse}\def\testclass{memoir}' 'next shared warned reusenamed'
job carryreuse '\def\testcase{carryreuse}\def\testclass{memoir}' 'next shared warned reusenamed'
# Numbers restart in each chapter: a carried note names no mark of another
# chapter's note with its number (review S2).
job chapreuse '\def\testcase{chapreuse}\def\testclass{memoir}' 'next warned noreusenamed'
# Warm: each job built again from the .aux (and .bbl) of another case, as after
# an edit, must settle on the same PDF as from clean, in at most two runs more
# than its floor (#93: a settled result that depends on an old .aux).
warm() { # warm <from> <name> <definitions>
  [ -z "$CASES" ] || case " $CASES " in *" warm-$2 "*) ;; *) return;; esac
  j=$src-warm-$2
  cp "$src-$1.aux" "$j.aux"; cp "$src-$1.bbl" "$j.bbl" 2>/dev/null
  settled=no
  for i in $(seq 1 "$MAXRUNS"); do
    cp "$j.aux" "$j.aux.old"
    $ENGINE -shell-escape -interaction=nonstopmode -jobname="$j" \
      "${PRE}$3\\input{$src}" > /dev/null 2>&1
    [ "$i" = 1 ] && { biber "$j" > /dev/null 2>&1; continue; }
    if cmp -s "$j.aux" "$j.aux.old" && ! grep -q 'Rerun to get\|may have changed' "$j.log"
    then settled=yes; break; fi
  done
  if [ "$settled" = yes ] && [ "$i" -le $(( ${floors[$2]:-$MAXRUNS} + 2 )) ] \
     && diff <(pdftotext -layout "$j.pdf" -) <(pdftotext -layout "$src-$2.pdf" -) >/dev/null
  then
    echo "didactic footreuse spread test: warm-$2 PASS (from $1, $i runs, floor ${floors[$2]})"
  else
    echo "didactic footreuse spread test: warm-$2 FAIL (from $1, settled: $settled, $i runs, floor ${floors[$2]})"
    status=1
  fi
}
warm parted same '\def\testcase{same}'
warm same parted '\def\testcase{parted}'
warm splitrest splitreuse '\def\testcase{splitreuse}\def\testclass{memoir}'
warm splitreuse splitrest '\def\testcase{splitrest}\def\testclass{memoir}'
warm carryreuse waitreuse '\def\testcase{waitreuse}\def\testclass{memoir}'
exit $status
