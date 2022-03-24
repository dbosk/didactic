LATEX?=latex

.PHONY: all
all: didactic.sty didactic.pdf

didactic.pdf: didactic.dtx
didactic.sty: didactic.ins

.PHONY: clean
clean:
	${RM} didactic.sty didactic.pdf
	${RM} didactic.log


INCLUDE_MAKEFILES=makefiles
include ${INCLUDE_MAKEFILES}/tex.mk
