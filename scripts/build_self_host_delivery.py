#!/usr/bin/env python3
"""Assemble a secret-free, commit-bound operator review package. Never deploys."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

try:
    from .build_self_host_bundle import build_bundle, git
except ImportError:
    from build_self_host_bundle import build_bundle, git

OPERATOR_FILES = (
    "self_host_stack.py",
    "self_host_snapshot.py",
    "self_host_test_target.py",
    "document_deletion_dispatcher.py",
    "document_retention_report.py",
    "reconcile_self_host_storage_orphans.py",
    "public_web_build.py",
    "verify_local_auth_isolation.py",
    "verify_self_host_document_deletion.py",
    "verify_self_host_storage_gates.py",
    "verify_self_host_password_recovery.py",
    "verify_self_host_otp_sessions.py",
    "verify_research_cms_persistence.py",
    "verify_self_host_web_e2e.py",
    "measure_self_host_acceptance.py",
)


def assemble(repo: Path, upstream: Path, output: Path) -> dict:
    repo, output = repo.resolve(), output.resolve()
    if output.exists() or output.is_relative_to(repo):
        raise ValueError("new package directory outside the repository required")
    if git(repo, "status", "--porcelain"):
        raise ValueError("commit all reviewed sources before packaging")
    commit = git(repo, "rev-parse", "HEAD")
    bundle = output / "backend"
    manifest = build_bundle(repo, upstream, bundle)
    try:
        # Resolve only the model, never a live environment. Values remain
        # template expressions; the shipped image references become immutable.
        raw = subprocess.check_output(
            [
                "docker",
                "compose",
                "--project-directory",
                str(bundle),
                "--env-file",
                str(bundle / ".env.example"),
                "-f",
                str(bundle / "docker-compose.yml"),
                "config",
                "--no-interpolate",
                "--no-path-resolution",
                "--format",
                "json",
            ],
            stderr=subprocess.DEVNULL,
        )
        model = json.loads(raw)
        lock = json.loads(
            (repo / "deploy/self-hosted/images.lock.json").read_text("utf8")
        )
        for service in model["services"].values():
            reference = service["image"]
            pinned = lock.get(reference)
            if not pinned or pinned.get("architecture") != "amd64":
                raise ValueError("unreviewed image in upstream Compose")
            service["image"] = pinned["digest"]
        (bundle / "docker-compose.pinned.json").write_bytes(
            json.dumps(model, indent=2).encode()
        )
        operator = output / "scripts"
        operator.mkdir()
        for filename in OPERATOR_FILES:
            shutil.copyfile(repo / "scripts" / filename, operator / filename)
        for directory in ("deploy/self-hosted",):
            shutil.copytree(repo / directory, output / directory)
        shutil.copytree(repo / "supabase/tests", output / "supabase/tests")
        shutil.copytree(repo / "lib/l10n", output / "lib/l10n")
        docs = output / "docs"
        docs.mkdir()
        for filename in (
            "SELF_HOSTED_OPERATOR_RUNBOOK.md",
            "DOCUMENT_WORKER_OPERATIONS.md",
            "DOCUMENT_RETENTION_OPTIONS.md",
        ):
            shutil.copyfile(repo / "docs/master_execution" / filename, docs / filename)
        for file in output.rglob("*"):
            if file.name == ".env" or file.is_symlink():
                raise ValueError("active environment or symlink in package")
        files = {
            p.relative_to(output).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(output.rglob("*"))
            if p.is_file()
        }
        result = {
            "status": "OPERATOR_REVIEW_PACKAGE_NOT_RELEASE_AUTHORIZATION",
            "commit": commit,
            "migrations": manifest["migration_count"],
            "upstream": manifest["official_self_hosted_commit"],
            "architecture": "amd64",
            "files": files,
            "web_build": "Build separately with the approved public hostname and anon key; see runbook.",
            "production_actions_performed": False,
        }
        (output / "DELIVERY_MANIFEST.json").write_bytes(
            json.dumps(result, indent=2).encode()
        )
        return {key: value for key, value in result.items() if key != "files"}
    except Exception:
        # Retain incomplete output for diagnosis; never label it successful.
        (output / "INCOMPLETE.txt").write_text(
            "Package creation failed. Do not deploy.\n"
        )
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(
        json.dumps(
            assemble(Path(__file__).resolve().parents[1], args.upstream, args.output)
        )
    )


if __name__ == "__main__":
    main()
