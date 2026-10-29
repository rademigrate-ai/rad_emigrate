"""Adversarial owner-rule regressions using synthetic, nonlegal assertions."""

import copy
import unittest

from scripts.tests.test_content_consolidation import source
from tools.content_consolidation.build import title_key, topic_key
from tools.content_consolidation.composition import compose, compose_library
from tools.content_consolidation.precedence_v4 import (
    VERSION,
    classify_passage,
    equivalence,
    preferred_publisher,
)
from tools.plan3_content.parser import digest


def paragraph(value, **extra):
    return {"type": "paragraph", "text": value, **extra}


class PassagePolicyTests(unittest.TestCase):
    def test_medical_education_and_employment_are_general(self):
        for value in (
            "Medical university admission requires an exam.",
            "Nursing education and scholarship opportunities.",
            "Employment of doctors and nurses.",
            "Doctor salaries and professional licensing for immigration.",
            "Dentist immigration routes and work visa requirements.",
            "پذیرش دانشگاه پزشکی و حقوق پرستاران و مهاجرت پزشکان",
        ):
            with self.subTest(value=value):
                self.assertEqual(preferred_publisher(value), "digivisa.ir")

    def test_genuine_clinical_passages_prefer_radvisa(self):
        for value in (
            "Diagnostic criteria include persistent fever.",
            "Clinical nursing includes assessment of pain.",
            "The mechanism of action affects drug metabolism.",
            "روش جراحی و پروتکل درمان بیماری توضیح داده شده است",
            "عوارض جانبی و منع مصرف دارو",
        ):
            with self.subTest(value=value):
                self.assertEqual(preferred_publisher(value), "radvisa.com")

    def test_mixed_assertions_are_preserved_without_blanket_priority(self):
        value = (
            "University admission and clinical treatment require different evidence."
        )
        self.assertEqual(classify_passage(value), "mixed_uncertain")
        self.assertIsNone(preferred_publisher(value))

    def test_ordered_requirement_paraphrase_is_semantic_not_exact(self):
        left = paragraph("Applicants must submit a valid passport.")
        right = paragraph("A valid passport is required from applicants.")
        evidence = equivalence(left, right)
        self.assertEqual(evidence["kind"], "semantic")
        self.assertEqual(evidence["policy_version"], VERSION)
        self.assertNotEqual(digest(left), digest(right))

    def test_persian_requirement_paraphrase(self):
        left = paragraph("متقاضیان باید گذرنامه معتبر ارائه دهند.")
        right = paragraph("ارائه گذرنامه معتبر برای متقاضیان الزامی است.")
        self.assertEqual(equivalence(left, right)["kind"], "semantic")

    def test_subject_object_reversal_is_not_bag_of_words_match(self):
        self.assertIsNone(
            equivalence(
                paragraph("Doctors must provide patients with care."),
                paragraph("Patients must provide doctors with care."),
            )
        )

    def test_scope_conditions_dates_thresholds_and_additional_facts_survive(self):
        pairs = (
            ("Applicants must submit 100 euros.", "Applicants must submit 200 euros."),
            (
                "Applicants must submit a passport in Germany.",
                "Applicants must submit a passport in Canada.",
            ),
            (
                "Applicants must submit a passport in 2024.",
                "Applicants must submit a passport in 2026.",
            ),
            (
                "Applicants must submit a passport.",
                "Applicants must not submit a passport.",
            ),
            (
                "Applicants must submit a passport.",
                "Applicants must submit a passport unless exempt.",
            ),
            (
                "Applicants must submit a passport.",
                "Applicants must submit a passport and a certificate.",
            ),
            ("Applicants may submit a passport.", "Applicants must submit a passport."),
            ("Adverse effects include a rash.", "Side effects include a rash."),
        )
        for left, right in pairs:
            with self.subTest(left=left, right=right):
                self.assertIsNone(equivalence(paragraph(left), paragraph(right)))

    def test_tables_lists_and_links_require_exact_structure(self):
        self.assertIsNone(
            equivalence(
                {"type": "table", "text": "A B", "rows": [["A", "B"]]},
                {"type": "table", "text": "A B", "rows": [["A"], ["B"]]},
            )
        )
        self.assertIsNone(
            equivalence(
                {"type": "list", "text": "A B", "ordered": True},
                {"type": "list", "text": "A B", "ordered": False},
            )
        )
        self.assertIsNone(
            equivalence(
                paragraph(
                    "Applicants must provide a valid passport.",
                    links=["https://example.com/a"],
                ),
                paragraph(
                    "A valid passport is required from applicants.",
                    links=["https://example.com/b"],
                ),
            )
        )


