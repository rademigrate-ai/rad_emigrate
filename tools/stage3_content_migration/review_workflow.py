#!/usr/bin/env python3
"""Local-only editorial review exchange with validation and audit history.

The tool deliberately cannot write to Supabase or mark content publishable.

Examples:
  python review_workflow.py export --out artifacts/review_exchange
  python review_workflow.py import-decisions \
      --exchange artifacts/review_exchange \
      --input reviewer-decisions.jsonl

The exported JSONL is suitable for a spreadsheet/JSON editor. Reviewers update
only the ``decision`` object and return the file for import. Import is
all-or-nothing: every row is validated before any local state is replaced.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import tempfile
from typing import Any, Iterable


SCHEMA_VERSION = "rad-editorial-review-exchange-v1"
DECISION_SCHEMA_VERSION = "rad-editorial-review-decision-v1"
ALLOWED_STATUSES = {
    "unreviewed",
    "in_review",
    "needs_research",
    "approved",
    "rejected",
    "unresolved",
}
FINAL_STATUSES = {"approved", "rejected", "unresolved"}
HTTPS_RE = re.compile(r"^https://[^\s]+$", re.IGNORECASE)


def _jsonl(path: pathlib.Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        value = json.loads(line)
        if not isinstance(value, dict):
            raise ValueError(f"{path}:{number}: expected a JSON object")
        rows.append(value)
    return rows


def _canonical_json(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: pathlib.Path) -> str:
    return _sha256_bytes(path.read_bytes())


def _record_sha256(record: dict[str, Any]) -> str:
    return _sha256_bytes(_canonical_json(record))


def _write_jsonl_atomic(path: pathlib.Path, rows: Iterable[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", newline="\n", dir=path.parent, delete=False
    ) as handle:
        temp = pathlib.Path(handle.name)
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temp, path)


def _write_json_atomic(path: pathlib.Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", newline="\n", dir=path.parent, delete=False
    ) as handle:
        temp = pathlib.Path(handle.name)
        handle.write(data)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temp, path)


def _url_group_index(duplicate_map: dict[str, Any]) -> tuple[dict[str, str], dict[str, list[str]]]:
    index: dict[str, str] = {}
    members: dict[str, list[str]] = {}
    for group in duplicate_map.get("groups", []):
        group_id = group.get("group_id")
        urls = [member.get("url") for member in group.get("members", [])]
        urls = [url for url in urls if isinstance(url, str) and url]
        if not isinstance(group_id, str) or not group_id:
            continue
        members[group_id] = urls
        for url in urls:
            index[url] = group_id
    return index, members


def _official_index(findings: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        row["id"]: row
        for row in findings.get("findings", [])
        if isinstance(row, dict) and isinstance(row.get("id"), str)
    }


def _claim_export(
    row: dict[str, Any],
    url_groups: dict[str, str],
    group_members: dict[str, list[str]],
    official: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    reference = row.get("official_reference")
    finding = official.get(reference) if isinstance(reference, str) else None
    official_urls = list((finding or {}).get("official_urls") or [])
    discrepancy = None
    if row.get("material_discrepancy_flag"):
        if finding:
            discrepancy = (
                f"Claim is flagged for comparison with official finding {reference} "
                f"({finding.get('verification_state', 'state unknown')}): "
                f"{finding.get('facts', 'no official finding summary supplied')}"
            )
        else:
            discrepancy = (
                "Claim is marked as a material discrepancy, but its referenced "
                "official finding is absent; research is required before disposition."
            )
    elif finding:
        discrepancy = (
            f"High-risk claim requires disposition against official finding {reference}: "
            f"{finding.get('facts', 'no official finding summary supplied')}"
        )

    source_url = row.get("url")
    source_claim_id = row.get("claim_id")
    occurrence_suffix = _sha256_bytes(
        f"{source_url or ''}|{row.get('claim_text') or ''}".encode("utf-8")
    )[:12]
    occurrence_id = f"{source_claim_id}:{occurrence_suffix}"
    duplicate_group = url_groups.get(source_url)
    evidence_urls = [source_url] if isinstance(source_url, str) and source_url else []
    item = {
        "schema_version": SCHEMA_VERSION,
        "item_type": "regulatory_claim",
        # Ledger claim_id values identify wording and may legitimately recur
        # on multiple pages. Decisions target a stable source occurrence.
        "item_id": occurrence_id,
        "priority": row.get("priority"),
        "identical_ledger_occurrences": 1,
        "duplicate_group_id": duplicate_group,
        "duplicate_source_urls": group_members.get(duplicate_group, evidence_urls),
        "source": {
            "site": row.get("site"),
            "page_title": row.get("page_title"),
            "evidence_urls": evidence_urls,
        },
        "claim": {
            "source_claim_id": source_claim_id,
            "type": row.get("claim_type"),
            "text": row.get("claim_text"),
            "wording": row.get("claim_wording"),
            "destinations": row.get("destinations") or [],
        },
        "official_evidence": {
            "finding_id": reference,
            "urls": official_urls,
            "summary": (finding or {}).get("facts"),
            "verification_state": (finding or {}).get("verification_state"),
        },
        "discrepancy_description": discrepancy,
        "decision": _blank_decision(),
        "safety": _safety(row.get("regulatory_status")),
    }
    item["source_record_sha256"] = _record_sha256(
        {key: value for key, value in item.items() if key not in {"decision", "source_record_sha256"}}
    )
    return item


def _visa_export(row: dict[str, Any]) -> dict[str, Any]:
    official_findings = row.get("official_findings") or []
    official_urls = sorted(
        {
            url
            for finding in official_findings
            if isinstance(finding, dict)
            for url in finding.get("official_urls", [])
            if isinstance(url, str)
        }
    )
    discrepancy_findings = [
        finding
        for finding in official_findings
        if isinstance(finding, dict)
        and finding.get("verification_state") in {"contradicted", "discrepancy"}
    ]
    descriptions = [
        f"{finding.get('id')}: {finding.get('facts', 'no summary supplied')}"
        for finding in discrepancy_findings
    ]
    item = {
        "schema_version": SCHEMA_VERSION,
        "item_type": "visa_draft",
        "item_id": row.get("program_slug"),
        "priority": row.get("priority"),
        "duplicate_group_id": None,
        "duplicate_source_urls": [],
        "source": {
            "site": None,
            "page_title": row.get("title"),
            "evidence_urls": row.get("evidence_urls") or [],
        },
        "claim": {
            "type": "visa_draft",
            "text": row.get("title"),
            "wording": "draft_catalogue_entry",
            "destinations": [row.get("destination")],
            "category": row.get("category"),
        },
        "official_evidence": {
            "finding_id": None,
            "urls": official_urls,
            "summary": None,
            "verification_state": None,
        },
        "discrepancy_description": " | ".join(descriptions) or None,
        "decision": _blank_decision(),
        "safety": _safety(row.get("regulatory_status")),
    }
    item["source_record_sha256"] = _record_sha256(
        {key: value for key, value in item.items() if key not in {"decision", "source_record_sha256"}}
    )
    return item


def _blank_decision() -> dict[str, Any]:
    return {
        "schema_version": DECISION_SCHEMA_VERSION,
        "status": "unreviewed",
        "reviewer": None,
        "reviewed_at": None,
        "rationale": None,
        "evidence_checked": [],
        "official_evidence_checked": [],
        "proposed_correction": None,
    }


def _safety(regulatory_status: Any) -> dict[str, Any]:
    return {
        "source_regulatory_status": regulatory_status,
        "production_write_allowed": False,
        "automatic_approval_allowed": False,
        "publication_allowed": False,
    }


def export_exchange(args: argparse.Namespace) -> int:
    regulatory = _jsonl(pathlib.Path(args.regulatory_queue))
    visa = _jsonl(pathlib.Path(args.visa_queue))
    duplicate_map = json.loads(pathlib.Path(args.duplicate_map).read_text(encoding="utf-8"))
    findings = json.loads(pathlib.Path(args.official_findings).read_text(encoding="utf-8"))
    url_groups, group_members = _url_group_index(duplicate_map)
    official = _official_index(findings)

    priorities = set(args.priority)
    rows = [
        _claim_export(row, url_groups, group_members, official)
        for row in regulatory
        if row.get("priority") in priorities
    ]
    rows.extend(
        _visa_export(row) for row in visa if row.get("priority") in priorities
    )
    # The historical ledger can contain byte-identical sentence occurrences
    # from repeated markup on one source page. They are indistinguishable as
    # review targets, so collapse them while retaining an auditable count.
    consolidated: dict[tuple[str, str], dict[str, Any]] = {}
    for row in rows:
        identity = (row["item_type"], row["item_id"])
        if identity not in consolidated:
            consolidated[identity] = row
            continue
        existing = consolidated[identity]
        existing["identical_ledger_occurrences"] = (
            existing.get("identical_ledger_occurrences", 1) + 1
        )
        existing["source_record_sha256"] = _record_sha256(
            {
                key: value
                for key, value in existing.items()
                if key not in {"decision", "source_record_sha256"}
            }
        )
    rows = list(consolidated.values())
    rows.sort(key=lambda row: (row["item_type"], str(row["item_id"])))
    ids = [(row["item_type"], row["item_id"]) for row in rows]
    if len(ids) != len(set(ids)):
        raise ValueError("export contains duplicate item_type/item_id identities")

    out = pathlib.Path(args.out)
    export_path = out / "P0_REVIEW_EXPORT.jsonl"
    _write_jsonl_atomic(export_path, rows)
    manifest = {
        "schema_version": SCHEMA_VERSION,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "scope": {"priorities": sorted(priorities), "production_writes": 0},
        "counts": {
            "total": len(rows),
            "regulatory_claims": sum(r["item_type"] == "regulatory_claim" for r in rows),
            "visa_drafts": sum(r["item_type"] == "visa_draft" for r in rows),
            "duplicate_grouped": sum(bool(r["duplicate_group_id"]) for r in rows),
        },
        "inputs": {
            "regulatory_queue": _sha256_file(pathlib.Path(args.regulatory_queue)),
            "visa_queue": _sha256_file(pathlib.Path(args.visa_queue)),
            "duplicate_map": _sha256_file(pathlib.Path(args.duplicate_map)),
            "official_findings": _sha256_file(pathlib.Path(args.official_findings)),
        },
        "export": {"file": export_path.name, "sha256": _sha256_file(export_path)},
        "safety": {
            "automatic_approval": False,
            "automatic_publication": False,
            "production_writes": 0,
        },
    }
    _write_json_atomic(out / "REVIEW_EXPORT_MANIFEST.json", manifest)
    print(json.dumps(manifest["counts"], sort_keys=True))
    return 0


def _parse_timestamp(value: Any, field: str) -> dt.datetime:
    if not isinstance(value, str) or not value:
        raise ValueError(f"{field} must be a non-empty ISO-8601 timestamp")
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ValueError(f"{field} must be a valid ISO-8601 timestamp") from error
    if parsed.tzinfo is None:
        raise ValueError(f"{field} must include a timezone")
    return parsed


def validate_decision_row(
    row: dict[str, Any], source: dict[str, Any]
) -> dict[str, Any]:
    errors: list[str] = []
    for key in ("schema_version", "item_type", "item_id", "source_record_sha256", "decision"):
        if key not in row:
            errors.append(f"missing {key}")
    if row.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    for key in ("item_type", "item_id", "source_record_sha256"):
        if row.get(key) != source.get(key):
            errors.append(f"{key} does not match the exported source record")
    decision = row.get("decision")
    if not isinstance(decision, dict):
        errors.append("decision must be an object")
        decision = {}
    if decision.get("schema_version") != DECISION_SCHEMA_VERSION:
        errors.append(f"decision.schema_version must be {DECISION_SCHEMA_VERSION}")
    status = decision.get("status")
    if status not in ALLOWED_STATUSES:
        errors.append(f"decision.status must be one of {sorted(ALLOWED_STATUSES)}")

    reviewer = decision.get("reviewer")
    reviewed_at = decision.get("reviewed_at")
    rationale = decision.get("rationale")
    if status != "unreviewed":
        if not isinstance(reviewer, dict):
            errors.append("decision.reviewer is required after review begins")
        else:
            if not isinstance(reviewer.get("id"), str) or not reviewer["id"].strip():
                errors.append("decision.reviewer.id is required")
            if not isinstance(reviewer.get("display_name"), str) or not reviewer["display_name"].strip():
                errors.append("decision.reviewer.display_name is required")
        try:
            _parse_timestamp(reviewed_at, "decision.reviewed_at")
        except ValueError as error:
            errors.append(str(error))
    elif reviewer is not None or reviewed_at is not None:
        errors.append("unreviewed decisions cannot carry reviewer attribution")

    if status in FINAL_STATUSES | {"needs_research"}:
        if not isinstance(rationale, str) or len(rationale.strip()) < 10:
            errors.append("final/needs_research decisions require a rationale of at least 10 characters")

    for field in ("evidence_checked", "official_evidence_checked"):
        urls = decision.get(field)
        if not isinstance(urls, list) or any(
            not isinstance(url, str) or not HTTPS_RE.match(url) for url in (urls or [])
        ):
            errors.append(f"decision.{field} must be a list of HTTPS URLs")

    source_urls = set(source.get("source", {}).get("evidence_urls") or [])
    official_urls = set(source.get("official_evidence", {}).get("urls") or [])
    checked = set(decision.get("evidence_checked") or [])
    official_checked = set(decision.get("official_evidence_checked") or [])
    if not checked.issubset(source_urls):
        errors.append("decision.evidence_checked contains a URL outside the export")
    if not official_checked.issubset(official_urls):
        errors.append("decision.official_evidence_checked contains a URL outside the export")
    if status == "approved" and not official_checked:
        errors.append("approved decisions require at least one exported official URL to be checked")

    correction = decision.get("proposed_correction")
    if correction is not None and (not isinstance(correction, str) or not correction.strip()):
        errors.append("decision.proposed_correction must be null or non-empty text")
    if errors:
        raise ValueError("; ".join(errors))

    normalized = {
        "schema_version": DECISION_SCHEMA_VERSION,
        "item_type": source["item_type"],
        "item_id": source["item_id"],
        "source_record_sha256": source["source_record_sha256"],
        "status": status,
        "reviewer": reviewer,
        "reviewed_at": reviewed_at,
        "rationale": rationale.strip() if isinstance(rationale, str) else None,
        "evidence_checked": sorted(checked),
        "official_evidence_checked": sorted(official_checked),
        "proposed_correction": correction.strip() if isinstance(correction, str) else None,
        "safety": {
            "production_write_allowed": False,
            "publication_allowed": False,
            "requires_separate_authorized_import": True,
        },
    }
    normalized["decision_sha256"] = _record_sha256(normalized)
    return normalized


def import_decisions(args: argparse.Namespace) -> int:
    exchange = pathlib.Path(args.exchange)
    manifest_path = exchange / "REVIEW_EXPORT_MANIFEST.json"
    export_path = exchange / "P0_REVIEW_EXPORT.jsonl"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != SCHEMA_VERSION:
        raise ValueError("unsupported review export manifest schema")
    expected_hash = manifest.get("export", {}).get("sha256")
    if _sha256_file(export_path) != expected_hash:
        raise ValueError("review export hash differs from its manifest")

    sources = {
        (row["item_type"], row["item_id"]): row for row in _jsonl(export_path)
    }
    incoming_rows = _jsonl(pathlib.Path(args.input))
    normalized: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []
    seen: set[tuple[str, str]] = set()
    for number, row in enumerate(incoming_rows, 1):
        identity = (row.get("item_type"), row.get("item_id"))
        source = sources.get(identity)
        if identity in seen:
            errors.append({"line": number, "item": identity, "error": "duplicate decision row"})
            continue
        seen.add(identity)
        if source is None:
            errors.append({"line": number, "item": identity, "error": "item is outside this export"})
            continue
        try:
            normalized.append(validate_decision_row(row, source))
        except ValueError as error:
            errors.append({"line": number, "item": identity, "error": str(error)})
    if errors:
        report = {
            "schema_version": DECISION_SCHEMA_VERSION,
            "accepted": False,
            "errors": errors,
            "production_writes": 0,
        }
        _write_json_atomic(exchange / "DECISION_IMPORT_REPORT.json", report)
        print(json.dumps(report, ensure_ascii=False))
        return 2

    current_path = exchange / "CURRENT_DECISIONS.jsonl"
    current = {}
    if current_path.exists():
        current = {
            (row["item_type"], row["item_id"]): row for row in _jsonl(current_path)
        }
    audit_path = exchange / "REVIEW_AUDIT.jsonl"
    audit = _jsonl(audit_path) if audit_path.exists() else []
    imported_at = dt.datetime.now(dt.timezone.utc).isoformat()
    changed = 0
    for row in normalized:
        identity = (row["item_type"], row["item_id"])
        prior = current.get(identity)
        if prior and prior.get("decision_sha256") == row["decision_sha256"]:
            continue
        event = {
            "schema_version": "rad-editorial-review-audit-v1",
            "event_id": _sha256_bytes(
                _canonical_json(
                    {
                        "identity": identity,
                        "prior": (prior or {}).get("decision_sha256"),
                        "new": row["decision_sha256"],
                    }
                )
            ),
            "recorded_at": imported_at,
            "item_type": row["item_type"],
            "item_id": row["item_id"],
            "previous_status": (prior or {}).get("status"),
            "new_status": row["status"],
            "reviewer": row["reviewer"],
            "previous_decision_sha256": (prior or {}).get("decision_sha256"),
            "decision_sha256": row["decision_sha256"],
            "production_write": False,
        }
        if not any(existing.get("event_id") == event["event_id"] for existing in audit):
            audit.append(event)
        current[identity] = row
        changed += 1

    current_rows = sorted(current.values(), key=lambda row: (row["item_type"], row["item_id"]))
    _write_jsonl_atomic(current_path, current_rows)
    _write_jsonl_atomic(audit_path, audit)
    _write_jsonl_atomic(
        exchange / "REJECTED_OR_UNRESOLVED.jsonl",
        [row for row in current_rows if row["status"] in {"rejected", "unresolved", "needs_research"}],
    )
    report = {
        "schema_version": DECISION_SCHEMA_VERSION,
        "accepted": True,
        "received": len(incoming_rows),
        "changed": changed,
        "current_decisions": len(current_rows),
        "status_counts": {
            status: sum(row["status"] == status for row in current_rows)
            for status in sorted(ALLOWED_STATUSES)
        },
        "audit_events": len(audit),
        "production_writes": 0,
        "publication_actions": 0,
    }
    _write_json_atomic(exchange / "DECISION_IMPORT_REPORT.json", report)
    print(json.dumps(report, sort_keys=True))
    return 0


def parser() -> argparse.ArgumentParser:
    repo = pathlib.Path(__file__).resolve().parents[2]
    review = repo / "artifacts" / "stage3_review_queues_20261012"
    regulatory = repo / "artifacts" / "stage3_regulatory_verification_20261011"
    canonical = repo / "artifacts" / "stage3_canonical_dataset_20261011"
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="command", required=True)
    export = sub.add_parser("export", help="create a validated reviewer exchange")
    export.add_argument("--regulatory-queue", default=review / "REGULATORY_REVIEW_QUEUE.jsonl")
    export.add_argument("--visa-queue", default=review / "VISA_DRAFT_REVIEW_QUEUE.jsonl")
    export.add_argument("--duplicate-map", default=canonical / "DUPLICATE_CANONICAL_MAP.json")
    export.add_argument("--official-findings", default=regulatory / "OFFICIAL_SOURCE_FINDINGS_20261011.json")
    export.add_argument("--priority", action="append", default=["P0_disposition_required"])
    export.add_argument("--out", required=True)
    export.set_defaults(func=export_exchange)
    imp = sub.add_parser("import-decisions", help="validate and record returned decisions")
    imp.add_argument("--exchange", required=True)
    imp.add_argument("--input", required=True)
    imp.set_defaults(func=import_decisions)
    return ap


def main() -> int:
    args = parser().parse_args()
    try:
        return args.func(args)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"accepted": False, "error": str(error), "production_writes": 0}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
