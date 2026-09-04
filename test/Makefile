# cocotb harness for the Tiny Tapeout gl_test job.
#   make            RTL simulation
#   GATES=yes make  gate-level simulation against gate_level_netlist.v
# https://docs.cocotb.org/en/stable/quickstart.html

SIM ?= icarus
FST ?= -fst
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src

# Must match info.yaml source_files.
PROJECT_SOURCES = \
  tt_um_baked_weights.v chip_core.v wrom_macro_ovf.v sequencer.v tmac.v trit_dec5.v \
  rnd_shift.v mingru.v rmsnorm.v resid_add.v sqrelu.v sigmoid_lut.v rsqrt_lut.v \
  norm_const.v norm_sh.v site_const.v mat_const.v gate_const.v wrom_ovf.v

ifneq ($(GATES),yes)

SIM_BUILD = sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

SIM_BUILD = sim_build/gl
COMPILE_ARGS += -DGL_TEST
COMPILE_ARGS += -DFUNCTIONAL
COMPILE_ARGS += -DUSE_POWER_PINS
COMPILE_ARGS += -DSIM
COMPILE_ARGS += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
# Copied in by the gds workflow from the tt_submission artifact.  It instantiates the ROM
# macro as a black box, so the model below has to come in alongside.
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# The ROM is a finished block, not Verilog source.  BOTH modes compile its behavioural
# model, loaded with the same weight image the macro GDS carries.  Without the define the
# model falls back to "wrom_b0.hex" in test/, which does not exist.
COMPILE_ARGS += -DWROM_B0_VMEM_PATH=\"$(PWD)/../macro/wrom_b0.hex\"
VERILOG_SOURCES += $(PWD)/../macro/wrom_b0.v

COMPILE_ARGS += -I$(SRC_DIR)

VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

COCOTB_TEST_MODULES = test
MODULE = test

include $(shell cocotb-config --makefiles)/Makefile.sim
