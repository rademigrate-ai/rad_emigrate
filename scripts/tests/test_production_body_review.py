"""Focused regression tests for independent body review failure boundaries."""

import copy
import gzip
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.production_body_review import (
    classify_delta,
    detail,
    digest,
    draft_body,
    html_doc,
    matching_link_cases,
    source_review,
    structure_digest,
    verify_capture_files,
    write_rows,
)


class BodyReviewTests(unittest.TestCase):
    def body(self, *values):
        return {
            "title": "T",
            "sections": [
                {
                    "blocks": [
                        {"id": str(i), "type": "paragraph", "text": v, "items": []}
                        for i, v in enumerate(values)
                    ]
                }
            ],
            "related_article_ids": [],
        }

    def test_additive_requires_exact_ordered_current_content(self):
        d = classify_delta(self.body("a", "b"), self.body("x", "a", "b", "y"))
        self.assertEqual(d["classification"], "EXACT_ADDITIVE_ORDER_PRESERVED")
        self.assertEqual(d["additional_desired_occurrences"], 2)
        self.assertEqual(
            classify_delta(self.body("a", "b"), self.body("b", "a"))["classification"],
            "REORDER_OR_RESECTION_WITH_ADDITIONS",
        )

    def test_changed_human_text_and_multiplicity_are_not_additive(self):
        self.assertEqual(
            classify_delta(self.body("a", "a"), self.body("a"))[
                "unmatched_current_occurrences"
            ],
            1,
        )
        self.assertEqual(
            classify_delta(self.body("a "), self.body("a"))["classification"],
            "CURRENT_CONTENT_OR_METADATA_NEEDS_EXPLICIT_RECONCILIATION",
        )
        new = self.body("a")
        new["title"] = "Changed"
        self.assertIn(
            "title", classify_delta(self.body("a"), new)["changed_nonsection_fields"]
        )

    def test_only_transport_and_request_key_ignored_by_display_diff(self):
        a = self.body("a")
        b = copy.deepcopy(a)
        b["expected_revision"] = 9
        b["merge_manifest_id"] = "new"
        b["request_key"] = "key"
        self.assertEqual(
            classify_delta(a, draft_body(b))["changed_nonsection_fields"], []
        )
        b["related_article_ids"] = ["other"]
        self.assertEqual(
            classify_delta(a, draft_body(b))["changed_nonsection_fields"],
            ["related_article_ids"],
        )

    def fixture(self):
        block = {"type": "paragraph", "text": "proof"}
        s = {
            "source_id": "s",
            "snapshot_id": "snap",
            "body_text": "proof",
            "body_sha256": digest("proof"),
            "raw_html_sha256": "raw",
            "url": "https://example.test",
            "title": "T",
            "blocks": [block],
        }
        ref = {
            "source_id": "s",
            "snapshot_id": "snap",
            "block_index": 0,
            "start": 0,
            "end": 5,
            "sha256": digest("proof"),
            "structure_sha256": structure_digest(block),
            "url": s["url"],
        }
        item = {
            "article_id": "a",
            "locale": "fa",
            "title": "T",
            "sections": [
                {
                    "heading": "H",
                    "blocks": [
                        {
                            "id": "b",
                            "original_structure": block,
                            "selected_origin": ref,
                            "provenance": [ref],
                        }
                    ],
                }
            ],
            "draft_request": {
                "article_id": "a",
                "locale": "fa",
                "title": "T",
                "related_article_ids": [],
            },
            "published": False,
            "publication_allowed": False,
            "editorial_state": "draft",
        }
        return item, s

    def test_source_offsets_structure_and_storage_binding_all_required(self):
        item, s = self.fixture()
        self.assertEqual(source_review(item, [s], {"s": s}, {"a"})["errors"], [])
        bad = copy.deepcopy(item)
        bad["sections"][0]["blocks"][0]["provenance"][0]["end"] = 4
        self.assertTrue(source_review(bad, [s], {"s": s}, {"a"})["errors"])
        bad = copy.deepcopy(item)
        bad["sections"][0]["blocks"][0]["original_structure"]["text"] = "changed"
        self.assertTrue(source_review(bad, [s], {"s": s}, {"a"})["errors"])
        bad = copy.deepcopy(s)
        bad["snapshot_id"] = "wrong"
        self.assertTrue(source_review(item, [bad], {"s": s}, {"a"})["errors"])

    def test_untrusted_html_is_inert_and_csp_blocks_network(self):
        raw = "</pre><script>alert(1)</script><img src=x onerror=alert(2)>"
        packet = html_doc(raw, detail(raw, {"raw": raw}))
        self.assertNotIn("<script>", packet)
        self.assertNotIn("<img src=", packet)
        self.assertIn("&lt;script&gt;", packet)
        self.assertIn("default-src 'none'", packet)

    def test_preserved_snapshot_raw_hash_is_distinct_from_original_capture(self):
        item, s = self.fixture()
        stored = copy.deepcopy(s)
        stored["raw_html_sha256"] = "historical_raw"
        stored["source_evidence"] = {"captured_raw_html_sha256": "raw"}
        baseline = {
            "snap": {
                "source_id": "s",
                "canonical_url": s["url"],
                "content_hash": s["body_sha256"],
                "raw_html_sha256": "historical_raw",
            }
        }
        self.assertEqual(
            source_review(item, [stored], {"s": s}, {"a"}, baseline)["errors"], []
        )
        self.assertTrue(source_review(item, [stored], {"s": s}, {"a"})["errors"])

    def test_hash_binds_content_but_is_key_order_independent(self):
        self.assertEqual(digest({"a": 1, "b": 2}), digest({"b": 2, "a": 1}))
        self.assertNotEqual(digest({"a": 1}), digest({"a": 2}))

    def test_raw_capture_bytes_are_verified_without_executing_markup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            review = (
                root
                / "_audit/RAD_MASTER_CONVERGENCE_20261031/db_forward_review/body-review"
            )
            (review / "payloads").mkdir(parents=True)
            write_rows(
                review / "review-cases.jsonl.gz",
                [{"case_id": "C1", "article_id": "a", "locale": "fa"}],
            )
            payload = {
                "sources": [{"source_id": "s"}],
                "item": {"source_links": [], "source_assets": []},
            }
            (review / "payloads/a-fa.json.gz").write_bytes(
                gzip.compress(json.dumps(payload).encode())
            )
            raw = root / "source.html"
            raw.write_text("<script>never_execute()</script>", "utf8")
            source = {
                "source_id": "s",
                "raw_html_asset": str(raw),
                "raw_html_sha256": digest(raw.read_text("utf8")),
                "body_text": "proof",
                "body_sha256": digest("proof"),
                "url": "https://example.test",
            }
            for name, rows in [
                ("RAD_MASTER_EXECUTION_20261029/content/composition-safe", [source]),
                (
                    "RAD_MASTER_CONVERGENCE_20261031/content-recovery/additive-two-source-delta/composition",
                    [],
                ),
            ]:
                p = root / "_audit" / name
                p.mkdir(parents=True)
                write_rows(p / "sources.jsonl.gz", rows)
            self.assertEqual(verify_capture_files(root)["raw_bytes_verified"], 1)
            raw.write_text("changed", "utf8")
            self.assertEqual(
                verify_capture_files(root)["status"], "REVIEW_CAPTURE_EVIDENCE_FAILURES"
            )

    def test_exact_link_case_mapping_requires_same_original_capture(self):
        link = {
            "source_id": "s",
            "source_url": "https://source.test",
            "label": "L",
            "url": "https://target.test",
            "original_href": "/target",
        }
        variant = {"capture_id": "cap", "raw_html_sha256": "raw"}
        case = {
            "case_id": "known",
            "case_sha256": "hash",
            "source_id": "s",
            "source_url": "https://source.test",
            "capture_ids": ["cap"],
            "evidence": {
                "original_proof": {
                    "raw_html_sha256": "raw",
                    "label": "L",
                    "canonical_url": "https://target.test",
                }
            },
        }
        self.assertEqual(len(matching_link_cases(link, variant, [case])), 1)
        case["capture_ids"] = ["different"]
        self.assertEqual(matching_link_cases(link, variant, [case]), [])
        self.assertEqual(len(matching_link_cases(link, variant, [case], False)), 1)
        case["evidence"]["original_proof"]["canonical_url"] = "https://different.test"
        case["evidence"]["original_proof"]["original_targets"] = [{}]
        link["original_href"] = None
        self.assertEqual(matching_link_cases(link, variant, [case], False), [])

    def test_optimized_python_cannot_bypass_review_integrity_assertions(self):
        result = subprocess.run(
            [sys.executable, "-B", "-O", "-c", "import tools.production_body_review"],
            check=False,
            cwd=Path(__file__).resolve().parents[2],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("optimized_python_forbidden", result.stderr)


if __name__ == "__main__":
    unittest.main()
