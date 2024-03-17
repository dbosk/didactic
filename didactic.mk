didactic.sty: ${INCLUDE_DIDACTIC}/didactic.sty
	${LN} $^ $@

didactic.sty: didactic-Swedish.dict didactic-English.dict

didactic-Swedish.dict: ${INCLUDE_DIDACTIC}/didactic-Swedish.dict
	${LN} $^ $@
didactic-English.dict: ${INCLUDE_DIDACTIC}/didactic-English.dict
	${LN} $^ $@

.PHONY: ${INCLUDE_DIDACTIC}/didactic.sty

${INCLUDE_DIDACTIC}/didactic.sty:
	${MAKE} -C $(dir $@) $(notdir $@)


.PHONY: clean clean-didactic
clean: clean-didactic
clean-didactic:
	${RM} didactic.sty
	${RM} didactic-Swedish.dict didactic-English.dict

.PHONY: distclean distclean-didactic
distclean: distclean-didactic
distclean-didactic:
	${MAKE} -C ${INCLUDE_DIDACTIC} clean distclean
