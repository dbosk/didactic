#!/bin/sh
# test-runpaths.sh LATEX PYTHONTEX: the path by which minted finds a transcript
# (issue #118, after its review).  The notes of test-runjobs-contents.tex are
# built, with a run and a pair, in:
#   a document's directory whose name has % # ~, a space and a non-ASCII
#   letter, with PythonTeX's defaults, and laid out as decks are
#   (-output-directory, PythonTeX run there, \setpythontexoutputdir{.} and
#   \setpythontexworkingdir{..}) with a build directory whose name has # ~, a
#   space and a non-ASCII letter, which are then in the path given to minted;
#   a directory that is renamed after the build and then typeset again
#   without PythonTeX, as make does when the .pytxcode is unchanged, in both
#   layouts.
# Each must typeset without an error, with this checkout's didactic.sty, and
# show the runs and the pair.  The builds are outside the checkout, and the
# programs print a word unique to the run, so that their transcripts' names are
# too (test-outside.sh, issue #136): a path that minted can't follow fails.
LATEX="$1"
PYTHONTEX="$2"
top=$(pwd)
odd='a%b#c~d e-ö'
fails=0
. "$top/test-outside.sh"

check() { # what: succeeds or not
	if [ "$2" = yes ]; then
		echo "PASS $1"
	else
		echo "FAIL $1"; fails=$((fails+1))
	fi
}
# setup DIR LAYOUT BUILD: a fresh document in DIR
setup() {
	rm -rf "$1"; document "$1"
	cp "$top"/test-runjobs-notes.tex "$top"/test-runjobs-contents.tex "$1"
	printf '%s\n' 'print("only in the notes")' "print(\"$token\")" \
		> "$1/runjobs-only.py"
	printf '%s\n' 'print("version", 1)' "print(\"$token\")" \
		> "$1/runjobs-prog.py"
	if [ $2 = deck ]; then
		mkdir -p "$1/$3/_minted"
		printf '%s\n' '\setpythontexoutputdir{.}' \
			'\setpythontexworkingdir{..}' > "$1/test-runjobs-layout.tex"
	else
		: > "$1/test-runjobs-layout.tex"
	fi
}
# tex DIR BUILD: one pass, in the document's directory DIR
tex() {
	(cd "$1" && $LATEX -interaction=nonstopmode -output-directory="$2" \
		test-runjobs-notes.tex >/dev/null)
}
pytex() { # DIR BUILD
	(cd "$1/$2" && $PYTHONTEX test-runjobs-notes >/dev/null)
}
full() { tex "$1" "$2"; pytex "$1" "$2"; tex "$1" "$2"; tex "$1" "$2"; }
# shows DIR BUILD: this checkout's didactic.sty and no error in the log, and the
# runs and the pair in the PDF
shows() {
	own_sty "$1/$2/test-runjobs-notes.log" &&
	! grep -q '^!' "$1/$2/test-runjobs-notes.log" &&
	! grep -q 'Package minted Error' "$1/$2/test-runjobs-notes.log" &&
	pdftotext "$1/$2/test-runjobs-notes.pdf" - > "$1/text.txt" &&
	grep -qF 'version 1' "$1/text.txt" &&
	grep -qF 'print("version", 1)' "$1/text.txt" &&
	grep -qxF 'only in the notes' "$1/text.txt" && echo yes
}

outside runpaths; cd "$outside"

d="default/$odd"; setup "$d" default .; full "$d" .
check "a document's directory named '$odd'" "$(shows "$d" .)"

# A % in the name of -output-directory stops minted, with v2.18 too.
d="deck/$odd"; b='build #~ ö'; setup "$d" deck "$b"; full "$d" "$b"
check "a document's directory named '$odd', its build directory '$b', as decks" \
	"$(shows "$d" "$b")"

for layout in default deck; do
	if [ $layout = deck ]; then b=ltxobj; else b=.; fi
	setup moved-$layout $layout $b; full moved-$layout $b
	mv moved-$layout moved-$layout-2; tex moved-$layout-2 $b
	check "$layout: renamed after the build, typeset again without PythonTeX" \
		"$(shows moved-$layout-2 $b)"
done

cd "$top"; leave
[ $fails -eq 0 ] || { echo "$fails failed"; exit 1; }
