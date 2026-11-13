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
# the .toc and .nav where moving arguments end up.  (The .aux keeps \\ensv as it
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
  if grep -q '\\ensv\b' "$job.toc" 2>/dev/null; then
    fail "$job" "an unexpanded \\ensv in the .toc"
  fi
  case "$text" in
    *SHARED*) ;;
    *) fail "$job" "SHARED is missing" ;;
  esac
  case "$text" in
    *'print("Hello, world!")'*) ;;
    *) fail "$job" "the block's \\inputminted is missing" ;;
  esac
  printf '%s\n' "$text" | grep -qx 'Hello, world!' \
    || fail "$job" "the output of the block's \\runpython is missing"
}

NOTES="TITLE CHAPTER SECTION PROSE FRAMETITLE FRAME VERBATIM EXERCISE ITEM \
  BLOCKED NOTE WHOLEFRAME CAPTION STRING CHUNK"
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

# A woven chunk in a block: each edition has its own, and the chunk index,
# which noweave writes after the file's last chunk, reaches both.
for job in test-bilingual test-bilingual-sv; do
  case "$(pdftotext "$job.pdf" -)" in
    *SHAREDCHUNK*) ;;
    *) fail "$job" "the shared chunk is missing" ;;
  esac
  entries=$(grep -c 'nwixadds' "$job.aux")
  [ "$entries" -ge 3 ] \
    || fail "$job" "the chunk index has $entries entries, not 3"
done

# The test documents are examples too, so the script must find nothing wrong
# with them: no error, and no stamp in a form that it no longer reads.
for source in test-bilingual.tex test-bilingual-sv.tex \
  test-bilingual-slides.tex test-bilingual-slides-sv.tex \
  test-bilingual-contents.tex test-bilingual-preamble.tex \
  test-bilingual-nested.tex test-bilingual-nested-inner.tex \
  test-bilingual-nested-innermost.tex test-bilingual-off.tex \
  test-bilingual-woven.nw; do
  report=$(./didactic-sync.py --list "$source" 2>&1) \
    || fail "$source" "didactic-sync.py finds it malformed: $report"
  case "$report" in
    *"no pair here"*) fail "$source" "a stamp with no pair: $report" ;;
  esac
done

# beamer's own block titles, such as Example, come from translator, which
# follows babel only with the two lines that the documentation gives; this
# package's titles, such as Exercise, follow babel by themselves.
for job in test-bilingual test-bilingual-slides; do
  text=$(pdftotext "$job.pdf" -)
  case "$text" in
    *Example*) ;;
    *) fail "$job" "beamer's block title is not English" ;;
  esac
  case "$text" in
    *Exempel*) fail "$job" "a Swedish block title in the English edition" ;;
  esac
done
for job in test-bilingual-sv test-bilingual-slides-sv; do
  text=$(pdftotext "$job.pdf" -)
  case "$text" in
    *Exempel*) ;;
    *) fail "$job" "beamer's block title is not Swedish" ;;
  esac
  case "$text" in
    *Example*) fail "$job" "an English block title in the Swedish edition" ;;
  esac
done

pdftotext test-bilingual.pdf - | grep -q 'see section' \
  || fail test-bilingual "\\cref does not say section"
pdftotext test-bilingual-sv.pdf - | grep -q 'see avsnitt' \
  || fail test-bilingual-sv "\\cref does not say avsnitt"

pdftotext test-bilingual-off.pdf - | grep -q 'own ensv: x y' \
  || fail test-bilingual-off "own \\ensv is gone"
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
  rm -f test-bilingual-taken.pdf
  ${PDFLATEX:-pdflatex} -shell-escape -interaction=nonstopmode \
    -jobname=test-bilingual-taken \
    "\\documentclass{${CLASS:-article}}\\usepackage[british]{babel}$1\\begin{document}${2:-x}\\end{document}" \
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

# didactic defines no \tr: physics's \tr is the trace whichever of the two is
# loaded first, didactic says nothing about it, and \ensv works beside it.
for order in "\\usepackage{physics}\\usepackage{didactic}" \
  "\\usepackage{didactic}\\usepackage{physics}"; do
  taken "$order" "\$\\tr{4242}\$ \\ensv{ENWORD}{SVWORD}"
  if grep -q '^!' test-bilingual-taken.log; then
    fail physics "an error with $order"
  fi
  if grep -Eq 'Package didactic Warning.*\\tr([^a-z]|$)' \
    test-bilingual-taken.log; then
    fail physics "a warning about \\tr with $order"
  fi
  text=$(pdftotext test-bilingual-taken.pdf - 2>/dev/null)
  case "$text" in
    *ENWORD*) ;;
    *) fail physics "\\ensv missing with $order" ;;
  esac
  case "$text" in
    *SVWORD*) fail physics "\\ensv gave the other language with $order" ;;
  esac
  case "$text" in
    *tr*4242*) ;;
    *) fail physics "physics's \\tr is not the trace with $order" ;;
  esac
