"""Tests for the read-only, non-certifying portability inventory."""

import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from scripts.self_host_portability_inventory import inspect


class SelfHostPortabilityInventoryTest(unittest.TestCase):
    def test_inventory_counts_gates_and_never_reports_release_ready(self):
        with TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "pubspec.yaml").write_text("name: rad_emigrate\n", encoding="utf-8")
            (root / "supabase").mkdir()
            (root / "supabase/config.toml").write_text(
                'project_id = "rad_emigrate"\n[db]\nmajor_version = 17\n', encoding="utf-8"
            )
            migration = root / "supabase/migrations"
            migration.mkdir()
            (migration / "20261104000000_test.sql").write_text("select 1;", encoding="utf-8")
            functions = root / "supabase/functions/research-sync"
            functions.mkdir(parents=True)
            (functions / "index.ts").write_text("export default {};", encoding="utf-8")
            (root / "lib").mkdir()
            (root / "lib/main.dart").write_text(
                'const endpoint = "https://sample-ref.supabase.co";', encoding="utf-8"
            )
            (root / "lib/test").mkdir()
            (root / "lib/test/ignored.dart").write_text(
                'const fake = "https://fixture.supabase.co";', encoding="utf-8"
            )
            gates_path = root / "docs/master_execution/acceptance_gates.json"
            gates_path.parent.mkdir(parents=True)
            gates_path.write_text(
                json.dumps({"date": "2026-10-31", "gates": [
                    {"status": "VERIFIED_PASS"}, {"status": "BLOCKED_EXTERNAL"}
                ]}), encoding="utf-8"
            )

            report = inspect(root)
            self.assertEqual(report["migration_count"], 1)
            self.assertEqual(report["edge_functions"], ["research-sync"])
            self.assertTrue(report["postgres17_local_configured"])
            self.assertEqual(report["gate_ledger"]["count"], 2)
            self.assertEqual(report["gate_ledger"]["by_status"]["BLOCKED_EXTERNAL"], 1)
            self.assertEqual(
                report["runtime_source_paths_with_literal_managed_supabase_urls"],
                ["lib/main.dart"],
            )
            self.assertFalse(report["self_hosted_deployment_manifest_exists"])
            self.assertIn("NOT_RELEASE_CERTIFICATION", report["classification"])
            self.assertNotIn("sample-ref.supabase.co", json.dumps(report))

    def test_rejects_wrong_root(self):
        with TemporaryDirectory() as temp:
            with self.assertRaises(ValueError):
                inspect(Path(temp))


if __name__ == "__main__":
    unittest.main()
