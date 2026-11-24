# Midterm verification suite

This suite implements the report's ten constrained-random families (R01 through
R10) and ten corner-case families (C01 through C10). Python 3.9+ and its standard
library are enough to generate vectors and test the reference/generators.

**DUT status: RTL pass, netlist not run.** The full default corpus was compiled
with Icarus Verilog 13.0 and run against converted RTL at 2.90 ns: 1,039 of 1,039
instances pass after two baseline fixes (partial-block PC selection and CMP flag
ordering). The manifest and summary are in `results/verification/`. Netlist mode
has not been run because the SAED32 Verilog models are not installed here; the
archived SS netlist also predates the fixes and must be resynthesized.

## Files

| File | Purpose |
|---|---|
| `sw/golden.py` | Independent eight-bit architectural interpreter and instruction encoding. |
| `sim/cases.py` | Programs, seeded random workloads, corner fixtures, reference expectations. |
| `sim/tb_regression.v` | Shared top-level Verilog testbench for converted RTL or a mapped netlist. |
| `sim/run.py` | Offline export and explicitly requested future simulation, logs, summary manifest. |
| `sim/test_suite.py` | Software-only checks of the interpreter, generators, export, and runner. |

The original TB and cocotb workloads are preserved under `sim/legacy/`. Run commands from the
repository root. On this Mac use `/usr/bin/python3` or another explicitly selected
Python 3.9+ interpreter; no package installation or virtual environment is needed.

## Run without hardware tools

```bash
make verification_unit PYTHON=/usr/bin/python3
make verification_vectors PYTHON=/usr/bin/python3
```

The default export contains **1,039 instances**: 100 random instances for each of
the ten random families plus 39 directed instances across ten corner families.
Output defaults to a new timestamped directory under `build/verification/`.
`manifest.json` records every instance as `not_run`. No simulator is discovered or
invoked in generation mode, which is also the CLI's default mode.

An explicit directory and a small developer sample can be requested:

```bash
/usr/bin/python3 -m sim.run --mode generate --trials 2 --out build/vectors-small
/usr/bin/python3 -m sim.run --case C09 --out build/vectors-branches
```

Output directories must not already exist. This prevents accidental overwriting
of earlier evidence. Use a new `--out` for each command, or omit it for a unique
timestamped directory. Default exports are generated artifacts; the scripts and
software model are the source deliverables to retain in version control.

Each instance contains:

- `program.hex`: 256 sixteen-bit instruction words, padded with NOPs.
- `data.hex`: all 256 initial data bytes, including guard values.
- `expected.hex`: all 256 final bytes, including unchanged guards.
- `writes.hex`: a 32-bit expected accepted-store count for every byte address.
- `case.json`: testcase family, goal, corpus seed, per-instance delay seed, thread
  count, response delays, and reset mode.

The top-level manifest records image/configuration hashes, verification-source
hashes (including the testbench and reference), and per-instance status.
The full-memory comparison detects unexpected writes. Per-address write counts
detect omitted stores even if a destination already contains its expected value,
and duplicate stores even if they write the same value.

## Testcase catalog

Each random family has its own RNG seeded with `1000 + family_number + seed_offset`.
Trials consume that deterministic sequence in order. `--seed-offset` selects a
different reproducible corpus; `--trials` defaults to 100 for **each** random family.

| Family | Verification goal and expected result |
|---|---|
| R01 | Eight-thread random-byte matadd; two cores, modulo-256 sums. |
| R02 | Four-thread random-byte matadd; one core, no idle-core writes. |
| R03 | Random length-12/16 matadd; redispatch and correct block IDs/output indices. |
| R04 | Random 2×2 matmul with bytes 0 through 7; exact integer matrix product. |
| R05 | Random full-byte 2×2 matmul; dot products modulo 256. |
| R06 | Random dependent CONST/ADD/SUB/MUL program; all eight working-register signatures correct. |
| R07 | Eight random nonzero-divisor divisions with dependent additions; quotient-dependent signatures correct. |
| R08 | Six lane-local store/load sequences; stored data, reload signatures, and counts correct. |
| R09 | Random CMP and branch masks with convergent lanes; taken or fallthrough signature correct. |
| R10 | Two-core matadd with independent random channel response delays of 1 through 8 cycles; same correct data despite backpressure. |
| C01 | Thread counts 1, 3, 5, 7; inactive lanes must not write, partial blocks must terminate. |
| C02 | Zero threads; `done` must arrive, memory must be unchanged, no data request permitted. |
| C03 | Thread counts 12, 13, 20; core reuse and partial final block with correct outputs/guards. |
| C04 | Four ADD/SUB boundary programs: 255+1, 0-1, 127+1, 128-1; byte wraparound correct. |
| C05 | MUL 255×255, 255×0, 255×1; results 1, 0, 255. |
| C06 | DIV 0/1, 255/1, 255/255, 1/255; results 0, 255, 1, 0. |
| C07 | Attempts to overwrite R13/R14/R15; metadata signatures remain block ID, 4, and lane ID across 12 threads. |
| C08 | Read/modify/write addresses 0 through 3 and 252 through 255; boundary bytes updated once, other bytes unchanged. |
| C09 | Five less/equal/greater and sign-boundary operand pairs × three individual NZP masks; correct branch signature in all 15 programs. |
| C10 | Reset during the first unacknowledged read or write, then restart; pending response discarded and final outputs/counts correct. |

