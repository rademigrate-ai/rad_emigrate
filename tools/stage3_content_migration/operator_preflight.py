#!/usr/bin/env python3
"""Read-only production preflight for the Stage 3 ingestion package.

This command never opens a database connection and never executes ingestion
SQL. Live database facts must be supplied as a read-only snapshot produced by
an authorized operator/query tool. Missing evidence is a NO-GO, never a pass.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import pathlib
import re
import subprocess
import sys
from typing import Any, Callable


SCHEMA_VERSION = "rad-production-preflight-v1"
FEED_TABLE = ".".join(("public", "feed_items"))
REQUIRED_RLS_TABLES = {
    "source_documents",
    "source_snapshots",
    "research_findings",
    "content_drafts",
    "feed_items",
}
REQUIRED_FUNCTIONS = {
    "ingest_research_snapshot",
    "set_research_finding_status",
    "set_content_draft_status",
    "update_content_draft",
    "publish_content_draft",
}


def _read(path: pathlib.Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _git(repo: pathlib.Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=repo, check=True, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    ).stdout.strip()


class Checks:
    def __init__(self) -> None:
        self.rows: list[dict[str, Any]] = []

    def add(self, check_id: str, passed: bool, detail: str, stop_reason: str | None = None, evidence: Any = None) -> None:
        self.rows.append({
            "id": check_id,
            "status": "PASS" if passed else "FAIL",
            "detail": detail,
            "stop_reason": None if passed else (stop_reason or detail),
            "evidence": evidence,
        })

    def guard(self, check_id: str, action: Callable[[], tuple[bool, str, Any]], stop_prefix: str) -> None:
        try:
            passed, detail, evidence = action()
            self.add(check_id, passed, detail, f"{stop_prefix}: {detail}", evidence)
        except Exception as error:  # preflight converts uncertainty to NO-GO
            self.add(check_id, False, str(error), f"{stop_prefix}: {error}")


def _check_package_manifest(repo: pathlib.Path, manifest_path: pathlib.Path) -> tuple[bool, str, Any]:
    manifest = _read(manifest_path)
    failures = []
    for entry in manifest.get("files", []):
        path = repo / entry["path"]
        if not path.is_file():
            failures.append(f"missing:{entry['path']}")
        elif path.stat().st_size != entry.get("bytes"):
            failures.append(f"size:{entry['path']}")
        elif _sha(path) != entry.get("sha256"):
            failures.append(f"hash:{entry['path']}")
    count_ok = len(manifest.get("files", [])) == manifest.get("file_count")
    if not count_ok:
        failures.append("file_count")
    return not failures, f"verified {len(manifest.get('files', []))} package entries; failures={len(failures)}", failures[:50]


def _check_sql_manifest(package: pathlib.Path) -> tuple[bool, str, Any]:
    manifest = _read(package / "INGEST_MANIFEST.json")
    failures = []
    names = []
    for entry in manifest.get("files", []):
        path = package / "sql" / entry["file"]
        names.append(entry["file"])
        if not path.is_file():
            failures.append(f"missing:{entry['file']}")
        elif _sha(path) != entry.get("sha256"):
            failures.append(f"hash:{entry['file']}")
    expected = manifest.get("execution_order", []) + ["90_verify.sql", "91_rollback.sql"]
    if sorted(set(names)) != sorted(set(expected)):
        failures.append("execution_order/files mismatch")
    ingest_text = "\n".join(
        path.read_text(encoding="utf-8", errors="replace").lower()
        for path in sorted((package / "sql").glob("10_ingest_*.sql"))
    )
    for banned in (
        f"insert into {FEED_TABLE}",
        f"update {FEED_TABLE}",
        "publish_content_draft(",
    ):
        if banned in ingest_text:
            failures.append(f"automatic publication token:{banned}")
    return not failures, f"verified {len(names)} SQL files; failures={len(failures)}", failures[:50]


def _check_canonical(canonical: pathlib.Path) -> tuple[bool, str, Any]:
    manifest = _read(canonical / "DATASET_MANIFEST.json")
    dataset = canonical / "CANONICAL_CONTENT_DATASET.jsonl"
    duplicate_map = canonical / "DUPLICATE_CANONICAL_MAP.json"
    failures = []
    if _sha(dataset) != manifest.get("dataset_sha256"):
        failures.append("dataset hash")
    if _sha(duplicate_map) != manifest.get("duplicate_map_sha256"):
        failures.append("duplicate map hash")
    count = 0
    ids: set[str] = set()
    urls: set[str] = set()
    unsafe = 0
    for line in dataset.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        count += 1
        # Dataset rows are snapshot/content observations. Repeated document
        # IDs are expected when the same canonical URL was acquired more than
        # once; SQL generation folds them into one source_document and keeps
        # distinct content hashes as snapshots.
        ids.add(row.get("id"))
        urls.add(row.get("canonical_url"))
        if row.get("review_status") != "unreviewed" or row.get("regulatory_verification_status") != "REVIEW_REQUIRED":
            unsafe += 1
    if count != manifest.get("rows"):
        failures.append(f"row count {count}!={manifest.get('rows')}")
    if unsafe:
        failures.append(f"unsafe review statuses:{unsafe}")
    if manifest.get("feed_eligible") != 0 or not manifest.get("all_review_required"):
        failures.append("manifest publication/review gate")
    return not failures, f"rows={count}, unique_ids={len(ids)}, unique_urls={len(urls)}, unsafe={unsafe}", failures[:50]


def _check_local_backup(repo: pathlib.Path, archive: pathlib.Path, checksum: pathlib.Path) -> tuple[bool, str, Any]:
    archive = archive if archive.is_absolute() else repo / archive
    checksum = checksum if checksum.is_absolute() else repo / checksum
    if not archive.is_file() or not checksum.is_file():
        return False, "local backup archive/checksum is missing", [str(archive), str(checksum)]
    expected = checksum.read_text(encoding="utf-8").strip().split()[0].lower()
    actual = _sha(archive)
    passed = bool(re.fullmatch(r"[0-9a-f]{64}", expected)) and expected == actual
    return passed, f"archive bytes={archive.stat().st_size}, checksum_match={passed}", {"expected": expected, "actual": actual}


def _check_live_snapshot(path: pathlib.Path, project_ref: str, batch_marker: str, max_age_hours: int) -> tuple[bool, str, Any]:
    if not path.is_file():
        return False, "authorized read-only live-check snapshot is missing", str(path)
    value = _read(path)
    failures = []
    if value.get("schema_version") != "rad-production-live-check-v1":
        failures.append("schema_version")
    if value.get("project_ref") != project_ref:
        failures.append("project_ref")
    if value.get("writes_performed") != 0 or value.get("method") != "read_only_sql":
        failures.append("read-only attestation")
    if value.get("batch_marker") != batch_marker:
        failures.append("batch_marker")
    if value.get("batch_marker_count") != 0:
        failures.append(f"batch marker collision count={value.get('batch_marker_count')}")
    captured = dt.datetime.fromisoformat(str(value.get("captured_at_utc", "")).replace("Z", "+00:00"))
    age = dt.datetime.now(dt.timezone.utc) - captured
    if age.total_seconds() < -300 or age > dt.timedelta(hours=max_age_hours):
        failures.append(f"snapshot age {age.total_seconds()/3600:.1f}h")
    if value.get("baseline_matches") is not True:
        failures.append("production baseline mismatch")
    detail = (
        f"project={value.get('project_ref')}, collision_count={value.get('batch_marker_count')}, "
        f"age_hours={age.total_seconds()/3600:.2f}"
    )
    if failures:
        detail += f", failures={json.dumps(failures, sort_keys=True)}"
    return not failures, detail, failures


def _check_security_catalog(path: pathlib.Path) -> tuple[bool, str, Any]:
    if not path.is_file():
        return False, "production catalog is missing", str(path)
    catalog = _read(path)
    failures = []
    rls = {
        row.get("table_name")
        for row in catalog.get("rls", [])
        if row.get("schema_name") == "public" and row.get("relrowsecurity") is True
    }
    missing_rls = sorted(REQUIRED_RLS_TABLES - rls)
    if missing_rls:
        failures.append({"missing_rls": missing_rls})
    functions = {
        row.get("proname")
        for row in catalog.get("functions", [])
        if row.get("schema_name") == "public"
    }
    missing_functions = sorted(REQUIRED_FUNCTIONS - functions)
    if missing_functions:
        failures.append({"missing_functions": missing_functions})
    grants = catalog.get("function_grants", [])
    for function in REQUIRED_FUNCTIONS:
        rows = [row for row in grants if row.get("nspname") == "public" and row.get("proname") == function]
        if not rows:
            continue
        acl = " ".join(str(row.get("acl") or "") for row in rows)
        if "anon=" in acl and "anon=X" in acl:
            failures.append({"unsafe_anon_execute": function})
    trigger_names = {row.get("tgname") for row in catalog.get("triggers", [])}
    if "research_finding_review_candidate" not in trigger_names:
        failures.append({"missing_trigger": "research_finding_review_candidate"})
    return not failures, f"rls={len(rls)}, required_functions_present={len(REQUIRED_FUNCTIONS)-len(missing_functions)}", failures


def _check_live_security(path: pathlib.Path) -> tuple[bool, str, Any]:
    """Validate authorized live RLS, grants and human-gate observations."""
    value = _read(path)
    failures: list[Any] = []
    rls = value.get("rls") or {}
    for table in sorted(REQUIRED_RLS_TABLES):
        if rls.get(table) is not True:
            failures.append({"rls_not_enabled": table})
    functions = value.get("functions") or {}
    for function in sorted(REQUIRED_FUNCTIONS):
        state = functions.get(function) or {}
        if state.get("present") is not True:
            failures.append({"missing_function": function})
            continue
        if state.get("anon_execute") is not False:
            failures.append({"anon_can_execute": function})
        if state.get("security_definer") is not True or state.get("empty_search_path") is not True:
            failures.append({"unsafe_function_definition": function})
    ingest = functions.get("ingest_research_snapshot") or {}
    if ingest.get("service_role_execute") is not True or ingest.get("authenticated_execute") is not False:
        failures.append({"unsafe_ingest_grants": ingest})
    publish = functions.get("publish_content_draft") or {}
    if publish.get("authenticated_execute") is not True:
        failures.append({"missing_authenticated_publish_grant": publish})
    if publish.get("approved_only_publish_gate") is not True:
        failures.append({"missing_approved_only_publish_gate": True})
    if value.get("research_review_trigger_present") is not True:
        failures.append({"missing_trigger": "research_finding_review_candidate"})
    detail = (
        f"live RLS tables={sum(rls.get(t) is True for t in REQUIRED_RLS_TABLES)}/{len(REQUIRED_RLS_TABLES)}, "
        f"functions={sum((functions.get(f) or {}).get('present') is True for f in REQUIRED_FUNCTIONS)}/{len(REQUIRED_FUNCTIONS)}"
    )
    if failures:
        detail += f", failures={json.dumps(failures, sort_keys=True)}"
    return not failures, detail, failures


def _check_external_backup(path: pathlib.Path | None) -> tuple[bool, str, Any]:
    if path is None or not path.is_file():
        return False, "independent backup attestation is absent", None
    value = _read(path)
    required = {"schema_version", "archive_sha256", "verified_at", "storage_location", "verified_by"}
    missing = sorted(required - set(value))
    if missing:
        return False, f"backup attestation missing fields: {missing}", value
    if value.get("schema_version") != "rad-external-backup-attestation-v1":
        return False, "backup attestation schema is unsupported", value.get("schema_version")
    if not re.fullmatch(r"[0-9a-f]{64}", str(value.get("archive_sha256", ""))):
        return False, "backup attestation archive_sha256 is invalid", value.get("archive_sha256")
    try:
        verified_at = dt.datetime.fromisoformat(str(value.get("verified_at", "")).replace("Z", "+00:00"))
        if verified_at.tzinfo is None:
            raise ValueError("timezone missing")
    except ValueError:
        return False, "backup attestation verified_at must be timezone-aware ISO-8601", value.get("verified_at")
    if not str(value.get("storage_location", "")).strip() or not str(value.get("verified_by", "")).strip():
        return False, "backup location/reviewer is empty", value
    return True, "independent backup attestation is present", value


def run(args: argparse.Namespace) -> dict[str, Any]:
    repo = pathlib.Path(args.repo).resolve()
    package = (repo / args.package).resolve()
    canonical = (repo / args.canonical).resolve()
    checks = Checks()

    checks.guard("git.branch", lambda: (
        _git(repo, "branch", "--show-current") == args.expected_branch,
        f"actual={_git(repo, 'branch', '--show-current')}, expected={args.expected_branch}",
        None,
    ), "wrong Git branch")
    checks.guard("git.head", lambda: (
        not args.expected_head or _git(repo, "rev-parse", "HEAD") == args.expected_head,
        f"actual={_git(repo, 'rev-parse', 'HEAD')}, expected={args.expected_head or 'not pinned'}",
        None,
    ), "Git HEAD mismatch")
    checks.guard("git.remote_sync", lambda: (
        _git(repo, "rev-parse", "HEAD") == _git(repo, "rev-parse", f"origin/{args.expected_branch}"),
        f"head={_git(repo, 'rev-parse', 'HEAD')}, remote={_git(repo, 'rev-parse', f'origin/{args.expected_branch}')}",
        None,
    ), "branch is not synchronized with origin")
    checks.guard("git.clean", lambda: (
        _git(repo, "status", "--porcelain") == "",
        "worktree clean" if _git(repo, "status", "--porcelain") == "" else "worktree has tracked/untracked changes",
        _git(repo, "status", "--porcelain").splitlines()[:100],
    ), "worktree is not clean")
    checks.guard("manifest.package", lambda: _check_package_manifest(repo, package / "PACKAGE_MANIFEST.json"), "package manifest verification failed")
    checks.guard("manifest.sql", lambda: _check_sql_manifest(package), "SQL manifest verification failed")
    checks.guard("canonical.dataset", lambda: _check_canonical(canonical), "canonical dataset verification failed")

    ingest = _read(package / "INGEST_MANIFEST.json")
    batch_marker = ingest.get("batch_marker")
    checks.guard("production.live_baseline", lambda: _check_live_snapshot(
        pathlib.Path(args.live_check).resolve(), args.project_ref, batch_marker, args.live_max_age_hours
    ), "read-only production baseline/collision verification failed")
    checks.guard("production.security", lambda: _check_live_security(pathlib.Path(args.live_check).resolve()), "RLS/grant/trigger verification failed")
    checks.guard("backup.local", lambda: _check_local_backup(repo, pathlib.Path(args.backup_archive), pathlib.Path(args.backup_checksum)), "local backup verification failed")
    attestation = pathlib.Path(args.external_backup_attestation).resolve() if args.external_backup_attestation else None
    checks.guard("backup.independent", lambda: _check_external_backup(attestation), "independent backup verification failed")

    stop_reasons = [row["stop_reason"] for row in checks.rows if row["status"] == "FAIL"]
    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "project_ref": args.project_ref,
        "batch_marker": batch_marker,
        "decision": "GO" if not stop_reasons else "NO-GO",
        "writes_performed": 0,
        "ingestion_sql_executed": False,
        "checks": checks.rows,
        "stop_reasons": stop_reasons,
    }


def parser() -> argparse.ArgumentParser:
    repo = pathlib.Path(__file__).resolve().parents[2]
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", default=repo)
    ap.add_argument("--package", default="artifacts/stage3_ingestion_package_20261012")
    ap.add_argument("--canonical", default="artifacts/stage3_canonical_dataset_20261011")
    ap.add_argument("--production-catalog", default="supabase/reconciliation/production_catalog.json")
    ap.add_argument("--project-ref", default="inshddthftkhcdosoqcn")
    ap.add_argument("--expected-branch", default="handoff/codex-stage1-stage2-20261010")
    ap.add_argument("--expected-head", default="")
    ap.add_argument("--live-check", required=True, help="authorized read-only live-check JSON")
    ap.add_argument("--live-max-age-hours", type=int, default=24)
    ap.add_argument("--backup-archive", default="backups/rad-raw-evidence-20261012.tar.gz")
    ap.add_argument("--backup-checksum", default="backups/rad-raw-evidence-20261012.tar.gz.sha256")
    ap.add_argument("--external-backup-attestation", default="")
    ap.add_argument("--out", required=True)
    return ap


def main() -> int:
    args = parser().parse_args()
    try:
        report = run(args)
    except Exception as error:
        report = {
            "schema_version": SCHEMA_VERSION,
            "decision": "NO-GO",
            "writes_performed": 0,
            "ingestion_sql_executed": False,
            "checks": [],
            "stop_reasons": [f"preflight internal error: {error}"],
        }
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"decision": report["decision"], "stop_reasons": report["stop_reasons"]}, ensure_ascii=False))
    return 0 if report["decision"] == "GO" else 3


if __name__ == "__main__":
    raise SystemExit(main())
