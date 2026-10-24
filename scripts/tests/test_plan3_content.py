"""Content pipeline/security regressions; synthetic fixtures are not immigration advice."""

import copy
import gzip
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.request import Request

from tools.plan3_content.crawl import Collector, SafeRedirect, disposition, stable_id
from tools.plan3_content.dataset import (
    canonicalize,
    cms_payload,
    digest_bytes,
    registry_sha256,
    source_records,
    uid,
    validate_package,
    write_jsonl,
)
from tools.plan3_content.importer import (
    load_import,
    sqlite_import,
    sqlite_rehearsal,
    validate_runtime,
)
from tools.plan3_content.parser import digest, extract, normalize_url, search_normalize
from tools.plan3_content.quality import assess_references, assess_source

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "supabase/contracts/rad_v1.json"
REG = json.loads(REGISTRY.read_text(encoding="utf8"))
BODY = (
    "SYNTHETIC LOCAL FIXTURE. This paragraph tests source preservation and contains no factual immigration advice. "
    * 5
)


def record(
    url="https://radvisa.com/content/synthetic-canada",
    title="Synthetic Canada",
    body=BODY,
    language="en",
):
    html = (
        '<html lang="'
        + language
        + '"><head><title>'
        + title
        + '</title></head><body><div class="BoxSizeAsli"><div class="Box"><h1>'
        + title
        + '</h1><div class="BoxCenter"><h2>Fixture section</h2><p>'
        + body
        + "</p></div></div></div></body></html>"
    ).encode("utf8")
    return source_records(
        [
            {
                "id": stable_id(url),
                "url": url,
                "fetch_status": "fetched",
                "status": 200,
                "retrieved_at": "2026-10-24T12:00:00Z",
                "raw_sha256": digest_bytes(html),
                "extraction": extract(html, url),
            }
        ],
        {"sources": []},
    )[0]


def article(source):
    g = canonicalize([source])[0][0]
    return cms_payload(g, source, REG, {"CA", "DE", "GB"})


def package(directory, sources=None):
    sources = sources or [record()]
    articles = [article(s) for s in sources]
    write_jsonl(directory / "sources.jsonl.gz", sources)
    write_jsonl(directory / "drafts.jsonl.gz", articles)
    p = {
        "publication_allowed": False,
        "production_import_enabled": False,
        "approved_by": None,
        "approved_at": None,
        "source_file": "sources.jsonl.gz",
        "source_file_sha256": digest_bytes(
            (directory / "sources.jsonl.gz").read_bytes()
        ),
        "payload_file": "drafts.jsonl.gz",
        "payload_file_sha256": digest_bytes(
            (directory / "drafts.jsonl.gz").read_bytes()
        ),
        "articles": [
            {"canonical_id": a["canonical_id"], "payload_sha256": a["payload_sha256"]}
            for a in articles
        ],
    }
    path = directory / "package.json"
    path.write_text(json.dumps(p), encoding="utf8")
    return path, articles


