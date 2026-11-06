"""Read-only, hash-bound disposition of an existing Production Visa package.

This report is neither an import receipt nor an editorial approval. It consumes
the existing package without rewriting its seals, decisions or source material.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
from typing import Any

from scripts.production_reconciliation_package import read_rows, validate_package


def file_sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def compare_production_heads(
    baseline: list[dict[str, Any]], readback: dict[str, Any]
) -> dict[str, Any]:
    if readback.get("project_id") != "inshddthftkhcdosoqcn":
        raise ValueError("production_readback_target_mismatch")
    current = {}
    for row in readback["head_bindings"]:
        key = (row["article_id"], row["locale"])
        if key in current:
            raise ValueError("production_readback_duplicate_head")
        current[key] = row
    fields = (
        "head_id",
        "published_id",
        "revision",
        "body_md5",
        "actor_id_md5",
        "title_summary_md5",
        "stored_content_hash",
        "created_at",
    )
    differences = []
    for row in baseline:
        key = (row["article_id"], row["locale"])
        actual = current.get(key, {})
        changed = [field for field in fields if row[field] != actual.get(field)]
        if changed:
            differences.append(
                {"article_id": key[0], "locale": key[1], "fields": changed}
            )
    return {
        "status": "PASS_PRESERVED_BASELINE_HEADS"
        if not differences
        else "DRIFT_DETECTED",
        "observed_at": readback["observed_at"],
        "baseline_heads_checked": len(baseline),
        "current_heads": len(current),
        "new_head_keys": len(
            set(current) - {(r["article_id"], r["locale"]) for r in baseline}
        ),
        "fields_checked": list(fields),
        "differences": differences,
        "approved_revisions_observed": readback["approved_revisions"],
        "published_heads_observed": readback["published_heads"],
        "limitation": "Supplied read-only observation; not a post-import success receipt.",
    }


def operation_outcome(operation: dict[str, Any]) -> dict[str, Any]:
    item = operation["payload"]["item"]
    case = operation.get("review_case", {})
    delta = case.get("delta", {})
    classification = delta.get("classification")
    pending = operation["action"] == "PENDING_HUMAN_RECONCILIATION"
    mechanical = (
        pending
        and classification
        in {"EXACT_ADDITIVE_ORDER_PRESERVED", "REORDER_OR_RESECTION_WITH_ADDITIONS"}
        and delta.get("unmatched_current_occurrences") == 0
        and delta.get("changed_nonsection_fields") == []
        and case.get("source_review_status") == "PASS_EXACT_MECHANICAL_SOURCE_INTEGRITY"
        and case.get("source_review_errors") == []
    )
    reconciliation = (
        "MECHANICALLY_PRESERVES_CURRENT_CONTENT_DETACHED_DRAFT_PROPOSAL"
        if mechanical
        else "SUBSTANTIVE_RECONCILIATION_HELD"
        if pending
        else operation["action"]
    )
    links = item.get("source_links", [])
    unconfirmed = sum(
        isinstance(link.get("href_evidence"), dict)
        and link["href_evidence"].get("confirmed") is False
        for link in links
    )
    other_links = sum(not isinstance(link.get("href_evidence"), dict) for link in links)
    assets = item.get("source_assets", [])
    conflicts = item.get("conflicts", [])
    holds = ["NO_REVISION_BOUND_CMS_CLEARANCE_IN_SOURCE_PACKAGE"]
    if item["verification_state"] != "verified":
        holds.append("EXISTING_CMS_FACTUAL_VERIFICATION_CONTRACT_UNSATISFIED")
    if conflicts:
        holds.append("UNRESOLVED_SOURCE_CONFLICTS")
    if pending:
        holds.append("SEALED_IMPORT_EXECUTOR_REQUIRES_BOUND_RECONCILIATION_DISPOSITION")
    codes = item["country_codes"]
    return {
        "operation_id": operation["operation_id"],
        "article_id": operation["article_id"],
        "locale": operation["locale"],
        "revision_id_proposed": operation["revision_id"],
        "payload_sha256": operation["payload_sha256"],
        "provenance_sha256": operation["provenance_sha256"],
        "sealed_import_action": operation["action"],
        "reconciliation": reconciliation,
        "current_head": (operation["expected_current"] or {}).get("head_id"),
        "country_codes": codes,
        "discovery_after_publication": "COUNTRY_CARDS" if codes else "OTHER_TITLES",
        "original_verification_state": item["verification_state"],
        "claims_requiring_evidence": sum(
            claim.get("verification_status") != "verified"
            or not claim.get("official_references")
            or not claim.get("verified_at")
            for claim in item.get("claims", [])
        ),
        "conflict_count": len(conflicts),
        "unconfirmed_links_not_proven_broken": unconfirmed,
        "links_with_other_evidence_representation": other_links,
        "media_references_to_keep_hidden": sum(
            asset.get("public_render_allowed") is not True for asset in assets
        ),
        "publication_holds": holds,
        "outcome": "HELD_PENDING_HOSTED_IMPORT_AND_CMS_RELEASE_EVIDENCE",
        "imported_by_audit": False,
        "approved_by_audit": False,
        "published_by_audit": False,
    }


def audit_package(
    package: Path,
    expected_package_sha256: str,
    input_root: Path,
    production_readback: Path | None = None,
) -> dict[str, Any]:
    plan_path = package / "plan.json"
    operations_path = package / "operations.jsonl.gz"
    plan = json.loads(plan_path.read_text(encoding="utf8"))
    if plan.get("package_sha256") != expected_package_sha256:
        raise ValueError("unexpected_package_sha256")
    operations = list(read_rows(operations_path))
    validate_package(plan, operations)
    checked_inputs = 0
    for name, expected in plan["inputs"].items():
        path = Path(name)
        if not path.is_absolute():
            path = input_root / path
        if file_sha(path) != expected:
            raise ValueError("package_input_hash_mismatch:" + name)
        checked_inputs += 1
    if not operations:
        raise ValueError("empty_operation_package")
    actions = Counter(op["action"] for op in operations)
    if dict(actions) != plan["operation_counts"]:
        raise ValueError("operation_counts_mismatch")
    outcomes = [operation_outcome(op) for op in operations]
    countries: Counter[str] = Counter()
    blocks = claims = conflicts = omissions = 0
    for op, outcome in zip(operations, outcomes, strict=True):
        item = op["payload"]["item"]
        countries.update(set(outcome["country_codes"]))
        blocks += sum(len(section["blocks"]) for section in item["sections"])
        claims += len(item.get("claims", []))
        conflicts += len(item.get("conflicts", []))
        omissions += len(item.get("omissions", []))
    result = {
        "format": "RAD_VISA_RELEASE_AUDIT_V1",
        "status": "HOLD_PRODUCTION_RELEASE",
        "package_sha256": expected_package_sha256,
        "plan_file_sha256": file_sha(plan_path),
        "operations_file_sha256": file_sha(operations_path),
        "input_files_hash_verified": checked_inputs,
        "planned_operation_count": len(outcomes),
        "planned_distinct_articles": len({o["article_id"] for o in outcomes}),
        "planned_distinct_revisions": len(
            {o["revision_id_proposed"] for o in outcomes}
        ),
        "sealed_import_actions": dict(sorted(actions.items())),
        "reconciliation_counts": dict(
            sorted(Counter(o["reconciliation"] for o in outcomes).items())
        ),
        "retained_blocks": blocks,
        "equivalent_source_segment_references": omissions,
        "claims": claims,
        "recorded_conflicts": conflicts,
        "planned_country_coverage": dict(sorted(countries.items())),
        "planned_other_titles_operations": sum(
            not o["country_codes"] for o in outcomes
        ),
        "planned_multi_country_operations": sum(
            len(o["country_codes"]) > 1 for o in outcomes
        ),
        "unconfirmed_links_not_proven_broken": sum(
            o["unconfirmed_links_not_proven_broken"] for o in outcomes
        ),
        "media_references_to_keep_hidden": sum(
            o["media_references_to_keep_hidden"] for o in outcomes
        ),
        "imported_by_audit": 0,
        "approved_by_audit": 0,
        "published_by_audit": 0,
        "held_operations": len(outcomes),
        "outcomes": outcomes,
        "limitations": [
            "Package integrity does not establish current hosted schema or row state.",
            "Current public visibility requires separate anonymous API readback.",
            "Source fidelity does not establish official factual verification.",
            "Mechanical proposals do not impersonate authenticated editorial actors.",
            "Media can remain hidden without discarding original source references.",
            "The audit performs no database, network, import, approval or Feed operation.",
        ],
    }
    if production_readback is not None:
        result["production_readback_file_sha256"] = file_sha(production_readback)
        result["production_head_comparison"] = compare_production_heads(
            plan["production_baseline"],
            json.loads(production_readback.read_text(encoding="utf8")),
        )
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--expected-package-sha256", required=True)
    parser.add_argument("--input-root", type=Path, required=True)
    parser.add_argument("--production-readback", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = audit_package(
        args.package,
        args.expected_package_sha256,
        args.input_root,
        args.production_readback,
    )
    # Exclusive creation protects prior evidence and immutable source artifacts.
    with args.output.open("x", encoding="utf8", newline="\n") as output:
        output.write(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
        output.write("\n")
    print(json.dumps({k: v for k, v in result.items() if k != "outcomes"}, indent=2))


if __name__ == "__main__":
    main()
