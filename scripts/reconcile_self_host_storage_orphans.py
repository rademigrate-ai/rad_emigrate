#!/usr/bin/env python3
"""Report (and only on explicit request, delete) orphaned document objects.

Requirement 7: before the two-phase deletion RPC existed, a client could delete
a `public.documents` row and leave its Storage object readable forever. Those
pre-existing orphans need reconciling.

Deliberately NOT a bulk cleanup. Default mode reports only. Deleting requires
--delete-verified-orphans AND a per-object age floor, and an object is treated
as an orphan only when it is positively verified to have no referencing row and
no in-flight deletion request. Anything ambiguous is reported, never deleted.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import UTC, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from self_host_stack import sql  # noqa: E402
from self_host_test_target import load_target, target_root  # noqa: E402

BUCKET = "documents"


def approved_orphans(eligible: list[str], approved: list[str]) -> list[str]:
    """Allow exact, individually reviewed names only; never a blanket purge."""
    if not approved:
        raise ValueError(
            "explicit --approved-object <exact-storage-path> required for deletion"
        )
    if len(approved) != len(set(approved)):
        raise ValueError("duplicate approved object")
    unknown = set(approved) - set(eligible)
    if unknown:
        raise ValueError(
            "approved paths must exist among age-verified, unreferenced candidates"
        )
    return sorted(approved)


def call(
    url: str, method: str, apikey: str, payload: object | None = None
) -> tuple[int, bytes]:
    body = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(url, data=body, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    req.add_header("apikey", apikey)
    req.add_header("Authorization", f"Bearer {apikey}")
    try:
        # This helper is restricted to an owned loopback test target. Windows
        # proxy settings can otherwise send 127.0.0.1 requests off-machine.
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(req, timeout=30) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()


def storage_objects(root: Path) -> list[tuple[str, str]]:
    """Every object in the documents bucket, with its creation time."""
    rows = (
        sql(
            root,
            b"select name||'|'||created_at::text from storage.objects "
            b"where bucket_id='documents' order by name;",
        )
        .stdout.decode()
        .splitlines()
    )
    return [tuple(row.split("|", 1)) for row in rows if row.strip()]


def referenced_paths(root: Path) -> set[str]:
    """Paths a documents row or an in-flight deletion request still claims."""
    rows = (
        sql(
            root,
            b"select file_path from public.documents where file_path is not null "
            b"union select object_path from private.rad_document_deletions "
            b"where state <> 'finalized';",
        )
        .stdout.decode()
        .splitlines()
    )
    return {row.strip() for row in rows if row.strip()}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--delete-verified-orphans",
        action="store_true",
        help="actually delete; omit for a report-only run",
    )
    parser.add_argument(
        "--min-age-hours",
        type=int,
        default=24,
        help="refuse to delete an object younger than this (default 24)",
    )
    parser.add_argument(
        "--approved-object",
        action="append",
        default=[],
        metavar="EXACT_PATH",
        help="human-reviewed exact object path (required for each destructive deletion)",
    )
    args = parser.parse_args()
    if args.min_age_hours < 0:
        parser.error("--min-age-hours must be nonnegative")

    root = target_root()
    api, _anon, service_key = load_target()

    objects = storage_objects(root)
    referenced = referenced_paths(root)
    cutoff = datetime.now(UTC) - timedelta(hours=args.min_age_hours)

    orphans: list[str] = []
    too_young: list[str] = []
    for name, created in objects:
        if name in referenced:
            continue
        try:
            age_ok = datetime.fromisoformat(created.replace(" ", "T")) < cutoff
        except ValueError:
            # An unparseable timestamp is ambiguous; never delete on a guess.
            too_young.append(name)
            continue
        (orphans if age_ok else too_young).append(name)

    # Count claims that point at an object which actually exists, separately
    # from claims whose object is already gone. Reporting only the raw claim
    # count invites the misreading that referenced + orphans should equal the
    # object total, which it never does once rows outlive their objects.
    present = {name for name, _ in objects}
    live_references = referenced & present
    dangling_references = sorted(referenced - present)

    report = {
        "bucket": BUCKET,
        "objects_total": len(objects),
        "objects_referenced_by_a_row_or_request": len(live_references),
        "verified_orphans": len(orphans),
        "skipped_too_young_or_ambiguous": len(too_young),
        "rows_referencing_a_missing_object": len(dangling_references),
        "min_age_hours": args.min_age_hours,
        "mode": "DELETED" if args.delete_verified_orphans else "REPORT_ONLY",
        "deleted": 0,
        "delete_failures": 0,
    }

    if args.delete_verified_orphans:
        try:
            targets = approved_orphans(orphans, args.approved_object)
        except ValueError as error:
            parser.error(str(error))
        report["approved_objects"] = len(targets)
        report["skipped_not_approved"] = len(orphans) - len(targets)
        report["skipped_since_scan"] = 0
        for name in targets:
            # Re-check the live claim and the object's age immediately before
            # every destructive call. No wildcard, unreviewed batch or bulk
            # action is ever accepted.
            current = dict(storage_objects(root))
            if name in referenced_paths(root) or name not in current:
                report["skipped_since_scan"] += 1
                continue
            try:
                fresh_date = datetime.fromisoformat(current[name].replace(" ", "T"))
            except ValueError:
                report["skipped_since_scan"] += 1
                continue
            if fresh_date >= cutoff:
                report["skipped_since_scan"] += 1
                continue
            status, _ = call(
                f"{api}/storage/v1/object/{BUCKET}/{urllib.parse.quote(name, safe='/')}",
                "DELETE",
                service_key,
            )
            if status in (200, 204, 404):
                report["deleted"] += 1
            else:
                report["delete_failures"] += 1
        report["status"] = (
            "APPROVED_OBJECTS_DELETED"
            if not report["delete_failures"]
            else "PARTIAL_FAILURE"
        )
    else:
        report["status"] = "REPORT_ONLY_NOTHING_DELETED"

    print(json.dumps(report, indent=2))
    print(
        "\nobjects_total = objects_referenced_by_a_row_or_request + verified_orphans "
        "+ skipped_too_young_or_ambiguous. A row whose object is already gone is "
        "counted in rows_referencing_a_missing_object and is NOT an orphan: there is "
        "nothing in Storage to delete for it."
    )
    if too_young:
        print(
            f"\n{len(too_young)} object(s) were skipped as too young or ambiguous and "
            "were NOT deleted. Re-run later or inspect them individually.",
        )
    if dangling_references:
        print(
            f"\n{len(dangling_references)} document row(s) or request(s) reference an "
            "object that no longer exists. These are reported for inspection only; "
            "this tool never edits or deletes database rows."
        )
    if report["delete_failures"]:
        raise SystemExit("some orphan deletions failed; rerun after investigating")


if __name__ == "__main__":
    if not os.environ.get("RAD_SELF_HOST_TEST_ROOT"):
        raise SystemExit(
            "set RAD_SELF_HOST_TEST_ROOT to an owned disposable self-host install"
        )
    main()
