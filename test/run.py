from vunit import VUnit
import inspect

from os.path import join, dirname, abspath

root = abspath(dirname(__file__))

# Create VUnit instance
if "compile_builtins" in inspect.signature(VUnit.from_argv).parameters:
    vu = VUnit.from_argv(compile_builtins=False)
else:
    vu = VUnit.from_argv()

vu.add_vhdl_builtins()  # Add the VHDL builtins explicitly!

# Add open-logic libraries
olo_lib = vu.add_library("olo")
olo_lib.add_source_files("../lib/open-logic/src/base/vhdl/*.vhd")
olo_lib.add_source_files("../lib/open-logic/3rdParty/en_cl_fix/hdl/*.vhd")
olo_lib.add_source_files("../lib/open-logic/src/fix/vhdl/*.vhd")

# Add libraries
lib = vu.add_library("project")
lib.add_source_files("../hdl/project_pkg.vhd")
lib.add_source_files("../hdl/modulator/src/modulator.vhd")
lib.add_source_files("../hdl/modulator/test/modulator_tb.vhd")
lib.add_source_files("../hdl/transforms/src/abc2dq.vhd")
lib.add_source_files("../hdl/transforms/test/abc2dq_tb.vhd")
lib.add_source_files("../hdl/transforms/src/dq2abc.vhd")
lib.add_source_files("../hdl/transforms/test/dq2abc_tb.vhd")
#lib.add_source_files("../hdl/svpwm/src/svpwm.vhd")
#lib.add_source_files("../hdl/svpwm/test/svpwm_tb.vhd")
lib.add_source_files("../hdl/modulator/src/modulator.vhd")
lib.add_source_files("../hdl/modulator/test/modulator_tb.vhd")

# Obviously flags must be set after files are imported
vu.add_compile_option('ghdl.a_flags', ['-frelaxed-rules', '-Wno-hide', '-Wno-shared'])
vu.add_compile_option('nvc.a_flags', ['--relaxed'])

# Configure modelsim
for tb in lib.get_test_benches():
    tb.set_sim_option("modelsim.init_file.gui", join(root, "..", "sim", "scripts", tb.name + "_wave.do"))

# Configure  testbenches
tb = lib.entity("modulator_tb")
tb.add_config(name = "default")
tb.add_config(name = "LUTMax", generics=dict(DataWidth_g="12", LutWidth_g="11", TestLimit_g="0.005"))
tb.add_config(name = "LUTMin", generics=dict(DataWidth_g="12", LutWidth_g="3", TestLimit_g="0.1"))

tb = lib.entity("abc2dq_tb")
tb.add_config(name = "default")
tb.add_config(name = "d", generics=dict(AC_D_g="1.0", AC_Q_g="0.0", DC_g="0.0"))
tb.add_config(name = "d_negative", generics=dict(AC_D_g="-1.0", AC_Q_g="0.0", DC_g="0.0"))
tb.add_config(name = "q", generics=dict(AC_D_g="0.0", AC_Q_g="1.0", DC_g="0.0"))
tb.add_config(name = "q_negative", generics=dict(AC_D_g="0.0", AC_Q_g="-1.0", DC_g="0.0"))
tb.add_config(name = "dc", generics=dict(AC_D_g="0.5", AC_Q_g="0.0", DC_g="0.5"))
tb.add_config(name = "dc_negative", generics=dict(AC_D_g="0.5", AC_Q_g="0.0", DC_g="-0.5"))
tb.add_config(name = "saturate", generics=dict(AC_D_g="1.0", AC_Q_g="1.0", DC_g="1.0", TestLimit_g="1.0"))

tb = lib.entity("dq2abc_tb")
tb.add_config(name = "default")
tb.add_config(name = "d", generics=dict(D_g="1.0", Q_g="0.0"))
tb.add_config(name = "d_negative", generics=dict(D_g="-1.0", Q_g="0.0"))
tb.add_config(name = "q", generics=dict(D_g="0.0", Q_g="1.0"))
tb.add_config(name = "q_negative", generics=dict(D_g="0.0", Q_g="-1.0"))
tb.add_config(name = "saturate", generics=dict(D_g="1.0", Q_g="1.0", TestLimit_g="1.0"))

# Run VUnit
vu.main()