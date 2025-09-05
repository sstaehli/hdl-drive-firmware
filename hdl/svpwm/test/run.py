from vunit import VUnit

# Create VUnit instance
vu = VUnit.from_argv(compile_builtins=False)  # Do not use compile_builtins.
vu.add_vhdl_builtins()  # Add the VHDL builtins explicitly!

# Add open-logic libraries
olo_lib = vu.add_library("olo")
olo_lib.add_source_files("../../../lib/open-logic/src/base/vhdl/*.vhd")
olo_lib.add_source_files("../../../lib/open-logic/3rdParty/en_cl_fix/hdl/*.vhd")
olo_lib.add_source_files("../../../lib/open-logic/src/fix/vhdl/*.vhd")

# Add libraries
lib = vu.add_library("project")
lib.add_source_files("../../project_pkg.vhd")
lib.add_source_files("../src/svpwm.vhd")
lib.add_source_files("./svpwm_tb.vhd")

# Obviously flags must be set after files are imported
vu.add_compile_option('ghdl.a_flags', ['-frelaxed-rules', '-Wno-hide', '-Wno-shared'])
vu.add_compile_option('nvc.a_flags', ['--relaxed'])

# Run VUnit
vu.main()