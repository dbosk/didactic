LATEX?=latex
PDFLATEX?=xelatex -pdf
LATEXFLAGS=-shell-escape
PYTHONTEX=python3 $(shell which pythontex) --interpreter python:python3

.DELETE_ON_ERROR:

.PHONY: all
all: didactic.sty didactic.pdf didactic.tar.gz test.pdf test-footcite.pdf \
	test-footcite-twoside.pdf test-footcite-memoir.pdf test-run.pdf \
	test-note-heading.pdf test-pair.pdf test-pair-slides.pdf \
	test-sidecap.pdf test-sidecap-off.pdf \
	test-marginfloat.pdf test-marginfloat-slides.pdf \
	test-frametitle.pdf test-frametitle-slides.pdf \
	test-keep.pdf test-keep-tall.pdf test-keep-tall100.pdf \
	test-keep-chain.pdf

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

# frame titles, in the notes and on the slides, from one source.
test-frametitle.pdf test-frametitle-slides.pdf: %.pdf: %.tex didactic.sty \
		test-frametitle-contents.tex
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

# Run LaTeX on $< until the references settle.  The labels inside a listing of
# minted come only once minted has its cache, so on a fresh checkout the page
# references take three passes, later builds two.  Fail if they never settle.
define latex_until_settled
for i in 1 2 3 4 5; do \
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $< || exit 1; \
	grep -q 'Rerun to get' $(basename $<).log || exit 0; \
done; echo "$<: references did not settle"; exit 1
endef

# listings kept together across pages.  The document checks its pages itself
# and logs PASS or FAIL for each check, and a last line if it got there.  A
# failed test leaves no PDF, only the log (.DELETE_ON_ERROR), so that the next
# make doesn't call it up to date.
test-keep.pdf: test-keep.tex didactic.sty
	-${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PYTHONTEX} test-keep
	@${latex_until_settled}
	! grep -E 'didactic keep test:.*(FAIL|SKIP)' test-keep.log
	grep -q 'didactic keep test: all checks ran' test-keep.log

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
	${RM} _minted/*.minted
	latexmk -C test.tex