class UrlTests(unittest.TestCase):
    def test_encoded_unicode_and_tracking_share_identity(self):
        self.assertEqual(
            normalize_url("http://WWW.radvisa.com/کانادا/?utm_source=x#section"),
            normalize_url("https://radvisa.com/%DA%A9%D8%A7%D9%86%D8%A7%D8%AF%D8%A7"),
        )

    def test_encoded_reserved_characters_do_not_merge_sources(self):
        self.assertNotEqual(
            normalize_url("https://radvisa.com/a%2fb"),
            normalize_url("https://radvisa.com/a/b"),
        )
        self.assertNotEqual(
            normalize_url("https://radvisa.com/a%252Fb"),
            normalize_url("https://radvisa.com/a%2Fb"),
        )

    def test_meaningful_repeated_query_order_preserved(self):
        self.assertIn("id=b&id=a", normalize_url("https://radvisa.com/x?id=b&id=a"))
        self.assertNotEqual(
            normalize_url("https://radvisa.com/x?id=1"),
            normalize_url("https://radvisa.com/x?id=2"),
        )

    def test_credentials_controls_and_nonweb_schemes_rejected(self):
        for u in [
            "javascript:alert(1)",
            "file:///etc/passwd",
            "https://a:b@radvisa.com/",
            "https://radvisa.com/a%0db",
            "https://radvisa.com:8443/",
        ]:
            with self.subTest(url=u), self.assertRaises(ValueError):
                normalize_url(u)

    def test_stateful_paths_and_attachments_are_not_articles(self):
        for u in [
            "https://radvisa.com/logout",
            "https://digivisa.ir/admin/x",
            "https://radvisa.com/a.pdf",
            "https://radvisa.com/a?task=delete",
            "https://radmohajer.ir/fa/country/10-demo/196-legacy",
            "https://radmohajer.ir/fa/country?view=form",
        ]:
            self.assertIsNotNone(disposition(u))
        self.assertEqual(
            disposition("https://example.org/x"), "external_reference_not_crawled"
        )

    def test_robots_denial_is_fail_closed(self):
        from urllib.robotparser import RobotFileParser

        with tempfile.TemporaryDirectory() as d:
            c = Collector(Path(d))
            self.assertFalse(c.allowed("https://radvisa.com/a"))
            rp = RobotFileParser()
            rp.parse(["User-agent: *", "Disallow: /private"])
            c.robots["radvisa.com"] = rp
            self.assertFalse(c.allowed("https://radvisa.com/private/a"))
            self.assertTrue(c.allowed("https://radvisa.com/content/a"))


class ParserTests(unittest.TestCase):
    def test_base_href_prevents_repeated_route_crawler_traps(self):
        html = b'<base href="https://digivisa.ir/"><h1>Fixture</h1><a href="article/a">x</a>'
        x = extract(html, "https://digivisa.ir/article/current")
        self.assertEqual(x["links"][0]["url"], "https://digivisa.ir/article/a")

    def test_declared_base_trailing_slash_semantics_preserved(self):
        x = extract(
            b'<base href="https://radmohajer.ir/fa/menu/"><a href="child">x</a>',
            "https://radmohajer.ir/fa/menu",
        )
        self.assertEqual(x["links"][0]["url"], "https://radmohajer.ir/fa/menu/child")

    def test_no_container_does_not_become_complete_article(self):
        x = extract(
            b"<html><title>Metadata only</title><nav>navigation text</nav></html>",
            "https://radvisa.com/",
        )
        self.assertEqual(x["body_text"], "")
        self.assertEqual(x["body_status"], "no_recognized_article_container")

    def test_navigation_comments_scripts_are_not_article_body(self):
        x = extract(
            b'<nav>PRIVATE NAV</nav><div itemprop="articleBody"><h2>Fixture</h2><p>Actual synthetic text.</p><script>alert(1)</script><div class="comments">comment</div></div>',
            "https://radmohajer.ir/fa/a",
        )
        self.assertNotIn("NAV", x["body_text"])
        self.assertNotIn("alert", x["body_text"])
        self.assertNotIn("comment", x["body_text"])
        self.assertEqual(x["body_status"], "complete_source_container")

    def test_tables_and_nested_lists_preserve_original_structure(self):
        x = extract(
            b'<div itemprop="articleBody"><table><tr><th>A</th><th>B</th></tr><tr><td colspan="2">C</td></tr></table><ul><li>Parent<ul><li>Child</li></ul></li></ul></div>',
            "https://radmohajer.ir/fa/a",
        )
        table = next(b for b in x["blocks"] if b["type"] == "table")
        listing = next(b for b in x["blocks"] if b["type"] == "bullet_list")
        self.assertEqual(table["rows"][1][0]["colspan"], "2")
        self.assertEqual(
            listing["items"][0]["children"][0]["items"][0]["text"], "Child"
        )
        self.assertEqual(x["body_status"], "complete_source_container")

    def test_original_persian_retained_normalization_separate(self):
        original = "كي ی ۱۲٣"
        x = extract(
            ('<div itemprop="articleBody"><p>' + original + "</p></div>").encode(),
            "https://radmohajer.ir/fa/a",
        )
        self.assertEqual(x["body_text"], original)
        self.assertNotEqual(search_normalize(original), original)

    def test_source_dates_not_inferred_from_footer_or_copyright(self):
        x = extract(
            b'<footer>Copyright 2026</footer><div itemprop="articleBody"><p>Fixture.</p></div>',
            "https://radmohajer.ir/fa/a",
        )
        self.assertEqual(x["dates"], [])

    def test_evidenced_ambiguous_dates_retained_without_fake_utc(self):
        x = extract(
            '<meta property="article:published_time" content="۱۴۰۴/۰۱/۰۱"><div itemprop="articleBody"><p>آزمایش</p></div>'.encode(),
            "https://radmohajer.ir/fa/a",
        )
        self.assertEqual(x["dates"][0]["value"], "۱۴۰۴/۰۱/۰۱")


