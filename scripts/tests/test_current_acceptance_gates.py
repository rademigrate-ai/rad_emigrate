"""Retain every employer requirement and its distinct acceptance boundary."""

import json
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class CurrentGateLedger(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ledger = json.loads(
            (ROOT / "docs/master_execution/acceptance_gates.json").read_text("utf8")
        )

    def test_all_original_gates_keep_backend_ui_authorization_and_missing_tests(self):
        gates = self.ledger["gates"]
        self.assertEqual(sorted(row["id"] for row in gates), list(range(1, 48)))
        for row in gates:
            with self.subTest(gate=row["id"]):
                self.assertEqual(row["original_requirement"], row["acceptance"])
                for key in (
                    "required_backend",
                    "required_ui",
                    "required_authorization",
                    "missing_implementation_or_decision",
                    "missing_tests",
                    "actual_acceptance_result",
                    "evidence_scope",
                ):
                    self.assertTrue(row[key].strip(), key)
                for path in row["existing_tests"]:
                    self.assertTrue((ROOT / path).exists(), path)

    def test_status_counts_are_exact_and_no_release_exclusion_is_invented(self):
        rows = self.ledger["gates"]
        counted = Counter(row["status"] for row in rows)
        self.assertEqual(dict(counted), self.ledger["status_counts"])
        self.assertTrue(set(counted) <= set(self.ledger["allowed_current_statuses"]))
        for row in rows:
            if row["status"] == "NOT_IN_APPROVED_RELEASE_SCOPE":
                self.assertTrue(row.get("owner_scope_approval_reference"))

    def test_unimplemented_work_and_local_evidence_do_not_claim_release_go(self):
        if any(row["status"] == "NOT_IMPLEMENTED" for row in self.ledger["gates"]):
            self.assertTrue(self.ledger["overall_verdict"].startswith("NO-GO"))
        self.assertFalse(self.ledger["owner_constraints"]["paid_calls"])
        self.assertIn("AUTHORIZED", self.ledger["owner_constraints"]["browser_e2e"])
