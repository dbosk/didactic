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

# The test notes load beamerarticle with notheorems, so their example is this
# package's own, which follows babel anyway.  Notes without notheorems get
# beamer's, from translator, like the slides, and didactic sets translator up
# for them just as much.
cat > test-bilingual-titles.tex <<'TITLES'
\documentclass{memoir}
\PassOptionsToPackage{main=swedish}{babel}
\PassOptionsToPackage{english,swedish}{cleveref}
\usepackage{beamerarticle}
\input{test-bilingual-preamble.tex}
\begin{document}
\begin{example}NOTESEXAMPLE\end{example}
\begin{theorem}NOTESTHEOREM\end{theorem}
\end{document}
TITLES
rm -f test-bilingual-titles.pdf
${PDFLATEX:-pdflatex} -shell-escape -interaction=nonstopmode \
  test-bilingual-titles.tex >/dev/null 2>&1
text=$(pdftotext test-bilingual-titles.pdf - 2>/dev/null | tr -s ' \n' '  ')
case "$text" in
  *Exempel*NOTESEXAMPLE*Teorem*NOTESTHEOREM*) ;;
  *) fail titles "beamer's titles in Swedish notes without notheorems: $text" ;;
esac

# An author's own lines for translator, which the documentation asked for
# before didactic set it up itself, are harmless, before didactic or after.
for edition in british:EN:Example:Exempel swedish:SV:Exempel:Example; do
  babel=${edition%%:*} rest=${edition#*:} rest=${rest#*:}
  want=${rest%%:*} other=${rest#*:}
  for place in before after; do
    lines='\uselanguage{Swedish}\languagealias{swedish}{Swedish}'
    case $place in
      before) first=$lines second= ;;
      after) first= second=$lines ;;
    esac
    cat > test-bilingual-ownlines.tex <<OWNLINES
\documentclass{beamer}
\PassOptionsToPackage{main=$babel}{babel}
\usepackage[british,swedish]{babel}
$first
\usepackage{didactic}
$second
\begin{document}
\begin{frame}
\begin{example}OWNLINES\end{example}
\end{frame}
\end{document}
OWNLINES
    rm -f test-bilingual-ownlines.pdf
    ${PDFLATEX:-pdflatex} -shell-escape -interaction=nonstopmode \
      test-bilingual-ownlines.tex >/dev/null 2>&1
    text=$(pdftotext test-bilingual-ownlines.pdf - 2>/dev/null)
    case "$text" in
      *"$want"*OWNLINES*) ;;
      *) fail ownlines "$babel, lines $place didactic: no $want" ;;
    esac
    case "$text" in
      *"$other"*) fail ownlines "$babel, lines $place didactic: $other" ;;
    esac
  done
done

# nobilingual is the way to have didactic leave the languages alone: a Swedish
# beamer deck with it gets no set-up of translator, so beamer's titles stay
# English, as without didactic.
cat > test-bilingual-ownlines.tex <<'NOBILINGUAL'
\documentclass{beamer}
\usepackage[english,swedish]{babel}
\usepackage[nobilingual]{didactic}
\begin{document}
\begin{frame}
\begin{example}NOBILINGUAL\end{example}
\end{frame}
\end{document}
NOBILINGUAL
rm -f test-bilingual-ownlines.pdf
${PDFLATEX:-pdflatex} -shell-escape -interaction=nonstopmode \
  test-bilingual-ownlines.tex >/dev/null 2>&1
case "$(pdftotext test-bilingual-ownlines.pdf - 2>/dev/null)" in
  *Example*NOBILINGUAL*) ;;
  *) fail nobilingual "translator was set up, or the deck didn't build" ;;
esac

# cleveref's capitalise reaches this package's names too: the English edition
# with it says "Exercise 1" mid-sentence, beside cleveref's own "Section", and
# the Swedish edition without it "övningsuppgift 1" beside "avsnitt", as the
# decks are built.
for edition in british:swedish,english:capitalise swedish:english,swedish:; do
  babel=${edition%%:*} rest=${edition#*:}
  order=${rest%%:*} capitalise=${rest#*:}
  cat > test-bilingual-cref.tex <<CREF
\documentclass{memoir}
\PassOptionsToPackage{main=$babel}{babel}
\PassOptionsToPackage{$order}{cleveref}
\PassOptionsToPackage{$capitalise}{cleveref}
\usepackage[noamsthm,notheorems]{beamerarticle}
\input{test-bilingual-preamble.tex}
\begin{document}
\section{S}\label{sec:cref}
\begin{exercise}\label{ex:one}A.\end{exercise}
\begin{exercise}\label{ex:two}B.\end{exercise}
MID \cref{ex:one} beside \cref{sec:cref}. PLURAL \cref{ex:one,ex:two}.
\end{document}
CREF
  rm -f test-bilingual-cref.pdf
  for pass in 1 2; do
    ${PDFLATEX:-pdflatex} -shell-escape -interaction=nonstopmode \
      test-bilingual-cref.tex >/dev/null 2>&1
  done
  text=$(pdftotext test-bilingual-cref.pdf - 2>/dev/null | tr -s ' \n' '  ')
  case $babel in
    british) want="MID Exercise 1 beside Section*PLURAL Exercises 1 and 2" ;;
    swedish) want="MID övningsuppgift 1 beside avsnitt*PLURAL övningsuppgifterna 1 och 2" ;;
  esac
  case "$text" in
    *$want*) ;;
    *) fail cref "$babel, ${capitalise:-no capitalise}: $text" ;;
  esac
