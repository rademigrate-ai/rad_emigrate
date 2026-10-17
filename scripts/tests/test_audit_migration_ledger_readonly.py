import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "audit_migration_ledger_readonly.py"
spec = importlib.util.spec_from_file_location("rad_migrations", SCRIPT)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class LedgerGateTests(unittest.TestCase):
    def test_matching_ids_are_not_claimed_sql_equal(self):
        result = m.compare([{"version": "20261001191421", "name": "initial"}],
                           [{"version": "20261001191421", "name": "initial"}])
        self.assertEqual(result["status"], "LEDGER_IDS_MATCH_SCHEMA_STILL_UNVERIFIED")

    def test_version_alias_and_unknown_names_are_blockers(self):
        live = [{"version": "20261001191421", "name": "same"},
                {"version": "20261001191653", "name": "alias"},
                {"version": "20261001194638", "name": "remote_only"}]
        repo = [{"version": "20261001191421", "name": "same"},
                {"version": "20261002000000", "name": "alias"},
                {"version": "20261003000000", "name": "repo_only"}]
        x = m.compare(live, repo)
        self.assertEqual(x["status"], "NO_GO")
        self.assertEqual([len(x[k]) for k in ("version_aliases","live_only","repo_only")],[1,1,1])

    def test_duplicate_ledger_ids_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "Duplicate version"):
            m.compare([{"version": "20261001191421", "name": "a"},
                       {"version": "20261001191421", "name": "b"}], [])
        with self.assertRaisesRegex(ValueError, "Duplicate name"):
            m.compare([], [{"version": "20261001191421", "name": "a"},
                           {"version": "20261001191653", "name": "a"}])

    def test_live_snapshot_still_fails_closed_and_does_not_write(self):
        root = SCRIPT.parent.parent
        path = root / "supabase/reconciliation/rad_live_migrations_observed_20261018.json"
        before = path.read_bytes()
        result = m.compare(m.load_live(path), m.load_repo(root))
        self.assertEqual(result["live_count"], 47)
        self.assertGreaterEqual(result["repo_count"], 47)
        self.assertEqual(result["exact_version_and_name"], 27)
        self.assertEqual(len(result["version_aliases"]), 16)
        self.assertEqual(len(result["live_only"]), 4)
        self.assertGreaterEqual(len(result["repo_only"]), 4)
        p = subprocess.run([sys.executable,str(SCRIPT),"--live",str(path),
                            "--repo-root",str(root),"--baseline",str(path)],
                           capture_output=True,text=True)
        self.assertEqual(p.returncode,2)
        self.assertEqual(json.loads(p.stdout)["status"],"NO_GO")
        self.assertEqual(path.read_bytes(),before)


if __name__ == "__main__":
    unittest.main()
