"""Export portable source and explicitly selected evidence, without running tools."""

import argparse
import hashlib
import json
from pathlib import Path
import sys
import zipfile


SOURCE_DIRS = ("rtl", "sim", "sw", "syn", "ptpx", "scripts")
BLOCKED_SUFFIXES = {".db", ".lib", ".so", ".dylib", ".dll", ".a", ".exe",
                    ".zip", ".tgz", ".tar", ".gz", ".pem", ".key", ".p12", ".pfx"}


def files_under(root, source):
    """Yield only regular, repository-contained files; never follow symlinks."""
    relative = source.relative_to(root)
    for length in range(1, len(relative.parts) + 1):
        if (root / Path(*relative.parts[:length])).is_symlink():
            raise ValueError("symlink is not allowed in export input ancestors: " + str(source))
    if not source.exists():
        raise ValueError("missing export input: " + str(source))
    source.resolve().relative_to(root)
    paths = sorted(source.rglob("*")) if source.is_dir() else [source]
    for p in paths:
        if p.is_symlink():
            raise ValueError("symlink is not allowed in exports: " + str(p))
        if p.is_dir():
            continue
        if not p.is_file():
            raise ValueError("nonregular export input: " + str(p))
        p.resolve().relative_to(root)
        rel = p.relative_to(root)
        if "__pycache__" in rel.parts or p.suffix in {".pyc", ".pyo"} or p.name == ".DS_Store":
            continue
        if (p.name.startswith(".env") or p.name in {"credentials.json", ".netrc", "id_rsa", "id_ed25519"} or
                any(part in {".git", ".ssh", ".aws", ".venv", "node_modules"} for part in rel.parts)):
            raise ValueError("credential/environment input is not exportable: " + str(rel))
        blocked_extension = p.suffix.lower() in BLOCKED_SUFFIXES and not p.name.lower().endswith(".vcd.gz")
        if (blocked_extension or p.name.lower().startswith("saed32") or
                any(part.lower() == "pdk" or part.startswith("stdcell_") for part in rel.parts)):
            raise ValueError("licensed/library/binary archive input is not exportable: " + str(rel))
        yield rel, p


def package_readme(team, runs):
    selected = "\n".join("- `" + p + "`" for p in runs) or "- None selected."
    return """# Tiny-GPU midterm code package: team %d

This is a **draft export**, not a claim that hardware verification, SS timing,
power analysis, or all assignment requirements have passed. Check the separate
report and the selected result logs. `SUBMISSION.json` inventories every packaged
file with SHA-256; no licensed PDK libraries are included.

## Layout

`rtl/`: SystemVerilog; `sim/`: regression and legacy kernel tests;
`sw/`: independent reference; `syn/`: DC; `ptpx/`: PrimeTime;
`scripts/`: path helpers/export/checks; `docs/`: architecture and figures.

Run all commands from this extracted directory. Python 3.9+ and its standard
library suffice for the offline checks. Choose an explicit suitable interpreter.

```bash
make verification_unit PYTHON=python3
make verification_vectors PYTHON=python3
```

Generation writes 1,039 instances under `build/verification/`; the selected
`results/verification/` evidence is the recorded 1,039/1,039 RTL pass after the
two baseline fixes. Read `sim/README.md` for the test catalog and reference semantics.

## Hardware and software reproduction

Hardware commands require separately installed sv2v, Icarus/vvp, optional cocotb
2.x, Synopsys tools/licenses, and the course-provided SAED32 libraries. Record tool
versions and configure PDK paths on the host. No package command installs tools.

```bash
make compile
python3 -m sim.run --mode rtl --rtl build/gpu.v --period 2.9
dc_shell -x 'set RUN_DIR build/synthesis/candidate; set CORNER ss0p75v125c' -f syn/dc_synth.tcl
```

The maintained flow defaults to the required SS 0.75 V / 125°C libraries. The
selected SS run, its exact flow snapshot, and its caveats are under `results/ss/`.
See `syn/README.md` and `ptpx/README.md` for frequency search, flags, ECO, and
power measurement commands. For any chosen final netlist:

```bash
python3 -m sim.run --mode netlist --netlist PATH_TO_FINAL_NETLIST \\
  --cell-model PATH_TO_LVT_MODEL --cell-model PATH_TO_HVT_MODEL
make gls NETLIST=PATH_TO_FINAL_NETLIST CLK_PERIOD=CHOSEN_PERIOD SAED=PDK_LIB_DIR
pt_shell -x 'set RUN_DIR build/synthesis/candidate; set VCD build/gpu_gls.vcd' -f ptpx/pt_power.tcl
```

Supply every mapped Vt model, use the exact post-ECO implementation, and regenerate
period-matched workload activity. The RTL corpus has been run; netlist simulation
was not run here because the SAED32 models are external. The archived SS PPA
predates the two RTL fixes, so resynthesize before treating it as final. A
zero-delay netlist run is not timing signoff.
The report and presentation are separate deliverables, not included in this code
ZIP. Full historical evidence remains in the development repository.

## Selected evidence

%s
""" % (team, selected)


