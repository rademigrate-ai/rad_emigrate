"""Synthetic preservation/identity regressions, not immigration facts."""

import json
import unittest
from pathlib import Path

from tools.content_consolidation.build import consolidate, title_key, topic_key
from tools.content_consolidation.composition import compose_library
from tools.content_consolidation.import_payload import payload
from tools.content_consolidation.importer import batch_sql, prepare
from tools.content_consolidation.mapping import source_mapping
from tools.content_consolidation.parser import extract_primary


def source(identity, title, domain="radvisa.com", countries=None, blocks=None):
    from tools.plan3_content.dataset import uid

    blocks = blocks or [{"type": "paragraph", "text": "Unique synthetic detail."}]
    return {
        "source_id": uid(identity),
        "snapshot_id": uid("snap:" + identity),
        "title": title,
        "domain": domain,
        "url": f"https://{domain}/article/{identity}",
        "language": "fa",
        "body_text": "\n\n".join(b["text"] for b in blocks),
        "blocks": blocks,
        "consolidation_disposition": "body_ready_for_unreviewed_composition",
        "taxonomy": {
            "country_codes": countries or ["CA"],
            "country_evidence": "source_title",
            "pathway": "study",
        },
    }


class CountryCategoryCompositionTests(unittest.TestCase):
    def test_import_projection_retains_exact_anchor_to_rich_block_mapping(self):
        from tools.plan3_content.parser import digest

        row = source("projection", "تحصیل کانادا")
        row.update(
            retrieved_at="2026-10-24T00:00:00Z",
            body_sha256=digest(row["body_text"]),
            raw_html_sha256=digest("fixture"),
        )
        article = self.compose([row])[0][0]
        registry = json.loads(
            Path("supabase/contracts/rad_v1.json").read_text(encoding="utf8")
        )
        result = payload(article, {row["source_id"]: row}, registry)
        self.assertEqual(result["status"], "technical_draft_only")
        projection = result["item"]["projection_map"][0]
        self.assertEqual(
            projection["first_rich_block_id"], article["sections"][0]["blocks"][0]["id"]
        )
        self.assertEqual(
            projection["section_id"],
            result["item"]["draft_request"]["sections"][0]["id"],
        )

    def test_transport_sql_escapes_source_text_and_selects_unoccupied_delimiter(self):
        result = batch_sql(
            [
                {
                    "item": {"text": "$rad_import_0$'; SELECT 'source text only'; --"},
                    "sources": [],
                }
            ],
            "00000000-0000-4000-8000-000000000001",
            "a" * 64,
            "00000000-0000-4000-8000-000000000002",
        )
        self.assertIn("do $rad_import_1$begin", result)
        self.assertIn("$rad_import_0$''; SELECT ''source text only''; --", result)
        self.assertIn("standard_conforming_strings=on", result)

    def test_import_preparation_refuses_production_before_reading_any_files(self):
        with self.assertRaisesRegex(ValueError, "staging_project_only"):
            prepare(
                Path("absent"), Path("absent-output"), "inshddthftkhcdosoqcn", "invalid"
            )

    def compose(self, rows):
        return compose_library(rows, title_key, topic_key)

    def test_distinct_titles_and_professions_share_category_without_losing_scope(self):
        rows = [
            source("a", "تحصیل کانادا"),
            source("b", "تحصیل پرستاری کانادا", "digivisa.ir"),
        ]
        articles, mappings, _, _ = self.compose(rows)
        self.assertEqual(len(articles), 1)
        self.assertEqual(articles[0]["visa_category"], "study")
        self.assertEqual(
            {s["program"] for s in articles[0]["sections"]}, {"general", "nursing"}
        )
        self.assertEqual(len(articles[0]["segment_ledger"]), 2)
        self.assertFalse(articles[0]["publication_allowed"])

    def test_true_duplicate_represented_but_nuance_and_promises_preserved(self):
        p = {"type": "paragraph", "text": "A unique condition."}
        rows = [
            source(
                "a",
                "تحصیل کانادا",
                blocks=[p, {"type": "paragraph", "text": "تضمین ویزا 100%"}],
            ),
            source(
                "b",
                "پذیرش کانادا",
                "digivisa.ir",
                blocks=[
                    p,
                    {
                        "type": "paragraph",
                        "text": "A unique condition, except for nurses.",
                    },
                ],
            ),
        ]
        articles, _, _, _ = self.compose(rows)
        a = articles[0]
        self.assertEqual(len(a["omissions"]), 1)
        self.assertEqual(len(a["segment_ledger"]), 4)
        self.assertIn(
            "تضمین ویزا 100%", [b["text"] for s in a["sections"] for b in s["blocks"]]
        )
        self.assertTrue(
            any(c["review_reason"].startswith("unsupported") for c in a["claims"])
        )

    def test_supplementary_and_nonvisa_are_one_independent_record_per_scope(self):
        rows = [
            source("a", "تحصیل کانادا"),
            source("b", "زندگی کانادا", "radmohajer.ir"),
            source("c", "فرهنگ کانادا", countries=["CA", "DE"]),
        ]
        articles, _, relations, countries = self.compose(rows)
        self.assertEqual(len(articles), 3)
        self.assertEqual(len(relations), 2)
        self.assertEqual(len(countries), 3)
        self.assertEqual(len({(r["parent_id"], r["related_id"]) for r in relations}), 2)
        self.assertFalse(
            any(
                "radmohajer.ir" in a["source_publishers"]
                for a in articles
                if a["content_class"] == "canonical"
            )
        )

    def test_different_country_or_category_never_collapses(self):
        rows = [
            source("a", "تحصیل کانادا"),
            source("b", "کار کانادا"),
            source("c", "تحصیل آلمان", countries=["DE"]),
        ]
        articles, _, _, _ = self.compose(rows)
        self.assertEqual(len(articles), 3)
        self.assertEqual(
            len({(tuple(a["country_codes"]), a["visa_category"]) for a in articles}), 3
        )

    def test_heading_table_structure_and_trailing_heading_are_preserved(self):
        blocks = [
            {"type": "heading", "text": "Conditions", "level": 2},
            {
                "type": "table",
                "text": "A B",
                "rows": [
                    [
                        {"text": "A", "header": True, "colspan": "2", "rowspan": "1"},
                        {"text": "B", "header": False, "colspan": "1", "rowspan": "1"},
                    ]
                ],
                "caption": None,
            },
            {"type": "heading", "text": "Unresolved heading", "level": 3},
        ]
        a = self.compose([source("a", "تحصیل کانادا", blocks=blocks)])[0][0]
        self.assertEqual(len(a["segment_ledger"]), 3)
        table = next(
            b for s in a["sections"] for b in s["blocks"] if b["type"] == "table"
        )
        self.assertEqual(table["original_structure"], blocks[1])

    def test_ambiguous_country_or_route_requires_review_not_wrong_assignment(self):
        row = source("a", "تحصیل و کار کانادا", countries=["CA", "DE"])
        self.assertTrue(source_mapping(row)["independent"])
        articles, _, _, _ = self.compose([row])
        self.assertEqual(articles[0]["content_class"], "editorial")


