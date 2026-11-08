.PHONY: test compile gls

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

# Gate-level sim of a DC netlist for PrimeTime power: make gls RUN=runs/best_hvt CLK_PERIOD=<that period>
# Writes build/gpu_gls.vcd. Zero-delay (no SDF), so PT sees functional toggles only.
SAED ?= /usr/local/synopsys/pdk/SAED32_EDK/lib
SAED_VLIB = $(SAED)/stdcell_rvt/verilog/saed32nm.v $(SAED)/stdcell_hvt/verilog/saed32nm_hvt.v $(SAED)/stdcell_lvt/verilog/saed32nm_lvt.v
RUN ?= runs/best_hvt

gls:
	mkdir -p build
	iverilog -g2012 -o build/gls.vvp -s tb_gpu -DCLK_PERIOD=$(CLK_PERIOD) $(if $(MATADD),-DMATADD) \
		syn/$(RUN)/out/gpu_netlist.v $(SAED_VLIB) test/tb_gpu.v
	vvp build/gls.vvp +vcd +vcdfile=build/gpu_gls.vcd

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
