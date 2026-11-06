"""Mutation checks for independent V4 source/decision/route verification."""

import copy
import unittest

from scripts.tests.test_content_consolidation import source
from scripts.tests.test_precedence_v4 import paragraph
from tools.content_completion.full_audit_v4 import AuditFailure, audit, sha
from tools.content_consolidation.composition import compose


class IndependentAuditTests(unittest.TestCase):
    def fixture(
        self,
        left="Applicants must provide a valid passport.",
        right="A valid passport is required from applicants.",
    ):
        sources = [
            source("d", "Guide", "digivisa.ir", blocks=[paragraph(left)]),
            source("r", "Guide", "radvisa.com", blocks=[paragraph(right)]),
        ]
        article = compose(sources, "article", "Guide", ["CA"])
        return sources, article

    def assert_rejected(self, sources, article, code):
        with self.assertRaises(AuditFailure) as caught:
            audit(sources, [article])
        self.assertIn(code, {e["code"] for e in caught.exception.report["errors"]})

    def test_independent_composition_pass_is_separate_from_app_rendering(self):
        sources, article = self.fixture()
        result = audit(sources, [article])
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["source_segments_accounted"], 2)
        self.assertEqual(result["semantic_duplicate_representations"], 1)
        self.assertEqual(result["application_status"], "NOT_RUN")
        self.assertEqual(result["verified_admin_render_routes"], 0)

    def test_removed_source_block_fails_with_missing_segment_evidence(self):
        sources, article = self.fixture()
        article["sections"][0]["blocks"] = []
        self.assert_rejected(sources, article, "eligible_source_segments_missing")

    def test_missing_duplicate_target_fails(self):
        sources, article = self.fixture()
        article["omissions"][0]["represented_block_id"] = "missing"
        self.assert_rejected(sources, article, "dedup_target_missing_or_unlinked")

    def test_source_hash_and_offsets_are_independently_checked(self):
        for key, value, error in (
            ("sha256", "0" * 64, "source_ref_hash_or_origin_changed"),
            ("start", 1, "source_ref_offsets_changed"),
        ):
            with self.subTest(key=key):
                sources, article = self.fixture()
                article["sections"][0]["blocks"][0]["provenance"][1][key] = value
                self.assert_rejected(sources, article, error)

    def test_semantic_evidence_signature_cannot_be_forged(self):
        sources, article = self.fixture()
        article["omissions"][0]["equivalence_evidence"]["signature_sha256"] = "0" * 64
        self.assert_rejected(sources, article, "unjustified_semantic_removal")

    def force_removal(self, left, right):
        sources, article = self.fixture(left, right)
        blocks = article["sections"][0]["blocks"]
        chosen, removed = blocks
        removed_ref = removed["provenance"][0]
        chosen["provenance"].append(removed_ref)
        article["sections"][0]["blocks"] = [chosen]
        article["segment_ledger"][1]["represented_block_id"] = chosen["id"]
        article["omissions"] = [
            {
                "provenance": removed_ref,
                "represented_block_id": chosen["id"],
                "equivalence_evidence": {
                    "kind": "semantic",
                    "signature_sha256": "forged",
                },
            }
        ]
        return sources, article

    def test_numeric_date_and_conditional_mutants_do_not_pass(self):
        for left, right in (
            (
                "Applicants must provide 100 euros.",
                "Applicants must provide 200 euros.",
            ),
            (
                "Applicants must provide a passport in 2024.",
                "Applicants must provide a passport in 2026.",
            ),
            (
                "Applicants must provide a passport.",
                "Applicants must provide a passport unless exempt.",
            ),
            (
                "Doctors must provide care to patients.",
                "Patients must provide care to doctors.",
            ),
        ):
            with self.subTest(right=right):
                sources, article = self.force_removal(left, right)
                self.assert_rejected(sources, article, "unjustified_semantic_removal")

    def test_exact_text_cannot_be_removed_across_effective_dates(self):
        sources, article = self.fixture(
            "A passport is required.", "A passport is required."
        )
        sources[1]["effective_date"] = "2026-01-01"
        self.assert_rejected(sources, article, "deduplication_crosses_source_scope")

    def test_country_and_translation_mutants_fail(self):
        sources, article = self.fixture()
        sources[1]["taxonomy"]["country_codes"] = ["DE"]
        self.assert_rejected(sources, article, "deduplication_crosses_source_scope")
        sources, article = self.fixture()
        article["locale"] = "en"
        self.assert_rejected(sources, article, "fabricated_locale_or_translation")

    def test_clinical_preferred_source_mutant_fails(self):
        sources, article = self.fixture(
            "The criteria for diagnosis include persistent fever.",
            "The diagnostic criteria include persistent fever.",
        )
        chosen = article["sections"][0]["blocks"][0]
        chosen["selected_origin"] = chosen["provenance"][0]
        chosen["original_structure"] = sources[0]["blocks"][0]
        chosen["text"] = sources[0]["blocks"][0]["text"]
        self.assert_rejected(sources, article, "passage_source_precedence_violated")

    def test_publication_cannot_be_inferred_from_import(self):
        sources, article = self.fixture()
        article["published"] = True
        self.assert_rejected(sources, article, "unauthorized_publication_flag")

    def test_source_variants_with_same_source_id_have_independent_coverage(self):
        sources, article = self.fixture()
        supplemental = copy.deepcopy(sources[0])
        supplemental["snapshot_id"] = "another-immutable-snapshot"
        with self.assertRaises(AuditFailure) as caught:
            audit(sources, [article], supplements=[supplemental])
        self.assertEqual(caught.exception.report["missing_source_segments"], 1)

    def test_render_receipts_require_every_structural_hash(self):
        sources, article = self.fixture()
        blocks = {
            b["id"]: sha(b["original_structure"])
            for s in article["sections"]
            for b in s["blocks"]
        }
        receipt = {
            "article_id": article["article_id"],
            "locale": article["locale"],
            "rendered_structure_hashes": blocks,
            "revision_id": "revision",
            "admin_authorized": True,
            "route": "/admin/article/article",
            "body_render_verified": True,
        }
        self.assertEqual(
            audit(sources, [article], route_receipts=[receipt])["application_status"],
            "PASS",
        )
        receipt["rendered_structure_hashes"] = {}
        self.assertEqual(
            audit(sources, [article], route_receipts=[receipt])["application_status"],
            "FAIL",
        )


if __name__ == "__main__":
    unittest.main()
