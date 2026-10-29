import gzip
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.content_completion.grok_transfer import ingest
from tools.content_completion.phase_bundle import Bundle, confined, prepare_independent
from tools.content_completion.phase_delivery import duplicates, verify_payload
from tools.content_completion.source_evidence import (
    country_evidence,
    original_url,
    parse_mohajer,
)
from tools.plan3_content.parser import digest


class SourceEvidenceTests(unittest.TestCase):
    def test_country_substrings_and_disagreements_are_not_guessed(self):
        proof = country_evidence(
            "مهندسی و تکمیل فرم",
            "https://radmohajer.ir/fa/guide",
            "Ukraine is discussed alongside the UK and Canada.",
        )
        self.assertEqual(proof["country_codes"], [])
        self.assertNotIn("IN", proof["body_candidates"])
        self.assertNotIn("IT", proof["body_candidates"])
        conflict = country_evidence(
            "تحصیل در آلمان", "https://radmohajer.ir/fa/کانادا/study", ""
        )
        self.assertTrue(conflict["disagreement"])
        self.assertEqual(conflict["country_codes"], [])
        self.assertEqual(
            country_evidence(
                "تحصیل در اوکراین", "https://radmohajer.ir/fa/ukraine", ""
            )["country_codes"],
            ["UA"],
        )

    def test_archived_unicode_identity_preserves_reserved_query_and_language(self):
        url = original_url(
            "https://web.archive.org/web/20260227001930id_/http://www.radmohajer.ir/fa/کشورها/a%2fb?start=4&utm_source=test"
        )
        self.assertEqual(
            url,
            "https://radmohajer.ir/fa/%DA%A9%D8%B4%D9%88%D8%B1%D9%87%D8%A7/a%2Fb?start=4",
        )
        self.assertNotEqual(
            original_url("https://radmohajer.ir/fa/a%2fb"),
            original_url("https://radmohajer.ir/fa/a/b"),
        )
        self.assertNotEqual(
            original_url("https://radmohajer.ir/fa/article"),
            original_url("https://radmohajer.ir/en/article"),
        )
        with self.assertRaises(ValueError):
            original_url("https://user:password@radmohajer.ir/fa/article")

    def test_owned_article_preserves_unicode_heading_table_list_and_archive_link(self):
        html = """<html><h1>Unrelated navigation title</h1><div class="item-page"><div class="page-header"><h2 itemprop="headline">شرایط تحصیل در کانادا</h2></div><dl class="article-info">chrome</dl><div itemprop="articleBody"><h2>مدارک و استثناها</h2><p>متن اصلی فارسی با نیم‌فاصله و شرطی که باید کامل محفوظ بماند. مدارک باید معتبر باشد و شرایط هر برنامه متفاوت است.</p><div class="pull-right"><table><tr><th rowspan="2">مدرک</th><th>هزینه</th></tr><tr><td>۱۲۰ دلار</td></tr></table></div><ol><li>اصل مدرک<ul><li>ترجمه رسمی</li></ul></li><li>استثنای برنامه</li></ol><a href="/web/20260227001930/http://www.radmohajer.ir/fa/documents">مدارک اصلی</a></div></div><footer>unrelated footer</footer></html>"""
        parsed = parse_mohajer(html.encode(), "https://radmohajer.ir/fa/article")
        article = parsed["articles"][0]
        self.assertEqual(parsed["page_kind"], "article")
        self.assertEqual(article["title"], "شرایط تحصیل در کانادا")
        self.assertNotIn("unrelated", article["body_text"])
        self.assertIn("نیم‌فاصله", article["body_text"])
        self.assertEqual(article["blocks"][0]["level"], 2)
        table = next(b for b in article["blocks"] if b["type"] == "table")
        self.assertEqual(table["rows"][0][0]["rowspan"], "2")
        ordered = next(b for b in article["blocks"] if b["type"] == "numbered_list")
        self.assertEqual(
            ordered["items"][0]["children"][0]["items"][0]["text"], "ترجمه رسمی"
        )
        self.assertEqual(
            article["original_links"][0]["url"], "https://radmohajer.ir/fa/documents"
        )
        self.assertIn("/web/", article["original_links"][0]["original_href"])

    def test_listing_without_readmore_is_never_promoted_to_full_article(self):
        html = (
            '<html><div class="blog"><div itemprop="blogPost"><div class="page-header"><h2><a href="/fa/full-article">Article title</a></h2></div><p>'
            + ("A substantive but clipped teaser. " * 20)
            + "</p></div></div></html>"
        )
        parsed = parse_mohajer(
            html.encode(), "https://radmohajer.ir/fa/articles?start=4"
        )
        self.assertEqual(parsed["articles"], [])
        self.assertEqual(parsed["page_kind"], "listing")
        self.assertEqual(len(parsed["listing_excerpts"]), 1)
        self.assertEqual(
            parsed["listing_excerpts"][0]["completeness"], "partial_listing_excerpt"
        )

    def test_raw_asset_is_lossless_deterministic_and_paths_are_confined(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            bundle = Bundle(root, [], "2026-10-28T09:30:43Z")
            raw = "<html>اصل متن فارسی</html>".encode()
            first = bundle.raw_asset(raw)
            data = (root / first["raw_html_asset"]).read_bytes()
            self.assertEqual(gzip.decompress(data), raw)
            self.assertEqual(data[9], 255)
            self.assertEqual(bundle.raw_asset(raw), first)
            self.assertEqual((root / first["raw_html_asset"]).read_bytes(), data)
            with self.assertRaises(ValueError):
                confined(root, "../outside.html")
            with self.assertRaises(ValueError):
                bundle.capture(
                    {"url": "https://radmohajer.ir/fa/test"},
                    {
                        "body_text": "different",
                        "blocks": [{"type": "paragraph", "text": "body"}],
                        "body_sha256": digest("different"),
                    },
                    "fixture",
                    raw,
                )


class DraftReconciliationTests(unittest.TestCase):
    def test_original_transfer_rejects_wrong_envelope_before_any_import_or_output(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            archive = root / "wrong.zip"
            archive.write_bytes(b"not the approved original transfer")
            output = root / "delivery"
            with self.assertRaisesRegex(
                ValueError, "original_transfer_ZIP_hash_mismatch"
            ):
                ingest(
                    output, root, archive, root / "handoff.md", "2026-10-28T10:27:59Z"
                )
            self.assertFalse(output.exists())

    def fixture(self, root, urls, existing=None):
        prepared = root / "prepared"
        prepared.mkdir()
        (prepared / "other-titles-inventory.json").write_text(
            json.dumps(existing or []), encoding="utf-8"
        )
        bundle = Bundle(root, [], "2026-10-28T09:30:43Z")
        for url, body in urls:
            bundle.capture(
                {"url": url, "language": "fa"},
                {
                    "title": "راهنمای کانادا",
                    "body_text": body,
                    "blocks": [{"type": "paragraph", "text": body}],
                    "completeness": "complete_owned_article_container",
                },
                "preserved_fixture",
                ("<article>" + body + "</article>").encode(),
            )
        registry = json.loads(
            Path("supabase/contracts/rad_v1.json").read_text(encoding="utf-8")
        )
        with patch("tools.content_completion.phase_bundle.BASE", root):
            result = prepare_independent(bundle, registry)
        return bundle, result

    def test_exact_mirrors_keep_both_sources_in_one_unapproved_independent_draft(self):
        with tempfile.TemporaryDirectory() as folder:
            body = "متن کامل منبع با شرایط و استثناها و مدارک اصلی. " * 8
            bundle, (drafts, maps, placements, review) = self.fixture(
                Path(folder),
                [
                    ("https://radmohajer.ir/fa/one", body),
                    ("https://radmohajer.ir/fa/two", body),
                ],
            )
            self.assertEqual(len(drafts), 1)
            item = drafts[0]["item"]
            self.assertEqual(item["content_class"], "editorial")
            self.assertEqual(len(item["source_ids"]), 2)
            self.assertEqual(len(item["sections"][0]["blocks"][0]["provenance"]), 2)
            self.assertFalse(item["publication_allowed"])
            self.assertIsNone(item["reviewer_id"])
            self.assertEqual(len(maps[0]["map"]["sources"]), 2)
            self.assertEqual(len(placements), 2)
            self.assertTrue(review)
            verify_payload(drafts[0], {})
            for source in drafts[0]["sources"]:
                self.assertIsNone(
                    source["source_evidence"]["original_http_capture_time"]
                )
                self.assertIsNone(source["source_evidence"]["original_http_status"])
                self.assertIn(
                    "not_original_HTTP",
                    source["source_evidence"]["retrieved_at_semantics"],
                )
            self.assertEqual(
                duplicates(list(bundle.captures.values()))[0]["kind"],
                "exact_body_alias",
            )

    def test_same_url_changed_body_is_held_without_overwriting_or_picking_a_version(
        self,
    ):
        with tempfile.TemporaryDirectory() as folder:
            bundle, (drafts, _maps, placements, review) = self.fixture(
                Path(folder),
                [
                    ("https://radmohajer.ir/fa/one", "شرایط قدیمی منبع. " * 20),
                    ("https://radmohajer.ir/fa/one", "شرایط جدید و متفاوت منبع. " * 20),
                ],
            )
            self.assertEqual(drafts, [])
            self.assertEqual(len(review), 2)
            self.assertTrue(
                all(
                    p["disposition"] == "full_source_version_review_candidate"
                    for p in placements
                )
            )
            self.assertEqual(len(bundle.captures), 2)
            self.assertTrue(
                any(
                    r["kind"] == "same_url_different_content"
                    for r in duplicates(list(bundle.captures.values()))
                )
            )

    def test_distinct_articles_in_same_country_are_not_collapsed(self):
        with tempfile.TemporaryDirectory() as folder:
            _bundle, (drafts, _maps, _placements, _review) = self.fixture(
                Path(folder),
                [
                    (
                        "https://radmohajer.ir/fa/one",
                        "هزینه و شرایط دانشگاه اول. " * 20,
                    ),
                    (
                        "https://radmohajer.ir/fa/two",
                        "مدارک و استثناهای مسیر دوم. " * 20,
                    ),
                ],
            )
            self.assertEqual(len(drafts), 2)
            changed = drafts[0]
            changed["item"]["publication_allowed"] = True
            with self.assertRaisesRegex(
                ValueError, "publication_or_approval_forbidden"
            ):
                verify_payload(changed, {})

    def test_company_pages_keep_raw_evidence_without_importing_new_articles(self):
        with tempfile.TemporaryDirectory() as folder:
            bundle, (drafts, _maps, placements, _review) = self.fixture(
                Path(folder),
                [
                    (
                        "https://radmohajer.ir/en/about-us",
                        "Company profile and contact details. " * 20,
                    )
                ],
            )
            self.assertEqual(drafts, [])
            self.assertEqual(len(bundle.captures), 1)
            self.assertIn("legitimately_excluded_company", placements[0]["disposition"])

    def test_payload_rejects_changed_rich_structure_and_source_text(self):
        with tempfile.TemporaryDirectory() as folder:
            _bundle, (drafts, _maps, _placements, _review) = self.fixture(
                Path(folder),
                [("https://radmohajer.ir/fa/one", "شرایط و مدارک اصلی منبع. " * 20)],
            )
            draft = drafts[0]
            draft["item"]["sections"][0]["blocks"][0]["original_structure"]["text"] = (
                "changed"
            )
            with self.assertRaisesRegex(ValueError, "rich_content_text_loss"):
                verify_payload(draft, {})
            draft["sources"][0]["body_text"] = "changed"
            with self.assertRaisesRegex(ValueError, "payload_source_hash_mismatch"):
                verify_payload(draft, {})

    def test_reconciliation_import_has_no_file_or_stdout_side_effects(self):
        import contextlib
        import importlib
        import io

        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            module = importlib.import_module(
                "tools.content_completion.reconcile_all_sources"
            )
            importlib.reload(module)
        self.assertEqual(stream.getvalue(), "")
        self.assertEqual(
            module.get_country_from_url_or_title(
                "https://radmohajer.ir/fa/ukraine", "مهندسی و فرم", ""
            ),
            "UA",
        )


if __name__ == "__main__":
    unittest.main()
