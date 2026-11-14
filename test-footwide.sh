#!/bin/bash
# Builds test-footwide.tex in each of its cases, under pdfLaTeX, XeLaTeX and
# LuaLaTeX, and with hyperref under pdfLaTeX, and checks each with
# test-footwide.py: a footnote at the foot is set in the width of the text, its
# text runs once, and the footnotes found not plain are those the case
# declares.  $MARGINFIX: a directory with the marginfix.sty to test against, put
# first on TEXINPUTS; unset, the one found.  $CASES: only these.
src=test-footwide
status=0
ALL='plain cite url prepost reuse twopar mixed color linewidth list display parbox vspace huge longsix rigid oneline beyond longthree bs fnmark lang'
[ -n "$MARGINFIX" ] && export TEXINPUTS="$(cd "$MARGINFIX" && pwd)//:$TEXINPUTS"
job() { # <engine> <case> [<definitions>]
  local eng=$1 c=$2 defs=$3 j=$src-$1-$2${3:+-h}
  [ -z "$CASES" ] || case " $CASES " in *" $c "*) ;; *) return;; esac
  rm -f "$j.aux"
  for i in 1 2 3; do
    timeout 200 $eng -interaction=nonstopmode -jobname="$j" \
      "\\def\\testcase{$c}$defs\\input{$src}" > /dev/null 2>&1
    [ $i = 1 ] && [ -f "$j.bcf" ] && biber -q "$j" > /dev/null 2>&1
  done
  if [[ " lang rigid oneline beyond " == *" $c "* ]]; then
    for i in 1 2 3; do
      timeout 200 $eng -interaction=nonstopmode -jobname="$j-ref" \
        "\\def\\testcase{$c}\\def\\testref{}$defs\\input{$src}" > /dev/null 2>&1
    done
  fi
  if res=$(python3 $src.py "$j" "$c"); then
    echo "didactic footwide test: $eng $c${3:+ hyperref} PASS"
  else
    echo "didactic footwide test: $eng $c${3:+ hyperref} $res"; status=1
  fi
}
for eng in pdflatex xelatex lualatex; do
  for c in $ALL; do job $eng $c; done
done
for c in $ALL; do
  job pdflatex $c '\def\testhyper{}'
done
exit $status
