"""Executable specifications for R01..R10 and C01..C10 from the midterm report,
plus the A1 (WAIT bypass) suite A1_01..A1_10 in generate_a1_cases()."""

from dataclasses import dataclass, field
import hashlib
import random
from typing import Dict, List, Optional

from sw.golden import encode, execute


class Program:
    """Tiny label-aware assembler for generated convergent programs."""

    def __init__(self):
        self.words = []
        self.labels = {}
        self.fixups = []

    def emit(self, op, *args, **kwargs):
        self.words.append(encode(op, *args, **kwargs))

    def label(self, name):
        if name in self.labels:
            raise ValueError("duplicate label: " + name)
        self.labels[name] = len(self.words)

    def branch(self, mask, label):
        self.fixups.append((len(self.words), mask, label))
        self.words.append(0)

    def finish(self):
        result = list(self.words)
        for pc, mask, name in self.fixups:
            if name not in self.labels:
                raise ValueError("undefined label: " + name)
            result[pc] = encode("BR", mask=mask, immediate=self.labels[name])
        if not 1 <= len(result) <= 256:
            raise ValueError("program does not fit instruction memory")
        return result


@dataclass
class Case:
    name: str
    family: str
    goal: str
    program: List[int]
    memory: List[int]
    threads: int
    expected: List[int]
    writes: Dict[int, int]
    seed: Optional[int] = None
    delay_min: int = 1
    delay_max: int = 1
    reset_kind: int = 0  # 1: abort first pending read; 2: abort first pending write
    delay_seed: int = 1
    # A1 performance expectations from sw/golden.py (per block; no functional effect)
    retired: List[int] = field(default_factory=list)
    memory_ops: List[int] = field(default_factory=list)


def make_case(name, family, goal, program, memory, threads=4, *, seed=None,
              delay_min=1, delay_max=1, reset_kind=0):
    if not 1 <= delay_min <= delay_max <= 8:
        raise ValueError("response delays must be between one and eight cycles")
    reference = execute(program, memory, threads)
    # Separate from the family data RNG: trials need different handshake schedules.
    key = (name + ":" + str(seed or 0)).encode("ascii")
    delay_seed = int.from_bytes(hashlib.sha256(key).digest()[:4], "big") or 1
    return Case(name, family, goal, program, list(memory), threads,
                reference.memory, reference.writes, seed, delay_min, delay_max,
                reset_kind, delay_seed, reference.retired, reference.memory_ops)


def initial_memory(rng=None):
    return ([rng.randrange(256) for _ in range(256)] if rng is not None else
            [(37 * i + 91) & 255 for i in range(256)])


def index(p):
    p.emit("MUL", 0, 13, 14)
    p.emit("ADD", 0, 0, 15)


def store_signature(p, register, base=200):
    p.emit("CONST", 11, immediate=base)
    p.emit("ADD", 11, 11, 0)
    p.emit("STR", rs=11, rt=register)


def matadd_program(n):
    p = Program()
    index(p)
    for reg, value in [(1, 0), (2, n), (3, 2*n)]:
        p.emit("CONST", reg, immediate=value)
    p.emit("ADD", 4, 1, 0)
    p.emit("LDR", 4, 4)
    p.emit("ADD", 5, 2, 0)
    p.emit("LDR", 5, 5)
    p.emit("ADD", 6, 4, 5)
    p.emit("ADD", 7, 3, 0)
    p.emit("STR", rs=7, rt=6)
    p.emit("RET")
    return p.finish()