class LegacyMarkupTests(unittest.TestCase):
    def test_word_and_generator_comments_never_become_article_or_list_text(self):
        html = b'<div itemprop="articleBody"><p>Visible synthetic text.</p><!--[if mso]><xml>hidden settings</xml><![endif]--><ul><li>Visible list<!--hidden generator code--></li></ul></div>'
        result = extract(html, "https://radvisa.com/fixture")
        self.assertEqual(result["body_status"], "complete_source_container")
        self.assertNotIn("hidden", result["body_text"])
        self.assertEqual(result["blocks"][1]["items"][0]["text"], "Visible list")

    def test_malformed_list_retains_visible_text_without_inventing_items(self):
        html = b'<div itemprop="articleBody"><p>Synthetic introduction.</p><ul><p>Synthetic first line.</p><p>Synthetic second line.</p></ul></div>'
        result = extract(html, "https://digivisa.ir/fixture")
        self.assertEqual(result["body_status"], "complete_source_container")
        self.assertIn("Synthetic first line.", result["body_text"])
        self.assertIn("Synthetic second line.", result["body_text"])
        self.assertIn(
            "malformed_list_preserved_without_inventing_structure", result["warnings"]
        )


class CollectorTests(unittest.TestCase):
    def test_redirects_refuse_external_hosts_downgrades_and_robots_denial(self):
        req = Request("https://radvisa.com/fixture")
        for target, allowed in [
            ("https://127.0.0.1/internal", True),
            ("https://outside.example.invalid/", True),
            ("http://radvisa.com/fixture", True),
            ("https://radvisa.com/private", False),
        ]:
            redirect = SafeRedirect(
                {"radvisa.com"}, lambda url, permitted=allowed: permitted, []
            )
            with self.subTest(target=target), self.assertRaises(ValueError):
                redirect.redirect_request(req, None, 302, "Found", {}, target)

    def test_redirect_preserves_required_trailing_slash_on_wire(self):
        redirect = SafeRedirect({"radvisa.com"}, lambda url: True, [])
        req = redirect.redirect_request(
            Request("https://radvisa.com/fixture"),
            None,
            301,
            "Moved",
            {},
            "https://radvisa.com/fixture/",
        )
        self.assertEqual(req.full_url, "https://radvisa.com/fixture/")

    def test_retained_failure_is_not_silently_counted_as_success(self):
        url = "https://radvisa.com/fixture"
        with tempfile.TemporaryDirectory() as d:
            cache = Path(d)
            collector = Collector(cache)
            (cache / (stable_id(url) + ".failure.json")).write_text(
                json.dumps(
                    {
                        "url": url,
                        "fetch_status": "http_error",
                        "status": 404,
                        "error": "Synthetic local fixture",
                        "retrieved_at": "2026-10-24T12:00:00Z",
                    }
                )
            )
            with (
                patch.object(collector, "allowed", return_value=True),
                patch.object(collector, "request") as request,
            ):
                collector.host_walk("radvisa.com", {url: ["synthetic_fixture"]})
            request.assert_not_called()
            self.assertEqual(collector.results[url]["fetch_status"], "http_error")
            self.assertNotIn("extraction", collector.results[url])

    def test_successful_cache_takes_precedence_over_prior_failed_attempt(self):
        url = "https://radvisa.com/fixture"
        html = b'<html><div itemprop="articleBody"><p>SYNTHETIC LOCAL FIXTURE.</p></div></html>'
        with tempfile.TemporaryDirectory() as d:
            cache = Path(d)
            sid = stable_id(url)
            collector = Collector(cache)
            (cache / (sid + ".failure.json")).write_text(
                json.dumps({"url": url, "fetch_status": "http_error", "status": 503})
            )
            (cache / (sid + ".html.gz")).write_bytes(gzip.compress(html, mtime=0))
            (cache / (sid + ".json")).write_text(
                json.dumps(
                    {
                        "raw_sha256": digest_bytes(html),
                        "status": 200,
                        "content_type": "text/html",
                        "final_url": url,
                    }
                )
            )
            with (
                patch.object(collector, "allowed", return_value=True),
                patch.object(collector, "request") as request,
            ):
                collector.host_walk("radvisa.com", {url: ["synthetic_fixture"]})
            request.assert_not_called()
            self.assertEqual(collector.results[url]["fetch_status"], "fetched")


