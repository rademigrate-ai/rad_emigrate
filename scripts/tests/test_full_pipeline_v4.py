"""Safety boundaries of the V4 transaction compiler and source-reference maps."""

import copy
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.tests.test_content_consolidation import source
from scripts.tests.test_precedence_v4 import paragraph
from tools.content_completion.full_pipeline_v4 import (
    canonicalize,
    do_sql,
    reference_metadata,
    retirement_candidates,
    rollback_operation_sql,
    safe_web_url,
    supplement_source_metadata,
)
from tools.content_consolidation.composition import compose
from tools.plan3_content.dataset import uid
from tools.plan3_content.parser import digest


class CompilerBoundaryTests(unittest.TestCase):
    def test_explicit_source_language_evidence_outranks_historical_wrong_locale(self):
        original = {
            "url": "https://radmohajer.ir/fa/norway",
            "title": "Source title",
            "language": "en",
            "body_sha256": "same body",
            "complete_article_body": True,
        }
        capture = {
            "url": original["url"],
            "title": original["title"],
            "language": "fa",
            "body_sha256": "same body",
            "original_capture_language": "en",
            "language_evidence": {
                "basis": "explicit_Persian_route_and_Persian_title_or_narrative"
            },
        }
        supplement_source_metadata([capture], [original], Path("sealed.jsonl.gz"))
        self.assertEqual(capture["language"], "fa")
        self.assertEqual(capture["original_capture_language"], "en")
        self.assertEqual(
            capture["historical_language_disagreement"]["historical_language"], "en"
        )

    def test_locale_correction_requires_explicit_mapping_and_preserved_source_hash(
        self,
    ):
        ref = {"url": "https://radmohajer.ir/fa/norway", "structure_sha256": "hash"}
        old = {"article_id": "old-en", "locale": "en", "segment_ledger": [ref]}
        target = {"article_id": "new-fa", "locale": "fa", "segment_ledger": [ref]}
        heads = {
            ("old-en", "en"): {
                "head_id": "old-head",
                "catalog_active": True,
                "batch_id": "batch",
                "published_id": None,
                "revision": 1,
                "catalog_hash": "catalog",
            }
        }
        with patch(
            "tools.content_completion.full_pipeline_v4.read_jsonl", return_value=[old]
        ):
            plans, blockers = retirement_candidates([target], heads, {("new-fa", "fa")})
            self.assertFalse(plans)
            self.assertEqual(
                blockers[0]["reason"], "prior_source_segments_not_proven_represented"
            )
            target["locale_corrections"] = [
                {
                    "source_url": ref["url"],
                    "original_capture_language": "en",
                    "corrected_locale": "fa",
                    "translation_created": False,
                }
            ]
            plans, blockers = retirement_candidates([target], heads, {("new-fa", "fa")})
            self.assertFalse(blockers)
            self.assertEqual(
                plans[0]["locales"][0]["replacement_destinations"],
                [{"article_id": "new-fa", "locale": "fa"}],
            )

    def test_missing_title_and_mixed_script_locale_use_sealed_exact_body_evidence(self):
        original = {
            "url": "https://radmohajer.ir/fa/austria",
            "title": "Original source title",
            "language": "fa",
            "body_sha256": "body",
            "complete_article_body": True,
        }
        capture = {
            "url": original["url"],
            "title": "",
            "language": "en",
            "body_sha256": "body",
            "blocks": [{"type": "paragraph", "text": "Unchanged source body"}],
            "body_text": "Unchanged source body",
        }
        supplement_source_metadata([capture], [original], Path("sealed.jsonl.gz"))
        self.assertEqual(capture["title"], original["title"])
        self.assertEqual(capture["language"], "fa")
        self.assertEqual(capture["original_capture_title"], "")
        self.assertEqual(capture["original_capture_language"], "en")
        self.assertEqual(capture["body_text"], "Unchanged source body")

    def test_changed_source_body_does_not_inherit_old_language(self):
        original = {
            "url": "https://radvisa.com/article/example",
            "title": "Old title",
            "language": "fa",
            "body_sha256": "old body",
            "complete_article_body": True,
        }
        capture = {
            "url": original["url"],
            "title": "New English article",
            "language": "en",
            "body_sha256": "new body",
        }
        supplement_source_metadata([capture], [original], Path("sealed.jsonl.gz"))
        self.assertEqual(capture["language"], "en")
        self.assertNotIn("original_capture_language", capture)

    def fixture(self):
        row = source(
            "compiler",
            "Guide",
            "digivisa.ir",
            blocks=[paragraph("A passport is required.")],
        )
        row.update(
            retrieved_at="2026-10-28T10:00:00Z",
            body_sha256=digest(row["body_text"]),
            raw_html_sha256=digest("captured raw"),
        )
        article = compose([row], uid("compiler-article"), "Guide", ["CA"])
        row["body_links"] = [
            {"label": "passport", "url": "https://example.org/passport"},
            {"label": "unsafe", "url": "javascript:alert(1)"},
        ]
        row["source_assets"] = [
            {
                "url": "https://example.org/image.png",
                "kind": "img",
                "public_render_allowed": False,
                "alt": "source image",
            }
        ]
        article["source_links"], article["source_assets"] = reference_metadata(
            article, {row["source_id"]: row}
        )
        return row, article

    def test_untrusted_source_text_cannot_close_do_block(self):
        sql = do_sql("perform 'source $rad_v4_0$ and $$; source text';")
        self.assertTrue(sql.startswith("do $rad_v4_1$"))
        self.assertIn("source $rad_v4_0$", sql)

    def test_media_and_reference_urls_cannot_inject_nonweb_schemes_or_credentials(self):
        for url in (
            "javascript:alert(1)",
            "https://user:password@example.org/a",
            "https://example.org/ x",
            "file:///tmp/x",
        ):
            self.assertFalse(safe_web_url(url))
        _row, article = self.fixture()
        self.assertEqual(len(article["source_links"]), 1)
        self.assertEqual(
            article["source_links"][0]["target_block_id"],
            article["sections"][0]["blocks"][0]["id"],
        )
        self.assertFalse(article["source_assets"][0]["public_render_allowed"])

    def test_reference_capture_uses_stored_snapshot_raw_hash_and_preserves_new_capture_hash(
        self,
    ):
        row, article = self.fixture()
        old_snapshot = uid("stored-snapshot")
        stored = [
            {
                "canonical_url": row["url"],
                "source_id": row["source_id"],
                "content_hash": row["body_sha256"],
                "snapshot_id": old_snapshot,
                "raw_html_sha256": digest("stored raw"),
            }
        ]
        projected = canonicalize(article, {row["source_id"]: row}, stored)
        source_row = projected["sources"][0]
        self.assertEqual(source_row["raw_html_sha256"], digest("stored raw"))
        self.assertEqual(
            source_row["source_evidence"]["captured_raw_html_sha256"],
            digest("captured raw"),
        )
        self.assertEqual(
            projected["reference_map"]["sources"][0]["snapshot_id"], old_snapshot
        )
        self.assertEqual(
            projected["reference_map"]["links"][0]["source_snapshot_id"], old_snapshot
        )

    def test_missing_historical_raw_hash_does_not_fabricate_reference_proof(self):
        row, article = self.fixture()
        stored = [
            {
                "canonical_url": row["url"],
                "source_id": row["source_id"],
                "content_hash": row["body_sha256"],
                "snapshot_id": uid("stored-snapshot"),
                "raw_html_sha256": None,
            }
        ]
        with self.assertRaisesRegex(ValueError, "raw_hash_missing"):
            canonicalize(article, {row["source_id"]: row}, stored)

    def test_shared_supplemental_provenance_is_not_remapped_twice_to_primary_snapshot(
        self,
    ):
        base, _ = self.fixture()
        alternate = copy.deepcopy(base)
        alternate.update(
            source_id=uid("alternate-source-version"),
            snapshot_id=uid("alternate-source-snapshot"),
            blocks=[
                paragraph("A distinct supplemental source condition is preserved.")
            ],
        )
        alternate["body_text"] = alternate["blocks"][0]["text"]
        alternate["body_sha256"] = digest(alternate["body_text"])
        article = compose([base, alternate], uid("variant-reader"), "Guide", ["CA"])
        snapshots = [
            (base, uid("DB-base-snapshot")),
            (alternate, uid("DB-alternate-snapshot")),
        ]
        stored = [
            {
                "source_id": base["source_id"],
                "canonical_url": base["url"],
                "snapshot_id": snapshot,
                "content_hash": row["body_sha256"],
                "raw_html_sha256": row["raw_html_sha256"],
            }
            for row, snapshot in snapshots
        ]
        projected = canonicalize(
            article, {row["source_id"]: row for row in (base, alternate)}, stored
        )
        rich = next(
            b
            for sec in projected["item"]["sections"]
            for b in sec["blocks"]
            if b["text"] == alternate["body_text"]
        )
        self.assertEqual(rich["selected_origin"]["source_id"], base["source_id"])
        self.assertEqual(
            rich["selected_origin"]["source_variant_id"], alternate["source_id"]
        )
        self.assertEqual(rich["selected_origin"]["snapshot_id"], snapshots[1][1])
        self.assertEqual(len(projected["item"]["source_capture_variants"]), 2)

    def test_rollback_requires_exact_revision_body_and_unmodified_shared_heads(self):
        row, article = self.fixture()
        item = canonicalize(article, {row["source_id"]: row}, [])["item"]
        prior = {"revision": 1, "head_id": uid("prior-head")}
        rollback = rollback_operation_sql(
            copy.deepcopy(item), prior, "a" * 64, uid("batch")
        )
        for gate in (
            "v.revision=2",
            "v.body=",
            "v.content_hash=",
            "applied_heads",
            "applied_identity",
            "applied_country_titles",
            "rad_editorial_clearances",
            "pg_advisory_xact_lock",
        ):
            self.assertIn(gate, rollback)
        self.assertNotIn("rollback_editorial_import", rollback)


if __name__ == "__main__":
    unittest.main()