def matmul_program():
    p = Program()
    index(p)
    for reg, value in [(1, 1), (2, 2), (3, 0), (4, 4), (5, 8)]:
        p.emit("CONST", reg, immediate=value)
    p.emit("DIV", 6, 0, 2)
    p.emit("MUL", 7, 6, 2)
    p.emit("SUB", 7, 0, 7)
    p.emit("CONST", 8, immediate=0)
    p.emit("CONST", 9, immediate=0)
    p.label("loop")
    for out, a, b in [(10, 6, 9), (11, 9, 7)]:
        p.emit("MUL", out, a, 2)
        p.emit("ADD", out, out, b)
        p.emit("ADD", out, out, 3 if out == 10 else 4)
        p.emit("LDR", out, out)
    p.emit("MUL", 12, 10, 11)
    p.emit("ADD", 8, 8, 12)
    p.emit("ADD", 9, 9, 1)
    p.emit("CMP", rs=9, rt=2)
    p.branch(4, "loop")
    p.emit("ADD", 9, 5, 0)
    p.emit("STR", rs=9, rt=8)
    p.emit("RET")
    return p.finish()


def arithmetic_program(op, a, b):
    p = Program()
    index(p)
    p.emit("CONST", 1, immediate=a)
    p.emit("CONST", 2, immediate=b)
    p.emit(op, 3, 1, 2)
    store_signature(p, 3)
    p.emit("RET")
    return p.finish()


def branch_program(a, b, mask):
    p = Program()
    index(p)
    p.emit("CONST", 1, immediate=a)
    p.emit("CONST", 2, immediate=b)
    p.emit("CMP", rs=1, rt=2)
    p.branch(mask, "taken")
    p.emit("CONST", 3, immediate=17)
    store_signature(p, 3)
    p.emit("RET")
    p.label("taken")
    p.emit("CONST", 3, immediate=231)
    store_signature(p, 3)
    p.emit("RET")
    return p.finish()


def random_program(family, rng, memory):
    if family in {"R01", "R02", "R03", "R10"}:
        n = {"R01": 8, "R02": 4, "R03": rng.choice([12, 16]), "R10": 8}[family]
        for i in range(2*n):
            memory[i] = rng.randrange(256)
        return matadd_program(n), n
    if family in {"R04", "R05"}:
        limit = 8 if family == "R04" else 256
        memory[:8] = [rng.randrange(limit) for _ in range(8)]
        return matmul_program(), 4
    if family == "R09":
        a, b = rng.randrange(256), rng.randrange(256)
        return branch_program(a, b, rng.randrange(1, 8)), 4
    p = Program()
    index(p)
    if family == "R06":
        for reg in range(1, 9):
            p.emit("CONST", reg, immediate=rng.randrange(256))
        for _ in range(24):
            p.emit(rng.choice(["ADD", "SUB", "MUL"]), rng.randrange(1, 9),
                   rng.randrange(1, 9), rng.randrange(1, 9))
        # Observe every generated register, not just one final arithmetic result.
        for reg in range(1, 9):
            store_signature(p, reg, 128 + 4*(reg-1))
    elif family == "R07":
        for iteration in range(8):
            p.emit("CONST", 1, immediate=rng.randrange(256))
            p.emit("CONST", 2, immediate=rng.randrange(1, 256))
            p.emit("DIV", 3, 1, 2)
            p.emit("ADD", 3, 3, 1)  # Dependent use of the quotient.
            store_signature(p, 3, 128 + 4*iteration)
    elif family == "R08":
        for iteration in range(6):
            base = 32 + 4*iteration
            p.emit("CONST", 1, immediate=base)
            p.emit("ADD", 1, 1, 0)
            p.emit("CONST", 2, immediate=rng.randrange(256))
            p.emit("ADD", 2, 2, 15)
            p.emit("STR", rs=1, rt=2)
            p.emit("LDR", 3, 1)
            store_signature(p, 3, 128 + 4*iteration)
    else:
        raise ValueError("unknown random family: " + family)
    p.emit("RET")
    return p.finish(), 4


