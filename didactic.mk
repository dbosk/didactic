DIDACTIC_STY=/tex/didactic.sty

didactic.sty: ${INCLUDE_DIDACTIC}/${DIDACTIC_STY}:
	${LN} $< $@

${INCLUDE_DIDACTIC}/${DIDACTIC_STY}:
	${MAKE} -C $(dir $@) $(notdir $@)


.PHONY: clean clean-didactic
clean: clean-didactic
clean-didactic:
	${MAKE} -C ${INCLUDE_DIDACTIC} clean

.PHONY: distclean distclean-didactic
distclean: distclean-didactic
distclean-didactic:
	${MAKE} -C ${INCLUDE_DIDACTIC} clean distclean
