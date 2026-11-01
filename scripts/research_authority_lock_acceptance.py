"""Explicit native-only concurrent authority-revocation regression.

Creates two small, uniquely named databases from the existing empty synthetic
research schema, reproduces the prior race, applies the forward, and removes only
those exact databases. No hosted connection, browser, provider or real user data.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import time
import uuid
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PSQL = Path(shutil.which("psql") or r"C:\Program Files\PostgreSQL\17\bin\psql.exe")
SOURCE = "rad_research_worker_http_20261031"
MIGRATION = (
    ROOT / "supabase/migrations/20261030221423_rad_bound_refresh_authority_lock.sql"
)
PREVIOUS = (
    ROOT / "supabase/migrations/20261030094141_rad_bound_official_source_refresh.sql"
)
ENV = {k: v for k, v in os.environ.items() if not k.upper().startswith("PG")}
ENV.update(PGHOSTADDR="127.0.0.1", PGCONNECT_TIMEOUT="5", PGCLIENTENCODING="UTF8")
ROOT_ID = "81000000-0000-4000-8000-000000000061"
ARTICLE = "81000000-0000-4000-8000-000000000010"
JOB = "81000000-0000-4000-8000-000000000090"
TOKEN = "81000000-0000-4000-8000-000000000091"
BINDING = "81000000-0000-4000-8000-000000000080"


def args(database: str):
    if database not in ("postgres", SOURCE) and not re.fullmatch(
        r"rad_authority_race_(?:red|green)_[a-f0-9]{10}", database
    ):
        raise ValueError("exact_owned_database_required")
    return [
        str(PSQL),
        "-XqAtw",
        "-h",
        "127.0.0.1",
        "-p",
        "64932",
        "-U",
        "postgres",
        "-d",
        database,
        "-v",
        "ON_ERROR_STOP=1",
    ]


def sql(
    database: str,
    value: str,
    *,
    application: str = "rad_authority_acceptance",
    check: bool = True,
):
    result = subprocess.run(
        args(database),
        check=False,
        input=value,
        text=True,
        encoding="utf-8",
        capture_output=True,
        env={**ENV, "PGAPPNAME": application},
        timeout=30,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    if check and result.returncode:
        raise RuntimeError(result.stderr)
    return result


def scalar(database: str, value: str):
    return sql(database, value).stdout.strip().splitlines()[-1]


def launch(database: str, value: str, application: str):
    return subprocess.Popen(
        args(database) + ["-c", value],
        text=True,
        encoding="utf-8",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={**ENV, "PGAPPNAME": application},
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )


def hold_transaction(database: str, value: str, application: str):
    process = subprocess.Popen(
        args(database),
        text=True,
        encoding="utf-8",
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={**ENV, "PGAPPNAME": application},
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    process.stdin.write("begin;" + value + ";\n")
    process.stdin.flush()
    wait_state(database, application, "state='idle in transaction'")
    return process


def wait_state(database: str, application: str, condition: str):
    for _ in range(80):
        if (
            scalar(
                database,
                f"select exists(select 1 from pg_stat_activity where application_name='{application}' and ({condition}));",
            )
            == "t"
        ):
            return
        time.sleep(0.05)
    raise RuntimeError("expected_concurrent_lock_state_not_observed")


def original_function(name: str):
    source = PREVIOUS.read_text(encoding="utf-8-sig")
    match = re.search(
        r"create function " + re.escape(name) + r"\([\s\S]*?\nend \$\$;", source
    )
    if not match:
        raise ValueError("exact_previous_function_definition_required")
    return match[0].replace("create function", "create or replace function", 1)


def run(runtime: Path, output: Path):
    marker = json.loads((runtime / "RAD_DISPOSABLE_LOCAL_ONLY.json").read_text())
    if (
        marker.get("port") != 64932
        or Path(marker.get("source", "")).resolve() != ROOT.resolve()
    ):
        raise ValueError("exact_owned_native_runtime_required")
    output.mkdir(parents=True, exist_ok=True)
    state = json.loads(
        scalar(
            SOURCE,
            "select jsonb_build_object('users',(select count(*) from auth.users),'jobs',(select count(*) from private.rad_research_jobs),'articles',(select count(*) from public.visa_articles));",
        )
    )
    if state != {"users": 0, "jobs": 0, "articles": 0}:
        raise ValueError("empty_synthetic_template_required")
    fixture = (
        (ROOT / "supabase/tests/rad_bound_official_refresh.sql")
        .read_text(encoding="utf-8-sig")
        .split("create function pg_temp.refresh_text", 1)[0]
    )
    results = {}
    for phase in ("red", "green"):
        database = "rad_authority_race_" + phase + "_" + uuid.uuid4().hex[:10]
        holder = capture = None
        created = False
        try:
            sql("postgres", "create database " + database + " template " + SOURCE + ";")
            created = True
            prior = (
                original_function("public.ingest_bound_official_refresh")
                + "\n"
                + original_function("private.rad_complete_bound_target")
            )
            sql(database, prior)
            if phase == "green":
                sql(database, MIGRATION.read_text(encoding="utf-8-sig"))
                sql(database, MIGRATION.read_text(encoding="utf-8-sig"))
            sql(
                database,
                fixture
                + f"select public.get_bound_official_refresh_targets('{JOB}','{TOKEN}'); commit;",
            )
            snapshots = int(
                scalar(database, "select count(*) from public.source_snapshots;")
            )
            holder_app = "rad_head_holder_" + phase
            capture_app = "rad_capture_" + phase
            holder = hold_transaction(
                database,
                f"select head_id from public.visa_article_heads where article_id='{ARTICLE}' and locale='en' for update",
                holder_app,
            )
            call = f"""begin;
