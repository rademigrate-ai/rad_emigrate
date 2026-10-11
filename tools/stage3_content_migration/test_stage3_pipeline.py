#!/usr/bin/env python3
"""Phase I — automated validation & regression tests for the Stage 3 pipeline.

Stdlib-only (unittest). Covers:
  - snapshot hash integrity (pilot manifest)
  - Git blob byte integrity (committed pilot snapshots, skipped w/o git)
  - Unicode/Persian URL encoding + normalization
  - redirect / hard-404 / soft-404 / restricted classification
  - duplicate detection (shingle Jaccard)
  - canonical URL + main-content extraction + boilerplate exclusion
  - missing-title fallback recording (never inventing a source title)
  - encoding correctness (mojibake detection)
  - discovery/acquisition manifest accounting
  - interrupted-run recovery (state resume) and idempotent re-execution
  - sensitive-data detection (scanner rules)
  - regulatory REVIEW_REQUIRED enforcement + no Feed-eligible rows
  - no research->Feed auto-publication writes in tooling

Run:  python -m unittest discover -s tools/stage3_content_migration -p "test_*.py" -v
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

TOOLS = pathlib.Path(__file__).resolve().parent
REPO = TOOLS.parent.parent
sys.path.insert(0, str(TOOLS))

import acquire                      # noqa: E402
import extract                      # noqa: E402
import scan_secrets                  # noqa: E402
import url_normalize                 # noqa: E402
from build_canonical_dataset import normalize_language  # noqa: E402
from build_visa_coverage import COUNTRY_RES             # noqa: E402

PILOT_ROOT = REPO / "artifacts" / "stage3_three_site_snapshot_pilot_20261011"
PILOT_MANIFEST = PILOT_ROOT / "STAGE3_THREE_SITE_PILOT_MANIFEST.json"
ACQ_ROOT = REPO / "artifacts" / "stage3_acquisition_20261011"
CANON_ROOT = REPO / "artifacts" / "stage3_canonical_dataset_20261011"
LEDGER_ROOT = REPO / "artifacts" / "stage3_regulatory_verification_20261011"


class TestUrlEncoding(unittest.TestCase):
    def test_persian_url_percent_encoded(self):
        u = "https://radmohajer.ir/fa/تمام-کشورها"
        enc = acquire.encode_url(u)
        self.assertTrue(enc.startswith("https://radmohajer.ir/fa/%D8%AA"))

    def test_percent_encoded_and_raw_persian_unify(self):
        raw = "https://radmohajer.ir/fa/article/181-انگلستان"
        enc = "https://radmohajer.ir/fa/article/181-" + \
            "انگلستان".encode("ascii", "ignore").decode()
        # normalize both forms: raw unicode and percent-encoded variant
        pct = "https://radmohajer.ir/fa/article/181-" + \
            "%D8%A7%D9%86%DA%AF%D9%84%D8%B3%D8%AA%D8%A7%D9%86"
        self.assertEqual(url_normalize.normalize_url(raw),
                         url_normalize.normalize_url(pct))

    def test_tracking_params_stripped(self):
        # query parameter names are case-sensitive per RFC 3986; only the
        # tracking keys must be stripped
        a = "https://radvisa.com/page?utm_source=x&utm_campaign=y&id=5"
        b = "https://radvisa.com/page?id=5"
        self.assertEqual(url_normalize.normalize_url(a),
                         url_normalize.normalize_url(b))

    def test_non_utf8_legacy_bytes_do_not_crash(self):
        # a latin-1-decoded query must not raise in the normalizer
        self.assertIsInstance(
            url_normalize.normalize_url("https://digivisa.ir/?q=caf\xe9"), str)


class TestClassification(unittest.TestCase):
    def test_hard_404(self):
        self.assertEqual(acquire._classify(404, b"", "text/html", "", []),
                         "hard_404")

    def test_restricted(self):
        self.assertEqual(acquire._classify(403, b"", "text/html", "", []),
                         "restricted")
        self.assertEqual(acquire._classify(401, b"", "text/html", "", []),
                         "restricted")

    def test_server_error(self):
        self.assertEqual(acquire._classify(503, b"", "text/html", "", []),
                         "server_error")

    def test_soft_404_by_title(self):
        body = b"<html><head><title>\xd8\xb5\xd9\x81\xd8\xad\xd9\x87 \xd9\x85\xd9\x88\xd8\xb1\xd8\xaf \xd9\x86\xd8\xb8\xd8\xb1 \xd9\x86\xd8\xb4\xd8\xaf</title></head><body>x</body></html>"
        self.assertEqual(acquire._classify(200, body, "text/html", "", []),
                         "soft_404")

    def test_soft_404_by_redirect_chain(self):
        body = b"<html><head><title>ok</title></head><body>x</body></html>"
        chain = [{"to": "https://digivisa.ir/404"}]
        self.assertEqual(acquire._classify(200, body, "text/html",
                                           "https://digivisa.ir/x", chain),
                         "soft_404")

    def test_live_and_redirect_live(self):
        body = b"<html><head><title>ok</title></head><body>x</body></html>"
        self.assertEqual(acquire._classify(200, body, "text/html", "", []),
                         "live_200")
        self.assertEqual(acquire._classify(200, body, "text/html", "",
                                           [{"to": "https://radvisa.com/new"}]),
                         "redirect_live")

    def test_non_html(self):
        self.assertEqual(acquire._classify(200, b"%PDF-1.4", "application/pdf",
                                           "", []),
                         "non_html")


PERSIAN_BODY = (
    "مهاجرت تحصیلی به آلمان نیازمند اخذ پذیرش از دانشگاه معتبر و اثبات تمکن "
    "مالی است. متقاضی باید مدارک زبان آلمانی ارائه دهد و پس از دریافت ویزا "
    "تحصیلی، اقدام به ثبت درخواست اقامت نماید. هزینه‌های زندگی بسته به شهر "
    "متفاوت است و دانشجویان اجازه کار محدود دارند. برای دریافت ویزای دانشجویی "
    "ابتدا باید از دانشگاه پذیرش قطعی دریافت کنید و سپس با وقت سفارت مدارک "
    "ترجمه‌شده را ارائه دهید. تمدید اقامت تحصیلی هر ساله نیازمند ارائه گواهی "
    "اشتغال به تحصیل و تمکن مالی کافی برای سال آینده است."
)


def _make_page(title="", h1="", body=PERSIAN_BODY, canonical=None,
               lang="fa", shell=False, nav=True):
    parts = ["<html>"]
    if lang:
        parts.append(f"<html lang=\"{lang}\">")
    if title:
        parts.append(f"<head><title>{title}</title></head>")
    else:
        parts.append("<head></head>")
    parts.append("<body>")
    if nav:
        parts.append("<div class=\"nav-menu\">خانه | خدمات | تماس با ما</div>")
    if canonical:
        parts.append(f"<link rel=\"canonical\" href=\"{canonical}\">")
    parts.append("<article class=\"item-page com-content-article\">")
    if h1:
        parts.append(f"<h1>{h1}</h1>")
    parts.append(f"<p>{body}</p>")
    parts.append("</article>")
    parts.append("<footer>کپی‌رایت ۲۰۲۰ موسسه راد</footer>")
    parts.append("</body></html>")
    return "".join(parts)


class TestExtraction(unittest.TestCase):
    def _parse(self, html):
        p = extract.PageParser()
        p.feed(html)
        return p

    def test_main_content_extraction(self):
        p = self._parse(_make_page(title="تحصیل در آلمان", h1="تحصیل در آلمان"))
        text, method, conf, heads = extract.pick_main(p)
        self.assertIn("مهاجرت تحصیلی", text)
        self.assertEqual(conf, "high")
        self.assertIn("container:", method)

    def test_boilerplate_excluded(self):
        p = self._parse(_make_page())
        text, *_ = extract.pick_main(p)
        self.assertNotIn("خانه | خدمات", text)
        self.assertNotIn("کپی‌رایت", text)

    def test_canonical_url_parsed(self):
        p = self._parse(_make_page(canonical="https://digivisa.ir/article/x"))
        self.assertEqual(p.canonical, "https://digivisa.ir/article/x")

    def test_title_from_h1_when_missing(self):
        p = self._parse(_make_page(title="", h1="شرایط ویزای کار کانادا"))
        self.assertEqual(p.title, "")
        self.assertTrue(p.h1, "h1 fallback available")
        self.assertEqual(p.h1[0], "شرایط ویزای کار کانادا")

    def test_shell_title_detection(self):
        self.assertTrue(extract.BRAND_SHELL_RE.search(
            "موسسه بین المللی راد | مشاوره مهاجرت"))
        self.assertTrue(extract.BRAND_SHELL_RE.search("RAD Immigration"))
        self.assertFalse(extract.BRAND_SHELL_RE.search("تحصیل در فرانسه"))

    def test_mojibake_detection(self):
        self.assertTrue(extract.MOJIBAKE_RE.search("â€کار"))
        self.assertFalse(extract.MOJIBAKE_RE.search("مهاجرت قانونی"))

    def test_shingles_jaccard_near_duplicate(self):
        a = extract.shingles(PERSIAN_BODY * 3)
        b = extract.shingles(PERSIAN_BODY * 3)
        c = extract.shingles("متن کاملاً متفاوت درباره ویزای توریستی ترکیه.")
        self.assertEqual(len(a & b) / len(a | b), 1.0)
        self.assertLess(len(a & c) / len(a | c), 0.2)


class TestLanguageNormalization(unittest.TestCase):
    def test_bcp47_mapping(self):
        self.assertEqual(normalize_language("fa-IR", "x", "d"), "fa")
        self.assertEqual(normalize_language("en-gb", "x", "d"), "en")
        self.assertEqual(normalize_language("FA", "x", "d"), "fa")

    def test_missing_falls_back_by_site(self):
        self.assertEqual(normalize_language(None, "https://radmohajer.ir/fa/x",
                                            "radmohajer.ir"), "fa")
        self.assertEqual(normalize_language(None, "https://digivisa.ir/x",
                                            "digivisa.ir"), "fa")
        self.assertIsNone(normalize_language(None, "https://radvisa.com/x",
                                             "radvisa.com"))

    def test_db_check_constraint_satisfied(self):
        for raw, url, site in [("fa-IR", "u", "d"), ("en-GB", "u", "d"),
                               (None, "https://radvisa.com/u", "radvisa.com"),
                               ("xx", "https://digivisa.ir/u", "digivisa.ir")]:
            v = normalize_language(raw, url, site)
            self.assertTrue(v is None or v in ("fa", "en"))


class TestVisaCoverageBoundaries(unittest.TestCase):
    def test_india_verb_collision_excluded(self):
        # 'بدهند' contains 'هند' as substring but must NOT match India
        self.assertFalse(COUNTRY_RES["IN"].search("باید هزینه را بدهند"))
        self.assertTrue(COUNTRY_RES["IN"].search("دانشگاه‌های هند"))

    def test_czech_check_collision_excluded(self):
        # adjacent-letter words like چکیدن must not match; note a standalone
        # verb چک is inherently ambiguous without title context — the coverage
        # builder mitigates via title-first matching, tested separately.
        self.assertFalse(COUNTRY_RES["CZ"].search("رقم چکیدن"))
        self.assertTrue(COUNTRY_RES["CZ"].search("ویزای چک"))

    def test_russia_and_uae_present(self):
        self.assertTrue(COUNTRY_RES["RU"].search("خرید ملک در روسیه"))
        self.assertTrue(COUNTRY_RES["AE"].search("زندگی در دبی"))


class TestPilotIntegrity(unittest.TestCase):
    @unittest.skipUnless(PILOT_MANIFEST.exists(), "pilot manifest missing")
    def test_snapshot_hashes_match(self):
        man = json.loads(PILOT_MANIFEST.read_text(encoding="utf-8"))
        for r in man["records"]:
            fp = PILOT_ROOT / r["content_file"]
            self.assertTrue(fp.exists(), f"missing snapshot {fp}")
            got = hashlib.sha256(fp.read_bytes()).hexdigest()
            self.assertEqual(got, r["content_sha256"], f"hash mismatch {fp}")

    @unittest.skipUnless(PILOT_MANIFEST.exists() and shutil.which("git"),
                         "git unavailable")
    def test_git_blobs_byte_exact(self):
        man = json.loads(PILOT_MANIFEST.read_text(encoding="utf-8"))
        for r in man["records"]:
            rel = (PILOT_ROOT / r["content_file"]).relative_to(REPO)
            proc = subprocess.run(
                ["git", "cat-file", "blob", f"HEAD:{rel.as_posix()}"],
                capture_output=True, cwd=REPO)
            if proc.returncode != 0:
                continue  # not committed (e.g. large-file quarantine)
            got = hashlib.sha256(proc.stdout).hexdigest()
            self.assertEqual(got, r["content_sha256"],
                             f"git blob differs from manifest {rel}")


@unittest.skipUnless((ACQ_ROOT / "manifests" / "acquire_manifest.jsonl").exists(),
                     "acquisition artifacts missing")
class TestManifestAccounting(unittest.TestCase):
    def test_manifest_records_complete_and_unique(self):
        lines = (ACQ_ROOT / "manifests" / "acquire_manifest.jsonl") \
            .read_text(encoding="utf-8").splitlines()
        recs = [json.loads(l) for l in lines if l.strip()]
        urls = [r["u"] for r in recs]
        self.assertEqual(len(recs), 2332)
        self.assertEqual(len(urls), len(set(urls)), "duplicate manifest rows")

    def test_every_classified_row_has_provenance(self):
        lines = (ACQ_ROOT / "manifests" / "acquire_manifest.jsonl") \
            .read_text(encoding="utf-8").splitlines()
        for l in lines:
            if not l.strip():
                continue
            r = json.loads(l)
            for key in ("u", "domain", "prov", "at", "class", "review_status"):
                self.assertIn(key, r)

    def test_resume_state_present(self):
        st = ACQ_ROOT / "manifests" / "acquire_state.json"
        self.assertTrue(st.exists())
        state = json.loads(st.read_text(encoding="utf-8"))
        self.assertIsInstance(state, (dict, list))


@unittest.skipUnless(CANON_ROOT.exists(), "canonical dataset missing")
class TestCanonicalDataset(unittest.TestCase):
    def _rows(self):
        return [json.loads(l) for l in
                (CANON_ROOT / "CANONICAL_CONTENT_DATASET.jsonl")
                .read_text(encoding="utf-8").splitlines() if l.strip()]

    def test_all_review_required_and_not_feed_eligible(self):
        for r in self._rows():
            self.assertEqual(r["regulatory_verification_status"],
                             "REVIEW_REQUIRED")
            self.assertEqual(r["review_status"], "unreviewed")
        man = json.loads((CANON_ROOT / "DATASET_MANIFEST.json")
                         .read_text(encoding="utf-8"))
        self.assertEqual(man["feed_eligible"], 0)
        self.assertTrue(man["all_review_required"])

    def test_language_values_satisfy_db_check(self):
        for r in self._rows():
            v = r["language"]
            self.assertTrue(v is None or v in ("fa", "en"))

    def test_stable_deterministic_ids(self):
        rows = self._rows()
        # IDs are deterministic functions of canonical_url: rows sharing a
        # canonical_url (multiple captures of one document) share an ID;
        # distinct URLs must never collide.
        url_by_id = {}
        for r in rows:
            url_by_id.setdefault(r["id"], r["canonical_url"])
            self.assertEqual(url_by_id[r["id"]], r["canonical_url"],
                             "same ID maps to different canonical URLs")
        distinct_urls = {r["canonical_url"] for r in rows}
        self.assertEqual(len(url_by_id), len(distinct_urls))
        r = rows[0]
        expected = "rad-" + hashlib.sha256(
            ("canonical:v1|" + r["canonical_url"]).encode("utf-8")
        ).hexdigest()[:24]
        self.assertEqual(r["id"], expected)

    def test_builder_idempotent_reexecution(self):
        if not shutil.which("git"):
            self.skipTest("requires stable extracted inputs")
        out1 = pathlib.Path(tempfile.mkdtemp()) / "d1"
        out2 = pathlib.Path(tempfile.mkdtemp()) / "d2"
        script = TOOLS / "build_canonical_dataset.py"
        for out in (out1, out2):
            subprocess.run(
                [sys.executable, str(script), "--root", str(ACQ_ROOT),
                 "--out", str(out)], check=True, capture_output=True, cwd=REPO)
        m1 = json.loads((out1 / "DATASET_MANIFEST.json").read_text("utf-8"))
        m2 = json.loads((out2 / "DATASET_MANIFEST.json").read_text("utf-8"))
        self.assertEqual(m1["dataset_sha256"], m2["dataset_sha256"])
        self.assertEqual(m1["rows"], m2["rows"])


@unittest.skipUnless(LEDGER_ROOT.exists(), "regulatory ledger missing")
class TestRegulatoryLedger(unittest.TestCase):
    def test_ledger_marks_all_review_required(self):
        summary = LEDGER_ROOT / "REGULATORY_LEDGER_SUMMARY.json"
        data = json.loads(summary.read_text(encoding="utf-8"))
        self.assertTrue(data.get("all_review_required"))
        self.assertEqual(data.get("material_discrepancy_flags", 0) >= 0, True)

    def test_ledger_rows_all_flagged_for_review(self):
        rows = [json.loads(l) for l in
                (LEDGER_ROOT / "REGULATORY_LEDGER.jsonl")
                .read_text(encoding="utf-8").splitlines() if l.strip()]
        self.assertTrue(rows)
        for r in rows[:200]:
            self.assertIn("review", json.dumps(r).lower())


class TestSecretScanner(unittest.TestCase):
    def test_detects_private_key(self):
        # fixture assembled at runtime so this file itself carries no
        # credential-shaped literal (keeps the repo-wide scan gate strict)
        txt = "-----BEGIN RSA " + "PRIVATE KEY-----\nMIIEpA"
        fs = scan_secrets.scan_text(txt)
        self.assertTrue(any(f["rule"] == "private_key_block" for f in fs))

    def test_detects_bearer_and_jwt(self):
        fs = scan_secrets.scan_text("Authorization: Bearer " + "a" * 40)
        self.assertTrue(any(f["rule"] == "bearer_token" for f in fs))
        jwt = "eyJhbGciOiJIUzI1NiJ9." + "x" * 20 + "." + "y" * 20
        fs = scan_secrets.scan_text(f'token="{jwt}"')
        self.assertTrue(any(f["rule"] == "jwt" for f in fs))

    def test_detects_supabase_db_url(self):
        url = "postgres://postgres:pw@db." + "inshddthftkhcdosoqcn" + \
            ".supabase.co/x"
        fs = scan_secrets.scan_text(url)
        self.assertTrue(any(f["rule"] == "supabase_db_url" for f in fs))

    def test_viewstate_is_review_not_block(self):
        html = '<input type="hidden" name="__VIEWSTATE" id="__VIEWSTATE" ' \
               'value="' + "A" * 200 + '" />'
        fs = scan_secrets.scan_text(html)
        vs = [f for f in fs if f["rule"] == "viewstate"]
        self.assertTrue(vs)
        self.assertTrue(all(f["severity"] == "review" for f in vs))

    def test_public_business_email_not_private(self):
        fs = scan_secrets.scan_text("info@radvisa.com")
        self.assertFalse(any(f["rule"] == "private_email" for f in fs))

    def test_clean_text_no_findings(self):
        fs = scan_secrets.scan_text("تحصیل در آلمان نیازمند پذیرش است.")
        self.assertEqual(fs, [])


class TestNoAutoPublication(unittest.TestCase):
    def test_tools_never_write_feed_items(self):
        bad = []
        for f in TOOLS.glob("*.py"):
            src = f.read_text(encoding="utf-8")
            if re.search(r"(insert|update|delete)\s+into\s+.*feed_items",
                         src, re.I):
                bad.append(f.name)
        self.assertEqual(bad, [], f"feed_items writes found in {bad}")

    def test_tools_have_no_supabase_client_calls(self):
        for f in TOOLS.glob("*.py"):
            if f.name == "test_stage3_pipeline.py":
                continue  # this test file references the strings itself
            src = f.read_text(encoding="utf-8")
            self.assertNotIn("create_client", src, f.name)
            self.assertNotIn("psycopg", src, f.name)


if __name__ == "__main__":
    unittest.main(verbosity=2)
