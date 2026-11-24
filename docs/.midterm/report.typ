#set document(title: "Tiny-GPU Midterm Report", author: ("Jordan Ayvazian", "Shane Zimmerman", "Svetlana Nosova"))
#set page(paper: "us-letter", margin: (x: 1.9cm, y: 2.1cm), numbering: "1")
#set text(font: "New Computer Modern", size: 10.5pt, lang: "en", hyphenate: true)
#set par(justify: true, leading: 0.62em)
#set heading(numbering: "1.1")
#show heading.where(level: 1): set text(size: 14pt)
#show heading.where(level: 2): set text(size: 12pt)
#show heading.where(level: 3): set text(size: 10.5pt)
#set table(inset: (x: 3.5pt, y: 2.5pt), stroke: 0.5pt + luma(190))
#set table(fill: (x, y) => if y == 0 { luma(236) } else { white })
#show table: set text(size: 8.4pt)
#show table: set par(justify: false)
#show table.cell.where(y: 0): set text(weight: "bold")
#show raw.where(block: false): set text(font: "DejaVu Sans Mono", size: 0.86em)
#show raw.where(block: true): block.with(fill: luma(246), inset: 7pt, radius: 2pt, width: 100%)
#show raw.where(block: true): set text(size: 8pt)

#align(center)[
  #text(18pt, weight: "bold")[Tiny-GPU Midterm Report]
  #v(0.6em)
  CS 220: Synthesis of Digital Systems, Fall 2026 \
  University of California, Riverside \
  Team 6: Jordan Ayvazian, Shane Zimmerman, Svetlana Nosova \
  November 9, 2026
]
#v(0.8em)

= Baseline
Tiny-GPU is an educational SIMD processor written in SystemVerilog. The
baseline has two compute cores of four thread lanes each and executes
one kernel at a time. A multicycle controller steps through FETCH,
DECODE, REQUEST, WAIT, EXECUTE, and UPDATE, which keeps the cost of each
control state visible and makes the design a suitable target for
control-state optimizations. The reported baseline is the clock-gated
LVT+HVT implementation at SS 0.75 V / 125 °C. This report covers the
baseline RTL, its verification, the software reference model, synthesis
and power results at the SS corner, and plans for three proposed
optimizations.

#align(center)[#table(
    columns: (auto, 1fr),
    align: (left, left),
    table.header([Parameter], [Value],),
    table.hline(),
    [Process corner], [SS 0.75 V / 125 °C],
    [Clock period], [2.90 ns],
    [Frequency], [344.8 MHz],
    [Standard-cell area], [46,632.883 µm² after ECO],
    [Setup slack], [+0.034710 ns],
    [Hold slack], [+0.000011 ns],
    [Average power, matmul], [5.2567 mW],
    [Average power, matadd], [5.4775 mW],
    [Kernel cycles, matmul / matadd], [491 / 178],
  )]

= Baseline RTL
== Design modules
The top-level default configuration has eight-bit data, eight-bit
addresses, 16-bit instructions, four external data-memory channels, and
one program-memory channel. Eight thread lanes share these interfaces
through memory controllers. All lanes in a block execute the same
instruction; each computes a next PC, but the scheduler assumes
convergence and uses the last active lane's value. Branch divergence is
unsupported. The existing workloads use full four-lane blocks, so
partial-block behavior is covered by the corner cases in Section 3.

#align(center)[#table(
    columns: (auto, 1fr),
    align: (left, left),
    table.header([Module], [Function],),
    table.hline(),
    [`rtl/gpu.sv`], [Instantiates the device control register,
    dispatcher, two cores, and both memory controllers. Registered links
    carry LSU traffic between cores and the data controller.],
    [`rtl/dcr.sv`], [Captures the eight-bit thread count when the host
    asserts `device_control_write_enable`.],
    [`rtl/dispatch.sv`], [Splits the thread count into blocks of four,
    assigns blocks to cores, supplies block IDs and active-lane counts,
    and raises kernel completion after all blocks finish.],
    [`rtl/controller.sv`], [Arbitrates consumer requests onto memory
    channels and returns each response to its requester. Separate
    instances serve instruction fetches and data accesses.],
    [`rtl/core.sv`], [Connects one scheduler, fetcher, and decoder to
    four lanes, each with an ALU, LSU, register file, and PC unit.],
    [`rtl/scheduler.sv`], [Sequences FETCH through UPDATE, tracks block
    completion, and selects the next shared PC.],
    [`rtl/fetcher.sv`], [Requests the instruction at the current PC and
    holds it until the core consumes it.],
    [`rtl/decoder.sv`], [Latches operand addresses, immediates, branch
    conditions, and control signals during DECODE; recognizes
    arithmetic, memory, constant, compare, branch, return, and NOP
    encodings.],
    [`rtl/registers.sv`], [Implements 16 eight-bit registers per lane.
    R0 through R12 are writable; R13, R14, and R15 hold block ID, block
    size, and thread ID. Reads operands in REQUEST and writes results in
    UPDATE.],
    [`rtl/alu.sv`], [Computes ADD, SUB, MUL, DIV, or comparison flags
    and registers the result during EXECUTE. Division is a combinational
    eight-bit operation.],
    [`rtl/lsu.sv`], [Issues a load or store, holds the request until a
    response arrives, captures returned data, and clears its transaction
    state during UPDATE.],
    [`rtl/pc.sv`], [Maintains lane-local NZP flags and calculates
    sequential or conditional-branch targets.],
  )]

== RTL changes
The RTL is the original tiny-gpu design with two bug fixes. No
instructions, registers, or interfaces were added. The regression suite
exposed both defects on its first full pass.

