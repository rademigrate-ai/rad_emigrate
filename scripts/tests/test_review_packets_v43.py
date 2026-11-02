"""Review packets fail closed and never treat an owner choice as publication."""

import copy
import hashlib
import importlib
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory


class ReviewPacketsTest(unittest.TestCase):
    def module(self):
        name = "tools.content_completion.review_packets_v43"
        self.assertIsNotNone(
            importlib.util.find_spec(name), "review packet generator is missing"
        )
        return importlib.import_module(name)

    def fixture(self):
        m = self.module()
        case = {
            "case_id": "heading:original-capture:4",
            "category": "heading",
            "source_id": "source",
            "capture_ids": ["original-capture"],
            "source_url": "https://example.invalid/original",
            "choices": [
                {
                    "id": "retain_unlevelled",
                    "effect": {"action": "keep_text", "publication_allowed": False},
                }
            ],
            "evidence": {"raw_html_sha256": "a" * 64},
        }
        case["case_sha256"] = m.case_hash(case)
        packet = {
            "version": "RAD_REVIEW_PACKETS_V4.3",
            "publication_allowed": False,
            "inputs": {},
            "cases": [case],
        }
        packet["packet_sha256"] = m.packet_hash(packet)
        decision = {
            "packet_sha256": packet["packet_sha256"],
            "publication_allowed": False,
            "decisions": [
                {
                    "case_id": case["case_id"],
                    "case_sha256": case["case_sha256"],
                    "choice": "retain_unlevelled",
                }
            ],
        }
        return m, packet, decision

    def test_valid_choice_emits_only_offline_effect_and_preserves_reference(self):
        m, packet, batch = self.fixture()
        plan = m.validate_decisions(packet, batch)
        self.assertFalse(plan["publication_allowed"])
        self.assertEqual(plan["hosted_writes"], 0)
        self.assertEqual(
            plan["decisions"][0]["source_url"], "https://example.invalid/original"
        )
        self.assertEqual(plan["decisions"][0]["effect"]["action"], "keep_text")
        self.assertEqual(plan["remaining_undecided"], 0)

    def test_stale_packet_and_case_hashes_fail(self):
        m, packet, batch = self.fixture()
        for field in ["packet_sha256", "case_sha256"]:
            changed = copy.deepcopy(batch)
            (changed if field == "packet_sha256" else changed["decisions"][0])[
                field
            ] = "0" * 64
            with self.subTest(field=field), self.assertRaises(ValueError):
                m.validate_decisions(packet, changed)

    def test_illegal_choice_duplicate_and_publication_fail(self):
        m, packet, batch = self.fixture()
        variants = []
        illegal = copy.deepcopy(batch)
        illegal["decisions"][0]["choice"] = "publish"
        variants.append(illegal)
        duplicate = copy.deepcopy(batch)
        duplicate["decisions"] *= 2
        variants.append(duplicate)
        publish = copy.deepcopy(batch)
        publish["publication_allowed"] = True
        variants.append(publish)
        override = copy.deepcopy(batch)
        override["decisions"][0]["approved"] = True
        variants.append(override)
        for changed in variants:
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                m.validate_decisions(packet, changed)

    def test_nested_publication_in_a_rehashed_packet_is_still_forbidden(self):
        m, packet, batch = self.fixture()
        packet["cases"][0]["choices"][0]["effect"]["publication_allowed"] = True
        packet["cases"][0]["case_sha256"] = m.case_hash(packet["cases"][0])
        packet["packet_sha256"] = m.packet_hash(packet)
        batch["packet_sha256"] = packet["packet_sha256"]
        batch["decisions"][0]["case_sha256"] = packet["cases"][0]["case_sha256"]
        with self.assertRaises(ValueError):
            m.validate_decisions(packet, batch)

    def test_blank_template_is_not_an_approval(self):
        m, packet, _ = self.fixture()
        template = m.decision_template(packet)
        self.assertIsNone(template["decisions"][0]["choice"])
        plan = m.validate_decisions(packet, template)
        self.assertEqual(plan["remaining_undecided"], 1)
        self.assertEqual(plan["decisions"], [])

    def test_link_choice_retains_source_label_as_effect_metadata(self):
        m = self.module()
        item = m.choice(
            "request",
            "Request clarification",
            "queue_request",
            label="Original anchor label",
        )
        self.assertEqual(item["effect"]["label"], "Original anchor label")

    def test_minimal_batch_preserves_every_case_hash_and_rejects_tampering(self):
        m, packet, _ = self.fixture()
        packet["owner_batches"] = m.owner_batches(packet["cases"])
        packet["packet_sha256"] = m.packet_hash(packet)
        template = m.batch_template(packet)
        self.assertIsNone(template["batches"][0]["choice"])
        template["batches"][0]["choice"] = "retain_unlevelled"
        expanded = m.expand_batches(packet, template)
        self.assertEqual(
            m.validate_decisions(packet, expanded)["remaining_undecided"], 0
        )
        template["batches"][0]["batch_sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            m.expand_batches(packet, template)

    def test_changed_original_input_or_tampered_case_fails(self):
        m, packet, batch = self.fixture()
        with TemporaryDirectory() as temp:
            path = Path(temp) / "raw.bin"
            path.write_bytes(b"original")
            packet["inputs"] = {str(path): hashlib.sha256(b"original").hexdigest()}
            packet["packet_sha256"] = m.packet_hash(packet)
            batch["packet_sha256"] = packet["packet_sha256"]
            path.write_bytes(b"changed")
            with self.assertRaises(ValueError):
                m.validate_decisions(packet, batch)
        packet["inputs"] = {}
        packet["cases"][0]["source_url"] = "https://example.invalid/substituted"
        packet["packet_sha256"] = m.packet_hash(packet)
        batch["packet_sha256"] = packet["packet_sha256"]
        with self.assertRaises(ValueError):
            m.validate_decisions(packet, batch)

    def test_raw_html_is_escaped_and_byte_roundtrip_required(self):
        m = self.module()
        raw = b'<script>fetch("https://example.invalid")</script>\xff'
        page = m.raw_evidence_html(raw)
        self.assertNotIn("<script>", page)
        self.assertIn("&lt;script&gt;", page)
        self.assertIn("Content-Security-Policy", page)
        self.assertIn("ff", page)
        proof = m.encoding_roundtrip(raw, hashlib.sha256(raw).hexdigest(), "latin1")
        self.assertTrue(proof["roundtrip_equal"])
        self.assertFalse(proof["semantic_encoding_verified"])
        with self.assertRaises(ValueError):
            m.encoding_roundtrip(raw, "0" * 64, "latin1")
        with self.assertRaises(ValueError):
            m.encoding_roundtrip(raw, hashlib.sha256(raw).hexdigest(), "utf8")

    def test_affected_blocks_use_exact_provenance_not_title_similarity(self):
        m = self.module()
        articles = [
            {
                "article_id": "a",
                "locale": "fa",
                "sections": [
                    {
                        "id": "section",
                        "blocks": [
                            {
                                "id": "block1",
                                "provenance": [{"source_id": "s", "block_index": 2}],
                            }
                        ],
                    }
                ],
            }
        ]
        index = m.affected_block_index(articles)
        self.assertEqual(
            index[("s", 2)],
            [
                {
                    "article_id": "a",
                    "locale": "fa",
                    "section_id": "section",
                    "block_id": "block1",
                }
            ],
        )
        self.assertNotIn(("other-source", 2), index)

    def test_repeated_original_proof_rows_keep_distinct_stable_case_ids(self):
        m = self.module()
        proof = {
            "capture_id": "same-original",
            "canonical_url": "https://example.invalid/a",
            "label": "same",
        }
        self.assertNotEqual(
            m.link_case_identity(proof, 2), m.link_case_identity(proof, 3)
        )
        self.assertEqual(m.link_case_identity(proof, 2), m.link_case_identity(proof, 2))

    def test_relocated_asset_is_resolved_without_rewriting_legacy_identity(self):
        m = self.module()
        original = "C:/Users/Mehrshad/Desktop/RAD - Emigrate/rad_full_content_v4/raw/original.html.gz"
        with TemporaryDirectory() as temp:
            workspace = Path(temp) / "RAD - Emigrate"
            asset = workspace / "rad_full_content_v4/raw/original.html.gz"
            asset.parent.mkdir(parents=True)
            asset.write_bytes(b"immutable raw")
            self.assertEqual(m.resolve_asset(original, [workspace]), asset)
        self.assertTrue(original.startswith("C:/"))

    def test_output_inside_sealed_evidence_is_rejected_before_any_write(self):
        m = self.module()
        with TemporaryDirectory() as temp:
            original = Path(temp) / "sealed-originals"
            original.mkdir()
            for output in [original, original / "nested"]:
                with self.subTest(output=output), self.assertRaises(ValueError):
                    m.guard_output_directory(output, [original])
            self.assertFalse((original / "nested").exists())
            m.guard_output_directory(Path(temp) / "new-review-output", [original])


if __name__ == "__main__":
    unittest.main()