done

# A document's own \ensv, defined before didactic, stays the document's, with a
# warning, and \didactictr gives the edition's text.
taken "\\newcommand\\ensv[2]{OWN(#1,#2)}\\usepackage{didactic}" \
  "\\ensv{a}{b} \\didactictr{ENWORD}{SVWORD}"
grep -q 'Package didactic Warning: \\ensv is already defined' \
  test-bilingual-taken.log || fail own "no warning for an own \\ensv"
text=$(pdftotext test-bilingual-taken.pdf - 2>/dev/null)
case "$text" in
  *"OWN(a,b)"*) ;;
  *) fail own "the document's own \\ensv was overwritten" ;;
esac
case "$text" in
  *ENWORD*) ;;
  *) fail own "\\didactictr missing beside an own \\ensv" ;;
esac

# A block's cut file is the job's own.  \subimport makes \input look in the
# imported directory first, where a deck built on its own may have left a cut
# file of the same name; the block must not read that one.
mkdir -p test-bilingual-import.d
printf '\\begin{en}\nFRESHCUT\n\\end{en}\n' > test-bilingual-import.d/inner.tex
echo STALECUT > test-bilingual-import.d/test-bilingual-import.cut
rm -f test-bilingual-import.pdf
${PDFLATEX:-pdflatex} -shell-escape -interaction=nonstopmode \
  -jobname=test-bilingual-import \
  "\\documentclass{article}\\usepackage[british]{babel}\\usepackage{import}\\usepackage{didactic}\\begin{document}\\subimport{test-bilingual-import.d/}{inner}\\end{document}" \
  >/dev/null 2>&1
case "$(pdftotext test-bilingual-import.pdf - 2>/dev/null)" in
  *FRESHCUT*) ;;
  *) fail import "a stale cut file in the imported directory was read" ;;
esac

# didactic-sync.py writes a block pair's stamp at the end of its first
# \begin line.  That has to be a comment to LaTeX: the same text with and
# without it, in both editions, in notes under \subimport and in a fragile
# frame on the slides, under pdflatex and xelatex.
mkdir -p test-bilingual-stamp.d
for variant in plain stamped; do
  case $variant in
    plain) stamp= ;;
    stamped) stamp=' % sync en=3f9c1a sv=b20e7d' ;;
  esac
  printf '\\begin{en}%s\nENSTAMPED\n\\end{en}\n\\begin{sv}\nSVSTAMPED\n\\end{sv}\nAFTER\n' \
    "$stamp" > test-bilingual-stamp.d/$variant.tex
done
# A fragile frame ends at an \end{frame} on a line of its own, so the
# document is a file.
stamp_text() {
  rm -f test-bilingual-stamp.pdf
  printf '%s\n' "$2" > test-bilingual-stamp.tex
  $1 -shell-escape -interaction=nonstopmode test-bilingual-stamp.tex \
    >/dev/null 2>&1
  pdftotext test-bilingual-stamp.pdf - 2>/dev/null | tr -s ' \n' '  '
}
for engine in pdflatex xelatex; do
  for language in british:EN:SV swedish:SV:EN; do
    babel=${language%%:*} mine=${language#*:} mine=${mine%%:*}
    other=${language##*:}
    for kind in notes slides; do
      texts=
      for variant in plain stamped; do
        case $kind in
          notes) document="\\documentclass{article}\\usepackage[$babel]{babel}\\usepackage{import}\\usepackage{didactic}\\begin{document}\\subimport{test-bilingual-stamp.d/}{$variant}\\end{document}" ;;
          slides) document="\\documentclass{beamer}
\\usepackage[$babel]{babel}\\usepackage{import}\\usepackage{didactic}
\\begin{document}
\\begin{frame}[fragile]
\\subimport{test-bilingual-stamp.d/}{$variant}
\\end{frame}
\\end{document}" ;;
        esac
        text=$(stamp_text $engine "$document")
        case "$text" in
          *"${mine}STAMPED"*AFTER*) ;;
          *) fail stamp "$engine $babel $kind $variant: ${mine}STAMPED or AFTER missing" ;;
        esac
        case "$text" in
          *"${other}STAMPED"*) fail stamp "$engine $babel $kind $variant: ${other}STAMPED" ;;
        esac
        texts="$texts|$text"
      done
      plain_text=$(printf '%s' "$texts" | cut -d'|' -f2)
      stamped_text=$(printf '%s' "$texts" | cut -d'|' -f3)
      [ "$plain_text" = "$stamped_text" ] \
        || fail stamp "$engine $babel $kind: the stamp changes the text"
    done
  done
done

[ "$status" = 0 ] && echo "bilingual: all as expected"
exit $status
