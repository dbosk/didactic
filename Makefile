LATEX?=latex
LATEXFLAGS=-shell-escape

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


INCLUDE_MAKEFILES=makefiles
include ${INCLUDE_MAKEFILES}/tex.mk
