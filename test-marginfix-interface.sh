#!/bin/bash
# Build test-marginfix-interface.tex in its variants and check the log.
#   found   the marginfix found: "didactic-interface: ok", and marginfix's list
#           of waiting notes made of \mfx@build@note, two boxes and a position
#   xelatex, lualatex  the same under those engines: ok
#   tl12    TeX Live's marginfix 1.2: ok as well (its missing names are optional)
#   old     the oldest kernel didactic asks for (latexrelease): ok, or carry with
#           a warning naming what is missing; either way said
#   broken  the kernel's \@specialoutput changed so that didactic can't patch it:
#           carry, and a warning naming it
src=test-marginfix-interface
status=0
# $MARGINFIX: a directory with the marginfix.sty to test against, put first on
# TEXINPUTS; unset, the one found.
[ -n "$MARGINFIX" ] && export TEXINPUTS="$(cd "$MARGINFIX" && pwd)//:$TEXINPUTS"
TL12=$(kpsewhich -var-value TEXMFDIST)/tex/latex/marginfix
build() { # <job> <definitions> [TEXINPUTS] [engine]
  rm -f "$1.aux"
  TEXINPUTS=${3:-$TEXINPUTS} timeout 120 ${4:-pdflatex} -interaction=nonstopmode \
    -jobname="$1" "$2\\input{$src}" > /dev/null 2>&1
}
say() { # <name> <ok?> <detail>
  if [ "$2" = 0 ]; then echo "didactic interface test: $1 PASS $3"
  else echo "didactic interface test: $1 FAIL $3"; status=1; fi
}
line() { grep -o '^didactic-interface: .*' "$1.log" | head -1; }
build $src-found ''
l=$(line $src-found)
list=$(tr -d '\n' < $src-found.log | grep -o 'interface-list: macro:->[^ ]* [^ ]* [^ ]* {[^}]*}' | head -1)
echo "$l" | grep -q '^didactic-interface: ok' \
  && echo "$list" | grep -q 'interface-list: macro:->\\mfx@build@note \\[^ ]* \\[^ ]* {-\?[0-9.]*pt}'
say found $? "($l; $list)"
for e in xelatex lualatex; do
  build $src-$e '' "" $e
  l=$(line $src-$e)
  echo "$l" | grep -q '^didactic-interface: ok'
  say $e $? "($l)"
done
build $src-tl12 '' "$TL12//:"
l=$(line $src-tl12)
echo "$l" | grep -q '^didactic-interface: ok'
say tl12 $? "($l)"
build $src-old '\def\testoldkernel{}'
l=$(line $src-old)
{ echo "$l" | grep -q '^didactic-interface: ok'; } \
  || { echo "$l" | grep -q '^didactic-interface: carry' \
       && grep -q 'Package didactic Warning: .*noteoverflow' $src-old.log; }
say old $? "($l)"
build $src-broken '\def\testbreak{}'
l=$(line $src-broken)
echo "$l" | grep -q '^didactic-interface: carry.*@specialoutput' \
  && tr -d '\n' < $src-broken.log | grep -q 'Package didactic Warning:.*@specialoutput'
say broken $? "($l)"
for j in found xelatex lualatex tl12 old broken; do
  n=$(grep -c '^!' $src-$j.log); [ "$n" = 0 ] || { say "$j errors" 1 "($n)"; }
done
exit $status