class CanonicalTests(unittest.TestCase):
    def test_exact_duplicates_retain_all_provenance(self):
        a = record()
        b = record("https://digivisa.ir/synthetic-canada")
        groups, near = canonicalize([a, b])
        self.assertEqual(len(groups), 1)
        self.assertEqual(len(groups[0]["source_ids"]), 2)
        self.assertFalse(near)

    def test_country_and_pathway_prevent_silent_merge(self):
        a = record()
        b = record("https://digivisa.ir/synthetic-germany", "Synthetic Germany")
        c = record("https://radvisa.com/work-canada", "Work Canada")
        self.assertEqual(len(canonicalize([a, b, c])[0]), 3)

    def test_language_variants_not_automatically_translated_or_merged(self):
        a = record()
        b = copy.deepcopy(a)
        b["source_id"] = uid("fa-fixture")
        b["language"] = "fa"
        self.assertEqual(len(canonicalize([a, b])[0]), 2)

    def test_new_duplicate_keeps_existing_canonical_id(self):
        a = record()
        b = record("https://digivisa.ir/synthetic-canada")
        old = uid("old-canonical")
        groups, _ = canonicalize([a, b], {a["source_id"]: old})
        self.assertEqual(groups[0]["canonical_id"], old)

    def test_two_preexisting_identities_never_silently_merged(self):
        a = record()
        b = record("https://digivisa.ir/synthetic-canada")
        groups, _ = canonicalize(
            [a, b], {a["source_id"]: uid("a"), b["source_id"]: uid("b")}
        )
        self.assertEqual(len(groups), 2)
        self.assertTrue(all(g["prior_canonical_collision"] for g in groups))

    def test_persian_diacritics_are_not_exact_duplicate_equivalence(self):
        a = record(body="عِلْم " + BODY)
        b = record("https://digivisa.ir/a", body="عَلَم " + BODY)
        self.assertEqual(len(canonicalize([a, b])[0]), 2)

    def test_numeric_differences_are_potential_conflicts_not_merged_facts(self):
        a = record(body=BODY + " SYNTHETIC value 123.")
        b = record("https://digivisa.ir/a", body=BODY + " SYNTHETIC value 456.")
        groups, near = canonicalize([a, b])
        self.assertEqual(len(groups), 2)
        self.assertEqual(near[0]["relationship"], "potential_numeric_or_date_conflict")
        self.assertFalse(near[0]["verified_contradiction"])