#align(center)[#table(
    columns: (auto, auto, 1fr),
    align: (left, left, left),
    table.header([Fix], [Files], [Change and justification],),
    table.hline(),
    [Partial-block PC selection], [`rtl/scheduler.sv`,
    `rtl/core.sv`], [A block with fewer than four active threads read
    `next_pc` from the last lane, which is disabled and never updates,
    so execution restarted at PC 0 indefinitely. The scheduler now takes
    `thread_count` and selects the last active lane's PC, holding PC 0
    when the count is zero.],
    [CMP flag encoding], [`rtl/alu.sv`], [Flags were derived from an
    unsigned eight-bit subtraction, so bit 2 meant \"not equal\" rather
    than \"less than\" and bit 0 was never set. The ALU now compares
    operands directly and writes N/Z/P to bits 2/1/0 for `a < b`,
    `a == b`, and `a > b`.],
  )]

Both are baseline bugs, not optimization regressions, and both are fixed
and re-verified. The corrected RTL passes all 1,039 default RTL
instances (Section 3.6). The synthesized netlist used for the PPA
predates these fixes.

== Measurement boundary
Program memory is 256 × 16 bits and data memory 256 × 8 bits. Both are
testbench arrays outside the synthesized `gpu` module, and the testbench
memory model serves all four data channels concurrently. It does not
model single-port SRAM serialization, bank conflicts, macro busy time,
or memory power. Reported area is standard-cell area, not die or
placed-and-routed area, and reported power covers GPU logic only. The
memory controllers and relay registers add latency beyond the memory
model itself.

= Verification
== Testbench and stimulus
`sim/legacy/tb_gpu.v` is the main Verilog testbench. It instantiates
`gpu`, drives clock and reset, initializes program and data memory,
writes the device control register, and launches a kernel. A
compile-time `MATADD` switch selects matrix addition instead of
multiplication, `CLK_PERIOD` sets the period, and `+vcd` dumps
waveforms. The testbench checks every expected output word and prints
`PASS` or a mismatch; a 100,000-cycle limit stops hung kernels. Failure
and timeout paths call `$finish`, so a zero exit status alone is not a
pass.

The regression testbench `sim/tb_regression.v` and runner `sim/run.py`
extend verification to directed, random, and corner cases.
`sim/cases.py` generates the programs and the input and expected memory
images. The testbench uses only top-level ports, so the same code runs
against converted RTL or a mapped netlist. Each instance checks all 256
memory bytes, per-address store counts, request stability, unknown
payloads, completion, and reset recovery, and calls `$fatal(1)` on
failure. A pass requires a clean exit and exactly one matching
`PASS <case> cycles=<n>` line.

The cocotb tests `sim/legacy/test_matmul.py` and
`sim/legacy/test_matadd.py` provide an independent path for the two
matrix kernels. They use a 25 µs clock and check function only. The 2.90
ns activity traces used for power come from the Verilog testbench.

== Netlist simulation
`make gls` compiles the same `tb_gpu` testbench against the synthesized
netlist and the SAED32 cell models. Array ports are already flattened,
so the packed testbench interfaces match. `sim/saed_xfix.awk`
preprocesses the mux UDP tables and adds X-select rows; without them the
SS netlist holds `core_state` at X after reset, because the scheduler's
next-state mux select is its own X output while both data inputs agree.
The patch changes simulation models only, not synthesized logic.

Gate-level simulation is zero delay and does not annotate the saved SDF.
It verifies mapped logical behavior and produces switching activity; it
does not demonstrate setup/hold closure or capture realistic gate-delay
glitches. Timing is checked separately in Design Compiler and PrimeTime.

Netlist regression was not run for this report because the SAED32
Verilog models and PDK are not installed here. The retained netlist is
also the DC output, while PrimeTime applies its ECO changes only inside
the timing and power session, so final netlist regression needs an
exported ECO-applied netlist.

== Directed testcases
#align(center)[#table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, left, left, left),
    table.header([ID], [Testcase], [Goal], [Expected result],),
    table.hline(),
    [B01], [Elementwise addition of two length-eight arrays, both
    `[0,1,2,3,4,5,6,7]`\; eight threads], [Both cores, lane and block
    indexing, constants, address arithmetic, loads, stores, two-block
    completion.], [Addresses 16 through 23 contain
    `[0,2,4,6,8,10,12,14]`.],
    [B02], [Multiply `[[1,2],[3,4]]` by `[[1,2],[3,4]]`\; four
    threads], [One full core, row and column indexing, integer division,
    multiply/accumulate, comparison, a convergent loop branch, memory
    traffic.], [Addresses 8 through 11 contain `[7,10,15,22]`.],
  )]

Running a workload through cocotb, the Verilog testbench, and gate-level
simulation does not make three independent testcases.

== Constrained-random testcases
Each family runs 100 generated instances with the listed deterministic
seed.

