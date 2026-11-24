"""Generate vectors offline, or explicitly run them with Icarus when available."""

import argparse
from dataclasses import asdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from typing import List

from sim.cases import Case, generate_cases


ROOT = Path(__file__).resolve().parents[1]


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def write_hex(path, values, width):
    path.write_text("".join(format(v, "0%dx" % width) + "\n" for v in values))


def export_cases(cases: List[Case], out: Path):
    """Write complete images, provenance, and explicit unrun DUT status."""
    if not cases:
        raise ValueError("no testcases selected")
    out = Path(out)
    out.mkdir(parents=True, exist_ok=False)
    manifest = {"schema": 1, "mode": "generate", "dut_status": "not_run",
                "reference": "unsigned byte ISA; convergent branches; NZP=bits 2/1/0",
                "families": sorted({c.family for c in cases}), "cases": []}
    manifest["verification_sources"] = [
        {"path": name, "sha256": hashlib.sha256((ROOT / name).read_bytes()).hexdigest()}
        for name in ["sim/tb_regression.v", "sim/cases.py", "sim/run.py", "sw/golden.py"]]
    for c in cases:
        folder = out / c.name
        folder.mkdir()
        write_hex(folder / "program.hex", c.program + [0]*(256-len(c.program)), 4)
        write_hex(folder / "data.hex", c.memory, 2)
        write_hex(folder / "expected.hex", c.expected, 2)
        write_hex(folder / "writes.hex", [c.writes.get(i, 0) for i in range(256)], 8)
        config = {k: v for k, v in asdict(c).items()
                  if k not in {"program", "memory", "expected", "writes"}}
        write_json(folder / "case.json", config)
        digest = hashlib.sha256()
        for filename in ["program.hex", "data.hex", "expected.hex", "writes.hex", "case.json"]:
            digest.update((folder / filename).read_bytes())
        manifest["cases"].append(dict(config, status="not_run", sha256=digest.hexdigest()))
    write_json(out / "manifest.json", manifest)
    return manifest


def classify(returncode, output, name):
    """Fail closed on wrong/missing completion, process failure, or HDL diagnostics."""
    if returncode != 0 or re.search(r"\b(FAIL|FATAL|ERROR|Mismatch)\b", output, re.I):
        return "fail"
    lines = re.findall(r"^PASS (\S+) cycles=(\d+)$", output, re.M)
    return "pass" if len(lines) == 1 and lines[0][0] == name else "fail"


def timeout_output(error, stage):
    parts = []
    for value in (error.stdout, error.stderr):
        if value:
            parts.append(value.decode("utf-8", errors="replace") if isinstance(value, bytes) else value)
    return "".join(parts) + "\nFAIL %s wall-clock timeout\n" % stage


