LATEX?=latex
PDFLATEX?=pdflatex
LATEXFLAGS=-shell-escape -halt-on-error
PYTHONTEX=python3 $(shell which pythontex) --interpreter python:python3

.PHONY: all
all: didactic.sty didactic.pdf didactic.tar.gz

SRC+=	didactic.dtx hello.py idea.tex lightblock.tex ProvideSemanticEnv.tex

didactic.pdf: ${SRC} didactic.sty
	${PDFLATEX} ${LATEXFLAGS} $<
	${PYTHONTEX} didactic
	${PDFLATEX} ${LATEXFLAGS} $<
	${PDFLATEX} ${LATEXFLAGS} $<

didactic.sty: didactic.ins
	${LATEX} ${LATEXFLAGS} $<

didactic.tar.gz: ${SRC} didactic.ins LICENSE Makefile README.md didactic.pdf
	tar -czf $@ --transform "s|^|didactic/|" $^

VERSION=$(shell sed -En "s/^.*v([0-9]+\.[0-9]+) didactic.*$$/\1/p" didactic.dtx)
.PHONY: release
release: didactic.tar.gz didactic.pdf didactic.sty
	git push
	gh release create v$(VERSION) -t "v$(VERSION)" $^

.PHONY: clean
clean:
	${RM} didactic.sty didactic.pdf
	${RM} didactic.log
	${RM} didactic.aux didactic.glo didactic.idx didactic.log
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
	${RM} tmp_didactic_minted_output.txt
