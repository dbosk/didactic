LATEX?=latex

.PHONY: all
all: beamer-didactic.sty beamer-didactic.pdf

.PHONY: clean
clean:
	${RM} beamer-didactic.sty beamer-didactic.pdf
	${RM} beamer-didactic.log


INCLUDE_MAKEFILES=makefiles
include ${INCLUDE_MAKEFILES}/tex.mk
