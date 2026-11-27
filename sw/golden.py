"""Width-aware ISA reference, independent of RTL scheduling and cell mapping.

CMP specifies unsigned ordering with NZP in bits 2/1/0. Division by zero,
divergent branches, and cross-thread memory races are outside this suite's
legal program contract and are rejected, not given invented reference values.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Sequence


OPS = {"NOP": 0, "BR": 1, "CMP": 2, "ADD": 3, "SUB": 4, "MUL": 5,
       "DIV": 6, "LDR": 7, "STR": 8, "CONST": 9, "RET": 15}


def encode(op: str, rd: int = 0, rs: int = 0, rt: int = 0,
           *, immediate: int = 0, mask: int = 0) -> int:
    """Encode one instruction; reject truncating/invalid assembler inputs."""
    if op not in OPS:
        raise ValueError("unknown opcode: " + op)
    if any(not isinstance(x, int) or not 0 <= x < 16 for x in (rd, rs, rt)):
        raise ValueError("register address must fit four bits")
    if not isinstance(immediate, int) or not 0 <= immediate < 256:
        raise ValueError("immediate must fit eight bits")
    if not isinstance(mask, int) or not 0 <= mask < 8:
        raise ValueError("branch mask must fit three bits")
    word = OPS[op] << 12
    if op == "BR":
        return word | (mask << 9) | immediate
    if op == "CONST":
        return word | (rd << 8) | immediate
    return word | (rd << 8) | (rs << 4) | rt


@dataclass
class Execution:
    memory: List[int]
    writes: Dict[int, int]
    # A1 (WAIT bypass) addition: per-block dynamic instruction counts. Blocks are
    # convergent, so one count per block covers every active lane. `retired`
    # includes the final RET; `memory_ops` counts LDR/STR. A1 does not change any
    # functional output (memory, writes); it removes exactly one scheduler cycle per
    # retired non-memory instruction, i.e. `retired - memory_ops` cycles per block
    # when the block runs alone on one core (see sim/compare_cycles.py).
    retired: List[int] = field(default_factory=list)
    memory_ops: List[int] = field(default_factory=list)

    def non_memory_ops(self) -> List[int]:
        """A1: instructions per block that skip WAIT (one cycle saved each)."""
        return [r - m for r, m in zip(self.retired, self.memory_ops)]


def execute(program: Sequence[int], memory: Sequence[int], threads: int,
            *, max_steps: int = 10000) -> Execution:
    """Execute convergent four-lane blocks; no cycle/timing model is implied."""
    if not 0 <= threads <= 255 or not isinstance(threads, int):
        raise ValueError("thread count must fit eight bits")
    if not 1 <= len(program) <= 256 or any(not 0 <= x <= 65535 for x in program):
        raise ValueError("program must contain 1..256 sixteen-bit words")
    if len(memory) != 256 or any(not 0 <= x <= 255 for x in memory):
        raise ValueError("memory must contain 256 bytes")
    if max_steps < 1:
        raise ValueError("step budget must be positive")
    code = list(program) + [0] * (256 - len(program))
    data = list(memory)
    writes: Dict[int, int] = {}
    owners: Dict[int, int] = {}
    readers: Dict[int, set] = {}
    retired: List[int] = []
    memory_ops: List[int] = []
    for block in range((threads + 3) // 4):
        count = min(4, threads - 4 * block)
        regs = [[0] * 13 + [block, 4, lane] for lane in range(count)]
        nzp = [0] * count
        pc = 0
        retired.append(0)      # A1 performance counters (no functional effect)
        memory_ops.append(0)
        for _ in range(max_steps):
            word = code[pc]
            op, rd, rs, rt = word >> 12, (word >> 8) & 15, (word >> 4) & 15, word & 15
            imm, mask = word & 255, (word >> 9) & 7
            if op not in OPS.values():
                raise ValueError("unsupported opcode at PC %d" % pc)
            retired[-1] += 1
            if op in (OPS["LDR"], OPS["STR"]):
                memory_ops[-1] += 1
            if op == OPS["RET"]:
                break
            targets = []
            for lane, r in enumerate(regs):
                tid = 4 * block + lane
                a, b = r[rs], r[rt]
                target, result = (pc + 1) & 255, None
                if op == OPS["BR"]:
                    if nzp[lane] & mask:
                        target = imm
                elif op == OPS["CMP"]:
                    nzp[lane] = 4 if a < b else 2 if a == b else 1
                elif op == OPS["ADD"]:
                    result = (a + b) & 255
                elif op == OPS["SUB"]:
                    result = (a - b) & 255
                elif op == OPS["MUL"]:
                    result = (a * b) & 255
                elif op == OPS["DIV"]:
                    if b == 0:
                        raise ValueError("division by zero")
                    result = a // b
                elif op == OPS["LDR"]:
                    if a in owners and owners[a] != tid:
                        raise ValueError("cross-thread memory conflict on read")
                    readers.setdefault(a, set()).add(tid)
                    result = data[a]
                elif op == OPS["STR"]:
                    if ((a in owners and owners[a] != tid) or
                            (readers.get(a, set()) - {tid})):
                        raise ValueError("cross-thread memory conflict on write")
                    owners[a] = tid
                    data[a] = b
                    writes[a] = writes.get(a, 0) + 1
                elif op == OPS["CONST"]:
                    result = imm
                if result is not None and rd < 13:
                    r[rd] = result
                targets.append(target)
            if len(set(targets)) != 1:
                raise ValueError("divergent branch targets")
            pc = targets[0]
        else:
            raise ValueError("instruction budget exhausted (nontermination)")
    return Execution(data, writes, retired, memory_ops)
