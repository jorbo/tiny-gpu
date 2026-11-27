#!/bin/bash
# power.sh <run_dir> <period>: ECO-netlist GLS VCDs (matmul, matadd) -> PrimeTime power
#
# Default (LAUNCHES unset): one launch, power averaged over the whole VCD including
# reset/setup (midterm method); reports in pt_reports/ and pt_reports_matadd/.
#
# LAUNCHES=N: the legacy TB runs N back-to-back launches (+launches=N; launch 0 is the
# original data, later launches seeded random data, all checked) and PrimeTime averages
# only over the kernel windows it prints (KERNEL_WINDOWS_NS -> VCD_TIME). Reports go to
# pt_reports_n<N>/ and pt_reports_matadd_n<N>/; the log is power_n<N>.log.
#   LAUNCHES=20 scripts/power.sh build/sweeps/ss_lh_cg_a1_2.25 2.25
set -u
cd "$(dirname -- "${BASH_SOURCE[0]}")/.." || exit 1   # repository root
export PATH=$HOME/.local/bin:$PATH
R=$1; P=$2
LAUNCHES=${LAUNCHES:-}
SUFFIX=""; TB_ARGS=""
if [ -n "$LAUNCHES" ]; then SUFFIX=_n$LAUNCHES; TB_ARGS="+launches=$LAUNCHES"; fi
L=$R/power$SUFFIX.log; : > $L
M=$PWD/build/saed_models; B=$PWD/build/gls_$(basename $R)_eco; mkdir -p $B
for k in matmul matadd; do
  D=""; [ $k = matadd ] && D=-DMATADD
  iverilog -g2012 -o $B/$k$SUFFIX.vvp -s tb_gpu -DCLK_PERIOD=$P $D $R/out/gpu_netlist_eco.v $M/saed32nm_lvt.v $M/saed32nm_hvt.v sim/legacy/tb_gpu.v > $B/$k$SUFFIX.compile.log 2>&1
  (cd $B && vvp $k$SUFFIX.vvp +vcd +vcdfile=$k$SUFFIX.vcd $TB_ARGS) > $B/$k$SUFFIX.sim.log 2>&1
  echo "$k: $(grep -E 'Completed|PASS|FAIL' $B/$k$SUFFIX.sim.log | tr '\n' ' ')" >> $L
  grep -q '^PASS' $B/$k$SUFFIX.sim.log || { echo "SIM_FAIL $k" >> $L; exit 1; }
  rpt=pt_reports; [ $k = matadd ] && rpt=pt_reports_matadd
  rpt=$rpt$SUFFIX
  WIN=""
  if [ -n "$LAUNCHES" ]; then
    WIN=$(grep '^KERNEL_WINDOWS_NS' $B/$k$SUFFIX.sim.log | cut -d' ' -f2-)
    echo "$k windows: $(echo $WIN | wc -w) values" >> $L
  fi
  pt_shell -x "set RUN_DIR $R; set CORNER ss0p75v125c; set VCD $B/$k$SUFFIX.vcd; set VCD_TIME {$WIN}; set RPT_NAME $rpt; set USE_ECO 1; set USE_SPEF 0" -f ptpx/pt_power.tcl > $R/pt_$k$SUFFIX.log 2>&1
  echo "$k power:" >> $L; cat $R/$rpt/summary.rpt >> $L
  # Large waveforms are not needed after PrimeTime has read them
  [ -n "$LAUNCHES" ] && rm -f $B/$k$SUFFIX.vcd
done
echo DONE >> $L
