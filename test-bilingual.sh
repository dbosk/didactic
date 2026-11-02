#!/bin/sh
# Read the test-bilingual PDFs: see test-bilingual.tex.  Exits non-zero if
# anything is missing or anything is there that shouldn't be.
status=0

fail() {
  echo "FAIL $1: $2"
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

[ "$status" = 0 ] && echo "bilingual: all as expected"
exit $status
