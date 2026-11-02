"""Extend the sealed import renderer with independently checked mechanical decisions.

The original generator and package bytes remain immutable. No human reviewer,
factual approval or hosted execution is inferred from a mechanical disposition.
"""

from __future__ import annotations

import argparse
import gzip
import json
from collections import Counter
from pathlib import Path

from scripts import production_reconciliation_package as original
from scripts.visa_release_audit import compare_production_heads, file_sha
from tools.production_body_review import digest as review_digest
from tools.production_body_review import draft_body, projected_blocks, semantic

POLICY = "RAD_CONTENT_PRECEDENCE_V4.1"


def independent_delta(before: dict, after: dict) -> dict:
    left = [original.canonical(b) for b in projected_blocks(before)]
    right = [original.canonical(b) for b in projected_blocks(after)]
    remaining = iter(right)
    ordered = all(any(value == candidate for candidate in remaining) for value in left)
    missing = sum((Counter(left) - Counter(right)).values())
    changed = [
        key
        for key in sorted(set(semantic(before)) | set(semantic(after)))
        if key != "sections" and semantic(before).get(key) != semantic(after).get(key)
    ]
    return {
        "classification": (
            "EXACT_ADDITIVE_ORDER_PRESERVED"
            if ordered and not changed
            else "REORDER_OR_RESECTION_WITH_ADDITIONS"
            if not missing and not changed
            else "CURRENT_CONTENT_OR_METADATA_NEEDS_EXPLICIT_RECONCILIATION"
        ),
        "unmatched_current_occurrences": missing,
        "changed_nonsection_fields": changed,
        "current_sequence_is_exact_subsequence": ordered,
    }


def prepare(plan: dict, operations: list[dict], review: Path, readback: dict) -> dict:
    original.validate_package(plan, operations)
    comparison = compare_production_heads(plan["production_baseline"], readback)
    if comparison["differences"]:
        raise ValueError("current_production_heads_changed")
    receipt = json.loads((review / "receipt.json").read_text("utf8"))
    captures = {}
    for name, expected in receipt["inputs"].items():
        path = Path(name)
        if path.name.startswith("production-full-body-") and path.suffix == ".json":
            if file_sha(path) != expected:
                raise ValueError("current_body_capture_tampered")
            for row in json.loads(path.read_text("utf8"))["rows"]:
                key = (row["article_id"], row["locale"])
                if key in captures:
                    raise ValueError("duplicate_current_body_capture")
                captures[key] = row
    dispositions = []
    for op in operations:
        if op["action"] != "PENDING_HUMAN_RECONCILIATION":
            continue
        case = op["review_case"]
        current = captures[(op["article_id"], op["locale"])]
        if (
            current["head_id"] != case["current_head"]
            or current["body_md5"] != case["current_body_md5"]
            or review_digest(current["body"]) != case["current_body_sha256"]
        ):
            raise ValueError("captured_current_body_binding_mismatch")
        delta = independent_delta(
            current["body"], draft_body(op["payload"]["item"]["draft_request"])
        )
        if any(delta[key] != case["delta"][key] for key in delta):
            raise ValueError("independent_delta_does_not_match_sealed_case")
        safe = (
            not delta["unmatched_current_occurrences"]
            and not delta["changed_nonsection_fields"]
            and case["source_review_status"] == "PASS_EXACT_MECHANICAL_SOURCE_INTEGRITY"
            and case["source_review_errors"] == []
        )
        dispositions.append(
            {
                "article_id": op["article_id"],
                "locale": op["locale"],
                "operation_id": op["operation_id"],
                "case_id": case["case_id"],
                "case_sha256": case["case_sha256"],
                "payload_sha256": op["payload_sha256"],
                "current_head": current["head_id"],
                "current_body_md5": current["body_md5"],
                "current_body_sha256": case["current_body_sha256"],
                "decision": "create_detached_draft"
                if safe
                else "hold_preserve_both_alternatives",
                "decision_basis": "owner_authorized_mechanical_preservation"
                if safe
                else "substantive_difference",
                "independent_delta": delta,
                "reviewer_id": None,
                "publication_allowed": False,
                "advance_existing_head": False,
                "conflicts_sha256": original.digest(
                    original.canonical(op["payload"]["item"].get("conflicts", []))
                ),
            }
        )
    result = {
        "format": "RAD_MECHANICAL_RECONCILIATION_V1",
        "policy": POLICY,
        "package_sha256": plan["package_sha256"],
        "adapter_sha256": file_sha(Path(__file__)),
        "review_receipt_sha256": file_sha(review / "receipt.json"),
        "current_heads_comparison": comparison,
        "dispositions": sorted(dispositions, key=lambda row: row["operation_id"]),
        "counts": dict(sorted(Counter(r["decision"] for r in dispositions).items())),
        "human_approvals": 0,
        "hosted_execution": False,
    }
    result["decision_package_sha256"] = original.digest(original.canonical(result))
    return result


