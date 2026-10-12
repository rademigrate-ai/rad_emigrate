#!/usr/bin/env python3
"""Deterministically validate Visa drafts without inventing visa facts.

This validator assesses evidence structure, provenance, mapping and review
readiness. It never decides what an immigration requirement, fee or timeline
should be. Missing facts are emitted as correction tasks for a human reviewer.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import pathlib
import re
from typing import Any


SCHEMA_VERSION = "rad-visa-evidence-validation-v1"
PLACEHOLDER_MARKERS = (
    "پس از تایید منابع رسمی",
    "پس از بازبینی انسانی",
    "پیش‌نویس",
    "review_required",
    "placeholder",
    "to be verified",
)
GUARANTEE_MARKERS = (
    "guarantee",
    "guaranteed",
    "100%",
    "تضمین",
    "قطعی",
)
TIMELINE_MARKERS = ("processing", "timeline", "روز", "ماه", "هفته", "year", "month", "day")
COST_MARKERS = ("fee", "cost", "هزینه", "دلار", "یورو", "eur", "usd")


def _read(path: pathlib.Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _nonempty(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _has_marker(text: str, markers: tuple[str, ...]) -> bool:
    lowered = text.casefold()
    return any(marker.casefold() in lowered for marker in markers)


def _issue(code: str, severity: str, message: str, action: str, evidence: list[str] | None = None) -> dict[str, Any]:
    return {
        "code": code,
        "severity": severity,
        "message": message,
        "required_action": action,
        "evidence": evidence or [],
    }


def validate(
    package: dict[str, Any],
    coverage: dict[str, Any],
    review_queue: list[dict[str, Any]],
) -> dict[str, Any]:
    destinations = {row.get("slug"): row for row in package.get("destinations", [])}
    localizations: dict[str, list[dict[str, Any]]] = collections.defaultdict(list)
    requirements: dict[str, list[dict[str, Any]]] = collections.defaultdict(list)
    steps: dict[str, list[dict[str, Any]]] = collections.defaultdict(list)
    for row in package.get("visa_program_localizations", []):
        localizations[row.get("program_slug")].append(row)
    for row in package.get("visa_program_requirements", []):
        requirements[row.get("program_slug")].append(row)
    for row in package.get("visa_program_steps", []):
        steps[row.get("program_slug")].append(row)
    coverage_index = {
        (row.get("destination"), row.get("category")): row
        for row in coverage.get("rows", [])
    }
    review_index = {row.get("program_slug"): row for row in review_queue}

    seen: set[str] = set()
    results: list[dict[str, Any]] = []
    for program in package.get("visa_programs", []):
        slug = program.get("slug")
        destination_slug = program.get("destination_slug")
        category = str(program.get("category_slug") or "").replace("-", "_")
        destination = str(destination_slug or "").upper()
        issues: list[dict[str, Any]] = []
        locs = localizations.get(slug, [])
        reqs = requirements.get(slug, [])
        program_steps = steps.get(slug, [])
        cov = coverage_index.get((destination, category))
        review = review_index.get(slug)
        official_findings = (cov or {}).get("official_findings") or []
        official_urls = sorted(
            {
                url
                for finding in official_findings
                if isinstance(finding, dict)
                for url in finding.get("official_urls", [])
                if isinstance(url, str) and url.startswith("https://")
            }
        )
        evidence_urls = list((cov or {}).get("evidence_urls") or [])

        if not _nonempty(slug) or slug in seen:
            issues.append(_issue(
                "INVALID_OR_DUPLICATE_SLUG", "blocker",
                "Program slug is missing or duplicated.",
                "Assign a unique deterministic program slug.",
            ))
        if _nonempty(slug):
            seen.add(slug)
        expected_prefix = f"{destination_slug}-"
        if destination_slug not in destinations or not str(slug or "").startswith(expected_prefix):
            issues.append(_issue(
                "DESTINATION_PROGRAM_MAPPING", "blocker",
                "Program slug/destination mapping is inconsistent with the destination package.",
                "Correct the destination mapping; do not infer a destination from page wording.",
            ))
        if cov is None:
            issues.append(_issue(
                "MISSING_COVERAGE_MAPPING", "blocker",
                "No destination/category coverage row maps to this draft.",
                "Map the draft to an existing evidence pair or remove it from the candidate package.",
            ))
        if review is None:
            issues.append(_issue(
                "MISSING_REVIEW_QUEUE_ENTRY", "blocker",
                "Draft is absent from the editorial review queue.",
                "Regenerate the review queue before any import.",
            ))
        if program.get("status") != "draft" or (review and review.get("regulatory_status") != "REVIEW_REQUIRED"):
            issues.append(_issue(
                "UNSAFE_REVIEW_STATUS", "blocker",
                "Draft is not protected by draft + REVIEW_REQUIRED status.",
                "Restore draft/REVIEW_REQUIRED status; do not auto-approve.",
            ))

        primary_url = program.get("primary_source_url")
        if not _nonempty(primary_url) or not str(primary_url).startswith("https://"):
            issues.append(_issue(
                "MISSING_PRIMARY_PROVENANCE", "blocker",
                "Primary source provenance is absent or not HTTPS.",
                "Attach a captured source URL and snapshot before review.",
            ))
        elif evidence_urls and primary_url not in evidence_urls:
            issues.append(_issue(
                "PRIMARY_SOURCE_OUTSIDE_EVIDENCE", "blocker",
                "Primary source URL is not present in the coverage evidence set.",
                "Reconcile provenance against the canonical evidence set.",
                [primary_url],
            ))

        if not official_urls:
            issues.append(_issue(
                "NO_OFFICIAL_EVIDENCE", "blocker",
                "No government/authority URL is linked to this draft.",
                "Research and capture an official source before approving eligibility, requirements, cost or timing.",
            ))
        if not locs:
            issues.append(_issue(
                "MISSING_LOCALIZATION", "blocker",
                "Program has no localized title/summary/description.",
                "Add reviewed localized copy with provenance.",
            ))
        for loc in locs:
            if not _nonempty(loc.get("title")) or not _nonempty(loc.get("summary")):
                issues.append(_issue(
                    "MISSING_TITLE_OR_SUMMARY", "blocker",
                    f"Locale {loc.get('locale')} lacks a title or summary.",
                    "Add reviewed text derived from cited evidence.",
                ))
            if not _nonempty(loc.get("description")):
                issues.append(_issue(
                    "MISSING_DESCRIPTION", "blocker",
                    f"Locale {loc.get('locale')} lacks a description.",
                    "Add a sourced, reviewed description.",
                ))

        if not reqs:
            issues.append(_issue(
                "MISSING_REQUIREMENTS", "blocker",
                "No eligibility/requirement records exist.",
                "Extract requirements from official evidence and record their citations.",
            ))
        for requirement in reqs:
            text = str(requirement.get("requirement") or "")
            if _has_marker(text, PLACEHOLDER_MARKERS):
                issues.append(_issue(
                    "PLACEHOLDER_REQUIREMENT", "blocker",
                    "Requirement row is an editorial placeholder, not an immigration requirement.",
                    "Replace only after an official-source reviewer supplies the exact requirement and citation.",
                    [requirement.get("source_url")] if requirement.get("source_url") else [],
                ))
            if requirement.get("is_mandatory") is None:
                issues.append(_issue(
                    "REQUIREMENT_MANDATORY_UNRESOLVED", "warning",
                    "Requirement mandatory/optional state is unresolved.",
                    "Have a reviewer classify it from official evidence, including exceptions.",
                ))
            if requirement.get("source_url") not in official_urls:
                issues.append(_issue(
                    "REQUIREMENT_NOT_OFFICIALLY_SOURCED", "blocker",
                    "Requirement does not cite a linked official authority URL.",
                    "Link the requirement to official evidence; RAD-owned pages alone are insufficient.",
                ))

        if not program_steps:
            issues.append(_issue(
                "MISSING_STEPS", "warning",
                "No application steps are present.",
                "Add only steps confirmed by official instructions.",
            ))
        for step in program_steps:
            combined = f"{step.get('title') or ''} {step.get('description') or ''}"
            if _has_marker(combined, PLACEHOLDER_MARKERS):
                issues.append(_issue(
                    "PLACEHOLDER_STEP", "blocker",
                    "Application step is a placeholder.",
                    "Replace with reviewed official process steps or leave the section unpublished.",
                ))
            if step.get("source_url") not in official_urls:
                issues.append(_issue(
                    "STEP_NOT_OFFICIALLY_SOURCED", "blocker",
                    "Application step does not cite a linked official authority URL.",
                    "Cite an official process page for each published step.",
                ))

        text_blob = " ".join(
            str(value or "")
            for loc in locs
            for value in (loc.get("title"), loc.get("summary"), loc.get("description"))
        )
        timeline = str(program.get("processing_time_text") or "")
        fees = str(program.get("fees_text") or "")
        if timeline and not official_urls:
            issues.append(_issue(
                "UNSUPPORTED_TIMELINE", "blocker",
                "Processing timeline is present without official evidence.",
                "Remove it or cite a dated official source and record its effective date.",
            ))
        if fees and not official_urls:
            issues.append(_issue(
                "UNSUPPORTED_COST", "blocker",
                "Fee/cost is present without official evidence.",
                "Remove it or cite a dated official fee schedule and currency.",
            ))
        if _has_marker(text_blob, GUARANTEE_MARKERS):
            issues.append(_issue(
                "UNSUPPORTED_GUARANTEE", "blocker",
                "Draft contains guarantee-like wording.",
                "Remove guarantee wording unless legal/editorial reviewers document narrowly supported wording; never guarantee an outcome.",
            ))
        for finding in official_findings:
            if isinstance(finding, dict) and finding.get("verification_state") in {"contradicted", "discrepancy"}:
                issues.append(_issue(
                    "CONFLICTING_OFFICIAL_FINDING", "blocker",
                    f"Official finding {finding.get('id')} is marked {finding.get('verification_state')}.",
                    "Resolve the conflict and record the reviewer disposition before approval.",
                    [url for url in finding.get("official_urls", []) if isinstance(url, str)],
                ))

        # Facts embedded in long source excerpts need an explicit check even
        # when the structured fields are empty. This does not label them true
        # or false; it routes them to the appropriate correction task.
        if _has_marker(text_blob, TIMELINE_MARKERS) and not official_urls:
            issues.append(_issue(
                "UNVERIFIED_TIMELINE_IN_COPY", "warning",
                "Localized copy appears to mention a time period without official evidence.",
                "Review each time claim and remove or cite it.",
            ))
        if _has_marker(text_blob, COST_MARKERS) and not official_urls:
            issues.append(_issue(
                "UNVERIFIED_COST_IN_COPY", "warning",
                "Localized copy appears to mention a fee/cost without official evidence.",
                "Review each cost claim and remove or cite it with effective date/currency.",
            ))

        # Deduplicate identical issue codes generated by repeated locale rows.
        unique: dict[str, dict[str, Any]] = {}
        for issue in issues:
            unique.setdefault(issue["code"], issue)
        issues = sorted(unique.values(), key=lambda issue: (issue["severity"] != "blocker", issue["code"]))
        blockers = sum(issue["severity"] == "blocker" for issue in issues)
        results.append({
            "program_slug": slug,
            "destination": destination,
            "category": category,
            "review_status": program.get("status"),
            "official_evidence_urls": official_urls,
            "source_evidence_urls": evidence_urls,
            "issues": issues,
            "blocker_count": blockers,
            "warning_count": sum(issue["severity"] == "warning" for issue in issues),
            "validation_status": "correction_required" if blockers else "human_review_required",
            "automatic_approval": False,
            "publication_allowed": False,
        })

    issue_counts = collections.Counter(
        issue["code"] for result in results for issue in result["issues"]
    )
    return {
        "schema_version": SCHEMA_VERSION,
        "summary": {
            "drafts": len(results),
            "correction_required": sum(r["validation_status"] == "correction_required" for r in results),
            "human_review_required": sum(r["validation_status"] == "human_review_required" for r in results),
            "with_official_evidence": sum(bool(r["official_evidence_urls"]) for r in results),
            "issue_counts": dict(sorted(issue_counts.items())),
            "automatic_approvals": 0,
            "production_writes": 0,
        },
        "drafts": sorted(results, key=lambda result: str(result["program_slug"])),
    }


def main() -> int:
    repo = pathlib.Path(__file__).resolve().parents[2]
    visa_dir = repo / "artifacts" / "stage3_visa_coverage_20261011"
    review_dir = repo / "artifacts" / "stage3_review_queues_20261012"
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--package", default=visa_dir / "VISA_INITIALIZATION_PACKAGE.json")
    ap.add_argument("--coverage", default=visa_dir / "VISA_COVERAGE_REPORT.json")
    ap.add_argument("--review-queue", default=review_dir / "VISA_DRAFT_REVIEW_QUEUE.jsonl")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    package_path = pathlib.Path(args.package)
    coverage_path = pathlib.Path(args.coverage)
    queue_path = pathlib.Path(args.review_queue)
    queue = [
        json.loads(line)
        for line in queue_path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    report = validate(_read(package_path), _read(coverage_path), queue)
    report["inputs"] = {
        "package_sha256": _sha(package_path),
        "coverage_sha256": _sha(coverage_path),
        "review_queue_sha256": _sha(queue_path),
    }
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    report_path = out / "VISA_EVIDENCE_VALIDATION.json"
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    correction_path = out / "VISA_CORRECTION_QUEUE.jsonl"
    with correction_path.open("w", encoding="utf-8", newline="\n") as handle:
        for row in report["drafts"]:
            if row["issues"]:
                handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
    manifest = {
        "schema_version": SCHEMA_VERSION,
        "inputs": report["inputs"],
        "outputs": {
            report_path.name: _sha(report_path),
            correction_path.name: _sha(correction_path),
        },
        "summary": report["summary"],
        "automatic_approval": False,
        "publication_allowed": False,
        "production_writes": 0,
    }
    (out / "VISA_VALIDATION_MANIFEST.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report["summary"], ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