def generate_cases(trials=100, seed_offset=0):
    """Return all families; each random family contains `trials` instances."""
    if not isinstance(trials, int) or trials < 1:
        raise ValueError("trials must be a positive integer")
    if not isinstance(seed_offset, int) or seed_offset < 0:
        raise ValueError("seed offset must be a nonnegative integer")
    cases = []
    goals = ["two-core byte addition", "one-core byte addition", "core redispatch",
             "bounded matrix multiplication", "overflowing matrix multiplication",
             "arithmetic dependencies", "nonzero unsigned division",
             "lane-local store/load forwarding", "convergent conditional branches",
             "memory backpressure and channel skew"]
    for number in range(1, 11):
        family, seed = "R%02d" % number, 1000 + number + seed_offset
        rng = random.Random(seed)
        for trial in range(trials):
            memory = initial_memory(rng)
            program, threads = random_program(family, rng, memory)
            cases.append(make_case("%s_%04d" % (family, trial), family,
                                   goals[number-1], program, memory, threads, seed=seed,
                                   delay_max=8 if family == "R10" else 1))

    def add(name, family, goal, program, threads=4, **kwargs):
        cases.append(make_case(name, family, goal, program, initial_memory(),
                               threads, **kwargs))

    for n in [1, 3, 5, 7]:
        add("C01_threads_%d" % n, "C01", "partial-block active-lane masking",
            matadd_program(n), n)
    add("C02_zero_threads", "C02", "empty launch has no data transactions",
        matadd_program(4), 0)
    for n in [12, 13, 20]:
        add("C03_threads_%d" % n, "C03", "redispatch and partial final block",
            matadd_program(n), n)
    for name, op, a, b in [("add_wrap", "ADD", 255, 1), ("sub_wrap", "SUB", 0, 1),
                            ("add_sign_boundary", "ADD", 127, 1),
                            ("sub_sign_boundary", "SUB", 128, 1)]:
        add("C04_" + name, "C04", "eight-bit arithmetic boundaries",
            arithmetic_program(op, a, b))
    for name, a, b in [("max_product", 255, 255), ("zero_product", 255, 0),
                        ("identity_product", 255, 1)]:
        add("C05_" + name, "C05", "product truncation", arithmetic_program("MUL", a, b))
    for a, b in [(0, 1), (255, 1), (255, 255), (1, 255)]:
        add("C06_div_%d_%d" % (a, b), "C06", "quotient boundaries",
            arithmetic_program("DIV", a, b))
    p = Program()
    for reg in [13, 14, 15]:
        p.emit("CONST", reg, immediate=77)
    index(p)
    for reg, base in [(13, 128), (14, 144), (15, 160)]:
        store_signature(p, reg, base)
    p.emit("RET")
    add("C07_metadata", "C07", "read-only metadata across multiple blocks", p.finish(), 12)
    for base in [0, 252]:
        p = Program()
        index(p)
        p.emit("CONST", 1, immediate=base)
        p.emit("ADD", 1, 1, 0)
        p.emit("LDR", 2, 1)
        p.emit("CONST", 3, immediate=1)
        p.emit("ADD", 2, 2, 3)
        p.emit("STR", rs=1, rt=2)
        p.emit("RET")
        add("C08_base_%d" % base, "C08", "memory boundary read/modify/write", p.finish())
    for a, b in [(0, 255), (17, 17), (255, 0), (127, 128), (128, 127)]:
        for mask in [4, 2, 1]:
            add("C09_cmp_%d_%d_mask_%d" % (a, b, mask), "C09",
                "NZP ordering and immediate CMP/BR dependency", branch_program(a, b, mask))
    for kind in [1, 2]:
        add("C10_reset_" + ("read" if kind == 1 else "write"), "C10",
            "abort stalled transaction and restart without stale responses",
            matadd_program(4), reset_kind=kind, delay_min=8, delay_max=8)
    return cases


# ---------------------------------------------------------------------------------
# A1: bypass WAIT for non-memory instructions (rtl/scheduler_a1.sv)
# Functional expectations are unchanged by A1, so every case is checked by the same
# golden model; the A1-specific property (one cycle saved per retired non-memory
# instruction) is checked by sim/compare_cycles.py against a baseline run.
# Memory map used by the A1 generators (idx = global thread index, < 16):
#   0..63    read-only inputs, lane address 16*s + idx
#   64..127  lane-local scratch for store/load, 64 + 16*s + idx
#   128..255 register signatures, 128 + 16*s + idx
# ---------------------------------------------------------------------------------

