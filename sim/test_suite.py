"""Software-only checks: no simulator, PDK, cocotb, or third-party package needed."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from sw.golden import encode, execute
from sim.cases import Program, branch_program, generate_cases, matadd_program, matmul_program
from sim.run import classify, export_cases
from sim import run as runner
from sim.cases import generate_a1_cases, SUITES
from sim import compare_cycles


class GoldenTests(unittest.TestCase):
    def test_kernel_assembly_matches_existing_binary_vectors(self):
        self.assertEqual(matadd_program(8), [0x50DE, 0x300F, 0x9100, 0x9208,
                         0x9310, 0x3410, 0x7440, 0x3520, 0x7550, 0x3645,
                         0x3730, 0x8076, 0xF000])
        self.assertEqual(matmul_program(), [0x50DE, 0x300F, 0x9101, 0x9202,
                         0x9300, 0x9404, 0x9508, 0x6602, 0x5762, 0x4707,
                         0x9800, 0x9900, 0x5A62, 0x3AA9, 0x3AA3, 0x7AA0,
                         0x5B92, 0x3BB7, 0x3BB4, 0x7BB0, 0x5CAB, 0x388C,
                         0x3991, 0x2092, 0x180C, 0x3950, 0x8098, 0xF000])

    def test_instruction_encoding_matches_published_kernels(self):
        # Catches swapped source fields and STR's nonstandard source placement.
        self.assertEqual(encode("MUL", 0, 13, 14), 0x50DE)
        self.assertEqual(encode("STR", rs=7, rt=6), 0x8076)
        self.assertEqual(encode("CONST", 1, immediate=255), 0x91FF)
        self.assertEqual(encode("BR", mask=4, immediate=12), 0x180C)
        with self.assertRaises(ValueError):
            encode("CONST", 1, immediate=256)

    def test_arithmetic_wraps_and_division_is_unsigned(self):
        program = [0x91FF, 0x9202, 0x3312, 0x4412, 0x5511, 0x6612,
                   0x9700, 0x8073, 0x9701, 0x8074, 0x9702, 0x8075,
                   0x9703, 0x8076, 0xF000]
        result = execute(program, [0] * 256, 1)
        self.assertEqual(result.memory[:4], [1, 253, 1, 127])
        self.assertEqual(result.writes, {0: 1, 1: 1, 2: 1, 3: 1})

    def test_branch_uses_nzp_not_reversed_flags(self):
        # Each taken BR skips a poison value, with flags refreshed by CMP.
        for a, b, mask in [(0, 255, 4), (17, 17, 2), (255, 0, 1)]:
            with self.subTest(a=a, b=b):
                p = [encode("CONST", 1, immediate=a),
                     encode("CONST", 2, immediate=b), encode("CMP", rs=1, rt=2),
                     encode("BR", mask=mask, immediate=6),
                     encode("CONST", 3, immediate=99), encode("RET"),
                     encode("CONST", 3, immediate=42),
                     encode("CONST", 4, immediate=200),
                     encode("STR", rs=4, rt=3), encode("RET")]
                self.assertEqual(execute(p, [0] * 256, 1).memory[200], 42)

    def test_untaken_branch_falls_through(self):
        self.assertEqual(execute(branch_program(255, 0, 4), [0]*256, 4).memory[200:204],
                         [17, 17, 17, 17])
        self.assertEqual(execute(branch_program(0, 255, 4), [0]*256, 4).memory[200:204],
                         [231, 231, 231, 231])

    def test_assembler_rejects_unresolved_and_duplicate_labels(self):
        p = Program()
        p.branch(4, "missing")
        with self.assertRaises(ValueError):
            p.finish()
        p.label("missing")
        with self.assertRaises(ValueError):
            p.label("missing")

    def test_metadata_is_read_only_and_partial_blocks_use_active_threads(self):
        p = [encode("CONST", 15, immediate=77), encode("CONST", 13, immediate=88),
             encode("MUL", 0, 13, 14), encode("ADD", 0, 0, 15),
             encode("CONST", 1, immediate=200), encode("ADD", 1, 1, 0),
             encode("STR", rs=1, rt=0), encode("RET")]
        result = execute(p, [170] * 256, 7)
        self.assertEqual(result.memory[200:208], [0, 1, 2, 3, 4, 5, 6, 170])
        self.assertEqual(sum(result.writes.values()), 7)

    def test_invalid_division_and_nontermination_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "zero"):
            execute([0x6100, 0xF000], [0] * 256, 1)
        with self.assertRaisesRegex(ValueError, "budget"):
            execute([0x2000, 0x1400], [0] * 256, 1, max_steps=10)

    def test_divergent_branches_and_cross_thread_races_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "diverg"):
            execute([0x20F0, 0x1404, 0x0000, 0xF000, 0xF000], [0] * 256, 4)
        with self.assertRaisesRegex(ValueError, "conflict"):
            execute([0x800F, 0xF000], [0] * 256, 4)


class GeneratorTests(unittest.TestCase):
    def test_backpressure_trials_use_distinct_recorded_delay_seeds(self):
        cases = [c for c in generate_cases(trials=100) if c.family == "R10"]
        seeds = [getattr(c, "delay_seed", None) for c in cases]
        self.assertEqual(len(set(seeds)), 100)
        self.assertEqual(seeds, [getattr(c, "delay_seed", None)
                                for c in generate_cases(trials=100) if c.family == "R10"])

    def test_all_twenty_families_are_distinct_and_reproducible(self):
        a = generate_cases(trials=2)
        b = generate_cases(trials=2)
        self.assertEqual(a, b)
        self.assertEqual({c.family for c in a},
                         {f"R{i:02d}" for i in range(1, 11)} |
                         {f"C{i:02d}" for i in range(1, 11)})
        self.assertEqual(len({c.name for c in a}), len(a))
        for i in range(1, 11):
            self.assertEqual(sum(c.family == f"R{i:02d}" for c in a), 2)
        self.assertNotEqual([c for c in a if c.family == "R01"],
                            [c for c in generate_cases(trials=2, seed_offset=1)
                             if c.family == "R01"])

    def test_matrix_vectors_match_independent_mathematics(self):
        for c in generate_cases(trials=3):
            if c.family in {"R01", "R02", "R03"}:
                n = c.threads
                expected = [(c.memory[i] + c.memory[n+i]) % 256 for i in range(n)]
                self.assertEqual(c.expected[2*n:3*n], expected)
            if c.family in {"R04", "R05"}:
                a, b = c.memory[:4], c.memory[4:8]
                expected = [(a[2*r]*b[col] + a[2*r+1]*b[col+2]) % 256
                            for r in range(2) for col in range(2)]
                self.assertEqual(c.expected[8:12], expected)

    def test_corner_fixtures_check_boundaries_and_reset_modes(self):
        cases = generate_cases(trials=1)
        lookup = {c.name: c for c in cases}
        self.assertEqual(lookup["C04_add_wrap"].expected[200:204], [0, 0, 0, 0])
        self.assertEqual(lookup["C04_sub_wrap"].expected[200:204], [255]*4)
        self.assertEqual(lookup["C05_max_product"].expected[200:204], [1]*4)
        self.assertEqual({c.reset_kind for c in cases if c.family == "C10"}, {1, 2})
        self.assertTrue(any(c.family == "C01" and c.threads == 1 for c in cases))
        empty = next(c for c in cases if c.family == "C02")
        self.assertEqual(empty.writes, {})
        self.assertEqual(empty.expected, empty.memory)

    def test_export_is_complete_and_never_claims_dut_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "vectors"
            manifest = export_cases(generate_cases(trials=1), out)
            self.assertEqual(manifest["dut_status"], "not_run")
            sources = manifest.get("verification_sources", [])
            self.assertIn("sim/tb_regression.v", [s["path"] for s in sources])
            self.assertIn("sw/golden.py", [s["path"] for s in sources])
            for c in manifest["cases"]:
                self.assertEqual(c["status"], "not_run")
                folder = out / c["name"]
                self.assertEqual(len((folder / "program.hex").read_text().splitlines()), 256)
                self.assertEqual(len((folder / "expected.hex").read_text().splitlines()), 256)
                self.assertEqual(len((folder / "writes.hex").read_text().splitlines()), 256)
            with self.assertRaises(FileExistsError):
                export_cases(generate_cases(trials=1), out)

    def test_generate_cli_needs_no_hardware_tools(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "vectors"
            proc = subprocess.run([sys.executable, "-m", "sim.run", "--mode", "generate",
                                   "--trials", "1", "--out", str(out)],
                                  capture_output=True, text=True, timeout=30,
                                  env=dict(os.environ, PATH=""))
            self.assertEqual(proc.returncode, 0, proc.stderr)
            manifest = json.loads((out / "manifest.json").read_text())
            self.assertEqual(manifest["dut_status"], "not_run")

    def test_invalid_generation_inputs_fail_before_creating_output(self):
        with self.assertRaises(ValueError):
            generate_cases(trials=0)

    def test_cli_rejects_unknown_case_without_silently_running_full_suite(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "vectors"
            proc = subprocess.run([sys.executable, "-m", "sim.run", "--case", "typo",
                                   "--trials", "1", "--out", str(out)],
                                  capture_output=True, text=True, timeout=30)
            self.assertNotEqual(proc.returncode, 0)
            self.assertFalse(out.exists())

    def test_simulation_preflight_failure_is_error_not_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "vectors"
            proc = subprocess.run([sys.executable, "-m", "sim.run", "--mode", "rtl",
                                   "--rtl", str(Path(tmp)/"absent.v"), "--case", "C02",
                                   "--trials", "1", "--out", str(out)],
                                  capture_output=True, text=True, timeout=30,
                                  env=dict(os.environ, PATH=""))
            self.assertNotEqual(proc.returncode, 0)
            manifest = json.loads((out / "manifest.json").read_text())
            self.assertEqual(manifest["dut_status"], "error")
            self.assertTrue(all(c["status"] == "not_run" for c in manifest["cases"]))


class ResultTests(unittest.TestCase):
    def test_timeout_diagnostics_keep_partial_stdout_and_stderr(self):
        error = subprocess.TimeoutExpired(["simulator"], 1,
                                          output=b"last transaction at PC 12\n",
                                          stderr=b"pending read\n")
        formatter = getattr(runner, "timeout_output", lambda e, stage: "")
        output = formatter(error, "simulation")
        self.assertIn("last transaction at PC 12", output)
        self.assertIn("pending read", output)
        self.assertEqual(classify(1, output, "C01"), "fail")

    def test_only_explicit_clean_matching_completion_is_pass(self):
        self.assertEqual(classify(0, "PASS R01_0000 cycles=42\n", "R01_0000"), "pass")
        for code, text in [(1, "PASS R01_0000 cycles=42\n"),
                           (0, ""), (0, "PASS other cycles=42\n"),
                           (0, "FAIL mismatch\nPASS R01_0000 cycles=42\n"),
                           (0, "PASS R01_0000 cycles=42\nFATAL: late error\n")]:
            with self.subTest(code=code, text=text):
                self.assertEqual(classify(code, text, "R01_0000"), "fail")


class A1Tests(unittest.TestCase):
    """A1 (WAIT bypass): golden counters, suite generation, and the cycle comparator."""

    def test_golden_counts_match_midterm_estimates(self):
        mm = execute(matmul_program(), [0] * 256, 4)
        self.assertEqual((mm.retired, mm.memory_ops, mm.non_memory_ops()), ([41], [5], [36]))
        ma = execute(matadd_program(8), [0] * 256, 8)
        self.assertEqual((ma.retired, ma.memory_ops, ma.non_memory_ops()),
                         ([13, 13], [3, 3], [10, 10]))
        self.assertEqual(execute([0xF000], [0] * 256, 0).retired, [])

    def test_counters_do_not_change_functional_results(self):
        for c in generate_cases(trials=1):
            ref = execute(c.program, c.memory, c.threads)
            self.assertEqual((ref.memory, ref.writes), (c.expected, c.writes))

    def test_a1_suite_has_ten_distinct_reproducible_families(self):
        a, b = generate_a1_cases(trials=2), generate_a1_cases(trials=2)
        self.assertEqual(a, b)
        self.assertEqual({c.family for c in a}, {"A1_%02d" % i for i in range(1, 11)})
        self.assertEqual(len({c.name for c in a}), len(a))
        midterm = {c.name for c in generate_cases(trials=2)}
        self.assertFalse(midterm & {c.name for c in a})
        self.assertNotEqual([c for c in a if c.family == "A1_01"],
                            [c for c in generate_a1_cases(trials=2, seed_offset=1)
                             if c.family == "A1_01"])
        self.assertEqual(len(SUITES["all"](2)), len(generate_cases(2)) + len(a))

    def test_a1_cases_exercise_both_paths(self):
        for c in generate_a1_cases(trials=3):
            with self.subTest(case=c.name):
                self.assertEqual(len(c.retired), (c.threads + 3) // 4)
                self.assertTrue(all(r > m for r, m in zip(c.retired, c.memory_ops)))
                if c.family not in {"A1_01", "A1_05", "A1_06"}:
                    self.assertTrue(all(m > 0 for m in c.memory_ops), "no memory op")
        families = {c.family: c for c in generate_a1_cases(trials=1)}
        self.assertEqual(families["A1_01"].memory_ops, [8])          # signatures only
        self.assertEqual(families["A1_07"].delay_max, 8)
        resets = {c.reset_kind for c in generate_a1_cases(1) if c.family == "A1_09"}
        self.assertEqual(resets, {1, 2})

    def _manifest(self, rows):
        cases = []
        for name, threads, dmax, reset, base, opt in rows:
            cases.append({"name": name, "family": name[:5], "threads": threads,
                          "delay_min": 1, "delay_max": dmax, "reset_kind": reset,
                          "retired": [10], "memory_ops": [3], "status": "pass",
                          "cycles": base if opt is None else opt})
        return {"mode": "rtl", "cases": cases}

    def test_compare_cycles_rules(self):
        base = self._manifest([("A1_01_a", 4, 1, 0, 100, None), ("A1_08_b", 8, 1, 0, 100, None),
                               ("A1_07_c", 4, 8, 0, 100, None), ("A1_09_d", 4, 8, 1, 100, None)])
        good = self._manifest([("A1_01_a", 4, 1, 0, 0, 93), ("A1_08_b", 8, 1, 0, 0, 99),
                               ("A1_07_c", 4, 8, 0, 0, 120), ("A1_09_d", 4, 8, 1, 0, 140)])
        rows, violations = compare_cycles.compare(base, good)
        self.assertEqual(violations, [])
        self.assertEqual([r["rule"] for r in rows], ["exact", "functional", "faster", "functional"])  # sorted by name
        off_by_one = self._manifest([("A1_01_a", 4, 1, 0, 0, 94), ("A1_08_b", 8, 1, 0, 0, 100),
                                     ("A1_07_c", 4, 8, 0, 0, 1), ("A1_09_d", 4, 8, 1, 0, 1)])
        _, violations = compare_cycles.compare(base, off_by_one)
        self.assertEqual(len(violations), 2)
        failed = self._manifest([("A1_01_a", 4, 1, 0, 0, 93), ("A1_08_b", 8, 1, 0, 0, 99),
                                 ("A1_07_c", 4, 8, 0, 0, 1), ("A1_09_d", 4, 8, 1, 0, 1)])
        failed["cases"][2]["status"] = "fail"
        self.assertEqual(len(compare_cycles.compare(base, failed)[1]), 1)
        with self.assertRaises(ValueError):
            compare_cycles.compare(base, {"mode": "rtl", "cases": good["cases"][:2]})
        zero_b = self._manifest([("C02_z", 0, 1, 0, 1, None)])
        rows, violations = compare_cycles.compare(zero_b, self._manifest([("C02_z", 0, 1, 0, 0, 1)]))
        self.assertEqual((rows[0]["rule"], violations), ("equal", []))
        self.assertEqual(len(compare_cycles.compare(
            zero_b, self._manifest([("C02_z", 0, 1, 0, 0, 2)]))[1]), 1)


if __name__ == "__main__":
    unittest.main()
