"""Offline layout checks. Never invoke an HDL or licensed toolchain."""

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


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


if __name__ == "__main__":
    unittest.main()
