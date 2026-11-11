#!/bin/bash
# Build test-noteoverflow-foot.tex in its variants and check each with
# test-noteoverflow-foot.py.  Each job runs biber after its first run, then runs
# until its .aux file stops changing and LaTeX asks for no other run (at most
# twelve runs).  CASES, if set, names the jobs to run.
#
#   default  pdflatex, no options: the default is foot
#   break    pdflatex, noteoverflow=break: nothing at the foot, notes capped away
#            from their marks, and the same words
#   hyper    pdflatex, with hyperref: no warning about a link target
#   fast     pdflatex, footnotereuse=fast, whose ghost notes need a foot too
#   off      pdflatex, footnotereuse=off
#   draft    pdflatex, draft: the default is carry, nothing at the foot (and
#            footnotereuse=off, so no labels)
#   lua      lualatex
#   xe       xelatex: notes go to the foot; what fits nowhere is carried, away
#            from its mark, with a warning that says why
#   trad, tradbreak         style=verbose-trad2 (ibid., op. cit., idem), foot and
#                           break, with the same words
#   counter, counterbreak   citecounter=true, each citation saying whether it is
#                           cited more than once, the same words
#   backref, backrefbreak   backref=true and a bibliography, which lists where a
#                           work is cited: a copy that isn't printed adds no page
#                           (biblatex's records in the .aux, counted by work, as
#                           break's; the pages themselves move with the layout)
#   xenowhere xelatex, with a footnote that fits neither in the margin nor at the
#            foot: it goes with its line to the next page, or is carried with a
#            warning where the page can't end early (it had to be carried when
#            XeTeX could have no early end), and the job settles
#   xenowherebreak  the same under noteoverflow=break
#   nowhere  the same under pdflatex: the page ends early instead (yield), and
#            the note goes to the next page with its line
#   hbox     test-noteoverflow-foot-hbox.tex, with foot, break, and carry (ref,
#            where no copy for the foot is made and TeX speaks for the only one,
#            whatever the mechanism; it was break without the fork's wrapper of
#            footnotes, \marginnotefoot undefined): the copy of a
#            footnote that isn't printed says nothing about overfull or underfull
#            lines, and the printed one says what TeX would, with its place
#   twocol   pdflatex, two columns, where foot can't work: the default is break,
#            without a word
#   twofoot  the same, asking for foot: break, and a warning that says why
#
# test-noteoverflow-foot.py checks the outcome (PDF, labels, biblatex's records,
# warnings), not any log line of marginfix's.  PRE, if set, is TeX code put first
# on each command line (to load another implementation, say).
#
# Runs to settle are a requirement: each job is built again with
# noteoverflow=carry (\testfloor, job <job>-floor), which moves no note for a
# page that ends early, and may take at most two runs more than that floor:
# citations here reuse notes (footnotereuse), and the number of a reusing mark
# may change a run after the note it reuses moves.
src=test-noteoverflow-foot
status=0
# $MARGINFIX: a directory with the marginfix.sty to test against, put first on
# TEXINPUTS; unset, the one found.
[ -n "$MARGINFIX" ] && export TEXINPUTS="$(cd "$MARGINFIX" && pwd)//:$TEXINPUTS"
settle() { # <job> <engine> <definitions>
  rm -f "$1.aux" "$1.bbl"
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    [ -f "$1.aux" ] && cp "$1.aux" "$1.aux.old"
    timeout "${TEXTIMEOUT:-120}" "$2" -shell-escape -interaction=nonstopmode -jobname="$1" \
      "${PRE}$3\\input{$src}" > /dev/null
    # a run that never ends (more than $TEXTIMEOUT s, 120) fails
    [ $? = 124 ] && { echo "didactic noteoverflow foot test: $1 FAIL: a run never ends"; return 1; }
    [ "$i" = 1 ] && { biber "$1" > /dev/null || return 1; continue; }
    if cmp -s "$1.aux" "$1.aux.old" \
       && ! grep -q 'Rerun to get\|may have changed' "$1.log"
    then runs=$i; return 0; fi
  done
  echo "didactic noteoverflow foot test: $1 FAIL: not settled in 12 runs"
  return 1
}
job() { # <name> <engine> <definitions> <check arguments>
  [ -z "$CASES" ] || case " $CASES " in *" $1 "*) ;; *) return;; esac
  j=$src-$1
  settle "$j-floor" "$2" "\\def\\testfloor{}$3" || { status=1; return; }
  floor=$runs
  settle "$j" "$2" "$3" || { status=1; return; }
  if [ "$runs" -gt $((floor + 2)) ]; then
    echo "didactic noteoverflow foot test: $j runs FAIL ($runs, floor $floor)"
    status=1
  else
    echo "didactic noteoverflow foot test: $j runs PASS ($runs, floor $floor)"
  fi
  python3 $src.py check "$j" $4 || status=1
}
job default pdflatex '' foot
job break pdflatex '\def\testoptions{noteoverflow=break}' 'nofoot spill away'
job hyper pdflatex '\def\testhyper{}' foot
job fast pdflatex '\def\testoptions{footnotereuse=fast}' foot
job off pdflatex '\def\testoptions{footnotereuse=off}' 'foot nolabels'
job draft pdflatex '\def\testoptions{draft}' 'nofoot spill away nolabels'
job lua lualatex '' foot
job xe xelatex '' 'foot spill away'
job trad pdflatex '\def\teststyle{verbose-trad2}' foot
job tradbreak pdflatex '\def\teststyle{verbose-trad2}\def\testoptions{noteoverflow=break}' \
  'nofoot spill away'