class PayloadTests(unittest.TestCase):
    def test_payload_matches_authoritative_closed_contract_and_is_unapproved(self):
        a = article(record())
        self.assertTrue(a["validation"]["draft_payload_valid"])
        self.assertFalse(a["publication_allowed"])
        self.assertIsNone(a["approved_at"])
        self.assertEqual(a["wire"]["save_visa_article_draft"]["expected_revision"], 0)

    def test_catalog_constraint_is_not_bypassed_by_synthetic_country(self):
        s = record(title="Synthetic Ireland")
        g = canonicalize([s])[0][0]
        a = cms_payload(g, s, REG, {"CA"})
        self.assertIn(
            "destination_not_in_authoritative_catalog",
            a["validation"]["blocking_errors"],
        )
        self.assertEqual(a["country_code"], "IE")

    def test_generic_article_does_not_invent_a_country(self):
        a = article(
            record(
                "https://radvisa.com/content/synthetic-general",
                title="Synthetic general fixture",
            )
        )
        self.assertIsNone(a["country_code"])
        self.assertFalse(a["validation"]["draft_payload_valid"])

    def test_empty_and_thin_body_are_not_filled(self):
        thin = record(body="A short synthetic fixture.")
        self.assertFalse(thin["complete_article_body"])
        self.assertEqual(canonicalize([thin])[0], [])
        group = canonicalize([record()])[0][0]
        a = cms_payload(group, thin, REG, {"CA"})
        self.assertIn(
            "thin_source_body_requires_editorial_review",
            a["validation"]["blocking_errors"],
        )

    def test_http_200_error_page_never_becomes_a_canonical_article(self):
        s = record(title="404 Page not found")
        self.assertEqual(s["http_status"], 200)
        self.assertFalse(s["complete_article_body"])
        self.assertEqual(s["article_body_assessment"], "soft_404_not_an_article")
        self.assertEqual(canonicalize([s])[0], [])

    def test_section_evidence_maps_to_its_own_original_text(self):
        s = record()
        s["blocks"] = [
            {"type": "heading", "text": "First fixture"},
            {"type": "paragraph", "text": BODY},
            {"type": "heading", "text": "Second fixture"},
            {"type": "paragraph", "text": "Distinct synthetic section. " * 30},
        ]
        s["body_text"] = "\n\n".join(b["text"] for b in s["blocks"])
        s["body_sha256"] = digest(s["body_text"])
        s["snapshot_id"] = uid("snapshot:" + s["source_id"] + ":" + s["body_sha256"])
        a = article(s)
        refs = a["wire"]["save_visa_article_draft"]["sections"][1]["evidence_refs"]
        self.assertIn("Distinct synthetic section", refs[0]["excerpt"])
        self.assertIn("chars=", refs[0]["locator"])
        self.assertNotEqual(refs[0]["excerpt"], s["body_text"][:4000])

    def test_table_text_adaptation_is_explicit_not_discarded(self):
        s = record()
        s["blocks"] = [
            {
                "type": "table",
                "text": BODY,
                "rows": [[{"text": "Synthetic header"}], [{"text": "Synthetic cell"}]],
                "caption": "Synthetic table",
            }
        ]
        s["body_text"] = BODY
        s["body_sha256"] = digest(BODY)
        a = article(s)
        self.assertIn(
            "native_table_unsupported_plain_text_CMS_v1_original_table_preserved",
            a["validation"]["warnings"],
        )
        self.assertIn(
            "Synthetic cell",
            a["wire"]["save_visa_article_draft"]["sections"][0]["blocks"][0]["text"],
        )

    def test_placeholder_blocked_without_claiming_factual_validation(self):
        s = record(body="Lorem ipsum " + BODY)
        q = assess_source(s)
        self.assertIn("placeholder_text", q["blocking_errors"])
        self.assertEqual(q["verified_claims"], 0)

    def test_existing_production_document_id_preserved(self):
        url = "https://radvisa.com/content/synthetic-canada"
        existing = uid("existing-real-id")
        html = b'<div itemprop="articleBody"><p>Fixture.</p></div>'
        s = source_records(
            [
                {
                    "id": stable_id(url),
                    "url": url,
                    "fetch_status": "fetched",
                    "extraction": extract(html, url),
                }
            ],
            {"sources": [{"id": existing, "url": url, "title": "Existing"}]},
        )[0]
        self.assertEqual(s["source_id"], existing)
        self.assertEqual(s["id_origin"], "existing_production_document")


