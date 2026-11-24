# SS 0.75 V / 125 °C baseline evidence

This directory is the selected worst-case baseline, imported from the upstream
SS commits and relocated without payload changes. `migration.json` verifies every
file's SHA-256 against `origin/master`.

## Selected run

`runs/best_ss_lh_cg/` is the clock-gated LVT+HVT implementation at **2.90 ns
(344.8 MHz)**. It is a copy of `runs/ss_lh_cg_2.90/` with the PrimeTime reports
and ECO lists added.

| Quantity | Value |
|---|---:|
| DC pre-ECO cell area | 46,553.590 µm² |
| PrimeTime post-ECO cell area | 46,632.883 µm² |
| Setup WNS (PT) | +0.034710 ns |
| Hold WNS (PT) | +0.000011 ns |
| Max-capacitance violations | 0 after ECO (172 before) |
| Min-pulse-width violations | 877 at -0.07 ns |
| Matmul power | 1.0324 mW dynamic + 4.2243 mW leakage = 5.2567 mW |
| Matadd power | 1.2047 mW dynamic + 4.2728 mW leakage = 5.4775 mW |

The 2.90 ns point is the shortest DC-passing entry in `runs/sweep_ss_lh_cg.csv`;
2.85 ns fails with one design-rule net. PrimeTime's pulse-width check is not part
of the sweep pass test, so 2.90 ns is not pulse-width clean. At 3.05 ns the
checked high phase would be 1.425 ns against a 1.42 ns library minimum; that
point exists in the sweep but has no PrimeTime or power run.

## Layout

| Location | Contents |
|---|---|
| `runs/best_ss_lh_cg/` | Selected run: DC netlist/SDC/reports, PT ECO lists, PT timing/area/power reports, logs. |
| `runs/ss_lh_cg_*/` | Every saved sweep point, including the failing 2.85 ns candidate. |
| `runs/sweep_ss_lh_cg.csv`, `.log` | Sweep table and search log. |
| `activity/` | Compressed gate-level VCDs for matmul and matadd at 2.90 ns. |
| `flow_snapshot/syn/` | Exact SS flow scripts from `origin/master`: DC, sweep, PT ECO, PT power, constraints. |

## Caveats

- The DC netlist and the VCDs predate the two RTL bug fixes (partial-block PC
  selection and CMP flags). The PPAs here describe the pre-fix implementation.
- PrimeTime applies `out/eco_changes.tcl` inside the session. No ECO-applied
  netlist was exported, so the retained VCDs do not exactly match the post-ECO
  timing/area database.
- The power logs retain `PWR-264` vector-width warnings (6,789 matmul, 5,143
  matadd), one `PT-063` environment error, and 167 `NED-079` messages each.
- 99.99% of nets are annotated; the only nonannotated net is
  `program_memory_controller/mem_write_ready[0]`.

Do not copy licensed `.db`/`.lib` files into the repository. The Tcl scripts
expect the course PDK at `/usr/local/synopsys/pdk/SAED32_EDK/lib`.