class PrimaryExtractionTests(unittest.TestCase):
    def test_nested_owned_box_is_substantive_not_an_unrelated_sidebar(self):
        html = b'<div class="BoxSizeAsli"><div class="Box"><h1>Owned</h1><div class="BoxCenter"><p>Intro</p><div class="Box"><div class="BoxCenter"><p>Unique nested condition</p></div></div></div></div></div>'
        result = extract_primary(html, "https://radvisa.com/article/synthetic")
        self.assertIn("Unique nested condition", result["body_text"])
        self.assertEqual(result["omitted_regions"], [])

    def test_larger_recommendation_box_cannot_replace_article(self):
        html = (
            '<div class="BoxSizeAsli"><div class="Box"><div class="BoxTop">'
            '<h1>Synthetic primary</h1></div><div class="BoxCenter">'
            '<div class="Row"><a class="Back">Index</a><span class="DateRegister">date</span></div>'
            "<p>Unique source body.</p><h2>Owned heading</h2><p>Owned detail.</p>"
            '</div></div><div class="Box"><div class="BoxCenter"><p>'
            + "Unrelated recommendation. " * 100
            + "</p></div></div></div>"
        )
        r = extract_primary(html.encode(), "https://radvisa.com/article/synthetic")
        self.assertEqual(
            r["body_text"], "Unique source body.\n\nOwned heading\n\nOwned detail."
        )
        self.assertEqual(len(r["omitted_regions"]), 2)
        self.assertEqual(r["body_status"], "complete_source_container")

    def test_unbound_legacy_box_fails_closed(self):
        r = extract_primary(
            b'<h1>Outside</h1><div class="BoxSizeAsli"><div class="Box"><div class="BoxCenter"><p>Other</p></div></div></div>',
            "https://digivisa.ir/article/x",
        )
        self.assertEqual(r["body_text"], "")
        self.assertEqual(r["body_status"], "unbound_article_region")

    def test_semantic_article_body_remains_independent(self):
        r = extract_primary(
            b'<h1>Source</h1><article itemprop="articleBody"><p>Standalone text.</p></article>',
            "https://radmohajer.ir/fa/test",
        )
        self.assertEqual(r["body_text"], "Standalone text.")


class TopicIdentityTests(unittest.TestCase):
    def test_direction_audience_conditions_and_year_are_not_erased(self):
        for left, right in [
            ("مهاجرت از کانادا", "مهاجرت به کانادا"),
            ("تحصیل پزشکی کانادا", "تحصیل پرستاری کانادا"),
            ("تحصیل 2024 کانادا", "تحصیل 2026 کانادا"),
            ("تحصیل کانادا", "شرایط تحصیل کانادا"),
        ]:
            self.assertNotEqual(title_key(left), title_key(right))

    def test_supplementary_body_cannot_be_merged_into_primary(self):
        with self.assertRaisesRegex(ValueError, "supplementary"):
            consolidate([{"domain": "radvisa.com"}, {"domain": "radmohajer.ir"}])


if __name__ == "__main__":
    unittest.main()
