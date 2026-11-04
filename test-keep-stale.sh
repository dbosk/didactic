#!/bin/sh
# test-keep-stale.sh LATEX: the states of test-keep-stale.tex, from a clean .aux.
# Each step runs LaTeX until the references settle and checks the pages of the
# heading and the table, and what the .aux says.
LATEX="$1"
doc=test-keep-stale
fails=0
page() { sed -n "s/^.newlabel{$1}{{[^}]*}{\([0-9]*\)}.*/\1/p" $doc.aux; }
breaks() { grep -c 'keep@hb' $doc.aux; }
run() {
	for i in 1 2 3 4 5 6; do
		$LATEX -shell-escape -interaction=nonstopmode $doc.tex >/dev/null ||
			{ echo "FAIL: LaTeX stopped, $1"; exit 1; }
		grep -q 'Rerun to get' $doc.log || break
	done
	if grep -q 'Rerun to get' $doc.log; then
		echo "FAIL didn't settle, $1"; fails=$((fails+1))
	fi
}
check() { # what expected actual
	if [ "$2" = "$3" ]; then
		echo "PASS $1"
	else
		echo "FAIL $1: expected $2, got $3"; fails=$((fails+1))
	fi
}
room() { printf '\\roomfor{%s}\n' "$1" > $doc-room.tex; }
opt() { printf '\\PassOptionsToPackage{%s}{didactic}\n' "$1" > $doc-opt.tex; }

rm -f $doc.aux
opt ""; room 4; run "room 4"
check "room 4: heading moves to the table" 2 "$(page a)"
check "room 4: table with it" 2 "$(page t)"
check "room 4: the break is recorded" 1 "$(breaks)"

room 30; run "room 30"
check "more room: heading back on the first page" 1 "$(page a)"
check "more room: table with it" 1 "$(page t)"
check "more room: the break is gone from the .aux" 0 "$(breaks)"
run "room 30 again"
check "more room, a run later: stays" 1 "$(page a)"

room 4; run "room 4 again"
check "less room again: moves" 2 "$(page a)"

opt "keepmaxgap=0"; run "no limit"
check "no limit: moves" 2 "$(page a)"
room 30; run "no limit, more room"
check "no limit, more room: the break is retracted" 1 "$(page a)"
check "no limit, more room: table with it" 1 "$(page t)"
check "no limit, more room: gone from the .aux" 0 "$(breaks)"
opt ""; room 4; run "room 4 once more"
check "limit again, less room: moves" 2 "$(page a)"

opt "keepafterheading=0"; run "option off"
check "keepafterheading=0 on a warm .aux: stays" 1 "$(page a)"
check "keepafterheading=0: no break in the .aux" 0 "$(breaks)"

rm -f $doc.aux; opt ""; room 4; run "room 4 a third time"
check "from clean: moves" 2 "$(page a)"
opt "keepmaxgap=2"; run "smaller limit"
check "keepmaxgap=2 on a warm .aux: stays" 1 "$(page a)"
check "keepmaxgap=2: no break in the .aux" 0 "$(breaks)"
check "keepmaxgap=2: a warning names the heading" 1 \
	"$(grep -c 'heading in test-keep-stale, line 20' $doc.log)"

if [ "$fails" -ne 0 ]; then
	echo "$fails checks failed"; exit 1
fi
