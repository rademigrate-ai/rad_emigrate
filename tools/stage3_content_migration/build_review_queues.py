#!/usr/bin/env python3
"""Step 7 — risk-prioritized editorial review packages.

Inputs:
  --ledger      REGULATORY_LEDGER.jsonl (verbatim claims, flat rows)
  --findings    OFFICIAL_SOURCE_FINDINGS_20261011.json
  --visa-coverage   VISA_COVERAGE_REPORT.json
  --visa-package    VISA_INITIALIZATION_PACKAGE.json
  --out         output dir

Outputs:
  REGULATORY_REVIEW_QUEUE.jsonl  - every flagged claim, prioritized P0/P1/P2
  VISA_DRAFT_REVIEW_QUEUE.jsonl  - all 165 visa drafts, prioritized
  REVIEW_QUEUE_SUMMARY.md        - counts, methodology, top items

Priority rules (deterministic):
  P0  material discrepancy against an official source, OR high-risk claim
      type (fee / processing time / guarantee / eligibility-rule / visa-
      existence) that IS officially referenced (needs disposition first)
  P1  high-risk claim type without official reference (needs research)
  P2  all remaining claims (routine editorial pass)

Every row keeps regulatory_status=REVIEW_REQUIRED. No approvals, no writes.
"""
import argparse
import collections
import json
import pathlib
import re

HIGH_RISK_TYPES = {
    "fee", "fees", "cost", "processing_time", "guarantee", "success_rate",
    "eligibility", "visa_existence", "government_policy", "deadline",
    "work_rights", "admission_requirement",
    # actual ledger vocabulary:
    "timeline",            # processing/entry timelines — the classic
                           # "outdated claim" surface
    "program_existence",   # "does this visa/route exist" claims
}

# Within a tier, order by blast radius: false promises first, then money,
# eligibility, existence, rights, timing.
TYPE_RANK = {"guarantee": 0, "fee": 1, "eligibility": 2,
             "program_existence": 3, "work_rights": 4, "timeline": 5}