def run_simulation(manifest, out, args):
    """Compile once, run each instance in a new simulator process, save all outcomes."""
    manifest["mode"] = args.mode
    manifest["dut_status"] = "not_run"
    manifest["limitations"] = ["zero-delay simulation; no SDF timing verification"]
    source = Path(args.rtl if args.mode == "rtl" else args.netlist).resolve()
    models = [Path(p).resolve() for p in args.cell_model]
    if not source.is_file():
        raise ValueError("DUT source does not exist: " + str(source))
    if args.mode == "netlist" and not models:
        raise ValueError("netlist mode requires --cell-model paths for the actual mapped libraries")
    if any(not p.is_file() for p in models):
        raise ValueError("a supplied cell-model file does not exist")
    for tool in [args.iverilog, args.vvp]:
        if shutil.which(tool) is None:
            raise ValueError("required simulator executable not found: " + tool)
    # Preserve executable identity without an extra version-query invocation.
    manifest["simulator_executables"] = [
        {"path": str(Path(shutil.which(tool)).resolve()),
         "sha256": hashlib.sha256(Path(shutil.which(tool)).read_bytes()).hexdigest()}
        for tool in [args.iverilog, args.vvp]]
    sources = [source] + models
    manifest["sources"] = [{"path": str(p), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                           for p in sources]
    manifest["clock_period_ns"] = args.period
    exe = out / "simulation.vvp"
    command = [args.iverilog, "-g2012", "-s", "tb_regression",
               "-DCLK_PERIOD=%s" % args.period, "-o", str(exe),
               str(ROOT / "sim/tb_regression.v")] + [str(p) for p in sources]
    manifest["compile_command"] = command
    try:
        compiled = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
    except subprocess.TimeoutExpired as error:
        (out / "compile.log").write_text(timeout_output(error, "compilation"))
        raise ValueError("compilation timed out") from error
    (out / "compile.log").write_text(compiled.stdout + compiled.stderr)
    if compiled.returncode:
        raise ValueError("compilation failed; see compile.log")
    for c in manifest["cases"]:
        folder = out / c["name"]
        command = [args.vvp, str(exe), "+case_dir=" + str(folder), "+name=" + c["name"],
                   "+threads=%d" % c["threads"], "+delay_min=%d" % c["delay_min"],
                   "+delay_max=%d" % c["delay_max"], "+seed=%d" % c["delay_seed"],
                   "+reset_kind=%d" % c["reset_kind"], "+max_cycles=%d" % args.max_cycles]
        if args.vcd:
            command.append("+vcd=" + str(folder / "wave.vcd"))
        c["command"] = command
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
            output = result.stdout + result.stderr
            c["returncode"] = result.returncode
            c["status"] = classify(result.returncode, output, c["name"])
            match = re.search(r"^PASS \S+ cycles=(\d+)$", output, re.M)
            if c["status"] == "pass" and match:
                c["cycles"] = int(match.group(1))
        except subprocess.TimeoutExpired as error:
            output = timeout_output(error, "simulation")
            c["status"] = "fail"
            c["failure"] = "timeout"
        (folder / "simulation.log").write_text(output)
        # Persist partial progress, but never call an unfinished suite passing.
        write_json(out / "manifest.json", manifest)
    manifest["dut_status"] = ("pass" if all(c["status"] == "pass" for c in manifest["cases"])
                              else "fail")
    write_json(out / "manifest.json", manifest)
    return manifest["dut_status"] == "pass"


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mode", choices=["generate", "rtl", "netlist"], default="generate")
    p.add_argument("--out", type=Path, help="new directory; existing outputs are never overwritten")
    p.add_argument("--trials", type=int, default=100, help="instances per random family")
    p.add_argument("--seed-offset", type=int, default=0)
    p.add_argument("--case", action="append", default=[], help="select family or instance (repeatable)")
    p.add_argument("--rtl", default=str(ROOT / "build/gpu.v"), help="converted/flattened RTL")
    p.add_argument("--netlist", help="exact mapped netlist; required in netlist mode")
    p.add_argument("--cell-model", action="append", default=[], help="cell-model file (repeatable)")
    p.add_argument("--period", type=float, default=2.55)
    p.add_argument("--timeout", type=float, default=60, help="wall seconds per compile/instance")
    p.add_argument("--max-cycles", type=int, default=100000)
    p.add_argument("--iverilog", default="iverilog")
    p.add_argument("--vvp", default="vvp")
    p.add_argument("--vcd", action="store_true", help="large: save one trace per instance")
    return p


def main(argv=None):
    args = parser().parse_args(argv)
    manifest, out = None, None
    try:
        if not 0 < args.period < 1e6 or not 0 < args.timeout < 1e6 or args.max_cycles < 1:
            raise ValueError("period, timeout, and cycle budget must be positive finite values")
        if args.mode == "netlist" and not args.netlist:
            raise ValueError("--netlist is required for netlist mode")
        cases = generate_cases(args.trials, args.seed_offset)
        if args.case:
            known = {c.name for c in cases} | {c.family for c in cases}
            if set(args.case) - known:
                raise ValueError("unknown case selector: " + ", ".join(sorted(set(args.case)-known)))
            cases = [c for c in cases if c.name in args.case or c.family in args.case]
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        out = (args.out or ROOT / "build/verification" / stamp).resolve()
        manifest = export_cases(cases, out)
        manifest["seed_offset"], manifest["trials"] = args.seed_offset, args.trials
        if args.mode != "generate":
            passed = run_simulation(manifest, out, args)
        else:
            passed = True  # Generation succeeded; this is NOT a DUT pass.
            write_json(out / "manifest.json", manifest)
        print("%d instances; DUT status: %s; %s" %
              (len(cases), manifest["dut_status"], out / "manifest.json"))
        return 0 if passed else 1
    except (ValueError, OSError, OverflowError) as error:
        if manifest is not None and out is not None:
            manifest["dut_status"] = "error"
            manifest["error"] = str(error)
            write_json(out / "manifest.json", manifest)
        print("ERROR: " + str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
