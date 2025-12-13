from vunit import VUnit
import inspect

# Create VUnit instance
if "compile_builtins" in inspect.signature(VUnit.from_argv).parameters:
    vu = VUnit.from_argv(compile_builtins=False)
else:
    vu = VUnit.from_argv()

vu.add_vhdl_builtins()  # Add the VHDL builtins explicitly!

# Add open-logic libraries
olo_lib = vu.add_library("olo")
olo_lib.add_source_files("../../lib/open-logic/src/base/vhdl/*.vhd")
olo_lib.add_source_files("../../lib/open-logic/3rdParty/en_cl_fix/hdl/*.vhd")
olo_lib.add_source_files("../../lib/open-logic/src/fix/vhdl/*.vhd")

# Add libraries
lib = vu.add_library("project")
lib.add_source_files("../project_pkg.vhd")
lib.add_source_files("../svpwm/src/svpwm.vhd")
lib.add_source_files("../svpwm/test/svpwm_tb.vhd")
lib.add_source_files("../modulator/src/modulator.vhd")
lib.add_source_files("../modulator/test/modulator_tb.vhd")
lib.add_source_files("../dqtransform/src/dqtransform.vhd")
lib.add_source_files("../dqtransform/test/dqtransform_tb.vhd")

# Obviously flags must be set after files are imported
vu.add_compile_option('ghdl.a_flags', ['-frelaxed-rules', '-Wno-hide', '-Wno-shared'])
vu.add_compile_option('nvc.a_flags', ['--relaxed'])

# Run VUnit
vu.main()