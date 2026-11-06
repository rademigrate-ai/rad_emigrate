#!/usr/bin/env python3
"""Read-only retention candidate report. This tool has no deletion/schedule mode."""

import argparse
import json
import re
from pathlib import Path


def validate_policy(policy: dict) -> bool:
    if policy.get("automatic_purge_enabled") is not False:
        raise ValueError(
            "automatic retention destruction is not implemented or authorized"
        )
    days = policy.get("retention_days")
    if (
        days is None
        and policy.get("clock_anchor") is None
        and not policy.get("terminal_application_statuses")
    ):
        return False
    statuses = policy.get("terminal_application_statuses")
    if (
        type(days) is not int
        or days < 1
        or policy.get("clock_anchor") != "document_created_at"
        or not isinstance(statuses, list)
        or not statuses
        or any(
            not isinstance(s, str) or not re.fullmatch(r"[a-z][a-z0-9_]{0,63}", s)
            for s in statuses
        )
        or not isinstance(policy.get("policy_approval_reference"), str)
        or not policy["policy_approval_reference"].strip()
    ):
        raise ValueError(
            "explicit policy duration, supported clock, terminal statuses and approval reference required"
        )
    return True


def candidate_query(policy: dict) -> str | None:
    if not validate_policy(policy):
        return None
    statuses = ",".join("'" + s + "'" for s in policy["terminal_application_statuses"])
    return f"""select jsonb_build_object('candidates_for_review',count(*))
      from public.documents d join public.applications a on a.id=d.application_id
      where a.status in ({statuses})
        and d.created_at < now()-make_interval(days=>{policy["retention_days"]})
        and d.status<>'pending_deletion'
        and not exists(select 1 from private.rad_document_preservation_holds h where h.document_id=d.id)
        and not exists(select 1 from private.rad_document_deletions q where q.document_id=d.id);"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy", type=Path, required=True)
    args = parser.parse_args()
    policy = json.loads(args.policy.read_text("utf8"))
    query = candidate_query(policy)
    report = {
        "mode": "REPORT_ONLY",
        "automatic_purge_enabled": False,
        "policy_status": "CONFIGURED_FOR_REVIEW" if query else "UNCONFIGURED",
        "approval_authenticity_verified": False,
    }
    if query:
        from self_host_stack import sql
        from self_host_test_target import target_root

        report.update(
            json.loads(
                sql(
                    target_root(), ("begin read only;" + query + "rollback;").encode()
                ).stdout
            )
        )
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