#align(center)[#table(
    columns: (auto, 1.1fr, 1.4fr),
    align: (left, left, left),
    table.header([ID / seed], [Stimulus and constraints], [Goal and
      expected result],),
    table.hline(),
    [R01 / 1001], [Eight-element matadd with independent random
    bytes], [Both cores and modulo-256 addition; every output equals
    `(A[i]+B[i]) & 255`.],
    [R02 / 1002], [Four-element matadd, one complete block, random
    bytes], [One busy core, no unintended writes from the idle core;
    exactly four correct outputs.],
    [R03 / 1003], [Length-12 or length-16 matadd; nonoverlapping buffers
    within 256 bytes], [Block reuse after core reset, correct block IDs;
    every element written to its assigned output.],
    [R04 / 1004], [Random 2×2 matmul with operands from 0 through
    7], [Convergent loop control, multiply/accumulate without overflow;
    outputs match integer matrix multiplication.],
    [R05 / 1005], [Random full-byte 2×2 matmul], [Truncated products and
    accumulations; outputs equal the low eight bits of each mathematical
    dot product.],
    [R06 / 1006], [Random bounded straight-line ADD/SUB/MUL/CONST
    programs; writable registers only], [Operand selection,
    dependencies, destination writeback; stored signatures match the
    instruction reference.],
    [R07 / 1007], [Random DIV operands with divisors from 1 through
    255], [Unsigned quotients; stored signatures equal
    `((a // b) + a) & 255`.],
    [R08 / 1008], [Random loads and stores to legal, nonconflicting
    lane-local scratch locations], [Address and data routing,
    read-after-write behavior; final memory matches the reference.],
    [R09 / 1009], [Random terminating CMP/BR programs with identical
    branch decisions across active lanes], [Taken and untaken convergent
    branches; executed control flow and output signatures match the
    specified NZP semantics.],
    [R10 / 1010], [Random finite program and data response delays of 1
    through 8 cycles], [Backpressure and completion despite channel
    skew; outputs stay bit exact and no requests are lost.],
  )]

== Corner-case testcases
#align(center)[#table(
    columns: (auto, 1.2fr, 1.4fr),
    align: (left, left, left),
    table.header([ID], [Testcase], [Goal and expected result],),
    table.hline(),
    [C01], [One active thread and partial blocks with 3, 5, and 7 total
    threads], [Active-lane masking and partial-block PC selection; only
    active threads produce outputs and the kernel terminates.],
    [C02], [Zero-thread launch after valid reset and
    configuration], [Empty-workload handling; completion without a
    data-memory transaction.],
    [C03], [More blocks than cores, including a partial last
    block], [Redispatch, block metadata, and reset between blocks; every
    requested thread runs once and guard locations stay unchanged.],
    [C04], [ADD/SUB boundary values: `0`, `1`, `127`, `128`, and
    `255`], [Eight-bit wraparound; examples include `255+1 -> 0` and
    `0-1 -> 255`.],
    [C05], [MUL zero, one, and maximum-byte combinations], [Product
    truncation; examples include `255*255 -> 1` and `255*0 -> 0`.],
    [C06], [DIV boundaries: `0/1`, `255/1`, `255/255`, and
    `1/255`], [Quotients `0`, `255`, `1`, and `0`. Division by zero is
    excluded until its contract is defined.],
    [C07], [Attempt writes to R13, R14, and R15, then use those
    registers in output signatures], [Read-only metadata protection;
    block ID, block size, and thread ID remain correct.],
    [C08], [Legal loads and stores at addresses 0 and 255, with sentinel
    locations elsewhere], [Address boundaries; only intended
    destinations change.],
    [C09], [Equal, less-than, and greater-than CMP operands followed
    immediately by corresponding branches], [NZP ordering, comparison
    sizing and signedness, and the CMP-to-branch dependency; the
    expected branch is taken.],
    [C10], [Reset during a stalled load or store, then a fresh legal
    launch], [Recovery of dispatcher, controllers, and lanes; no stale
    response contaminates the restarted kernel.],
  )]

== Results
#align(center)[#table(
    columns: (auto, 1fr),
    align: (left, left),
    table.header([Check], [Result],),
    table.hline(),
    [Directed B01/B02, RTL], [PASS, 178 / 491 cycles],
    [Default corpus, RTL], [1,039 / 1,039],
    [Directed B01/B02, gate level (recorded)], [PASS, 178 / 491 cycles],
    [Netlist regression], [Not run, models absent],
  )]

The default corpus is 1,000 constrained-random instances plus 39 corner
instances. Report-preparation runs used Icarus Verilog 13.0; the
manifest and summary are in `results/verification/rtl_manifest.json` and
`results/verification/rtl_summary.txt`. Twenty software-only checks of
the reference model and generators also pass.

The recorded gate-level results are supported by the compressed VCDs in
`results/ss/activity/`. Those VCDs and the netlist predate the two RTL
fixes, so they establish pre-fix behavior only.

= Software golden model
The cocotb tests compute expected matrix results directly in Python.
`sw/golden.py` is a separate architectural interpreter and instruction
encoder for the generated regression programs. It models eight-bit
wraparound, protected metadata registers, convergent four-lane control
flow, and race-free memory access, with a bounded instruction budget.
Comparison and flag behavior is specified independently of the RTL:
unsigned operands, with N/Z/P in bits 2/1/0. Program generation rejects
division by zero, divergent branches, invalid instructions, and
cross-thread memory races.

Generated programs write register signatures to memory, so the
external-interface testbench can check results without hierarchical
signal names. The model is not cycle accurate and does not emit a
retirement trace. Software-only tests cover arithmetic and branch
expectations, published kernel encodings, independent matrix products,
metadata protection, and rejection of nontermination and races.

#align(center)[#table(
    columns: (auto, 1fr),
    align: (left, left),
    table.header([Metric], [Definition],),
    table.hline(),
    [Functional correctness], [Exact equality for every checked output
    and sentinel location; zero mismatches.],
    [Regression completion], [All directed, random, and corner cases
    pass at RTL and gate level without timeouts or unknown checked
    outputs.],
    [Kernel cycles], [Clock edges from the launch interval until
    `done`\; compare only under the same memory model.],
    [Kernel latency], [`cycles × clock period`, using each
    implementation's own closed period.],
    [Energy estimate], [Average measured logic power times kernel
    latency.],
  )]

Host software runtime is not a hardware performance metric. Cycle counts
come from simulation.

= Synthesis
== Libraries and constraints
Synthesis targets the worst-case SS corner with
`saed32rvt_ss0p75v125c.db`, `saed32lvt_ss0p75v125c.db`, and
`saed32hvt_ss0p75v125c.db`. The selected run maps standard cells to LVT
and HVT only: 11,563 LVT and 3,835 HVT cells, with RVT available for
linking and constraint references. The design has 211 clock gates.

