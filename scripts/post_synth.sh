#!/bin/bash
# post_synth.sh <run_dir> <period> <expect_matmul_cycles>
# GLS identity check -> PT ECO -> PT timing probe -> ECO netlist export
set -u
cd "$(dirname -- "${BASH_SOURCE[0]}")/.." || exit 1   # repository root
export PATH=$HOME/.local/bin:$PATH
R=$1; P=$2; EXP=$3; L=$R/post_synth.log
: > $L
B=$PWD/build/gls_$(basename $R); mkdir -p $B
M=$PWD/build/saed_models
iverilog -g2012 -o $B/mm.vvp -s tb_gpu -DCLK_PERIOD=$P $R/out/gpu_netlist.v $M/saed32nm_lvt.v $M/saed32nm_hvt.v $M/saed32nm.v sim/legacy/tb_gpu.v >> $L 2>&1
cyc=$((cd $B && vvp mm.vvp +vcd +vcdfile=gpu_gls.vcd) | grep -oP 'Completed in \K[0-9]+')
echo "GLS_DC matmul cycles=$cyc expect=$EXP" >> $L
[ "$cyc" = "$EXP" ] || { echo "IDENTITY_FAIL" >> $L; exit 1; }
pt_shell -x "set RUN_DIR $R; set CORNER ss0p75v125c" -f ptpx/pt_eco.tcl > $R/pt_eco.log 2>&1
grep "ECO changes" $R/pt_eco.log >> $L
pt_shell -x "set RUN_DIR $R; set CORNER ss0p75v125c; set VCD $B/gpu_gls.vcd; set RPT_NAME pt_probe" -f ptpx/pt_power.tcl > $R/pt_probe.log 2>&1
cat $R/pt_probe/summary.rpt >> $L
dc_shell -x "set RUN_DIR $R" -f ptpx/export_eco_netlist.tcl > $R/export.log 2>&1
grep -E "ECO export|Wrote" $R/export.log | grep -v echo >> $L
echo DONE >> $L