A1_DATA_REGS = range(1, 9)   # r9/r10: CMP operands and DIV divisor; r11/r12: addresses


def a1_signatures(p, regs=A1_DATA_REGS):
    for slot, reg in enumerate(regs):
        store_signature(p, reg, 128 + 16*slot)


def a1_address(p, reg, base):
    p.emit("CONST", reg, immediate=base)
    p.emit("ADD", reg, reg, 0)


def a1_alu(p, rng, count):
    """Random ALU ops on r1..r8; DIV gets a fresh nonzero divisor in r9."""
    for _ in range(count):
        op = rng.choice(["ADD", "SUB", "MUL", "DIV", "CONST", "NOP"])
        rd, rs, rt = (rng.choice(A1_DATA_REGS) for _ in range(3))
        if op == "CONST":
            p.emit("CONST", rd, immediate=rng.randrange(256))
        elif op == "NOP":
            p.emit("NOP")
        elif op == "DIV":
            p.emit("CONST", 9, immediate=rng.randrange(1, 256))
            p.emit("DIV", rd, rs, 9)
        else:
            # Mix in the thread ID now and then so lanes hold different values.
            p.emit(op, rd, rs, 15 if rng.random() < 0.2 else rt)


def a1_mixed_program(rng, segments=10):
    """Random interleaving of ALU runs, load-use, store/load and CMP/BR segments."""
    p = Program()
    index(p)
    for reg in A1_DATA_REGS:
        p.emit("CONST", reg, immediate=rng.randrange(256))
    labels = 0
    kinds = ["alu", "load", "store", "branch"]
    plan = kinds + [rng.choice(kinds) for _ in range(segments - len(kinds))]
    rng.shuffle(plan)
    for kind in plan:
        if kind == "alu":
            a1_alu(p, rng, rng.randrange(2, 6))
        elif kind == "load":
            rd = rng.choice(A1_DATA_REGS)
            a1_address(p, 12, 16*rng.randrange(4))
            p.emit("LDR", rd, 12)
            p.emit("ADD", rd, rd, rng.choice(A1_DATA_REGS))   # immediate load-use
        elif kind == "store":
            rv, rd = rng.choice(A1_DATA_REGS), rng.choice(A1_DATA_REGS)
            a1_address(p, 12, 64 + 16*rng.randrange(4))
            p.emit("STR", rs=12, rt=rv)
            p.emit("LDR", rd, 12)                               # store->load, no ALU between
            p.emit("SUB", rd, rd, 15)
        else:
            # Lane-independent operands keep the branch convergent.
            p.emit("CONST", 9, immediate=rng.randrange(256))
            p.emit("CONST", 10, immediate=rng.randrange(256))
            p.emit("CMP", rs=9, rt=10)
            target = "skip%d" % labels
            labels += 1
            p.branch(rng.randrange(1, 8), target)
            a1_alu(p, rng, rng.randrange(1, 3))
            p.label(target)
    a1_signatures(p)
    p.emit("RET")
    return p.finish()