def validate_decisions(
    plan: dict, operations: list[dict], decisions: dict
) -> list[dict]:
    original.validate_package(plan, operations)
    bound = dict(decisions)
    expected = bound.pop("decision_package_sha256", None)
    if (
        decisions.get("format") != "RAD_MECHANICAL_RECONCILIATION_V1"
        or decisions.get("policy") != POLICY
        or decisions.get("package_sha256") != plan["package_sha256"]
        or decisions.get("adapter_sha256") != file_sha(Path(__file__))
        or original.digest(original.canonical(bound)) != expected
    ):
        raise ValueError("mechanical_decision_package_mismatch")
    pending = {
        o["operation_id"]: o
        for o in operations
        if o["action"] == "PENDING_HUMAN_RECONCILIATION"
    }
    rows = decisions["dispositions"]
    if len(rows) != len(pending) or {r["operation_id"] for r in rows} != set(pending):
        raise ValueError("complete_unique_disposition_set_required")
    selected = [o for o in operations if o["action"].startswith("INSERT_")]
    for row in rows:
        op = pending[row["operation_id"]]
        case = op["review_case"]
        if (
            row["article_id"] != op["article_id"]
            or row["locale"] != op["locale"]
            or row["case_id"] != case["case_id"]
            or row["payload_sha256"] != op["payload_sha256"]
            or row["case_sha256"] != case["case_sha256"]
            or row["current_head"] != op["expected_current"]["head_id"]
            or row["current_body_md5"] != op["expected_current"]["body_md5"]
            or row["current_body_sha256"] != case["current_body_sha256"]
            or row["reviewer_id"] is not None
            or row["publication_allowed"] is not False
            or row["advance_existing_head"] is not False
            or row["conflicts_sha256"]
            != original.digest(
                original.canonical(op["payload"]["item"].get("conflicts", []))
            )
            or any(
                row["independent_delta"][k] != case["delta"][k]
                for k in row["independent_delta"]
            )
        ):
            raise ValueError("mechanical_decision_binding_mismatch")
        if row["decision"] == "create_detached_draft":
            if (
                case["delta"]["unmatched_current_occurrences"] != 0
                or case["delta"]["changed_nonsection_fields"] != []
                or case["source_review_errors"] != []
                or case["source_review_status"]
                != "PASS_EXACT_MECHANICAL_SOURCE_INTEGRITY"
            ):
                raise ValueError("substantive_case_cannot_be_mechanically_selected")
            selected.append(op)
        elif row["decision"] != "hold_preserve_both_alternatives":
            raise ValueError("unknown_mechanical_decision")
    return selected


def write_review_sql(
    path: Path, plan: dict, operations: list[dict], decisions: dict
) -> dict:
    selected = validate_decisions(plan, operations, decisions)
    with (
        path.open("xb") as raw,
        gzip.GzipFile(fileobj=raw, mode="wb", filename="", mtime=0) as output,
    ):
        output.write(
            b"begin;do $$begin raise exception 'MECHANICAL_REVIEW_ONLY_RECOVERY_ACTOR_ENDPOINT_REQUIRED';end $$;\n"
        )
        for statement in original.plan_statements(
            plan,
            selected,
            "nullif(current_setting('rad.future_approved_actor_id',true),'')",
        ):
            output.write((statement + "\n").encode())
        output.write(b"rollback;\n")
    return {
        "prepared_insert_operations": len(selected),
        "held_operations": len(operations) - len(selected),
        "gzip_sha256": file_sha(path),
        "hosted_execution": False,
    }


