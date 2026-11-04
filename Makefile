LATEX?=latex
PDFLATEX?=xelatex -pdf
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
# The order of float numbers, from the pages the floats end up on.
TEST_FLOATORDER=	test-marginfloat-samepar test-marginfloat-moved \
			test-marginfloat-chapters test-marginfloat-kinds \
			test-marginfloat-article
# The same with \includeonly, from the .aux files of the whole document.
TEST_INCLUDE=		test-marginfloat-include-all test-marginfloat-include

.PHONY: all
all: didactic.sty didactic.pdf didactic.tar.gz test.pdf test-footcite.pdf \
	test-footcite-twoside.pdf test-footcite-memoir.pdf test-run.pdf \
	test-note-heading.pdf test-pair.pdf test-pair-slides.pdf \
	test-sidecap.pdf test-sidecap-off.pdf \
	test-marginfloat.pdf test-marginfloat-slides.pdf \
	test-frametitle.pdf test-frametitle-slides.pdf \
	${TEST_FRAMETITLE_CASES:=.pdf} \
	test-marginfloat-cases.pdf test-marginfloat-order.pdf \
	test-marginfloat-inorder.pdf test-marginfloat-hidden.pdf \
	${TEST_FLOATORDER:=.pdf} test-marginfloat-include.pdf \
	test-format.pdf check

SRC+=	didactic.dtx idea.tex lightblock.tex ProvideSemanticEnv.tex pairruns.tex
SRC+=	marginfloats.tex
SRC+=	hello.py ask.py askmany.py greet.py filter.py pairgreet1.py pairgreet2.py
SRC+=	pairwrite.py pairread.py

# The change history (\PrintChanges) needs makeindex on the .glo file; that
# also checks that every \changes entry can be written and typeset.
didactic.pdf: ${SRC} didactic.sty
	-${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PYTHONTEX} didactic
	${PDFLATEX} ${LATEXFLAGS} $<
	makeindex -s gglo.ist -o didactic.gls didactic.glo
	grep -q 'work in a source shared' didactic.gls
	${PDFLATEX} ${LATEXFLAGS} $<

# docstrip asks before overwriting, so remove the old file first.
didactic.sty: didactic.ins didactic.dtx
	${RM} $@
	${LATEX} ${LATEXFLAGS} $<

didactic.tar.gz: ${SRC} didactic.ins LICENSE Makefile README.md didactic.pdf
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
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<
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
		${TEST_FRAMETITLE_CASES} ${TEST_FLOATORDER} ${TEST_INCLUDE}
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
${TEST_FRAMETITLE_CASES:=.pdf}: %.pdf: %.tex didactic.sty
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
	${RM} didactic.hd
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
	${RM} ${TEST_INCLUDE:=.pdf} ${TEST_INCLUDE:=.aux} ${TEST_INCLUDE:=.log}
	${RM} ${TEST_INCLUDE:=.out} ${TEST_INCLUDE:=.unq} ${TEST_INCLUDE:=.pytxcode}
	${RM} test-marginfloat-include-a.aux test-marginfloat-include-b.aux
	${RM} test-format.pdf test-format.aux test-format.log test-format.unq
	${RM} test-format.pytxcode
	latexmk -C test.tex
