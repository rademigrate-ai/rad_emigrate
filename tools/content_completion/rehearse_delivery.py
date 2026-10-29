"""Rollback-only rehearsal on an explicitly named loopback fixture database.

This is never hosted-backup or managed Supabase restore evidence.
"""

import argparse
import gzip
import hashlib
import json
import os
import re
import subprocess
import time
from pathlib import Path

from tools.content_consolidation.regression import quote
from tools.plan3_content.dataset import read_jsonl


def rehearse(directory, psql, database, port):
    if (
        not re.fullmatch(r"rad_content_[a-z0-9_]+", database)
        or not 1024 <= port <= 65535
    ):
        raise ValueError("owned_loopback_fixture_required")
    sql = gzip.decompress(
        (directory / "import-review/PROPOSED_IMPORT_REVIEW_ONLY.sql.gz").read_bytes()
    ).decode()
    rollback = gzip.decompress(
        (directory / "import-review/PROPOSED_ROLLBACK_REVIEW_ONLY.sql.gz").read_bytes()
    ).decode()
    plan = json.loads(
        (directory / "import-review/import-plan.json").read_text(encoding="utf-8")
    )
    if (
        hashlib.sha256(sql.encode()).hexdigest() != plan["sql_sha256"]
        or hashlib.sha256(rollback.encode()).hexdigest() != plan["rollback_sql_sha256"]
    ):
        raise ValueError("reviewed_sql_hash_mismatch")
    main = sql[
        sql.index("do $recovery$") : sql.index("end $recovery$;")
        + len("end $recovery$;")
    ]
    body = sql.replace(
        "begin;\n",
        "begin;\ncreate temporary table recovery_heads_before on commit drop as select * from public.visa_article_heads;\ncreate temporary table recovery_catalog_before on commit drop as select * from private.rad_editorial_catalog;\n",
        1,
    ).removesuffix("commit;\n")
    body += "create temporary table recovery_counts_once as select (select count(*) from public.visa_article_revisions) revisions,(select count(*) from private.rad_editorial_rich_revisions) rich,(select count(*) from public.source_snapshots) snapshots;\n"
    body += (
        "update private.rad_editorial_import_target set enabled=true where project_ref='epolbumcfbohtmgvomki';\nselect set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);\n"
        + main
    )
    body += "do $$begin if exists(select 1 from recovery_counts_once where revisions<>(select count(*) from public.visa_article_revisions) or rich<>(select count(*) from private.rad_editorial_rich_revisions) or snapshots<>(select count(*) from public.source_snapshots)) then raise exception 'exact_retry_created_duplicates';end if;end$$;\n"
    retirements = read_jsonl(directory / "prepared/source-reading-retirements.jsonl.gz")
    for row in retirements:
        a = row["article_id"]
        body += f"do $$begin if not exists(select 1 from private.rad_editorial_catalog where article_id='{a}' and not active) or not exists(select 1 from recovery_heads_before b join private.rad_editorial_rich_revisions r on r.revision_id=b.head_id where b.article_id='{a}') then raise exception 'duplicate_reader_retirement_lost_history';end if;end$$;\n"
    # Simulate a human link approval inside a subtransaction. The import must
    # conflict, and the injected review itself is rolled back by that exception.
    if retirements:
        a = retirements[0]["article_id"]
        body += (
            "select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);\n"
            f"do $review_guard$begin insert into private.rad_editorial_country_titles(country_code,article_id,state) values('CA','{a}','approved') on conflict(country_code,article_id) do update set state='approved';execute "
            + quote(main)
            + ";raise exception 'human_review_not_protected';exception when raise_exception then if sqlerrm<>'duplicate_reader_changed_or_reviewed' then raise;end if;end$review_guard$;\n"
        )
    with gzip.open(
        directory / "prepared/new-draft-payloads.jsonl.gz", "rt", encoding="utf-8"
    ) as stream:
        first = json.loads(next(stream))
    first["item"]["title"] += " SYNTHETIC conflict input"
    args = ",".join(
        [
            quote(plan["batch_id"]),
            quote(plan["manifest_sha256"]),
            quote(plan["actor_id"]),
            quote(json.dumps(first["item"], ensure_ascii=False)) + "::jsonb",
            quote(json.dumps(first["sources"], ensure_ascii=False)) + "::jsonb",
        ]
    )
    body += (
        "select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);\ndo $conflict$begin begin perform public.import_editorial_draft("
        + args
        + ");raise exception 'changed_input_not_rejected';exception when sqlstate 'PT409' then null;end;end$conflict$;\n"
    )
    body += (
        "update private.rad_editorial_import_target set enabled=false where project_ref='epolbumcfbohtmgvomki';\n"
        + rollback.split("begin;\n", 1)[1].removesuffix("commit;\n")
    )
    body += "do $$begin if exists(select 1 from recovery_heads_before b left join public.visa_article_heads h using(article_id,locale) where h.head_id is distinct from b.head_id or h.published_id is distinct from b.published_id) then raise exception 'rollback_did_not_restore_original_heads';end if;if exists(select 1 from recovery_catalog_before b join private.rad_editorial_catalog c using(article_id) where to_jsonb(c) is distinct from to_jsonb(b)) then raise exception 'rollback_did_not_restore_original_catalog';end if;end$$;\nrollback;\n"
    started = time.monotonic()
    environment = {
        k: v for k, v in os.environ.items() if not k.upper().startswith("PG")
    }
    environment.update(
        PGHOSTADDR="127.0.0.1", PGCONNECT_TIMEOUT="5", PGCLIENTENCODING="UTF8"
    )
    result = subprocess.run(
        [
            str(psql),
            "-h",
            "127.0.0.1",
            "-p",
            str(port),
            "-U",
            "postgres",
            "-d",
            database,
            "-XAtq",
            "-w",
            "-v",
            "ON_ERROR_STOP=1",
        ],
        input=body,
        capture_output=True,
        encoding="utf-8",
        timeout=180,
        env=environment,
    )
    (directory / "retry-rollback-rehearsal.log").write_text(
        result.stdout + result.stderr, encoding="utf-8"
    )
    receipt = {
        "scope": "local restored synthetic-Auth fixture with preserved source corpus; NOT hosted backup evidence",
        "exit_code": result.returncode,
        "seconds": round(time.monotonic() - started, 2),
        "sql_sha256": plan["sql_sha256"],
        "rollback_sql_sha256": plan["rollback_sql_sha256"],
        "exact_retry_no_duplicates": result.returncode == 0,
        "changed_input_rejected": result.returncode == 0,
        "rollback_restores_all_original_heads": result.returncode == 0,
        "rollback_restores_original_catalog": result.returncode == 0,
        "duplicate_reader_history_preserved": result.returncode == 0,
        "reviewed_link_blocks_retirement": result.returncode == 0,
        "hosted_executed": False,
    }
    (directory / "retry-rollback-rehearsal.json").write_text(
        json.dumps(receipt, indent=2) + "\n", encoding="utf-8"
    )
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--psql", type=Path, required=True)
    parser.add_argument("--database", required=True)
    parser.add_argument("--port", type=int, required=True)
    args = parser.parse_args()
    receipt = rehearse(args.directory, args.psql, args.database, args.port)
    print(json.dumps(receipt))
    raise SystemExit(0 if receipt["exit_code"] == 0 else 1)
