LATEX?=latex
PDFLATEX?=xelatex
LATEXFLAGS=-shell-escape
PYTHONTEX=python3 $(shell which pythontex) --interpreter python:python3

# A failed check leaves no PDF, so that the next make doesn't call it up to date.
.DELETE_ON_ERROR:

# The cases of frame titles, one file per kind; see the header of each file.
TEST_FRAMETITLE_CASES=	test-frametitle-overlay test-frametitle-floats \
			test-frametitle-boxes test-frametitle-end \
			test-frametitle-template \
			test-frametitle-template-after \
			test-frametitle-noarticle test-frametitle-article
TEST_KEEP_CHAPTER=	test-keep-chapter-article test-keep-chapter-memoir \
			test-keep-chapter-book
TEST_KEEP_NOWEB=	test-keep-filbreak test-keep-breakcode \
			test-keep-breakcode-late test-keep-filbreak-nogap
TEST_KEEP_SMALL=	test-keep-style test-keep-columns test-keep-guard \
			test-keep-pagereset test-keep-nofiles test-keep-nofiles0 test-keep-box \
			test-keep-addvspace test-keep-club test-keep-club-article
TEST_NOTEOVERFLOW=	test-noteoverflow test-noteoverflow-lua test-noteoverflow-carry \
			test-noteoverflow-draft test-noteoverflow-draftbreak \
			test-noteoverflow-xe test-noteoverflow-old
# The order of float numbers, from the pages the floats end up on.
TEST_FLOATORDER=	test-marginfloat-samepar test-marginfloat-moved \
			test-marginfloat-chapters test-marginfloat-kinds \
			test-marginfloat-article
# The same with \includeonly, from the .aux files of the whole document.
TEST_INCLUDE=		test-marginfloat-include-all test-marginfloat-include
# Warnings from where listings ended up.
TEST_KEEPCHECK=		test-keep-leadin test-keep-leadin-off test-keep-overfull \
			test-keep-multicol test-keep-twocol test-keep-noweb \
			test-keep-noweb-break test-keep-once test-keep-enumitem test-keep-first \
			test-keep-parted

.PHONY: all
all: didactic.sty didactic.pdf didactic.tar.gz test.pdf test-footcite.pdf \
	test-footcite-twoside.pdf test-footcite-memoir.pdf test-run.pdf \
	test-note-heading.pdf test-pair.pdf test-pair-slides.pdf \
	test-sidecap.pdf test-sidecap-off.pdf \
	test-marginfloat.pdf test-marginfloat-slides.pdf \
	test-frametitle.pdf test-frametitle-slides.pdf \
	test-keep.pdf test-keep-tall.pdf test-keep-tall100.pdf \
	test-keep-chain.pdf test-keep-huge.pdf test-keep-blank.pdf test-keep-include.pdf \
		test-keep-heading.pdf test-keep-heading3.pdf \
		test-keep-nogap.pdf test-keep-nogap3.pdf test-keep-sweep \
		${TEST_KEEP_NOWEB:=.pdf} ${TEST_KEEP_SMALL:=.pdf} \
	test-keep-flush.pdf ${TEST_KEEP_CHAPTER:=.pdf} test-keep-stale.pdf \
	${TEST_NOTEOVERFLOW:=.pdf} test-oldkernel.pdf \
	test-margin-log.pdf test-margin-log-article.pdf \
	${TEST_FRAMETITLE_CASES:=.pdf} \
	test-marginfloat-cases.pdf test-marginfloat-order.pdf \
	test-marginfloat-inorder.pdf test-marginfloat-hidden.pdf \
	${TEST_FLOATORDER:=.pdf} test-marginfloat-include.pdf \
	test-format.pdf test-oldkernel-title.pdf test-biburl check

