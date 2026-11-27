# PrimeTime flow

These scripts default to the worst-case SS 0.75 V / 125 °C libraries
(`CORNER=ss0p75v125c`). The exact SS flow used for the recorded baseline is
preserved in `results/ss/flow_snapshot/syn/`; use `CORNER=tt0p78v25c` only for the
exploratory TT replay.

Set `RUN_DIR` explicitly. It must contain `out/gpu_netlist.v` and `out/gpu.sdc`.
Relative paths are repository-relative; absolute host paths are also supported.
Use a working directory under `build/` rather than modifying archived evidence.

```bash
# After synthesizing build/synthesis/ss_candidate:
pt_shell -x 'set RUN_DIR build/synthesis/ss_candidate; set CORNER ss0p75v125c' \
  -f ptpx/pt_eco.tcl > build/synthesis/pt_eco.log 2>&1
```

The ECO script writes `out/eco_changes.tcl`, `out/eco_changes_dc.tcl`, and a
remaining-violation report. The power script applies the PT change list by
default. The netlist on disk is not automatically rewritten; export and simulate
the exact changed implementation before final gate-level validation/activity.

`ptpx/export_eco_netlist.tcl` does that export in `dc_shell`: it reads
`out/gpu_netlist.v`, sources `out/eco_changes_dc.tcl`, and writes
`out/gpu_netlist_eco.v` (same `change_names`/`write` settings as synthesis).
Replaying it on the archived 2.90 ns run gives 46,632.882978 µm², identical to
PrimeTime's post-ECO area, and the result passes matmul GLS in 491 cycles.

```bash
dc_shell -x 'set RUN_DIR build/sweeps/ss_lh_cg_a1_<period>' -f ptpx/export_eco_netlist.tcl
```

Simulate `gpu_netlist_eco.v` (regression and VCDs); PrimeTime keeps reading
`gpu_netlist.v` plus `eco_changes.tcl`, which is the same implementation.

## Workload activity and power

Set `SAED` to the licensed PDK library directory, not a downloaded replacement.
The following legacy-TB commands generate one waveform per matrix workload:

```bash
make gls NETLIST=build/synthesis/ss_candidate/out/gpu_netlist.v \
  CLK_PERIOD=2.9 SAED="$SAED"
cp build/gpu_gls.vcd build/matmul.vcd
make gls NETLIST=build/synthesis/ss_candidate/out/gpu_netlist.v \
  CLK_PERIOD=2.9 MATADD=1 SAED="$SAED"
cp build/gpu_gls.vcd build/matadd.vcd

pt_shell \
  -x 'set RUN_DIR build/synthesis/ss_candidate; set CORNER ss0p75v125c; set VCD build/matmul.vcd; set RPT_NAME pt_reports' \
  -f ptpx/pt_power.tcl > build/synthesis/pt_matmul.log 2>&1
pt_shell \
  -x 'set RUN_DIR build/synthesis/ss_candidate; set CORNER ss0p75v125c; set VCD build/matadd.vcd; set RPT_NAME pt_reports_matadd' \
  -f ptpx/pt_power.tcl > build/synthesis/pt_matadd.log 2>&1
```

Replace the example period with the selected run's period and use its exact
netlist. Current GLS is zero delay, not SDF timing verification. The new full
suite is separately documented in [sim/README.md](../sim/README.md).

**Extended-period (reported) power:** `LAUNCHES=20 scripts/power.sh <RUN_DIR> <period>`
simulates 20 back-to-back launches of each kernel (`sim/legacy/tb_gpu.v +launches=N`,
randomized data after launch 0, every launch checked). It passes the printed
`KERNEL_WINDOWS_NS` to `pt_power.tcl` as `VCD_TIME`, i.e. `read_vcd -time {s0 e0 ...}`
in ns, so power is averaged over kernel execution only. Reports go to
`pt_reports_n20/` and `pt_reports_matadd_n20/`. The average converged within 0.25%
between N=5 and N=20 (`results/a1/README.md`).

`USE_ECO` defaults to 1; `USE_SPEF` defaults to 0. Activity is averaged over the
full supplied VCD unless the measurement flow is explicitly changed. Save the
window and annotation diagnostics, resolve width/import errors, and use longer
representative executions before accepting final average power. Full annotation
coverage alone does not prove correct waveform interpretation.

For historical TT replay, copy the selected archive into a new `build/` working
directory, set `CORNER=tt0p78v25c`, and decompress its activity from
`results/tt/activity/`. Do not edit
the archived report/log/netlist bytes. Diagnostics are in `ptpx/diagnostics/`;
the SRAM probe is not an integrated memory implementation or a measured GPU PPA
component.
