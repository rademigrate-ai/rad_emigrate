"""Prepare a sealed disabled Research activation review package, offline only."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

PROJECT = "inshddthftkhcdosoqcn"
JOB = "rad-official-source-dispatch-v1"
FLAGS = {
    "RAD_OFFICIAL_SOURCE_WORKER_ENABLED": False,
    "RAD_OFFICIAL_SOURCE_DISCOVERY_ENABLED": False,
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def scheduler_sql(schedule, vault_name):
    if schedule not in ("*/15 * * * *", "*/30 * * * *", "0 * * * *"):
        raise ValueError("reviewed_bounded_cadence_required")
    if not re.fullmatch("rad_[a-z0-9_]{3,60}_purpose", vault_name):
        raise ValueError("vault_secret_name_only")
    # The entire script is deliberately refused, even if session settings happen
    # to be present. It is review material, not an activation authorization.
    return f"""-- REVIEW ONLY: no hosted execution authorized.
BEGIN;
DO $guard$ BEGIN
 RAISE EXCEPTION 'REVIEW_ONLY_RECOVERY_OWNER_AND_ACTIVATION_RECEIPTS_REQUIRED';
END $guard$;
-- After separate approval: require exact project, forward/source hashes,
-- actual authority bindings, disabled deployment/negative-auth acceptance,
-- egress identity and owner-approved cadence before reviewing this guard.
DO $preflight$ BEGIN
 IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = '{JOB}') THEN
  RAISE EXCEPTION 'EXISTING_JOB_MUST_BE_RECONCILED_NOT_REPLACED';
 END IF;
 IF (SELECT count(*) FROM vault.decrypted_secrets WHERE name = '{vault_name}') <> 1 THEN
  RAISE EXCEPTION 'ONE_MATCHING_PURPOSE_SECRET_REQUIRED';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM vault.decrypted_secrets WHERE name = '{vault_name}'
                AND length(decrypted_secret) BETWEEN 32 AND 512) THEN
  RAISE EXCEPTION 'PURPOSE_SECRET_LENGTH_INVALID';
 END IF;
END $preflight$;
SELECT cron.schedule('{JOB}', '{schedule}', $dispatch$
 SELECT net.http_post(
  url := 'https://{PROJECT}.supabase.co/functions/v1/official-source-worker?dispatch=1',
  headers := jsonb_build_object('Content-Type','application/json',
   'x-rad-official-source-token',
   (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = '{vault_name}')),
  body := '{{}}'::jsonb, timeout_milliseconds := 10000);
$dispatch$);
COMMIT;
"""


def build_package(repo, sources, schedule, vault_name):
    repo = Path(repo).resolve()
    sql = scheduler_sql(schedule, vault_name)
    hashes = {}
    for path in sources:
        original = Path(path).absolute()
        path = original.resolve()
        if path != original or original.is_symlink():
            raise ValueError("owned_regular_source_required")
        if not path.is_relative_to(repo) or path.is_symlink() or not path.is_file():
            raise ValueError("owned_regular_source_required")
        hashes[path.relative_to(repo).as_posix()] = sha(path)
    if not hashes:
        raise ValueError("runtime_sources_required")
    result = {
        "project_id": PROJECT,
        "activation_state": "REVIEW_ONLY",
        "hosted_operations_executed": 0,
        "paid_calls_authorized": False,
        "flags": FLAGS.copy(),
        "gateway_verify_jwt": False,
        "authentication": "dedicated purpose token checked before queue/database access",
        "source_sha256": dict(sorted(hashes.items())),
        "scheduler_review_sha256": hashlib.sha256(sql.encode()).hexdigest(),
        "stop_review_sha256": hashlib.sha256(
            stop_sql(schedule, vault_name).encode()
        ).hexdigest(),
        "proposed_cadence_pending_owner_choice": schedule,
        "purpose_secret_reference": "vault:" + vault_name,
        "deploy_disabled_command": [
            "supabase",
            "functions",
            "deploy",
            "official-source-worker",
            "--project-ref",
            PROJECT,
            "--no-verify-jwt",
            "--use-api",
        ],
        "set_disabled_secrets_command": [
            "supabase",
            "secrets",
            "set",
            "--project-ref",
            PROJECT,
            "--env-file",
            "PRIVATE_DISABLED_ENV_FILE",
        ],
        "operation_order": [
            "R0: approve real backup/isolated-restore and exact forward schema package first; validate current Production drift again.",
            "R1: set both flags false and purpose token using a private env file; separately place matching token in Vault without logging it; deploy only sealed worker source disabled.",
            "R2: verify disabled POST yields503 with zero queue mutation, non-POST405; hosted assertions require separate approval. Keep discovery false and avoid all search providers.",
            "R3: after approved authority identity/domain/proof/root records, exact source bindings and pinned deny-private egress exist, enable refresh only; test missing/wrong token403 before queue access and bounded one-job dispatch.",
            "R4: approve one cadence and review scheduler SQL; create only the new named dispatcher job. Admin explicitly enqueues refresh jobs; dispatcher does not create periodic research requests.",
            "R5: disable worker flag first, unschedule only this recorded job id after exact command-hash comparison, verify no further claims; preserve leases, jobs, source snapshots and drafts for retry.",
        ],
        "legacy_jobs": "Inventory and retain existing daily enqueue/worker jobs. They use a different public queue; no replacement, disabling or double-scheduling is authorized here.",
        "required_receipts": [
            "current_recoverable_checkpoint",
            "independent_managed_restore_auth_storage_acceptance",
            "exact_forward_package_and_endpoint",
            "sealed_disabled_deployment",
            "purpose_auth_negative_acceptance",
            "authority_registry_human_approvals",
            "source_binding_and_pinned_egress_acceptance",
            "owner_activation_scope_and_cadence",
        ],
        "not_established": [
            "hosted gateway acceptance",
            "Production approved authority registry",
            "current recovery checkpoint",
            "human authority approvals",
        ],
    }
    encoded = json.dumps(result, sort_keys=True, separators=(",", ":")).encode()
    result["package_sha256"] = hashlib.sha256(encoded).hexdigest()
    return result


def stop_sql(schedule, vault_name):
    command = scheduler_sql(schedule, vault_name).split("$dispatch$")[1]
    command_md5 = hashlib.md5(command.encode(), usedforsecurity=False).hexdigest()
    return f"""-- First disable both flags using the approved private env file.
