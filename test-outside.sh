# test-outside.sh, sourced by the tests whose subject is the path by which a
# file is found (issue #136): test-pair-import.sh, test-runpaths.sh and
# test-runjobs.sh.  LaTeX finds a file through kpathsea, which searches the
# directory LaTeX runs in and then, recursively, the texmf trees.  The README
# installs this checkout in TEXMFHOME, so a relative path such as
# examples/x.py is found in any directory of the checkout that ends in it, from
# wherever LaTeX runs: a test built in the checkout, or one whose file names
# also occur there, can pass although the code looks in the wrong place.
# So these tests build in a fresh directory outside the checkout, under
# $TMPDIR or /tmp, with names that contain a word unique to the run.
#
# The script that sources this sets top to the checkout and counts its
# failures in fails.
#   outside NAME    makes that directory, $outside, and sets $token to the
#                   unique word; stops the test if kpathsea searches the
#                   directory's subdirectories, as it would in a texmf tree
#   document DIR    makes DIR, with this checkout's didactic.sty, which LaTeX
#                   finds beside the document before any in a texmf tree, and
#                   an empty _minted
#   own_sty LOG     the log shows that LaTeX loaded that didactic.sty
#   unseen PATH...  kpathsea finds none of the paths from the current
#                   directory: a test that looks for them in the wrong place
#                   fails
#   leave           removes $outside if nothing failed, or says where it is

outside() {
	outside=$(mktemp -d "${TMPDIR:-/tmp}/didactic-$1.XXXXXX") || exit 2
	token=${outside##*.}
	mkdir "$outside/probe"
	: > "$outside/probe/probe-$token.tex"
	if [ -n "$(cd "$outside" && kpsewhich "probe-$token.tex")" ]; then
		echo "kpathsea searches $outside: these tests can't run there"
		rm -rf "$outside"; exit 2
	fi
	rm -r "$outside/probe"
}
document() {
	mkdir -p "$1/_minted" && cp "$top/didactic.sty" "$1"
}
own_sty() {
	grep -q '(\./didactic\.sty' "$1"
}
unseen() {
	for p in "$@"; do
		found=$(kpsewhich "$p")
		if [ -n "$found" ]; then
			echo "kpathsea finds $p at $found"
			return 1
		fi
	done
}
leave() {
	if [ "$fails" -eq 0 ]; then
		rm -rf "$outside"
	else
		echo "the builds are in $outside"
	fi
}