done

# Blocks and strings in babel's names: a block is \begin{onlyin}{<name>}, and
# the edition is babel's main language, by its tag, whichever it is.  The same
# source in three editions, British (English), Swedish and German; a block
# named english belongs to the British edition.
mkdir -p test-bilingual-names.d
cat > test-bilingual-names.d/inner.tex <<'INNER'
\begin{onlyin}{english}
ENINNER
\end{onlyin}
\begin{onlyin}{swedish}
SVINNER
\end{onlyin}
\begin{onlyin}{ngerman}
DEINNER
\end{onlyin}
INNER
names_document() {
  cat > test-bilingual-names.tex <<NAMES
\documentclass{article}
\usepackage[english,british,swedish,ngerman,main=$1]{babel}
\usepackage{hyperref}
\usepackage{didactic}
\begin{document}
\tableofcontents
\section{\didactictr[english,swedish,ngerman]{ENTITLE}{SVTITLE}{DETITLE}}
\begin{onlyin}{english}
ENBLOCK
\input{test-bilingual-names.d/inner}
\end{onlyin}
\begin{onlyin}{swedish}
SVBLOCK
\input{test-bilingual-names.d/inner}
\end{onlyin}
\begin{onlyin}{ngerman}
DEBLOCK
\input{test-bilingual-names.d/inner}
\end{onlyin}
SHARED $2
\end{document}
NAMES
  rm -f test-bilingual-names.pdf test-bilingual-names.aux \
    test-bilingual-names.toc test-bilingual-names.out
  for pass in 1 2; do
    ${PDFLATEX:-pdflatex} -shell-escape -interaction=nonstopmode \
      test-bilingual-names.tex >/dev/null 2>&1
  done
}
for edition in british:EN swedish:SV ngerman:DE; do
  babel=${edition%%:*} mine=${edition#*:}
  names_document $babel \
    '\ensv{ENPAIR}{SVPAIR}\sven{SVSVEN}{ENSVEN}\didactictr{ENOLD}{SVOLD}'
  if [ $babel = ngerman ]; then
    # those three strings have no German text: errors, checked below
    :
  elif command grep -q '^!' test-bilingual-names.log; then
    fail names "$babel: $(command grep -m1 '^!' test-bilingual-names.log)"
  fi
  text=$(pdftotext test-bilingual-names.pdf - 2>/dev/null | tr -s ' \n' '  ')
  want="${mine}BLOCK ${mine}INNER"
  case "$text" in
    *"${mine}TITLE"*"${mine}TITLE"*"$want"*SHARED*) ;;
    *) fail names "$babel: not its title, block and inner block: $text" ;;
  esac
  # the inner file is input in every outer block: once shown, twice dropped
  # with its excluded outer block
  [ "$(printf '%s' "$text" | command grep -o "${mine}INNER" | wc -l)" = 1 ] \
    || fail names "$babel: ${mine}INNER isn't there exactly once"
  for other in EN SV DE; do
    [ $other = $mine ] && continue
    case "$text" in
      *"${other}BLOCK"*|*"${other}INNER"*|*"${other}TITLE"*)
        fail names "$babel: the ${other} edition's text" ;;
    esac
  done
  bookmarks=$(sed 's/\\000//g' test-bilingual-names.out 2>/dev/null)
  case "$bookmarks" in
    *"${mine}TITLE"*) ;;
    *) fail names "$babel: the bookmark isn't ${mine}TITLE: $bookmarks" ;;
  esac
  case $babel in
    british) want="ENPAIRENSVENENOLD" ;;
    swedish) want="SVPAIRSVSVENSVOLD" ;;
    ngerman) want="" ;;
  esac
  case "$text" in
    *"SHARED $want"*) ;;
    *) fail names "$babel: the strings aren't $want: $text" ;;
  esac
done
# A string with no text for the edition stops, naming its languages.
command grep -q "no text for the edition.*de" test-bilingual-names.log \
  || fail names "\\ensv in the German edition isn't an error"
command grep -q "english and swedish\|english,swedish" test-bilingual-names.log \
  || fail names "the error doesn't name the string's languages"

