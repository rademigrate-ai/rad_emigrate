"""Version corrected source payloads and rebuild batches without hosted writes.

Original generators, source captures, packages and human approvals stay intact.
This tool emits proposals and an additional publication hold guard, never approval.
"""

from __future__ import annotations

import argparse
import copy
import json
from collections import Counter
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5

from scripts import production_mechanical_decisions as mechanical
from scripts import production_reconciliation_package as original
from scripts.source_editorial_batches import group_batches, has_public_media
from scripts.visa_release_audit import file_sha
from tools.plan3_content.dataset import read_jsonl

AUTHORED = "AUTHORED_TEXT_REQUIRES_COMPLETE_BODY_PROOF"


def save(path, value):
    with path.open("x", encoding="utf8", newline="\n") as stream:
        json.dump(value, stream, ensure_ascii=False, sort_keys=True, indent=2)
        stream.write("\n")


def correct_operations(operations, proposals):
    """Accept only body-preserving AE corrections with literal bound evidence."""
    by_id = {op["operation_id"]: op for op in operations}
    replacements = {}
    for proposal in proposals:
        parent = by_id.get(proposal["original_operation_id"])
        op = proposal["proposed_operation"]
        if parent is None or parent["operation_id"] in replacements:
            raise ValueError("unique_existing_correction_parent_required")
        if parent["payload_sha256"] != proposal["original_payload_sha256"]:
            raise ValueError("correction_parent_payload_changed")
        before, after = parent["payload"], op["payload"]
        if before["sources"] != after["sources"]:
            raise ValueError("correction_must_preserve_original_sources")
        if (
            parent["expected_current"] is not None
            or op["expected_current"] is not None
            or before["item"]["country_codes"] != []
            or after["item"]["country_codes"] != ["AE"]
            or {
                k: v
                for k, v in after["item"].items()
                if k not in ("country_codes", "country_source_evidence")
            }
            != {k: v for k, v in before["item"].items() if k != "country_codes"}
        ):
            raise ValueError("only_unassigned_initial_country_metadata_may_change")
        evidence = after["item"]["country_source_evidence"]
        source = next(
            (
                s
                for s in after["sources"]
                if s.get("source_variant_id", s["source_id"])
                == evidence["source_variant_id"]
            ),
            None,
        )
        reference = evidence["geography_reference"]
        if (
            source is None
            or original.digest(source["body_text"]) != evidence["source_body_sha256"]
            or not evidence["excerpt"]
            or source["body_text"][
                evidence["start"] : evidence["start"] + len(evidence["excerpt"])
            ]
            != evidence["excerpt"]
            or reference["url"]
            != "https://www.moet.gov.ae/en/web/guest/emirates-of-the-uae"
            or file_sha(Path(reference["captured_page_asset"]))
            != reference["captured_page_sha256"]
        ):
            raise ValueError("literal_original_country_evidence_required")
        if (
            original.make_operation(
                after, parent["expected_current"], parent["operation_class"]
            )
            != op
        ):
            raise ValueError("corrected_operation_hash_binding_invalid")
        replacements[parent["operation_id"]] = op
    return [replacements.get(op["operation_id"], op) for op in operations]


def rebind_decisions(parent_plan, parent_ops, parent_decisions, plan, operations):
    mechanical.validate_decisions(parent_plan, parent_ops, parent_decisions)
    old_pending = {
        op["operation_id"]: op
        for op in parent_ops
        if op["action"] == "PENDING_HUMAN_RECONCILIATION"
    }
    new_pending = {
        op["operation_id"]: op
        for op in operations
        if op["action"] == "PENDING_HUMAN_RECONCILIATION"
    }
    if old_pending != new_pending:
        raise ValueError("changed_substantive_cases_require_new_review_evidence")
    result = copy.deepcopy(parent_decisions)
    result.pop("decision_package_sha256")
    result["parent_decision_package_sha256"] = parent_decisions[
        "decision_package_sha256"
    ]
    result["package_sha256"] = plan["package_sha256"]
    result["decision_package_sha256"] = original.digest(original.canonical(result))
    mechanical.validate_decisions(plan, operations, result)
    return result


