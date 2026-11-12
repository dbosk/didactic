#!/bin/bash
# Build test-marginfix-interface.tex in its variants and check the log.
#   found   the marginfix found: "didactic-interface: ok", and marginfix's list
#           of waiting notes in the shape didactic parses: nothing but
#           \mfx@build@note with two boxes and a position, \mfx@build@skip with
#           a length and \mfx@build@clear (didactic's check at the start of the
#           document sees names only)
#   xelatex, lualatex  the same under those engines: ok, and the list's shape
#   tl12    TeX Live's marginfix 1.2: ok as well (its missing names are optional),
#           and the list's shape
#   changed the marginfix found with its entries in another form (the boxes in
#           a group): the check of the list's shape fails on it, so that the
#           check itself is tested
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
# the list after one note, as didactic parses it (\@didactic@sift and the
# others): one or more entries, each one of three forms, and nothing else
list() { tr -d '\n' < "$1.log" | grep -o 'interface-list: macro:->.* :end' | head -1; }
shape() {
  echo "$1" | grep -Eq '^interface-list: macro:->(\\mfx@build@note \\[A-Za-z@]+ \\[A-Za-z@]+ \{-?[0-9.]+pt\}|\\mfx@build@skip \{-?[0-9.]+pt\}|\\mfx@build@clear )+ :end$'
}
build $src-found ''
l=$(line $src-found) ls=$(list $src-found)
echo "$l" | grep -q '^didactic-interface: ok' && shape "$ls"
say found $? "($l; $ls)"
for e in xelatex lualatex; do
  build $src-$e '' "" $e
  l=$(line $src-$e) ls=$(list $src-$e)
  echo "$l" | grep -q '^didactic-interface: ok' && shape "$ls"
  say $e $? "($l; $ls)"
done
build $src-tl12 '' "$TL12//:"
l=$(line $src-tl12) ls=$(list $src-tl12)
echo "$l" | grep -q '^didactic-interface: ok' && shape "$ls"
say tl12 $? "($l; $ls)"
mf=$(kpsewhich marginfix.sty)
rm -rf $src-changed.d && mkdir $src-changed.d
sed 's/\\noexpand\\mfx@build@note\\@currbox\\@marbox{\\mfx@ypos}/\\noexpand\\mfx@build@note{\\@currbox\\@marbox}{\\mfx@ypos}/' \
  "$mf" > $src-changed.d/marginfix.sty
build $src-changed '' "$PWD/$src-changed.d//:$TEXINPUTS"
ls=$(list $src-changed)
! shape "$ls" && [ -n "$ls" ] && ! cmp -s "$mf" $src-changed.d/marginfix.sty
say changed $? "(not the shape: $ls)"
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