BEGIN;
DO $guard$ BEGIN
 RAISE EXCEPTION 'REVIEW_ONLY_EXACT_CREATED_JOB_AND_STOP_AUTHORIZATION_REQUIRED';
END $guard$;
DO $stop$ DECLARE target bigint; BEGIN
 IF (SELECT count(*) FROM cron.job WHERE jobname='{JOB}') <> 1 THEN
  RAISE EXCEPTION 'EXACT_ONE_CREATED_JOB_REQUIRED';
 END IF;
 SELECT jobid INTO target FROM cron.job WHERE jobname='{JOB}'
  AND md5(command)='{command_md5}' AND schedule='{schedule}';
 IF target IS NULL OR target::text IS DISTINCT FROM current_setting('rad.approved_created_cron_job_id',true) THEN
  RAISE EXCEPTION 'RECORDED_JOB_ID_COMMAND_AND_CADENCE_MUST_MATCH';
 END IF;
 PERFORM cron.unschedule(target);
END $stop$;
COMMIT;
"""


def verify_sources(repo, package):
    repo = Path(repo).resolve()
    bound = dict(package)
    expected_package = bound.pop("package_sha256", None)
    actual_package = hashlib.sha256(
        json.dumps(bound, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    if not bound.get("source_sha256") or actual_package != expected_package:
        raise ValueError("package_integrity")
    vault_reference = package.get("purpose_secret_reference", "")
    if not vault_reference.startswith("vault:"):
        raise ValueError("package_integrity")
    sql = scheduler_sql(
        package["proposed_cadence_pending_owner_choice"], vault_reference[6:]
    )
    if hashlib.sha256(sql.encode()).hexdigest() != package["scheduler_review_sha256"]:
        raise ValueError("package_integrity")
    stop = stop_sql(
        package["proposed_cadence_pending_owner_choice"], vault_reference[6:]
    )
    if hashlib.sha256(stop.encode()).hexdigest() != package["stop_review_sha256"]:
        raise ValueError("package_integrity")
    for name, expected in package["source_sha256"].items():
        original = repo / name
        path = original.resolve()
        if path != original or original.is_symlink():
            raise ValueError("source_changed")
        if not path.is_relative_to(repo) or not path.is_file() or sha(path) != expected:
            raise ValueError("source_changed")


def collect_sources(repo):
    repo = Path(repo).resolve()
    sources = [repo / "supabase/config.toml", repo / "scripts/research_egress.py"]
    sources += sorted((repo / "supabase/functions").rglob("*.ts"))
    sources += sorted((repo / "supabase/functions").rglob("*.json"))
    sources += sorted((repo / "supabase/contracts").rglob("*.json"))
    return sources


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo", type=Path, default=Path(__file__).resolve().parents[1]
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cadence", default="*/15 * * * *")
    parser.add_argument("--vault-name", default="rad_official_worker_purpose")
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError("new_output_directory_required")
    sources = collect_sources(args.repo)
    package = build_package(args.repo, sources, args.cadence, args.vault_name)
    args.output.mkdir(parents=True)
    (args.output / "activation-package.json").write_text(
        json.dumps(package, indent=2) + "\n", "utf8"
    )
    (args.output / "SCHEDULER_REVIEW_ONLY.sql").write_text(
        scheduler_sql(args.cadence, args.vault_name), "utf8", newline="\n"
    )
    (args.output / "STOP_REVIEW_ONLY.sql").write_text(
        stop_sql(args.cadence, args.vault_name), "utf8", newline="\n"
    )
    (args.output / "disabled-flags.env.example").write_text(
        "RAD_OFFICIAL_SOURCE_WORKER_ENABLED=false\nRAD_OFFICIAL_SOURCE_DISCOVERY_ENABLED=false\n",
        "utf8",
    )
    print(
        json.dumps(
            {
                "package_sha256": package["package_sha256"],
                "sources": len(sources),
                "hosted_operations_executed": 0,
            }
        )
    )


if __name__ == "__main__":
    main()
