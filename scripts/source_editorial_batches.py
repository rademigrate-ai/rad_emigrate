"""Prepare immutable source-faithful CMS approval requests; never call a hosted API."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5

from scripts import production_reconciliation_package as original
from scripts.production_mechanical_decisions import validate_decisions
from scripts.visa_release_audit import file_sha


def has_public_media(value):
    if isinstance(value, dict):
        return value.get("public_render_allowed") is True or any(
            has_public_media(v) for v in value.values()
        )
    return isinstance(value, list) and any(has_public_media(v) for v in value)


def group_batches(entries, article_by_revision, batch_size):
    grouped = {}
    for entry in entries:
        grouped.setdefault(article_by_revision[entry["revision_id"]], []).append(entry)
    chunks = []
    members = []
    for article in sorted(grouped):
        group = grouped[article]
        if len(group) > batch_size:
            raise ValueError("batch_must_fit_all_article_locales")
        if members and len(members) + len(group) > batch_size:
            chunks.append(members)
            members = []
        members.extend(group)
    if members:
        chunks.append(members)
    return chunks


def prepare_batches(plan, operations, decisions, source_receipt, output, batch_size=25):
    if not 1 <= batch_size <= 100:
        raise ValueError("bounded_batch_size_required")
    selected = validate_decisions(plan, operations, decisions)
    proof = json.loads(source_receipt.read_text("utf8"))
    if (
        not isinstance(proof, list)
        or not proof
        or any(
            row.get("report", {}).get("composition_status") != "PASS"
            or row["report"]["missing_source_segments"] != 0
            or row["report"]["source_segments_accounted"]
            != row["report"]["eligible_source_segments"]
            for row in proof
        )
    ):
        raise ValueError("successful_source_integrity_receipt_required")
    for name, expected in plan["inputs"].items():
        if file_sha(Path(name)) != expected:
            raise ValueError("frozen_input_changed:" + name)
    by_id = {op["operation_id"]: op for op in selected}
    catalog_active = {}
    for op in selected:
        catalog_active.setdefault(op["article_id"], op["expected_current"] is None)
    dispositions = []
    entries = []
    countries = Counter()
    for op in sorted(operations, key=lambda row: row["operation_id"]):
        item = op["payload"]["item"]
        holds = []
        if op["operation_id"] not in by_id:
            holds.append("substantive_version_difference_preserve_both")
        if item.get("conflicts"):
            holds.append("unresolved_numeric_or_content_conflict")
        if has_public_media(item):
            holds.append("public_media_not_allowed_in_source_contract_v1")
        if item.get("composition_policy") != "RAD_CONTENT_PRECEDENCE_V4.1":
            holds.append("unexpected_source_policy")
        disposition = {
            "operation_id": op["operation_id"],
            "article_id": op["article_id"],
            "locale": op["locale"],
            "revision_id": op["revision_id"],
            "payload_sha256": op["payload_sha256"],
            "country_codes": item["country_codes"],
            "holds": holds,
            "status": "HELD"
            if holds
            else "PREPARED_REQUIRES_IMPORT_AND_AUTHENTICATED_SOURCE_APPROVAL",
            "verification_state": "unverified",
            "approved": False,
            "published": False,
        }
        dispositions.append(disposition)
        if holds:
            continue
        current = op["expected_current"]
        entries.append(
            {
                "revision_id": op["revision_id"],
                "expected_head_id": current["head_id"]
                if current
                else op["revision_id"],
                "expected_published_id": current["published_id"] if current else None,
                "expected_catalog_active": catalog_active[op["article_id"]],
                "activate_catalog": True,
                "payload_sha256": op["payload_sha256"],
                "payload_text": original.canonical(op["payload"]),
            }
        )
        countries.update(set(item["country_codes"]))
    output.mkdir(exist_ok=False, parents=True)
    batches = []
    article_by_revision = {op["revision_id"]: op["article_id"] for op in selected}
    chunks = group_batches(entries, article_by_revision, batch_size)
    for members in chunks:
        manifest_text = original.canonical(members)
        manifest_sha = original.digest(manifest_text)
        batch_id = str(uuid5(NAMESPACE_URL, "rad-source-editorial:" + manifest_sha))
        request = {
            "p_batch_id": batch_id,
            "p_manifest_text": manifest_text,
            "p_manifest_sha256": manifest_sha,
            "p_source_integrity_receipt_sha256": file_sha(source_receipt),
            "p_note": None,
        }
        path = output / f"batch-{len(batches):03d}.approval-request.json"
        path.write_bytes(
            (
                json.dumps(request, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
            ).encode()
        )
        batches.append(
            {
                "batch_id": batch_id,
                "members": len(members),
                "manifest_sha256": manifest_sha,
                "approval_request_file": path.name,
                "approval_request_file_sha256": file_sha(path),
                "publish_request": {
                    "p_batch_id": batch_id,
                    "p_manifest_sha256": manifest_sha,
                },
            }
        )
    report = {
        "format": "RAD_SOURCE_EDITORIAL_RELEASE_PLAN_V1",
        "status": "PREPARED_NOT_APPROVED_NOT_PUBLISHED",
        "package_sha256": plan["package_sha256"],
        "mechanical_decisions_sha256": decisions["decision_package_sha256"],
        "source_integrity_receipt_sha256": file_sha(source_receipt),
        "generator_sha256": file_sha(Path(__file__)),
        "operations": len(operations),
        "eligible_proposals": len(entries),
        "held": len(operations) - len(entries),
        "proposed_country_coverage": dict(sorted(countries.items())),
        "proposed_other_titles": sum(
            not r["country_codes"] for r in dispositions if not r["holds"]
        ),
        "batches": batches,
        "dispositions": dispositions,
        "authenticated_actor": None,
        "hosted_writes": 0,
        "approved": 0,
        "published": 0,
        "note": "Copy request templates before supplying the real Admin's note. Database eligibility is rechecked inside approval and publication; imports and deployment remain separately gated.",
    }
    (output / "release-plan.json").write_bytes(
        (
            json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
        ).encode()
    )
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--decisions", type=Path, required=True)
    parser.add_argument("--source-integrity-receipt", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--batch-size", type=int, default=25)
    args = parser.parse_args()
    report = prepare_batches(
        json.loads((args.package / "plan.json").read_text("utf8")),
        list(original.read_rows(args.package / "operations.jsonl.gz")),
        json.loads(args.decisions.read_text("utf8")),
        args.source_integrity_receipt,
        args.output,
        args.batch_size,
    )
    print(
        json.dumps(
            {
                k: report[k]
                for k in (
                    "status",
                    "operations",
                    "eligible_proposals",
                    "held",
                    "approved",
                    "published",
                )
            }
        )
    )


if __name__ == "__main__":
    main()
