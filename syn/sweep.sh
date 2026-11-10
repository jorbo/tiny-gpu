#!/usr/bin/env bash
# Binary search for the shortest clock period that closes timing in Design Compiler.
# A run passes when every setup slack >= 0, there are no hold violations and no DRC
# (max_transition / max_capacitance) violations.
#
# Run from syn/ after `make compile`:
#   ./sweep.sh [vt] [lo_ns] [hi_ns] [step_ns]
#   vt: rvt | hvt (RVT+HVT, default) | lvt (LVT+RVT+HVT) | lh (LVT+HVT, no RVT)
# Results: runs/<vt>_<period>/ per run, runs/sweep_<vt>.csv, runs/best_<vt> -> best run dir

set -u
VT=${1:-hvt}
LO=${2:-1.0}
HI=${3:-8.0}
STEP=${4:-0.05}
# Parallel DC runs per round (one license each): JOBS=3 ./sweep.sh lh
JOBS=${JOBS:-1}
# Library corner (default worst case, per the project spec) and clock gating: CG=1 ./sweep.sh lh
CORNER=${CORNER:-ss0p75v125c}
CG=${CG:-0}

case $VT in
    rvt) VT_ARGS="set USE_HVT 0; set USE_LVT 0" ;;
    hvt) VT_ARGS="set USE_HVT 1; set USE_LVT 0" ;;
    lvt) VT_ARGS="set USE_HVT 1; set USE_LVT 1" ;;
    lh)  VT_ARGS="set USE_HVT 1; set USE_LVT 1; set NO_RVT 1" ;;
    *)   echo "unknown vt '$VT' (rvt|hvt|lvt|lh)"; exit 1 ;;
esac

# Run names carry the corner and gating so they never reuse another config's results:
# ss0p75v125c + CG=1 + lh -> runs/ss_lh_cg_<period>
NAME=${CORNER:0:2}_$VT
[ "$CG" = 1 ] && NAME=${NAME}_cg
VT_ARGS="$VT_ARGS; set CORNER $CORNER; set CLOCK_GATING $CG"

mkdir -p runs
CSV=runs/sweep_$NAME.csv
[ -f "$CSV" ] || echo "period_ns,freq_mhz,setup_wns,tns,hold_viol,drc_nets,cell_area,status" > "$CSV"

# Synthesize at period $1, print PASS or FAIL
run_period() {
    local p dir qor wns tns hold drc area status
    p=$(printf "%.2f" "$1")
    dir=runs/${NAME}_$p
    qor=$dir/reports/qor.rpt
    if [ ! -f "$qor" ]; then
        mkdir -p "$dir"
        echo "$(date +%T) synthesizing at $p ns (log: $dir/dc.log)" >&2
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
    grep -q "^$p," "$CSV" || echo "$p,$(awk -v p="$p" 'BEGIN {printf "%.1f", 1000 / p}'),$wns,$tns,$hold,$drc,$area,$status" >> "$CSV"
    [ $status = FAIL ] && echo "  $p ns: setup_wns=$wns tns=$tns hold_viol=$hold drc_nets=$drc" >&2
    echo $status
}

# hi must pass; lo is assumed to fail
if [ "$(run_period "$HI")" != PASS ]; then
    echo "period $HI ns does not close timing, raise hi"
    exit 1
fi
best=$(printf "%.2f" "$HI")
# Each round synthesizes JOBS periods spread evenly inside (lo, hi) in parallel, then narrows to
# the smallest pass and the largest fail below it. JOBS=1 is a plain binary search.
while awk -v l="$LO" -v h="$HI" -v s="$STEP" 'BEGIN {exit !(h - l > s + 1e-9)}'; do
    points=$(awk -v l="$LO" -v h="$HI" -v s="$STEP" -v n="$JOBS" 'BEGIN {
        for (i = 1; i <= n; i++) {
            p = int((l + (h - l) * i / (n + 1)) / s + 0.5) * s
            if (p > l + 1e-9 && p < h - 1e-9) printf "%.2f\n", p
        }}' | sort -un)
    for p in $points; do
        run_period "$p" > "runs/.status_${NAME}_$p" &
    done
    wait
    for p in $points; do
        r=$(cat "runs/.status_${NAME}_$p")
        rm -f "runs/.status_${NAME}_$p"
        echo "period $p ns: $r"
        if [ "$r" = PASS ] && awk -v p="$p" -v h="$HI" 'BEGIN {exit !(p < h)}'; then
            HI=$p
            best=$p
        fi
    done
    for p in $points; do
        r=$(grep "^$p," "$CSV" | tail -1 | awk -F, '{print $NF}')
        if [ "$r" != PASS ] && awk -v p="$p" -v l="$LO" -v h="$HI" 'BEGIN {exit !(p > l && p < h)}'; then
            LO=$p
        fi
    done
done

ln -sfn "${NAME}_$best" "runs/best_$NAME"
echo "best period: $best ns ($(awk -v p="$best" 'BEGIN {printf "%.1f", 1000 / p}') MHz) -> runs/best_$NAME"
