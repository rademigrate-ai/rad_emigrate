#!/usr/bin/env python3
"""Read-only migration-history drift preflight for RAD Supabase.

No database connections and no repair/push capability. This is a stop gate:
matching logical names do NOT prove matching SQL effects.
"""
import argparse
import json
import re
from pathlib import Path

FILENAME = re.compile(r"^(\d{14})_([a-z0-9_]+)\.sql$")


def load_live(path: Path):
    raw = json.loads(path.read_text(encoding="utf-8"))
    rows = raw.get("migrations") if isinstance(raw, dict) else raw
    if not isinstance(rows, list):
        raise ValueError("Expected a migrations list")
    answer = []
    for row in rows:
        version, name = str(row["version"]), str(row["name"])
        if not re.fullmatch(r"\d{14}", version) or not re.fullmatch(r"[a-z0-9_]+", name):
            raise ValueError("Malformed live migration identifier")
        answer.append({"version": version, "name": name})
    return answer


def load_repo(root: Path):
    folder = root / "supabase" / "migrations"
    result = []
    for file in sorted(folder.glob("*.sql")):
        found = FILENAME.fullmatch(file.name)
        if not found:
            raise ValueError("Unexpected repository migration filename: " + file.name)
        result.append({"version": found.group(1), "name": found.group(2), "file": file.name})
    return result


def unique(rows, key, kind):
    values = [r[key] for r in rows]
    if len(values) != len(set(values)):
        raise ValueError("Duplicate " + key + " in " + kind)
    return {r[key]: r for r in rows}


def compare(live, repo):
    lv = unique(live, "version", "live history")
    ln = unique(live, "name", "live history")
    rv = unique(repo, "version", "repository")
    rn = unique(repo, "name", "repository")
    exact = []
    aliases = []
    live_only = []
    for applied in live:
        local = rn.get(applied["name"])
        if local is None:
            live_only.append(applied)
        elif applied["version"] == local["version"]:
            exact.append(applied)
        else:
            aliases.append({
                "name": applied["name"],
                "live_version": applied["version"],
                "repo_version": local["version"],
            })
    repo_only = [local for local in repo if local["name"] not in ln]
    collisions = [
        {"version": version, "live_name": applied["name"], "repo_name": rv[version]["name"]}
        for version, applied in lv.items()
        if version in rv and applied["name"] != rv[version]["name"]
    ]
    unproven = bool(aliases or live_only or repo_only or collisions)
    return {
        "status": "NO_GO" if unproven else "LEDGER_IDS_MATCH_SCHEMA_STILL_UNVERIFIED",
        "live_count": len(live),
        "repo_count": len(repo),
        "exact_version_and_name": len(exact),
        "version_aliases": aliases,
        "live_only": live_only,
        "repo_only": repo_only,
        "version_collisions": collisions,
        "warning": "This cannot establish SQL/catalog equivalence; never infer that db push or migration repair is safe.",
    }


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--live", type=Path, required=True, help="read-only observed ledger JSON")
    cli.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parent.parent)
    cli.add_argument("--baseline", type=Path, help="optional expected observed ledger snapshot")
    args = cli.parse_args()
    live = load_live(args.live)
    if args.baseline is not None and live != load_live(args.baseline):
        raise SystemExit("NO_GO: observed live ledger differs from pinned read-only baseline")
    result = compare(live, load_repo(args.repo_root))
    print(json.dumps(result, indent=2, ensure_ascii=False))
    if result["status"] == "NO_GO":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
