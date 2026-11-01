"""Original markup, not title similarity, determines source limitation evidence."""

import hashlib
import unittest

from tools.content_completion.source_limitations_v42 import (
    capture_disposition,
    encoding_disposition,
    heading_disposition,
    link_disposition,
)
from tools.plan3_content.parser import digest


def source(raw, blocks, links=()):
    body = "\n\n".join(block["text"] for block in blocks)
    return {
        "source_id": "original-source",
        "capture_id": "original-capture",
        "snapshot_id": "original-snapshot",
        "url": "https://radvisa.com/article/guide",
        "resolved_url": "https://radvisa.com/article/guide",
        "domain": "radvisa.com",
        "title": "Guide",
        "language": "en",
        "blocks": blocks,
        "body_text": body,
        "body_sha256": digest(body),
        "structure_sha256": digest(blocks),
        "raw_html_sha256": hashlib.sha256(raw).hexdigest(),
        "raw_html_asset": "synthetic.html.gz",
        "body_links": list(links),
        "http_status": 200,
        "completeness": "thin_or_placeholder_requires_review",
    }


class SourceLimitationEvidenceTests(unittest.TestCase):
    def test_document_form_wrapper_does_not_hide_owned_headings_or_links(self):
        raw = b'<form><h1>Guide</h1><div itemprop="articleBody"><h2>Documents</h2><p>Read <a href="/law#original">Law</a>.</p><form><a href="/wrong">Law</a></form></div></form>'
        row = source(
            raw,
            [
                {"type": "heading", "text": "Documents", "level": 2},
                {"type": "paragraph", "text": "Read Law ."},
            ],
        )
        heading = heading_disposition(row, {"block_index": 0}, raw)
        link = link_disposition(
            row, {"canonical_url": "https://radvisa.com/law", "label": "Law"}, raw
        )
        self.assertEqual(heading["disposition"], "VERIFIED_OWNED_NUMERIC_HEADING")
        self.assertEqual(
            link["original_targets"],
            [
                {
                    "url": "https://radvisa.com/law#original",
                    "original_href": "/law#original",
                }
            ],
        )

    def test_legacy_faq_placeholder_and_bare_labels_stay_pending(self):
        for body in [
            "متن سوالات متداول در حال تدوین است. لطفا بعدا مجددا مراجعه نمایید.",
            "IELTS TOEFL",
        ]:
            raw = f'<h1>Guide</h1><div itemprop="articleBody"><p>{body}</p></div>'.encode()
            row = source(raw, [{"type": "paragraph", "text": body}])
            result = capture_disposition(row, raw, [])
            self.assertNotIn("candidate", result)

    def test_owned_error_page_is_not_a_recovered_article(self):
        raw = '<h1>صفحه مورد نظر یافت نشد</h1><div itemprop="articleBody"><h2>404</h2><p>Return to home.</p></div>'.encode()
        row = source(
            raw,
            [
                {"type": "heading", "text": "404", "level": 2},
                {"type": "paragraph", "text": "Return to home."},
            ],
        )
        row["title"] = "صفحه مورد نظر یافت نشد"
        result = capture_disposition(row, raw, [])
        self.assertEqual(
            result["disposition"], "EXPLICIT_ERROR_PAGE_NOT_RECOVERED_ARTICLE"
        )
        self.assertNotIn("candidate", result)

    def test_modified_body_or_structure_cannot_reuse_original_raw_seal(self):
        raw = b'<h1>Guide</h1><div itemprop="articleBody"><h2>Documents</h2></div>'
        row = source(raw, [{"type": "heading", "text": "Documents", "level": 2}])
        row["body_text"] = "Forged body"
        with self.assertRaisesRegex(ValueError, "body_checksum_mismatch"):
            heading_disposition(row, {"block_index": 0}, raw)

    def test_emphasis_heading_has_verified_markup_without_invented_numeric_level(self):
        raw = b'<h1>Guide</h1><div itemprop="articleBody"><p><strong>Applicants need ID.</strong></p></div>'
        row = source(raw, [{"type": "heading", "text": "Applicants need ID."}])
        result = heading_disposition(row, {"block_index": 0}, raw)
        self.assertEqual(result["disposition"], "VERIFIED_UNLEVELED_EMPHASIS_HEADING")
        self.assertIsNone(result["level"])
        self.assertTrue(result["raw_markup_verified"])
        self.assertNotIn("replacement_blocks", result)

    def test_native_heading_is_bound_to_owned_body_not_same_text_in_navigation(self):
        raw = b'<nav><h2>Documents</h2></nav><h1>Guide</h1><div itemprop="articleBody"><h3>Documents</h3><p>Original body.</p></div>'
        row = source(
            raw,
            [
                {"type": "heading", "text": "Documents", "level": 3},
                {"type": "paragraph", "text": "Original body."},
            ],
        )
        result = heading_disposition(row, {"block_index": 0}, raw)
        self.assertEqual(result["disposition"], "VERIFIED_OWNED_NUMERIC_HEADING")
        self.assertEqual(result["level"], 3)
        self.assertEqual(len(result["raw_matches"]), 1)
        self.assertTrue(result["raw_matches"][0]["raw_heading_tag"].startswith("<h3>"))

    def test_duplicate_owned_heading_occurrences_are_not_arbitrarily_chosen(self):
        raw = b'<h1>Guide</h1><div itemprop="articleBody"><h2>Documents</h2><p>A.</p><h2>Documents</h2><p>B.</p></div>'
        row = source(
            raw,
            [
                {"type": "heading", "text": "Documents", "level": 2},
                {"type": "paragraph", "text": "A."},
                {"type": "heading", "text": "Documents", "level": 2},
                {"type": "paragraph", "text": "B."},
            ],
        )
        first = heading_disposition(row, {"block_index": 0}, raw)
        second = heading_disposition(row, {"block_index": 2}, raw)
        self.assertLess(
            first["raw_matches"][0]["decoded_character_start"],
            second["raw_matches"][0]["decoded_character_start"],
        )

    def test_link_uses_full_owned_body_proof_not_http_https_equivalence(self):
        raw = b'<nav><a href="http://radvisa.com/law#wrong">Law</a></nav><h1>Guide</h1><div itemprop="articleBody"><p>Read <a href="https://radvisa.com/law#original">Law</a>.</p></div>'
        row = source(
            raw,
            [{"type": "paragraph", "text": "Read Law ."}],
            [{"url": "https://radvisa.com/law", "label": "Law"}],
        )
        result = link_disposition(
            row, {"canonical_url": "https://radvisa.com/law", "label": "Law"}, raw
        )
        self.assertEqual(result["disposition"], "VERIFIED_OWNED_ORIGINAL_LINK_TARGET")
        self.assertEqual(
            result["original_targets"],
            [
                {
                    "url": "https://radvisa.com/law#original",
                    "original_href": "https://radvisa.com/law#original",
                }
            ],
        )
        self.assertTrue(result["complete_body_identity_verified"])

    def test_changed_body_cannot_certify_link_even_with_identical_label_and_target(
        self,
    ):
        raw = b'<h1>Guide</h1><div itemprop="articleBody"><p>Different <a href="/law">Law</a>.</p></div>'
        row = source(raw, [{"type": "paragraph", "text": "Original Law ."}])
        result = link_disposition(
            row, {"canonical_url": "https://radvisa.com/law", "label": "Law"}, raw
        )
        self.assertFalse(result["resolved"])
        self.assertEqual(result["disposition"], "BODY_IDENTITY_REQUIRES_REVIEW")

    def test_heading_only_original_body_is_recovered_without_changing_its_blocks(self):
        raw = b'<h1>Guide</h1><div itemprop="articleBody"><h2>First heading</h2><h2>An authored explanation.</h2></div>'
        row = source(
            raw,
            [
                {"type": "heading", "text": "First heading", "level": 2},
                {"type": "heading", "text": "An authored explanation.", "level": 2},
            ],
        )
        result = capture_disposition(row, raw, [])
        self.assertEqual(result["disposition"], "VERIFIED_COMPLETE_OWNED_BODY")
        self.assertEqual(result["candidate"]["blocks"], row["blocks"])
        self.assertEqual(result["candidate"]["body_sha256"], row["body_sha256"])
        self.assertFalse(result["candidate"]["publication_allowed"])

    def test_title_similarity_or_same_text_without_alias_binding_cannot_resolve_url(
        self,
    ):
        raw = b'<h1>Guide</h1><div itemprop="articleBody"><p>Coming soon</p></div>'
        row = source(raw, [{"type": "paragraph", "text": "Coming soon"}])
        other = {
            **row,
            "url": "https://radvisa.com/article/different",
            "completeness": "complete_owned_article_container",
        }
        result = capture_disposition(row, raw, [other])
        self.assertNotEqual(result["disposition"], "VERIFIED_EXACT_CAPTURE_ALIAS")
        self.assertNotIn("candidate", result)

    def test_encoding_defect_outside_owned_body_is_distinguished_from_body_damage(self):
        outside = b"<script>var x='\xe4';</script><div itemprop='articleBody'><p>Intact.</p></div>"
        inside = b"<div itemprop='articleBody'><p>Damaged \xe4.</p></div>"
        self.assertEqual(
            encoding_disposition(outside)["disposition"],
            "ENCODING_DEFECT_OUTSIDE_OWNED_BODY",
        )
        self.assertEqual(
            encoding_disposition(inside)["disposition"],
            "OWNED_BODY_ENCODING_REQUIRES_REVIEW",
        )

    def test_wrong_raw_hash_never_produces_verified_evidence(self):
        raw = b'<div itemprop="articleBody"><p>Changed.</p></div>'
        row = source(raw, [{"type": "paragraph", "text": "Changed."}])
        row["raw_html_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "raw_checksum_mismatch"):
            heading_disposition(row, {"block_index": 0}, raw)


if __name__ == "__main__":
    unittest.main()
