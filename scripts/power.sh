#!/bin/bash
# power.sh <run_dir> <period>: ECO-netlist GLS VCDs (matmul, matadd) -> PrimeTime power
set -u
cd /home/csgrad/szimm011/tiny-gpu/tiny-gpu
export PATH=$HOME/.local/bin:$PATH
R=$1; P=$2; L=$R/power.log; : > $L
M=$PWD/build/saed_models; B=$PWD/build/gls_$(basename $R)_eco; mkdir -p $B
for k in matmul matadd; do
  D=""; [ $k = matadd ] && D=-DMATADD
  iverilog -g2012 -o $B/$k.vvp -s tb_gpu -DCLK_PERIOD=$P $D $R/out/gpu_netlist_eco.v $M/saed32nm_lvt.v $M/saed32nm_hvt.v sim/legacy/tb_gpu.v > $B/$k.compile.log 2>&1
  (cd $B && vvp $k.vvp +vcd +vcdfile=$k.vcd) > $B/$k.sim.log 2>&1
  echo "$k: $(grep -E 'Completed|PASS|FAIL' $B/$k.sim.log | tr '\n' ' ')" >> $L
  rpt=pt_reports; [ $k = matadd ] && rpt=pt_reports_matadd
  pt_shell -x "set RUN_DIR $R; set CORNER ss0p75v125c; set VCD $B/$k.vcd; set RPT_NAME $rpt; set USE_ECO 1; set USE_SPEF 0" -f ptpx/pt_power.tcl > $R/pt_$k.log 2>&1
  echo "$k power:" >> $L; cat $R/$rpt/summary.rpt >> $L
done
echo DONE >> $L