class ReferenceTests(unittest.TestCase):
    def test_broken_internal_link_is_distinct_from_unverified_external_evidence(self):
        source = record()
        target = record("https://radvisa.com/missing")
        target.update(http_status=404, fetch_status="http_error")
        source["body_links"] = [
            {"url": target["url"], "label": "Synthetic missing reference"},
            {
                "url": "https://government.example.invalid/fixture",
                "label": "Synthetic external reference",
            },
        ]
        for s in [source, target]:
            s["quality"] = assess_source(s)
        assess_references([source, target])
        self.assertEqual(
            source["reference_validation"][0]["target_status"],
            "broken_internal_reference",
        )
        self.assertEqual(
            source["reference_validation"][1]["target_status"],
            "external_target_not_verified",
        )
        self.assertIn("broken_internal_reference", source["quality"]["warnings"])
        self.assertEqual(source["quality"]["verified_claims"], 0)

    def test_nul_content_is_blocked_before_database_text_import(self):
        source = record()
        source["body_text"] += "\x00"
        self.assertIn(
            "unsupported_control_character", assess_source(source)["blocking_errors"]
        )


class ImportTests(unittest.TestCase):
    def test_contract_fingerprint_survives_windows_and_linux_checkouts(self):
        with tempfile.TemporaryDirectory() as d:
            p, _ = package(Path(d))
            payload = json.loads(p.read_text())
            payload["cms_registry_sha256"] = registry_sha256(REGISTRY)
            p.write_text(json.dumps(payload))
            for name, content in [
                ("lf.json", REGISTRY.read_bytes().replace(b"\r\n", b"\n")),
                (
                    "crlf.json",
                    REGISTRY.read_bytes()
                    .replace(b"\r\n", b"\n")
                    .replace(b"\n", b"\r\n"),
                ),
            ]:
                contract = Path(d) / name
                contract.write_bytes(content)
                self.assertEqual(validate_package(p, contract)["articles"], 1)

    def test_wire_identity_cannot_target_another_article(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            p, articles = package(root)
            a = articles[0]
            a["wire"]["save_visa_article_draft"]["article_id"] = uid(
                "different-article"
            )
            a["payload_sha256"] = digest(a["wire"])
            write_jsonl(root / "drafts.jsonl.gz", articles)
            x = json.loads(p.read_text())
            x["payload_file_sha256"] = digest_bytes(
                (root / "drafts.jsonl.gz").read_bytes()
            )
            x["articles"][0]["payload_sha256"] = a["payload_sha256"]
            p.write_text(json.dumps(x))
            with self.assertRaisesRegex(ValueError, "article_identity"):
                load_import(p, REGISTRY)

    def test_citation_locator_must_match_exact_excerpt(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            p, articles = package(root)
            a = articles[0]
            a["wire"]["save_visa_article_draft"]["sections"][0]["evidence_refs"][0][
                "locator"
            ] = "fixture;chars=1:5"
            a["payload_sha256"] = digest(a["wire"])
            write_jsonl(root / "drafts.jsonl.gz", articles)
            x = json.loads(p.read_text())
            x["payload_file_sha256"] = digest_bytes(
                (root / "drafts.jsonl.gz").read_bytes()
            )
            x["articles"][0]["payload_sha256"] = a["payload_sha256"]
            p.write_text(json.dumps(x))
            with self.assertRaisesRegex(ValueError, "citation_locator"):
                load_import(p, REGISTRY)

    def test_offline_package_and_citation_graph_validate(self):
        with tempfile.TemporaryDirectory() as d:
            p, _ = package(Path(d))
            a, s = load_import(p, REGISTRY)
            self.assertEqual(len(a), 1)
            self.assertEqual(len(s), 1)

    def test_journal_retry_is_idempotent_and_stays_draft(self):
        with tempfile.TemporaryDirectory() as d:
            p, _ = package(Path(d))
            result = sqlite_rehearsal(p, REGISTRY, Path(d) / "new.sqlite")
            self.assertEqual(result["first"]["created"], 1)
            self.assertEqual(result["second"]["replayed"], 1)
            self.assertTrue(result["row_counts_unchanged_on_retry"])
            self.assertEqual(result["publication_writes"], 0)

    def test_existing_owned_db_not_overwritten(self):
        with tempfile.TemporaryDirectory() as d:
            p, _ = package(Path(d))
            db = Path(d) / "existing.sqlite"
            db.write_bytes(b"preserve")
            with self.assertRaises(ValueError):
                sqlite_rehearsal(p, REGISTRY, db)
            self.assertEqual(db.read_bytes(), b"preserve")

    def test_changed_body_same_canonical_id_conflicts_non_destructively(self):
        s = record()
        a = article(s)
        with sqlite3.connect(":memory:") as db:
            sqlite_import(db, [a], {s["source_id"]: s})
            changed = copy.deepcopy(a)
            changed["payload_sha256"] = "0" * 64
            with self.assertRaisesRegex(ValueError, "revision_conflict"):
                sqlite_import(db, [changed], {s["source_id"]: s})
            self.assertEqual(
                db.execute("select payload_hash,state from plan3_articles").fetchone(),
                (a["payload_sha256"], "draft"),
            )

    def test_forged_approval_flags_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p, _ = package(Path(d))
            x = json.loads(p.read_text())
            x["approved_by"] = uid("fake-approval")
            p.write_text(json.dumps(x))
            with self.assertRaisesRegex(ValueError, "approval"):
                validate_package(p, REGISTRY)

    def test_publication_enabled_package_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p, _ = package(Path(d))
            x = json.loads(p.read_text())
            x["publication_allowed"] = True
            p.write_text(json.dumps(x))
            with self.assertRaisesRegex(ValueError, "draft_only"):
                validate_package(p, REGISTRY)

    def test_payload_path_escape_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p, _ = package(Path(d))
            x = json.loads(p.read_text())
            x["payload_file"] = "../outside.gz"
            p.write_text(json.dumps(x))
            with self.assertRaisesRegex(ValueError, "path_escape"):
                validate_package(p, REGISTRY)

    def test_payload_tampering_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p, _ = package(Path(d))
            (Path(d) / "drafts.jsonl.gz").write_bytes(b"tamper")
            with self.assertRaisesRegex(ValueError, "payload_file_hash"):
                validate_package(p, REGISTRY)

    def test_citation_snapshot_tampering_rejected_even_with_recomputed_file_hash(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            p, articles = package(root)
            a = articles[0]
            a["wire"]["save_visa_article_draft"]["sections"][0]["evidence_refs"][0][
                "snapshot_id"
            ] = uid("wrong-snapshot")
            a["payload_sha256"] = digest(a["wire"])
            write_jsonl(root / "drafts.jsonl.gz", articles)
            x = json.loads(p.read_text())
            x["payload_file_sha256"] = digest_bytes(
                (root / "drafts.jsonl.gz").read_bytes()
            )
            x["articles"][0]["payload_sha256"] = a["payload_sha256"]
            p.write_text(json.dumps(x))
            with self.assertRaisesRegex(ValueError, "citation_mapping"):
                load_import(p, REGISTRY)

    def test_hosted_runtime_is_rejected_before_any_docker_or_db_call(self):
        for url in [
            "postgresql://u:p@inshddthftkhcdosoqcn.supabase.co:5432/postgres",
            "postgresql://u:p@127.0.0.1.evil:62522/postgres",
            "postgresql://127.0.0.1/postgres",
            "postgresql://127.0.0.1:62522/postgres?host=remote.example",
            "postgresql://127.0.0.1:62522/postgres?hostaddr=1.2.3.4",
            "postgresql://127.0.0.1:62522/other_db",
        ]:
            with (
                self.subTest(url=url),
                patch("subprocess.check_output") as call,
                self.assertRaises(ValueError),
            ):
                validate_runtime(url, Path("does-not-exist"), ROOT)
            call.assert_not_called()


if __name__ == "__main__":
    unittest.main()
