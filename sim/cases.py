"""Executable specifications for R01..R10 and C01..C10 from the midterm report."""

from dataclasses import dataclass
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
                reset_kind, delay_seed)


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
