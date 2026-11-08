#!/usr/bin/env bash
# Binary search for the shortest clock period that closes timing in Design Compiler.
# A run passes when every setup slack >= 0, there are no hold violations and no DRC
# (max_transition / max_capacitance) violations.
#
# Run from syn/ after `make compile`:
#   ./sweep.sh [vt] [lo_ns] [hi_ns] [step_ns]
#   vt: rvt | hvt (RVT+HVT, default) | lvt (LVT+RVT+HVT)
# Results: runs/<vt>_<period>/ per run, runs/sweep_<vt>.csv, runs/best_<vt> -> best run dir

set -u
VT=${1:-hvt}
LO=${2:-1.0}
HI=${3:-8.0}
STEP=${4:-0.05}

case $VT in
    rvt) VT_ARGS="set USE_HVT 0; set USE_LVT 0" ;;
    hvt) VT_ARGS="set USE_HVT 1; set USE_LVT 0" ;;
    lvt) VT_ARGS="set USE_HVT 1; set USE_LVT 1" ;;
    *)   echo "unknown vt '$VT' (rvt|hvt|lvt)"; exit 1 ;;
esac

mkdir -p runs
CSV=runs/sweep_$VT.csv
[ -f "$CSV" ] || echo "period_ns,freq_mhz,setup_wns,tns,hold_viol,drc_nets,cell_area,status" > "$CSV"

# Synthesize at period $1, print PASS or FAIL
run_period() {
    local p dir qor wns tns hold drc area status
    p=$(printf "%.2f" "$1")
    dir=runs/${VT}_$p
    qor=$dir/reports/qor.rpt
    if [ ! -f "$qor" ]; then
        mkdir -p "$dir"
        dc_shell -x "set CLK_PERIOD $p; $VT_ARGS; set RUN_DIR $dir" -f dc_synth.tcl > "$dir/dc.log" 2>&1
    fi
    if [ ! -f "$qor" ]; then
        echo "$p,,,,,,,ERROR" >> "$CSV"
        echo FAIL
        return
    fi
    # Worst value over all path groups
    wns=$(awk '/Critical Path Slack:/ {if (min == "" || $4 < min) min = $4} END {print min}' "$qor")
    tns=$(awk '/Total Negative Slack:/ {s += $4} END {print s + 0}' "$qor")
    hold=$(awk '/No. of Hold Violations:/ {s += $5} END {print s + 0}' "$qor")
    drc=$(awk '/Nets With Violations:/ {print $4}' "$qor")
    area=$(awk '/Cell Area:/ {print $3}' "$qor")
    if awk -v w="$wns" -v t="$tns" -v h="$hold" -v d="$drc" 'BEGIN {exit !(w >= 0 && t == 0 && h == 0 && d == 0)}'; then
        status=PASS
    else
        status=FAIL
    fi
    echo "$p,$(awk -v p="$p" 'BEGIN {printf "%.1f", 1000 / p}'),$wns,$tns,$hold,$drc,$area,$status" >> "$CSV"
    echo $status
}

# hi must pass; lo is assumed to fail
if [ "$(run_period "$HI")" != PASS ]; then
    echo "period $HI ns does not close timing, raise hi"
    exit 1
fi
best=$(printf "%.2f" "$HI")
while awk -v l="$LO" -v h="$HI" -v s="$STEP" 'BEGIN {exit !(h - l > s + 1e-9)}'; do
    mid=$(awk -v l="$LO" -v h="$HI" -v s="$STEP" 'BEGIN {printf "%.2f", int((l + h) / 2 / s + 0.5) * s}')
    r=$(run_period "$mid")
    echo "period $mid ns: $r"
    if [ "$r" = PASS ]; then
        HI=$mid
        best=$mid
    else
        LO=$mid
    fi
done

ln -sfn "${VT}_$best" "runs/best_$VT"
echo "best period: $best ns ($(awk -v p="$best" 'BEGIN {printf "%.1f", 1000 / p}') MHz) -> runs/best_$VT"
