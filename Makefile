.PHONY: test compile

export LIBPYTHON_LOC=$(shell cocotb-config --libpython)
export PYGPI_PYTHON_BIN=$(shell cocotb-config --python-bin)
export GPI_USERS=$(LIBPYTHON_LOC);$(shell $(PYGPI_PYTHON_BIN) -m cocotb_tools.config --pygpi-entry-point)

test_%:
	make compile
	iverilog -o build/sim.vvp -s gpu -g2012 build/gpu.v
	COCOTB_TEST_MODULES=test.test_$* vvp -m $$( $${PYGPI_PYTHON_BIN} -m cocotb_tools.config --lib-name-path vpi icarus ) build/sim.vvp

# Plain Verilog testbench (no cocotb): make tb_matmul / tb_matadd, writes build/gpu.vcd
CLK_PERIOD ?= 10

tb_%:
	make compile
	iverilog -g2012 -o build/tb.vvp -s tb_gpu -DCLK_PERIOD=$(CLK_PERIOD) $(if $(filter matadd,$*),-DMATADD) build/gpu.v test/tb_gpu.v
	vvp build/tb.vvp +vcd

compile:
	make compile_alu
	sv2v -I src/* -w build/gpu.v
	echo "" >> build/gpu.v
	cat build/alu.v >> build/gpu.v
	echo '`timescale 1ns/1ns' > build/temp.v
	cat build/gpu.v >> build/temp.v
	mv build/temp.v build/gpu.v

compile_%:
	sv2v -w build/$*.v src/$*.sv

# TODO: Get gtkwave visualizaiton

show_%: %.vcd %.gtkw
	gtkwave $^