class CompositionPolicyTests(unittest.TestCase):
    def test_audience_qualification_survives_identical_leading_work_condition(self):
        condition = paragraph("Workers may be employed for 20 hours per week.")
        members = [
            source(
                "iran",
                "Work in Canada for Iranian applicants",
                "digivisa.ir",
                blocks=[condition],
            ),
            source(
                "others",
                "Work in Canada for other applicants",
                "radvisa.com",
                blocks=[condition],
            ),
        ]
        article = compose(
            members, "work-country", "Work Visa Canada", ["CA"], route="work"
        )
        blocks = [b for sec in article["sections"] for b in sec["blocks"]]
        self.assertEqual(len(blocks), 2)
        self.assertEqual(article["omissions"], [])
        self.assertEqual(
            {sec["heading"] for sec in article["sections"]},
            {m["title"] for m in members},
        )
        self.assertEqual(
            {b["selected_origin"]["source_title"] for b in blocks},
            {m["title"] for m in members},
        )

    def test_city_qualification_is_not_erased_by_country_work_category(self):
        condition = paragraph("A separate appointment is required.")
        members = [
            source(
                "city", "Work in Canada in Toronto", "digivisa.ir", blocks=[condition]
            ),
            source("country", "Work in Canada", "radvisa.com", blocks=[condition]),
        ]
        article = compose(
            members, "work-country", "Work Visa Canada", ["CA"], route="work"
        )
        self.assertEqual(len(article["segment_ledger"]), 2)
        self.assertEqual(article["omissions"], [])

    def test_generic_same_country_route_titles_still_share_proven_context(self):
        condition = paragraph("A valid passport is required.")
        members = [
            source("study", "Study in Canada", "digivisa.ir", blocks=[condition]),
            source("admission", "Admission Canada", "radvisa.com", blocks=[condition]),
        ]
        article = compose(
            members, "study-country", "Study Visa Canada", ["CA"], route="study"
        )
        self.assertEqual(len(article["omissions"]), 1)

    def test_nonvisa_primary_topics_merge_with_explicit_old_identity_mapping(self):
        members = [
            source(
                "d",
                "فرهنگ کانادا",
                "digivisa.ir",
                blocks=[paragraph("A unique general fact.")],
            ),
            source(
                "r",
                "فرهنگ کانادا",
                "radvisa.com",
                blocks=[paragraph("A unique second fact.")],
            ),
        ]
        articles, _, _, _ = compose_library(members, title_key, topic_key)
        self.assertEqual(len(articles), 1)
        self.assertEqual(len(articles[0]["source_prior_article_ids"]), 2)
        self.assertIn(
            articles[0]["article_id"], articles[0]["source_prior_article_ids"]
        )
        self.assertEqual(len(articles[0]["segment_ledger"]), 2)

    def test_distinct_radmohajer_bodies_remain_independently_identifiable(self):
        members = [
            source(
                "m1",
                "فرهنگ کانادا",
                "radmohajer.ir",
                blocks=[paragraph("An independent first fact.")],
            ),
            source(
                "m2",
                "فرهنگ کانادا",
                "radmohajer.ir",
                blocks=[paragraph("An independent second fact.")],
            ),
        ]
        articles, _, _, _ = compose_library(members, title_key, topic_key)
        self.assertEqual(len(articles), 2)
        self.assertEqual(len({a["article_id"] for a in articles}), 2)

    def test_radmohajer_snapshot_variants_share_reader_without_block_id_collision(self):
        first = source(
            "m",
            "فرهنگ کانادا",
            "radmohajer.ir",
            blocks=[paragraph("An independent first fact.")],
        )
        second = copy.deepcopy(first)
        second["snapshot_id"] = "another-snapshot"
        second["blocks"] = [paragraph("An independent revised fact.")]
        second["body_text"] = second["blocks"][0]["text"]
        articles, _, _, _ = compose_library([first, second], title_key, topic_key)
        self.assertEqual(len(articles), 1)
        article = articles[0]
        self.assertEqual(len(article["source_prior_article_ids"]), 2)
        blocks = [b for section in article["sections"] for b in section["blocks"]]
        self.assertEqual(len({b["id"] for b in blocks}), 2)
        self.assertEqual(len(article["source_snapshot_ids"]), 2)

    def compose_pair(self, digi, rad, title="Medical education Germany", **kwargs):
        return compose(
            [
                source("digi", title, "digivisa.ir", ["DE"], digi),
                source("rad", title, "radvisa.com", ["DE"], rad),
            ],
            "synthetic-article",
            title,
            ["DE"],
            **kwargs,
        )

    def test_one_medical_article_selects_different_publishers_per_passage(self):
        digi = [
            paragraph("Applicants must submit a valid passport."),
            paragraph("The criteria for diagnosis include persistent fever."),
        ]
        rad = [
            paragraph("A valid passport is required from applicants."),
            paragraph("The diagnostic criteria include persistent fever."),
        ]
        article = self.compose_pair(digi, rad)
        blocks = [b for s in article["sections"] for b in s["blocks"]]
        self.assertEqual(len(blocks), 2)
        self.assertEqual(
            [b["selected_origin"]["publisher"] for b in blocks],
            ["digivisa.ir", "radvisa.com"],
        )
        self.assertEqual(blocks[1]["text"], rad[1]["text"])
        self.assertEqual(len(article["segment_ledger"]), 4)
        self.assertEqual(len(article["omissions"]), 2)
        clinical_omission = next(
            o
            for o in article["omissions"]
            if o["selected_origin"]["publisher"] == "radvisa.com"
        )
        self.assertEqual(clinical_omission["provenance"]["publisher"], "digivisa.ir")
        self.assertEqual(
            clinical_omission["selected_origin"]["publisher"], "radvisa.com"
        )
        self.assertFalse(article["published"])
        self.assertTrue(
            all(c["verification_status"] == "not_verified" for c in article["claims"])
        )

    def test_unique_secondary_information_retains_source_and_hash(self):
        article = self.compose_pair(
            [paragraph("A distinct general fact.")],
            [paragraph("A unique supplemental eligibility condition.")],
        )
        blocks = [b for s in article["sections"] for b in s["blocks"]]
        self.assertEqual(len(blocks), 2)
        self.assertEqual(blocks[1]["source_role"], "supplemental")
        self.assertEqual(
            blocks[1]["selected_origin"]["sha256"], digest(blocks[1]["text"])
        )
        self.assertEqual(article["omissions"], [])

    def test_different_heading_scope_does_not_deduplicate_same_text(self):
        article = self.compose_pair(
            [
                {"type": "heading", "text": "Conditions in 2024", "level": 2},
                paragraph("A passport is required."),
            ],
            [
                {"type": "heading", "text": "Conditions in 2026", "level": 2},
                paragraph("A passport is required."),
            ],
        )
        self.assertEqual(len(article["segment_ledger"]), 4)
        self.assertEqual(article["omissions"], [])

    def test_different_source_country_scope_is_never_collapsed(self):
        p = paragraph("A valid passport is required from applicants.")
        article = compose(
            [
                source("d", "Guide", "digivisa.ir", ["DE"], [p]),
                source("r", "Guide", "radvisa.com", ["CA"], [p]),
            ],
            "synthetic",
            "Guide",
            ["DE", "CA"],
        )
        self.assertEqual(article["omissions"], [])

    def test_equivalence_does_not_remove_unknown_similar_passage(self):
        article = self.compose_pair(
            [paragraph("University entry requires documented qualifications.")],
            [
                paragraph(
                    "Qualifications must be documented for admission to university."
                )
            ],
        )
        self.assertEqual(article["omissions"], [])
        self.assertEqual(len(article["segment_ledger"]), 2)

    def test_member_permutation_is_deterministic(self):
        p = paragraph("Applicants must provide a valid passport.")
        members = [
            source("d", "Guide", "digivisa.ir", blocks=[p]),
            source("r", "Guide", "radvisa.com", blocks=[p]),
        ]
        self.assertEqual(
            compose(members, "id", "Guide", ["CA"]),
            compose(list(reversed(members)), "id", "Guide", ["CA"]),
        )

    def test_radmohajer_cannot_merge_with_primary(self):
        with self.assertRaisesRegex(ValueError, "supplementary"):
            compose(
                [{"domain": "radmohajer.ir"}, {"domain": "digivisa.ir"}],
                "id",
                "Guide",
                [],
            )


if __name__ == "__main__":
    unittest.main()