`syn/constraints.sdc` defines an ideal clock with 0.1 ns uncertainty and
transition, input and output delays of 20% of the period (0.58 ns at
2.90 ns), an `INVX1_RVT` input driver, and an output load of 0.005
library units. No clock tree or extracted interconnect is included.

== Script and methodology
`syn/dc_synth.tcl` runs top-down synthesis with hierarchy retained
(`compile_ultra -no_autoungroup`). It reads `build/gpu.v`, elaborates
and links `gpu`, uniquifies instances, checks the design, applies
constraints, and writes the netlist and reports. The clock-gated build
adds `-gate_clock`.

The main steps are:

+ Map critical logic to the permitted LVT and HVT libraries.
+ Raise setup uncertainty by 3% of the target period during initial
  optimization, then restore the stated 0.1 ns before final reporting.
+ Insert clock gates for enabled register banks. DC's default gating
  can choose RVT cells even when ordinary RVT mapping is disabled, so
  the script swaps compatible gating cells to LVT after compilation.
+ Apply incremental setup recovery, hold fixing, and driver upsizing or
  buffering, then recheck all three, since a hold or capacitance fix can
  break a near-critical setup path.
+ Write area, timing, QoR, design-rule, power, and Vt-mix reports,
  followed by the mapped netlist, SDC, SDF, SPEF, and RTL-to-gate name
  mapping.

DC power reports can use default activity when no SAIF is supplied, so
they are not the source of the workload power in Section 6. PrimeTime
reads the gate-level VCDs instead.

== Maximum frequency
`syn/sweep.sh` searches candidate periods with several independent DC
jobs per round. A candidate passes only with nonnegative worst setup
slack, zero total negative slack, zero hold violations, and zero
design-rule-violating nets. The saved clock-gated LVT+HVT sweep is in
`results/ss/runs/sweep_ss_lh_cg.csv`:

#align(center)[#table(
    columns: (auto, auto, auto, auto, auto, auto, auto, auto),
    align: (right, right, right, right, right, right, right, left),
    table.header([Period (ns)], [Frequency (MHz)], [Setup WNS
      (ns)], [TNS (ns)], [Hold violations], [DRC nets], [Cell area
      (µm²)], [Status],),
    table.hline(),
    [2.85], [350.9], [+0.01], [0], [0], [1], [46,274.794], [FAIL],
    [2.90], [344.8], [+0.03], [0], [0], [0], [46,553.590], [PASS],
    [2.95], [339.0], [+0.02], [0], [0], [0], [47,228.342], [PASS],
    [3.05], [327.9], [+0.01], [0], [0], [0], [47,983.150], [PASS],
    [3.10], [322.6], [+0.05], [0], [0], [0], [47,822.531], [PASS],
    [3.20], [312.5], [0.00], [0], [0], [0], [46,829.336], [PASS],
    [3.55], [281.7], [0.00], [0], [0], [0], [46,979.790], [PASS],
    [3.90], [256.4], [+0.01], [0], [0], [0], [46,838.486], [PASS],
    [5.25], [190.5], [+0.04], [0], [0], [0], [45,705.512], [PASS],
    [6.65], [150.4], [+0.16], [0], [0], [0], [44,497.311], [PASS],
    [8.00], [125.0], [+0.16], [0], [0], [0], [42,808.016], [PASS],
  )]

The shortest passing period is 2.90 ns; 2.85 ns retains one design-rule
net. Area is nonmonotonic across nearby constraints, so 2.90 ns is the
best demonstrated DC point, not a global optimum. Frequency is
`1000 / period_ns` MHz.

The sweep does not include PrimeTime's minimum-pulse-width check, which
Section 5.5 covers. The shortest saved period whose ideal half-period
minus 0.1 ns uncertainty exceeds the 1.42 ns library minimum is 3.05 ns
(327.9 MHz), but that point has not been through PrimeTime ECO and
power.

== Frequency, area, and critical path
#align(center)[#table(
    columns: (1fr, auto, auto),
    align: (left, right, right),
    table.header([Quantity], [DC before PT ECO], [PrimeTime after ECO],),
    table.hline(),
    [Clock period], [2.90 ns], [2.90 ns],
    [Frequency], [344.8 MHz], [344.8 MHz],
    [Standard-cell area], [46,553.590 µm²], [46,632.883 µm²],
    [Leaf cells], [15,398], [15,412],
    [Setup slack], [+0.03 ns], [+0.034710 ns],
    [Hold status], [Zero violations], [Worst slack +0.000011 ns],
    [Design-rule status], [Zero violating nets], [Zero max-capacitance
    nets; 877 pulse-width violations],
    [Clock gates], [211], [211],
    [Vt mix], [11,563 LVT / 3,835 HVT / 0 RVT], [Not re-reported],
  )]

The ECO adds 79.293 µm² and 14 leaf cells. PrimeTime reports 0.046633
mm² of cell area; DC's separate interconnect-area estimate is not added
to it. Sources are `reports/area.rpt`, `reports/qor.rpt`,
`reports/timing.rpt`, `pt_reports/area.rpt`, and
`pt_reports/summary.rpt` under `results/ss/runs/best_ss_lh_cg/`.

The DC critical path runs from `lsu_write_valid_reg[2]` in core 0 to
`data_memory_controller/mem_write_data_reg[22]`: 2.72 ns arrival against
2.75 ns required, for +0.03 ns slack. Next are other write-data and
write-address bits from the same source at +0.04 ns, plus an arithmetic
path from `rt_reg[4]` to `alu_out_reg_reg[0]`. Both memory-control and
arithmetic logic constrain the design, with the LSU write path dominant.
The retained PrimeTime setup/hold path reports are filtered to negative
slack and show no details when timing passes.

