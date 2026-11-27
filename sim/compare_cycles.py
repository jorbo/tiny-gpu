"""A1 cycle check: compare a baseline run manifest with an optimized run of the same cases.

Usage:
    python3 -m sim.compare_cycles BASELINE/manifest.json A1/manifest.json
    python3 -m sim.compare_cycles BASELINE_SHARDS/ A1_SHARDS/   # dirs of */manifest.json

Both manifests must come from `sim.run --mode rtl|netlist` with the same suite, trials,
and seed offset. A1 (rtl/scheduler_a1.sv) removes the WAIT state for every non-memory
instruction, so per case:

* exact:   one block on one core, fixed response delay, no reset injection
           -> baseline_cycles - a1_cycles == retired - memory_ops  (from sw/golden.py)
           With a single core there is no arbitration, so every bypassed WAIT is
           exactly one cycle.
* faster:  other fixed-delay, no-reset cases (two cores share the program-memory
           channel, so arbitration can shift savings) -> a1_cycles < baseline_cycles
* equal:   zero-thread launch (no instruction executes) -> identical cycle counts
* functional: random response delays or reset injection -> both runs pass; cycles
           are reported but not constrained (handshake schedules differ).

Exit status: 0 if every case passes in both runs and every applicable rule holds, 1 on
any violation, 2 on unusable input.
"""

import argparse
from collections import OrderedDict
import json
from pathlib import Path
import sys


def rule(case):
    if case["threads"] == 0:
        return "equal"          # nothing executes: both designs only report done
    single = 1 <= case["threads"] <= 4
    fixed = case["delay_min"] == case["delay_max"]
    if fixed and case["reset_kind"] == 0:
        return "exact" if single else "faster"
    return "functional"


def compare(baseline, optimized):
    """Return (rows, violations); rows are per-case dicts."""
    base = {c["name"]: c for c in baseline["cases"]}
    opt = {c["name"]: c for c in optimized["cases"]}
    if set(base) != set(opt):
        raise ValueError("manifests contain different case sets (%d vs %d cases)"
                         % (len(base), len(opt)))
    rows, violations = [], []
    for name in sorted(base):
        b, o = base[name], opt[name]
        kind = rule(b)
        row = {"name": name, "family": b["family"], "rule": kind,
               "baseline": b.get("cycles"), "optimized": o.get("cycles"),
               "expected_saving": None, "ok": True}
        if b.get("status") != "pass" or o.get("status") != "pass":
            row["ok"] = False
            violations.append("%s: not passing in both runs (baseline=%s, optimized=%s)"
                              % (name, b.get("status"), o.get("status")))
        elif kind == "exact":
            saving = b["retired"][0] - b["memory_ops"][0]
            row["expected_saving"] = saving
            if b["cycles"] - o["cycles"] != saving:
                row["ok"] = False
                violations.append("%s: saved %d cycles, expected %d"
                                  % (name, b["cycles"] - o["cycles"], saving))
        elif kind == "equal" and o["cycles"] != b["cycles"]:
            row["ok"] = False
            violations.append("%s: zero-thread launch took %d cycles, baseline %d"
                              % (name, o["cycles"], b["cycles"]))
        elif kind == "faster" and not o["cycles"] < b["cycles"]:
            row["ok"] = False
            violations.append("%s: optimized %d cycles is not below baseline %d"
                              % (name, o["cycles"], b["cycles"]))
        rows.append(row)
    return rows, violations


def summarize(rows):
    families = OrderedDict()
    for r in rows:
        families.setdefault(r["family"], []).append(r)
    lines = ["%-8s %5s %5s %6s %6s %10s %10s %8s" % (
        "family", "cases", "fail", "exact", "faster", "base_avg", "opt_avg", "saved%")]
    for family, group in families.items():
        done = [r for r in group if r["baseline"] is not None and r["optimized"] is not None]
        base = sum(r["baseline"] for r in done) / len(done) if done else 0
        opt = sum(r["optimized"] for r in done) / len(done) if done else 0
        lines.append("%-8s %5d %5d %6d %6d %10.1f %10.1f %7.2f%%" % (
            family, len(group), sum(not r["ok"] for r in group),
            sum(r["rule"] == "exact" for r in group),
            sum(r["rule"] == "faster" for r in group),
            base, opt, 100 * (base - opt) / base if base else 0))
    return "\n".join(lines)


def load(path):
    """Read one manifest.json, or merge every */manifest.json under a directory
    (a run sharded by --case into one sim.run process per family)."""
    path = Path(path)
    if path.is_file():
        return json.loads(path.read_text())
    shards = sorted(path.glob("*/manifest.json"))
    if not shards:
        raise ValueError("no manifest.json in %s" % path)
    merged = {"mode": None, "cases": [], "shards": [str(s) for s in shards]}
    for shard in shards:
        m = json.loads(shard.read_text())
        if merged["mode"] not in (None, m.get("mode")):
            raise ValueError("shards mix simulation modes")
        merged["mode"] = m.get("mode")
        merged["cases"].extend(m["cases"])
    names = [c["name"] for c in merged["cases"]]
    if len(names) != len(set(names)):
        raise ValueError("duplicate cases across shards in %s" % path)
    return merged


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("baseline", type=Path, help="baseline manifest.json or shard directory")
    p.add_argument("optimized", type=Path, help="optimized (A1) manifest.json or shard directory")
    p.add_argument("--json", type=Path, help="write per-case rows here")
    args = p.parse_args(argv)
    try:
        manifests = [load(path) for path in (args.baseline, args.optimized)]
        for path, m in zip((args.baseline, args.optimized), manifests):
            if m.get("mode") not in ("rtl", "netlist"):
                raise ValueError("%s is not a simulation manifest" % path)
        rows, violations = compare(*manifests)
    except (OSError, ValueError, KeyError) as error:
        print("ERROR: %s" % error, file=sys.stderr)
        return 2
    print(summarize(rows))
    if args.json:
        args.json.write_text(json.dumps(rows, indent=2) + "\n")
    for v in violations:
        print("VIOLATION " + v)
    print("%d cases; %d violations" % (len(rows), len(violations)))
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main())
