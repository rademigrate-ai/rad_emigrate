import gzip
import json
import tempfile
import unittest
from pathlib import Path

from tools.content_completion.source_delivery_forensics import (
    classify_capture,
    classify_inventory,
    known_url_register,
    propose_dubai_country_correction,
    raw_block_proof,
    restore_capture_identities,
    sha,
    source_crosswalk,
    verify_package_articles,
)


def capture(raw):
    return {
        "source_id": "original",
        "capture_id": "capture",
        "snapshot_id": "snapshot",
        "url": "https://radmohajer.ir/fa/original",
        "raw_html_sha256": sha(raw),
        "raw_html_asset": "raw.html.gz",
        "domain": "radmohajer.ir",
    }


class SourceDeliveryForensicsTest(unittest.TestCase):
    def test_crosswalk_preserves_legitimate_multiple_destination_occurrences(self):
        raw = b'<div itemprop="articleBody">Original</div>'
        source = capture(raw) | {"blocks": [{"type": "paragraph", "text": "Original"}]}
        ref = {"source_id": "original", "snapshot_id": "snapshot", "block_index": 0}
        ledger = ref | {
            "sha256": sha("Original"),
            "structure_sha256": sha(source["blocks"][0]),
            "represented_block_id": "block",
            "selected_origin": ref,
            "status": "preserved",
            "start": 0,
            "end": 8,
        }
        article = {
            "article_id": "a",
            "locale": "fa",
            "country_codes": [],
            "visa_category": None,
            "source_publishers": ["radmohajer.ir"],
            "sections": [{"blocks": [{"id": "block", "provenance": [ref]}]}],
            "segment_ledger": [ledger],
        }
        raw_proofs = {("original", "snapshot"): [{"status": "RAW_DOM_MATCH"}]}
        rows = list(
            source_crosswalk(
                [source], [article, article | {"article_id": "b"}], {}, raw_proofs
            )
        )
        self.assertEqual(len(rows), 2)
        with self.assertRaisesRegex(ValueError, "duplicate_source_segment"):
            list(source_crosswalk([source], [article, article], {}, raw_proofs))

    def test_discovery_frontier_and_original_gaps_are_not_silently_excluded(self):
        inventory = [
            {
                "url": "https://radvisa.com/menu",
                "source_id": "menu",
                "disposition": "NONCONTENT_ROUTE",
            }
        ]
        limitations = [
            {
                "original_url": "https://digivisa.ir/missing",
                "source_id": "missing",
                "observed_content_kinds": [],
            }
        ]
        rows = list(known_url_register(inventory, limitations, []))
        self.assertEqual(len(rows), 2)
        self.assertTrue(any(r["in_historical_421_gap_scope"] for r in rows))
        self.assertTrue(
            all(not r["legacy_noncontent_label_is_independent_proof"] for r in rows)
        )
        self.assertTrue(all(not r["historical_absence_claimed"] for r in rows))

    def test_encoding_damage_outside_body_is_not_repaired_or_imported(self):
        raw = b'<script>\xe4</script><div itemprop="articleBody"><p>Original 2025.</p></div>'
        source = capture(raw) | {
            "blocks": [{"type": "paragraph", "text": "Original 2025."}]
        }
        self.assertEqual(raw_block_proof(source, raw)[0]["status"], "RAW_DOM_MATCH")
        broken = b'<div itemprop="articleBody"><p>Original \xe4</p></div>'
        self.assertEqual(
            raw_block_proof(capture(broken) | {"blocks": source["blocks"]}, broken)[0][
                "status"
            ],
            "ENCODING_DAMAGE_IN_OWNED_BODY",
        )

    def test_stored_snapshot_alias_must_bind_the_original_capture_identity(self):
        refs = {
            "variant": {
                "source_id": "stored",
                "snapshot_id": "stored-snapshot",
                "original_snapshot_id": "original-snapshot",
            }
        }
        value = {
            "source_id": "stored",
            "snapshot_id": "stored-snapshot",
            "source_variant_id": "variant",
            "sha256": "literal-hash",
        }
        self.assertEqual(
            restore_capture_identities(value, refs),
            {
                "source_id": "variant",
                "snapshot_id": "original-snapshot",
                "sha256": "literal-hash",
            },
        )
        with self.assertRaisesRegex(ValueError, "stored_source_variant_binding"):
            restore_capture_identities(value | {"source_id": "forged"}, refs)
        with self.assertRaisesRegex(ValueError, "stored_snapshot_variant_binding"):
            restore_capture_identities(value | {"snapshot_id": "forged"}, refs)

    def test_country_correction_keeps_identity_full_body_and_unverified_state(self):
        text = "Dubai universities serve the UAE."
        source = {"source_id": "original", "body_text": text, "body_sha256": sha(text)}
        ready = {
            "sources": [source],
            "item": {
                "article_id": "same-article",
                "title": "Dubai universities",
                "country_codes": [],
                "draft_request": {"sections": ["unchanged"]},
                "sections": ["unchanged"],
                "verification_state": "unverified",
            },
        }
        reference = {
            "url": "https://www.moet.gov.ae/en/web/guest/emirates-of-the-uae",
            "captured_page_sha256": "a" * 64,
        }
        correction = propose_dubai_country_correction(
            ready, "original", text, reference
        )
        self.assertEqual(correction["item"]["country_codes"], ["AE"])
        self.assertEqual(
            correction["item"]["draft_request"], ready["item"]["draft_request"]
        )
        self.assertEqual(correction["item"]["article_id"], "same-article")
        self.assertEqual(correction["item"]["verification_state"], "unverified")
        self.assertEqual(ready["item"]["country_codes"], [])
        with self.assertRaisesRegex(ValueError, "literal_original_country_excerpt"):
            propose_dubai_country_correction(
                ready, "original", "Invented UAE quote", reference
            )

    def test_error_response_is_not_historical_absence(self):
        raw = b'<html><title>Page not found</title><link rel="canonical" href="/404.htm"></html>'
        result = classify_capture(capture(raw), raw)
        self.assertEqual(
            result["observed_content_kind"],
            "ERROR_RESPONSE_HISTORICAL_IDENTITY_UNDETERMINED",
        )
        self.assertFalse(result["original_historical_body_proved_absent"])
        self.assertFalse(result["publication_allowed"])
        with self.assertRaisesRegex(ValueError, "raw_capture_hash"):
            classify_capture(capture(raw), raw + b"tampered")

    def test_placeholder_requires_every_paragraph_to_be_placeholder_or_title(self):
        raw = (
            b'<title>FAQ</title><div itemprop="articleBody"><p>No FAQ found!</p></div>'
        )
        self.assertEqual(
            classify_capture(capture(raw), raw)["observed_content_kind"],
            "EXPLICIT_PUBLISHER_PLACEHOLDER",
        )
        authored = raw.replace(
            b"</div>", b"<p>Applicants must submit a valid passport.</p></div>"
        )
        self.assertEqual(
            classify_capture(capture(authored), authored)["observed_content_kind"],
            "AUTHORED_TEXT_REQUIRES_COMPLETE_BODY_PROOF",
        )

    def test_category_excerpts_are_not_recovered_full_articles(self):
        raw = b'<main><div class="blog"><p>A clipped article excerpt.</p></div></main>'
        self.assertEqual(
            classify_capture(capture(raw), raw)["observed_content_kind"],
            "CATEGORY_LIST_WITH_PARTIAL_EXCERPTS",
        )

    def test_media_reference_is_retained_without_public_clearance(self):
        raw = b'<div itemprop="articleBody"><video><source src="clip.mp4">Your browser does not support video</video></div>'
        result = classify_capture(capture(raw), raw)
        self.assertEqual(
            result["observed_content_kind"], "MEDIA_ONLY_NO_AUTHORED_TRANSCRIPT"
        )
        self.assertEqual(result["media_references"][0]["literal_src"], "clip.mp4")
        self.assertFalse(result["media_references"][0]["public_render_allowed"])

    def test_empty_container_and_title_only_are_not_complete_bodies(self):
        for raw, expected in [
            (b'<div itemprop="articleBody"></div>', "EMPTY_OWNED_CONTAINER"),
            (
                b'<title>Country visa</title><div itemprop="articleBody">Country visa</div>',
                "TITLE_ONLY_NO_ARTICLE_BODY",
            ),
        ]:
            self.assertEqual(
                classify_capture(capture(raw), raw)["observed_content_kind"], expected
            )

    def test_raw_dom_proof_checks_order_multiplicity_and_numeric_qualifications(self):
        raw = b'<div itemprop="articleBody"><p>Fee is 500 in 2025.</p><p>Only graduates qualify.</p></div>'
        source = capture(raw) | {
            "blocks": [
                {"type": "paragraph", "text": "Fee is 500 in 2025."},
                {"type": "paragraph", "text": "Only graduates qualify."},
            ]
        }
        self.assertTrue(
            all(p["status"] == "RAW_DOM_MATCH" for p in raw_block_proof(source, raw))
        )
        source["blocks"] = source["blocks"] * 2
        self.assertEqual(
            [p["status"] for p in raw_block_proof(source, raw)].count("RAW_DOM_MATCH"),
            2,
        )
        source["blocks"] = [{"type": "paragraph", "text": "Fee is 500 in 2026."}]
        self.assertEqual(
            raw_block_proof(source, raw)[0]["status"], "RAW_DOM_REQUIRES_REVIEW"
        )

    def test_raw_table_requires_real_cells_and_span_attributes(self):
        raw = b'<div itemprop="articleBody"><table><tr><th colspan="2">A</th></tr></table></div>'
        block = {
            "type": "table",
            "text": "A",
            "caption": None,
            "rows": [[{"text": "A", "header": True, "colspan": "2", "rowspan": "1"}]],
        }
        source = capture(raw) | {"blocks": [block]}
        self.assertEqual(raw_block_proof(source, raw)[0]["status"], "RAW_DOM_MATCH")
        block["rows"][0][0]["colspan"] = "1"
        self.assertEqual(
            raw_block_proof(source, raw)[0]["status"], "RAW_DOM_REQUIRES_REVIEW"
        )

    def test_nested_list_structure_is_not_certified_by_flat_text_alone(self):
        raw = (
            b'<div itemprop="articleBody"><ul><li>A<ol><li>B</li></ol></li></ul></div>'
        )
        block = {
            "type": "bullet_list",
            "text": "A B",
            "items": [{"text": "A B", "children": []}],
        }
        self.assertEqual(
            raw_block_proof(capture(raw) | {"blocks": [block]}, raw)[0]["status"],
            "RAW_DOM_REQUIRES_REVIEW",
        )
        block["items"] = [
            {
                "text": "A",
                "children": [
                    {"ordered": True, "items": [{"text": "B", "children": []}]}
                ],
            }
        ]
        self.assertEqual(
            raw_block_proof(capture(raw) | {"blocks": [block]}, raw)[0]["status"],
            "RAW_DOM_MATCH",
        )

    def test_original_urls_without_captures_remain_explicit(self):
        rows = [
            {
                "source_id": "unavailable",
                "url": "https://radvisa.com/original",
                "disposition": "SOURCE_UNAVAILABLE",
            }
        ]
        result = classify_inventory(rows, [], [])
        self.assertEqual(len(result), 1)
        self.assertEqual(
            result[0]["classification_status"], "NO_ORIGINAL_BODY_EVIDENCE"
        )
        self.assertFalse(result[0]["silently_excluded"])
        with self.assertRaisesRegex(ValueError, "duplicate_original"):
            classify_inventory(rows * 2, [], [])

    def test_operation_payload_must_match_composed_destination(self):
        article = {
            "article_id": "article",
            "locale": "fa",
            "sections": [],
            "segment_ledger": [],
            "country_codes": ["DE"],
            "title": "Original",
            "composition_policy": "RAD_CONTENT_PRECEDENCE_V4.1",
        }
        payload = {"item": article, "sources": []}
        op = {
            "operation_id": "operation",
            "article_id": "article",
            "locale": "fa",
            "revision_id": "future",
            "payload_sha256": sha(payload),
            "payload": payload,
        }
        plan = {"operation_bindings": [{k: v for k, v in op.items() if k != "payload"}]}
        plan["package_sha256"] = sha(plan)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "plan.json").write_text(json.dumps(plan), encoding="utf8")
            (root / "operations.jsonl.gz").write_bytes(
                gzip.compress((json.dumps(op) + "\n").encode())
            )
            result, _ = verify_package_articles(root, [article])
            self.assertEqual(result[("article", "fa")]["revision_id"], "future")
            with self.assertRaisesRegex(ValueError, "destination_mismatch"):
                verify_package_articles(root, [article | {"country_codes": ["FR"]}])

    def test_crosswalk_cannot_omit_a_source_block(self):
        raw = b'<div itemprop="articleBody">Original</div>'
        source = capture(raw) | {"blocks": [{"type": "paragraph", "text": "Original"}]}
        with self.assertRaisesRegex(ValueError, "unexplained_source_segment_loss"):
            list(source_crosswalk([source], [], {}, {}))


if __name__ == "__main__":
    unittest.main()