SRC+=	didactic.dtx idea.tex lightblock.tex ProvideSemanticEnv.tex pairruns.tex
SRC+=	marginfloats.tex
SRC+=	hello.py ask.py askmany.py greet.py filter.py pairgreet1.py pairgreet2.py
SRC+=	pairwrite.py pairread.py
# The review behind the decisions on page breaks: the appendix and its sources, and
# what it was made from, which isn't read in the build (a record of the searches).
SRC+=	appendix.tex appendix-measure.tex appendix-hitlist.tex didactic.bib
LIT_RECORD=	heading-foot-of-page.csv $(wildcard queries/*.csv) \
		queries/t-pen.py queries/t-pen-memoir.py queries/pen.py queries/heading-room.py \
		queries/pen-results.txt $(wildcard measure-flow/*.py measure-flow/*.sh measure-flow/*.md) \
		$(wildcard measure-real/*.py) measure-real/README.md \
		measure-real/measure-real.conf.example

# The change history (\PrintChanges) needs makeindex on the .glo file; that
# also checks that every \changes entry can be written and typeset.
didactic.pdf: ${SRC} didactic.sty
	-${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PYTHONTEX} didactic
	biber didactic
	${PDFLATEX} ${LATEXFLAGS} $<
	makeindex -s gglo.ist -o didactic.gls didactic.glo
	grep -q 'work in a source shared' didactic.gls
	grep -q 'a frame title is a run-in heading' didactic.gls
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<
	! grep -E 'Empty bibliography|Citation .*undefined|could not be found' didactic.log
	! grep -E 'WARN|ERROR' didactic.blg
	! grep -E 'Reference .*undefined' didactic.log
	pdftotext didactic.pdf - | tr -d '\f' | grep -q '^References$$'

# docstrip asks before overwriting, so remove the old file first.
didactic.sty: didactic.ins didactic.dtx
	${RM} $@
	${LATEX} ${LATEXFLAGS} $<

didactic.tar.gz: ${SRC} ${LIT_RECORD} didactic.ins LICENSE Makefile README.md didactic.pdf
	tar -czf $@ --transform "s|^|didactic/|" $^

test.pdf: test.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} $<

# footnote-reuse test: needs biber and two more passes so zref abspage labels
# resolve from the .aux.
test-footcite.pdf: test-footcite.tex test-footcite.bib didactic.sty
	${PDFLATEX} ${LATEXFLAGS} $<
	biber test-footcite
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<

# same as above but exercises cross-spread reuse under twoside.
test-footcite-twoside.pdf: test-footcite-twoside.tex test-footcite.bib didactic.sty
	${PDFLATEX} ${LATEXFLAGS} $<
	biber test-footcite-twoside
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<

# modes of footnote reuse (reuse, reserve, given up) with memoir's margin
# footnotes; the states are forced in the document, so it settles quickly.
test-footcite-memoir.pdf: test-footcite-memoir.tex test-footcite.bib didactic.sty
	${PDFLATEX} ${LATEXFLAGS} $<
	biber test-footcite-memoir
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<

# run tests: \runpython with stdin, args and transcripts. Needs pythontex, like
# didactic.pdf; the first pass fails on the missing pythontex output.
TEST_RUN_EXAMPLES=	ask.py askmany.py greet.py filter.py slowask.py loop.py boom.py \
	test-basedir/contents.tex test-basedir/examples/readdata.py \
	test-basedir/examples/data.txt
test-run.pdf: test-run.tex didactic.sty ${TEST_RUN_EXAMPLES}
	-${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PYTHONTEX} test-run
	${PDFLATEX} ${LATEXFLAGS} $<

test-note-heading.pdf: test-note-heading.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} $<

# side captions; twice, since memoir finds odd and even pages from the .aux
test-sidecap.pdf test-sidecap-off.pdf: %.pdf: %.tex test-sidecap.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<

# margin floats, in the notes and on the slides, from one source; twice, for
# the references and marginfix's anchors.
TEST_MARGINFLOAT_SRC=	test-marginfloat-contents.tex marginfloats.tex
test-marginfloat.pdf test-marginfloat-slides.pdf: %.pdf: %.tex didactic.sty \
		${TEST_MARGINFLOAT_SRC}
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<
test-marginfloat-cases.pdf test-marginfloat-hidden.pdf: %.pdf: %.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<
test-marginfloat-order.pdf test-marginfloat-inorder.pdf: %.pdf: %.tex \
		test-marginfloat-order.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<
${TEST_FLOATORDER:=.pdf}: %.pdf: %.tex didactic.sty
	@${latex_until_settled}
# The whole document first: the .aux files of the chapters that the second one
# leaves out are its input as much as its sources.  Three runs of the second: its
# first has no main .aux yet, so it can't take over the left out chapter's counters.
test-marginfloat-include-all.pdf: test-marginfloat-include-all.tex \
		test-marginfloat-include-a.tex test-marginfloat-include-b.tex \
		didactic.sty
	${RM} test-marginfloat-include-a.aux test-marginfloat-include-b.aux
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<
test-marginfloat-include.pdf: test-marginfloat-include.tex \
		test-marginfloat-include-all.pdf
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<

# What the headers of the tests expect, from the PDFs and logs: building a test
# only shows that LaTeX didn't stop.  Phony, so that it runs every time, also
# on PDFs that are up to date.
CHECKED_TESTS=	test-marginfloat test-marginfloat-slides test-marginfloat-cases \
		test-marginfloat-order test-marginfloat-inorder \
		test-marginfloat-hidden test-frametitle test-frametitle-slides \
		test-block-nested ${TEST_FRAMETITLE_CASES} ${TEST_FLOATORDER} ${TEST_INCLUDE} \
		${TEST_KEEPCHECK} test-oldkernel-title
# Deliberate breaks of the source, and which tests catch them: see test-mutants.txt.
# Not part of all: it takes hours.
.PHONY: mutants
mutants: test-mutants.py test-mutants.txt
	python3 test-mutants.py ${MUTANTS}

.PHONY: check
check: test-check.py ${CHECKED_TESTS:=.pdf}
	python3 test-check.py ${CHECKED_TESTS}

# a format from before the hooks we use: the warning from didactic itself, so
# right after the log opens the file, since other packages ask for releases too.
test-format.pdf: test-format.tex didactic.sty
	-${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	grep -A2 'didactic.sty$$' test-format.log | grep -q 'You have requested release'

# frame titles, in the notes and on the slides, from one source; twice, since
# beamer asks for a rerun for its outline.
test-frametitle.pdf test-frametitle-slides.pdf: %.pdf: %.tex didactic.sty \
		test-frametitle-contents.tex
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<
test-block-nested.pdf ${TEST_FRAMETITLE_CASES:=.pdf} test-oldkernel-title.pdf: %.pdf: %.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<

# code side by side, in the notes and on the slides; minted needs
# -shell-escape and a run after pythontex to insert the highlighted code.
TEST_PAIR_EXAMPLES=	pairgreet1.py pairgreet2.py hello.py pairtabs.py \
			pairwrite.py pairread.py pairruns.tex
test-pair.pdf test-pair-slides.pdf: %.pdf: %.tex didactic.sty ${TEST_PAIR_EXAMPLES}
	-${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PYTHONTEX} $*
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<

# Run LaTeX on $< until the references settle.  Without a cache minted sets its
# listings as plain text in the first pass, with no labels, so on a fresh checkout
# the page references take three passes, later builds two.  At least two, for
# that plain text.  Fail if they never settle.
define latex_until_settled
${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $< || exit 1; \
for i in 1 2 3 4 5; do \
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $< || exit 1; \
	grep -q 'Rerun to get' $(basename $<).log || exit 0; \
done; echo "$<: references did not settle"; exit 1
endef

# listings kept together across pages.  The document checks its pages itself
# and logs PASS or FAIL for each check, and a last line if it got there.  A
# failed test leaves no PDF, only the log (.DELETE_ON_ERROR), so that the next
# make doesn't call it up to date.  Like test-run, the first pass fails on the
# missing pythontex output, and make ignores that (-); the passes after it don't.
# The passes before the last can still log FAIL lines (cases E, F, S, Y and R, whose
# pages depend on the .aux), as the references settle; only the last pass, whose log
# the greps read, counts.
test-keep.pdf: test-keep.tex didactic.sty
	-${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PYTHONTEX} test-keep
	@${latex_until_settled}
	! grep -E 'didactic keep test:.*(FAIL|SKIP)' test-keep.log
	grep -q 'didactic keep test: all checks ran' test-keep.log
	! grep 'Overfull .vbox' test-keep.log
	pdftotext -layout test-keep.pdf - | grep -Eq '^ *1\. +qline 1$$'
	test "$$(pdftotext test-keep.pdf - | awk -v RS='\f' '/wline 1\n/ && /wline 30/ {n++} /wline 27/ && /wline 30/ {m++} END {print n+0, m+0}')" = "0 1"

# listings too tall for a page, and what warns when one can't be kept: see the
# documents.  Words that are off the paper aren't in pdftotext's output.
count_word=$$(pdftotext $@ - | grep -o $(1) | wc -l)
count_warn=$$(grep -c 'Package didactic Warning: .*$(1)' $(basename $@).log)

test-keep-tall.pdf: test-keep-tall.tex didactic.sty
	@${latex_until_settled}
	! grep 'Overfull .vbox' test-keep-tall.log
	test "${call count_word,word}" -eq 1600
	test "${call count_word,third}" -eq 2041
	test "${call count_word,long}" -eq 8161
	test "${call count_warn,too tall}" -eq 2
	test "${call count_warn,can.t keep}" -eq 1
	test "${call count_warn,something between}" -eq 1
	test "${call count_word,marked}" -eq 8
	test "${call count_warn,doesn.t fit}" -eq 0

test-keep-tall100.pdf: test-keep-tall100.tex test-keep-tall.tex didactic.sty
	@${latex_until_settled}
	! grep 'Overfull .vbox' test-keep-tall100.log
	test "${call count_word,unit}" -eq 90
	test "$$(pdftotext $@ - | awk -v RS='\f' '/Half a page/ && /unit 10\n/ {n++} /unit 88\n/ && /unit 90\n/ {m++} END {print n+0, m+0}')" = "1 1"
	test "${call count_word,fitting}" -eq "$$(wc -l < test-keep-tall100-f.txt)"
	test "${call count_warn,too tall}" -eq 2
	test "${call count_warn,doesn.t fit}" -eq 0

# what is kept with a listing makes the page overfull: that can't be undone,
# so it must warn.
test-keep-chain.pdf: test-keep-chain.tex didactic.sty
	@${latex_until_settled}
	grep -q 'Overfull .vbox' test-keep-chain.log
	test "${call count_warn,doesn.t fit}" -eq 2
	test "${call count_word,chained}" -eq 40
	test "${call count_word,boxed}" -eq 0

# warnings from where things ended up, checked by test-check.py; see the documents.
test-keep-noweb.pdf test-keep-noweb-break.pdf: %.pdf: %.tex \
		test-keep-noweb-body.tex didactic.sty
	@${latex_until_settled}
test-keep-leadin.pdf test-keep-leadin-off.pdf: %.pdf: %.tex \
		test-keep-leadin-body.tex didactic.sty
	@${latex_until_settled}
test-keep-enumitem.pdf test-keep-once.pdf test-keep-overfull.pdf test-keep-multicol.pdf test-keep-twocol.pdf \
		test-keep-first.pdf test-keep-parted.pdf: %.pdf: %.tex didactic.sty
	@${latex_until_settled}
# The cases are set for the fonts of pdflatex.
test-keep-parted.pdf: PDFLATEX=pdflatex

# The whole document first: the .aux files of what the second leaves out are its input.
test-keep-include-all.pdf: test-keep-include-all.tex test-keep-include-a.tex \
		test-keep-include-b.tex didactic.sty
	${RM} test-keep-include-a.aux test-keep-include-b.aux
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
test-keep-include.pdf: test-keep-include.tex test-keep-include-all.pdf
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	! grep -q 'didactic@hn@' test-keep-include.log
	test "${call count_warn,The heading in a file left out}" -eq 1

test-keep-blank.pdf: test-keep-blank.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	! grep 'didactic blank test: WRONG' test-keep-blank.log
	test "$$(grep -c 'didactic blank test: right' test-keep-blank.log)" -eq 25
	grep -q 'didactic blank test: all ran' test-keep-blank.log

# multicol from the distribution: noweb's examples, in a texmf tree, have an old copy,
# with no multicols*.
test-keep-multicol.pdf: export TEXINPUTS:=$(shell kpsewhich -var-value=TEXMFDIST)/tex/latex/tools::

test-keep-huge.pdf: test-keep-huge.tex didactic.sty
	@${latex_until_settled}
	grep -q 'Package didactic Warning: Line 1 of a listing .*taller than a page' test-keep-huge.log
	grep -A3 'taller than a page' test-keep-huge.log | grep -q 'is lost'
	grep -A3 'taller than a page' test-keep-huge.log | grep -q 'input line 23'
	! grep 'may break\|between its lines' test-keep-huge.log

# a heading keeps its lines, within keepmaxgap, or warns: see the documents.
# Each document also runs with keepafterheading=3 (the files ending in 3 only set
# that), where more is asked of the chain and the estimate.
test-keep-heading.pdf test-keep-heading3.pdf: %.pdf: %.tex test-keep-heading.tex \
		didactic.sty
	@${latex_until_settled}
	! grep -E 'didactic heading test:.*FAIL' $*.log
	grep -q 'didactic heading test: all checks ran' $*.log
	! grep 'Overfull .vbox' $*.log
	test "$$(grep -c 'Package didactic Warning: .*Only 1 of' $*.log)" -eq 0
	test "$$(grep -c 'Package didactic Warning: .*Only 2 of' $*.log)" -eq ${ONLY2}
	test "${call count_warn,What starts at}" -eq 1
	test "$$(grep -c 'didactic heading test.*PASS' $*.log)" -ge 40
test-keep-heading.pdf: ONLY2=0
test-keep-heading3.pdf: ONLY2=3

test-keep-nogap.pdf test-keep-nogap3.pdf: %.pdf: %.tex test-keep-nogap.tex \
		test-basedir/keep1/x.tex test-basedir/keep2/x.tex \
		test-basedir/keep3.tex didactic.sty
	@${latex_until_settled}
	! grep -E 'didactic heading test:.*FAIL' $*.log
	grep -q 'didactic heading test: all checks ran' $*.log
	test "$$(grep -c 'Package didactic Warning: The heading in test-keep-nogap' $*.log)" -eq ${NOGAP_HEADINGS}
	! grep 'Overfull .vbox' $*.log
test-keep-nogap.pdf: NOGAP_HEADINGS=0
test-keep-nogap3.pdf: NOGAP_HEADINGS=1

# page breaks around headings and listings, room by room, against plain LaTeX with
# the same fonts and margins: see test-keep-sweep.py.  pdflatex, for those fonts.
SWEEP=m a s s3 e c m3 k k3
SWEEP_ALL=${SWEEP} mp ap sp ep cp kp mq aq sq
${SWEEP_ALL:%=test-keep-sweep-%.tex}: test-keep-sweep-%.tex: test-keep-sweep.py
	python3 $< gen $* > $@
${SWEEP_ALL:%=test-keep-sweep-%.pdf}: PDFLATEX=pdflatex
${SWEEP_ALL:%=test-keep-sweep-%.pdf}: %.pdf: %.tex didactic.sty
	@${latex_until_settled}
	! grep 'Overfull .vbox' $*.log
.PHONY: test-keep-sweep
test-keep-sweep: test-keep-sweep.py ${SWEEP_ALL:%=test-keep-sweep-%.pdf}
	rc=0; for v in ${SWEEP}; do python3 $< check $$v || rc=1; done; exit $$rc

# noweb without breakcode warns, once; with breakcode, however it is set, it doesn't.
${TEST_KEEP_NOWEB:=.pdf}: %.pdf: %.tex didactic.sty
	@${latex_until_settled}
	test "${call count_warn,Code chunks of noweb}" -eq "${FILBREAK_WARNINGS}"
	test -z "${LATE_CHECK}" || grep -q 'didactic late test: PASS' $*.log
test-keep-breakcode-late.pdf: LATE_CHECK=yes
test-keep-filbreak.pdf: FILBREAK_WARNINGS=1
test-keep-breakcode.pdf test-keep-breakcode-late.pdf test-keep-filbreak-nogap.pdf: \
		FILBREAK_WARNINGS=0

# the keep options in small documents; see each of them.  The first runs at each
# keepafterheading.
test-keep-style.pdf: test-keep-style.tex didactic.sty
	for k in 0 2 3; do \
		${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode \
			"\def\testk{$$k}\input{test-keep-style}" || exit 1; \
		! grep -E 'didactic style test:.*FAIL' test-keep-style.log || exit 1; \
		grep -q 'didactic style test: all checks ran' test-keep-style.log || exit 1; \
		test "$$(grep -c 'didactic style ran' test-keep-style.log)" -eq 1 || exit 1; \
		! grep '^!' test-keep-style.log || exit 1; \
	done
test-keep-columns.pdf: test-keep-columns.tex didactic.sty
	@${latex_until_settled}
	test "${call count_warn,In columns}" -eq 1
test-keep-guard.pdf: test-keep-guard.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	for m in hpage tp hb hm after pp; do \
		grep -q "providecommand.@didactic@keep@$$m" test-keep-guard.aux || exit 1; \
	done
	sed -i '/providecommand/d' test-keep-guard.aux
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode \
		"\def\testbeamer{}\input{test-keep-guard}"
	! grep '^!' test-keep-guard.log
test-keep-pagereset.pdf: test-keep-pagereset.tex didactic.sty
	@${latex_until_settled}
	test "$$(grep -c 'keepafterheading): it moves' test-keep-pagereset.log)" -eq 2
	! grep "heading in test-keep-pagereset, line $$(grep -n 'Stays, number raised' test-keep-pagereset.tex | cut -d: -f1)" test-keep-pagereset.log
test-keep-nofiles.pdf test-keep-nofiles0.pdf: %.pdf: %.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	test "${call count_warn,With .nofiles}" -eq 1
test-keep-box.pdf test-keep-club.pdf test-keep-club-article.pdf: %.pdf: %.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	! grep -E 'didactic (box|club) test:.*FAIL' $*.log
	grep -Eq 'didactic (box|club) test: all checks ran' $*.log
test-keep-club-article.pdf: test-keep-club.tex
test-keep-addvspace.pdf: test-keep-addvspace.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode "\def\testk{0}\input{test-keep-addvspace}"
	sed -n 's/^didactic addvspace: //p' test-keep-addvspace.log > test-keep-addvspace.k0
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode "\def\testk{2}\input{test-keep-addvspace}"
	sed -n 's/^didactic addvspace: //p' test-keep-addvspace.log | cmp - test-keep-addvspace.k0
	test -s test-keep-addvspace.k0

# a heading that ends a page under \flushbottom leaves the space at the foot.
test-keep-flush.pdf: test-keep-flush.tex didactic.sty
	@${latex_until_settled}
	test "$$(pdfinfo $@ | sed -n 's/^Pages: *//p')" -eq 2
	! grep 'Underfull .vbox' test-keep-flush.log

# a \chapter isn't taken for the section before it: one page in the .aux per
# section, and an entry for a table only if a section stands in for the chapter.
${TEST_KEEP_CHAPTER:=.pdf}: %.pdf: %.tex didactic.sty
	@${latex_until_settled}
	test "$$(grep -c '^.@didactic@keep@hpage' $*.aux)" -eq "$$(grep -c '^.section\*' $*.tex)"
	test "$$(grep -c '^.@didactic@keep@tp' $*.aux)" -eq "$$(grep -c '^.section\*.After' $*.tex)"

# the break before a heading doesn't go stale; see the script.
test-keep-stale.pdf: test-keep-stale.tex test-keep-stale.sh didactic.sty
	sh test-keep-stale.sh "${PDFLATEX} ${LATEXFLAGS}"

# noteoverflow.  break needs pdfTeX or LuaTeX, so these name the engine, except
# test-noteoverflow-xe, which is about the engine that can't; test-noteoverflow-lua
# is test-noteoverflow under LuaLaTeX.
NOTEOVERFLOW_SRC=	test-noteoverflow-contents.tex didactic.sty
test-noteoverflow.pdf test-noteoverflow-carry.pdf test-noteoverflow-draft.pdf \
		test-noteoverflow-draftbreak.pdf: PDFLATEX=pdflatex
test-noteoverflow-lua.pdf: PDFLATEX=lualatex
define settle_many
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do \
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $< || exit 1; \
	grep -q 'Rerun to get' $(basename $<).log || exit 0; \
done; echo "$<: references did not settle"; exit 1
endef
count_spill=$$(grep -c 'marginfix-spill.*$(1)' $(basename $@).log)
test-noteoverflow.pdf test-noteoverflow-lua.pdf test-noteoverflow-draftbreak.pdf: %.pdf: %.tex \
		${NOTEOVERFLOW_SRC}
	@${settle_many}
	! grep '^!' $*.log
	test "$$(grep -c 'marginfix-spill' $*.log)" -eq 0
	test "$$(grep -c 'mfx@yield' $*.aux)" -gt 0
test-noteoverflow-carry.pdf test-noteoverflow-draft.pdf: %.pdf: %.tex ${NOTEOVERFLOW_SRC}
	@${settle_many}
	! grep '^!' $*.log
	test "${call count_spill,intended}" -gt 0
	test "${call count_spill,unresolved}" -eq 0
	test "$$(grep -c 'mfx@yield' $*.aux)" -eq 0
test-noteoverflow-xe.pdf: %.pdf: %.tex ${NOTEOVERFLOW_SRC}
	@${settle_many}
	! grep '^!' $*.log
	test "${call count_spill,unresolved}" -gt 0
	test "${call count_warn,A margin note from page}" -eq "${call count_spill,unresolved}"
test-noteoverflow-old.pdf: test-noteoverflow-old.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	! grep '^!' test-noteoverflow-old.log
	test "${call count_warn,option noteoverflow needs marginfix}" -eq 1
	test "${call count_warn,marginnoteoverflow needs marginfix}" -eq 1

# the place of the margin column in the log against where a note is printed.
test-margin-log.pdf test-margin-log-article.pdf: %.pdf: %.tex test-margin-log.tex \
		test-margin-log.sh didactic.sty
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	./test-margin-log.sh $*

# a kernel from before \fpeval; see the document.
test-oldkernel.pdf: test-oldkernel.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	grep -q 'didactic-margin: odd=[0-9.]* even=[0-9.]* width=[0-9.]*' test-oldkernel.log

# biburlpenalty and bibemergencystretch: biblatex's URL break penalties, which
# didactic leaves alone (biburlpenalty breaks URLs its own way), and the
# bibliography's \emergencystretch, with biblatex loaded before didactic,
# after it or not at all; one run per case, order:options:penalty set in
# the preamble:expected penalty:stretch set in the preamble:expected stretch.
BIBURL_CASES=before:::0::3em after:::0::3em \
	before:biburlpenalty=500::0::3em after:biburlpenalty::0::3em \
	after:biburlpenalty=0::0::3em before:biburlpenalty=-5::0::3em \
	before::100:100::3em after::100:100::3em \
	before:bibemergencystretch=1em::0::1em \
	after:bibemergencystretch=0pt::0::0pt \
	before:::0:2em:2em after:::0:2em:2em none:::0::
.PHONY: test-biburl
test-biburl: test-biburl.tex didactic.sty test-biburl-overfull.pdf \
		test-biburl-breaks
	for c in ${BIBURL_CASES}; do \
	  IFS=:; set -- $$c; unset IFS; ${RM} test-biburl.aux; \
	  ${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode \
	    "\\def\\testorder{$$1}\\def\\testoptions{$$2}\\def\\testset{$$3}\\def\\testexpect{$$4}\\def\\testsetstretch{$$5}\\def\\testexpectstretch{$$6}\\input{$<}" \
	    >/dev/null; \
	  grep 'didactic biburl test:' test-biburl.log || exit 1; \
	  ! grep -q 'didactic biburl test:.*FAIL' test-biburl.log || exit 1; \
	done

# where URLs break, read from the PDF: see test-biburl-breaks.py.  By default
# and with biburlpenalty=9000 (on), and with it under pdflatex with OT1 and
# \urlstyle{same} (same) and under lualatex (lua); then test-biburl-memoir,
# a memoir document under pdflatex.
.PHONY: test-biburl-breaks
test-biburl-breaks: test-biburl-breaks.tex test-biburl-memoir.tex \
		test-biburl-breaks.py didactic.sty
	rc=0; for m in default on same lua; do \
	  case $$m in same) e=pdflatex;; lua) e=lualatex;; *) e="${PDFLATEX}";; esac; \
	  ${RM} test-biburl-breaks.aux test-biburl-breaks.bbl; \
	  for p in 1 2; do \
	    $$e ${LATEXFLAGS} -interaction=nonstopmode \
	      "\\def\\testmode{$$m}\\input{$<}" >/dev/null; \
	    test $$p = 2 || biber test-biburl-breaks >/dev/null || exit 1; \
	  done; \
	  python3 test-biburl-breaks.py $$m || rc=1; \
	done; \
	${RM} test-biburl-memoir.aux test-biburl-memoir.bbl; \
	for p in 1 2 3; do \
	  pdflatex ${LATEXFLAGS} -interaction=nonstopmode test-biburl-memoir \
	    >/dev/null; \
	  test $$p != 1 || biber test-biburl-memoir >/dev/null || exit 1; \
	done; \
	python3 test-biburl-breaks.py memoir || rc=1; \
	exit $$rc

