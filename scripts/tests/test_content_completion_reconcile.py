import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.content_completion.reconcile import make_records, progress
from tools.plan3_content.parser import digest


class ReconciliationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.cache = Path(self.directory.name)
        self.source = {
            "url": "https://digivisa.ir/example",
            "source_id": "one",
            "domain": "digivisa.ir",
            "body_sha256": "old",
            "complete_article_body": True,
        }
        self.article = {"article_id": "a", "locale": "fa"}
        self.ledger = {"source_id": "one", "destination_article_id": "a"}

    def test_unobserved_is_not_called_current_or_staging_verified(self):
        rows = make_records(
            [self.source], [self.article], [], [self.ledger], {}, self.cache
        )
        self.assertEqual(rows[0]["change_disposition"], "not_recrawled")
        self.assertFalse(rows[0]["original_coverage_verified_in_staging"])
        self.assertEqual(rows[0]["destination_article_ids"], ["a"])

    def test_new_url_is_unmapped_and_failure_remains_explicit(self):
        fresh = {
            "https://radvisa.com/new": {
                "url": "https://radvisa.com/new",
                "domain": "radvisa.com",
                "fetch_status": "http_error",
                "status": 403,
            }
        }
        rows = make_records(
            [self.source], [self.article], [], [self.ledger], fresh, self.cache
        )
        new = next(row for row in rows if row["source_id"] is None)
        self.assertEqual(new["change_disposition"], "fresh_fetch_unresolved")
        self.assertEqual(new["fresh_http_status"], 403)
        self.assertEqual(new["destination_article_ids"], [])

    def test_missing_destination_is_not_silently_reported_as_complete(self):
        with self.assertRaisesRegex(ValueError, "orphan_destination_segment"):
            make_records([self.source], [], [], [self.ledger], {}, self.cache)

    def test_skipped_host_does_not_erase_previous_actual_observation(self):
        url = "https://radmohajer.ir/example"
        with (self.cache / "radmohajer.ir.progress.jsonl").open(
            "w", encoding="utf8"
        ) as f:
            for status in ("fetched", "robots_denied_or_unavailable"):
                f.write(json.dumps({"url": url, "fetch_status": status}) + "\n")
        row = progress(self.cache)[url]
        self.assertEqual(row["fetch_status"], "fetched")
        self.assertEqual(row["latest_access_status"], "robots_denied_or_unavailable")

    @patch("tools.content_completion.reconcile.fresh_body")
    def test_same_text_does_not_hide_changed_table_or_link(self, body):
        url = self.source["url"]
        self.source.update(
            body_sha256=digest("same"),
            blocks=[{"type": "table", "rows": [["a"]]}],
            body_links=[{"url": "https://example.org/a"}],
        )
        observed = {url: {"url": url, "fetch_status": "fetched"}}
        body.return_value = (
            {
                "body_text": "same",
                "blocks": self.source["blocks"],
                "body_links": self.source["body_links"],
            },
            "hash_verified_raw",
        )
        row = make_records(
            [self.source], [self.article], [], [self.ledger], observed, self.cache
        )[0]
        self.assertEqual(row["change_disposition"], "body_blocks_and_links_unchanged")
        body.return_value[0]["body_links"] = [{"url": "https://example.org/different"}]
        row = make_records(
            [self.source], [self.article], [], [self.ledger], observed, self.cache
        )[0]
        self.assertEqual(
            row["change_disposition"],
            "structure_or_links_changed_requires_reconciliation",
        )


if __name__ == "__main__":
    unittest.main()
