"""Release reporting must not promote source fidelity to CMS publication."""

import copy
import json
import tempfile
import unittest
from pathlib import Path

from scripts import production_reconciliation_package as package
from scripts.visa_release_audit import (
    audit_package,
    compare_production_heads,
    file_sha,
    operation_outcome,
)


class VisaReleaseAuditTest(unittest.TestCase):
    def fixture(self):
        item = {
            "article_id": "11111111-1111-4111-8111-111111111111",
            "locale": "fa",
            "editorial_state": "draft",
            "verification_state": "unverified",
            "publication_allowed": False,
            "published": False,
            "reviewer_id": None,
            "country_codes": ["DE", "FR"],
            "sections": [{"blocks": [{"text": "Original source"}]}],
            "claims": [],
            "draft_request": {
                "article_id": "11111111-1111-4111-8111-111111111111",
                "locale": "fa",
                "merge_manifest_id": None,
                "related_article_ids": [],
                "expected_revision": 0,
            },
        }
        return package.make_operation(
            {"item": item, "sources": []}, None, "NEW_KEY_DRAFT_CANDIDATE"
        )

    def test_unconfirmed_link_and_hidden_media_do_not_become_false_claims(self):
        op = self.fixture()
        item = op["payload"]["item"]
        item["source_links"] = [{"href_evidence": {"confirmed": False}}, {}]
        item["source_assets"] = [{"public_render_allowed": False}]
        outcome = operation_outcome(op)
        self.assertEqual(outcome["unconfirmed_links_not_proven_broken"], 1)
        self.assertEqual(outcome["links_with_other_evidence_representation"], 1)
        self.assertEqual(outcome["media_references_to_keep_hidden"], 1)
        self.assertFalse(outcome["approved_by_audit"])
        self.assertFalse(outcome["published_by_audit"])
        self.assertIn(
            "EXISTING_CMS_FACTUAL_VERIFICATION_CONTRACT_UNSATISFIED",
            outcome["publication_holds"],
        )

    def test_mechanical_reconciliation_never_fabricates_human_clearance(self):
        op = self.fixture()
        op["action"] = "PENDING_HUMAN_RECONCILIATION"
        op["review_case"] = {
            "delta": {
                "classification": "EXACT_ADDITIVE_ORDER_PRESERVED",
                "unmatched_current_occurrences": 0,
                "changed_nonsection_fields": [],
            },
            "source_review_status": "PASS_EXACT_MECHANICAL_SOURCE_INTEGRITY",
            "source_review_errors": [],
        }
        before = copy.deepcopy(op)
        outcome = operation_outcome(op)
        self.assertEqual(
            outcome["reconciliation"],
            "MECHANICALLY_PRESERVES_CURRENT_CONTENT_DETACHED_DRAFT_PROPOSAL",
        )
        self.assertFalse(outcome["imported_by_audit"])
        self.assertEqual(op, before)
        for field, value in [
            ("unmatched_current_occurrences", 1),
            ("changed_nonsection_fields", ["title"]),
        ]:
            changed = copy.deepcopy(op)
            changed["review_case"]["delta"][field] = value
            self.assertEqual(
                operation_outcome(changed)["reconciliation"],
                "SUBSTANTIVE_RECONCILIATION_HELD",
            )

    def test_package_hashes_body_tampering_and_input_drift_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.txt"
            source.write_text("frozen", encoding="utf8")
            operation = self.fixture()
            operations = [operation]
            plan = package.seal_plan(
                {
                    "inputs": {"source.txt": file_sha(source)},
                    "operation_counts": {operation["action"]: 1},
                },
                operations,
            )
            (root / "plan.json").write_text(json.dumps(plan), encoding="utf8")
            package.write_rows(root / "operations.jsonl.gz", operations)
            result = audit_package(root, plan["package_sha256"], root)
            self.assertEqual(result["planned_multi_country_operations"], 1)
            self.assertEqual(result["planned_country_coverage"], {"DE": 1, "FR": 1})
            self.assertEqual(result["held_operations"], 1)
            self.assertEqual(result["published_by_audit"], 0)
            with self.assertRaisesRegex(ValueError, "unexpected_package_sha256"):
                audit_package(root, "0" * 64, root)
            source.write_text("changed", encoding="utf8")
            with self.assertRaisesRegex(ValueError, "package_input_hash_mismatch"):
                audit_package(root, plan["package_sha256"], root)
            source.write_text("frozen", encoding="utf8")
            operation["payload"]["item"]["sections"][0]["blocks"][0]["text"] = "Altered"
            package.write_rows(root / "operations.jsonl.gz", operations)
            with self.assertRaisesRegex(ValueError, "package_operation_integrity"):
                audit_package(root, plan["package_sha256"], root)

    def test_other_titles_and_unresolved_numbers_remain_explicit(self):
        op = self.fixture()
        op["payload"]["item"]["country_codes"] = []
        op["payload"]["item"]["conflicts"] = [{"first": 10, "second": 20}]
        outcome = operation_outcome(op)
        self.assertEqual(outcome["discovery_after_publication"], "OTHER_TITLES")
        self.assertIn("UNRESOLVED_SOURCE_CONFLICTS", outcome["publication_holds"])
        self.assertEqual(
            op["payload"]["item"]["conflicts"], [{"first": 10, "second": 20}]
        )

    def test_readback_checks_authorship_body_and_pointer_drift(self):
        baseline = [
            {
                "article_id": "a",
                "locale": "fa",
                "head_id": "head",
                "published_id": None,
                "revision": 1,
                "body_md5": "body",
                "actor_id_md5": "actor",
                "title_summary_md5": "title",
                "stored_content_hash": "hash",
                "created_at": "time",
            }
        ]
        readback = {
            "project_id": "inshddthftkhcdosoqcn",
            "head_bindings": copy.deepcopy(baseline),
            "observed_at": "time",
            "approved_revisions": 0,
            "published_heads": 0,
        }
        self.assertEqual(
            compare_production_heads(baseline, readback)["differences"], []
        )
        for field in ("actor_id_md5", "body_md5", "published_id", "head_id"):
            changed = copy.deepcopy(readback)
            changed["head_bindings"][0][field] = "changed"
            result = compare_production_heads(baseline, changed)
            self.assertEqual(result["status"], "DRIFT_DETECTED")
            self.assertEqual(result["differences"][0]["fields"], [field])
        readback["project_id"] = "epolbumcfbohtmgvomki"
        with self.assertRaisesRegex(ValueError, "target_mismatch"):
            compare_production_heads(baseline, readback)


if __name__ == "__main__":
    unittest.main()
