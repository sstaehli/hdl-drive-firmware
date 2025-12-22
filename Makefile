UNITS?="*"
export VUNIT_SIMULATOR?=ghdl

.PHONY: test
test:
	cd test && \
	VUNIT_SIMULATOR=nvc python3 ./run.py ${UNITS}

.PHONY: sim
sim:
	cd test && \
	VUNIT_SIMULATOR=modelsim python3 ./run.py -g ${UNITS}

.PHONY: psi_to_olo
psi_to_olo:
	git ls-files -z '*.vhd' | xargs -0 perl -pi -e \
	's/psi_lib/olo/g; \
	s/psi_fix_pkg/olo_fix_pkg/g; \
	s/PsiFixFmt_t/FixFormat_t/g; \
	s/PsiFixToReal/cl_fix_to_real/g; \
	s/PsiFixFromReal/cl_fix_from_real/g'