def capture_kind_holds(op, captures):
    holds = []
    if not op["payload"]["sources"]:
        raise ValueError("original_source_capture_evidence_required")
    for source in op["payload"]["sources"]:
        variant = source.get("source_variant_id", source["source_id"])
        proof = captures.get(variant)
        raw_sha = source.get("source_evidence", {}).get(
            "captured_raw_html_sha256", source["raw_html_sha256"]
        )
        if proof is None or proof["raw_html_sha256"] != raw_sha:
            raise ValueError("exact_source_kind_capture_binding_required")
        if proof["observed_content_kind"] != AUTHORED:
            holds.append("source_kind_or_article_completeness_unresolved")
    return sorted(set(holds))


def prepare_batches(plan, operations, decisions, captures, proof_path, output):
    selected = mechanical.validate_decisions(plan, operations, decisions)
    selected_ids = {op["operation_id"] for op in selected}
    active = {}
    for op in selected:
        active.setdefault(op["article_id"], op["expected_current"] is None)
    entries, dispositions = [], []
    countries = Counter()
    for op in sorted(operations, key=lambda row: row["operation_id"]):
        item = op["payload"]["item"]
        holds = capture_kind_holds(op, captures)
        if op["operation_id"] not in selected_ids:
            holds.append("substantive_version_difference_preserve_both")
        if item.get("conflicts"):
            holds.append("unresolved_numeric_or_content_conflict")
        if has_public_media(item):
            holds.append("public_media_not_allowed_in_source_contract_v1")
        if item.get("composition_policy") != "RAD_CONTENT_PRECEDENCE_V4.1":
            raise ValueError("unexpected_source_policy")
        dispositions.append(
            {
                **{
                    k: op[k]
                    for k in (
                        "operation_id",
                        "article_id",
                        "locale",
                        "revision_id",
                        "payload_sha256",
                    )
                },
                "country_codes": item["country_codes"],
                "holds": sorted(set(holds)),
                "status": "HELD"
                if holds
                else "PREPARED_REQUIRES_IMPORT_AND_REAL_ADMIN_APPROVAL",
                "verification_state": "unverified",
                "approved": False,
                "published": False,
            }
        )
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
                "expected_catalog_active": active[op["article_id"]],
                "activate_catalog": True,
                "payload_sha256": op["payload_sha256"],
                "payload_text": original.canonical(op["payload"]),
            }
        )
        countries.update(set(item["country_codes"]))
    output.mkdir(exist_ok=False)
    article_by_revision = {op["revision_id"]: op["article_id"] for op in selected}
    batches = []
    for members in group_batches(entries, article_by_revision, 25):
        manifest = original.canonical(members)
        manifest_sha = original.digest(manifest)
        batch_id = str(uuid5(NAMESPACE_URL, "rad-source-editorial:" + manifest_sha))
        path = output / f"batch-{len(batches):03d}.approval-request.json"
        save(
            path,
            {
                "p_batch_id": batch_id,
                "p_manifest_text": manifest,
                "p_manifest_sha256": manifest_sha,
                "p_source_integrity_receipt_sha256": file_sha(proof_path),
                "p_note": None,
            },
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
        "format": "RAD_CORRECTED_SOURCE_RELEASE_PLAN_V1",
        "package_sha256": plan["package_sha256"],
        "source_integrity_receipt_sha256": file_sha(proof_path),
        "mechanical_decisions_sha256": decisions["decision_package_sha256"],
        "operations": len(operations),
        "eligible_proposals": len(entries),
        "held": len(operations) - len(entries),
        "proposed_country_coverage": dict(sorted(countries.items())),
        "proposed_other_titles": sum(
            not row["country_codes"] for row in dispositions if not row["holds"]
        ),
        "batches": batches,
        "dispositions": dispositions,
        "authenticated_actor": None,
        "hosted_writes": 0,
        "approved": 0,
        "published": 0,
    }
    save(output / "release-plan.json", report)
    return report