== Timing closure limitation
Minimum pulse width remains open. PrimeTime reports 877 register clock
pins with `sequential_clock_pulse_width` violations: each high-phase
check requires 1.42 ns and measures 1.35 ns, for -0.07 ns. The 2.90 ns
clock has a 1.45 ns high phase; subtracting 0.1 ns of clock uncertainty
leaves 1.35 ns. The nominal phase clears the library minimum by 0.03 ns,
but the guard band makes the checked value negative. At 3.05 ns the
checked value would be 1.425 ns. That point exists in the DC sweep but
has not been validated in PrimeTime or used for power. Details are in
`results/ss/runs/best_ss_lh_cg/pt_reports/violators.rpt`.

The 2.90 ns result is setup, hold, and design-rule-net clean but not
pulse-width clean. Setup and hold slack leave little nominal margin, and
all timing uses pre-layout wire-load estimates and an ideal clock, so it
is not post-route signoff.

= PrimeTime power
== Script and methodology
`ptpx/pt_power.tcl` reads a run's netlist and SDC, links the
standard-cell libraries, and applies `out/eco_changes.tcl` when present.
It updates timing and writes timing, setup/hold, constraint, and clock
reports, and it calculates cell area by summing leaf-cell library areas.
It enables averaged power analysis, reads the workload VCD under
`tb_gpu/dut`, updates power, and writes switching-activity, total-power,
and hierarchical-power reports. Dynamic power is internal cell power
plus net-switching power; leakage is reported separately.

By default PrimeTime uses per-hierarchy wire-load estimates instead of
DC's SPEF. The reported power is therefore wire-load-based, not
extracted-interconnect analysis.

== Workloads and vectors
The activity vectors execute B01 and B02 with the same inputs and 2.90
ns period used in verification. Matadd activates both cores; matmul uses
one. This samples two relevant execution patterns, though the fixed
small datasets are not a broad workload distribution. The traces are
`results/ss/activity/gpu_gls_ss_2p90.vcd.gz` for matmul and
`results/ss/activity/gpu_gls_matadd_ss_2p90.vcd.gz` for matadd.

#block(breakable: false)[#align(center)[#table(
    columns: (auto, auto, auto, auto),
    align: (left, right, right, right),
    table.header([Workload], [Averaging
      window], [Launch-to-done], [Cycles],),
    table.hline(),
    [matmul], [0 to 1,437.675 ns], [1,423.90 ns], [491],
    [matadd], [0 to 529.975 ns], [516.20 ns], [178],
  )]]

Both VCDs use a 1 ps timescale and end at timestamps matching the
simulation windows in the PrimeTime logs. The script reads the full
trace with no workload-only restriction, so reset and setup activity
enter the average. Repeated launches and a longer steady-state window
are still needed to show that the averages are stable.

The switching reports annotate 16,041 of 16,042 nets (99.99%) and all
211 clock-gate outputs. The exception is
`program_memory_controller/mem_write_ready[0]`. The power logs still
contain `PWR-264` VCD identifier and vector-width warnings (6,789 for
matmul, 5,143 for matadd), plus a startup `PT-063` Library Compiler-path
error and 167 `NED-079` ECO annotation warnings. The reports were
produced, but these diagnostics remain unresolved; 99.99% annotation is
coverage, not proof that every waveform value was read correctly.

== Average power
#align(center)[#table(
    columns: (1fr, auto, auto),
    align: (left, right, right),
    table.header([Component (mW)], [matmul], [matadd],),
    table.hline(),
    [Dynamic, internal plus switching], [1.032396], [1.204701],
    [Leakage], [4.224331], [4.272786],
    [Total average logic power], [5.256727], [5.477488],
    [Leakage fraction], [80.36%], [78.01%],
  )]

The reports round the totals to 5.257 mW and 5.477 mW and come from
`results/ss/runs/best_ss_lh_cg/pt_reports/power.rpt` and
`results/ss/runs/best_ss_lh_cg/pt_reports_matadd/power.rpt`. There is no
memory-macro power because the measured DUT contains no macros, and peak
power was not measured.

The hierarchical matmul report assigns 1.66 mW to core 0, 1.68 mW to
idle core 1, 0.828 mW to the data-memory controller, 0.132 mW to the
dispatcher, 0.077 mW to the program-memory controller, and 0.011 mW to
the device control register. The remaining roughly 0.87 mW is top-level
relay logic and other blocks. The idle core costs slightly more than the
busy core because it received more LVT cells, and clock gating reduces
switching while leaving most leakage. The power-group report puts the
clock network at about 1.041 mW for matmul and 1.140 mW for matadd; that
is an alternative breakdown, not additional power to add.

== Latency and energy
For cycle count `C`, period `T` in ns, and average power `P` in W:

```text
latency_ns = C × T
estimated_energy_nJ = P × latency_ns
```

#align(center)[#table(
    columns: (1fr, auto, auto),
    align: (left, right, right),
    table.header([Metric], [matmul], [matadd],),
    table.hline(),
    [Launch-to-done latency], [1,423.90 ns], [516.20 ns],
    [Energy estimate, full-trace average power], [7.485 nJ], [2.827 nJ],
  )]

These values multiply a full-trace average by a shorter kernel interval,
so they are first-order estimates rather than integrations over the
active window. Exact energy needs a delimited power window or
time-resolved integration. No external-memory energy is included.

= Validation
== Design documentation
The original project documentation describes the same eight-bit data
path, 16-bit instructions, lane-local metadata registers, multicycle
schedule, and two matrix kernels used here. Its expected matadd output
and 2×2 matrix product agree with the software calculations and with the
RTL results. Top-level inspection confirms the two-core, four-lane
configuration. That documentation also discusses an unfinished cache
that is not in the current RTL; the RTL defines the implementation
boundary.

