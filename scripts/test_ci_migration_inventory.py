"""Prevent CI replay from silently omitting newly committed migrations."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class MigrationInventoryTest(unittest.TestCase):
    def test_reconstruction_inventory_and_execution_match_exact_lineage(self):
        script = (ROOT / "scripts/verify_migration_reconstruction.sh").read_text()
        listed = re.findall(r"    '(\d{14}_[^']+\.sql)',", script)
        executed = re.findall(r'  "\$backup/(\d{14}_[^"]+\.sql)"', script)
        historical = {p.name for p in (ROOT / "supabase/reconciliation/candidate").glob("*.sql")}
        active = {p.name for p in (ROOT / "supabase/migrations").glob("*.sql")}
        self.assertEqual(set(listed), active - historical)
        self.assertEqual(executed, sorted(listed))
        self.assertEqual(len(listed), len(set(listed)))

    def test_clean_schema_requires_owner_update_policy(self):
        script = (ROOT / "scripts/verify_clean_schema.sh").read_text()
        self.assertIn("storage_policy_count <> 4", script)
        self.assertIn('"policies":"5b8620228bf8c9346092eb66f1afa4cb"', script)

    def test_auth_harness_uses_rpc_and_tests_direct_insert_denial(self):
        script = (ROOT / "scripts/verify_local_auth_isolation.py").read_text()
        self.assertIn('"/rest/v1/rpc/submit_consultation_request"', script)
        self.assertIn('label="consultation direct INSERT must stay forbidden"', script)


if __name__ == "__main__":
    unittest.main()