Corner cases are directed programs, not aliases of the random families. Instances
within a family are not counted as additional assignment testcase types. R06,
R07, and R08 observe intermediate operations through multiple stored signatures.

## Architectural reference contract

The interpreter executes four-lane blocks with protected metadata registers,
eight-bit arithmetic/addresses/PCs, and unsigned division. N/Z/P are bits 2/1/0,
with N for unsigned `a < b`, Z for equality, and P for `a > b`. This is an explicit
expected contract, not an attempt to duplicate the RTL's comparison expression
sizing or flag ordering. C09 exposed a real disagreement with the original ALU;
the RTL now compares the operands directly and matches this contract.

Division by zero, divergent branch decisions, invalid opcodes, nontermination,
and cross-thread memory races are rejected during generation. Programs use
disjoint output/scratch regions per thread and convergent control flow, so the
reference does not depend on hardware arbitration order. It is not a timing model.

The partial-block cases exposed the scheduler's old last-lane PC choice; the RTL
now selects the last active lane's PC. Do not suppress or relabel a DUT failure as
PASS. Any further baseline fixes and fresh synthesis should be separate, documented
work.

## Testbench memory and reset behavior

The memory responder captures one request per valid episode. After a selected
delay of 1 through 8 rising edges it returns data/commits a store and asserts ACK.
ACK remains asserted until valid drops. Request address/data must stay stable
while valid is asserted. Read and write channels are independent, and conflicting
simultaneous accesses are outside the generated corpus. A held-valid store is
committed once, not on every clock edge.

These response timings intentionally have a defined capture/wait/ACK model;
do not compare its cycle counts directly with the older matrix testbench's memory
model. Delays describe the responder, not an SRAM macro or the complete controller
round trip. R10 uses a deterministic testbench LCG initialized from a distinct
recorded per-instance `delay_seed`, sampled separately per transaction/channel.
The seed is derived from the corpus seed and instance name with SHA-256, without
consuming the stimulus RNG. Delays use the LCG's upper bits to avoid a repeated
eight-transaction schedule from its low bits.

C10 asserts reset on a falling edge after a pending transaction has been captured
but before ACK. Dispatcher/core reset propagates during six reset cycles; the
responder drops pending transactions and readiness. External memory contents
survive reset rather than being reloaded to hide earlier writes. The same program
is restarted and compared with a fresh architectural execution. The reset test
models cancellation of an **unacknowledged** memory transaction, not persistence
of a transaction already committed by external memory.

The testbench uses only top-level ports, avoiding hierarchy/name differences
between RTL and synthesized netlists. It checks unknown request signals/payloads,
stable requests, completion, all bytes, and store counts. Failure uses `$fatal(1)`.
Inputs are driven on falling edges. No SDF is applied: future netlist runs check
logical behavior, not setup/hold timing or glitch power.

## Running with a toolchain

The RTL commands below were executed with Icarus Verilog 13.0; the netlist command
is not yet run in this environment. They require Icarus Verilog with SystemVerilog
support (`-g2012`) and `vvp`. The runner never installs tools, regenerates RTL, or
silently skips missing files.

Converted RTL, using the checked-in file or a newly generated equivalent:

```bash
python3 -m sim.run --mode rtl --rtl build/gpu.v --period 2.9 \
  --out build/verification-rtl
```

Mapped netlist (supply all actual mapped Vt cell-model files):

```bash
python3 -m sim.run --mode netlist \
  --netlist results/ss/runs/best_ss_lh_cg/out/gpu_netlist.v \
  --cell-model "$SAED/stdcell_lvt/verilog/saed32nm_lvt.v" \
  --cell-model "$SAED/stdcell_hvt/verilog/saed32nm_hvt.v" \
  --period 2.9 --out build/verification-netlist
```

Set `SAED` to the licensed PDK library directory; it is not downloaded. If a
different netlist includes RVT cells, supply its RVT model too. Use the exact final
post-ECO netlist when validating ECO changes; loading only the earlier DC netlist
does not test a separate PrimeTime change list. Timing closure and SS-corner PPA
remain separate licensed-tool tasks.

The Makefile also provides `verification_rtl` and `verification_netlist`, forwarding
`VERIFY_ARGS` to the corresponding mode. Simulation compiles once and starts a
fresh simulator process per instance. It saves the compile command, source hashes,
compile log, simulator executable hashes, per-instance command/log/status/cycles,
and a final manifest. Timeouts retain available partial stdout/stderr. A clean
exit plus exactly one matching `PASS <instance> cycles=<n>` is required. A missing
marker, explicit failure, tool error, or timeout fails the run. A preflight or
compilation error records `dut_status: error`, never PASS. The default wall timeout
is 60 seconds per compilation/instance; the HDL budget is 100,000 cycles.

Select one family or replay one trial using the same seed offset and a trial
count large enough to include that trial:

```bash
python3 -m sim.run --mode rtl --case C01 --out build/partial-block-check
python3 -m sim.run --mode rtl --case R01_0073 --trials 100 \
  --seed-offset 0 --out build/replay-r01-73
```

Use `--vcd` only when needed; it writes one potentially large waveform per selected
instance. These regression traces are not automatically representative long-window
power traces. A hardware pass is meaningful only for the source hashes and selected
instances recorded in that manifest; run all families before reporting full coverage.