The software calculations independently check final kernel outputs, and
fresh converted-RTL simulations reproduce them and the recorded 178 and
491 cycles. The regression suite found the two baseline defects
described in Section 2.2 rather than being tuned to the RTL, which
supports its value as an independent check. It does not validate the
full instruction set beyond the exercised programs or all legal launch
conditions.

== Internal consistency
- `1000 / 2.90 = 344.8276` MHz, which rounds to 344.8 MHz.
- `46,632.883 / 1,000,000 = 0.046632883` mm².
- Dynamic plus leakage equals total power in both PrimeTime summaries to
  the displayed precision.
- The saved VCD endpoints (1,437.675 ns and 529.975 ns) match the
  averaging windows in the PrimeTime logs.
- The DC and PrimeTime ECO implementations differ by 79.293 µm² and 14
  leaf cells, explained by the ECO rather than a unit conversion.
- Both tools report no setup or hold violations at 2.90 ns. PrimeTime
  adds 877 pulse-width violations, which the DC QoR report does not
  check.

== External comparison
No published SAED32 implementation of this design exists for a direct
comparison, and none is established here. A comparison against a
different GPU, technology node, voltage, memory boundary, or
placed-and-routed implementation would need those differences stated
explicitly. The reported PPA is therefore validated against the design
documentation and internal consistency, not against an external
baseline.

= Optimization implementation plan
== A1: bypass WAIT for non-memory instructions
The baseline always transitions from REQUEST to WAIT. A1 makes a
non-memory instruction go directly from REQUEST to EXECUTE while LDR and
STR keep the wait protocol. Decoded memory enables are already available
at REQUEST, and operand capture and UPDATE writeback stay unchanged.

Implementation should first compare baseline and A1 state traces for an
arithmetic instruction, a load, and a store. Non-memory instructions
should lose one cycle without a memory transaction, memory instructions
must still wait for every LSU response, and RET must assert completion
only after its architectural effects finish.

Matmul executes 41 instructions per block, five of them loads or stores,
so the estimate is 36 saved cycles: 491 to about 455. Matadd has 13
instructions and three memory operations, giving 10 saved cycles: 178 to
about 168. Both assume unchanged memory timing and no new inter-core
arbitration effects.

== A2: merge DECODE and REQUEST
A2 makes decode information available before operand capture at a merged
decode/request edge. The decoder and register-file reads are
synchronous, so renaming or skipping a state alone would expose stale
addresses or controls, since nonblocking updates appear only after the
edge.

The plan is to separate combinational instruction decoding from controls
held during execution, capture register operands and stable controls at
the merged edge, and keep the LSU's REQUESTING step so addresses and
data drive only after the new operands are valid. The change touches
`rtl/decoder.sv`, `rtl/registers.sv`, `rtl/lsu.sv`, `rtl/fetcher.sv`,
`rtl/scheduler.sv`, and their connections in `rtl/core.sv`. Arithmetic
dependencies, immediate changes, load and store sequences, and
CMP-then-branch need testing before measuring savings.

The estimate is one saved cycle per dynamic instruction: 41 for matmul
and 13 for matadd. The added decode-to-operand and control logic can
lengthen the critical path, so the estimate alone is not an acceptance
criterion.

== A3: fuse EXECUTE and UPDATE
A3 evaluates a combined execution and writeback stage. EXECUTE registers
`alu_out` and next-PC information while UPDATE consumes those registers,
so merging the state encodings without datapath changes would write the
previous result. The design must expose the current instruction's
combinational arithmetic result and branch decision at the writeback
edge, or add an equivalent bypass. CMP flag writes, branch evaluation,
load-result selection, RET handling, and LSU cleanup must all observe
the correct instruction, which requires changes in `rtl/alu.sv`,
`rtl/pc.sv`, `rtl/registers.sv`, `rtl/scheduler.sv`, and `rtl/lsu.sv`.

The main timing risk is the combinational divider and the longer path
into register-file writeback. With only +0.034710 ns of setup margin at
2.90 ns, A3 must be resynthesized at its own closed period and kept only
if latency or energy improves under the project's area and power
constraints.

== Order, estimates, and acceptance
Close the two baseline defects and complete the SS-corner flow first,
then freeze that corrected baseline. Evaluate A1 alone, A2 alone, A1+A2,
A3 alone, and only then any combination their results justify. This
isolates failure causes and keeps synthesis-flow improvements out of RTL
cycle savings.

#align(center)[#table(
    columns: (1fr, auto, auto),
    align: (left, right, right),
    table.header([Estimated change at 2.90 ns], [matmul], [matadd],),
    table.hline(),
    [A1 cycle reduction], [36 (7.33%)], [10 (5.62%)],
    [A2 cycle reduction], [41 (8.35%)], [13 (7.30%)],
    [A1+A2 cycles], [414], [155],
    [A1+A2 cycle reduction], [15.68%], [12.92%],
    [A1+A2 latency], [1,200.60 ns], [449.50 ns],
  )]

These are hypotheses, not measured results. At unchanged average power
the energy estimates would be about 6.31 nJ for matmul and 2.46 nJ for
matadd, but power and period must be remeasured. For A1+A2 to beat
baseline latency, its period must stay below about 3.439 ns for matmul
and 3.330 ns for matadd under the current cycle estimates. Those
thresholds are baseline latency divided by optimized cycles and will
change after the fixes and resynthesis.

An accepted variant must pass all functional regressions, meet setup,
hold, and design-rule constraints, and improve measured latency or
energy without silently changing workload or memory assumptions. ISA,
output data, and convergent control flow must stay unchanged. FETCH
latency remains a large cost that A1 through A3 do not address.

