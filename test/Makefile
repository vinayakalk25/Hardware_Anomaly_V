# Default simulator
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Target files to compile
VERILOG_SOURCES += $(PWD)/tb.v
VERILOG_SOURCES += $(PWD)/../src/tt_um_hardware_anomaly_detection.v

# TOPLEVEL is the name of the testbench module inside tb.v
TOPLEVEL = tb

# MODULE is the name of the Python test script (test.py)
MODULE = test

# Include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim