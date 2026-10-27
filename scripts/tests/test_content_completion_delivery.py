import copy
import gzip
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.content_completion.complete_recovery import append_contribution
from tools.content_completion.prepare_delivery import prepare
from tools.content_completion.recover_exclusions import retain_blocks
from tools.content_completion.recover_geography import make_draft
from tools.content_completion.resume import resume
from tools.plan3_content.parser import digest


class RecoveryDeliveryTests(unittest.TestCase):
    def test_delivered_recovery_preserves_originals_and_explicit_scope(self):
        root = Path(__file__).resolve().parents[2]
        delivery = root / "_audit/RAD_CONTENT_COMPLETION_20261027/prepared"

        def rows(path):
            with gzip.open(path, "rt", encoding="utf-8") as stream:
                return [json.loads(line) for line in stream]

        sources = {
            s["source_id"]: s
            for s in rows(
                root / "artifacts/RAD_CONTENT_CONSOLIDATION_20261026/sources.jsonl.gz"
            )
        }
        new = rows(delivery / "new-draft-payloads.jsonl.gz")
        revised = rows(delivery / "canonical-revision-payloads.jsonl.gz")
        self.assertEqual((len(new), len(revised)), (80, 91))
        items = {
            (r["article_id"], r["item"]["locale"]): r["item"] for r in new + revised
        }
        for item in items.values():
            self.assertFalse(item["published"])
            self.assertFalse(item["publication_allowed"])
            self.assertEqual(item["verification_state"], "unverified")
            for section in item["sections"]:
                for block in section["blocks"]:
                    for ref in block["provenance"]:
                        source = sources[ref["source_id"]]
                        self.assertEqual(
                            source["body_text"][ref["start"] : ref["end"]],
                            block["original_structure"]["text"],
                        )
                        self.assertEqual(
                            digest(source["blocks"][ref["block_index"]]),
                            ref["structure_sha256"],
                        )
        returning_students = items[("b396ad72-bfd0-5ac5-b26f-38bfd114a5ed", "fa")]
        self.assertEqual(returning_students["content_class"], "editorial")
        self.assertIsNone(returning_students["visa_category"])
        original_drafts = rows(
            root / "artifacts/RAD_CONTENT_RECOVERY_20261027/geographic-drafts.jsonl.gz"
        )
        for draft in original_drafts:
            self.assertEqual(
                items[(draft["article_id"], draft["locale"])]["sections"],
                draft["sections"],
            )
        maps = rows(delivery / "reference-maps.jsonl.gz")
        self.assertEqual({(r["article_id"], r["locale"]) for r in maps}, set(items))
        ledger = rows(delivery / "source-section-ledger.jsonl.gz")
        self.assertEqual(len(ledger), 31055)
        self.assertFalse(
            any(
                r["inclusion_status"] == "unresolved_source_classification"
                for r in ledger
            )
        )
        for record in ledger:
            if not record["destinations"]:
                self.assertTrue(record["exception"])
        retirements = rows(delivery / "source-reading-retirements.jsonl.gz")
        self.assertEqual(len(retirements), 20)
        by_source = {}
        for record in ledger:
            by_source.setdefault(record["source_id"], []).append(record)
        for retirement in retirements:
            for sid in retirement["source_ids"]:
                self.assertEqual(len(by_source[sid]), len(sources[sid]["blocks"]))
                for record in by_source[sid]:
                    self.assertTrue(record["destinations"])
                    self.assertTrue(
                        all(
                            d["content_class"] == "canonical"
                            for d in record["destinations"]
                        )
                    )
                    self.assertTrue(
                        all(
                            d["article_id"] != retirement["article_id"]
                            for d in record["destinations"]
                        )
                    )
        medical = [
            section
            for item in items.values()
            for section in item["sections"]
            if any(
                r["source_id"] == "9550de35-ae09-50fd-adb3-3408cb3dd8b2"
                for b in section["blocks"]
                for r in b["provenance"]
            )
        ]
        self.assertTrue(medical)
        self.assertTrue(all(s["program"] == "medical-study" for s in medical))
        evidence = json.loads(
            (delivery / "body-country-evidence.json").read_text(encoding="utf-8")
        )
        self.assertEqual(len(evidence), 72)
        originals = {
            (r["article_id"], r["locale"]): r
            for r in rows(
                root / "artifacts/RAD_CONTENT_CONSOLIDATION_20261026/articles.jsonl.gz"
            )
        }
        associated = [
            r
            for r in revised
            if r.get("catalog_reclassification", {}).get("kind")
            == "body_evidenced_country_association"
        ]
        self.assertEqual(len(associated), 60)
        for row in associated:
            item = row["item"]
            old = originals[(row["article_id"], item["locale"])]
            self.assertEqual(item["sections"], old["sections"])
            self.assertEqual(old["country_codes"], [])
            proof = item["country_scope_evidence"]
            source = sources[proof["source_id"]]
            self.assertEqual(
                proof["excerpt"], source["blocks"][proof["source_block_index"]]["text"]
            )
            self.assertEqual(item["country_codes"], [proof["country_code"]])
        madrid = {
            ref["block_index"]
            for item in items.values()
            if item["content_class"] == "canonical"
            for sec in item["sections"]
            for block in sec["blocks"]
            for ref in block["provenance"]
            if ref["source_id"] == "f9b092c3-a209-503f-930b-2c7c430ac3b1"
        }
        self.assertTrue(set(range(4, 18)).issubset(madrid))
        talent = [
            (item["visa_category"], ref["block_index"])
            for item in items.values()
            if item["content_class"] == "canonical"
            for sec in item["sections"]
            for block in sec["blocks"]
            for ref in block["provenance"]
            if ref["source_id"] == "d8b26ffb-1004-5aea-8fae-341b409d1aa6"
        ]
        self.assertEqual(set(talent), {("work", i) for i in range(34)})
        nova = [
            block
            for item in items.values()
            if item["visa_category"] == "work"
            for sec in item["sections"]
            for block in sec["blocks"]
            if any(
                ref["source_id"] == "b98d2372-74ed-51fd-9028-775462cbf30e"
                for ref in block["provenance"]
            )
        ]
        self.assertEqual(len(nova), 15)
        self.assertTrue(
            all(
                {ref["source_id"] for ref in block["provenance"]}
                == {
                    "b98d2372-74ed-51fd-9028-775462cbf30e",
                    "1b4d48bc-014f-5cc7-87b6-6d031156c8d3",
                }
                for block in nova
            )
        )
        skilled = [
            r
            for r in ledger
            if r["source_id"] == "e2fac2da-900a-5744-91ff-7ad7649b619c"
        ]
        for record in skilled:
            index = record["source_block_index"]
            expected = (
                {"AU"}
                if index in set(range(1, 7)) | set(range(14, 26))
                else ({"CA"} if index in range(7, 14) else set())
            )
            actual = {
                country
                for d in record["destinations"]
                if d["content_class"] == "canonical"
                for country in d["country_codes"]
            }
            self.assertEqual(actual, expected)

    def test_append_preserves_existing_rich_body_and_limits_source_scope(self):
        blocks = [
            {"type": "heading", "text": "Country background"},
            {"type": "paragraph", "text": "Independent detail"},
            {"type": "heading", "text": "Study eligibility"},
            {"type": "paragraph", "text": "Unique admission exception"},
        ]
        source = {
            "source_id": "s",
            "snapshot_id": "snapshot",
            "url": "https://radvisa.com/article/source",
            "title": "Source",
            "domain": "radvisa.com",
            "language": "en",
            "taxonomy": {"country_codes": ["CA"]},
            "body_text": "\n\n".join(b["text"] for b in blocks),
            "blocks": blocks,
        }
        source["body_sha256"] = digest(source["body_text"])
        independent = make_draft(source)
        base = copy.deepcopy(independent)
        base["article_id"] = "existing-canonical"
        base["source_ids"] = ["existing-source"]
        for section in base["sections"]:
            for block in section["blocks"]:
                for ref in block["provenance"]:
                    ref["source_id"] = "existing-source"
        for ref in base["segment_ledger"]:
            ref["source_id"] = "existing-source"
        baseline = copy.deepcopy(base)
        actual, _ = append_contribution(base, independent, [2, 3])
        self.assertEqual(base, baseline)
        self.assertEqual(actual["sections"][: len(base["sections"])], base["sections"])
        additions = actual["sections"][len(base["sections"]) :]
        self.assertEqual(
            [b["text"] for s in additions for b in s["blocks"]],
            ["Study eligibility", "Unique admission exception"],
        )
        self.assertEqual(
            [
                r["block_index"]
                for r in actual["segment_ledger"][len(base["segment_ledger"]) :]
            ],
            [2, 3],
        )
        retained = retain_blocks(independent, [2, 3])
        self.assertEqual(
            [r["start"] for r in retained["segment_ledger"]],
            [
                r["start"]
                for r in independent["segment_ledger"]
                if r["block_index"] in (2, 3)
            ],
        )

    def test_mirror_keeps_one_body_both_provenances_and_exact_retry(self):
        blocks = [
            {"type": "heading", "text": "Physician stream"},
            {"type": "paragraph", "text": "Distinct eligibility exception"},
        ]
        source = {
            "source_id": "a",
            "snapshot_id": "sa",
            "url": "https://radvisa.com/article/a",
            "title": "Stream",
            "domain": "radvisa.com",
            "language": "en",
            "taxonomy": {"country_codes": ["CA"]},
            "body_text": "\n\n".join(b["text"] for b in blocks),
            "blocks": blocks,
        }
        source["body_sha256"] = digest(source["body_text"])
        first = make_draft(source)
        first["sections"][0]["program"] = "physician-stream"
        baseline = copy.deepcopy(first)
        mirror = make_draft(
            {
                **source,
                "source_id": "b",
                "snapshot_id": "sb",
                "url": "https://digivisa.ir/article/b",
            }
        )
        result, _ = append_contribution(
            first, mirror, [0, 1], "physician-stream", ["a"]
        )
        self.assertEqual(first, baseline)
        actual = [b for s in result["sections"] for b in s["blocks"]]
        self.assertEqual(len(actual), 2)
        self.assertTrue(
            all({r["source_id"] for r in b["provenance"]} == {"a", "b"} for b in actual)
        )
        repeated, _ = append_contribution(
            result, mirror, [0, 1], "physician-stream", ["a"]
        )
        self.assertEqual(repeated, result)

    def test_resume_reuses_historical_journal_without_metadata_sidecar(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            prior, output, corpus = root / "prior", root / "output", root / "corpus"
            prior.mkdir()
            corpus.mkdir()
            raw = b"<article>Original source capture</article>"
            compressed = gzip.compress(raw, mtime=0)
            (prior / "source.html.gz").write_bytes(compressed)
            row = {
                "id": "source",
                "url": "https://radvisa.com/article/test",
                "domain": "radvisa.com",
                "fetch_status": "fetched",
                "status": 200,
                "raw_sha256": hashlib.sha256(raw).hexdigest(),
                "content_type": "text/html",
                "final_url": "https://radvisa.com/article/test",
            }
            (prior / "radvisa.com.progress.jsonl").write_text(
                json.dumps(row) + "\n", encoding="utf-8"
            )
            (corpus / "sources.jsonl.gz").write_bytes(
                gzip.compress((json.dumps({"url": row["url"]}) + "\n").encode())
            )
            with patch("tools.content_completion.resume.GuardedCollector.run") as run:
                resume(prior, corpus, output)
            run.assert_called_once()
            self.assertEqual((prior / "source.html.gz").read_bytes(), compressed)
            self.assertEqual((output / "cache/source.html.gz").read_bytes(), compressed)
            self.assertEqual(
                json.loads((output / "resume-receipt.json").read_text())[
                    "reused_captures"
                ],
                1,
            )
            self.assertEqual(
                json.loads((output / "cache/source.json").read_text())["raw_sha256"],
                row["raw_sha256"],
            )

    def test_production_refused_before_any_file_read(self):
        with self.assertRaisesRegex(ValueError, "staging_only"):
            prepare(Path("absent"), Path("absent"), "inshddthftkhcdosoqcn")


if __name__ == "__main__":
    unittest.main()
