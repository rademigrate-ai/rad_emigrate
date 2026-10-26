"""Emit reviewable, journaled, staging-only draft import SQL.

No network or hosted credentials are used. Execute generated files through an
authorized staging Management API connection. Never point them at Production.
"""

import argparse
import hashlib
import json
from pathlib import Path
from uuid import UUID

from tools.plan3_content.dataset import read_jsonl, uid, write_jsonl

from .import_payload import payload
from .regression import quote
from .verify import verify

PROJECT = "epolbumcfbohtmgvomki"


def batch_sql(items, batch_id, manifest_hash, actor):
    calls = []
    for item in items:
        calls.append(
            "perform public.import_editorial_draft("
            + ",".join(
                [
                    quote(batch_id) + "::uuid",
                    quote(manifest_hash),
                    quote(actor) + "::uuid",
                    quote(
                        json.dumps(
                            item["item"], ensure_ascii=False, separators=(",", ":")
                        )
                    )
                    + "::jsonb",
                    quote(
                        json.dumps(
                            item["sources"], ensure_ascii=False, separators=(",", ":")
                        )
                    )
                    + "::jsonb",
                ]
            )
            + ");"
        )
    body = "\n".join(calls)
    counter = 0
    delimiter = "$rad_import_0$"
    while delimiter in body:
        counter += 1
        delimiter = f"$rad_import_{counter}$"
    return (
        "begin;\nset local standard_conforming_strings=on;\nset local statement_timeout='120s';\nselect set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);\ndo "
        + delimiter
        + "begin\n"
        + body
        + "\nend "
        + delimiter
        + ";\ncommit;\nselect count(*) as imported_locales from private.rad_editorial_import_journal where batch_id="
        + quote(batch_id)
        + "::uuid;\n"
    )


def prepare(directory, output, project, actor, batch_size=10):
    if project != PROJECT:
        raise ValueError("staging_project_only")
    UUID(actor)
    if not 1 <= batch_size <= 50:
        raise ValueError("batch_size_out_of_range")
    verification = verify(directory)
    registry = json.loads(
        Path("supabase/contracts/rad_v1.json").read_text(encoding="utf8")
    )
    sources = {s["source_id"]: s for s in read_jsonl(directory / "sources.jsonl.gz")}
    manifest_hash = hashlib.sha256(
        (directory / "manifest.json").read_bytes()
    ).hexdigest()
    batch_id = uid("rad-editorial-staging-v3:" + project + ":" + manifest_hash)
    rows = [
        payload(a, sources, registry)
        for a in read_jsonl(directory / "articles.jsonl.gz")
    ]
    ready = [r for r in rows if r["status"] == "technical_draft_only"]
    blocked = [r for r in rows if r["status"] != "technical_draft_only"]
    output.mkdir(parents=True, exist_ok=True)
    write_jsonl(output / "payloads.jsonl.gz", ready)
    (output / "blocked.json").write_text(
        json.dumps(blocked, ensure_ascii=False, indent=2), encoding="utf8"
    )
    paths = []
    for start in range(0, len(ready), batch_size):
        path = output / f"batch-{start // batch_size:03d}.sql"
        path.write_text(
            batch_sql(
                ready[start : start + batch_size], batch_id, manifest_hash, actor
            ),
            encoding="utf8",
        )
        paths.append(
            {
                "file": path.name,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "locales": len(ready[start : start + batch_size]),
            }
        )
    result = {
        "project": project,
        "batch_id": batch_id,
        "manifest_hash": manifest_hash,
        "actor_id": actor,
        "technical_draft_locales": len(ready),
        "blocked_locales": len(blocked),
        "verified_legal_claims": 0,
        "human_approved_articles": 0,
        "publication_ready": 0,
        "verification": verification,
        "batches": paths,
    }
    (output / "import-plan.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf8"
    )
    (output / "rollback.sql").write_text(
        "begin;\nselect set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);\nselect public.rollback_editorial_import("
        + quote(batch_id)
        + "::uuid);\ncommit;\n",
        encoding="utf8",
    )
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--project-ref", required=True)
    parser.add_argument("--actor-id", required=True)
    parser.add_argument("--batch-size", type=int, default=10)
    args = parser.parse_args()
    result = prepare(
        args.directory, args.output, args.project_ref, args.actor_id, args.batch_size
    )
    print(json.dumps({k: v for k, v in result.items() if k != "batches"}))
