LATEX?=latex
PDFLATEX?=xelatex -pdf
LATEXFLAGS=-shell-escape
PYTHONTEX=python3 $(shell which pythontex) --interpreter python:python3

.PHONY: all
all: didactic.sty didactic.pdf didactic.tar.gz test.pdf test-footcite.pdf \
	test-footcite-twoside.pdf test-footcite-memoir.pdf test-run.pdf \
	test-note-heading.pdf test-pair.pdf test-pair-slides.pdf \
	test-sidecap.pdf test-sidecap-off.pdf \
	test-marginfloat.pdf test-marginfloat-slides.pdf \
	test-frametitle.pdf test-frametitle-slides.pdf \
	test-keep.pdf test-noteyield test-biburl

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

# listings kept together across pages; three times, for the page references
# and the heading before a long table, which moves in the run after.  The
# document checks its pages itself and logs PASS or FAIL for each check.
test-keep.pdf: test-keep.tex didactic.sty
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode $<
	! grep 'didactic keep test:.*FAIL' test-keep.log

# noteyieldmaxgap: marginfix's \marginnoteyieldlimit in lines, by default
# keepmaxgap's; one run per case, options:lines (0 for no limit).  Needs
# a marginfix with \marginnoteyieldlimit (else SKIP, which fails).
NOTEYIELD_CASES=:5 keepmaxgap=8:8 noteyieldmaxgap=3:3 \
	keepmaxgap=8,noteyieldmaxgap=2:2 noteyieldmaxgap=0:0
.PHONY: test-noteyield
test-noteyield: test-noteyield.tex didactic.sty
	for c in ${NOTEYIELD_CASES}; do \
	  ${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode \
	    "\\def\\testoptions{$${c%:*}}\\def\\testlines{$${c#*:}}\\input{$<}" \
	    >/dev/null; \
	  grep 'didactic noteyield test:' test-noteyield.log; \
	  ! grep -q 'didactic noteyield test:.*\(FAIL\|SKIP\)' \
	    test-noteyield.log || exit 1; \
	done

# biburlpenalty and bibemergencystretch: biblatex's URL break penalties and
# the bibliography's \emergencystretch, with biblatex loaded before didactic,
# after it or not at all; one run per case, order:options:penalty set in
# the preamble:expected penalty:stretch set in the preamble:expected stretch.
BIBURL_CASES=before:::9000::3em after:::9000::3em \
	before:biburlpenalty=500::500::3em after:biburlpenalty=0::0::3em \
	before::100:100::3em after::100:100::3em \
	before:bibemergencystretch=1em::9000::1em \
	after:bibemergencystretch=0pt::9000::0pt \
	before:::9000:2em:2em after:::9000:2em:2em none:::0::
.PHONY: test-biburl
test-biburl: test-biburl.tex didactic.sty
	for c in ${BIBURL_CASES}; do \
	  IFS=:; set -- $$c; unset IFS; ${RM} test-biburl.aux; \
	  ${PDFLATEX} ${LATEXFLAGS} -interaction=nonstopmode \
	    "\\def\\testorder{$$1}\\def\\testoptions{$$2}\\def\\testset{$$3}\\def\\testexpect{$$4}\\def\\testsetstretch{$$5}\\def\\testexpectstretch{$$6}\\input{$<}" \
	    >/dev/null; \
	  grep 'didactic biburl test:' test-biburl.log || exit 1; \
	  ! grep -q 'didactic biburl test:.*FAIL' test-biburl.log || exit 1; \
	done

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
	${RM} test-keep-?.txt test-keep.pytxcode
	${RM} -R _minted-test-keep
	latexmk -C test.tex
