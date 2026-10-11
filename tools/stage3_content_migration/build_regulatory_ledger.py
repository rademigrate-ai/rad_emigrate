#!/usr/bin/env python3
"""Build the Stage 3 regulatory verification ledger from extracted content.

Deterministic, stdlib-only. For every extracted page (PASS/REVIEW), extracts
regulatory-sensitive claims (fees, timelines, eligibility, guarantees, program
existence, work rights) preserving ORIGINAL source wording, classifies each
claim, links destination-matched official-source findings where available, and
flags material discrepancies. EVERY row remains REVIEW_REQUIRED; this tool
never approves, auto-publishes, or invents anything.

Usage:
  python build_regulatory_ledger.py --root artifacts/stage3_acquisition_20261011 \
      --findings artifacts/stage3_regulatory_verification_20261011/OFFICIAL_SOURCE_FINDINGS_20261011.json \
      --out artifacts/stage3_regulatory_verification_20261011
"""
import argparse
import hashlib
import json
import pathlib
import re
import sys
from collections import Counter

DEST_KEYWORDS = {
    "CA": ["کانادا", "canada"],
    "DE": ["آلمان", "المان", "germany", "deutschland"],
    "GB": ["انگلستان", "انگلیس", "بریتانیا", "britain", "united kingdom", " uk "],
    "US": ["آمریکا", "امریکا", "ایالات متحده", "united states", "usa "],
    "AU": ["استرالیا", "australia"],
    "SE": ["سوئد", "سوید", "sweden"],
    "DK": ["دانمارک", "denmark"],
    "NO": ["نروژ", "norway"],
    "FI": ["فنلاند", "finland"],
    "IT": ["ایتالیا", "italy"],
    "FR": ["فرانسه", "france"],
    "ES": ["اسپانیا", "spain"],
    "AT": ["اتریش", "austria"],
    "NL": ["هلند", "netherlands", "holland"],
    "TR": ["ترکیه", "turkey"],
    "MY": ["مالزی", "malaysia"],
    "HU": ["مجارستان", "hungary"],
    "PT": ["پرتغال", "portugal"],
    "GR": ["یونان", "greece"],
    "CZ": ["چک", "czech"],
    "PL": ["لهستان", "poland"],
    "AE": ["امارات", "دبی", "dubai", "uae"],
    "CY": ["قبرس", "cyprus"],
}

CLAIM_MARKERS = [
    ("guarantee", re.compile(
        r"(تضمین|ضمانت|۱۰۰\s*٪|۱۰۰\s*در\s*صد|صد\s*در\s*صد|guarantee|گارانتی|موفقیت\s*\d|\d+\s*درصد\s*(موفقیت|قبولی)|success\s*rate)", re.I)),
    ("fee", re.compile(
        r"(دلار|یورو|پوند|ریال|شهریه|هزینه|فی\s|حداقل\s*سرمایه|سرمایه\s*گذاری\s*به\s*مبلغ|deposit|tuition|fee|cost|CAD|USD|EUR|GBP|AUD|DKK|SEK|NOK)", re.I)),
    ("timeline", re.compile(
        r"(\d+\s*(ماه|سال|روز|هفته)|زمان\s*(بررسی|پردازش|صدور)|مدت\s*(بررسی|اقامت|ویزا)|processing\s*time|\d+\s*(months?|days?|years?|weeks?))", re.I)),
    ("program_existence", re.compile(
        r"(گرین\s*کارت|کارت\s*سبز|golden|ویزای\s*سرمایه\s*گذاری|اقامت\s*سرمایه\s*گذاری|تابعیت\s*سرمایه|شهروندی\s*سرمایه|residency\s*by\s*investment|citizenship\s*by\s*investment|اقامت\s*از\s*طریق\s*سرمایه)", re.I)),
    ("work_rights", re.compile(
        r"(کار\s*(کردن|یابی|در حین)|اجازه\s*کار|حق\s*کار|ویزای\s*کاری|کار\s*حین\s*تحصیل|work\s*right|part[- ]?time|اقدام\s*از\s*داخل)", re.I)),
    ("eligibility", re.compile(
        r"(شرایط|الزامات|نیازمند|پیش\s*نیاز|الگوی|گواهی|زبان\s*(آلمانی|انگلیسی)?\s*[ABC]1|IELTS|TOEFL|آیلتس|تافل|اقدام\s*از\s*طریق|eligibility|requirement)", re.I)),
]
TYPE_PRIORITY = ["guarantee", "program_existence", "fee", "timeline", "work_rights", "eligibility"]

# Official findings id -> (destination, claim_types) it informs.
FINDING_LINKS = {
    "dk_green_card_abolished": ({"DK"}, {"program_existence"}),
    "de_no_passive_investment": ({"DE"}, {"program_existence"}),
    "ca_investment_routes_closed": ({"CA"}, {"program_existence"}),
    "gb_no_investor_route": ({"GB"}, {"program_existence"}),
    "au_no_golden_visa": ({"AU"}, {"program_existence"}),
    "se_work_study": ({"SE"}, {"program_existence"}),
    "dk_green_card_abolished_note": ({"DK"}, {"program_existence"}),
}
# Findings whose facts CONTRADICT matching claims (material discrepancy).
CONTRADICTING = {"dk_green_card_abolished", "de_no_passive_investment",
                 "ca_investment_routes_closed", "gb_no_investor_route",
                 "au_no_golden_visa", "se_work_study"}