# A tag where babel's name belongs, and a block of version 2.17, stop with
# the form to write.
block_document() {
  printf '%s\n' '\documentclass{article}' \
    '\usepackage[british,swedish]{babel}' '\usepackage{didactic}' \
    '\begin{document}' "$1" X "$2" '\end{document}' \
    > test-bilingual-names.tex
  rm -f test-bilingual-names.pdf
  ${PDFLATEX:-pdflatex} -shell-escape -interaction=nonstopmode \
    test-bilingual-names.tex >/dev/null 2>&1
}
block_document '\begin{onlyin}{sv}' '\end{onlyin}'
command grep -q "begin{onlyin}{swedish}" test-bilingual-names.log \
  || fail names "\\begin{onlyin}{sv} doesn't name \\begin{onlyin}{swedish}"
if pdftotext test-bilingual-names.pdf - 2>/dev/null | grep -q X; then
  fail names "\\begin{onlyin}{sv} isn't skipped"
fi
block_document '\begin{onlyin}{klingon}' '\end{onlyin}'
command grep -q "Unknown language .klingon." test-bilingual-names.log \
  || fail names "\\begin{onlyin}{klingon} isn't an unknown language"
block_document '\begin{en}' '\end{en}'
command grep -q "begin{onlyin}{english}" test-bilingual-names.log \
  || fail names "\\begin{en} doesn't name \\begin{onlyin}{english}"
command grep -q -- "--migrate" test-bilingual-names.log \
  || fail names "\\begin{en} doesn't name --migrate"
block_document '\begin{sv}' '\end{sv}'
command grep -q "begin{onlyin}{swedish}" test-bilingual-names.log \
  || fail names "\\begin{sv} doesn't name \\begin{onlyin}{swedish}"
# a list of languages may have spaces after its commas (the edition is
# swedish, babel's last language)
block_document '\didactictr[english, swedish]{ENSPACE}{SVSPACE}' ''
pdftotext test-bilingual-names.pdf - 2>/dev/null | grep -q SVSPACE \
  || fail names "\\didactictr[english, swedish] has no Swedish text"

# language= takes babel's name, and overrides babel's main language; a tag is
# an error that names the name, there and in \didacticlanguage; a language
# that only babel knows, not the package's table, is an edition too.
edition_document() {
  printf '%s\n' '\documentclass{article}' "\\usepackage[$1]{babel}" \
    "\\usepackage$2{didactic}" '\begin{document}' \
    '\begin{onlyin}{english}' ENEDITION '\end{onlyin}' \
    '\begin{onlyin}{swedish}' SVEDITION '\end{onlyin}' \
    "\\begin{onlyin}{estonian}" ETEDITION '\end{onlyin}' \
    '\end{document}' > test-bilingual-names.tex
  rm -f test-bilingual-names.pdf
  ${PDFLATEX:-pdflatex} -shell-escape -interaction=nonstopmode \
    test-bilingual-names.tex >/dev/null 2>&1
  pdftotext test-bilingual-names.pdf - 2>/dev/null | tr -s ' \n' '  '
}
case "$(edition_document british,swedish,estonian,main=british '[language=swedish]')" in
  *SVEDITION*) ;;
  *) fail names "language=swedish doesn't give the Swedish edition" ;;
esac
edition_document british,swedish '[language=sv]' >/dev/null
command grep -A1 "not the tag .sv." test-bilingual-names.log \
  | grep -q "write swedish" || fail names "language=sv doesn't name swedish"
block_document '\didacticlanguage{en}' ''
command grep -A1 "not the tag .en." test-bilingual-names.log \
  | grep -q "write english" || fail names "\\didacticlanguage{en} doesn't name english"
edition_document british,swedish '[language=klingon]' >/dev/null
command grep -q "Unknown language .klingon." test-bilingual-names.log \
  || fail names "language=klingon isn't an unknown language"
for setup in "main=estonian:" "main=british:[language=estonian]"; do
  case "$(edition_document british,swedish,estonian,${setup%%:*} "${setup#*:}")" in
    *ETEDITION*) ;;
    *) fail names "estonian, which only babel knows, isn't an edition ($setup)" ;;
  esac
done

# The test documents are examples too, so the script must find nothing wrong
# with them: no error, and no stamp in a form that it no longer reads.
# test-bilingual-off.tex loads the package with nobilingual and has its own
# environment en, which the script leaves alone with a note.
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
# follows babel only once didactic has set it up, with no lines in the
# preamble; this
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
for name in comment onlyin; do
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
    stamped) stamp=' % sync english=3f9c1a swedish=b20e7d' ;;
  esac
  printf '\\begin{onlyin}{english}%s\nENSTAMPED\n\\end{onlyin}\n\\begin{onlyin}{swedish}\nSVSTAMPED\n\\end{onlyin}\nAFTER\n' \
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