job counter pdflatex '\def\testbib{citecounter=true}\def\testcounter{}' foot
job counterbreak pdflatex \
  '\def\testbib{citecounter=true}\def\testcounter{}\def\testoptions{noteoverflow=break}' \
  'nofoot spill away'
job backref pdflatex '\def\testbib{backref=true}\def\testbibliography{}' foot
job backrefbreak pdflatex \
  '\def\testbib{backref=true}\def\testbibliography{}\def\testoptions{noteoverflow=break}' \
  'nofoot spill away'
job xenowhere xelatex '\def\testnowhere{}' 'foot away'
job xenowherebreak xelatex '\def\testnowhere{}\def\testoptions{noteoverflow=break}' \
  'nofoot away'
job nowhere pdflatex '\def\testnowhere{}' foot
job twocol pdflatex '\def\testclassopt{twocolumn}' 'nofoot spill away'
job twofoot pdflatex '\def\testclassopt{twocolumn}\def\testoptions{noteoverflow=foot}' \
  'nofoot spill away warn'
hbox() { # test-noteoverflow-foot-hbox, with foot and with break (no bibliography)
  [ -z "$CASES" ] || case " $CASES " in *" hbox "*) ;; *) return;; esac
  for m in foot break ref; do
    j=$src-hbox-$m; rm -f "$j.aux"
    o=noteoverflow=$m; [ $m = ref ] && o=noteoverflow=carry
    for i in 1 2 3 4 5 6 7 8; do
      [ -f "$j.aux" ] && cp "$j.aux" "$j.aux.old"
      pdflatex -interaction=nonstopmode -jobname="$j" \
        "${PRE}\\def\\testoptions{$o}\\input{$src-hbox}" > /dev/null
      if [ -f "$j.aux.old" ] && cmp -s "$j.aux" "$j.aux.old" \
         && ! grep -q 'Rerun to get\|may have changed' "$j.log"; then break; fi
    done
  done
  python3 $src.py hbox $src-hbox-foot $src-hbox-break $src-hbox-ref || status=1
}
hbox
if [ -z "$CASES" ]; then
  python3 $src.py same $src-default $src-break || status=1
  python3 $src.py same $src-default $src-hyper || status=1
  python3 $src.py same $src-trad $src-tradbreak || status=1
  python3 $src.py same $src-counter $src-counterbreak || status=1
  for v in trad counter backref; do
    python3 $src.py records $src-$v $src-${v}break || status=1
  done
fi
exit $status
