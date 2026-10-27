"""Check delivered recovery drafts against immutable original source blocks."""

import json
import unittest
from pathlib import Path

from tools.plan3_content.dataset import read_jsonl
from tools.plan3_content.parser import digest


class GeographicDeliveryTests(unittest.TestCase):
    def test_each_delivered_block_and_reference_is_source_bound(self):
        root = Path("artifacts/RAD_CONTENT_RECOVERY_20261027")
        originals = {
            s["source_id"]: s
            for s in read_jsonl(
                Path("artifacts/RAD_CONTENT_CONSOLIDATION_20261026/sources.jsonl.gz")
            )
        }
        drafts = read_jsonl(root / "geographic-drafts.jsonl.gz")
        payloads = read_jsonl(root / "technically-ready-payloads.jsonl.gz")
        maps = read_jsonl(root / "article-reference-maps.jsonl.gz")
        decisions = json.loads((root / "dispositions.json").read_text(encoding="utf8"))
        observed = [
            json.loads(line)
            for line in (root / "source-observations.jsonl")
            .read_text(encoding="utf8")
            .splitlines()
        ]
        self.assertEqual(
            (len(drafts), len(payloads), len(maps), len(decisions), len(observed)),
            (49, 33, 49, 49, 49),
        )
        by_article = {(a["article_id"], a["locale"]): a for a in drafts}
        self.assertEqual(len(by_article), len(drafts))
        for article in drafts:
            self.assertEqual(len(article["source_ids"]), 1)
            source = originals[article["source_ids"][0]]
            blocks = [b for section in article["sections"] for b in section["blocks"]]
            self.assertEqual(
                [b["original_structure"] for b in blocks], source["blocks"]
            )
            self.assertFalse(article["publication_allowed"])
            self.assertFalse(article["published"])
            self.assertIsNone(article["reviewer_id"])
            for index, block in enumerate(blocks):
                ref = block["provenance"][0]
                self.assertEqual(ref["block_index"], index)
                self.assertEqual(ref["snapshot_id"], source["snapshot_id"])
                self.assertEqual(
                    source["body_text"][ref["start"] : ref["end"]], block["text"]
                )
                self.assertEqual(
                    digest(block["original_structure"]), ref["structure_sha256"]
                )
        for item in maps:
            article = by_article[(item["article_id"], item["locale"])]
            source = originals[article["source_ids"][0]]
            self.assertEqual(item["map"]["capture_status"], "complete")
            self.assertEqual(
                item["map"]["sources"][0]["raw_html_sha256"], source["raw_html_sha256"]
            )
            self.assertTrue(
                all(
                    link["source_snapshot_id"] == source["snapshot_id"]
                    for link in item["map"]["links"]
                )
            )
        self.assertEqual(
            {p["article_id"] for p in payloads},
            {
                d["article_id"]
                for d in decisions
                if d["technical_status"] == "local_draft_candidate"
            },
        )
        self.assertTrue(
            all(
                row["change_disposition"] == "body_blocks_and_links_unchanged"
                for row in observed
            )
        )


if __name__ == "__main__":
    unittest.main()