def export_submission(root, destination, *, team=6, runs=()):
    """Create a deterministic ZIP with one team directory. Never overwrite output."""
    root, destination = Path(root).resolve(), Path(destination).absolute()
    if not isinstance(team, int) or not 1 <= team <= 9999:
        raise ValueError("team must be an integer between 1 and 9999")
    if destination.exists() or destination.is_symlink():
        raise FileExistsError(destination)
    # Resolve parent aliases before checking output containment; never resolve the
    # final component first, which could hide an existing/dangling output symlink.
    destination = destination.parent.resolve() / destination.name
    for name in SOURCE_DIRS + ("docs", "results"):
        if root / name == destination or root / name in destination.parents:
            raise ValueError("write exports outside source/results directories (normally dist/)")
    payload = {}
    for name in SOURCE_DIRS:
        payload.update((str(rel), p.read_bytes()) for rel, p in files_under(root, root / name))
    for name in ["Makefile", "docs/architecture.md", "docs/images", "docs/img"]:
        source = root / name
        if name == "Makefile" or source.exists() or source.is_symlink():
            payload.update((str(rel), p.read_bytes()) for rel, p in files_under(root, source))
    selections = []
    for value in runs:
        relative = Path(value)
        if relative.is_absolute() or ".." in relative.parts or len(relative.parts) < 2:
            raise ValueError("select a repository-relative directory under results/tt/, results/ss/, or results/verification/")
        if relative.parts[:2] not in [("results", "tt"), ("results", "ss"), ("results", "verification")]:
            raise ValueError("result selection must be under results/tt/, results/ss/, or results/verification/")
        source = root / relative
        # Check every path component before resolving: a symlinked parent is unsafe too.
        if any((root / Path(*relative.parts[:n])).is_symlink() for n in range(1, len(relative.parts)+1)):
            raise ValueError("symlinked result selection is not allowed")
        if not source.is_dir():
            raise ValueError("selected result directory does not exist: " + str(relative))
        source.resolve().relative_to(root / "results")
        selections.append(str(relative))
        payload.update((str(rel), p.read_bytes()) for rel, p in files_under(root, source))
    selections = sorted(set(selections))
    payload["README.md"] = package_readme(team, selections).encode("utf-8")
    manifest = {"schema": 1, "team": team, "status": "draft", "selected_results": selections,
                "hardware_validation": "not asserted by exporter",
                "sha256": {name: hashlib.sha256(data).hexdigest() for name, data in sorted(payload.items())}}
    payload["SUBMISSION.json"] = (json.dumps(manifest, indent=2, sort_keys=True)+"\n").encode("utf-8")
    destination.parent.mkdir(parents=True, exist_ok=True)
    created = False
    try:
        with destination.open("xb") as stream:
            created = True
            with zipfile.ZipFile(stream, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                for name, data in sorted(payload.items()):
                    entry = zipfile.ZipInfo("midterm-team-%d/%s" % (team, name), (1980, 1, 1, 0, 0, 0))
                    entry.external_attr = 0o100644 << 16
                    entry.compress_type = zipfile.ZIP_DEFLATED
                    archive.writestr(entry, data)
    except Exception:
        if created:
            destination.unlink()  # Only the newly-created, incomplete archive.
        raise
    return destination


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--team", type=int, default=6)
    p.add_argument("--output", type=Path, default=Path("dist/midterm-team-6.zip"))
    p.add_argument("--run", action="append", default=[], help="explicit results/tt/..., results/ss/..., or results/verification/... directory")
    args = p.parse_args(argv)
    try:
        output = export_submission(Path(__file__).resolve().parents[1], args.output,
                                   team=args.team, runs=args.run)
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print("ERROR: " + str(error), file=sys.stderr)
        return 2
    print("Draft submission export: " + str(output))
    return 0


if __name__ == "__main__":
    sys.exit(main())
