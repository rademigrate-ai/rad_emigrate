from __future__ import annotations

import argparse
import json
import pathlib
import tempfile
import unittest


TOOLS = pathlib.Path(__file__).resolve().parent
REPO = TOOLS.parents[1]

import operator_preflight as preflight
import review_workflow as reviews
import validate_visa_drafts as visa_validation


class TestReviewDecisionValidation(unittest.TestCase):
    def setUp(self):
        self.source = {
            "schema_version": reviews.SCHEMA_VERSION,
            "item_type": "regulatory_claim",
            "item_id": "claim:occurrence",
            "source_record_sha256": "a" * 64,
            "source": {"evidence_urls": ["https://rad.example/evidence"]},
            "official_evidence": {"urls": ["https://gov.example/rule"]},
        }

    def row(self, status: str = "rejected"):
        return {
            "schema_version": reviews.SCHEMA_VERSION,
            "item_type": self.source["item_type"],
            "item_id": self.source["item_id"],
            "source_record_sha256": self.source["source_record_sha256"],
            "decision": {
                "schema_version": reviews.DECISION_SCHEMA_VERSION,
                "status": status,
                "reviewer": {"id": "reviewer-1", "display_name": "Reviewer One"},
                "reviewed_at": "2026-10-12T08:00:00+03:30",
                "rationale": "The source is outdated and must not be used.",
                "evidence_checked": ["https://rad.example/evidence"],
                "official_evidence_checked": ["https://gov.example/rule"],
                "proposed_correction": None,
            },
        }

    def test_rejected_decision_stays_non_publishable(self):
        normalized = reviews.validate_decision_row(self.row(), self.source)
        self.assertEqual(normalized["status"], "rejected")
        self.assertFalse(normalized["safety"]["publication_allowed"])
        self.assertFalse(normalized["safety"]["production_write_allowed"])
        self.assertEqual(normalized["reviewer"]["id"], "reviewer-1")

    def test_approval_requires_official_evidence_check(self):
        row = self.row("approved")
        row["decision"]["official_evidence_checked"] = []
        with self.assertRaisesRegex(ValueError, "official URL"):
            reviews.validate_decision_row(row, self.source)

    def test_unknown_evidence_url_rejected(self):
        row = self.row()
        row["decision"]["evidence_checked"] = ["https://attacker.example/not-exported"]
        with self.assertRaisesRegex(ValueError, "outside the export"):
            reviews.validate_decision_row(row, self.source)

    def test_unreviewed_cannot_impersonate_reviewer(self):
        row = self.row("unreviewed")
        with self.assertRaisesRegex(ValueError, "cannot carry reviewer"):
            reviews.validate_decision_row(row, self.source)

    def test_import_records_audit_and_safe_rejection_queue(self):
        with tempfile.TemporaryDirectory() as temp:
            exchange = pathlib.Path(temp)
            export = exchange / "P0_REVIEW_EXPORT.jsonl"
            reviews._write_jsonl_atomic(export, [self.source])
            reviews._write_json_atomic(
                exchange / "REVIEW_EXPORT_MANIFEST.json",
                {
                    "schema_version": reviews.SCHEMA_VERSION,
                    "export": {
                        "file": export.name,
                        "sha256": reviews._sha256_file(export),
                    },
                },
            )
            incoming = exchange / "incoming.jsonl"
            reviews._write_jsonl_atomic(incoming, [self.row("rejected")])
            args = argparse.Namespace(exchange=exchange, input=incoming)
            self.assertEqual(reviews.import_decisions(args), 0)
            current = reviews._jsonl(exchange / "CURRENT_DECISIONS.jsonl")
            audit = reviews._jsonl(exchange / "REVIEW_AUDIT.jsonl")
            rejected = reviews._jsonl(exchange / "REJECTED_OR_UNRESOLVED.jsonl")
            self.assertEqual([row["status"] for row in current], ["rejected"])
            self.assertEqual(len(audit), 1)
            self.assertEqual(len(rejected), 1)
            self.assertFalse(current[0]["safety"]["publication_allowed"])
            # Re-import is idempotent and creates no duplicate audit event.
            self.assertEqual(reviews.import_decisions(args), 0)
            self.assertEqual(len(reviews._jsonl(exchange / "REVIEW_AUDIT.jsonl")), 1)