# what biburlpenalty is for: a bibliography whose URL and DOI have 90 letters
# and digits without punctuation is set without an Overfull \hbox; both
# entries must be there, with their URL and DOI.
test-biburl-overfull.pdf: test-biburl-overfull.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	biber $(basename $@)
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	! grep -A3 'Overfull .hbox' $(basename $@).log
	test "$$(grep -c 'entry{' $(basename $@).bbl)" -eq 2
	pdftotext $@ - | grep -q 'DOI:'
	pdftotext $@ - | grep -q 'URL:'

VERSION=$(shell sed -En "s/^.*v([0-9]+(\.[0-9]+)+) didactic.*$$/\1/p" didactic.dtx)
.PHONY: release
release: didactic.tar.gz didactic.pdf didactic.sty
	git push
	gh release create v$(VERSION) -t "v$(VERSION)" $^

.PHONY: clean
clean:
	${RM} didactic.sty didactic.pdf
	${RM} didactic.log
	${RM} didactic.aux didactic.glo didactic.idx didactic.log
	${RM} didactic.gls didactic.glg
	${RM} didactic.out didactic.pdf
	${RM} didactic.pytxcode didactic.pytxmcr didactic.pytxpyg
	${RM} didactic.tar.gz didactic.toc didactic.unq
	${RM} didactic.hd didactic.bbl didactic.bcf didactic.blg didactic.run.xml
	${RM} pythontex_data.pkl
	${RM} -R _minted-didactic _minted-test pythontex_data.pkl
	${RM} $(wildcard py_default_default_*.stdout)
	${RM} -R pythontex-files-didactic
	${RM} test.pdf
	${RM} test.aux test.log test.unq
	${RM} didactic_output_*
	${RM} didactic_code_*
	${RM} -R didactic-files
	${RM} test-run.pdf test-run.aux test-run.log test-run.unq
	${RM} test-run.pytxcode test-run.pytxmcr test-run.pytxpyg
	${RM} -R pythontex-files-test-run _minted-test-run
	${RM} test-note-heading.pdf test-note-heading.aux test-note-heading.log
	${RM} test-note-heading.unq
	${RM} test-sidecap.pdf test-sidecap.aux test-sidecap.log test-sidecap.unq
	${RM} test-sidecap-off.pdf test-sidecap-off.aux test-sidecap-off.log
	${RM} test-sidecap-off.unq
	${RM} test-pair.pdf test-pair.aux test-pair.log test-pair.unq
	${RM} test-pair.pytxcode test-pair.pytxmcr test-pair.pytxpyg
	${RM} test-pair-slides.pdf test-pair-slides.aux test-pair-slides.log
	${RM} test-pair-slides.nav test-pair-slides.snm test-pair-slides.toc
	${RM} test-pair-slides.pytxcode test-pair-slides.pytxmcr
	${RM} test-pair-slides.pytxpyg test-pair-slides.out test-pair-slides.unq
	${RM} -R pythontex-files-test-pair pythontex-files-test-pair-slides
	${RM} test-footcite-memoir.pdf test-footcite-memoir.unq
	${RM} test-marginfloat.pdf test-marginfloat.aux test-marginfloat.log
	${RM} test-marginfloat.out test-marginfloat.unq
	${RM} test-marginfloat-slides.pdf test-marginfloat-slides.aux
	${RM} test-marginfloat-slides.log test-marginfloat-slides.nav
	${RM} test-marginfloat-slides.snm test-marginfloat-slides.toc
	${RM} test-marginfloat-slides.out test-marginfloat-slides.unq
	${RM} test-frametitle.pdf test-frametitle.aux test-frametitle.log
	${RM} test-frametitle.unq
	${RM} test-frametitle-slides.pdf test-frametitle-slides.aux
	${RM} test-frametitle-slides.log test-frametitle-slides.nav
	${RM} test-frametitle-slides.snm test-frametitle-slides.toc
	${RM} test-frametitle-slides.out test-frametitle-slides.unq
	${RM} test-keep.pdf test-keep.aux test-keep.log test-keep.unq
	${RM} test-keep-?.txt test-keep.pytxcode test-keep.pytxmcr test-keep.pytxpyg
	${RM} -R pythontex-files-test-keep
	${RM} test-keep-tall.pdf test-keep-tall.aux test-keep-tall.log
	${RM} test-keep-tall.unq test-keep-tall.pytxcode test-keep-tall-?.txt
	${RM} test-keep-tall100.pdf test-keep-tall100.aux test-keep-tall100.log
	${RM} test-keep-tall100.unq test-keep-tall100.pytxcode
	${RM} test-keep-tall100-?.txt
	${RM} test-keep-chain.pdf test-keep-chain.aux test-keep-chain.log
	${RM} test-keep-chain.unq test-keep-chain.pytxcode test-keep-chain-?.txt
	${RM} ${SWEEP_ALL:%=test-keep-sweep-%.tex}
	for f in test-keep-heading test-keep-heading3 test-keep-nogap test-keep-nogap3 \
			${SWEEP_ALL:%=test-keep-sweep-%} ${TEST_KEEP_NOWEB} \
			${TEST_KEEP_SMALL} \
			test-keep-flush test-keep-stale \
			test-block-nested ${TEST_KEEP_CHAPTER} ${TEST_NOTEOVERFLOW}; do \
		${RM} $$f.pdf $$f.aux $$f.log $$f.unq $$f.pytxcode $$f.out $$f.toc; \
	done
	${RM} test-keep-heading-?.txt test-keep-heading3-?.txt test-keep-stale-room.tex test-keep-stale-opt.tex
	${RM} ${TEST_KEEPCHECK:=.pdf} ${TEST_KEEPCHECK:=.aux} ${TEST_KEEPCHECK:=.log}
	${RM} ${TEST_KEEPCHECK:=.unq} ${TEST_KEEPCHECK:=.out}
	${RM} ${TEST_KEEPCHECK:=.pytxcode} ${TEST_KEEPCHECK:=-?.txt}
	${RM} test-keep-leadin-*.txt test-keep-leadin-off-*.txt
	${RM} test-keep-once-m.txt test-keep-once-g.stdout
	${RM} test-keep-include-all.pdf test-keep-include-all.aux test-keep-include-all.log
	${RM} test-keep-include.pdf test-keep-include.aux test-keep-include.log
	${RM} test-keep-include-a.aux test-keep-include-b.aux
	${RM} test-keep-include-all.unq test-keep-include.unq test-keep-include-all.pytxcode
	${RM} test-keep-include.pytxcode
	${RM} test-keep-multicol-*.txt test-keep-overfull-*.txt
	${RM} test-keep-huge.pdf test-keep-huge.aux test-keep-huge.log
	${RM} test-keep-huge.unq test-keep-huge.pytxcode test-keep-huge-h.txt
	${RM} test-keep-blank.pdf test-keep-blank.aux test-keep-blank.log
	${RM} test-keep-blank.unq test-keep-blank.pytxcode
	${RM} test-oldkernel.pdf test-oldkernel.aux test-oldkernel.log
	${RM} test-oldkernel.unq test-oldkernel.pytxcode
	${RM} test-margin-log.pdf test-margin-log.aux test-margin-log.log
	${RM} test-margin-log.unq test-margin-log.pytxcode
	${RM} test-margin-log-article.pdf test-margin-log-article.aux
	${RM} test-margin-log-article.log test-margin-log-article.unq
	${RM} test-margin-log-article.pytxcode
	${RM} -R _minted-test-keep
	${RM} _minted/*.minted
	${RM} ${TEST_FRAMETITLE_CASES:=.pdf} ${TEST_FRAMETITLE_CASES:=.aux}
	${RM} ${TEST_FRAMETITLE_CASES:=.log} ${TEST_FRAMETITLE_CASES:=.toc}
	${RM} ${TEST_FRAMETITLE_CASES:=.lof} ${TEST_FRAMETITLE_CASES:=.lot}
	${RM} ${TEST_FRAMETITLE_CASES:=.unq} ${TEST_FRAMETITLE_CASES:=.out}
	${RM} ${TEST_FRAMETITLE_CASES:=.pytxcode} test-frametitle.pytxcode
	${RM} test-frametitle-slides.pytxcode
	${RM} test-marginfloat-cases.pdf test-marginfloat-cases.aux
	${RM} test-marginfloat-cases.log test-marginfloat-cases.out
	${RM} test-marginfloat-cases.unq
	${RM} test-marginfloat-order.pdf test-marginfloat-order.aux
	${RM} test-marginfloat-order.log test-marginfloat-order.out
	${RM} test-marginfloat-order.unq
	${RM} test-marginfloat-inorder.pdf test-marginfloat-inorder.aux
	${RM} test-marginfloat-inorder.log test-marginfloat-inorder.out
	${RM} test-marginfloat-inorder.unq
	${RM} test-marginfloat-hidden.pdf test-marginfloat-hidden.aux
	${RM} test-marginfloat-hidden.log test-marginfloat-hidden.out
	${RM} test-marginfloat-hidden.unq
	${RM} test-marginfloat.pytxcode test-marginfloat-slides.pytxcode
	${RM} test-marginfloat-cases.pytxcode test-marginfloat-order.pytxcode
	${RM} test-marginfloat-inorder.pytxcode test-marginfloat-hidden.pytxcode
	${RM} ${TEST_FLOATORDER:=.pdf} ${TEST_FLOATORDER:=.aux}
	${RM} ${TEST_FLOATORDER:=.log} ${TEST_FLOATORDER:=.out}
	${RM} ${TEST_FLOATORDER:=.lof} ${TEST_FLOATORDER:=.lot}
	${RM} ${TEST_FLOATORDER:=.toc} ${TEST_FLOATORDER:=.unq}
	${RM} ${TEST_FLOATORDER:=.pytxcode}
	${RM} _minted/*.minted
	${RM} ${TEST_INCLUDE:=.pdf} ${TEST_INCLUDE:=.aux} ${TEST_INCLUDE:=.log}
	${RM} ${TEST_INCLUDE:=.out} ${TEST_INCLUDE:=.unq} ${TEST_INCLUDE:=.pytxcode}
	${RM} test-marginfloat-include-a.aux test-marginfloat-include-b.aux
	${RM} test-format.pdf test-format.aux test-format.log test-format.unq
	${RM} test-format.pytxcode
	${RM} test-oldkernel-title.pdf test-oldkernel-title.aux test-oldkernel-title.log
	${RM} test-oldkernel-title.unq test-oldkernel-title.pytxcode test-oldkernel-title.toc
	latexmk -C test.tex
