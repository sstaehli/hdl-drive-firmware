UNITS?="*"
GHDL?=ghdl
NVC?=nvc
MODELSIM?=/tools/altera/25.1std/questa_fse/bin/vsim

.PHONY: venv
venv:
	python -m venv .venv
	. .venv/bin/activate
	pip install vunit_hdl

.PHONY: test
test:
	cd test && \
	./nvc-vunit-docker ./run.py

.PHONY: debug
debug:
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