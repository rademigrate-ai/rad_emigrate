#!/usr/bin/env python3
"""Non-mutating RAD Supabase recorded-SQL fingerprint comparison.

Accepts *metadata only* (version/name/count/hash) from a read-only export.
Matching fingerprints support text parity, NOT SQL execution semantics or
production rollout authorization. No network/database access and no writes.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

FILE = re.compile(r"^(?P<version>[0-9]{14})_(?P<name>[a-z0-9_]+)\.sql$")

def variants(text: str) -> set[str]:
    # Postgres btrim without explicit character set removes ASCII spaces,
    # not newlines/tabs. Respect that when mirroring captured hash variants.
    lf = text.replace("\r\n", "\n")
    # The Supabase history API may omit trailing file newlines. These are
    # insignificant only *after* the closing SQL statement, so we compare
    # both the original and file-tail-whitespace canonical forms.
    inputs = (text, text.strip(" "), lf, lf.strip(" "),
              text.rstrip(), lf.rstrip())
    return {hashlib.md5(s.encode("utf-8")).hexdigest() for s in inputs}

def inspect(root: Path, observed: dict) -> dict:
    rows = observed["rows"]
    if len(rows) != len({r["version"] for r in rows}):
        raise ValueError("duplicate observed migration versions")
    if len(rows) != len({r["name"] for r in rows}):
        raise ValueError("duplicate observed migration names")
    repo = {}
    for p in (root / "supabase" / "migrations").glob("*.sql"):
        m = FILE.fullmatch(p.name)
        if not m:
            raise ValueError(f"unexpected migration filename: {p.name}")
        if m["name"] in repo:
            raise ValueError(f"duplicate local migration name: {m['name']}")
        repo[m["name"]] = {"version":m["version"],"path":p}

    results = []
    for r in rows:
        f = repo.get(r["name"])
        result = {"name":r["name"],"live_version":r["version"],
                  "repo_version": f["version"] if f else None,
                  "version_alias": bool(f and f["version"] != r["version"]),
                  "recorded_statement_count":r["statement_count"]}
        if not f:
            result["sql_parity"] = "NO_REPO_NAME"
        elif r["statement_count"] != 1:
            result["sql_parity"] = "MULTI_OR_EMPTY_STATEMENTS_NOT_COMPARABLE"
        else:
            local = f["path"].read_text(encoding="utf-8")
            hashed = variants(local)
            observed_hashes = {r[k] for k in ("md5_first","md5_trim","md5_lf","md5_lf_trim","md5_tail_trim")}
            result["sql_parity"] = ("FINGERPRINT_MATCH" if hashed & observed_hashes
                                    else "TEXT_DIFFERENCE_OR_STORAGE_FORMAT")
            result["repository_file"] = f["path"].name
            result["repo_utf8_bytes"] = len(local.encode("utf-8"))
            result["live_first_chars"] = r["first_length"]
        results.append(result)

    known = {r["name"] for r in rows}
    counts = {}
    for row in results:
        counts[row["sql_parity"]] = counts.get(row["sql_parity"],0)+1
    return {
        "status":"NO_GO",  # NEVER authorize database deployment from hash parity
        "baseline_live_count":len(rows),
        "repo_migration_count":len(repo),
        "match_counts":counts,
        "version_alias_count":sum(r["version_alias"] for r in results),
        "repo_only_names":sorted(set(repo)-known),
        "results":results,
        "meaning":"Only SQL-text hash comparison. MD5 matching is not a cryptographic equivalence certificate; historical effects, ancillary DDL/data, and catalog drift need separate verification.",
    }

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root",type=Path,default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--observed",type=Path,required=True)
    args = parser.parse_args()
    result=inspect(args.repo_root,json.loads(args.observed.read_text(encoding="utf-8")))
    print(json.dumps(result,indent=2,ensure_ascii=False))
    raise SystemExit(2)

if __name__=="__main__":
    main()
