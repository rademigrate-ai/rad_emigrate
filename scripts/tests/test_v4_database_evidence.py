import gzip
import json
import tempfile
import unittest
from pathlib import Path

from tools.content_completion.v4_database_evidence import jsonb_text, prepare


class IndependentDatabaseEvidence(unittest.TestCase):
    def test_compiler_cannot_drop_a_block_and_certify_its_own_payload(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ref = {"source_id": "variant", "snapshot_id": "original"}
            article = {
                "article_id": "dc64ad5e-c2bf-403a-955f-24e42c097361",
                "locale": "fa",
                "title": "عنوان",
                "country_codes": ["DE"],
                "category": "study",
                "content_class": "canonical",
                "sections": [
                    {
                        "blocks": [
                            {"id": "one", "text": "Unique fact.", "provenance": [ref]}
                        ]
                    }
                ],
            }

            def write(name, rows):
                with gzip.open(
                    root / (name + ".jsonl.gz"), "wt", encoding="utf-8"
                ) as stream:
                    for row in rows:
                        stream.write(json.dumps(row) + "\n")

            write("articles", [article])
            write("sources", [{"source_id": "variant", "snapshot_id": "original"}])
            write("supplements", [])
            item = json.loads(json.dumps(article))
            item["sections"][0]["blocks"][0]["provenance"] = [
                {
                    "source_id": "stored-document",
                    "snapshot_id": "stored-snapshot",
                    "source_variant_id": "variant",
                }
            ]
            write("payload", [{"article_id": article["article_id"], "item": item}])
            self.assertTrue(
                prepare(root / "payload.jsonl.gz", root / "valid", composition=root)[
                    "independent_composition_payload_bridge"
                ]
            )
            item["sections"][0]["blocks"] = []
            write("payload", [{"article_id": article["article_id"], "item": item}])
            with self.assertRaisesRegex(
                ValueError, "composition_payload_content_mismatch"
            ):
                prepare(root / "payload.jsonl.gz", root / "lost", composition=root)

    def test_postgres_key_order_uses_utf8_byte_length_then_binary(self):
        self.assertEqual(
            jsonb_text({"long": [True, None, "متن"], "é": 2, "b": 1, "aa": 3}),
            '{"b": 1, "aa": 3, "é": 2, "long": [true, null, "متن"]}',
        )

    def test_unsupported_numeric_normalization_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "unsupported_jsonb"):
            jsonb_text({"threshold": 1.2})

    def test_expected_browser_hash_covers_media_and_links(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            payload = root / "payload.jsonl.gz"
            row = {
                "article_id": "dc64ad5e-c2bf-403a-955f-24e42c097361",
                "item": {
                    "locale": "fa",
                    "sections": [{"blocks": [{"text": "متن"}]}],
                    "source_assets": [{"url": "https://digivisa.ir/image.png"}],
                },
            }

            def write():
                with gzip.open(payload, "wt", encoding="utf-8") as stream:
                    stream.write(json.dumps(row) + "\n")

            write()
            prepare(payload, root / "first")
            first = json.loads((root / "first/expected-ui-heads.json").read_text())[0]
            row["item"]["source_assets"] = []
            write()
            prepare(payload, root / "second")
            second = json.loads((root / "second/expected-ui-heads.json").read_text())[0]
            self.assertEqual(
                first["expected_rich_sections_sha256"],
                second["expected_rich_sections_sha256"],
            )
            self.assertNotEqual(
                first["expected_body_sha256"], second["expected_body_sha256"]
            )
            query = (root / "first/database-query-0000.sql").read_text()
            self.assertIn("substring(ss.normalized_text", query)
            self.assertIn("rollback;", query)
            self.assertNotIn("update ", query)


if __name__ == "__main__":
    unittest.main()
