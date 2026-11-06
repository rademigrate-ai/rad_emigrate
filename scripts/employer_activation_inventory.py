#!/usr/bin/env python3
"""Compare read-only Production metadata with an isolated compiled CMS catalog.

The output is an inventory, never an authorization or an executable migration.
Signatures come from PostgreSQL, rather than being guessed from Dart call names.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

PROJECT = "inshddthftkhcdosoqcn"


def compare(repo: Path, installed: dict, candidate: dict) -> dict:
    if (
        installed.get("project") != PROJECT
        or candidate.get("project") != "LOCAL_SYNTHETIC"
    ):
        raise ValueError("explicit_production_and_isolated_catalogs_required")
    public = [f for f in candidate["functions"] if f["schema"] == "public"]
    known = {f["name"] for f in public}
    references: dict[str, set[str]] = {}
    unresolved: dict[str, set[str]] = {}
    for path in sorted((repo / "lib").rglob("*.dart")):
        text = path.read_text("utf8")
        for match in re.finditer(
            r"(?:[.]rpc|\b_rpc|\b_call|\b_transition)\(\s*['\"]([a-z][a-z0-9_]+)['\"]",
            text,
        ):
            if match[1] not in known:
                unresolved.setdefault(match[1], set()).add(
                    path.relative_to(repo).as_posix()
                )
        # Include selector/wrapper string references as well as direct calls.
        # This is deliberately a conservative dependency inventory, not a claim
        # that every string reference represents an executed request.
        for match in re.finditer(r"['\"]([a-z][a-z0-9_]+)['\"]", text):
            if match[1] in known:
                references.setdefault(match[1], set()).add(
                    path.relative_to(repo).as_posix()
                )
    deployed = {
        (f["schema"], f["name"], f["identity"]): f for f in installed["functions"]
    }
    definitions: dict[str, str] = {}
    for path in sorted((repo / "supabase/migrations").glob("*.sql")):
        for match in re.finditer(
            r"create\s+(?:or\s+replace\s+)?function\s+public[.]([a-z_0-9]+)",
            path.read_text("utf8"),
            re.I,
        ):
            definitions[match[1]] = path.relative_to(repo).as_posix()
    rows = []
    for function in public:
        name = function["name"]
        if name not in references:
            continue
        existing = deployed.get(("public", name, function["identity"]))
        rows.append(
            {
                "name": name,
                "signature": f"public.{name}({function['identity']})",
                "arguments": function["arguments"],
                "result": function["result"],
                "status": "MISSING"
                if existing is None
                else "INSTALLED_SAME_DEFINITION"
                if existing["definition_sha256"] == function["definition_sha256"]
                else "INSTALLED_DIFFERENT_DEFINITION",
                "installed_sha256": existing["definition_sha256"] if existing else None,
                "candidate_sha256": function["definition_sha256"],
                "candidate_owner": function["owner"],
                "candidate_security_definer": function["security_definer"],
                "candidate_grants": function.get("grants"),
                "candidate_settings": function.get("settings"),
                "last_definition_migration": definitions.get(name),
                "client_references": sorted(references[name]),
            }
        )
    history = {r["version"]: r["name"] for r in installed.get("migration_history", [])}
    migrations = [
        {
            "file": p.name,
            "sha256": hashlib.sha256(p.read_bytes()).hexdigest(),
            "version_recorded": p.name[:14] in history,
            "recorded_name": history.get(p.name[:14]),
        }
        for p in sorted((repo / "supabase/migrations").glob("*.sql"))
    ]
    return {
        "production_project": PROJECT,
        "observed_at": installed.get("checked_at"),
        "source_commit": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=repo, text=True
        ).strip(),
        "source_dirty": bool(
            subprocess.check_output(
                ["git", "status", "--porcelain"], cwd=repo, text=True
            ).strip()
        ),
        "execution_allowed": False,
        "employer_acceptance_phase": "AFTER_OWNER_DEPLOYMENT",
        "selection": "Conservative literal references in production Dart, matched against isolated compiled public functions; dynamic wrappers are included by their selector strings.",
        "rpc_inventory": sorted(rows, key=lambda r: r["signature"]),
        "unresolved_client_literals": {
            name: sorted(paths) for name, paths in sorted(unresolved.items())
        },
        "counts": {
            s: sum(r["status"] == s for r in rows)
            for s in (
                "MISSING",
                "INSTALLED_SAME_DEFINITION",
                "INSTALLED_DIFFERENT_DEFINITION",
            )
        },
        "migration_files": migrations,
        "history_warning": "Unmatched timestamps are not an execution list. Production uses the reviewed closure and guarded dependency order; never replay historical SQL or repair its ledger from this report.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--installed", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = compare(
        Path(__file__).resolve().parents[1],
        json.loads(args.installed.read_text("utf8")),
        json.loads(args.candidate.read_text("utf8")),
    )
    args.output.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf8"
    )
    print(json.dumps({"counts": report["counts"], "execution_allowed": False}))


if __name__ == "__main__":
    main()