= Optimization verification plan
== Regression and architectural checks
For each variant, run the directed cases, all 1,039 default instances,
and the netlist run on the corrected, ECO-applied netlist. Record
testcase ID, seed, memory timing, expected and actual output signatures,
cycle count, and pass/fail status, and make failures return a failing
process status as well as a diagnostic.

Add checks that disabled lanes write nothing, outstanding requests hold
address and data until acknowledged, the scheduler does not commit a
load before its result is valid, and `done` follows all requested
blocks. The monitor must respect the level-held valid/ready protocol
rather than treating every high-valid cycle as a new transaction.

For control-stage changes, compare architectural retirement events or
committed results, not raw internal signals. A faster implementation
will change state occupancy and request timing, so compare transaction
content and per-thread ordering without demanding identical arbitration
order for independent accesses.

== Golden-model updates
A1 through A3 preserve instruction semantics, so the functional model
should not change; any optimization that alters expected numerical
outputs is rejected. Timing assumptions and the performance monitor must
count the new stages and waits, and a later cycle-accurate model must
state which hardware version it describes.

If testing reveals another baseline defect, define the intended
behavior, add a failing regression, and document the fix before
comparing optimized RTL. The two defects found so far follow that
pattern: the partial-block PC fix and the CMP flag fix are covered by
C01, C03, C09, and R09, and full-block workloads and the matmul `BRn`
loop behave as before. Fresh synthesis, ECO, VCD regeneration, and power
measurement must follow any further RTL change.

== Memory latency and waveforms
Extend the testbench to sweep response latency over 1, 2, 4, and 8
cycles with independent finite channel delays. Evaluate ideal concurrent
channels separately from a serialized single-port memory and any banked
model; equal capacity does not imply equal bandwidth. For a tentative 6
ns cycle and 3 ns access SRAM at a 2.90 ns logic clock, minimum access
spacing is three cycles and read availability needs at least two
logic-clock intervals before wrapper delays. Exact handshake timing must
be defined at clock edges and checked against the macro specification.

Inspect waveforms around non-memory WAIT bypass, the merged
decode/request edge, load completion, CMP and branch dependencies, reset
recovery, and final RET.

== PPA and energy re-evaluation
Repeat the SS period search for every accepted variant with the same
I/O, load, and Vt assumptions. Export the exact post-ECO netlist and
constraints, run gate-level regression on it, regenerate period-matched
activity, resolve annotation warnings, and measure both kernels in
PrimeTime. For average power, run enough launches that extending the
window stabilizes the result, choosing and reporting the convergence
criterion in advance. Report reset-inclusive and kernel-only windows
separately if both matter, and include memory in PPA only when it is
part of the evaluated design.

For each workload, record cycles, closed period, latency, area,
internal, switching, and leakage power, and consistently delimited
energy.

= Reproduction README
== Tools and versions
#align(center)[#table(
    columns: (auto, 1fr),
    align: (left, left),
    table.header([Component], [Requirement],),
    table.hline(),
    [Icarus Verilog and `vvp`], [Required for Verilog simulation;
    report-preparation runs used 13.0.],
    [`sv2v`], [Regenerates `build/gpu.v` from `rtl/`\;
    report-preparation runs used 0.0.13.],
    [Python], [The regression runner needs 3.9+ and only the standard
    library; report-preparation runs used `/usr/bin/python3` 3.9.6.],
    [cocotb], [Needed only for `make test_*`\; the compatibility update
    was tested with Python 3.13, cocotb 2.0.1, and Icarus 12.0.],
    [Synopsys Design Compiler], [Recorded version W-2024.09-SP5-4; needs
    a license and the SAED32 `.db` files.],
    [Synopsys PrimeTime with power analysis], [Recorded version
    V-2023.12-SP5-4; needs a license, libraries, and a configured tool
    environment.],
    [SAED32 Verilog models], [Needed for gate-level simulation; set
    `SAED` to the directory containing `stdcell_*/verilog/`.],
  )]

The Tcl scripts hard-code `/usr/local/synopsys/pdk/SAED32_EDK/lib`, the
synthesis-host PDK location; update it for another machine. `SAED`
affects only the gate-level Makefile, not the Tcl library selections.
Use the course-provided PDK and tools.

To recreate the cocotb environment in isolation:

```bash
uv venv --python 3.13 .venv
uv pip install --python .venv/bin/python 'cocotb==2.0.1'
source .venv/bin/activate
```

Start the examples in the repository root:

```bash
export ROOT="$PWD"
export REPRO="$ROOT/build/report_reproduction"
mkdir -p "$REPRO"
```

== RTL compilation and simulation
Regenerate the converted RTL and run the two kernels:

```bash
mkdir -p build
timeout 120 make compile

iverilog -g2012 -s tb_gpu -DCLK_PERIOD=2.9 \
  -o "$REPRO/matmul.vvp" build/gpu.v sim/legacy/tb_gpu.v
timeout 60 vvp "$REPRO/matmul.vvp" > "$REPRO/rtl_matmul.log" 2>&1
grep -qx PASS "$REPRO/rtl_matmul.log"

iverilog -g2012 -s tb_gpu -DCLK_PERIOD=2.9 -DMATADD \
  -o "$REPRO/matadd.vvp" build/gpu.v sim/legacy/tb_gpu.v
timeout 60 vvp "$REPRO/matadd.vvp" > "$REPRO/rtl_matadd.log" 2>&1
grep -qx PASS "$REPRO/rtl_matadd.log"
```

Expect `PASS` with 491 cycles for matmul and 178 for matadd. Period
affects timestamps, not cycle counts. `+vcd +vcdfile=<path>` keeps a
waveform.

== Hardware and software verification
With cocotb configured:

