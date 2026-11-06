"""Mechanical decisions preserve exact occurrences and never assert human review."""

import copy
import json
import tempfile
import unittest
from pathlib import Path

from scripts import production_mechanical_decisions as mechanical
from scripts import production_reconciliation_package as original
from scripts.source_editorial_batches import group_batches, has_public_media
from scripts.visa_release_audit import file_sha
from tools.production_body_review import digest as review_digest


class MechanicalDecisionTest(unittest.TestCase):
    def body(self, *values):
        return {
            "title": "Title",
            "summary": "",
            "article_id": "11111111-1111-4111-8111-111111111111",
            "locale": "en",
            "expected_revision": 0,
            "merge_manifest_id": None,
            "related_article_ids": [],
            "sections": [
                {
                    "blocks": [
                        {"id": str(i), "type": "paragraph", "text": value, "items": []}
                        for i, value in enumerate(values)
                    ]
                }
            ],
        }

    def test_order_resection_multiplicity_and_qualifications_are_distinct(self):
        ordered = mechanical.independent_delta(
            self.body("a", "b"), self.body("a", "x", "b")
        )
        self.assertEqual(ordered["classification"], "EXACT_ADDITIVE_ORDER_PRESERVED")
        reordered = mechanical.independent_delta(
            self.body("a", "b"), self.body("b", "a", "x")
        )
        self.assertEqual(
            reordered["classification"], "REORDER_OR_RESECTION_WITH_ADDITIONS"
        )
        self.assertEqual(
            mechanical.independent_delta(self.body("a", "a"), self.body("a"))[
                "unmatched_current_occurrences"
            ],
            1,
        )
        self.assertEqual(
            mechanical.independent_delta(
                self.body("fee 10 for adults"), self.body("fee 20 for children")
            )["unmatched_current_occurrences"],
            1,
        )
        changed = self.body("a")
        changed["title"] = "Different title"
        self.assertEqual(
            mechanical.independent_delta(self.body("a"), changed)[
                "changed_nonsection_fields"
            ],
            ["title"],
        )

    def fixture(self, root):
        before = self.body("a")
        after = self.body("a", "b")
        current = {
            "article_id": before["article_id"],
            "locale": "en",
            "head_id": "22222222-2222-4222-8222-222222222222",
            "published_id": None,
            "revision": 1,
            "body_md5": "b" * 32,
            "actor_id_md5": "a" * 32,
            "title_summary_md5": "c" * 32,
            "stored_content_hash": "d" * 64,
            "created_at": "time",
        }
        ready = {
            "item": {
                "article_id": before["article_id"],
                "locale": "en",
                "editorial_state": "draft",
                "verification_state": "unverified",
                "publication_allowed": False,
                "published": False,
                "reviewer_id": None,
                "draft_request": after,
            },
            "sources": [],
        }
        value = {"item": ready["item"], "sources": []}
        case = {
            "case_id": "TEST-CASE",
            "article_id": before["article_id"],
            "locale": "en",
            "payload_sha256": review_digest(value),
            "current_head": current["head_id"],
            "current_body_md5": current["body_md5"],
            "current_body_sha256": review_digest(before),
            "delta": mechanical.independent_delta(before, after),
            "source_review_status": "PASS_EXACT_MECHANICAL_SOURCE_INTEGRITY",
            "source_review_errors": [],
        }
        case["case_sha256"] = review_digest(case)
        op = original.make_operation(
            ready,
            current,
            "DISTINCT_SECTIONS_REQUIRE_APPROVED_RECONCILED_NEW_DRAFT",
            case,
        )
        plan = original.seal_plan({"production_baseline": [current]}, [op])
        capture = root / "production-full-body-0.json"
        capture.write_text(
            json.dumps({"rows": [current | {"body": before}]}), encoding="utf8"
        )
        (root / "receipt.json").write_text(
            json.dumps({"inputs": {str(capture): file_sha(capture)}}), encoding="utf8"
        )
        readback = {
            "project_id": original.PROJECT,
            "head_bindings": [current],
            "observed_at": "time",
            "approved_revisions": 0,
            "published_heads": 0,
        }
        return plan, [op], readback

    def test_hash_bound_actorless_decisions_use_existing_engine_without_approval(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            plan, operations, readback = self.fixture(root)
            result = mechanical.prepare(plan, operations, root, readback)
            self.assertEqual(result["counts"], {"create_detached_draft": 1})
            self.assertIsNone(result["dispositions"][0]["reviewer_id"])
            self.assertEqual(
                mechanical.validate_decisions(plan, operations, result), operations
            )
            self.assertIn(
                "MECHANICAL_REVIEW_ONLY", mechanical.render(plan, operations, result)
            )
            tampered = copy.deepcopy(result)
            tampered["dispositions"][0]["reviewer_id"] = "invented"
            with self.assertRaisesRegex(ValueError, "package_mismatch"):
                mechanical.validate_decisions(plan, operations, tampered)
            readback["head_bindings"] = [
                readback["head_bindings"][0] | {"head_id": "changed"}
            ]
            with self.assertRaisesRegex(ValueError, "heads_changed"):
                mechanical.prepare(plan, operations, root, readback)

    def test_nested_media_cannot_hide_behind_top_level_false_flag(self):
        self.assertTrue(
            has_public_media(
                {
                    "source_assets": [{"public_render_allowed": False}],
                    "sections": [
                        {
                            "blocks": [
                                {"original_structure": {"public_render_allowed": True}}
                            ]
                        }
                    ],
                }
            )
        )
        self.assertFalse(
            has_public_media({"source_assets": [{"public_render_allowed": False}]})
        )

    def test_two_locales_share_one_catalog_activation_batch(self):
        entries = [
            {"revision_id": "b-en"},
            {"revision_id": "a-fa"},
            {"revision_id": "a-en"},
        ]
        mapping = {"a-en": "a", "a-fa": "a", "b-en": "b"}
        batches = group_batches(entries, mapping, 2)
        self.assertEqual(len(batches), 2)
        self.assertEqual({e["revision_id"] for e in batches[0]}, {"a-en", "a-fa"})
        with self.assertRaisesRegex(ValueError, "all_article_locales"):
            group_batches(entries, mapping, 1)


if __name__ == "__main__":
    unittest.main()
