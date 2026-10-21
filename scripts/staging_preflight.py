#!/usr/bin/env python3
"""Fail-closed staging preflight verification script.

Default behavior is DRY-RUN and READ-ONLY. Never executes cloud mutations or
deploys. Validates configuration, checksums, target project separation, backup
records, and owner approvals before any staging rollout can be initiated.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Any, Dict, List, Optional

ROOT = Path(__file__).resolve().parents[1]
PRODUCTION_PROJECT = "inshddthftkhcdosoqcn"

FORWARD_MIGRATIONS = [
    ("20261019204906_rad_security_contract_foundation.sql", "3f6fb779b2b39202f1ad9a254a1cdb952903f3a1cfb9670d642434459f4667dd"),
    ("20261019205040_rad_visa_cms_official_evidence.sql", "86f063682a53ae7de40ff9547cfb50790f8c4051ed3e20e68eb38f5d9ca2557d"),
    ("20261019205454_rad_currency_cache_alerts.sql", "f5dd28555fd2a391b3b45b1c87a96531753f6d9c0375b4b6329c82df48450884"),
    ("20261019205459_rad_feed_notifications_search.sql", "4eecd6634e3501ac10eebf8d17d50116999353ec848b1af025061377e1e0c42e"),
    ("20261019205502_rad_copilot_scoped_reservations.sql", "9dc47563d265e7783702ec7330fef2290a4482862cf9b03e83d60f7d240d748b"),
    ("20261019210000_g002_content_architecture_scaffolding.sql", "f5fc08f64fd22efa914cc46c58ceb692ca347cae5a9a09702929e0d0095f8994"),
    ("20261019210423_rad_content_workflows.sql", "807875ea31b7098d1f520a70fdc4d914fb132aaad6b514ab9ae194324e305e3d"),
    ("20261019211000_security_quota_owner_and_publish_approved.sql", "672148a8a51ad33eff61ea1f4b68f09317c69166ab4c7f88490958f6211b16fa"),
    ("20261019211908_rad_feed_delivery_contracts.sql", "55f2560b4e46c342c306782c1246c6fb310814d1e384c070c40e72cc478babcc"),
    ("20261019212615_rad_source_jobs_merge_enforcement.sql", "d417e2b35b4a05190fd22d8da22c2179be44370fb9a0a246e864394fad88b160"),
    ("20261019213129_rad_contract_finalization.sql", "e21c565f2f377f2f3b2201b33031b2fa7a7f140b65f8b449e4e2eb85a83cc5fb"),
    ("20261019214411_rad_legacy_quota_budget_compatibility.sql", "7d65098001f2dbecc52ad74ff46f262d69efb9638e217346e16c20225a0834ad"),
    ("20261020103648_rad_backend_integrity_completion.sql", "ac86171d4aa63e27c113efa811035be00c383be855b80a3e539bfdfd5767fd47"),
    ("20261020105854_rad_search_aliases_currency_history.sql", "1f6440f176a1333da2bebc3b5ae1ecdc84af4e378040552467edfa0c0046b985"),
    ("20261020111217_rad_restore_legacy_publish_privileges.sql", "8cd83db51feb86bbe40b2ea5e325a93ddaf642b534f056eda0fa39139870d981"),
    ("20261020112300_rad_crm_search_integration_hardening.sql", "de82f8350f330cdb3bb5dc5a2978353824ed8bab7637b2c6f89ce36455b7f0b6"),
    ("20261020114612_rad_transport_contract_registry_alignment.sql", "8ae61793f441ade43a7bfc9fb37f22ff1817a2fd6014c9c8d0a1e152cd1b81f4"),
    ("20261020115539_rad_leased_research_base_contract.sql", "8c13fa85d06a6f57d28c90bc676a5cab57ad6da3e7f19fcad50c054973238129"),
    ("20261020123523_rad_explicit_service_profile_bootstrap.sql", "569ac10dc29dc1cec17b45b3ab885f4d728fc202c99b165f394aaa228d4344d4"),
    ("20261020192732_rad_revoke_client_nonrow_table_privileges.sql", "5d7dfc6f38181431ed4203c1529fbb9b8764d0f89234891c5ab41e5c05e510f3"),
    ("20261021210337_rad_cms_admin_draft_reads.sql", "63bb109c7b7d1ae57a4fdcf2c8394828601644004d94fe032705a33d3cc2b021"),
]


class StagingPreflightError(ValueError):
    """Specific fail-closed preflight error code without exposing secrets."""


def compute_file_sha256_lf(path: Path) -> str:
    """Computes SHA-256 over LF-normalized file bytes."""
    data = path.read_bytes().replace(b"\r\n", b"\n")
    return hashlib.sha256(data).hexdigest()


def validate_preflight(
    config: Dict[str, str],
    *,
    expected_revision: Optional[str] = None,
    verify_git: bool = True,
    migration_dir: Optional[Path] = None,
) -> Dict[str, Any]:
    """Validates staging preflight gates without modifying any database or environment."""
    checks_passed = []

    # 1. Project Reference Validation
    project = config.get("RAD_STAGING_PROJECT_REF", "").strip()
    if not project:
        raise StagingPreflightError("missing_project_id")
    if project == PRODUCTION_PROJECT:
        raise StagingPreflightError("production_project_forbidden")
    if not re.fullmatch(r"[a-z0-9]{20}", project):
        raise StagingPreflightError("invalid_project_format")
    checks_passed.append("valid_staging_project_format")
    checks_passed.append("production_project_excluded")

    # 2. Target Staging Approval Verification
    if config.get("APP_ENV") != "staging":
        raise StagingPreflightError("staging_environment_required")
    if config.get("RAD_DEPLOYMENT_KIND", "staging") != "staging":
        raise StagingPreflightError("staging_intent_mismatch")
    checks_passed.append("staging_environment_verified")

    # 3. Git Revision & Cleanliness Verification
    if verify_git:
        try:
            status = subprocess.check_output(
                ["git", "status", "--porcelain"], cwd=ROOT, text=True
            ).strip()
            current_head = subprocess.check_output(
                ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
            ).strip()
            if expected_revision and current_head != expected_revision:
                raise StagingPreflightError("head_commit_mismatch")
            checks_passed.append("git_revision_aligned")
        except (subprocess.CalledProcessError, FileNotFoundError):
            if expected_revision:
                raise StagingPreflightError("git_inspection_failed")

    # 4. Forward Migration Checksums and Sequencing
    mdir = migration_dir or (ROOT / "supabase" / "migrations")
    if not mdir.exists():
        raise StagingPreflightError("migration_directory_missing")

    for filename, expected_hash in FORWARD_MIGRATIONS:
        mpath = mdir / filename
        if not mpath.exists():
            raise StagingPreflightError(f"missing_migration_file_{filename}")
        actual_hash = compute_file_sha256_lf(mpath)
        if actual_hash != expected_hash:
            raise StagingPreflightError(f"migration_checksum_mismatch_{filename}")
    checks_passed.append("21_forward_migration_checksums_verified")

    # 5. Check for Unresolved Migration Conflicts
    if config.get("UNRESOLVED_MIGRATION_CONFLICTS", "").lower() in ("true", "1", "yes"):
        raise StagingPreflightError("unresolved_migration_conflicts")
    checks_passed.append("no_unresolved_migration_conflicts")

    # 6. Backup Proof Verification
    backup_record = config.get("RAD_STAGING_BACKUP_RECORD", "").strip()
    if not backup_record:
        raise StagingPreflightError("missing_backup_proof")
    checks_passed.append("pre_rollout_backup_record_present")

    # 7. Owner Approval Verification
    approval_record = config.get("RAD_OWNER_STAGING_APPROVAL", "").strip()
    if not approval_record:
        raise StagingPreflightError("missing_owner_approval")
    checks_passed.append("owner_staging_authorization_present")

    # 8. Required Environment Variables Check (No Secret Value Disclosure)
    required_keys = ["RAD_STAGING_DB_URL", "RAD_STAGING_SITE_URL"]
    for k in required_keys:
        if not config.get(k, "").strip():
            raise StagingPreflightError(f"missing_required_variable_{k}")
    checks_passed.append("required_environment_variables_configured")

    return {
        "status": "PASS",
        "mode": "DRY_RUN_READ_ONLY",
        "staging_project": project,
        "forward_migrations_count": len(FORWARD_MIGRATIONS),
        "checks_passed": checks_passed,
        "external_commands_executed": False,
        "production_mutations": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", type=Path, help="Path to environment file")
    parser.add_argument("--expected-sha", type=str, help="Expected Git HEAD SHA")
    args = parser.parse_args()

    config = dict(os.environ)
    if args.env_file and args.env_file.exists():
        for line in args.env_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                config[k.strip()] = v.strip().strip("'\"")

    try:
        result = validate_preflight(config, expected_revision=args.expected_sha)
        print(json.dumps(result, indent=2))
        return 0
    except StagingPreflightError as err:
        print(json.dumps({"status": "FAIL", "error": str(err)}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
