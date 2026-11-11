#!/bin/bash
# Build test-footreuse-spread.tex in its cases, under article (notes at the foot)
# and memoir (notes in the margin), and check each by its outcome with
# test-footreuse-spread.py.  Each job runs biber after its first run, then runs
# until its .aux file stops changing and LaTeX asks for no other run (at most
# $MAXRUNS, 8: not settling fails).  $ENGINE (pdflatex), $CASES (job names) and
# $PRE (TeX code put first, to load another implementation, say) can be set.
src=test-footreuse-spread
status=0
ENGINE=${ENGINE:-pdflatex}
MAXRUNS=${MAXRUNS:-8}
job() { # <name> <definitions> [<arguments of test-footreuse-spread.py>]
  [ -z "$CASES" ] || case " $CASES " in *" $1 "*) ;; *) return;; esac
  j=$src-$1; rm -f "$j.aux" "$j.bbl"
  settled=no
  for i in $(seq 1 "$MAXRUNS"); do
    [ -f "$j.aux" ] && cp "$j.aux" "$j.aux.old"
    $ENGINE -shell-escape -interaction=nonstopmode -jobname="$j" \
      "${PRE}$2\\input{$src}" > /dev/null 2>&1
    [ "$i" = 1 ] && { biber "$j" > /dev/null 2>&1; continue; }
    if cmp -s "$j.aux" "$j.aux.old" && ! grep -q 'Rerun to get\|may have changed' "$j.log"
    then settled=yes; break; fi
  done
  errors=$(grep -c '^!' "$j.log")
  if [ "$settled$errors" != yes0 ]; then
    echo "didactic footreuse spread test: $1 FAIL (settled: $settled, errors: $errors)"
    status=1; return
  fi
  if res=$(python3 $src.py "$j" $3); then
    echo "didactic footreuse spread test: $1 PASS ($i runs) $res"
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
exit $status