```bash
timeout 300 make test_matadd > "$REPRO/cocotb_matadd.log" 2>&1
timeout 300 make test_matmul > "$REPRO/cocotb_matmul.log" 2>&1
```

Run the software checks, generate the vectors, and run the full RTL
corpus:

```bash
make verification_unit PYTHON=/usr/bin/python3
/usr/bin/python3 -m sim.run --mode generate --out "$REPRO/verification-vectors"
/usr/bin/python3 -m sim.run --mode rtl --rtl build/gpu.v \
  --period 2.9 --out "$REPRO/verification-rtl"
```

Expect 1,039 of 1,039 passing. Use a new `--out` directory per run.
Netlist mode needs an explicit netlist plus all mapped cell models:

```bash
/usr/bin/python3 -m sim.run --mode netlist \
  --netlist results/ss/runs/best_ss_lh_cg/out/gpu_netlist.v \
  --cell-model "$SAED/stdcell_lvt/verilog/saed32nm_lvt.v" \
  --cell-model "$SAED/stdcell_hvt/verilog/saed32nm_hvt.v" \
  --period 2.9 --out "$REPRO/verification-netlist"
```

That command is not reported as executed because the models are absent
here.

== Synthesis
On the licensed synthesis host, run a fresh SS clock-gated candidate:

```bash
cd "$ROOT"
timeout 7200 dc_shell \
  -x 'set CLK_PERIOD 2.9; set CORNER ss0p75v125c; \
      set USE_HVT 1; set USE_LVT 1; set NO_RVT 1; set CLOCK_GATING 1; \
      set RUN_DIR build/reproduce_ss_lh_cg_2.90' \
  -f syn/dc_synth.tcl > "$REPRO/dc.log" 2>&1
```

Inspect the log for tool errors and the generated `qor.rpt`, timing
reports, and `violators.rpt`\; a clean exit is not proof of closure. DC
does not check minimum pulse width, so run PrimeTime before declaring
closure.

To reproduce the sweep:

```bash
cd "$ROOT"
RUN_ROOT="$REPRO/sweep_ss" CORNER=ss0p75v125c CG=1 JOBS=3 \
  timeout 21600 bash syn/sweep.sh lh 2.85 3.10 0.05 \
  > "$REPRO/sweep_ss.log" 2>&1
```

`JOBS=3` uses up to three DC licenses; use `JOBS=1` otherwise. `CG=0` is
ungated; pass `CG=1` for the recorded baseline.

== Gate-level simulation
Set `SAED` to the PDK library directory. The Makefile preprocesses the
cell models through `sim/saed_xfix.awk`:

```bash
cd "$ROOT"
export SAED=/usr/local/synopsys/pdk/SAED32_EDK/lib
timeout 300 make gls NETLIST=results/ss/runs/best_ss_lh_cg/out/gpu_netlist.v \
  CLK_PERIOD=2.9 SAED="$SAED" > "$REPRO/gls_matmul.log" 2>&1
grep -qx PASS "$REPRO/gls_matmul.log"

timeout 300 make gls NETLIST=results/ss/runs/best_ss_lh_cg/out/gpu_netlist.v \
  CLK_PERIOD=2.9 MATADD=1 SAED="$SAED" > "$REPRO/gls_matadd.log" 2>&1
grep -qx PASS "$REPRO/gls_matadd.log"
```

These simulate the saved DC netlist and should reproduce 491 and 178
cycles. `make gls` does not apply PrimeTime's ECO list, so post-ECO
verification needs a new ECO-applied, exported netlist, with activity
regenerated afterwards.

== PrimeTime
To replay the recorded power analysis, decompress the activity and write
reports into a new copy of the run:

```bash
cd "$ROOT"
gzip -dc results/ss/activity/gpu_gls_ss_2p90.vcd.gz > "$REPRO/matmul_saved.vcd"
gzip -dc results/ss/activity/gpu_gls_matadd_ss_2p90.vcd.gz > "$REPRO/matadd_saved.vcd"
cp -R results/ss/runs/best_ss_lh_cg "$REPRO/ss_replay"

timeout 1800 pt_shell \
  -x "set RUN_DIR {$REPRO/ss_replay}; set VCD {$REPRO/matmul_saved.vcd}; \
      set CORNER ss0p75v125c; set RPT_NAME pt_reports_reproduced_matmul; \
      set USE_ECO 1; set USE_SPEF 0" \
  -f ptpx/pt_power.tcl > "$REPRO/pt_matmul.log" 2>&1

timeout 1800 pt_shell \
  -x "set RUN_DIR {$REPRO/ss_replay}; set VCD {$REPRO/matadd_saved.vcd}; \
      set CORNER ss0p75v125c; set RPT_NAME pt_reports_reproduced_matadd; \
      set USE_ECO 1; set USE_SPEF 0" \
  -f ptpx/pt_power.tcl > "$REPRO/pt_matadd.log" 2>&1
```

Reproduction should show the same 5.2567 mW and 5.4775 mW totals, the
877 pulse-width violations, and the same annotation diagnostics.
Agreement does not resolve those diagnostics.

For a new candidate, generate its own ECO list instead of reusing saved
cell names:

```bash
cd "$ROOT"
timeout 1800 pt_shell \
  -x 'set RUN_DIR build/reproduce_ss_lh_cg_2.90; set CORNER ss0p75v125c' \
  -f ptpx/pt_eco.tcl > "$REPRO/pt_eco_new.log" 2>&1
```

Then export and verify the modified netlist, regenerate both VCDs at the
selected period, and run `pt_power.tcl` with the new `RUN_DIR` and each
VCD. Inspect warnings, nonannotated nets, setup and hold, residual DRC,
library corner, and measurement windows before accepting results.
