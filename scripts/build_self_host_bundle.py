#!/usr/bin/env python3
"""Build an offline, NON-DEPLOYABLE RAD self-hosted staging bundle.

Copies the pinned official Docker release plus tracked RAD Edge Function sources
and SQL migrations. Does not start containers, execute SQL, or package secrets.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path, PurePosixPath
from tempfile import TemporaryDirectory

UPSTREAM_COMMIT = "bc27d2661edd09a5d0b8d76ce33da6d4071a756e"


def git(root: Path, *args: str) -> str:
    try:
        result = subprocess.check_output(
            ["git", "-C", str(root), *args], stderr=subprocess.DEVNULL
        )
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        raise ValueError("required local Git revision evidence unavailable") from exc
    return result.decode("utf8").strip()


def tracked_app_paths(root: Path) -> list[PurePosixPath]:
    raw = subprocess.check_output(
        [
            "git",
            "-C",
            str(root),
            "ls-files",
            "-z",
            "--",
            "supabase/functions",
            "supabase/migrations",
        ]
    )
    result = []
    for item in filter(None, raw.decode("utf8").split("\0")):
        relative = PurePosixPath(item)
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("unsafe tracked path")
        if relative.parts[:3] == ("supabase", "functions", "tests"):
            continue
        if any(part == ".env" or part.startswith(".env.") for part in relative.parts):
            continue
        result.append(relative)
    return sorted(result)


def build_bundle(
    root: Path,
    upstream: Path,
    output: Path,
    expected_upstream_sha: str = UPSTREAM_COMMIT,
) -> dict:
    root, upstream, output = root.resolve(), upstream.resolve(), output.resolve()
    if not (root / "pubspec.yaml").is_file():
        raise ValueError("RAD source repository not found")
    if not (upstream / "docker/docker-compose.yml").is_file():
        raise ValueError("official Docker Compose source not found")
    if git(upstream, "rev-parse", "HEAD") != expected_upstream_sha:
        raise ValueError("official Docker source commit does not match pinned release")
    if output.exists():
        raise FileExistsError("refusing to overwrite existing bundle")
    if output.is_relative_to(root) or output.is_relative_to(upstream):
        raise ValueError("output must be outside source and upstream trees")

    tracked = tracked_app_paths(root)
    migrations = [p for p in tracked if p.parts[:2] == ("supabase", "migrations")]
    entries = [
        p
        for p in tracked
        if p.parts[:2] == ("supabase", "functions") and p.name == "index.ts"
    ]
    if not migrations or not entries:
        raise ValueError("missing tracked migrations or Edge Function entry points")
    output.parent.mkdir(parents=True, exist_ok=True)

    with TemporaryDirectory(prefix="rad-selfhost-build-", dir=output.parent) as temp:
        stage = Path(temp) / "bundle"
        shutil.copytree(
            upstream / "docker",
            stage,
            ignore=shutil.ignore_patterns(".env", ".env.functions"),
        )

        hashed = {}
        for relative in tracked:
            src = root.joinpath(*relative.parts)
            if (
                src.is_symlink()
                or not src.is_file()
                or not src.resolve().is_relative_to(root)
            ):
                raise ValueError("invalid or escaped tracked RAD source path")
            if relative.parts[1] == "functions":
                dest = stage / "volumes/functions" / Path(*relative.parts[2:])
            else:
                dest = stage / "rad_migrations" / relative.name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dest)
            digest = hashlib.sha256(src.read_bytes()).hexdigest()
            if hashlib.sha256(dest.read_bytes()).hexdigest() != digest:
                raise OSError("staged RAD source bytes differ from tracked source")
            hashed[relative.as_posix()] = digest

        if any(stage.rglob(".env")) or any(stage.rglob(".env.functions")):
            raise ValueError("bundle unexpectedly contains live environment files")
        manifest = {
            "status": "OFFLINE_BUNDLE_ONLY_NOT_MIGRATION_OR_RELEASE_ACCEPTANCE",
            "rad_commit": git(root, "rev-parse", "HEAD"),
            "official_self_hosted_commit": expected_upstream_sha,
            "migration_count": len(migrations),
            "edge_function_names": sorted(p.parts[2] for p in entries),
            "tracked_app_file_sha256": dict(sorted(hashed.items())),
            "required_acceptance": [
                "validated_fresh_postgres17_schema_reconstruction",
                "edge_gateway_jwt_and_cron_parity",
                "auth_rls_storage_and_draft_persistence",
                "secret_mail_and_ai_provider_configuration",
                "disposable_backup_restore_and_upgrade_test",
                "manual_employer_scope_acceptance",
            ],
        }
        (stage / "RAD_BUNDLE_MANIFEST.json").write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf8"
        )
        (stage / "RAD_NOT_READY_FOR_DEPLOYMENT.txt").write_text(
            "Offline sources only. Do not run rad_migrations blindly or expose example secrets.\n"
            "Complete the acceptance gates in RAD_BUNDLE_MANIFEST.json first.\n",
            encoding="utf8",
        )
        stage.rename(output)
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root", type=Path, default=Path(__file__).resolve().parents[1]
    )
    parser.add_argument("--upstream", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = build_bundle(args.root, args.upstream, args.output)
    print(
        json.dumps(
            {
                "status": result["status"],
                "rad_commit": result["rad_commit"],
                "official_self_hosted_commit": result["official_self_hosted_commit"],
                "migration_count": result["migration_count"],
                "edge_function_names": result["edge_function_names"],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
