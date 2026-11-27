# A1 results: bypass WAIT for non-memory instructions

Baseline = midterm RTL with the two bug fixes (`rtl/scheduler.sv`, `build/gpu.v`).
A1 = baseline with `rtl/scheduler_a1.sv` (`build/gpu_a1.v`). Both were synthesized
with the same flow: SS 0.75 V / 125 °C, LVT+HVT (no RVT mapped), clock gating,
`syn/constraints.sdc`. Each design is evaluated at its own maximum frequency.

## Maximum frequency selection

`syn/sweep.sh lh` (CG=1), searched between 2.00 and 2.50 ns (2.50 ns passes for both). A period passes DC with WNS >= 0,
TNS = 0, zero hold violations and zero DRC nets (`sweeps/*.csv`), and must then
also close in PrimeTime after `ptpx/pt_eco.tcl` (setup and hold >= 0, no violators).

| Design | Selected period | Next shorter period tried | Reason it failed |
|---|---|---|---|
| Baseline | 2.35 ns | 2.30 ns | DC 0.00 ns (rounded); PrimeTime -0.004 ns, 11 endpoints |
| A1 | 2.25 ns | 2.20 ns | DC WNS -0.08 ns, TNS -3.21 ns |

Before the selection, every DC run analyzed RTL into the shared working
directory, so concurrent baseline and A1 sweeps could elaborate each other's
modules (an "A1" 2.30 ns run produced a baseline scheduler). `syn/dc_synth.tcl`
now uses a per-run `RUN_DIR/work` design library; all numbers here come from
re-runs after that fix. Each selected netlist was also checked by gate-level
matmul: 491 cycles (baseline) and 455 cycles (A1), so each is the intended design.

## PPA comparison (PrimeTime, post-ECO)

| | Frequency (MHz) | Period (ns) | Setup WNS (ns) | Hold WNS (ns) | Area (µm²) | Power matmul (mW) | Power matadd (mW) |
|---|---:|---:|---:|---:|---:|---:|---:|
| Baseline | 425.5 | 2.35 | +0.047952 | +0.091396 | 46,934.043 | 6.6727 | 6.9490 |
| A1 | 444.4 | 2.25 | +0.067512 | +0.091396 | 45,035.333 | 6.5687 | 6.8654 |
| Change | +4.44% | -0.10 | | | -4.05% | -1.56% | -1.20% |

Power breakdown (mW):

| | matmul dynamic | matmul leakage | matadd dynamic | matadd leakage |
|---|---:|---:|---:|---:|
| Baseline | 0.9544 | 5.7183 | 1.1563 | 5.7927 |
| A1 | 1.0139 | 5.5548 | 1.2199 | 5.6455 |

No PrimeTime violators of any kind remain for either design, including
minimum pulse width. The midterm's 877 pulse-width violations matched its 877
`DFFX1_HVT` flops (1.42 ns minimum high phase). These netlists map every flop
to LVT.

Critical paths (DC, both are the per-lane ALU):

| Design | Startpoint | Endpoint | Arrival | Slack |
|---|---|---|---:|---:|
| Baseline | `cores[0]/threads[2]/register_instance/rt_reg[1]` | `threads[2]/alu_instance/alu_out_reg_reg[0]` | 2.13 ns | +0.07 ns |
| A1 | `cores[1]/threads[0]/register_instance/rs_reg[7]` | `threads[0]/alu_instance/alu_out_reg_reg[0]` | 2.03 ns | +0.07 ns |

## Latency and energy (legacy kernel testbench, gate level, ECO netlist)

`energy = average power × cycles × period`. The power is averaged over the full
trace (including reset/setup), so these are first-order estimates, as at the midterm.

| | matmul cycles | matmul latency | matmul energy | matadd cycles | matadd latency | matadd energy |
|---|---:|---:|---:|---:|---:|---:|
| Baseline | 491 | 1,153.85 ns | 7.699 nJ | 178 | 418.30 ns | 2.907 nJ |
| A1 | 455 | 1,023.75 ns | 6.725 nJ | 170 | 382.50 ns | 2.626 nJ |
| Change | -7.33% | -11.28% | -12.66% | -4.49% | -8.56% | -9.66% |

## Attribution: what A1 itself contributes

The critical path in both designs is the ALU, whose RTL is identical. By
hierarchy (`reports/area.rpt`), the A1 area saving is entirely in `alu_instance`
(13,833.8 → 11,903.9 µm² over eight lanes). The scheduler, the only module A1
changes, grows from 567.0 to 594.4 µm² (+27.4 µm², 0.06% of the design). The
frequency and area differences are therefore DC optimization variance on the
unchanged ALU, not an effect of A1. DC area is nonmonotonic in the period
(baseline 46.9-50.2k µm² between 2.30 and 2.50 ns).

A1's own effect is the cycle reduction at negligible area:

