"""Deterministic technical and editorial flags, never factual/approval automation."""

import datetime as dt
import re
from collections import Counter
from urllib.parse import urlsplit

from .parser import HOSTS, search_normalize


def assess_source(source, as_of="2026-10-24"):
    errors = []
    warnings = []
    body = source["body_text"]
    blocks = source["blocks"]
    if not source["url"] or urlsplit(source["url"]).hostname not in HOSTS:
        errors.append("source_url_missing_or_out_of_scope")
    if not body:
        errors.append("body_unavailable")
    if source.get("article_body_assessment") in (
        "soft_404_not_an_article",
        "thin_or_metadata_only_body",
    ):
        errors.append(source["article_body_assessment"])
    if re.search(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", body):
        errors.append("unsupported_control_character")
    if source["body_status"] != "complete_source_container":
        errors.append("source_body_not_complete")
    if re.search(r"\blorem ipsum\b|\bTODO\b|\bFIXME\b", body, re.IGNORECASE):
        errors.append("placeholder_text")
    if search_normalize(body) in ["coming soon", "به زودی", "در حال تکمیل"]:
        errors.append("placeholder_text")
    if not any(b["type"] == "heading" for b in blocks):
        warnings.append("no_source_headings")
    repeats = Counter(
        search_normalize(b["text"]) for b in blocks if len(b["text"]) > 80
    )
    duplicate_blocks = sum(n - 1 for n in repeats.values() if n > 1)
    if duplicate_blocks:
        warnings.append("duplicate_source_blocks_require_review")
    if source["language"] not in ("fa", "en"):
        errors.append("unsupported_or_unknown_language")
    if "html_language_disagrees_with_body" in source["parser_warnings"]:
        warnings.append("language_consistency_review")
    warnings.extend(source["parser_warnings"])
    for evidence in source["date_evidence"]:
        value = evidence["value"]
        # Preserve Jalali/ambiguous strings; do not manufacture Gregorian dates or timezones.
        if re.match(r"^\d{4}-\d{2}-\d{2}", value):
            try:
                date = dt.date.fromisoformat(value[:10])
                if (
                    date.year >= 1900
                    and (dt.date.fromisoformat(as_of) - date).days > 548
                ):
                    warnings.append("old_evidenced_page_date_requires_review")
            except ValueError:
                warnings.append("malformed_source_date")
        else:
            warnings.append("ambiguous_source_date_preserved_without_conversion")
    numbers = sorted(set(re.findall(r"\d+(?:[.,/]\d+)*", search_normalize(body))))
    if numbers:
        warnings.append("unverified_numeric_or_date_mentions")
    if source["taxonomy"]["country_disagreement"]:
        warnings.append("country_title_url_disagreement")
    refs = source.get("body_links", [])
    return {
        "blocking_errors": sorted(set(errors)),
        "warnings": sorted(set(warnings)),
        "duplicate_block_count": duplicate_blocks,
        "source_reference_count": len(refs),
        "external_references_unverified": sum(
            urlsplit(r["url"]).hostname not in HOSTS for r in refs
        ),
        "link_target_validation": "internal_fetch_dispositions_only_external_targets_not_certified",
        "numeric_date_mentions_unverified": numbers,
        "verified_claims": 0,
        "human_review_required": True,
        "publication_allowed": False,
        "editorial_ready": False,
    }


def assess_references(sources):
    """Resolve internal references against observed dispositions, without network."""
    targets = {s["url"]: s for s in sources}
    for s in sources:
        if s["resolved_url"] and s["fetch_status"] == "fetched":
            targets.setdefault(s["resolved_url"], s)
    for s in sources:
        checks = []
        for ref in s["body_links"]:
            target = targets.get(ref["url"])
            if urlsplit(ref["url"]).hostname not in HOSTS:
                status = "external_target_not_verified"
            elif target is None:
                status = "internal_target_not_discovered"
            elif target["http_status"] in (404, 410):
                status = "broken_internal_reference"
            elif target["fetch_status"] == "fetched":
                status = "retrieved_internal_target_not_factual_verification"
            else:
                status = "internal_target_" + target["fetch_status"]
            checks.append({**ref, "target_status": status})
        s["reference_validation"] = checks
        if any(c["target_status"] == "broken_internal_reference" for c in checks):
            s["quality"]["warnings"] = sorted(
                set(s["quality"]["warnings"] + ["broken_internal_reference"])
            )
