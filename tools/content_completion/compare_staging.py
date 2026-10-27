"""Compare all imported Staging rich-section hashes with the sealed corpus.

Uses a read-only Staging metadata export and only SELECT on an owned loopback
PostgreSQL instance for PostgreSQL's canonical JSONB hash formatting.
"""

from __future__ import annotations

import argparse
import gzip
import json
import os
import re
import subprocess
import uuid
from pathlib import Path


def quote(value):
    return "'" + value.replace("'", "''") + "'"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--articles", type=Path, required=True)
    parser.add_argument("--staging-hashes", type=Path, required=True)
    parser.add_argument("--psql", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--local-port", type=int, default=64132)
    parser.add_argument("--local-database", default="rad_stage71_20261026_patch_v2")
    args = parser.parse_args()
    if not 1024 <= args.local_port <= 65535 or not re.fullmatch(
        r"rad_[a-z0-9_]+", args.local_database
    ):
        raise ValueError("owned_loopback_database_required")
    recorded = json.loads(args.staging_hashes.read_text(encoding="utf-8"))
    if recorded.get("project") != "epolbumcfbohtmgvomki":
        raise ValueError("unexpected_staging_project")
    with gzip.open(args.articles, "rt", encoding="utf-8") as stream:
        articles = [json.loads(line) for line in stream]
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith("PG")}
    env.update(PGHOSTADDR="127.0.0.1", PGCONNECT_TIMEOUT="5", PGCLIENTENCODING="UTF8")
    expected = {}
    for offset in range(0, len(articles), 25):
        entries = []
        for article in articles[offset : offset + 25]:
            article_id = str(uuid.UUID(article["article_id"]))
            locale = article["locale"]
            if locale not in ("fa", "en"):
                raise ValueError("unexpected_locale")
            raw = json.dumps(
                article["sections"], ensure_ascii=False, separators=(",", ":")
            )
            entries.append(f"({quote(article_id)},{quote(locale)},{quote(raw)}::jsonb)")
        sql = (
            "select id,locale,encode(extensions.digest(sections::text,'sha256'),'hex') from (values "
            + ",".join(entries)
            + ") t(id,locale,sections);"
        )
        run = subprocess.run(
            [
                str(args.psql),
                f"postgresql://postgres@127.0.0.1:{args.local_port}/{args.local_database}",
                "-XAtq",
                "-F",
                "\t",
                "-v",
                "ON_ERROR_STOP=1",
            ],
            input=sql,
            capture_output=True,
            text=True,
            encoding="utf-8",
            env=env,
            timeout=120,
        )
        if run.returncode:
            raise RuntimeError(run.stderr[-2000:])
        for line in run.stdout.splitlines():
            article_id, locale, checksum = line.split("\t")
            expected[(article_id, locale)] = checksum
    actual = {(str(row["article_id"]), row["locale"]): row for row in recorded["rows"]}
    if len(expected) != len(articles) or len(actual) != len(recorded["rows"]):
        raise ValueError("duplicate_article_locale")
    results = []
    for identity in sorted(expected.keys() | actual.keys()):
        row = actual.get(identity, {})
        checksum = expected.get(identity)
        results.append(
            {
                "article_id": identity[0],
                "locale": identity[1],
                "expected_sections_sha256": checksum,
                "imported_sections_sha256": row.get("imported_sections_sha256"),
                "head_sections_sha256": row.get("head_sections_sha256"),
                "import_matches_corpus": checksum is not None
                and checksum == row.get("imported_sections_sha256"),
                "head_matches_corpus": checksum is not None
                and checksum == row.get("head_sections_sha256"),
                "head_is_imported_revision": bool(row)
                and row.get("head_id") == row.get("revision_id"),
            }
        )
    summary = {
        "article_locales": len(results),
        "matching_imports": sum(r["import_matches_corpus"] for r in results),
        "matching_heads": sum(r["head_matches_corpus"] for r in results),
        "head_is_import": sum(r["head_is_imported_revision"] for r in results),
        "limitations": "Imported section equality does not prove current website coverage, semantic classification, reference maps, human approval or browser rendering.",
    }
    args.output.write_text(
        json.dumps({"summary": summary, "rows": results}, ensure_ascii=False, indent=2)
        + "\n",
        encoding="utf-8",
    )
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
