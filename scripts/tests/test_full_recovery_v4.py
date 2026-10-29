"""Recovery never turns missing evidence into a completed article."""

import gzip
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock
from urllib.robotparser import RobotFileParser

from tools.content_completion.full_recovery_v4 import (
    FULL,
    Links,
    Recovery,
    capture_from_raw,
    decode_html,
    route_disposition,
)
from tools.plan3_content.dataset import write_jsonl


class FullRecoveryV4Test(unittest.TestCase):
    def test_legitimate_joomla_article_is_not_generic_query_exclusion(self):
        self.assertIsNone(
            route_disposition(
                "https://radmohajer.ir/index.php?option=com_content&view=article&id=22"
            )
        )

    def test_stateful_joomla_task_stays_excluded(self):
        self.assertEqual(
            route_disposition(
                "https://radmohajer.ir/index.php?option=com_content&view=article&id=22&task=delete"
            )[0],
            "NONCONTENT_ROUTE",
        )

    def test_image_under_administrator_is_media_not_article_exclusion(self):
        self.assertEqual(
            route_disposition("https://digivisa.ir/administrator/files/test.jpg")[0],
            "ATTACHMENT_REFERENCE",
        )

    def test_encoding_windows1256_preserves_persian(self):
        original = '<html><meta charset="windows-1256"><p>مهاجرت به آلمان</p></html>'
        decoded, encoding = decode_html(original.encode("cp1256"))
        self.assertEqual(decoded.decode("utf-8"), original)
        self.assertEqual(encoding, "cp1256")

    def test_invalid_encoding_is_not_replacement_success(self):
        with self.assertRaises(UnicodeDecodeError):
            decode_html(b"<html>\xff\xff</html>")

    def test_nested_structure_and_raw_hash_survive(self):
        raw = (
            '<html lang="fa"><h1>مقاله</h1><div itemprop="articleBody"><p>'
            + "متن کامل مقاله مهاجرت به آلمان. " * 20
            + "</p><ul><li>یک<ul><li>دو</li></ul></li></ul><table><tr><th>شرط</th><th>مقدار</th></tr><tr><td>سن</td><td>۲۵</td></tr></table></div></html>"
        ).encode()
        capture = capture_from_raw(
            raw, "https://radmohajer.ir/fa/article", {"status": 200}, "original.gz"
        )[0]
        self.assertEqual(capture["completeness"], FULL)
        self.assertTrue(any(b["type"] == "table" for b in capture["blocks"]))
        self.assertTrue(any(b["type"] == "bullet_list" for b in capture["blocks"]))
        self.assertIsNone(capture["acquisition_timestamp"])
        self.assertFalse(capture["publication_allowed"])

    def test_pagination_and_canonical_links_are_discovered(self):
        links = Links(
            b'<a href="?start=10" rel="next">Next</a><a href="/fa/article">a</a><a href="javascript:fail()">x</a>',
            "https://radmohajer.ir/fa",
        )
        self.assertIn("https://radmohajer.ir/fa?start=10", links.pagination)
        self.assertIn("https://radmohajer.ir/fa/article", links.links)
        self.assertEqual(len(links.links), 2)

    def test_failed_fetch_is_unresolved_not_unrecoverable(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            bundle, output = root / "bundle", root / "output"
            bundle.mkdir()
            write_jsonl(
                bundle / "source-master.jsonl.gz",
                [
                    {
                        "url": "https://radvisa.com/unknown-article",
                        "source_id": "source",
                        "recovery_status": "unavailable_or_unfetched",
                    }
                ],
            )
            write_jsonl(bundle / "source-captures.jsonl.gz", [])
            recovery = Recovery(bundle, output)
            recovery.observations.append(
                {"url": "https://radvisa.com/unknown-article", "error": "timeout"}
            )
            summary = recovery.run()
            inventory = [
                json.loads(x)
                for x in gzip.decompress((output / "inventory.jsonl.gz").read_bytes())
                .decode()
                .splitlines()
            ]
            self.assertEqual(inventory[0]["disposition"], "SOURCE_UNRESOLVED")
            self.assertEqual(summary["unrecoverable_claimed"], 0)
            self.assertEqual(summary["complete_source_pages"], 0)

    def test_distinct_complete_versions_get_composable_supplements(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            bundle, output = root / "bundle", root / "output"
            bundle.mkdir()
            url = "https://radmohajer.ir/fa/example"
            write_jsonl(
                bundle / "source-master.jsonl.gz",
                [
                    {
                        "url": url,
                        "source_id": "source",
                        "recovery_status": "full_body_and_verified_raw",
                    }
                ],
            )
            write_jsonl(bundle / "source-captures.jsonl.gz", [])
            recovery = Recovery(bundle, output)
            for value in ("شرایط قدیمی ", "شرایط تازه "):
                raw = (
                    '<h1>مقاله</h1><div itemprop="articleBody"><p>'
                    + value * 40
                    + "</p></div>"
                ).encode()
                recovery.by_url[url].extend(
                    capture_from_raw(raw, url, {}, "raw.html.gz")
                )
            summary = recovery.finish()
            self.assertEqual(summary["complete_source_pages"], 1)
            self.assertEqual(summary["alternate_complete_source_versions"], 1)
            supplements = [
                json.loads(x)
                for x in gzip.decompress(
                    (output / "version-supplements.jsonl.gz").read_bytes()
                )
                .decode()
                .splitlines()
            ]
            self.assertNotEqual(
                supplements[0]["source_id"], supplements[0]["origin_source_id"]
            )
            self.assertEqual(summary["distinct_complete_capture_versions"], 2)

    def test_fresh_fetch_binds_relative_output_asset_to_repository_root(self):
        with tempfile.TemporaryDirectory(dir=Path.cwd()) as temp:
            root = Path(temp).relative_to(Path.cwd())
            bundle, output = root / "bundle", root / "output"
            bundle.mkdir()
            url = "https://radmohajer.ir/fa/example"
            write_jsonl(
                bundle / "source-master.jsonl.gz",
                [
                    {
                        "url": url,
                        "source_id": "source",
                        "recovery_status": "unavailable_or_unfetched",
                    }
                ],
            )
            write_jsonl(bundle / "source-captures.jsonl.gz", [])
            recovery = Recovery(bundle, output)
            policy = RobotFileParser()
            policy.parse(["User-agent: *", "Allow: /"])
            recovery.collector.robots["radmohajer.ir"] = policy
            raw = (
                '<h1>مقاله</h1><div itemprop="articleBody"><p>'
                + "متن مقاله " * 50
                + "</p></div>"
            ).encode()
            recovery.collector.request = Mock(
                return_value=(
                    raw,
                    {
                        "status": 200,
                        "final_url": url,
                        "content_type": "text/html; charset=utf-8",
                    },
                )
            )
            recovery.fetch_host("radmohajer.ir")
            self.assertEqual(recovery.by_url[url][0]["completeness"], FULL)
            self.assertTrue(Path(recovery.by_url[url][0]["raw_html_asset"]).is_file())
            self.assertFalse(any("error" in row for row in recovery.observations))


if __name__ == "__main__":
    unittest.main()
