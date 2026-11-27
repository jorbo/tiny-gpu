# Synthesis flow

Run from the repository root on a licensed host. The maintained scripts have
repository-relative path handling and default to the worst-case SS 0.75 V / 125 °C
libraries (`CORNER=ss0p75v125c`). Use `CORNER=tt0p78v25c` only to replay the
exploratory TT runs.

```bash
make compile
mkdir -p build/synthesis
dc_shell \
  -x 'set CLK_PERIOD 2.9; set CORNER ss0p75v125c; set USE_HVT 1; set USE_LVT 1; set NO_RVT 1; set CLOCK_GATING 1; set RUN_DIR build/synthesis/ss_candidate' \
  -f syn/dc_synth.tcl > build/synthesis/dc.log 2>&1
```

Outputs are `RUN_DIR/out/` and `RUN_DIR/reports/`. Without `RUN_DIR`, the defaults
are `build/synthesis/rvt` or `build/synthesis/multi_vt`. Relative paths are rooted
at the repository, not the invoking directory. RTL/optional SAIF are read from
`build/gpu.v` and `build/gpu.saif`; constraints come from `syn/constraints.sdc`.

Design variants: `make compile VARIANT=a1` writes `build/gpu_a1.v` (A1, WAIT bypass,
`rtl/scheduler_a1.sv`). Pass `set RTL build/gpu_a1.v` in `-x` to synthesize it. In
the sweep, `VARIANT=a1` does this and tags run names with `_a1`
(`ss_lh_cg_a1_<period>`); the default `VARIANT=baseline` keeps the old names.

Each run analyzes RTL into its own design library, `RUN_DIR/work`. Before this,
`analyze` wrote `*.mr`/`*.syn` files into the shared working directory, so
concurrent DC runs of different RTL (baseline and A1 sweeps) could elaborate each
other's modules. Single-variant sweeps, like the midterm's, were not affected.

The optimization flags, clock-gating choices, setup margin, hold/DRC repair loops,
and numeric constraints were not changed by repository organization. The exact
SS flow is preserved in `results/ss/flow_snapshot/syn/`; the original TT scripts
remain in `results/tt/flow_snapshot/syn/`.

## Period search

```bash
RUN_ROOT="$PWD/build/sweeps/ss_lh" CORNER=ss0p75v125c CG=1 JOBS=3 \
  bash syn/sweep.sh lh 2.85 3.10 0.05
# A1 (after make compile VARIANT=a1)
VARIANT=a1 RUN_ROOT="$PWD/build/sweeps" CG=1 JOBS=2 bash syn/sweep.sh lh 2.70 3.10 0.05
```

`RUN_ROOT` defaults to `build/sweeps/`; each candidate gets its own directory.
`JOBS=3` needs up to three DC licenses. Modes are `rvt`, `hvt` (RVT+HVT), `lvt`
(LVT+RVT+HVT), and `lh` (LVT+HVT). Clock gating is off by default; pass `CG=1` for
the recorded gated sweep. Run names include the corner and gating, but use a
distinct `RUN_ROOT` for each source version or configuration. Do not mix SS and TT
cached results.

After synthesis inspect errors, setup/hold, max transition/capacitance, Vt mix,
and cell area. A CSV PASS is not a substitute for independent PrimeTime checks.
For signoff, retain unfiltered high-precision critical paths as well as violation
reports. Archive selected inputs/scripts/reports under the appropriate `results/`
corner directory; keep unsuccessful scratch iterations in `build/` unless useful
as explicitly labeled evidence.