def render_admission_guard(package_sha, proof_sha, holds):
    """Additional immutable holds apply to stale and corrected package versions."""
    for value in (package_sha, proof_sha):
        if len(value) != 64 or any(c not in "0123456789abcdef" for c in value):
            raise ValueError("sha256_binding_required")
    values = []
    for package, row in holds:
        values.append(
            "("
            + ",".join(
                original.literal(value)
                for value in (
                    package,
                    row["operation_id"],
                    row["payload_sha256"],
                    row["article_id"],
                    row["locale"],
                    row["revision_id"],
                    ";".join(row["holds"]),
                )
            )
            + ")"
        )
    return (
        """-- Apply after source-faithful publication, before any batch approval.
-- This adds admission and refusal rules; it approves or publishes no content.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
create table private.rad_source_publication_holds(
 package_sha256 text not null check(package_sha256~'^[a-f0-9]{64}$'),
 operation_id text not null check(operation_id~'^[a-f0-9]{64}$'),
 payload_sha256 text not null check(payload_sha256~'^[a-f0-9]{64}$'),
 article_id uuid not null,locale text not null check(locale in('fa','en')),
 revision_id uuid not null,reason text not null check(length(reason)>0),
 primary key(package_sha256,operation_id));
alter table private.rad_source_publication_holds enable row level security;
revoke all on private.rad_source_publication_holds from public,anon,authenticated,service_role;
create trigger rad_source_publication_holds_immutable before update or delete
 on private.rad_source_publication_holds for each row execute function private.rad_immutable();
insert into private.rad_source_publication_holds values
"""
        + ",\n".join(values)
        + ";\n"
        + """create function private.rad_source_hold_event_guard() returns trigger
language plpgsql set search_path='' as $$begin
 if new.publication_basis='source_faithful' and exists(
  select 1 from private.rad_production_reconciliation_journal j
  join private.rad_source_publication_holds h on h.package_sha256=j.package_sha256
   and h.operation_id=j.operation_id and h.payload_sha256=j.payload_sha256
   and h.article_id=j.article_id and h.locale=j.locale and h.revision_id=j.revision_id
  where j.revision_id=new.revision_id) then
  raise exception 'source_publication_hold_requires_evidence_reconciliation' using errcode='PT422';
 end if;
 return new;
end $$;
revoke all on function private.rad_source_hold_event_guard() from public,anon,authenticated,service_role;
create trigger aa_rad_source_hold_event_guard before insert on public.visa_article_revision_events
 for each row execute function private.rad_source_hold_event_guard();
insert into private.rad_source_editorial_admissions values(
"""
        + ",".join(
            original.literal(v)
            for v in (package_sha, proof_sha, "RAD_CONTENT_PRECEDENCE_V4.1")
        )
        + ");\ncommit;\n"
    )


