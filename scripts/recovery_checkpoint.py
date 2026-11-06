"""Offline recovery command preparation and failure-safe encrypted export.

No connection is opened by the CLI. A profile is an operator's claim, never
independent recovery proof. Live execution requires separate authorization.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

PROJECT = "inshddthftkhcdosoqcn"
STAGING = "epolbumcfbohtmgvomki"
SECURITY = "kojogjkasconksifxkdg"
HASH_FIELDS = (
    "source_identity_sha256",
    "destination_identity_sha256",
    "owner_authorization_sha256",
    "managed_restore_toc_review_sha256",
)
REF_FIELDS = (
    "pg_service_file_ref",
    "pg_pass_file_ref",
    "key_custodian_ref",
    "encrypted_destination_ref",
)
TRUE_FIELDS = (
    "source_writes_quiesced",
    "destination_empty",
    "outbound_blocked_before_restore",
    "cron_disabled_before_restore",
)
FIELDS = {
    "source_project",
    "source_service",
    "destination_project",
    "destination_service",
    "recipient_fingerprint",
    "retention_days",
    "maximum_loss_seconds",
    "maximum_restore_seconds",
    *HASH_FIELDS,
    *REF_FIELDS,
    *TRUE_FIELDS,
}


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=True, separators=(",", ":"))


def build_plan(profile, snapshot):
    if set(profile) != FIELDS:
        raise ValueError("exact_profile_fields_only_no_credentials")
    if profile["source_project"] != PROJECT:
        raise ValueError("production_source_required")
    destination = profile["destination_project"]
    if not isinstance(destination, str) or not re.fullmatch("[a-z]{20}", destination):
        raise ValueError("independently_identified_isolated_destination_required")
    if destination in (PROJECT, STAGING, SECURITY):
        raise ValueError("shared_destination_forbidden")
    for field in ("source_service", "destination_service"):
        if not isinstance(profile[field], str) or not re.fullmatch(
            "rad_[a-z0-9_]{3,50}", profile[field]
        ):
            raise ValueError("named_pg_service_required")
    if profile["source_service"] == profile["destination_service"]:
        raise ValueError("distinct_services_required")
    for field in HASH_FIELDS:
        if not isinstance(profile[field], str) or not re.fullmatch(
            "[a-f0-9]{64}", profile[field]
        ):
            raise ValueError("approved_identity_and_review_hashes_required")
    if profile["source_identity_sha256"] == profile["destination_identity_sha256"]:
        raise ValueError("distinct_endpoint_identities_required")
    for field in REF_FIELDS:
        if not isinstance(profile[field], str) or not re.fullmatch(
            r"(?:file|vault):[A-Za-z0-9_./:-]{1,240}", profile[field]
        ):
            raise ValueError("secret_reference_only")
    for field in TRUE_FIELDS:
        if profile[field] is not True:
            raise ValueError("quiescence_and_pre_restore_isolation_required")
    for field in ("retention_days", "maximum_restore_seconds"):
        if type(profile[field]) is not int or profile[field] <= 0:
            raise ValueError("positive_retention_and_restore_objective_required")
    if (
        type(profile["maximum_loss_seconds"]) is not int
        or profile["maximum_loss_seconds"] < 0
    ):
        raise ValueError("loss_objective_required")
    if not isinstance(profile["recipient_fingerprint"], str) or not re.fullmatch(
        "[A-F0-9]{40,64}", profile["recipient_fingerprint"]
    ):
        raise ValueError("public_encryption_fingerprint_required")
    if not re.fullmatch("[A-Fa-f0-9]{8}-[A-Fa-f0-9]{8}-[1-9][0-9]*", snapshot):
        raise ValueError("exported_snapshot_id_required")
    result = {
        "status": "OPERATOR_PLAN_ONLY_NOT_RECOVERY_PROOF",
        "project_id": PROJECT,
        "profile_sha256": hashlib.sha256(canonical(profile).encode()).hexdigest(),
        "hosted_operations_executed": 0,
        "snapshot_holder_sql": "BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY; SELECT pg_export_snapshot(); -- hold connection open until dump completes",
        "database_producer": [
            "pg_dump",
            "--format=custom",
            "--no-password",
            "--lock-wait-timeout=30s",
            "--snapshot=" + snapshot,
            "--dbname",
            "service=" + profile["source_service"],
        ],
        "roles_producer": [
            "pg_dumpall",
            "--roles-only",
            "--no-password",
            "--database",
            "service=" + profile["source_service"],
        ],
        "encryptor": [
            "gpg",
            "--batch",
            "--no-auto-key-retrieve",
            "--trust-model",
            "always",
            "--recipient",
            profile["recipient_fingerprint"],
            "--encrypt",
        ],
        "restore_consumer": [
            "pg_restore",
            "--exit-on-error",
            "--single-transaction",
            "--no-password",
            "--use-list",
            "REVIEWED_MANAGED_RESTORE_TOC.list",
            "--dbname",
            "service=" + profile["destination_service"],
        ],
        "environment_refs": {k: profile[k] for k in REF_FIELDS},
        "prerequisites": [
            "Verify service file TLS verify-full, root CA, database, hostname and project-qualified role against independently approved endpoint identities; service alias alone proves nothing.",
            "Freeze application, Auth, role/configuration and Storage writes before snapshot; keep frozen until database, roles, platform settings and every Storage byte are sealed.",
            "Compare full non-extension relation inventory and dump TOC including every auth/storage/migration table and custom managed-schema object; do not assume CLI defaults include them.",
            "Capture and encrypt all private/public Storage objects using supported read API; hash original bytes, metadata and bucket configuration with full pagination.",
            "Roles export includes password hashes: encrypt stream immediately. Review managed-role conflicts and roles outside database snapshot under the same freeze.",
            "Block outbound traffic, email, cron startup, workers and webhooks at destination before restore; compatibility and encryption-root portability must be approved first.",
            "Review and hash TOC before restore; do not ignore errors, use --clean, disable constraints, or silently omit managed customizations/owners/ACLs.",
            "Decrypt in a pipe to pg_restore; require both process exit codes zero. Preserve failure and use a newly approved empty destination after partial external effects.",
            "Verify all schema/ACL/RLS/FKs, ordered row hashes and Storage bytes before forward DDL; independently test existing authorized account through real isolated Auth/API.",
        ],
    }
    result["plan_sha256"] = hashlib.sha256(canonical(result).encode()).hexdigest()
    return result


def verify_files(root, artifacts):
    root = Path(root).resolve()
    if not artifacts:
        raise ValueError("nonempty_artifacts_required")
    for name, expected in artifacts.items():
        target = (root / name).resolve()
        if not target.is_relative_to(root) or not name.endswith(".gpg"):
            raise ValueError("encrypted_owned_artifact_required")
        if not target.is_file():
            raise ValueError("artifact_mismatch")
        with target.open("rb") as stream:
            if hashlib.file_digest(stream, "sha256").hexdigest() != expected:
                raise ValueError("artifact_mismatch")


def checked_export(producer, encryptor, target, env=None):
    """Pipe directly to encryption; promote only if BOTH subprocesses succeed.

    Commands are supplied as argument arrays by an authorized operator, without
    shell expansion. Stderr is intentionally not copied into public audit logs.
    This helper is also exercised with synthetic data in the local rehearsal.
    """
    target = Path(target)
    if target.suffix != ".gpg" or target.exists():
        raise ValueError("new_encrypted_artifact_required")
    partial = target.with_suffix(".gpg.partial")
    if partial.exists():
        raise ValueError("existing_partial_requires_inspection")
    source = sink = None
    try:
        with partial.open("xb") as output:
            source = subprocess.Popen(
                producer, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env
            )
            sink = subprocess.Popen(
                encryptor,
                stdin=source.stdout,
                stdout=output,
                stderr=subprocess.DEVNULL,
                env=env,
            )
            source.stdout.close()
            sink_code = sink.wait(timeout=3600)
            source_code = source.wait(timeout=30)
            if source_code:
                raise RuntimeError("producer_failed")
            if sink_code:
                raise RuntimeError("encryptor_failed")
            output.flush()
            os.fsync(output.fileno())
        if not partial.stat().st_size:
            raise RuntimeError("empty_ciphertext")
        # Exclusive link prevents accidental replacement of a checkpoint created
        # by another operator after the original existence check.
        os.link(partial, target)
        partial.unlink()
    finally:
        for process in (source, sink):
            if process is not None and process.poll() is None:
                process.kill()
                process.wait()
        if partial.exists():
            partial.unlink()
    with target.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", type=Path, required=True)
    parser.add_argument("--snapshot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    plan = build_plan(json.loads(args.profile.read_text("utf8")), args.snapshot)
    with args.output.open("x", encoding="utf8") as stream:
        stream.write(json.dumps(plan, indent=2) + "\n")


if __name__ == "__main__":
    main()
