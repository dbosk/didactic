LATEX?=latex
PDFLATEX?=pdflatex
LATEXFLAGS=-shell-escape
PYTHONTEX=python3 $(shell which pythontex) --interpreter python:python3

.PHONY: all
all: didactic.sty didactic.pdf didactic.tar.gz

didactic.pdf: didactic.dtx didactic.sty hello.py idea.tex lightblock.tex
	${PDFLATEX} ${LATEXFLAGS} $<
	${PYTHONTEX} didactic
	${PDFLATEX} ${LATEXFLAGS} $<

didactic.sty: didactic.ins
	${LATEX} ${LATEXFLAGS} $<

didactic.tar.gz: didactic.dtx didactic.ins hello.py idea.tex
didactic.tar.gz: LICENSE lightblock.tex Makefile README.md
	tar -czf $@ --transform "s|^|didactic/|" $^

.PHONY: clean
clean:
	${RM} didactic.sty didactic.pdf
	${RM} didactic.log
	${RM} didactic.aux didactic.glo didactic.idx didactic.log
	${RM} didactic.out didactic.pdf
	${RM} didactic.pytxcode didactic.pytxmcr didactic.pytxpyg
	${RM} didactic.tar.gz didactic.toc didactic.unq
	${RM} pythontex_data.pkl
	${RM} -R _minted-didactic
	${RM} $(wildcard py_default_default_*.stdout)
	${RM} -R pythontex-files-didactic