def build(args):
    parent = json.loads((args.package / "plan.json").read_text("utf8"))
    operations = list(original.read_rows(args.package / "operations.jsonl.gz"))
    original.validate_package(parent, operations)
    for name, expected in parent["inputs"].items():
        if file_sha(Path(name)) != expected:
            raise ValueError("frozen_parent_input_changed:" + name)
    audit = json.loads(args.acceptance.read_text("utf8"))
    for name, expected in audit["artifact_sha256"].items():
        if file_sha(args.acceptance.parent / name) != expected:
            raise ValueError("forensic_artifact_changed:" + name)
    if (
        audit["prepared_not_executed"]["original_package_sha256"]
        != parent["package_sha256"]
    ):
        raise ValueError("forensic_parent_package_binding_required")
    proposals = read_jsonl(args.corrections)
    if len(proposals) != 4 or any(
        p["original_package_sha256"] != parent["package_sha256"] for p in proposals
    ):
        raise ValueError("four_bound_country_corrections_required")
    corrected = correct_operations(operations, proposals)
    args.output.mkdir(exist_ok=False)
    seed = copy.deepcopy(parent)
    seed.pop("package_sha256")
    seed.pop("operation_bindings")
    seed["parent_package_sha256"] = parent["package_sha256"]
    seed["derivation"] = (
        "FOUR_LITERAL_SOURCE_COUNTRY_CORRECTIONS_NO_BODY_OR_HEAD_CHANGES"
    )
    for path in (args.acceptance, args.corrections, args.capture_kinds):
        seed["inputs"][str(path)] = file_sha(path)
    plan = original.seal_plan(seed, corrected)
    original.validate_package(plan, corrected)
    save(args.output / "plan.json", plan)
    original.write_rows(args.output / "operations.jsonl.gz", corrected)
    decisions = rebind_decisions(
        parent,
        operations,
        json.loads(args.decisions.read_text("utf8")),
        plan,
        corrected,
    )
    save(args.output / "mechanical-decisions.json", decisions)
    original_proof = json.loads(args.source_proof.read_text("utf8"))
    if not original_proof or any(
        r["report"]["composition_status"] != "PASS"
        or r["report"]["missing_source_segments"] != 0
        for r in original_proof
    ):
        raise ValueError("original_source_coverage_proof_required")
    save(
        args.output / "source-integrity.json",
        {
            "kind": "OFFLINE_SOURCE_AND_COUNTRY_BINDING_NOT_HUMAN_APPROVAL",
            "package_sha256": plan["package_sha256"],
            "parent_source_proof_sha256": file_sha(args.source_proof),
            "forensic_acceptance_sha256": file_sha(args.acceptance),
            "capture_kinds_sha256": file_sha(args.capture_kinds),
            "parent_source_reports": original_proof,
            "body_preserving_country_corrections": 4,
            "human_approvals": 0,
            "hosted_writes": 0,
        },
    )
    captures = {r["source_id"]: r for r in read_jsonl(args.capture_kinds)}
    report = prepare_batches(
        plan,
        corrected,
        decisions,
        captures,
        args.output / "source-integrity.json",
        args.output / "publication",
    )
    prior = read_jsonl(
        args.acceptance.parent / "operation-acceptance-dispositions.jsonl.gz"
    )
    old_holds = [(parent["package_sha256"], row) for row in prior if row["holds"]]
    new_holds = [
        (plan["package_sha256"], row) for row in report["dispositions"] if row["holds"]
    ]
    (args.output / "admission-and-holds.review.sql").write_text(
        render_admission_guard(
            plan["package_sha256"],
            file_sha(args.output / "source-integrity.json"),
            old_holds + new_holds,
        ),
        encoding="utf8",
        newline="\n",
    )
    summary = {
        "package_sha256": plan["package_sha256"],
        "parent_package_sha256": parent["package_sha256"],
        "operations": len(corrected),
        "changed_operations": sum(
            a != b for a, b in zip(operations, corrected, strict=True)
        ),
        "prepared_imports": len(
            mechanical.validate_decisions(plan, corrected, decisions)
        ),
        "publication_candidates": report["eligible_proposals"],
        "publication_holds": report["held"],
        "publication_batches": len(report["batches"]),
        "stale_package_publication_holds": len(old_holds),
        "existing_heads_advanced": 0,
        "imported": 0,
        "approved": 0,
        "published": 0,
        "hosted_release_authorized": False,
        "producer_sha256": file_sha(Path(__file__)),
        "files": {
            str(p.relative_to(args.output)): file_sha(p)
            for p in args.output.rglob("*")
            if p.is_file()
        },
    }
    save(args.output / "manifest.json", summary)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in (
        "package",
        "decisions",
        "source-proof",
        "acceptance",
        "capture-kinds",
        "corrections",
        "output",
    ):
        parser.add_argument("--" + name, type=Path, required=True)
    print(json.dumps(build(parser.parse_args()), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
