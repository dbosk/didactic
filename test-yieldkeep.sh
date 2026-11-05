#!/bin/bash
# Check test-yieldkeep.tex: a page must not end early for a margin note where
# that parts a heading from the lines it is owed, or leaves a paragraph's first
# or last line alone; the note is then capped, with a warning that says why.
# Calls pdflatex itself: only there can a page end early.  Each job runs until
# its .aux file stops changing and the last run asks for no other.
job=test-yieldkeep
status=0
grep -q 'MFX@fit@capwhy' "$(kpsewhich marginfix.sty)" || {
  echo "didactic yieldkeep test: FAIL: marginfix is too old, this needs its" \
    "integration branch, https://github.com/dbosk/marginfix"; exit 1; }
settle() { # <job> <case> <room> <options>
  rm -f "$1.aux" "$1.pdf"
  for i in 1 2 3 4 5 6 7 8; do
    [ -f "$1.aux" ] && cp "$1.aux" "$1.aux.old"
    pdflatex -shell-escape -interaction=nonstopmode -jobname="$1" \
      "\\def\\testcase{$2}\\def\\testroom{$3}\\def\\testoptions{$4}\\input{$job}" \
      > /dev/null
    if [ -f "$1.aux.old" ] && cmp -s "$1.aux" "$1.aux.old" \
       && ! grep -q 'may have changed' "$1.log"; then
      settled=yes; return
    fi
  done
  settled=no
}
# check <name> <case> <room> <options> <expect>: expect is
#   yield       the page ends early for the note, no warning about a line;
#   hold:<word> it doesn't, the note is capped, and didactic's warning has <word>.
#   parted      the page ends right under the heading;
#   clean       it settles with no errors, and a note was split;
#   warnlone:<word> the page ends early, and a warning has <word>.
check() {
  name=$1; j=$job-$name
  settle "$j" "$2" "$3" "$4"
  errors=$(grep -c '^!' "$j.log")
  yields=$(grep -c '^marginfix-yield: page=[0-9]* before' "$j.log")
  capped=$(grep -c '^marginfix-spill: .* capped$' "$j.log")
  unresolved=$(grep -c '^marginfix-spill: .* unresolved$' "$j.log")
  told=$(grep -c 'its page early would\|early for another note' "$j.log")
  limit=$(grep -c 'marginnoteyieldlimit keeps page' "$j.log")
  p1=$(pdftotext -f 1 -l 1 "$j.pdf" - 2>/dev/null)
  head1=$(printf '%s\n' "$p1" | grep -c 'HEADINGX')
  first1=$(printf '%s\n' "$p1" | grep -c 'FIRSTLINE')
  state="settled: $settled, errors: $errors, early ends: $yields, capped: $capped,"
  state="$state unresolved: $unresolved, told: $told, limit: $limit, heading on p1: $head1,"
  state="$state first line on p1: $first1"
  ok=no
  if [ "$settled$errors$unresolved" = yes00 ]; then
    case $5 in
      hold:*)
        grep -q "${5#hold:}" "$j.log" && [ "$yields" = 0 ] && [ "$capped" -gt 0 ] \
          && [ "$first1" -gt 0 ] && [ "$limit" = 0 ] && ok=yes;;
      yield)
        [ "$yields" -gt 0 ] && [ "$capped$told" = 00 ] && ok=yes;;
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
parted='a heading from its lines'
first='first line alone'
last='last line alone'
check heading heading 7 '' "hold:$parted"
check stacked stacked 9 '' "hold:$parted"
check headlist headlist 7 '' "hold:$parted"
check headthm headthm 7 '' "hold:$parted"
check withother withother 8 '' "hold:another note"
check tallheading tallheading 11 '' "hold:$parted"
check tallclub tallclub 4 '' "hold:$first"
check tallwidow tallwidow 9 '' "hold:$last"
check tallmiddle tallmiddle 9 '' yield
check second second 9 '' "hold:$parted"
check vertical vertical 7 '' "hold:$parted"
check headingzero heading 7 'noteyieldmaxgap=0' "hold:$parted"
check headingoff heading 7 'keepafterheading=0' parted
check runin runin 4 '' yield
check theorem theorem 4 '' yield
check runintwo runintwo 7 '' "hold:$parted"
check club club 4 '' "hold:$first"
check widow widow 7 '' "hold:$last"
check clubzero club 4 'noteyieldmaxgap=0' "warnlone:$first"
check middle middle 9 '' yield
check split split 4 '' clean
rm -f "$job-slides.aux"
pdflatex -shell-escape -interaction=nonstopmode "$job-slides" > /dev/null
errors=$(grep -c '^!' "$job-slides.log")
if [ "$errors" = 0 ]; then
  echo "didactic yieldkeep test: slides PASS"
else
  echo "didactic yieldkeep test: slides FAIL ($errors errors)"; status=1
fi
exit $status