- matmul: 491 → 455 cycles (-36, exactly the 36 non-memory instructions per block)
- matadd: 178 → 170 cycles (-8 of 10 bypassed WAITs per block; two cores share one
  program-memory channel, so fetch arbitration absorbs part of the saving. In the
  regression testbench's memory model the 8-thread matadd saves only 1 cycle.)
- At an equal 2.35 ns clock, A1 latency would be 1,069.25 ns (matmul) and 399.50 ns
  (matadd).

## Verification

| Check | Baseline | A1 |
|---|---|---|
| RTL, `--suite all` (midterm 1,039 + A1 817), 2.90 ns | 1,856 / 1,856 | 1,856 / 1,856 |
| `sim.compare_cycles` RTL | | 0 violations (1,856 cases) |
| Netlist (ECO netlist, own period), `--suite all` | 1,856 / 1,856 | 1,856 / 1,856 |
| `sim.compare_cycles` netlist | | 0 violations (1,856 cases) |
| Netlist cycles equal to RTL cycles | 1,856 / 1,856 | 1,856 / 1,856 |
| GLS legacy matmul / matadd (ECO netlist) | PASS 491 / 178 | PASS 455 / 170 |

## For the final report

Mapped to the final project manual's parts; the numbers are the tables above.

- **Part 1 (RTL):** one file modified: `rtl/scheduler.sv` → `rtl/scheduler_a1.sv`
  (same module name; commented header). In the REQUEST state the next state is WAIT
  only if `decoded_mem_read_enable || decoded_mem_write_enable`, else EXECUTE. These
  decoder outputs were already wired to the scheduler but unused. No other RTL
  changed; `make compile VARIANT=a1` selects the file list.
- **Part 2 (verification):** the same testbench `sim/tb_regression.v` is used for
  RTL and netlist, so the netlist testbench does not differ. The ten A1 testcase
  families A1_01-A1_10 (goals and expected results tabulated in
  `sim/README.md`) all pass at RTL and gate level. Also report the A1-specific
  check, `sim/compare_cycles.py`: exact cycle saving per case, 0 violations.
- **Part 3 (synthesis/PT):** use the PPA comparison, critical-path and
  frequency-selection tables. Paste `runs/*/reports/qor.rpt`, `reports/timing.rpt`
  (first path), `pt_reports/summary.rpt`, `pt_reports/power.rpt` and
  `pt_reports/area.rpt` for both designs. State the attribution: the cycle
  reduction is A1's effect; the frequency and area deltas are DC variance in the
  unchanged ALU. Mention the shared-design-library bug and the PrimeTime slack
  check as methodology.
- **Part 4 (software model):** `sw/golden.py` now counts retired and memory
  instructions per block (commented as A1). Functional outputs are unchanged by
  A1. The predicted saving, retired minus memory instructions, matches hardware
  exactly for single-core runs (matmul 41 - 5 = 36).
- **Baseline section update:** the midterm's 344.8 MHz / 46,632.9 µm² / 877
  pulse-width violations describe the pre-fix netlist and a sweep that stopped at
  2.85 ns. The fixed baseline is 425.5 MHz / 46,934.0 µm² with no violations.
- **Caveats to state:** power is averaged over one kernel launch, including reset
  (see open items). The netlist is pre-layout, with an ideal clock and wire-load
  models. The two-core matadd saving is limited by the shared program-memory
  channel.

## Open items

1. **Extended-period power (required by the manual, both designs):** the VCDs
   cover one kernel launch, including reset. Run repeated launches (or a longer
   workload) until the average stabilizes, and report kernel-only power.
2. **Reproduction scripts:** the post-synthesis steps were run with throwaway
   scripts in the git-ignored `build/` directory. Move them into the repository
   and add them to the README:
   - `post_synth.sh`: gate-level identity check, PT ECO, PT timing probe, ECO export
   - `power.sh`: ECO-netlist VCDs, then PrimeTime power
   - `netlist_shards.sh`: parallel netlist regression
3. **Submission packaging:** the whole repository archives to about 28 MB, over
   the 20 MB limit. Build `final-team-6/` from `rtl sim sw syn ptpx scripts
   results/a1` plus the README (about 1.8 MB zipped), and fix the paths for that
   layout.
4. Optional: peak power.

## Files

- `runs/<design>_ss_lh_cg_<period>/`: `dc.log`, DC `reports/`, PT `pt_reports/` (matmul)
  and `pt_reports_matadd/`, PT/ECO logs, `out/gpu_netlist.v` (DC),
  `out/gpu_netlist_eco.v` (ECO applied, simulated), `out/eco_changes*.tcl`,
  `out/gpu.sdc`, `gls/` simulation logs.
- `sweeps/`: period-sweep CSVs. All rows are post-fix runs (per-run design
  library); the earlier shared-library sweeps are not used.
- `verification/`: compressed RTL and netlist manifests (netlist runs were sharded
  into one `sim.run --case` process per family and merged), compile logs,
  `compare_cycles` output for RTL and netlist.