def load_jsonl(p):
    return [json.loads(l) for l in
            pathlib.Path(p).read_text(encoding="utf-8").splitlines() if l.strip()]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger", required=True)
    ap.add_argument("--findings", required=True)
    ap.add_argument("--visa-coverage", required=True)
    ap.add_argument("--visa-package", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)

    ledger = load_jsonl(a.ledger)
    findings = json.loads(pathlib.Path(a.findings).read_text(encoding="utf-8"))
    coverage = json.loads(pathlib.Path(a.visa_coverage).read_text(encoding="utf-8"))
    package = json.loads(pathlib.Path(a.visa_package).read_text(encoding="utf-8"))

    dest_findings = collections.defaultdict(list)
    for f in findings.get("findings", []):
        dest_findings[f.get("destination")].append(f)

    # ---- regulatory queue ----
    queue = []
    tier_counts = collections.Counter()
    type_counts = collections.Counter()
    for row in ledger:
        ctype = (row.get("claim_type") or "").lower()
        type_counts[ctype] += 1
        flagged = bool(row.get("material_discrepancy_flag"))
        has_official = bool(row.get("official_findings_linked") or
                            row.get("reference_official_finding"))
        high_risk = ctype in HIGH_RISK_TYPES or any(
            k in ctype for k in ("fee", "process", "guarante", "eligib",
                                 "visa", "deadline", "right"))
        if flagged or (high_risk and has_official):
            tier = "P0_disposition_required"
        elif high_risk:
            tier = "P1_research_needed"
        else:
            tier = "P2_routine_editorial"
        tier_counts[tier] += 1
        queue.append({
            "priority": tier,
            "claim_id": row.get("claim_id"),
            "site": row.get("site"),
            "url": row.get("url"),
            "page_title": row.get("page_title"),
            "claim_type": ctype,
            "claim_text": row.get("claim_text"),
            "claim_wording": row.get("claim_wording"),
            "destinations": row.get("destinations"),
            "material_discrepancy_flag": flagged,
            "verification_state": row.get("verification_state"),
            "official_reference": row.get("reference_official_finding"),
            "requires_human_approval": True,
            "regulatory_status": "REVIEW_REQUIRED",
            "auto_approved": False,
        })
    prio_order = {"P0_disposition_required": 0, "P1_research_needed": 1,
                  "P2_routine_editorial": 2}
    queue.sort(key=lambda r: (prio_order[r["priority"]],
                              TYPE_RANK.get(r["claim_type"], 9),
                              r.get("claim_id") or ""))
    with open(out / "REGULATORY_REVIEW_QUEUE.jsonl", "w",
              encoding="utf-8", newline="\n") as f:
        for r in queue:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    # ---- visa draft queue ----
    cov_by_key = {(r["destination"], r["category"]): r
                  for r in coverage.get("rows", [])}
    loc_by_slug = {l["program_slug"]: l
                   for l in package.get("visa_program_localizations", [])}
    vqueue = []
    v_counts = collections.Counter()
    for prog in package.get("visa_programs", []):
        slug = prog["slug"]
        dest = prog["destination_slug"].upper()
        cat = prog["category_slug"].replace("-", "_")
        cov = cov_by_key.get((dest, cat), {})
        has_official = bool(cov.get("official_findings"))
        discrepancy_dest = any(
            f.get("verification_state") in ("contradicted", "discrepancy")
            for f in dest_findings.get(dest, []))
        invest_like = cat in ("invest", "business")
        if discrepancy_dest or (invest_like and has_official):
            tier = "P0_disposition_required"
        elif not has_official:
            tier = "P1_research_needed"
        else:
            tier = "P2_routine_editorial"
        v_counts[tier] += 1
        vqueue.append({
            "priority": tier,
            "program_slug": slug,
            "destination": dest,
            "category": cat,
            "title": (loc_by_slug.get(slug) or {}).get("title"),
            "primary_source_url": prog.get("primary_source_url"),
            "evidence_urls": cov.get("evidence_urls", []),
            "evidence_pass_pages": cov.get("pass", 0),
            "official_findings": cov.get("official_findings", []),
            "coverage_tier": cov.get("tier"),
            "status_in_package": prog.get("status"),
            "requires_human_approval": True,
            "regulatory_status": "REVIEW_REQUIRED",
            "auto_approved": False,
        })
    vqueue.sort(key=lambda r: (prio_order[r["priority"]], r["program_slug"]))
    with open(out / "VISA_DRAFT_REVIEW_QUEUE.jsonl", "w",
              encoding="utf-8", newline="\n") as f:
        for r in vqueue:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    summary = {
        "schema_version": "rad-review-queues-v1",
        "regulatory": {
            "total_claims": len(queue),
            "priorities": dict(tier_counts),
            "top_claim_types": dict(type_counts.most_common(12)),
            "all_review_required": True,
            "auto_approved": 0,
        },
        "visa_drafts": {
            "total": len(vqueue),
            "priorities": dict(v_counts),
            "all_status_draft": True,
            "auto_approved": 0,
        },
        "risk_rules": [
            "P0: material discrepancy vs official source, or high-risk claim "
            "type (fees/processing/guarantees/eligibility/visa-existence/"
            "deadlines/work-rights) with an official reference to disposition",
            "P1: high-risk claim type without official reference (research "
            "required before any editorial pass)",
            "P2: routine editorial pass",
            "Visa P0: destination has contradicted/discrepant official "
            "findings, or invest/business drafts with official findings",
        ],
        "writes_performed": 0,
    }
    (out / "REVIEW_QUEUE_SUMMARY.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")

    md = [
        "# Editorial Review Queues — Stage 3 (2026-10-12)",
        "",
        "All items are **REVIEW_REQUIRED**; nothing was approved or published.",
        "",
        "## Regulatory claims (%d)" % len(queue),
        "",
    ]
    for k in ("P0_disposition_required", "P1_research_needed",
              "P2_routine_editorial"):
        md.append(f"- {k}: **{tier_counts.get(k, 0)}**")
    md += ["", "## Visa drafts (%d)" % len(vqueue), ""]
    for k in ("P0_disposition_required", "P1_research_needed",
              "P2_routine_editorial"):
        md.append(f"- {k}: **{v_counts.get(k, 0)}**")
    md += [
        "",
        "## How to work the queues",
        "",
        "1. Start with P0: each row carries the verbatim claim, source URL,",
        "   flag and the official finding it conflicts with; the reviewer",
        "   records disposition (uphold source wording / mark outdated /",
        "   reject) — the tooling never decides.",
        "2. P1 needs official-source research before an editorial decision.",
        "3. P2 is a routine pass; duplicates within a page can be batched.",
        "4. Visa drafts additionally need program-level verification against",
        "   official sources before promotion to knowledge/review workflows.",
        "",
    ]
    (out / "REVIEW_QUEUE_SUMMARY.md").write_text("\n".join(md),
                                                 encoding="utf-8")
    print(json.dumps({"regulatory": len(queue), "priors": dict(tier_counts),
                      "visa": len(vqueue), "visa_priors": dict(v_counts)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
