import unittest
from unittest.mock import patch

from tools.content_completion.recover_geography import (
    build,
    is_geographic_candidate,
    make_draft,
)
from tools.plan3_content.parser import digest


class GeographyRecoveryTests(unittest.TestCase):
    def source(self):
        blocks = [
            {"type": "heading", "level": 2, "text": "First"},
            {"type": "paragraph", "text": "Unique paragraph."},
            {"type": "heading", "level": 2, "text": "Other"},
            {
                "type": "table",
                "text": "A B",
                "rows": [[{"text": "A", "colspan": 2}, {"text": "B"}]],
            },
            {"type": "heading", "level": 2, "text": "First"},
            {"type": "paragraph", "text": "Unique final paragraph."},
        ]
        body = "\n\n".join(block["text"] for block in blocks)
        return {
            "url": "https://digivisa.ir/article/about-canada",
            "title": "About Canada",
            "source_id": "source",
            "snapshot_id": "snapshot",
            "domain": "digivisa.ir",
            "language": "en",
            "body_text": body,
            "body_sha256": digest(body),
            "blocks": blocks,
            "body_status": "complete_source_container",
            "consolidation_disposition": "nonarticle_or_incomplete_requires_review",
            "taxonomy": {"page_type": "organization", "country_codes": ["CA"]},
        }

    def test_repeated_headings_keep_full_original_order_and_structure(self):
        source = self.source()
        draft = make_draft(source)
        blocks = [b for section in draft["sections"] for b in section["blocks"]]
        self.assertEqual([b["original_structure"] for b in blocks], source["blocks"])
        self.assertEqual(
            [b["provenance"][0]["block_index"] for b in blocks], list(range(6))
        )
        self.assertFalse(draft["publication_allowed"])
        self.assertIsNone(draft["reviewer_id"])

    def test_candidate_excludes_company_page_even_if_country_tagged(self):
        source = self.source()
        source["body_text"] *= 10
        source["title"] = "About us Canada"
        self.assertFalse(is_geographic_candidate(source))

    def test_altered_source_is_not_composed(self):
        source = self.source()
        source["body_text"] += "tampered"
        with self.assertRaisesRegex(ValueError, "source_body_hash"):
            make_draft(source)

    def test_country_proposal_requires_exact_original_source_excerpt(self):
        source = self.source()
        source["taxonomy"]["country_codes"] = []
        evidence = {
            "source_id": source["source_id"],
            "country_code": "CA",
            "excerpt": "Unique paragraph.",
        }
        draft = make_draft(source, evidence)
        self.assertEqual(draft["country_codes"], ["CA"])
        self.assertEqual(draft["country_source_evidence"], evidence)
        with self.assertRaisesRegex(ValueError, "invalid_country_source_evidence"):
            make_draft(source, {**evidence, "excerpt": "not in the source"})

    @patch("tools.content_completion.recover_geography.payload")
    @patch("tools.content_completion.recover_geography.reference_capture")
    def test_unmatched_current_source_cannot_become_technical_candidate(
        self, capture, payload
    ):
        source = self.source()
        source["blocks"][1]["text"] = "Synthetic geography text " * 20
        source["body_text"] = "\n\n".join(b["text"] for b in source["blocks"])
        source["body_sha256"] = digest(source["body_text"])
        capture.return_value = None
        payload.return_value = {"status": "technical_draft_only"}
        rows, drafts, ready, maps = build([source], [], [], {}, [])
        self.assertEqual(len(drafts), 1)
        self.assertEqual(ready, [])
        self.assertEqual(maps, [])
        self.assertIn("current_source_not_fully_matched", rows[0]["reasons"])
        self.assertIn("original_reference_capture_unavailable", rows[0]["reasons"])


if __name__ == "__main__":
    unittest.main()
