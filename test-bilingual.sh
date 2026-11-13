#!/bin/sh
# Read the test-bilingual PDFs: see test-bilingual.tex.  Exits non-zero if
# anything is missing or anything is there that shouldn't be.
status=0

fail() {
  printf 'FAIL %s: %s\n' "$1" "$2"
  status=1
}

# check JOB MINE OTHER WORDS...: each marker is there with MINE as its prefix,
# and nothing at all has the prefix OTHER.  The text comes from the PDF, plus
# the .toc and .nav where moving arguments end up.  (The .aux keeps \\tr as it
# is in a label's title, which is unexpanded on purpose: hyperref's \\nameref
# text expands when used.)
check() {
  job=$1 mine=$2 other=$3
  shift 3
  text=$(pdftotext "$job.pdf" -) || { fail "$job" "no PDF"; return; }
  for word in "$@"; do
    case "$text" in
      *"$mine$word"*) ;;
      *) fail "$job" "$mine$word is missing" ;;
    esac
  done
  case "$text" in
    *"$other"[A-Z][A-Z]*) fail "$job" "the other language: $other" ;;
  esac
  if grep -q "$other[A-Z][A-Z]" "$job.toc" "$job.nav" 2>/dev/null; then
    fail "$job" "the other language in the .toc or .nav"
  fi
  # bookmarks are in UTF-16 there
  if sed 's/\\000//g' "$job.out" 2>/dev/null | grep -q "$other[A-Z][A-Z]"; then
    fail "$job" "the other language in the bookmarks"
  fi
  if grep -q '\\tr\b' "$job.toc" 2>/dev/null; then
    fail "$job" "an unexpanded \\tr in the .toc"
  fi
  case "$text" in
    *SHARED*) ;;
    *) fail "$job" "SHARED is missing" ;;
  esac
  case "$text" in
    *"Hello, World"*|*"hello"*) ;;
    *) fail "$job" "the block's minted or runpython is missing" ;;
  esac
}

NOTES="TITLE CHAPTER SECTION PROSE FRAMETITLE FRAME VERBATIM EXERCISE ITEM \
  BLOCKED NOTE WHOLEFRAME CAPTION STRING"
SLIDES="TITLE SECTION FRAMETITLE FRAME VERBATIM EXERCISE ITEM BLOCKED \
  WHOLEFRAME STRING"

check test-bilingual EN SV $NOTES
check test-bilingual-sv SV EN $NOTES
check test-bilingual-slides EN SV $SLIDES
check test-bilingual-slides-sv SV EN $SLIDES

for job in test-bilingual-slides test-bilingual-slides-sv; do
  case "$(pdftotext "$job.pdf" -)" in
    *ENPROSE*|*SVPROSE*) fail "$job" "prose outside the frames" ;;
  esac
done

pdftotext test-bilingual.pdf - | grep -q 'see section' \
  || fail test-bilingual "\\cref does not say section"
pdftotext test-bilingual-sv.pdf - | grep -q 'see avsnitt' \
  || fail test-bilingual-sv "\\cref does not say avsnitt"

pdftotext test-bilingual-off.pdf - | grep -q 'own tr: x' \
  || fail test-bilingual-off "own \\tr is gone"
pdftotext test-bilingual-off.pdf - | grep -q 'own en' \
  || fail test-bilingual-off "own en is gone"

nested=$(pdftotext test-bilingual-nested.pdf -)
for word in NESTEDFIRST NESTEDINNER NESTEDINNERMOST NESTEDINNEREND NESTEDLAST \
  AFTERNESTED; do
  case "$nested" in
    *"$word"*) ;;
    *) fail test-bilingual-nested "$word is missing" ;;
  esac
done
case "$nested" in
  *NESTEDSV*) fail test-bilingual-nested "the other language" ;;
esac

# A name that comment.sty would overwrite stops the build, with a message that
# names the way out; an environment of that name is no such thing.
taken() {
  ${PDFLATEX:-pdflatex} -shell-escape -interaction=nonstopmode \
    -jobname=test-bilingual-taken \
    "\\documentclass{${CLASS:-article}}\\usepackage[british]{babel}$1\\begin{document}x\\end{document}" \
    >/dev/null 2>&1
}
for name in comment en sv; do
  taken "\\newcommand\\$name[1]{#1}\\usepackage{didactic}"
  grep -q "Package didactic Error.*\\\\$name" test-bilingual-taken.log \
    || fail taken "no error for $name"
  grep -q nobilingual test-bilingual-taken.log \
    || fail taken "the error for $name does not name nobilingual"
  taken "\\newcommand\\$name[1]{#1}\\usepackage[nobilingual]{didactic}"
  if grep -q '^!' test-bilingual-taken.log; then
    fail taken "nobilingual with own $name"
  fi
done
for package in comment verbatim; do
  taken "\\usepackage{$package}\\usepackage{didactic}"
  if grep -q '^!' test-bilingual-taken.log; then
    fail taken "$package loaded first"
  fi
  if grep -q 'Package didactic Warning.*comment' test-bilingual-taken.log; then
    fail taken "a warning about the comment environment of $package"
  fi
done

CLASS=memoir taken "\\usepackage{didactic}"
if grep -q 'Package didactic Warning.*comment' test-bilingual-taken.log; then
  fail taken "a warning about memoir's comment environment"
fi

# The document's own environment comment is replaced by comment.sty's, which
# drops its contents; if it printed them, that text is lost, so say so.
taken "\\newenvironment{comment}{NOTE:}{}\\usepackage{didactic}"
grep -q "Package didactic Warning.*comment" test-bilingual-taken.log \
  || fail taken "no warning for an environment comment of the document's own"
grep -q nobilingual test-bilingual-taken.log \
  || fail taken "the warning for an environment comment does not name nobilingual"

# A block's cut file is the job's own.  \subimport makes \input look in the
# imported directory first, where a deck built on its own may have left a cut
# file of the same name; the block must not read that one.
mkdir -p test-bilingual-import.d
printf '\\begin{en}\nFRESHCUT\n\\end{en}\n' > test-bilingual-import.d/inner.tex
echo STALECUT > test-bilingual-import.d/test-bilingual-import.cut
${PDFLATEX:-pdflatex} -shell-escape -interaction=nonstopmode \
  -jobname=test-bilingual-import \
  "\\documentclass{article}\\usepackage[british]{babel}\\usepackage{import}\\usepackage{didactic}\\begin{document}\\subimport{test-bilingual-import.d/}{inner}\\end{document}" \
  >/dev/null 2>&1
case "$(pdftotext test-bilingual-import.pdf - 2>/dev/null)" in
  *FRESHCUT*) ;;
  *) fail import "a stale cut file in the imported directory was read" ;;
esac

[ "$status" = 0 ] && echo "bilingual: all as expected"
exit $status
