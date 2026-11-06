"""CI proof: shipped source snapshot is read-only, complete and hash-bound.

The private source-capture corpus is not needed in GitHub CI. Local generation
verifies against the sealed corrected batch payloads before writing assets.
"""

import gzip
import hashlib
import json
import unittest
from pathlib import Path
from urllib.parse import urlsplit


class FrozenVisaDeliveryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(__file__).resolve().parents[2]
        cls.folder = cls.root / "assets/visa_frozen_content"
        cls.index = json.loads((cls.folder / "index.json").read_text("utf-8"))

    def test_all_1077_articles_are_bundled_and_23_holds_excluded(self):
        index = self.index
        self.assertEqual(index["format"], "RAD_FROZEN_VISA_DELIVERY_V1")
        self.assertEqual(index["total_candidates"], 1077)
        self.assertEqual(index["held_excluded"], 23)
        self.assertEqual(index["countries_count"], 56)
        self.assertEqual(index["independent_other_titles"], 251)
        self.assertFalse(index["editorial_approved"])
        self.assertEqual(index["update_mode"], "read_only")
        self.assertFalse(index["production_database_written"])
        self.assertEqual(
            index["source_package_sha256"],
            "4beb6ba711c5b0243d69be29b32a76c13f5ebcc47ce131e7ca406bcd67e6c282",
        )
        rows = index["articles"]
        self.assertEqual(len(rows), 1077)
        self.assertEqual(len({(r["id"], r["locale"]) for r in rows}), 1077)
        self.assertEqual(
            len({p.name for p in (self.folder / "articles").glob("*.json.gz")}),
            1077,
        )
        self.assertEqual(len({code for r in rows for code in r["country_codes"]}), 56)
        self.assertEqual(sum(not r["country_codes"] for r in rows), 251)

    def test_every_article_body_and_source_is_integrity_bound(self):
        allowed = {"digivisa.ir", "radvisa.com", "radmohajer.ir"}
        seen = set()
        for row in self.index["articles"]:
            path = self.root / row["asset"]
            self.assertTrue(path.is_file(), row["asset"])
            compressed = path.read_bytes()
            self.assertEqual(
                hashlib.sha256(compressed).hexdigest(),
                row["compressed_sha256"],
                row["id"],
            )
            raw = gzip.decompress(compressed)
            self.assertEqual(hashlib.sha256(raw).hexdigest(), row["sha256"])
            article = json.loads(raw)
            self.assertEqual(article["id"], row["id"])
            self.assertEqual(article["revision_id"], row["revision_id"])
            self.assertFalse(article["editorial_approved"])
            self.assertEqual(article["verification_state"], "unverified")
            self.assertEqual(article["delivery_mode"], "frozen_source_readonly")
            self.assertEqual(article["source_policy"], "RAD_CONTENT_PRECEDENCE_V4.1")
            self.assertTrue(article["rich_sections"], row["id"])
            self.assertTrue(article["sources"], row["id"])
            self.assertFalse(article["source_assets"])
            self.assertEqual(article["country_codes"], row["country_codes"])
            self.assertEqual(
                row["block_count"],
                sum(len(section["blocks"]) for section in article["rich_sections"]),
            )
            for section in article["rich_sections"]:
                self.assertTrue(section["blocks"])
                for block in section["blocks"]:
                    self.assertTrue(
                        block.get("original_structure") is not None
                        or block.get("text") is not None
                    )
            for source in article["sources"]:
                url = urlsplit(source["url"])
                self.assertEqual(url.scheme in {"http", "https"}, True)
                self.assertIn(url.hostname.removeprefix("www."), allowed)
                self.assertEqual(len(source["body_sha256"]), 64)
            seen.add(row["asset"])
        self.assertEqual(len(seen), 1077)

    def test_no_candidate_becomes_an_automatic_research_publication(self):
        for row in self.index["articles"]:
            self.assertNotIn("service_role", row)
            self.assertNotIn("approved_by", row)
            self.assertNotIn("publication_receipt", row)
            self.assertNotIn("feed_id", row)


if __name__ == "__main__":
    unittest.main()
