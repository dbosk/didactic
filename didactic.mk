didactic.sty: ${INCLUDE_DIDACTIC}/didactic.sty
	${LN} $< $@

${INCLUDE_DIDACTIC}/didactic.sty::
	${MAKE} -C $(dir $@) $(notdir $@)


.PHONY: clean clean-didactic
clean: clean-didactic
clean-didactic:
	${RM} didactic.sty

.PHONY: distclean distclean-didactic
distclean: distclean-didactic
distclean-didactic:
	${MAKE} -C ${INCLUDE_DIDACTIC} clean distclean
