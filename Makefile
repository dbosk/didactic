LATEX?=latex
PDFLATEX?=pdflatex
LATEXFLAGS=-shell-escape
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
	${RM} -R _minted-didactic
	${RM} $(wildcard py_default_default_*.stdout)
	${RM} -R pythontex-files-didactic
