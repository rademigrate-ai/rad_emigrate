"""Verify corrected/legacy package files, then use the unchanged guarded renderer.

This adapter never connects to a database or supplies release authorization.
The sealed generator must remain byte-identical for existing package bindings.
"""

import argparse
import gzip
import json
import re
from pathlib import Path

from scripts import production_mechanical_decisions as mechanical
from scripts import production_reconciliation_package as core
from scripts.production_reconciliation_package import canonical, digest


def load_sealed_package(directory):
    """Read either producer's sealed bytes; this never supplies authorization."""
    root = directory.resolve(strict=True)
    legacy = (root / "artifact-seals.json").is_file()
    manifest_name = "artifact-seals.json" if legacy else "manifest.json"
    seal_file = root / manifest_name
    if seal_file.is_symlink():
        raise ValueError("package_artifact_path")
    manifest = json.loads(seal_file.read_text("utf8"))
    if not isinstance(manifest, dict):
        raise ValueError("package_manifest_invalid")
    seals = manifest if legacy else manifest.get("files")
    if (
        not isinstance(seals, dict)
        or not {"plan.json", "operations.jsonl.gz"} <= seals.keys()
    ):
        raise ValueError("package_manifest_required_artifacts")
    verified = {}
    resolved = set()
    for name, expected in seals.items():
        if not isinstance(name, str):
            raise ValueError("package_artifact_path")
        relative = name.replace("\\", "/")
        parts = relative.split("/")
        if (
            any(p in ("", ".", "..") for p in parts)
            or ":" in relative
            or "\0" in relative
        ):
            raise ValueError("package_artifact_path")
        path = root.joinpath(*parts)
        if (
            any(
                root.joinpath(*parts[:i]).is_symlink() for i in range(1, len(parts) + 1)
            )
            or not path.resolve().is_relative_to(root)
            or path.resolve() in resolved
            or relative == manifest_name
        ):
            raise ValueError("package_artifact_path")
        if not isinstance(expected, str) or not re.fullmatch("[a-f0-9]{64}", expected):
            raise ValueError("package_artifact_digest")
        content = path.read_bytes()
        if digest(content) != expected:
            raise ValueError("package_artifact_tampered:" + name)
        resolved.add(path.resolve())
        # Parse the exact bytes just verified, rather than rereading a path.
        if relative in ("plan.json", "operations.jsonl.gz"):
            verified[relative] = content
    if not legacy:
        entries = list(root.rglob("*"))
        if any(p.is_symlink() for p in entries):
            raise ValueError("package_artifact_path")
        actual = {p.resolve() for p in entries if p.is_file() and p != seal_file}
        if actual != resolved:
            raise ValueError("package_manifest_file_inventory_mismatch")
    plan = json.loads(verified["plan.json"].decode("utf8"))
    bound = dict(plan)
    expected = bound.pop("package_sha256")
    if digest(canonical(bound)) != expected:
        raise ValueError("package_plan_hash_mismatch")
    operations = [
        json.loads(line)
        for line in gzip.decompress(verified["operations.jsonl.gz"])
        .decode("utf8")
        .splitlines()
        if line.strip()
    ]
    if not legacy and (
        manifest.get("package_sha256") != expected
        or type(manifest.get("operations")) is not int
        or manifest["operations"] != len(operations)
    ):
        raise ValueError("package_manifest_plan_binding_mismatch")
    return plan, operations


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        choices=[
            "render-approved-production",
            "render-approved-restore",
            "render-compensating-rollback",
            "render-mechanical",
        ],
    )
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--authorization", type=Path, required=True)
    parser.add_argument("--decisions", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--execution-scope",
        choices=["approved_isolated_restore", "approved_production"],
    )
    args = parser.parse_args()
    if args.output.resolve().is_relative_to(args.package.resolve()):
        raise ValueError("package_output_must_be_external")
    if args.execution_scope and args.command not in (
        "render-compensating-rollback",
        "render-mechanical",
    ):
        parser.error(
            "--execution-scope applies only to compensation or mechanical rendering"
        )
    plan, operations = load_sealed_package(args.package)
    authorization = json.loads(args.authorization.read_text("utf8"))
    if args.command == "render-mechanical":
        if args.decisions is None:
            parser.error("render-mechanical requires the bound JSON --decisions")
        decisions = json.loads(args.decisions.read_text("utf8"))
        sql = mechanical.render(
            plan,
            operations,
            decisions,
            authorization,
            args.execution_scope or "approved_isolated_restore",
        )
    elif args.command == "render-compensating-rollback":
        decisions = list(core.read_rows(args.decisions)) if args.decisions else []
        if decisions:
            raise ValueError("compensation_uses_initial_journal_decision_set")
        sql = core.render_rollback_sql(
            plan,
            operations,
            authorization,
            args.execution_scope or "approved_isolated_restore",
        )
    else:
        decisions = list(core.read_rows(args.decisions)) if args.decisions else []
        scope = (
            "approved_production"
            if args.command == "render-approved-production"
            else "approved_isolated_restore"
        )
        sql = core.render_sql(plan, operations, authorization, decisions, scope)
    with args.output.open("x", encoding="utf8", newline="\n") as stream:
        stream.write(sql)
    print(
        json.dumps(
            {
                "sql_sha256": digest(args.output.read_bytes()),
                "execution_performed": False,
            }
        )
    )


if __name__ == "__main__":
    main()
