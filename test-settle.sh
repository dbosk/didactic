#!/bin/bash
# The settle of the note suites starts from no .aux and no .aux.old of its own job: a
# stale .aux.old equal to what the first run writes must not end the settle after one
# run.  One did: a pass with TeX Live's marginfix 1.2 after the pass with another in
# the same directory, or a run again in a used tree, ended a row's settle against an
# .aux.old it didn't write, and the row's warnings found from the last run were never
# made nor checked.  Only a row whose first run asks for no other (no label of its
# own changes) could end so; mcolblock is one: build it, leave its .aux as .aux.old,
# build it again; it must take more than one run.  (test-notefoot had the same flaw
# without its effect: each of its jobs labels its notes, so its first run always asks
# for another.)  $MARGINFIX as for the suites.
status=0
check() { # check <name> <script> <case> <job> <line pattern>
  CASES=$3 ./$2 > /dev/null 2>&1
  cp "$4.aux" "$4.aux.old"
  out=$(CASES=$3 ./$2 2>&1 | grep "test: $3 ")
  case "$out" in
    *"(1 runs"*|"") echo "didactic settle test: $1 FAIL ($out)"; status=1;;
    *) echo "didactic settle test: $1 PASS";;
  esac
}
check noteplace test-noteplace.sh mcolblock test-noteplace-mcolblock
exit $status
