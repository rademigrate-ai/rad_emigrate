#!/usr/bin/env python3
"""Phase H — visa content coverage from evidence.

Scans the canonical content dataset for destination-country and program-category
coverage using word-boundary matching (plain substring matching inflates counts
via Persian words like 'بدهند' colliding with 'هند' (India) or 'چک' (check)
colliding with 'Czech').

Outputs (under --out):
  VISA_COVERAGE_REPORT.json        - per country x category evidence matrix
  VISA_INITIALIZATION_PACKAGE.json - draft rows mapped to the real DB schema
                                     (content_sources, destinations,
                                      destination_localizations, visa_programs,
                                      visa_program_localizations,
                                      visa_program_requirements, steps)
                                     ALL rows status='draft', review_required.
  VISA_VALIDATION_REPORT.md        - coverage gaps and validation summary

Deterministic, stdlib-only, NO database writes.
"""
import argparse
import collections
import hashlib
import json
import pathlib
import re

SCHEMA_VERSION = "rad-visa-coverage-v1"

# ISO-3166 alpha-2 -> (Persian name(s), English name(s))
COUNTRIES = {
    "DE": (["آلمان"], ["Germany"]),
    "CA": (["کانادا"], ["Canada"]),
    "GB": (["انگلستان", "بریتانیا"], ["United Kingdom", "Britain", "England"]),
    "US": (["آمریکا", "ایالات متحده", "امریکا"], ["United States", "USA", "America"]),
    "AU": (["استرالیا", "استراليا"], ["Australia"]),
    "SE": (["سوئد", "سوید"], ["Sweden"]),
    "DK": (["دانمارک"], ["Denmark"]),
    "NO": (["نروژ"], ["Norway"]),
    "FI": (["فنلاند"], ["Finland"]),
    "FR": (["فرانسه"], ["France"]),
    "IT": (["ایتالیا", "ايتاليا"], ["Italy"]),
    "ES": (["اسپانیا", "اسپانيا"], ["Spain"]),
    "PT": (["پرتغال"], ["Portugal"]),
    "AT": (["اتریش"], ["Austria"]),
    "TR": (["ترکیه", "تركيه"], ["Turkey", "Türkiye"]),
    "MY": (["مالزی", "ماليزيا"], ["Malaysia"]),
    "NL": (["هلند"], ["Netherlands", "Holland"]),
    "BE": (["بلژیک"], ["Belgium"]),
    "CH": (["سوئیس"], ["Switzerland"]),
    "AE": (["امارات", "دبی"], ["UAE", "Emirates", "Dubai"]),
    "QA": (["قطر"], ["Qatar"]),
    "OM": (["عمان"], ["Oman"]),
    "GR": (["یونان"], ["Greece"]),
    "PL": (["لهان", "لهستان"], ["Poland"]),
    "HU": (["مجارستان"], ["Hungary"]),
    "CZ": (["چک", "جمهوری چک"], ["Czech"]),
    "RO": (["رومانی"], ["Romania"]),
    "CY": (["قبرس"], ["Cyprus"]),
    "NZ": (["نیوزیلند", "نیوزلند"], ["New Zealand"]),
    "IE": (["ایرلند"], ["Ireland"]),
    "JP": (["ژاپن"], ["Japan"]),
    "KR": (["کره جنوبی"], ["South Korea"]),
    "SG": (["سنگاپور"], ["Singapore"]),
    "IN": (["هند", "هندوستان"], ["India"]),
    "PK": (["پاکستان"], ["Pakistan"]),
    "IQ": (["عراق"], ["Iraq"]),
    "AF": (["افغانستان"], ["Afghanistan"]),
    "LB": (["لبنان"], ["Lebanon"]),
    "JO": (["اردن"], ["Jordan"]),
    "EG": (["مصر"], ["Egypt"]),
    "BR": (["برزیل"], ["Brazil"]),
    "GE": (["گرجستان"], ["Georgia"]),
    "AM": (["ارمنستان", "ارمنيه"], ["Armenia"]),
    "AZ": (["آذربایجان", "آذربايجان"], ["Azerbaijan"]),
    "UA": (["اوکراین", "اوکراين"], ["Ukraine"]),
    "RS": (["صربستان"], ["Serbia"]),
    "HR": (["کرواسی"], ["Croatia"]),
    "SK": (["اسلوواکی"], ["Slovakia"]),
    "EE": (["استونی"], ["Estonia"]),
    "LV": (["لتونی"], ["Latvia"]),
    "LT": (["لیتوانی"], ["Lithuania"]),
    "MT": (["مالت"], ["Malta"]),
    "ZA": (["آفریقای جنوبی"], ["South Africa"]),
    "RU": (["روسیه"], ["Russia"]),
    "CN": (["چین"], ["China"]),
    "KZ": (["قزاقستان"], ["Kazakhstan"]),
    "UZ": (["ازبکستان"], ["Uzbekistan"]),
    "TJ": (["تاجیکستان"], ["Tajikistan"]),
    "TH": (["تایلند"], ["Thailand"]),
    "ID": (["اندونزی"], ["Indonesia"]),
    "PH": (["فیلیپین"], ["Philippines"]),
    "VN": (["ویتنام"], ["Vietnam"]),
    "BH": (["بحرین"], ["Bahrain"]),
    "KW": (["کویت"], ["Kuwait"]),
    "SA": (["عربستان", "عربستان سعودی"], ["Saudi Arabia"]),
    "MA": (["مراکش"], ["Morocco"]),
    "DZ": (["الجزایر"], ["Algeria"]),
    "NG": (["نیجریه"], ["Nigeria"]),
    "KE": (["کنیا"], ["Kenya"]),
    "MV": (["مالدیو"], ["Maldives"]),
}

