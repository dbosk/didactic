LATEX?=latex
PDFLATEX?=xelatex -pdf
LATEXFLAGS=-shell-escape
PYTHONTEX=python3 $(shell which pythontex) --interpreter python:python3

.PHONY: all
all: didactic.sty didactic.pdf didactic.tar.gz test.pdf test-footcite.pdf \
	test-footcite-twoside.pdf test-footcite-memoir.pdf test-run.pdf \
	test-note-heading.pdf test-pair.pdf test-pair-slides.pdf \
	test-sidecap.pdf test-sidecap-off.pdf didactic-sync.py

SRC+=	didactic.dtx idea.tex lightblock.tex ProvideSemanticEnv.tex pairruns.tex
SRC+=	hello.py ask.py askmany.py greet.py filter.py pairgreet1.py pairgreet2.py
SRC+=	pairwrite.py pairread.py
SRC+=	didactic-sync.nw didactic-sync.tex didactic-sync.py

# The change history (\PrintChanges) needs makeindex on the .glo file; that
# also checks that every \changes entry can be written and typeset.  minted
# takes a _minted found elsewhere on the search path, such as in an installed
# copy of this package, for its own unless there is one here.
didactic.pdf: ${SRC} didactic.sty
	@mkdir -p _minted
	-${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PYTHONTEX} didactic
	${PDFLATEX} ${LATEXFLAGS} $<
	makeindex -s gglo.ist -o didactic.gls didactic.glo
	${PDFLATEX} ${LATEXFLAGS} $<

# docstrip asks before overwriting, so remove the old file first.
didactic.sty: didactic.ins didactic.dtx
	${RM} $@
	${LATEX} ${LATEXFLAGS} $<

# The sync script is a literate program.  It's tangled next to didactic.sty, so
# that builds find it with kpsewhich, and its explanation is woven into
# didactic.pdf.  black only tidies the spacing between chunks, so it's optional.
BLACK?=	$(if $(shell command -v black),black -q -,cat)
didactic-sync.py: didactic-sync.nw
	notangle -R"[[$@]]" $< | ${BLACK} > $@
	chmod +x $@

test_didactic_sync.py: didactic-sync.nw
	notangle -R"[[$@]]" $< > $@

didactic-sync.tex: didactic-sync.nw
	noweave -n -delay -t2 -autolang -index -filter tominted $< > $@

.PHONY: test-sync
test-sync: didactic-sync.py test_didactic_sync.py
	python3 -m pytest -q test_didactic_sync.py

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

# code side by side, in the notes and on the slides; minted needs
# -shell-escape and a run after pythontex to insert the highlighted code.
TEST_PAIR_EXAMPLES=	pairgreet1.py pairgreet2.py hello.py pairtabs.py \
			pairwrite.py pairread.py pairruns.tex
test-pair.pdf test-pair-slides.pdf: %.pdf: %.tex didactic.sty ${TEST_PAIR_EXAMPLES}
	-${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PYTHONTEX} $*
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<

# bilingual documents: one contents file, both editions, as notes and slides.
# The first pass fails on the missing pythontex output; check-bilingual reads
# the PDFs for what should and shouldn't be there.
TEST_BILINGUAL=	test-bilingual test-bilingual-sv \
		test-bilingual-slides test-bilingual-slides-sv
$(addsuffix .pdf,${TEST_BILINGUAL}): %.pdf: %.tex test-bilingual-contents.tex \
		didactic.sty hello.py
	@mkdir -p _minted
	-${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PYTHONTEX} $*
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<

# nobilingual leaves the names alone, for a document with its own \tr
test-bilingual-off.pdf: test-bilingual-off.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} $<

# a block that inputs a file holding a block
test-bilingual-nested.pdf: test-bilingual-nested.tex \
		test-bilingual-nested-inner.tex test-bilingual-nested-innermost.tex \
		didactic.sty
	${PDFLATEX} ${LATEXFLAGS} $<

.PHONY: check-bilingual
check-bilingual: $(addsuffix .pdf,${TEST_BILINGUAL}) test-bilingual-off.pdf \
		test-bilingual-nested.pdf
	./test-bilingual.sh

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
	${RM} didactic-sync.py didactic-sync.tex test_didactic_sync.py
	${RM} *.cut
	${RM} $(addsuffix .pdf,${TEST_BILINGUAL}) test-bilingual-off.pdf
	${RM} test-bilingual-nested.pdf test-bilingual-nested.unq
	${RM} test-bilingual-taken.pdf test-bilingual-taken.unq
	${RM} -R test-bilingual-import.d
	${RM} test-bilingual-import.pdf test-bilingual-import.unq
	${RM} $(addsuffix .unq,${TEST_BILINGUAL}) test-bilingual-off.unq
	${RM} $(addsuffix .pytxcode,${TEST_BILINGUAL})
	${RM} $(addsuffix .pytxmcr,${TEST_BILINGUAL})
	${RM} $(addsuffix .pytxpyg,${TEST_BILINGUAL})
	${RM} -R $(addprefix pythontex-files-,${TEST_BILINGUAL})
	latexmk -C test.tex
