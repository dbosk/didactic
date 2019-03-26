LATEX?=latex

.PHONY: all
all: beamer-didactic.sty beamer-didactic.pdf

beamer-didactic.pdf: beamer-didactic.dtx
beamer-didactic.sty: beamer-didactic.ins

.PHONY: clean
clean:
	${RM} beamer-didactic.sty beamer-didactic.pdf
	${RM} beamer-didactic.log


INCLUDE_MAKEFILES=makefiles
include ${INCLUDE_MAKEFILES}/tex.mk