def a1_random_program(family, rng, memory):
    """Return (program, threads) for random A1 families; may set input memory."""
    for i in range(64):
        memory[i] = rng.randrange(256)
    if family == "A1_01":
        p = Program()
        index(p)
        for reg in A1_DATA_REGS:
            p.emit("CONST", reg, immediate=rng.randrange(256))
        a1_alu(p, rng, 32)
        a1_signatures(p)
        p.emit("RET")
        return p.finish(), 4
    if family == "A1_02":
        p = Program()
        index(p)
        p.emit("CONST", 4, immediate=rng.randrange(256))
        for slot in range(4):
            a1_address(p, 1, 16*slot)
            p.emit("LDR", 2, 1)
            p.emit("ADD", 3, 2, 15)      # first use right after WAIT -> EXECUTE
            p.emit("MUL", 3, 3, 2)
            p.emit("ADD", 4, 4, 3)
            p.emit("LDR", 5, 1)          # memory -> memory, both must wait
            p.emit("LDR", 6, 1)
            p.emit("SUB", 6, 6, 5)       # always 0: second load did not reuse stale data
            p.emit("ADD", 4, 4, 6)
        a1_signatures(p, [2, 3, 4, 5, 6])
        p.emit("RET")
        return p.finish(), 4
    if family == "A1_03":
        p = Program()
        index(p)
        for slot in range(4):
            a1_address(p, 1, 64 + 16*slot)
            p.emit("CONST", 2, immediate=rng.randrange(256))
            p.emit("ADD", 2, 2, 15)      # ALU immediately before STR
            p.emit("STR", rs=1, rt=2)
            p.emit("LDR", 3, 1)          # RAW through memory
            p.emit("SUB", 3, 3, 15)      # ALU immediately after LDR
            p.emit("ADD", 4, 4, 3)
        a1_signatures(p, [2, 3, 4])
        p.emit("RET")
        return p.finish(), 4
    if family == "A1_04":
        a, b = rng.randrange(256), rng.randrange(256)
        if rng.random() < 0.25:
            b = a
        memory[40], memory[41] = a, b
        p = Program()
        index(p)
        p.emit("CONST", 1, immediate=40)
        p.emit("CONST", 2, immediate=41)
        p.emit("LDR", 3, 1)              # shared read-only address: convergent branch
        p.emit("LDR", 4, 2)
        p.emit("CMP", rs=3, rt=4)        # CMP right after a waited load
        p.branch(rng.randrange(1, 8), "taken")
        p.emit("CONST", 5, immediate=17)
        p.emit("ADD", 5, 5, 3)
        a1_signatures(p, [5])
        p.emit("RET")
        p.label("taken")
        p.emit("CONST", 5, immediate=231)
        p.emit("SUB", 5, 5, 4)
        a1_signatures(p, [5])
        p.emit("RET")
        return p.finish(), 4
    if family == "A1_05":
        p = Program()
        index(p)
        p.emit("CONST", 1, immediate=0)
        p.emit("CONST", 2, immediate=rng.randrange(1, 25))
        p.emit("CONST", 3, immediate=1)
        p.emit("CONST", 4, immediate=rng.randrange(256))
        p.emit("CONST", 5, immediate=0)
        p.label("loop")
        p.emit("ADD", 5, 5, 4)
        p.emit("MUL", 6, 5, 15)
        p.emit("SUB", 6, 6, 3)
        p.emit("ADD", 1, 1, 3)
        p.emit("CMP", rs=1, rt=2)
        p.branch(4, "loop")
        p.emit("NOP")
        a1_signatures(p, [1, 5, 6])
        p.emit("RET")
        return p.finish(), 4
    if family == "A1_07":
        return a1_mixed_program(rng), 4
    raise ValueError("unknown A1 random family: " + family)


A1_GOALS = {
    "A1_01": "max bypass density: random straight-line ALU/CONST/NOP/DIV",
    "A1_02": "load-use right after WAIT->EXECUTE; back-to-back loads still wait",
    "A1_03": "STR/LDR never bypass; RAW through memory between ALU ops",
    "A1_04": "bypassed CMP/BR consuming waited load results",
    "A1_05": "long runs of bypassed CMP/BR in counted loops",
    "A1_06": "RET bypass and completion timing; zero/one memory-op edges",
    "A1_07": "memory backpressure (1-8 cycle responses) with bypassed ALU ops",
    "A1_08": "partial blocks and redispatch with bypass; disabled lanes silent",
    "A1_09": "reset during stalled read/write in bypass-heavy program, relaunch",
    "A1_10": "matmul/matadd workloads with random data",
}


