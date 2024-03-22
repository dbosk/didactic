LATEX?=latex
LATEXFLAGS=-shell-escape
PYTHONTEX=python3 $(shell locate pythontex3.py | tail -n 1)

.PHONY: all
all: didactic.sty didactic.pdf test.pdf

didactic.pdf: didactic.dtx didactic.sty
didactic.sty: didactic.ins

test.pdf: test.tex didactic.sty

.PHONY: clean
clean:
	${RM} didactic.sty didactic.pdf
	${RM} didactic.log
	${RM} test.pdf
	${RM} didactic.aux didactic.glo didactic.idx didactic.out didactic.pytxmcr
	${RM} didactic.pytxpyg didactic.toc didactic.unq
	${RM} -R _minted-didactic _minted-test pythontex_data.pkl
	${RM} test.aux test.log test.unq


INCLUDE_MAKEFILES=makefiles
include ${INCLUDE_MAKEFILES}/tex.mk
