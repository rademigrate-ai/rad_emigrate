"""Pure, reproducible tests for the read-only recorded-SQL hash audit."""
import importlib.util
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "verify_live_migration_sql_fingerprints.py"
OBSERVED = ROOT / "supabase" / "reconciliation" / "production_statement_fingerprints_20261018.json"
spec = importlib.util.spec_from_file_location("sqlfingerprints", SCRIPT)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class RecordedSQLFingerprintsTests(unittest.TestCase):
    def test_known_production_snapshot_is_no_go_not_a_release_gate(self):
        baseline = json.loads(OBSERVED.read_text(encoding="utf-8"))
        result = mod.inspect(ROOT, baseline)
        self.assertEqual(result["status"], "NO_GO")
        self.assertEqual(result["baseline_live_count"], 47)
        self.assertGreaterEqual(result["repo_migration_count"], 52)
        self.assertEqual(len(result["results"]), 47)
        self.assertEqual(result["match_counts"]["NO_REPO_NAME"], 4)
        self.assertEqual(result["version_alias_count"], 16)
        self.assertGreater(result["match_counts"]["FINGERPRINT_MATCH"], 0)

    def test_sql_hash_comparison_handles_only_trailing_whitespace(self):
        a = hashlib.md5("select 1;\n".encode()).hexdigest()
        b = hashlib.md5("select 1;".encode()).hexdigest()
        self.assertIn(a, mod.variants("select 1;\n"))
        self.assertIn(b, mod.variants("select 1;\n"))
        self.assertNotIn(hashlib.md5("select 2;".encode()).hexdigest(), mod.variants("select 1;"))

    def test_duplicate_observed_names_and_versions_fail_closed(self):
        row = {"name": "x", "version": "20261001000000", "statement_count": 1}
        with self.assertRaisesRegex(ValueError, "duplicate observed migration versions"):
            mod.inspect(ROOT, {"rows": [row, dict(row)]})
        with self.assertRaisesRegex(ValueError, "duplicate observed migration names"):
            mod.inspect(ROOT, {"rows": [row, dict(row, version="20261001000001")]})

    def test_audit_does_not_mutate_sql_or_input_file(self):
        before = OBSERVED.read_bytes()
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), "--repo-root", str(ROOT),
             "--observed", str(OBSERVED)],
            capture_output=True, text=True, check=False
        )
        self.assertEqual(completed.returncode, 2)
        result = json.loads(completed.stdout)
        self.assertEqual(result["status"], "NO_GO")
        self.assertEqual(OBSERVED.read_bytes(), before)
        self.assertNotIn("CREATE OR REPLACE FUNCTION", completed.stdout)


if __name__ == "__main__":
    unittest.main()
