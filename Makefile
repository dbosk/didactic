.PHONY: all
all:
	${MAKE} -C tex all
	${MAKE} -C python all

.PHONY: clean
clean:
	${MAKE} -C tex clean
	${MAKE} -C python clean

.PHONY: distclean
distclean:
	${MAKE} -C tex distclean
	${MAKE} -C python distclean