class TestReviewExchangeRealData(unittest.TestCase):
    @unittest.skipUnless((REPO / "artifacts/stage3_review_queues_20261012").exists(), "Stage 3 queues missing")
    def test_p0_export_is_grouped_linked_and_unapproved(self):
        with tempfile.TemporaryDirectory() as temp:
            args = argparse.Namespace(
                regulatory_queue=REPO / "artifacts/stage3_review_queues_20261012/REGULATORY_REVIEW_QUEUE.jsonl",
                visa_queue=REPO / "artifacts/stage3_review_queues_20261012/VISA_DRAFT_REVIEW_QUEUE.jsonl",
                duplicate_map=REPO / "artifacts/stage3_canonical_dataset_20261011/DUPLICATE_CANONICAL_MAP.json",
                official_findings=REPO / "artifacts/stage3_regulatory_verification_20261011/OFFICIAL_SOURCE_FINDINGS_20261011.json",
                priority=["P0_disposition_required"],
                out=temp,
            )
            self.assertEqual(reviews.export_exchange(args), 0)
            rows = reviews._jsonl(pathlib.Path(temp) / "P0_REVIEW_EXPORT.jsonl")
            claims = [row for row in rows if row["item_type"] == "regulatory_claim"]
            visas = [row for row in rows if row["item_type"] == "visa_draft"]
            self.assertEqual(sum(row.get("identical_ledger_occurrences", 1) for row in claims), 3128)
            self.assertEqual(len(visas), 14)
            self.assertEqual(len(rows), len({(row["item_type"], row["item_id"]) for row in rows}))
            self.assertTrue(any(row["duplicate_group_id"] for row in claims))
            self.assertTrue(any(row["official_evidence"]["urls"] for row in rows))
            self.assertTrue(all(row["decision"]["status"] == "unreviewed" for row in rows))
            self.assertTrue(all(not row["safety"]["publication_allowed"] for row in rows))


class TestVisaValidationRealData(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        visa_dir = REPO / "artifacts/stage3_visa_coverage_20261011"
        queue_path = REPO / "artifacts/stage3_review_queues_20261012/VISA_DRAFT_REVIEW_QUEUE.jsonl"
        if not visa_dir.exists() or not queue_path.exists():
            raise unittest.SkipTest("Stage 3 Visa artifacts missing")
        queue = [json.loads(line) for line in queue_path.read_text(encoding="utf-8").splitlines() if line.strip()]
        cls.report = visa_validation.validate(
            json.loads((visa_dir / "VISA_INITIALIZATION_PACKAGE.json").read_text(encoding="utf-8")),
            json.loads((visa_dir / "VISA_COVERAGE_REPORT.json").read_text(encoding="utf-8")),
            queue,
        )

    def test_all_165_drafts_are_deterministically_covered(self):
        self.assertEqual(self.report["summary"]["drafts"], 165)
        self.assertEqual(len({row["program_slug"] for row in self.report["drafts"]}), 165)

    def test_placeholders_are_not_treated_as_complete_requirements(self):
        counts = self.report["summary"]["issue_counts"]
        self.assertEqual(counts["PLACEHOLDER_REQUIREMENT"], 165)
        self.assertEqual(counts["PLACEHOLDER_STEP"], 165)
        self.assertEqual(self.report["summary"]["correction_required"], 165)

    def test_official_evidence_and_publication_gate(self):
        self.assertEqual(self.report["summary"]["with_official_evidence"], 48)
        self.assertEqual(self.report["summary"]["automatic_approvals"], 0)
        self.assertTrue(all(not row["publication_allowed"] for row in self.report["drafts"]))


class TestOperatorPreflightPrimitives(unittest.TestCase):
    def test_committed_manifests_verify(self):
        package = REPO / "artifacts/stage3_ingestion_package_20261012"
        canonical = REPO / "artifacts/stage3_canonical_dataset_20261011"
        ok, _, failures = preflight._check_package_manifest(REPO, package / "PACKAGE_MANIFEST.json")
        self.assertTrue(ok, failures)
        ok, _, failures = preflight._check_sql_manifest(package)
        self.assertTrue(ok, failures)
        ok, _, failures = preflight._check_canonical(canonical)
        self.assertTrue(ok, failures)

    def test_missing_live_snapshot_is_no_go(self):
        with tempfile.TemporaryDirectory() as temp:
            ok, detail, _ = preflight._check_live_snapshot(
                pathlib.Path(temp) / "missing.json", "project", "batch", 24
            )
        self.assertFalse(ok)
        self.assertIn("missing", detail)

    def test_batch_marker_collision_is_no_go(self):
        with tempfile.TemporaryDirectory() as temp:
            path = pathlib.Path(temp) / "live.json"
            path.write_text(json.dumps({
                "schema_version": "rad-production-live-check-v1",
                "project_ref": "project",
                "method": "read_only_sql",
                "writes_performed": 0,
                "batch_marker": "batch",
                "batch_marker_count": 1,
                "baseline_matches": True,
                "captured_at_utc": preflight.dt.datetime.now(preflight.dt.timezone.utc).isoformat(),
            }), encoding="utf-8")
            ok, _, failures = preflight._check_live_snapshot(path, "project", "batch", 24)
        self.assertFalse(ok)
        self.assertTrue(any("collision" in failure for failure in failures))

    def test_external_backup_requires_attestation(self):
        ok, detail, _ = preflight._check_external_backup(None)
        self.assertFalse(ok)
        self.assertIn("absent", detail)


if __name__ == "__main__":
    unittest.main(verbosity=2)
