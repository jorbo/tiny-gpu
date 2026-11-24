"""Offline layout/export checks. Never invoke an HDL or licensed toolchain."""

import hashlib
import gzip
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]


class RepositoryTests(unittest.TestCase):
    def test_tcl_root_resolution_outside_repository_and_complete_scripts(self):
        tcl = shutil.which("tclsh")
        if tcl is None:
            self.skipTest("plain Tcl interpreter not installed; no EDA tool required")
        helper = ROOT / "scripts/paths.tcl"
        script = "source {%s}\nputs [project_path build/gpu.v]\n" % helper
        for path in [ROOT / "syn/dc_synth.tcl", ROOT / "ptpx/pt_power.tcl",
                     ROOT / "ptpx/pt_eco.tcl", ROOT / "ptpx/diagnostics/cap_debug.tcl",
                     ROOT / "ptpx/diagnostics/sram_info.tcl"]:
            script += ('set f [open {%s} r]\nset text [read $f]\nclose $f\n'
                       'if {![info complete $text]} {exit 1}\n') % path
        with tempfile.TemporaryDirectory() as temp:
            proc = subprocess.run([tcl], input=script, cwd=temp, capture_output=True,
                                  text=True, timeout=10)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stderr, "")
        self.assertEqual(proc.stdout.strip(), str(ROOT / "build/gpu.v"))

    def test_legacy_logger_uses_disposable_build_directory(self):
        from sim.legacy.helpers.logger import Logger
        logger = Logger()
        self.assertEqual(Path(logger.filename).parent, ROOT / "build/logs")
        self.assertTrue(Path(logger.filename).parent.is_dir())

    def test_canonical_sources_exist(self):
        for rel in ["rtl/gpu.sv", "sim/legacy/tb_gpu.v", "sim/legacy/test_matadd.py",
                    "sw/golden.py", "syn/dc_synth.tcl", "ptpx/pt_power.tcl",
                    "ptpx/pt_eco.tcl", "docs/architecture.md"]:
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_preserved_artifacts_match_migration_hashes(self):
        index = ROOT / "results/migration.json"
        if not index.exists() and (ROOT / "SUBMISSION.json").exists():
            self.skipTest("full historical archive deliberately excluded from submission")
        self.assertTrue(index.is_file(), "missing migration evidence index")
        records = json.loads(index.read_text())["files"]
        self.assertGreater(len(records), 250)
        for record in records:
            p = ROOT / record["new"]
            self.assertTrue(p.is_file(), str(p))
            self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), record["sha256"], str(p))


class ExportTests(unittest.TestCase):
    def exporter(self):
        self.assertIsNotNone(importlib.util.find_spec("scripts.export_submission"))
        from scripts.export_submission import export_submission
        return export_submission

    def test_default_export_is_draft_self_contained_and_no_overwrite(self):
        export = self.exporter()
        with tempfile.TemporaryDirectory() as temp:
            destination = Path(temp) / "team.zip"
            export(ROOT, destination, team=6)
            before = destination.read_bytes()
            second = Path(temp) / "same-inputs.zip"
            export(ROOT, second, team=6)
            self.assertEqual(before, second.read_bytes(), "identical inputs must give identical ZIP bytes")
            with self.assertRaises(FileExistsError):
                export(ROOT, destination, team=6)
            self.assertEqual(destination.read_bytes(), before)
            with zipfile.ZipFile(destination) as archive:
                names = set(archive.namelist())
                self.assertIn("midterm-team-6/rtl/gpu.sv", names)
                self.assertIn("midterm-team-6/ptpx/pt_power.tcl", names)
                self.assertNotIn("midterm-team-6/build/gpu.v", names)
                self.assertFalse(any("__pycache__" in p or p.endswith(".db") for p in names))
                m = json.loads(archive.read("midterm-team-6/SUBMISSION.json"))
                self.assertEqual(m["status"], "draft")
                for name, sha in m["sha256"].items():
                    self.assertEqual(hashlib.sha256(archive.read("midterm-team-6/"+name)).hexdigest(), sha)
                archive.extractall(Path(temp) / "extracted with space")
            root = Path(temp) / "extracted with space/midterm-team-6"
            proc = subprocess.run(["make", "verification_unit", "PYTHON="+sys.executable],
                                  cwd=root, capture_output=True, text=True, timeout=60)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            proc = subprocess.run(["make", "-f", str(root / "Makefile"),
                                   "verification_unit", "PYTHON="+sys.executable],
                                  cwd=temp, capture_output=True, text=True, timeout=60)
            self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_export_rejects_a_symlinked_documentation_parent(self):
        export = self.exporter()
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            root = temp / "repo"
            root.mkdir()
            for name in ["rtl", "sim", "sw", "syn", "ptpx", "scripts"]:
                (root / name).mkdir()
                (root / name / "README.md").write_text("fixture\n")
            (root / "Makefile").write_text("verification_unit:\n\t@true\n")
            external = temp / "outside"
            external.mkdir()
            (external / "architecture.md").write_text("outside fixture; must not be bundled\n")
            (root / "docs").symlink_to(external, target_is_directory=True)
            with self.assertRaises(ValueError):
                export(root, temp / "escaped-docs.zip", team=6)

    def test_selected_results_and_rejection_of_escaping_or_licensed_inputs(self):
        export = self.exporter()
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            # Exercise selection on a tiny standalone fixture, not a licensed tool.
            root = temp / "repo"
            root.mkdir()
            for name in ["rtl", "sim", "sw", "syn", "ptpx", "scripts", "docs"]:
                (root / name).mkdir()
                (root / name / "README.md").write_text("fixture\n")
            (root / "Makefile").write_text("verification_unit:\n\t@true\n")
            run = root / "results/ss/candidate"
            run.mkdir(parents=True)
            (run / "summary.rpt").write_text("period_ns 3.1\n")
            (run / "activity.vcd.gz").write_bytes(gzip.compress(b"$timescale 1ps $end\n"))
            export(root, temp / "selected.zip", team=6, runs=["results/ss/candidate"])
            with zipfile.ZipFile(temp / "selected.zip") as archive:
                self.assertIn("midterm-team-6/results/ss/candidate/summary.rpt", archive.namelist())
                self.assertIn("midterm-team-6/results/ss/candidate/activity.vcd.gz", archive.namelist())
            alias = temp / "output-alias"
            alias.symlink_to(root / "rtl", target_is_directory=True)
            with self.assertRaises(ValueError):
                export(root, alias / "must-not-write.zip", team=6)
            for selection in ["../outside", "rtl", "/etc"]:
                with self.assertRaises(ValueError):
                    export(root, temp / "bad.zip", team=6, runs=[selection])
            (run / "licensed.db").write_bytes(b"do not redistribute")
            with self.assertRaises(ValueError):
                export(root, temp / "licensed.zip", team=6, runs=["results/ss/candidate"])
            (run / "licensed.db").unlink()
            (run / ".env").write_text("TEST_ONLY_PLACEHOLDER=1\n")
            with self.assertRaises(ValueError):
                export(root, temp / "credentials.zip", team=6, runs=["results/ss/candidate"])
            (run / ".env").unlink()
            (run / "outside-link").symlink_to(temp)
            with self.assertRaises(ValueError):
                export(root, temp / "symlink.zip", team=6, runs=["results/ss/candidate"])


if __name__ == "__main__":
    unittest.main()