def generate_a1_cases(trials=100, seed_offset=0):
    """A1 suite: random families use `trials` instances; corner families are fixed."""
    if not isinstance(trials, int) or trials < 1:
        raise ValueError("trials must be a positive integer")
    if not isinstance(seed_offset, int) or seed_offset < 0:
        raise ValueError("seed offset must be a nonnegative integer")
    cases = []

    def seed_of(family):
        return 2000 + int(family[-2:]) + seed_offset

    for family in ["A1_01", "A1_02", "A1_03", "A1_04", "A1_05", "A1_07"]:
        seed = seed_of(family)
        rng = random.Random(seed)
        for trial in range(trials):
            memory = initial_memory(rng)
            program, threads = a1_random_program(family, rng, memory)
            cases.append(make_case("%s_%04d" % (family, trial), family, A1_GOALS[family],
                                   program, memory, threads, seed=seed,
                                   delay_max=8 if family == "A1_07" else 1))

    def add(name, family, program, threads=4, memory=None, **kwargs):
        cases.append(make_case(name, family, A1_GOALS[family], program,
                               memory if memory is not None else initial_memory(),
                               threads, **kwargs))

    # A1_06: completion and memory-op edges
    p = Program()
    p.emit("RET")
    ret_only = p.finish()
    for n in [1, 4, 8]:
        add("A1_06_ret_only_threads_%d" % n, "A1_06", ret_only, n)
    p = Program()
    for _ in range(8):
        p.emit("NOP")
    index(p)
    store_signature(p, 15)
    p.emit("RET")
    add("A1_06_nops_then_store", "A1_06", p.finish())
    p = Program()
    index(p)
    p.emit("CONST", 1, immediate=99)
    p.emit("ADD", 1, 1, 15)
    store_signature(p, 1)            # STR is the last instruction before RET
    p.emit("RET")
    add("A1_06_store_before_ret", "A1_06", p.finish())
    p = Program()
    index(p)
    a1_address(p, 3, 64)
    p.emit("CONST", 4, immediate=7)
    p.emit("STR", rs=3, rt=4)
    p.emit("LDR", 5, 3)              # LDR is the last instruction before RET
    p.emit("RET")
    add("A1_06_load_before_ret", "A1_06", p.finish())
    p = Program()
    index(p)
    for reg in range(1, 13):
        p.emit("CONST", reg, immediate=(29 * reg + 3) & 255)
    a1_signatures(p, [1, 6, 12])
    p.emit("RET")
    add("A1_06_const_all_registers", "A1_06", p.finish())

    # A1_08: one mixed program at partial-block and multi-block thread counts
    rng = random.Random(seed_of("A1_08"))
    memory = initial_memory(rng)
    for i in range(64):
        memory[i] = rng.randrange(256)
    program = a1_mixed_program(rng)
    for n in [1, 3, 5, 7, 12, 13]:
        add("A1_08_threads_%d" % n, "A1_08", program, n, memory=list(memory),
            seed=seed_of("A1_08"))

    # A1_09: reset while a memory request is stalled, then a full relaunch
    rng = random.Random(seed_of("A1_09"))
    for variant in range(2):
        memory = initial_memory(rng)
        for i in range(64):
            memory[i] = rng.randrange(256)
        program = a1_mixed_program(rng)
        for kind in [1, 2]:
            add("A1_09_reset_%s_%d" % ("read" if kind == 1 else "write", variant), "A1_09",
                program, memory=list(memory), seed=seed_of("A1_09"),
                reset_kind=kind, delay_min=8, delay_max=8)

    # A1_10: real kernels with random data
    seed = seed_of("A1_10")
    rng = random.Random(seed)
    for trial in range(trials):
        memory = initial_memory(rng)
        memory[:8] = [rng.randrange(256) for _ in range(8)]
        cases.append(make_case("A1_10_matmul_%04d" % trial, "A1_10", A1_GOALS["A1_10"],
                               matmul_program(), memory, 4, seed=seed))
        memory = initial_memory(rng)
        memory[:16] = [rng.randrange(256) for _ in range(16)]
        cases.append(make_case("A1_10_matadd_%04d" % trial, "A1_10", A1_GOALS["A1_10"],
                               matadd_program(8), memory, 8, seed=seed))
    return cases


SUITES = {
    "midterm": generate_cases,
    "a1": generate_a1_cases,
    "all": lambda trials=100, seed_offset=0: (generate_cases(trials, seed_offset)
                                              + generate_a1_cases(trials, seed_offset)),
}