select set_config('request.jwt.claims','{{"role":"service_role"}}',true);
select public.ingest_bound_official_refresh('{JOB}','{TOKEN}','{BINDING}',
 (select expected_revision_id from private.rad_bound_refresh_job_targets where job_id='{JOB}' and binding_id='{BINDING}'),
 (select expected_snapshot_id from private.rad_bound_refresh_job_targets where job_id='{JOB}' and binding_id='{BINDING}'),
 'BEGIN_SOURCE synthetic change during concurrent revocation END_SOURCE',
 encode(convert_to('BEGIN_SOURCE synthetic change during concurrent revocation END_SOURCE','UTF8'),'base64'),
 'https://bound-refresh.example.org/info',200);commit;"""
            capture = launch(database, call, capture_app)
            wait_state(database, capture_app, "wait_event_type='Lock'")
            sql(
                database,
                f"update private.authority_trust_roots set active=false where id='{ROOT_ID}';",
            )
            assert (
                scalar(
                    database,
                    f"select not active from private.authority_trust_roots where id='{ROOT_ID}';",
                )
                == "t"
            )
            holder.communicate("commit;\n\\q\n", timeout=10)
            _stdout, stderr = capture.communicate(timeout=20)
            rows = json.loads(
                scalar(
                    database,
                    "select jsonb_build_object('proposals',(select count(*) from public.visa_research_proposals),'snapshots',(select count(*) from public.source_snapshots),'published',(select count(*) from public.visa_article_heads where published_id is not null));",
                )
            )
            if phase == "red":
                assert (
                    capture.returncode == 0
                    and rows["proposals"] == 1
                    and rows["snapshots"] == snapshots + 1
                ), (stderr, rows)
            else:
                assert (
                    capture.returncode != 0
                    and "official_binding_evidence_required" in stderr
                    and rows["proposals"] == 0
                    and rows["snapshots"] == snapshots
                ), (stderr, rows)
                # The reverse ordering must serialize too: once a valid capture
                # owns proof locks, a revocation cannot commit ahead of it.
                sql(
                    database,
                    f"update private.authority_trust_roots set active=true where id='{ROOT_ID}';",
                )
                holder_app = "rad_proof_holder_green"
                holder = hold_transaction(
                    database,
                    f"select private.rad_lock_bound_refresh_authority((select b from private.rad_official_refresh_bindings b where id='{BINDING}'),'https://bound-refresh.example.org/info')",
                    holder_app,
                )
                blocked = sql(
                    database,
                    f"begin;set local lock_timeout='250ms';update private.authority_trust_roots set active=false where id='{ROOT_ID}';commit;",
                    check=False,
                )
                assert blocked.returncode != 0 and "lock timeout" in blocked.stderr, (
                    blocked.stderr
                )
                assert (
                    scalar(
                        database,
                        f"select active from private.authority_trust_roots where id='{ROOT_ID}';",
                    )
                    == "t"
                )
                holder.communicate("commit;\n\\q\n", timeout=10)
                sql(
                    database,
                    f"update private.authority_trust_roots set active=false where id='{ROOT_ID}';",
                )
                assert (
                    scalar(
                        database,
                        f"select not active from private.authority_trust_roots where id='{ROOT_ID}';",
                    )
                    == "t"
                )
            assert rows["published"] == 0
            results[phase] = {
                "status": "REPRODUCED" if phase == "red" else "PASS",
                "revocation_committed_before_head_release": True,
                "capture_exit_code": capture.returncode,
                "safe_error": "official_binding_evidence_required"
                if phase == "green"
                else None,
                "rows": rows,
                "baseline_snapshots": snapshots,
                "revocation_cannot_overtake_held_proof_lock": phase == "green",
            }
        finally:
            for process in (capture, holder):
                if process is not None and process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
            if created:
                # Exact generated identifier was validated by args(); never a supplied database.
                sql("postgres", "drop database " + database + ";")
    receipt = {
        "status": "PASS",
        "observed_at": datetime.now(UTC).isoformat(),
        "scope": "native_synthetic_concurrent_transactions_only_not_hosted_restore",
        "results": results,
        "migration": MIGRATION.name,
        "migration_sha256": hashlib.sha256(MIGRATION.read_bytes()).hexdigest(),
        "paid_calls": 0,
        "hosted_mutations": 0,
        "owned_temporary_databases_removed": True,
    }
    receipt["forward_exact_retry"] = "PASS"
    receipt["harness_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    (output / "revocation-race-red-green.json").write_text(
        json.dumps(receipt, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    options = parser.parse_args()
    run(options.runtime, options.output)