def render(
    plan: dict,
    operations: list[dict],
    decisions: dict,
    authorization: dict | None = None,
    scope: str = "approved_isolated_restore",
) -> str:
    selected = validate_decisions(plan, operations, decisions)
    if authorization is None:
        return "begin;do $$begin raise exception 'MECHANICAL_REVIEW_ONLY_RECOVERY_ACTOR_ENDPOINT_REQUIRED';end $$;rollback;\n"
    original.validate_authorization(authorization, plan["package_sha256"], scope)
    mechanical_sha = decisions["decision_package_sha256"]
    empty_human_sha = original.digest(original.canonical([]))
    if (
        authorization.get("mechanical_decisions_sha256") != mechanical_sha
        or authorization.get("mechanical_adapter_sha256") != file_sha(Path(__file__))
        or authorization.get("human_decisions_sha256") != empty_human_sha
        or authorization.get("operation", "apply_unverified_drafts")
        != "apply_unverified_drafts"
    ):
        raise ValueError("exact_mechanical_authorization_required")
    guards = original.authorization_guards(
        plan, authorization, scope, empty_human_sha, []
    )
    pkg = original.literal(plan["package_sha256"])
    sha = original.literal(mechanical_sha)
    actor = original.literal(authorization["actor_id"])
    guards.append(f"""
create table if not exists private.rad_production_mechanical_receipts(
 package_sha256 text primary key,decision_sha256 text not null,actor_id uuid not null references auth.users(id),
 adapter_sha256 text not null,created_at timestamptz not null default now());
alter table private.rad_production_mechanical_receipts enable row level security;
revoke all on private.rad_production_mechanical_receipts from public,anon,authenticated,service_role;
do $mechanical$ begin
 if current_setting('rad.mechanical_decisions_sha256',true) is distinct from {sha}
 then raise exception 'MECHANICAL_CONTEXT_REQUIRED';end if;
 if exists(select 1 from private.rad_production_mechanical_receipts where package_sha256={pkg}
 and (decision_sha256<>{sha} or actor_id<>{actor}::uuid))
 then raise exception 'MECHANICAL_RECEIPT_CONFLICT';end if;
end $mechanical$;
insert into private.rad_production_mechanical_receipts(package_sha256,decision_sha256,actor_id,adapter_sha256)
values({pkg},{sha},{actor}::uuid,{original.literal(file_sha(Path(__file__)))}) on conflict do nothing;
""")
    guards.extend(
        original.plan_statements(
            plan, selected, actor, original.literal(empty_human_sha)
        )
    )
    guards.append("commit;")
    return "\n".join(guards) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare", "render", "review-sql"])
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--review", type=Path)
    parser.add_argument("--current-readback", type=Path)
    parser.add_argument("--decisions", type=Path)
    parser.add_argument("--authorization", type=Path)
    parser.add_argument(
        "--scope",
        choices=["approved_isolated_restore", "approved_production"],
        default="approved_isolated_restore",
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    plan = json.loads((args.package / "plan.json").read_text("utf8"))
    operations = list(original.read_rows(args.package / "operations.jsonl.gz"))
    if args.command == "prepare":
        if args.review is None or args.current_readback is None:
            parser.error("prepare requires --review and --current-readback")
        result = prepare(
            plan,
            operations,
            args.review,
            json.loads(args.current_readback.read_text("utf8")),
        )
        data = json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    else:
        if args.decisions is None:
            parser.error("render requires --decisions")
        result = json.loads(args.decisions.read_text("utf8"))
        if args.command == "review-sql":
            print(json.dumps(write_review_sql(args.output, plan, operations, result)))
            return
        auth = (
            json.loads(args.authorization.read_text("utf8"))
            if args.authorization
            else None
        )
        data = render(plan, operations, result, auth, args.scope)
    with args.output.open("x", encoding="utf8", newline="\n") as stream:
        stream.write(data)
    print(
        json.dumps({"output_sha256": file_sha(args.output), "hosted_execution": False})
    )


if __name__ == "__main__":
    main()
