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
