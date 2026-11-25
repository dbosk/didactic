#!/bin/sh
# test-runjobs.sh LATEX PYTHONTEX: two jobs of one document, the notes and the
# slides of test-runjobs-contents.tex, each rebuilt alone in either order while
# the program they both run changes its output (issue #118).  A job that LaTeX
# typesets again without a PythonTeX run, as after an edit of the prose, must
# still find every transcript it inputs: none may be deleted by the other job.
#
# The builds are outside the checkout, and the programs print a word unique to
# the run, so that their transcripts' names are too (test-outside.sh, issue
# #136): a transcript that minted can't find where it looks is missing.
#
# Three layouts, each in its own directory of that build:
#   shared  both jobs in the document's directory, with PythonTeX's defaults
#           (its output in pythontex-files-<job>);
#   outdir  both jobs in one build directory, -output-directory=ltxobj, with
#           PythonTeX run there, its output still per job, and
#           \setpythontexworkingdir{..};
#   dirs    a build directory per job, -output-directory=build-<job>, with
#           PythonTeX run there, \setpythontexoutputdir{.} and
#           \setpythontexworkingdir{..}, as decks do.
# Where PythonTeX runs in the build directory it runs with --rerun=always, as
# the decks' makefiles run it.  Then it reruns everything anyway, so only the
# shared layout checks that a changed program alone makes PythonTeX rerun it.
# In each, removing what the build made (pythontex-files-*, ltxobj or build-*)
# must remove every transcript: none is left in the document's directory.
# Jobs that share PythonTeX's output directory share its own files too, so they
# can't be typeset alone; that layout isn't tested.
LATEX="$1"
PYTHONTEX="$2"
top=$(pwd)
fails=0
. "$top/test-outside.sh"

check() { # what: succeeds or not
	if [ "$2" = yes ]; then
		echo "PASS $layout: $1"
	else
		echo "FAIL $layout: $1"; fails=$((fails+1))
	fi
}
# The program's source, shown by the pair, differs from its output.
version() {
	printf '%s\n' "print(\"version\", $1)" "print(\"$token\")" > runjobs-prog.py
}
build() { # job: its build directory
	case $layout in
	shared) echo . ;;
	outdir) echo ltxobj ;;
	dirs) echo build-$1 ;;
	esac
}
log() { echo $(build $1)/test-runjobs-$1.log; }
pdf() { echo $(build $1)/test-runjobs-$1.pdf; }
tex() { # job
	$LATEX -interaction=nonstopmode -output-directory=$(build $1) \
		test-runjobs-$1.tex >/dev/null
}
pytex() { # job
	case $layout in
	shared) $PYTHONTEX test-runjobs-$1 ;;
	*) (cd $(build $1) && $PYTHONTEX --rerun=always test-runjobs-$1) ;;
	esac >/dev/null
}
# A last pass, since minted leaves a placeholder where its cache lacks the code.
full() { tex $1; pytex $1; tex $1; tex $1; }
# The job typesets with this checkout's didactic.sty, without an error from
# minted (a missing transcript or side of a pair), and shows the text.
shows() { # job text
	own_sty $(log $1) &&
	! grep -q 'Package minted Error' $(log $1) &&
		pdftotext $(pdf $1) - | grep -qF "$2" && echo yes
}

outside runjobs
for layout in shared outdir dirs; do
	document "$outside/$layout"
	cd "$outside/$layout" || exit 2
	cp "$top"/test-runjobs-*.tex .
	mkdir -p $(build notes)/_minted $(build slides)/_minted
	case $layout in
	shared) : ;;
	outdir) echo '\setpythontexworkingdir{..}' ;;
	dirs) printf '%s\n' '\setpythontexoutputdir{.}' \
		'\setpythontexworkingdir{..}' ;;
	esac > test-runjobs-layout.tex
	printf '%s\n' 'print("only in the notes")' "print(\"$token\")" \
		> runjobs-only.py

	version 1; full notes; full slides
	check "notes built: version 1" "$(shows notes 'version 1')"
	check "notes built: the notes' own run" \
		"$(shows notes 'only in the notes')"
	check "slides built: version 1" "$(shows slides 'version 1')"
	check "slides built: the pair" "$(shows slides 'print("version", 1)')"

	version 2; full notes
	check "the program changed, notes rebuilt: version 2" \
		"$(shows notes 'version 2')"
	tex slides
	check "slides typeset again without PythonTeX: version 1 still there" \
		"$(shows slides 'version 1')"
	check "slides typeset again without PythonTeX: the pair still there" \
		"$(shows slides 'print("version", 1)')"

	full slides
	check "slides rebuilt: version 2" "$(shows slides 'version 2')"

	version 3; full slides
	check "the program changed, slides rebuilt: version 3" \
		"$(shows slides 'version 3')"
	tex notes
	check "notes typeset again without PythonTeX: version 2 still there" \
		"$(shows notes 'version 2')"
	check "notes typeset again without PythonTeX: the pair still there" \
		"$(shows notes 'print("version", 2)')"
	check "notes typeset again without PythonTeX: their own run still there" \
		"$(shows notes 'only in the notes')"

	case $layout in
	shared) rm -rf pythontex-files-* ;;
	*) rm -rf $(build notes) $(build slides) ;;
	esac
	left=$(echo $(ls didactic_output_* didactic_pair_* 2>/dev/null))
	check "no transcript left beside the document${left:+: $left}" \
		"$([ -z "$left" ] && echo yes)"
	cd "$top"
done

leave
[ $fails -eq 0 ] || { echo "$fails failed"; exit 1; }
