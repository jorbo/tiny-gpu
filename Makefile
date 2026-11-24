.DEFAULT_GOAL := help
# One Makefile. Trim old GNU make's leading list whitespace without splitting
# interior path spaces (make's word functions would split the filename).
ROOT := $(shell file="$$(printf '%s' "$(MAKEFILE_LIST)" | sed 's/^[[:space:]]*//')"; cd -- "$$(dirname -- "$$file")" && pwd)
BUILD := $(ROOT)/build
.PHONY: help test compile gls check

help:
	@echo "Offline: make check | verification_vectors"
	@echo "Hardware (explicit opt-in): make compile | test_matadd | tb_matmul | gls"
	@echo "See README.md, sim/README.md, syn/README.md and ptpx/README.md."

# cocotb is only needed for test_%; scoping these keeps other targets working on hosts without it
test_%: export LIBPYTHON_LOC = $(shell cocotb-config --libpython)
test_%: export PYGPI_PYTHON_BIN = $(shell cocotb-config --python-bin)
test_%: export GPI_USERS = $(LIBPYTHON_LOC);$(shell $(PYGPI_PYTHON_BIN) -m cocotb_tools.config --pygpi-entry-point)

test_%:
	$(MAKE) -C "$(ROOT)" compile
	iverilog -o "$(BUILD)/sim.vvp" -s gpu -g2012 "$(BUILD)/gpu.v"
	cd "$(ROOT)" && COCOTB_TEST_MODULES=sim.legacy.test_$* vvp -m $$( $${PYGPI_PYTHON_BIN} -m cocotb_tools.config --lib-name-path vpi icarus ) "$(BUILD)/sim.vvp"

# Plain Verilog testbench (no cocotb): make tb_matmul / tb_matadd, writes build/gpu.vcd
CLK_PERIOD ?= 10

tb_%:
	$(MAKE) -C "$(ROOT)" compile
	iverilog -g2012 -o "$(BUILD)/tb.vvp" -s tb_gpu -DCLK_PERIOD=$(CLK_PERIOD) $(if $(filter matadd,$*),-DMATADD) "$(BUILD)/gpu.v" "$(ROOT)/sim/legacy/tb_gpu.v"
	cd "$(ROOT)" && vvp "$(BUILD)/tb.vvp" +vcd

# Gate-level sim of a DC netlist for PrimeTime power:
#   make gls NETLIST=results/ss/runs/best_ss_lh_cg/out/gpu_netlist.v CLK_PERIOD=2.9 SAED=~/saed32/lib
# Writes build/gpu_gls.vcd. Zero-delay (no SDF), so PT sees functional toggles only.
# SAED points at a copy of SAED32_EDK/lib holding stdcell_*/verilog; missing Vt flavors are skipped.
SAED ?= /usr/local/synopsys/pdk/SAED32_EDK/lib
SAED_VLIB = $(wildcard $(SAED)/stdcell_rvt/verilog/saed32nm.v $(SAED)/stdcell_hvt/verilog/saed32nm_hvt.v $(SAED)/stdcell_lvt/verilog/saed32nm_lvt.v)
NETLIST ?= $(ROOT)/results/ss/runs/best_ss_lh_cg/out/gpu_netlist.v

# The cell models are copied through sim/saed_xfix.awk (mux X-select rows, see that file)
GLS_VLIB = $(addprefix $(BUILD)/saed_models/,$(notdir $(SAED_VLIB)))

$(BUILD)/saed_models/%.v: $(ROOT)/sim/saed_xfix.awk
	mkdir -p "$(BUILD)/saed_models"
	awk -f "$(ROOT)/sim/saed_xfix.awk" $(filter %/$*.v,$(SAED_VLIB)) > $@

gls: $(GLS_VLIB)
	mkdir -p "$(BUILD)"
	cd "$(ROOT)" && iverilog -g2012 -o build/gls.vvp -s tb_gpu -DCLK_PERIOD=$(CLK_PERIOD) $(if $(MATADD),-DMATADD) \
		"$(NETLIST)" $(GLS_VLIB) sim/legacy/tb_gpu.v
	cd "$(ROOT)" && vvp build/gls.vvp +vcd +vcdfile=build/gpu_gls.vcd

compile:
	mkdir -p "$(BUILD)"
	$(MAKE) -C "$(ROOT)" compile_alu
	sv2v -I "$(ROOT)"/rtl/* -w "$(BUILD)/gpu.v"
	echo "" >> "$(BUILD)/gpu.v"
	cat "$(BUILD)/alu.v" >> "$(BUILD)/gpu.v"
	echo '`timescale 1ns/1ns' > "$(BUILD)/temp.v"
	cat "$(BUILD)/gpu.v" >> "$(BUILD)/temp.v"
	mv "$(BUILD)/temp.v" "$(BUILD)/gpu.v"

compile_%:
	mkdir -p "$(BUILD)"
	sv2v -w "$(BUILD)/$*.v" "$(ROOT)/rtl/$*.sv"

# TODO: Get gtkwave visualizaiton

show_%: %.vcd %.gtkw
	gtkwave $^

# Midterm verification: generation/software checks do not invoke an HDL toolchain.
PYTHON ?= python3
VERIFY_ARGS ?=
.PHONY: verification_unit verification_vectors verification_rtl verification_netlist

verification_unit:
	cd "$(ROOT)" && $(PYTHON) -m unittest sim.test_suite -v

verification_vectors:
	cd "$(ROOT)" && $(PYTHON) -m sim.run --mode generate $(VERIFY_ARGS)

# Explicit opt-in only; uses supplied converted RTL/netlist, never regenerates it.
verification_rtl:
	cd "$(ROOT)" && $(PYTHON) -m sim.run --mode rtl $(VERIFY_ARGS)

verification_netlist:
	cd "$(ROOT)" && $(PYTHON) -m sim.run --mode netlist $(VERIFY_ARGS)

check:
	cd "$(ROOT)" && $(PYTHON) -m unittest sim.test_suite scripts.test_repository -v
