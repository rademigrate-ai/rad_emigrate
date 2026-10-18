"""Fail-closed regression checks for the 47-gate master acceptance evidence.

No network, repository writes, production calls or external service access.
"""
from collections import Counter
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs"
LEDGER = DOCS / "RAD_47_TASK_MASTER_LEDGER.md"
FILES = [
    "RAD_47_TASK_MASTER_LEDGER.md",
    "RAD_FEATURE_ACCEPTANCE_MATRIX.md",
    "RAD_SECURITY_AND_MIGRATION_REPORT.md",
    "RAD_E2E_QA_REPORT.md",
    "RAD_RELEASE_READINESS.md",
]
ALLOWED = {
    "NOT_STARTED", "IN_PROGRESS", "IMPLEMENTED",
    "VERIFIED_PASS", "BLOCKED", "FAILED",
}
ROW = re.compile(
    r"^\|\s*(\d{2})\s*\|\s*([^|]+)\|\s*"
    r"(NOT_STARTED|IN_PROGRESS|IMPLEMENTED|VERIFIED_PASS|BLOCKED|FAILED)"
    r"\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|",
    re.MULTILINE,
)


class AcceptanceLedgerIntegrity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ledger = LEDGER.read_text(encoding="utf-8")
        cls.rows = ROW.findall(cls.ledger)

    def test_all_47_unique_canonical_gates_and_nonempty_targets(self):
        self.assertEqual(len(self.rows), 47)
        self.assertEqual(
            sorted(int(row[0]) for row in self.rows),
            list(range(1, 48)),
        )
        for no, name, status, criteria, source, evidence in self.rows:
            with self.subTest(gate=no):
                self.assertTrue(name.strip())
                self.assertTrue(criteria.strip())
                self.assertTrue(source.strip())
                self.assertTrue(evidence.strip())
                self.assertIn(status, ALLOWED)

    def test_only_three_documentary_gates_accepted_from_canonical_issue(self):
        passing = [int(row[0]) for row in self.rows if row[2] == "VERIFIED_PASS"]
        self.assertEqual(passing, [1, 3, 5])
        self.assertIn("only **3/47**", self.ledger)

    def test_summary_counts_consistent_and_every_other_gate_unverified(self):
        counts = Counter(row[2] for row in self.rows)
        self.assertEqual(sum(counts.values()), 47)
        self.assertEqual(counts["VERIFIED_PASS"], 3)
        self.assertEqual(sum(counts[x] for x in ALLOWED - {"VERIFIED_PASS"}), 44)
        summary = next(
            s for s in self.ledger.splitlines() if s.startswith("**Counts:**")
        )
        for kind, amount in counts.items():
            self.assertIn(f"{kind} {amount}", summary)

    def test_five_required_evidence_documents_are_real_and_production_no_go(self):
        for filename in FILES:
            path = DOCS / filename
            with self.subTest(file=filename):
                self.assertTrue(path.is_file())
                content = path.read_text(encoding="utf-8")
                self.assertGreater(len(content), 500)
        self.assertIn("NO-GO", (DOCS / "RAD_RELEASE_READINESS.md").read_text(encoding="utf-8"))
        self.assertIn("47", (DOCS / "RAD_SECURITY_AND_MIGRATION_REPORT.md").read_text(encoding="utf-8"))

    def test_no_fictional_full_acceptance(self):
        self.assertNotIn("47/47 VERIFIED_PASS", self.ledger)
        self.assertIn("client", (DOCS / "RAD_RELEASE_READINESS.md").read_text(encoding="utf-8").lower())


if __name__ == "__main__":
    unittest.main()