COUNTRY_NAME = {}
for iso, (fa_list, en_list) in COUNTRIES.items():
    for n in fa_list + en_list:
        COUNTRY_NAME.setdefault(n.lower(), iso)

# word-boundary pattern per ISO code (alternation of all its names)
BOUNDARY = r"(?<![^\s\-_.,;:()\[\]«»؟!؟/])%s(?![^\s\-_.,;:()\[\]«»؟!؟/])"
COUNTRY_RES = {
    iso: re.compile("|".join(BOUNDARY % re.escape(n)
                              for n in fa_list + en_list), re.I)
    for iso, (fa_list, en_list) in COUNTRIES.items()
}

CATEGORIES = {
    "study": ["تحصیل", "دانشگاه", "دانشجو", "کالج", "آیلتس", "IELTS", "بورسیه", "bursary", "scholarship", "university", "student", "study", "college"],
    "work": ["ویزای کار", "کاریابی", "اشتغال", "شغل", "نیروی کار", "کارمند", "حقوق", "مزد", "work visa", "job", "employment", "skilled worker", "salary"],
    "job_seeker": ["جستجوی کار", "چانس‌کارته", "چانس کارته", "Chancenkarte", "Opportunity Card", "job seeker"],
    "invest": ["سرمایه‌گذاری", "سرمایه گذاری", "گلدن ویا", "golden visa", "investor", "investment"],
    "family": ["ویزای خانواده", "همسر", "والدین", "فرزندان", "family", "spouse", "partner visa", "نامزدی"],
    "business": ["ثبت شرکت", "کسب و کار", "کارآفرینی", "startup", "business", "company registration", "entrepreneur"],
    "tourism": ["ویزای توریستی", "گردشگری", "توریست", "tourist", "tourism", "visit visa"],
}
CAT_RES = {
    cat: re.compile("|".join(re.escape(k) for k in kws), re.I)
    for cat, kws in CATEGORIES.items()
}

# slug per category (must match DB check: ^[a-z0-9-]+$)
CATEGORY_SLUG = {
    "study": "study", "work": "work", "job_seeker": "job-seeker",
    "invest": "invest", "family": "family", "business": "business",
    "tourism": "tourism",
}

MIN_PAGES_READY = 3          # unique PASS-primary pages to be 'ready for review'
MAX_SUMMARY_CHARS = 1800     # keep summaries bounded


def detect(text: str):
    countries = sorted({iso for iso, rx in COUNTRY_RES.items() if rx.search(text)})
    cats = sorted({c for c, rx in CAT_RES.items() if rx.search(text)})
    return countries, cats


