# Tiny-GPU: CS 220 project

An educational two-core, four-lane-per-core SIMD GPU used to evaluate synthesis
and control-FSM optimizations. Team 6: Jordan Ayvazian, Shane Zimmerman, Svetlana
Nosova. The preserved [architecture and ISA documentation](docs/architecture.md)
describes the original tiny-gpu design and matrix kernels.

## Current status

- The selected baseline is the SS 0.75 V / 125°C clock-gated run at 2.90 ns
  (344.8 MHz) under `results/ss/runs/best_ss_lh_cg/`; its flow snapshot and
  activity are in `results/ss/`. Historical TT 0.78 V / 25°C results are retained
  under `results/tt/` as exploratory data.
- The full 10-random/10-corner-family suite passes 1,039/1,039 at RTL level after
  two baseline fixes (partial-block PC selection and CMP flags). The manifest is
  in `results/verification/`. Netlist regression is not yet run because the
  SAED32 models are absent, and the archived SS netlist predates the fixes.
- PrimeTime still reports 877 minimum-pulse-width violations at 2.90 ns, and the
  corrected RTL has not been resynthesized.
- The [report draft](docs/midterm/report.md) documents these results, the proposed
  optimizations, and the remaining evidence. The presentation and assignment PDF
  are also in `docs/midterm/`.

## Repository layout

| Directory | Contents |
|---|---|
| `rtl/` | Baseline SystemVerilog, relocated from `src/` without byte changes. |
| `sim/` | New regression suite; original Verilog/cocotb tests in `sim/legacy/`. |
| `sw/` | Independent architectural reference. |
| `syn/` | Design Compiler synthesis, constraints, and period sweep. |
| `ptpx/` | PrimeTime power/ECO; capacitance/SRAM diagnostics in `diagnostics/`. |
| `scripts/` | Portable Tcl paths and repository checks. |
| `results/` | SS baseline, corrected-RTL regression evidence, TT/legacy archives, relocation checksums. |
| `docs/` | Architecture, midterm report/presentation/assignment PDF, figures, wave-view settings, development notes. |
| `build/` | Disposable newly generated outputs, ignored by git. |

The [migration index](results/migration.json) records old/new paths and SHA-256
hashes for 320 preserved files, including RTL and historical evidence. Original
flow scripts are retained under `results/tt/flow_snapshot/`; original report/log/
netlist contents still contain their historical paths and are not rewritten.

## Offline setup and checks

Python 3.9+ and the standard library are sufficient. No install or virtual
environment is necessary. Run from the repository root; on this Mac choose the
explicit interpreter shown to avoid unrelated Python environments.

```bash
make check PYTHON=/usr/bin/python3
make verification_vectors PYTHON=/usr/bin/python3
```

`check` runs software-reference/generator/runner tests and repository layout
checks. It never runs HDL tools.
Vector generation creates a new timestamped directory under `build/verification/`
with 1,039 instances, all initially `not_run`. See [sim/README.md](sim/README.md)
for all families, seeds, expected results, and optional execution modes.

## Hardware tools and reproduction

Hardware commands require separately installed `sv2v`, Icarus Verilog/`vvp`, and
the course-provided SAED32 models. Synthesis and power need licensed Synopsys
tools and `.db` libraries. PDKs are external dependencies, not committed/exported.
Record actual tool versions on the execution host. Legacy cocotb tests target
cocotb 2.x; the compatibility commit records cocotb 2.0.1/Python 3.13.

```bash
# Requires sv2v; creates a fresh converted RTL input.
make compile

# Legacy functional kernels (cocotb), or plain Verilog kernel TB.
make test_matadd
make test_matmul
make tb_matmul CLK_PERIOD=2.9
make tb_matadd CLK_PERIOD=2.9

# New full suite: RTL mode passes 1,039/1,039 after the baseline fixes.
python3 -m sim.run --mode rtl --rtl build/gpu.v --period 2.9
```

The preserved pre-fix converted RTL is `results/tt/inputs/gpu.v`; the fixed
converted artifact used for the recorded regression is
`results/verification/gpu.v` (fresh `sv2v` conversion). Use an explicit `--rtl` argument to test a
snapshot without regenerating it. Do not confuse either with a fresh conversion
of the current RTL. Legacy logs go to
`build/logs/`; generated VCDs stay in `build/`. The old kernel TB and the new
regression responder use different memory timing, so their cycle counts are not
directly comparable.

See [syn/README.md](syn/README.md) for DC flags and frequency search and
[ptpx/README.md](ptpx/README.md) for ECO, period-matched activity, and PrimeTime.
Maintained Tcl scripts locate inputs relative to this repository, independent of
the caller's working directory. A relative `RUN_DIR` is repository-relative.
The maintained flows default to the SS corner; pass `CORNER=tt0p78v25c` only to replay the exploratory TT runs.

## Results and server handoff

The SS evidence has been imported into `results/ss/` with its exact flow
snapshot, run logs, constraints, library names, and tool versions; the payload
hashes are recorded in `results/ss/migration.json`. Future runs should use a new
unique `build/` directory while iterating, then be imported under a new
`results/ss/<run-id>/`. Never overwrite a TT run or rename TT data as SS.
[results/ss/README.md](results/ss/README.md) records the selected run and its
caveats. No server changes are performed by local commands.
