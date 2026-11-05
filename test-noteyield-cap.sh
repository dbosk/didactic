#!/bin/bash
# Check the cap of noteyieldmaxgap in the layout, on test-noteyield-cap.tex.
# Calls pdflatex itself, whatever PDFLATEX says: the page can only end early
# under pdfLaTeX or LuaLaTeX.  Each job runs until its .aux file stops changing
# and the last run asks for no other (at most eight runs).  Then:
#   default  notes are capped, each with marginfix's warning, the last note is
#            called out on page 1 and set on a later page, and no page ends
#            early;
#   off      with noteyieldmaxgap=0 nothing is capped and pages end early;
#   warm     noteyieldmaxgap=0, from the .aux file of default, is as off.
# Needs marginfix with \marginnoteyieldlimit, and with the warning and the
# records that don't outlive their reason: an older one fails, saying so.
job=test-noteyield-cap
mfx=https://github.com/dbosk/marginfix
fail() { echo "didactic noteyield cap test: FAIL: $*"; exit 1; }
settle() { # <job> <options>
  for i in 1 2 3 4 5 6 7 8; do
    [ -f "$1.aux" ] && cp "$1.aux" "$1.aux.old"
    pdflatex -shell-escape -interaction=nonstopmode -jobname="$1" \
      "\\def\\testoptions{$2}\\input{$job}" > /dev/null
    if [ -f "$1.aux.old" ] && cmp -s "$1.aux" "$1.aux.old" \
       && ! grep -q 'may have changed' "$1.log"; then
      ! grep -q '^!' "$1.log" || fail "$1: LaTeX errors: $(grep -m1 '^!' "$1.log")"
      return 0
    fi
  done
  fail "$1: the runs don't settle in 8 runs"
}
count() { grep -c "$1" "$2.log"; }
spills() { grep '^marginfix-\(spill\|yield\)' "$1.log"; }
rm -f "$job"-default.aux "$job"-off.aux "$job"-warm.aux
rm -f "$job"-default.pdf "$job"-off.pdf "$job"-warm.pdf

settle "$job-default" ""
capped=$(count ' capped$' "$job-default")
warned=$(count 'marginnoteyieldlimit keeps page [0-9]*$' "$job-default")
[ "$capped" -gt 0 ] || fail "default: nothing is capped; is marginfix too old" \
  "to have \\marginnoteyieldlimit, or does the document no longer test the cap?"
[ "$warned" -gt 0 ] || fail "default: $capped notes capped, no warning:" \
  "marginfix is too old, this needs its integration branch, $mfx"
[ "$warned" = "$capped" ] || fail "default: $capped capped, $warned warnings"
[ "$(count '^marginfix-yield: page=[0-9]* before' "$job-default")" = 0 ] \
  || fail "default: a page still ends early"
pdftotext -f 1 -l 1 "$job-default.pdf" - | grep -q Zeta \
  || fail "default: the last callout isn't on page 1"
pdftotext -f 1 -l 1 "$job-default.pdf" - | grep -q '\bN6\b' \
  && fail "default: the last note is on page 1, so it wasn't carried"
pdftotext -f 2 "$job-default.pdf" - | grep -q '\bN6\b' \
  || fail "default: the last note isn't on a later page"

settle "$job-off" "noteyieldmaxgap=0"
[ "$(count ' capped$' "$job-off")" = 0 ] || fail "off: notes are capped"
[ "$(count '^marginfix-yield: page=[0-9]* before' "$job-off")" -gt 0 ] \
  || fail "off: no page ends early, so the cap isn't what differs"

cp "$job-default.aux" "$job-warm.aux"
settle "$job-warm" "noteyieldmaxgap=0"
[ "$(count ' capped$' "$job-warm")" = 0 ] || fail "warm: noteyieldmaxgap=0" \
  "leaves notes capped from the old .aux file: marginfix is too old, this" \
  "needs its integration branch, $mfx"
[ "$(spills "$job-warm")" = "$(spills "$job-off")" ] \
  || fail "warm: not as from no .aux file"
diff <(pdftotext -layout "$job-warm.pdf" -) <(pdftotext -layout "$job-off.pdf" -) \
  > /dev/null || fail "warm: the text isn't as from no .aux file"
echo "didactic noteyield cap test: PASS ($capped notes capped with warnings;" \
  "=0 turns it off, also on a warm .aux file)"
