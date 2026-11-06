#!/usr/bin/env python3
"""Read-only RAD portability inventory. This is NOT a deployment certification."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

MANAGED_URL = re.compile(r"https?://[a-z0-9-]+\.supabase\.co(?:/|\b)", re.IGNORECASE)
EXCLUDED_DIRS = {"tests", "test", "fixtures", "generated", ".git"}


def inspect(root: Path) -> dict:
    root = root.resolve()
    if (
        not (root / "pubspec.yaml").is_file()
        or not (root / "supabase/config.toml").is_file()
    ):
        raise ValueError(
            "Expected RAD repository root with pubspec.yaml and supabase/config.toml"
        )

    migrations = sorted((root / "supabase/migrations").glob("*.sql"))
    functions_root = root / "supabase/functions"
    edge_functions = sorted(
        p.parent.name for p in functions_root.glob("*/index.ts") if p.is_file()
    )
    all_versions = [p.name.split("_", 1)[0] for p in migrations]
    duplicates = sorted(v for v, n in Counter(all_versions).items() if n > 1)

    managed_url_paths: set[str] = set()
    for base, extension in (
        (root / "lib", "*.dart"),
        (functions_root, "*.ts"),
        (root / "web", "*.js"),
    ):
        if not base.exists():
            continue
        for path in base.rglob(extension):
            if EXCLUDED_DIRS.intersection(path.relative_to(base).parts):
                continue
            # Only path names are reported. Never print source lines or secret values.
            if MANAGED_URL.search(path.read_text(encoding="utf-8", errors="replace")):
                managed_url_paths.add(path.relative_to(root).as_posix())

    gates_path = root / "docs/master_execution/acceptance_gates.json"
    gate_summary: dict = {"status": "NOT_AVAILABLE"}
    if gates_path.is_file():
        payload = json.loads(gates_path.read_text(encoding="utf-8"))
        gates = payload.get("gates", [])
        gate_summary = {
            "status": "HISTORICAL_ACCEPTANCE_LEDGER_NOT_CURRENT_PROOF",
            "recorded_date": payload.get("date"),
            "count": len(gates),
            "by_status": dict(
                sorted(Counter(g.get("status", "UNKNOWN") for g in gates).items())
            ),
        }

    deploy = root / "deploy/self-hosted"
    return {
        "classification": "READ_ONLY_STATIC_INVENTORY_NOT_RELEASE_CERTIFICATION",
        "postgres17_local_configured": "major_version = 17"
        in (root / "supabase/config.toml").read_text(encoding="utf-8"),
        "migration_count": len(migrations),
        "duplicate_migration_versions": duplicates,
        "edge_functions": edge_functions,
        "runtime_source_paths_with_literal_managed_supabase_urls": sorted(
            managed_url_paths
        ),
        "self_hosted_deployment_manifest_exists": any(
            (deploy / name).is_file() for name in ("compose.yaml", "docker-compose.yml")
        ),
        "gate_ledger": gate_summary,
        "unverified_operational_gates": [
            "reproducible_clean_self_hosted_install",
            "self_hosted_postgres17_schema_rpc_rbac_storage_parity",
            "real_research_ai_provider_execution_and_secrets",
            "full_employer_journey_and_human_editorial_acceptance",
            "backup_restore_rehearsal_on_disposable_instance",
            "frontend_backend_health_and_security_qa",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root", type=Path, default=Path(__file__).resolve().parents[1]
    )
    args = parser.parse_args()
    try:
        result = inspect(args.root)
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        parser.error(str(exc))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
