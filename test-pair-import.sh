#!/bin/sh
# test-pair-import.sh LATEX PYTHONTEX: a pair written by hand in a part that the
# document binds with \subimport from another directory (issue #133).  Its
# code column is \inputminted of a program relative to the part, which minted
# finds through the import path, and its other column runs the program, with
# \runbasedir{auto}.  The document is built outside the checkout, and the
# program's name has a word unique to the run (test-outside.sh, issue #136), so
# that kpathsea can't find it anywhere but in the part.  Two cases:
#   inputminted  the pair typesets, with the code and the output;
#   control      the same with \didacticinputminted, which empties the import
#                path, since it is for didactic's own files: minted must not
#                find the program.  If it did, kpathsea would be finding it
#                elsewhere, and the first case could pass without the import
#                path.
LATEX="$1"
PYTHONTEX="$2"
top=$(pwd)
fails=0
. "$top/test-outside.sh"

check() { # what: succeeds or not
	if [ "$2" = yes ]; then
		echo "PASS $1"
	else
		echo "FAIL $1"; fails=$((fails+1))
	fi
}

outside pairimport
prog=examples/pairimport-$token.py

# setup DIR COMMAND: the document in DIR, its part in DIR/part, the code column
# read with COMMAND
setup() {
	document "$1"
	mkdir -p "$1/part/examples"
	echo 'print("pair", "import", sep="+")' > "$1/part/$prog"
	printf '%s\n' '\documentclass{article}' '\usepackage{didactic}' \
		'\usepackage{import}' '\runbasedir{auto}' '\begin{document}' \
		'\subimport{part/}{contents}' '\end{document}' > "$1/pairimport.tex"
	printf '%s\n' '\begin{didacticpair}{2}' "$2{python}{$prog}" '&' \
		"\\runpython[chdir]{$prog}" '\end{didacticpair}' \
		> "$1/part/contents.tex"
}
tex() {
	(cd "$1" && $LATEX -interaction=nonstopmode pairimport.tex >/dev/null 2>&1)
}
pytex() { (cd "$1" && $PYTHONTEX pairimport >/dev/null); }
# A last pass, since minted leaves a placeholder where its cache lacks the code.
full() { tex "$1"; pytex "$1"; tex "$1"; tex "$1"; }

d="$outside/inputminted"; setup "$d" '\inputminted'
check "the program can't be found from where LaTeX runs" \
	"$(cd "$d" && unseen "$prog" "pairimport-$token.py" && echo yes)"
full "$d"
check "the pair typesets with this checkout's didactic.sty" \
	"$(own_sty "$d/pairimport.log" && ! grep -q '^!' "$d/pairimport.log" &&
		echo yes)"
pdftotext "$d/pairimport.pdf" "$d/text.txt"
check "the code column shows the program" \
	"$(grep -qF 'sep="+"' "$d/text.txt" && echo yes)"
check "the other column shows its output" \
	"$(grep -qF 'pair+import' "$d/text.txt" && echo yes)"

d="$outside/control"; setup "$d" '\didacticinputminted'
full "$d"
check "control: with the import path emptied, minted doesn't find the program" \
	"$(own_sty "$d/pairimport.log" &&
		python3 "$top/testlog.py" grep \
		"Cannot locate file \"$prog\"" "$d/pairimport.log" >/dev/null &&
		echo yes)"

leave
[ $fails -eq 0 ] || { echo "$fails failed"; exit 1; }