def slugify(url: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", url.lower()).strip("-")
    return (s[-60:] or "page").strip("-")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", required=True,
                    help="CANONICAL_CONTENT_DATASET.jsonl path")
    ap.add_argument("--findings", required=True,
                    help="OFFICIAL_SOURCE_FINDINGS json path")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    records = [json.loads(l) for l in
               pathlib.Path(args.dataset).read_text(encoding="utf-8").splitlines()
               if l.strip()]
    findings = json.loads(pathlib.Path(args.findings).read_text(encoding="utf-8"))
    official_by_dest = collections.defaultdict(list)
    for f in findings.get("findings", []):
        official_by_dest[f.get("destination")].append({
            "id": f.get("id"), "pathway": f.get("pathway"),
            "verification_state": f.get("verification_state"),
            "official_urls": f.get("official_urls"),
        })

    # index unique content units: group primaries only (deduped evidence)
    units = [r for r in records if r.get("is_group_primary")]
    matrix = collections.defaultdict(list)
    for r in units:
        title = r.get("extracted_title") or ""
        body = (r.get("body") or "")[:3000]
        # Titles are the strongest signal: if the title names any country /
        # category, trust only the title (a Russia article that merely mentions
        # Dubai in passing must not count as UAE coverage).
        t_countries, t_cats = detect(title)
        if t_countries:
            countries = t_countries
        else:
            countries = detect(body)[0]
        if t_cats:
            cats = t_cats
        else:
            cats = detect(body)[1]
        for c in countries:
            for cat in cats:
                row = dict(r)
                row["_title_hit"] = c in t_countries and cat in t_cats
                matrix[(c, cat)].append(row)

    coverage_rows = []
    tiers = collections.Counter()
    for (country, cat), rows in sorted(matrix.items()):
        n_pass = sum(1 for r in rows if r["quality_classification"] == "PASS")
        n_review = sum(1 for r in rows if r["quality_classification"] == "REVIEW")
        n_fail = sum(1 for r in rows if r["quality_classification"] == "FAIL")
        if n_pass >= MIN_PAGES_READY:
            tier = "evidence_backed_ready_for_review"
        elif n_pass >= 1 or n_review >= 2:
            tier = "incomplete_evidence"
        else:
            tier = "not_supported_by_sources"
        tiers[tier] += 1
        evidence = sorted(rows, key=lambda r: (r["quality_classification"] != "PASS",
                                               not r.get("_title_hit"),
                                               r["canonical_url"]))
        coverage_rows.append({
            "destination": country, "category": cat, "tier": tier,
            "unique_pages": len(rows), "pass": n_pass, "review": n_review,
            "fail": n_fail,
            "evidence_urls": [r["canonical_url"] for r in evidence[:10]],
            "official_findings": official_by_dest.get(country, []),
            "regulatory_state": "REVIEW_REQUIRED",
        })

    # --- initialization package (draft rows mapped to the real schema) ---
    content_sources = []
    for site in sorted({r["site"] for r in records}):
        content_sources.append({
            "publisher": site, "source_type": "rad_official",
            "title": f"RAD official site {site}", "url": f"https://{site}/",
            "language_code": "fa",
        })
    for iso, fl in sorted(official_by_dest.items()):
        for f in fl:
            for u in (f.get("official_urls") or [])[:1]:
                content_sources.append({
                    "publisher": iso, "source_type": "government",
                    "title": f"Official verification: {f['id']}", "url": u,
                    "language_code": "en",
                })

    destinations = []
    destination_localizations = []
    programs = []
    program_localizations = []
    requirements = []
    steps = []
    ready_rows = [r for r in coverage_rows
                  if r["tier"] == "evidence_backed_ready_for_review"]
    for row in ready_rows:
        country, cat = row["destination"], row["category"]
        dest_slug = country.lower()
        if not any(d["slug"] == dest_slug for d in destinations):
            destinations.append({"code": country, "slug": dest_slug,
                                 "status": "draft"})
            fa_name = next(n for n, iso in COUNTRY_NAME.items() if iso == country
                           and not n.isascii())
            destination_localizations.append({
                "destination_slug": dest_slug, "locale": "fa", "name": fa_name,
                "summary": f"خلاصه پوشش محتوایی {fa_name} — پیش‌نویس، نیازمند بازبینی انسانی.",
            })
        prog_slug = f"{dest_slug}-{CATEGORY_SLUG[cat]}"
        primary = next((r for r in sorted(
            matrix[(country, cat)],
            key=lambda r: (r["quality_classification"] != "PASS",
                           not r.get("_title_hit"), r["canonical_url"]))
            if r["quality_classification"] == "PASS"),
            matrix[(country, cat)][0])
        programs.append({
            "slug": prog_slug, "destination_slug": dest_slug,
            "category_slug": CATEGORY_SLUG[cat],
            "primary_source_url": primary["canonical_url"], "status": "draft",
        })
        title = primary.get("extracted_title") or prog_slug
        summary = (primary.get("body") or "")[:MAX_SUMMARY_CHARS]
        program_localizations.append({
            "program_slug": prog_slug, "locale": "fa",
            "title": title, "summary": summary,
            "description": f"استخراج‌شده از {len(row['evidence_urls'])} صفحه مدرک‌محور؛ "
                           f"وضعیت: REVIEW_REQUIRED.",
        })
        requirements.append({
            "program_slug": prog_slug, "locale": "fa",
            "requirement": "متن الزامات تنها از صفحات PASS استخراج و پس از تایید "
                           "منابع رسمی نهایی می‌شود.",
            "is_mandatory": None, "display_order": 0,
            "source_url": primary["canonical_url"],
        })
        steps.append({
            "program_slug": prog_slug, "locale": "fa",
            "title": "گام‌های فرایند (پیش‌نویس)",
            "description": "ساختار گام‌ها آماده است؛ محتوا پس از بازبینی انسانی و "
                           "تصدیق منابع رسمی پر می‌شود.",
            "display_order": 0, "source_url": primary["canonical_url"],
        })

    package = {
        "schema_version": SCHEMA_VERSION,
        "generated_from_dataset": str(pathlib.Path(args.dataset)),
        "note": "DRAFT ONLY — no writes performed. All rows status='draft'; "
                "every visa fact requires human review + official-source "
                "approval before any ingestion.",
        "content_sources": content_sources,
        "destinations": destinations,
        "destination_localizations": destination_localizations,
        "visa_programs": programs,
        "visa_program_localizations": program_localizations,
        "visa_program_requirements": requirements,
        "visa_program_steps": steps,
    }
    (out / "VISA_INITIALIZATION_PACKAGE.json").write_text(
        json.dumps(package, ensure_ascii=False, indent=2), encoding="utf-8")

    per_country = collections.Counter(r["destination"] for r in coverage_rows)
    per_cat = collections.Counter(r["category"] for r in coverage_rows)
    coverage = {
        "schema_version": SCHEMA_VERSION,
        "unique_content_units": len(units),
        "coverage_pairs": len(coverage_rows),
        "tiers": dict(tiers),
        "per_destination": dict(per_country.most_common()),
        "per_category": dict(per_cat.most_common()),
        "rows": coverage_rows,
        "all_review_required": True,
        "production_writes": 0,
    }
    (out / "VISA_COVERAGE_REPORT.json").write_text(
        json.dumps(coverage, ensure_ascii=False, indent=2), encoding="utf-8")

    md = [
        "# Visa Coverage Validation Report (Phase H)",
        "",
        f"- Unique content units (deduped primaries): **{len(units)}**",
        f"- Destination × category pairs with evidence: **{len(coverage_rows)}**",
        f"- Tier distribution: {dict(tiers)}",
        "",
        "## Top destinations by evidence volume",
        "",
    ]
    for iso, n in per_country.most_common(15):
        md.append(f"- {iso}: {n} category pairs")
    md += [
        "",
        "## Package discipline",
        "",
        "- All initialization rows are `status='draft'` and require human review;",
        "- every requirement/step cites a content source and is marked",
        "  REVIEW_REQUIRED;",
        "- no immigration fact was invented — summaries are excerpts of",
        "  captured source pages only;",
        "- no production writes were performed.",
        "",
    ]
    (out / "VISA_VALIDATION_REPORT.md").write_text("\n".join(md), encoding="utf-8")

    print(json.dumps({
        "unique_units": len(units), "pairs": len(coverage_rows),
        "tiers": dict(tiers), "draft_programs": len(programs),
        "destinations": len(destinations),
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
