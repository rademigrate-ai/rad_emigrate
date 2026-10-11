#!/usr/bin/env python3
"""Phase: pre-production readiness — regression tests for the validated
ingestion package, review queues, and the dataset contract fixes.

Run:  python -m unittest discover -s tools/stage3_content_migration -p "test_*.py"
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys
import unicodedata
import unittest
import urllib.parse

TOOLS = pathlib.Path(__file__).resolve().parent
REPO = TOOLS.parent.parent
sys.path.insert(0, str(TOOLS))

from build_canonical_dataset import content_type_for, normalize_language  # noqa: E402
from simulate_ingestion import url_key  # noqa: E402

CANON = REPO / "artifacts" / "stage3_canonical_dataset_20261011"
PKG = REPO / "artifacts" / "stage3_ingestion_package_20261012"
QUEUES = REPO / "artifacts" / "stage3_review_queues_20261012"


def _jsonl(p: pathlib.Path):
    return [json.loads(l) for l in p.read_text(encoding="utf-8").splitlines()
            if l.strip()]


class TestContentTypeFix(unittest.TestCase):
    def test_title_ending_with_slash_not_home(self):
        # regression: '...آمریکا/' title made url+probe end with '/'
        self.assertNotEqual(
            content_type_for(
                "https://radmohajer.ir/fa/articles/123-x",
                "پناهندگی/اخذ اقامت از طریق پناهندگی اروپا و آمریکا/"),
            "home")

    def test_bare_domains_are_home(self):
        for u in ("https://digivisa.ir", "https://digivisa.ir/",
                  "https://radmohajer.ir/fa", "https://radvisa.com/",
                  "https://radmohajer.ir/en/", "https://digivisa.ir/Index.aspx"):
            self.assertEqual(content_type_for(u, ""), "home", u)

    def test_article_not_home(self):
        self.assertEqual(
            content_type_for("https://digivisa.ir/article/10-دلیل", ""),
            "article")
        self.assertEqual(
            content_type_for("https://radvisa.com/content/some-page", ""),
            "other")


class TestLanguageContract(unittest.TestCase):
    def test_not_null_contract_values(self):
        for raw, url, site, body in [
            ("fa-IR", "u", "d", ""),
            ("en-gb", "u", "d", ""),
            (None, "https://radvisa.com/x", "radvisa.com",
             "متن فارسی درباره مهاجرت و تحصیل در خارج از کشور"),   # -> fa
            (None, "https://radvisa.com/en/x", "radvisa.com",
             "Study permit requirements for international students"),  # -> en
            ("xx", "https://digivisa.ir/u", "digivisa.ir", ""),      # site fa
        ]:
            v = normalize_language(raw, url, site, body)
            self.assertIn(v, ("fa", "en"), (raw, url))

    def test_script_detection_thresholds(self):
        self.assertEqual(normalize_language(None, "https://radvisa.com/x",
                                            "radvisa.com", "سلام دنیا"), "fa")
        self.assertEqual(normalize_language(None, "https://radvisa.com/x",
                                            "radvisa.com",
                                            "This is an English page about "
                                            "visa applications"), "en")
        # ambiguous tiny text stays None (counted as violation upstream)
        self.assertIsNone(normalize_language(None, "https://radvisa.com/x",
                                             "radvisa.com", "123"))


class TestUrlKeyEquivalence(unittest.TestCase):
    def test_trailing_slash_equivalent(self):
        self.assertEqual(url_key("https://digivisa.ir"),
                         url_key("https://digivisa.ir/"))
        self.assertEqual(url_key("https://radmohajer.ir/fa"),
                         url_key("https://radmohajer.ir/fa/"))

    def test_path_case_preserved(self):
        self.assertNotEqual(url_key("https://digivisa.ir/article/A"),
                            url_key("https://digivisa.ir/article/a"))

    def test_host_case_insensitive(self):
        self.assertEqual(url_key("https://RadVisa.com/page"),
                         url_key("https://radvisa.com/page"))

    # --- F-03 additions ---

    def test_surrounding_whitespace_ignored(self):
        self.assertEqual(url_key("  https://digivisa.ir/fa/  "),
                         url_key("https://digivisa.ir/fa"))
        self.assertEqual(url_key("https://digivisa.ir/fa/ news "),
                         url_key("https://digivisa.ir/fa/news"))

    def test_percent_encoded_persian_unifies_with_raw(self):
        raw = "https://radmohajer.ir/fa/مقالات/181-انگلستان"
        enc = "https://radmohajer.ir/fa/" + \
            urllib.parse.quote("مقالات/181-انگلستان", safe="/")
        self.assertEqual(url_key(raw), url_key(enc))

    def test_unicode_nfc_vs_nfd_unify(self):
        # Arabic yeh with hamza: precomposed (U+0626) vs base yeh +
        # combining hamza above (U+064A U+0654).  Explicit escapes so the
        # literal cannot be silently re-normalized by an editor.
        nfc = unicodedata.normalize("NFC", "\u0626")
        nfd = unicodedata.normalize("NFD", "\u0626")
        self.assertEqual(nfc, "\u0626")
        self.assertEqual(nfd, "\u064a\u0654")
        self.assertNotEqual(nfc, nfd)
        self.assertEqual(url_key("https://x.ir/" + nfc),
                         url_key("https://x.ir/" + nfd))

    def test_query_trim_and_case(self):
        self.assertEqual(url_key("https://x.ir/p?id= 5"),
                         url_key("https://x.ir/p?id=5"))
        # parameter names/values case-significant (RFC 3986), order kept
        self.assertNotEqual(url_key("https://x.ir/p?a=1&b=2"),
                            url_key("https://x.ir/p?a=2&b=1"))

    def test_fragments_dropped(self):
        self.assertEqual(url_key("https://x.ir/fa#section"),
                         url_key("https://x.ir/fa"))

    def test_zwnj_vs_space_not_unified(self):
        # distinct bytes on the sites -> distinct documents (no collapse)
        self.assertNotEqual(url_key("https://x.ir/دانشگاه‌های"),
                            url_key("https://x.ir/دانشگاه های"))

    def test_collision_safety_real_pairs(self):
        # real dataset URLs that must NOT collapse
        self.assertNotEqual(
            url_key("https://radmohajer.ir/fa/contacts"),
            url_key("https://radmohajer.ir/en/contact-us"))
        self.assertNotEqual(url_key("https://digivisa.ir/Index.aspx"),
                            url_key("https://digivisa.ir/index.aspx"))

    def test_simulator_and_generator_share_one_key(self):
        import generate_ingest_sql as gen
        import simulate_ingestion as sim
        for u in ("https://digivisa.ir", "https://digivisa.ir/fa/",
                  "https://radmohajer.ir/fa/مقالات/1-انگلستان",
                  " https://radvisa.com/x/ "):
            self.assertEqual(sim.url_key(u), gen.url_key(u), u)


@unittest.skipUnless(CANON.exists(), "canonical dataset missing")
class TestDatasetContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = _jsonl(CANON / "CANONICAL_CONTENT_DATASET.jsonl")

    def test_language_not_null_satisfied(self):
        for r in self.rows:
            self.assertIn(r["language"], ("fa", "en"))

    def test_title_not_null_satisfied(self):
        for r in self.rows:
            self.assertTrue(r["extracted_title"])
            if r["title_is_fallback"]:
                self.assertTrue(r["title_source"])

    def test_no_body_over_contract_limit(self):
        for r in self.rows:
            self.assertLessEqual(len(r["body"]), 99_999)

    def test_deterministic_ids_stable(self):
        r = self.rows[0]
        expected = "rad-" + hashlib.sha256(
            ("canonical:v1|" + r["canonical_url"]).encode()).hexdigest()[:24]
        self.assertEqual(r["id"], expected)


@unittest.skipUnless((PKG / "sql").exists(), "ingest package missing")
class TestIngestSqlPackage(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(
            (PKG / "INGEST_MANIFEST.json").read_text(encoding="utf-8"))

    def test_manifest_hashes_match_files(self):
        for f in self.manifest["files"]:
            data = (PKG / "sql" / f["file"]).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), f["sha256"],
                             f["file"])

    def test_expected_counts_match_impact_report(self):
        impact = json.loads((PKG / "INGESTION_IMPACT_REPORT.json")
                            .read_text(encoding="utf-8"))
        exp = self.manifest["expected_counts"]
        self.assertEqual(impact["counts"]["DOC_INSERT"],
                         exp["documents_created"])
        self.assertEqual(impact["counts"]["SNAP_INSERT"],
                         exp["snapshots_inserted"])
        self.assertEqual(impact["counts"].get("BLOCKED", 0), 0)
        self.assertEqual(impact["totals"]["production_documents"],
                         exp["documents_existing_untouched"])

    def test_chunks_are_balanced_transactions(self):
        chunks = sorted((PKG / "sql").glob("10_ingest_*.sql"))
        expected = len([f for f in self.manifest["execution_order"]
                        if f.startswith("10_ingest_")])
        self.assertEqual(len(chunks), expected)
        self.assertGreater(expected, 0)
        for c in chunks:
            t = c.read_text(encoding="utf-8")
            self.assertEqual(len(re.findall(r"^\s*begin;", t, re.M)), 1, c.name)
            self.assertEqual(len(re.findall(r"^\s*commit;", t, re.M)), 1, c.name)
            self.assertIn("on conflict", t)

    def test_chunk_sizes_are_bounded(self):
        # F-04: no chunk may exceed ~1.5MB (keeps SQL-editor executions safe)
        for c in (PKG / "sql").glob("10_ingest_*.sql"):
            self.assertLess(c.stat().st_size, 1_500_000, c.name)

    def test_no_feed_or_research_writes_anywhere(self):
        for f in (PKG / "sql").glob("*.sql"):
            t = f.read_text(encoding="utf-8").lower()
            for banned in ("feed_items", "research_findings", "content_drafts",
                           "knowledge_items", "knowledge_claims",
                           "destinations", "visa_programs"):
                if banned == "feed_items":
                    # allowed only in read-only SELECT count lines
                    for line in t.splitlines():
                        if "feed_items" in line and "select" not in line:
                            self.fail(f"{f.name}: non-select feed reference")
                else:
                    self.assertNotIn(banned, t, f.name)

    def test_every_snapshot_insert_carries_batch_marker_and_review_status(self):
        chunks = sorted((PKG / "sql").glob("10_ingest_*.sql"))
        total_marker = 0
        for c in chunks:
            t = c.read_text(encoding="utf-8")
            total_marker += t.count('"ingest_batch": "stage3-bulk-20261012"')
            self.assertEqual(
                t.count('"regulatory_status": "REVIEW_REQUIRED"'),
                t.count('"ingest_batch"'), c.name)
        self.assertEqual(total_marker,
                         self.manifest["expected_counts"]["snapshots_inserted"])

    def test_url_equivalent_rows_resolve_to_production_form(self):
        # digivisa root must be written with production's trailing slash and
        # must NOT be inserted as a document (exists by equivalence)
        found_join = False
        for c in (PKG / "sql").glob("10_ingest_*.sql"):
            t = c.read_text(encoding="utf-8")
            if "'https://digivisa.ir/'," in t:
                found_join = True
                self.assertIn("dataset_canonical_url", t)
        self.assertTrue(found_join)
        for c in (PKG / "sql").glob("10_ingest_*.sql"):
            t = c.read_text(encoding="utf-8")
            self.assertNotIn(
                "('https://digivisa.ir', 'rad_official'", t,
                "must not insert slash-equivalent duplicate document")

    def test_rollback_scoped_to_batch_marker(self):
        t = (PKG / "sql" / "91_rollback.sql").read_text(encoding="utf-8")
        self.assertIn("metadata->>'ingest_batch' = 'stage3-bulk-20261012'", t)
        # documents the FK-RESTRICT safety property that refuses destructive
        # rollback while review work cites batch snapshots
        self.assertIn("on delete restrict", t.lower())
        # restores the 5 pre-existing documents' prior hashes
        for h in ("a99199f438e3d2e4134a8d1be35c78473e4f7f6e60edc51d9760ec5f38b00110",
                  "643a3c62ef94bc0f5303a69808c4c847d3f87ab73689bb56fc0f506f9c8f8ec9"):
            self.assertIn(h, t)

    def test_rollback_is_set_based_not_url_list(self):
        """F-01: rollback must derive candidates from batch markers, must
        exclude pre-existing docs explicitly, and must contain NO
        metadata-comparison guard vulnerable to NULL evaluation."""
        t = (PKG / "sql" / "91_rollback.sql").read_text(encoding="utf-8")
        # candidate set from markers, captured before deletion
        self.assertIn("create temp table _rb_batch_docs", t)
        self.assertLess(t.index("create temp table _rb_batch_docs"),
                        t.index("delete from public.source_snapshots"))
        # no fragile mass URL list: only the pre-ingest production URLs may
        # appear as literals (5 live docs; tolerate <= 10 total)
        self.assertLessEqual(t.count("'https://"), 10,
                             "rollback must not embed a batch URL list")
        # pre-existing exclusion guard present
        self.assertIn("canonical_url not in", t)
        # NULL trap removed: no `metadata->>'ingest_batch' <> ...` predicate
        # anywhere (a snapshot without the key must protect its document)
        self.assertNotIn("'ingest_batch' <>", t)
        self.assertNotIn("'ingest_batch' !=", t)
        # surviving-snapshot protection carries no metadata predicate
        m = re.search(r"and not exists \(\s*select 1 from public\.source_snapshots "
                      r"s where s\.document_id = d\.id\)", t)
        self.assertIsNotNone(m, "set-based snapshot-survival guard missing")


@unittest.skipUnless(QUEUES.exists(), "review queues missing")
class TestReviewQueues(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reg = _jsonl(QUEUES / "REGULATORY_REVIEW_QUEUE.jsonl")
        cls.visa = _jsonl(QUEUES / "VISA_DRAFT_REVIEW_QUEUE.jsonl")

    def test_all_129_discrepancies_in_p0(self):
        flagged = [r for r in self.reg if r["material_discrepancy_flag"]]
        self.assertEqual(len(flagged), 129)
        self.assertTrue(all(r["priority"].startswith("P0") for r in flagged))

    def test_everything_review_required_and_unapproved(self):
        for r in self.reg:
            self.assertEqual(r["regulatory_status"], "REVIEW_REQUIRED")
            self.assertFalse(r["auto_approved"])
            self.assertTrue(r["requires_human_approval"])
        for r in self.visa:
            self.assertEqual(r["regulatory_status"], "REVIEW_REQUIRED")
            self.assertFalse(r["auto_approved"])
            self.assertEqual(r["status_in_package"], "draft")

    def test_visa_queue_covers_all_165_drafts(self):
        self.assertEqual(len(self.visa), 165)
        self.assertEqual(len({r["program_slug"] for r in self.visa}), 165)

    def test_regulatory_queue_covers_full_ledger(self):
        self.assertEqual(len(self.reg), 19017)


@unittest.skipUnless((PKG / "RAW_EVIDENCE_VERIFICATION.json").exists(),
                     "raw verification missing")
class TestRawEvidenceVerification(unittest.TestCase):
    def test_full_verification_recorded_complete(self):
        r = json.loads((PKG / "RAW_EVIDENCE_VERIFICATION.json")
                       .read_text(encoding="utf-8"))
        self.assertTrue(r["complete"])
        self.assertEqual(r["files_checked"], 1627)
        self.assertEqual(r["missing"], [])
        self.assertEqual(r["hash_mismatch"], [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
