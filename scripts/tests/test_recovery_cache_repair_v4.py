"""Discovery corrections preserve literal raw evidence and short owned articles."""

import unittest

from tools.content_completion.full_recovery_v4 import (
    FULL,
    Links,
    known_nonarticle_route,
    parse_owned,
    source_language_evidence,
)
from tools.content_completion.recovery_cache_repair_v4 import anchor_evidence


class CacheRepairV4Test(unittest.TestCase):
    def test_subdirectory_HTML_base_keeps_its_trailing_slash_semantics(self):
        raw = b'<base href="https://radmohajer.ir/fa/"><a href="article">a</a>'
        self.assertEqual(
            Links(raw, "https://radmohajer.ir/fa/parent").links,
            {"https://radmohajer.ir/fa/article"},
        )
        self.assertEqual(
            next(iter(anchor_evidence(raw, "https://radmohajer.ir/fa/parent")))[
                "correct_target_url"
            ],
            "https://radmohajer.ir/fa/article",
        )

    def test_about_a_country_is_substantive_content_not_company_endpoint(self):
        self.assertIsNone(known_nonarticle_route("https://digivisa.ir/about-italy"))
        raw = '<h1>درباره ایتالیا</h1><div itemprop="articleBody"><p>ایتالیا کشوری در جنوب اروپا است.</p></div>'.encode()
        articles, _ = parse_owned(raw, "https://digivisa.ir/about-italy")
        self.assertEqual(articles[0]["completeness"], FULL)

    def test_explicit_company_and_stateful_endpoints_stay_nonarticles(self):
        for url in (
            "https://digivisa.ir/about-us",
            "https://radmohajer.ir/fa/contact-us",
            "https://radmohajer.ir/fa/article?view=form",
        ):
            self.assertEqual(known_nonarticle_route(url)[0], "NONCONTENT_ROUTE")

    def test_Persian_university_list_is_not_an_English_translation(self):
        source = {
            "url": "https://radmohajer.ir/fa/norway/462-list",
            "title": "لیست دانشگاه های نروژ",
            "language": "en",
            "blocks": [
                {
                    "type": "paragraph",
                    "text": "لیست دانشگاه های نروژ در ادامه آمده است.",
                },
                {"type": "table", "text": "University of Oslo University of Bergen"},
            ],
        }
        language, evidence = source_language_evidence(source)
        self.assertEqual(language, "fa")
        self.assertEqual(evidence["original_capture_language"], "en")
        self.assertFalse(evidence["translation_created"])

    def test_explicit_original_English_route_is_preserved(self):
        language, evidence = source_language_evidence(
            {
                "url": "https://radvisa.com/article/lang/2/study",
                "title": "Study",
                "language": "en",
                "blocks": [
                    {"type": "paragraph", "text": "Original English study requirements"}
                ],
            }
        )
        self.assertEqual(language, "en")
        self.assertTrue(evidence["explicit_en_route"])

    def test_HTML_base_prevents_recursive_article_prefix(self):
        raw = b'<base href="https://digivisa.ir/"><a href="article/example">Article</a>'
        links = Links(raw, "https://digivisa.ir/article/parent")
        self.assertIn("https://digivisa.ir/article/example", links.links)
        self.assertNotIn("https://digivisa.ir/article/article/example", links.links)
        evidence = next(
            iter(anchor_evidence(raw, "https://digivisa.ir/article/parent"))
        )
        self.assertEqual(
            evidence["incorrect_target_url"],
            "https://digivisa.ir/article/article/example",
        )
        self.assertEqual(
            evidence["correct_target_url"], "https://digivisa.ir/article/example"
        )
        self.assertEqual(evidence["original_href"], "article/example")
        self.assertEqual(evidence["raw_anchor_tag"], '<a href="article/example">')

    def test_archive_wrapper_is_an_original_URL_not_a_first_party_web_path(self):
        raw = (
            b'<a href="/web/20260301000000/http://radmohajer.ir/fa/article">Article</a>'
        )
        links = Links(raw, "https://radmohajer.ir/fa/parent")
        self.assertEqual(links.links, {"https://radmohajer.ir/fa/article"})
        evidence = next(iter(anchor_evidence(raw, "https://radmohajer.ir/fa/parent")))
        self.assertIn("/web/", evidence["incorrect_target_url"])
        self.assertEqual(
            evidence["correct_target_url"], "https://radmohajer.ir/fa/article"
        )

    def test_script_and_comment_strings_are_not_article_edges(self):
        raw = b'<!-- <a href="wrong"> --><script>var x="<a href=wrong>";</script><base href="/"><a href="correct">a</a>'
        rows = list(anchor_evidence(raw, "https://digivisa.ir/article/parent"))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["correct_target_url"], "https://digivisa.ir/correct")

    def test_short_original_article_is_not_excluded_by_a_character_threshold(self):
        raw = '<html lang="fa"><h1>شرط پذیرش</h1><div itemprop="articleBody"><p>برای پذیرش ارائه مدرک زبان الزامی است.</p></div></html>'.encode()
        articles, _ = parse_owned(raw, "https://digivisa.ir/short-article")
        self.assertEqual(articles[0]["completeness"], FULL)
        self.assertLess(len(articles[0]["body_text"]), 300)

    def test_explicit_placeholder_remains_unresolved(self):
        raw = '<h1>شرایط</h1><div itemprop="articleBody"><p>به زودی</p></div>'.encode()
        articles, _ = parse_owned(raw, "https://digivisa.ir/placeholder")
        self.assertNotEqual(articles[0]["completeness"], FULL)

    def test_short_error_response_is_not_an_article(self):
        raw = '<h1>خطا</h1><div itemprop="articleBody"><p>این صفحه حذف شده است و برای بازگشت می توانید از لینک صفحه اصلی استفاده کنید.</p></div>'.encode()
        articles, _ = parse_owned(raw, "https://digivisa.ir/404.htm")
        self.assertNotEqual(articles[0]["completeness"], FULL)

    def test_primary_owned_media_binds_to_document_base_and_excludes_sidebar(self):
        raw = '<html><head><base href="https://digivisa.ir/"></head><body><h1>مقاله</h1><div itemprop="articleBody"><p>متن مقاله کوتاه ولی کامل است.</p><img src="images/article.jpg" alt="تصویر مقاله"><video src="media/article.mp4"></video></div><aside><img src="images/sidebar.jpg"></aside></body></html>'.encode()
        articles, _ = parse_owned(raw, "https://digivisa.ir/article/parent")
        assets = articles[0]["assets"]
        self.assertEqual(
            {a["url"] for a in assets},
            {
                "https://digivisa.ir/images/article.jpg",
                "https://digivisa.ir/media/article.mp4",
            },
        )
        self.assertTrue(all(not a["public_render_allowed"] for a in assets))


if __name__ == "__main__":
    unittest.main()
