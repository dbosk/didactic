beamer-didactic.sty: ${INCLUDE_BEAMERDIDACTIC}/beamer-didactic.sty
	${LN} $^ $@


.PHONY: ${INCLUDE_BEAMERDIDACTIC}/beamer-didactic.sty

${INCLUDE_BEAMERDIDACTIC}/beamer-didactic.sty:
	${MAKE} -C $(dir $@) $(notdir $@)


.PHONY: clean clean-beamer-didactic
clean: clean-beamer-didactic
clean-beamer-didactic:
	${RM} beamer-didactic.sty

.PHONY: distclean distclean-beamer-didactic
distclean: distclean-beamer-didactic
distclean-beamer-didactic:
	${MAKE} -C ${INCLUDE_BEAMERDIDACTIC} clean distclean