# Findings providing reference amounts/timelines for human comparison.
REFERENCE_FACTS = {
    ("CA", "fee"): "ca_study_permit", ("CA", "timeline"): "ca_family_citizenship",
    ("GB", "fee"): "gb_student_visa", ("GB", "timeline"): "gb_family_citizenship",
    ("AU", "fee"): "au_student_skilled", ("DE", "fee"): "de_opportunity_card",
    ("DK", "fee"): "dk_green_card_abolished", ("US", "program_existence"): "us_eb5",
}

SENT_SPLIT = re.compile(r"(?<=[.!?؟])\s+|\n+")
MAX_CLAIMS_PER_PAGE = 20


def guess_destination(text: str):
    low = " " + text.lower() + " "
    hits = [d for d, kws in DEST_KEYWORDS.items() if any(k in low for k in kws)]
    return hits


def classify_claim(sentence: str):
    for ctype in TYPE_PRIORITY:
        pat = dict(CLAIM_MARKERS)[ctype]
        if pat.search(sentence):
            return ctype
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--findings", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    root = pathlib.Path(args.root)
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    findings_doc = json.loads(pathlib.Path(args.findings).read_text(encoding="utf-8"))
    findings_by_id = {f["id"]: f for f in findings_doc["findings"]}

    ledger = []
    pages_with_claims = 0
    pages_scanned = 0
    for jf in sorted((root / "extracted").glob("*.jsonl")):
        if jf.name == "quality_ledger.jsonl":
            continue  # compact per-page ledger, not full records
        for line in jf.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            rec = json.loads(line)
            if rec["quality"] == "FAIL":
                continue
            pages_scanned += 1
            text = rec["main_text"] or ""
            if not text:
                continue
            dests = guess_destination((rec["title"] or "") + " " + rec["u"])
            claims = []
            for sent in SENT_SPLIT.split(text):
                sent = sent.strip()
                if len(sent) < 25 or len(sent) > 500:
                    continue
                ctype = classify_claim(sent)
                if not ctype:
                    continue
                claims.append((ctype, sent))
                if len(claims) >= MAX_CLAIMS_PER_PAGE:
                    break
            if not claims:
                continue
            pages_with_claims += 1
            for ctype, sent in claims:
                linked = []
                contradicted = False
                for fid, (fdests, ftypes) in FINDING_LINKS.items():
                    if fid not in findings_by_id:
                        continue
                    if ctype in ftypes and any(d in fdests for d in dests):
                        linked.append(fid)
                        if fid in CONTRADICTING:
                            contradicted = True
                reference = None
                for d in dests:
                    if (d, ctype) in REFERENCE_FACTS:
                        fid = REFERENCE_FACTS[(d, ctype)]
                        if fid in findings_by_id:
                            reference = fid
                            break
                row = {
                    "claim_id": hashlib.sha256(
                        (rec["u"] + "|" + sent).encode("utf-8")).hexdigest()[:20],
                    "site": rec["domain"],
                    "url": rec["u"],
                    "page_title": rec["title"],
                    "page_quality": rec["quality"],
                    "destinations": dests,
                    "claim_type": ctype,
                    "claim_text": sent,
                    "claim_wording": "verbatim_source",
                    "regulatory_status": "REVIEW_REQUIRED",
                    "requires_human_approval": True,
                    "official_findings_linked": linked,
                    "reference_official_finding": reference,
                    "material_discrepancy_flag": contradicted,
                    "verification_state": "pending_human_review" if not contradicted
                        else "discrepancy_vs_official_source_needs_review",
                }
                ledger.append(row)

    ledger_path = out / "REGULATORY_LEDGER.jsonl"
    with open(ledger_path, "w", encoding="utf-8", newline="\n") as f:
        for row in ledger:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    dist = Counter((r["destinations"][0] if r["destinations"] else "UNSPECIFIED",
                    r["claim_type"]) for r in ledger)
    summary = {
        "schema_version": "rad-regulatory-ledger-v1",
        "generated_from": str(root),
        "findings_file": str(args.findings),
        "pages_scanned_non_fail": pages_scanned,
        "pages_with_claims": pages_with_claims,
        "total_claims": len(ledger),
        "all_review_required": all(r["regulatory_status"] == "REVIEW_REQUIRED" for r in ledger),
        "material_discrepancy_flags": sum(1 for r in ledger if r["material_discrepancy_flag"]),
        "claims_with_official_reference": sum(
            1 for r in ledger if r["official_findings_linked"] or r["reference_official_finding"]),
        "per_destination_type": {f"{d}:{t}": n for (d, t), n in sorted(dist.items())},
        "ledger_sha256": hashlib.sha256(ledger_path.read_bytes()).hexdigest(),
        "official_findings_sha256": hashlib.sha256(
            pathlib.Path(args.findings).read_bytes()).hexdigest(),
        "notes": [
            "Every claim preserves verbatim source wording; nothing was rewritten or invented.",
            "official_findings_linked on contradicting pathways sets material_discrepancy_flag; "
            "the claim is NOT auto-rejected — it is escalated for human review.",
            "REGULATORY_LEDGER rows are derived data; they never flow to feed_items.",
        ],
    }
    (out / "REGULATORY_LEDGER_SUMMARY.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in summary.items()
                      if k not in ("per_destination_type", "notes")}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
