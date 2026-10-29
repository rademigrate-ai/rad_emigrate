"""Import/reconcile the complete corpus ONLY on this checkout's marked fixture.

No hosted connection or user-supplied database URL is accepted. The local
bootstrap imports the immutable743-locale baseline before V4 revisions so both
new drafts and preservation of existing content are exercised by the real app.
"""

import argparse
import gzip
import hashlib
import json
import os
import subprocess
from datetime import UTC, datetime
from pathlib import Path

from tools.content_completion.phase_bundle import save_json
from tools.content_completion.prepare_delivery import ACTOR, PROJECT
from tools.content_consolidation.importer import prepare

ROOT = Path(__file__).resolve().parents[2]
PSQL = Path(r"C:\Program Files\PostgreSQL\17\bin\psql.exe")


def connection(runtime):
    runtime = runtime.resolve()
    if runtime != ROOT / "_scratch/v4-runtime":
        raise ValueError("owned_v4_runtime_path_required")
    marker = json.loads((runtime / "RAD_DISPOSABLE_LOCAL_ONLY.json").read_text("utf-8"))
    if marker != {
        "project": "rad_full_content_v4_20261028",
        "source": str(ROOT),
        "port": 64522,
    }:
        raise ValueError("owned_v4_runtime_marker_required")
    environment = {
        k: v for k, v in os.environ.items() if not k.upper().startswith("PG")
    }
    environment.update(
        PGPASSWORD="postgres",
        PGHOSTADDR="127.0.0.1",
        PGCONNECT_TIMEOUT="30",
        PGCLIENTENCODING="UTF8",
    )
    command = [
        str(PSQL),
        "-XAtqw",
        "-v",
        "ON_ERROR_STOP=1",
        "-v",
        "VERBOSITY=terse",
        "-h",
        "127.0.0.1",
        "-p",
        "64522",
        "-U",
        "postgres",
        "-d",
        "postgres",
    ]
    # The exact task-owned container is an alternative local transport when
    # Docker Desktop's Windows TCP forwarding is unavailable after restart.
    # It does not accept a caller-controlled container or remote Docker host.
    if os.environ.get("RAD_V4_LOCAL_CONTAINER_TRANSPORT") == "1":
        if any(os.environ.get(key) for key in ("DOCKER_HOST", "DOCKER_CONTEXT")):
            raise ValueError("local_default_docker_context_required")
        command = [
            r"C:\Program Files\Docker\Docker\resources\bin\docker.exe",
            "exec",
            "-i",
            "supabase_db_rad_full_content_v4_20261028",
            "psql",
            "-XAtqw",
            "-v",
            "ON_ERROR_STOP=1",
            "-v",
            "VERBOSITY=terse",
            "-U",
            "postgres",
            "-d",
            "postgres",
        ]

    def sql(body, timeout=600):
        if isinstance(body, Path):
            with body.open("r", encoding="utf-8") as stream:
                result = subprocess.run(
                    command,
                    stdin=stream,
                    encoding="utf-8",
                    capture_output=True,
                    check=False,
                    env=environment,
                    timeout=timeout,
                )
        else:
            result = subprocess.run(
                command,
                input=body,
                encoding="utf-8",
                capture_output=True,
                check=False,
                env=environment,
                timeout=timeout,
            )
        if result.returncode:
            error = RuntimeError(result.stderr[:2000])
            error.local_stdout = result.stdout
            raise error
        return result.stdout.strip()

    return sql


def bootstrap(runtime, output):
    sql = connection(runtime)
    output.mkdir(parents=True, exist_ok=True)
    existing_plan = output / "import-plan.json"
    plan = (
        json.loads(existing_plan.read_text("utf-8"))
        if existing_plan.exists()
        else prepare(
            ROOT / "artifacts/RAD_CONTENT_CONSOLIDATION_20261026",
            output,
            PROJECT,
            ACTOR,
            10,
        )
    )
    expected_manifest = hashlib.sha256(
        (
            ROOT / "artifacts/RAD_CONTENT_CONSOLIDATION_20261026/manifest.json"
        ).read_bytes()
    ).hexdigest()
    if (
        plan["project"] != PROJECT
        or plan["actor_id"] != ACTOR
        or plan["manifest_hash"] != expected_manifest
    ):
        raise ValueError("local_baseline_plan_changed")
    count = int(sql("select count(*) from public.visa_article_heads;"))
    if count:
        protected = int(
            sql(
                f"select count(*) from public.visa_article_heads h left join private.rad_editorial_import_journal j on j.article_id=h.article_id and j.locale=h.locale where j.batch_id is distinct from '{plan['batch_id']}'::uuid or j.rolled_back_at is not null or h.head_id is distinct from j.revision_id or h.published_id is not null or private.rad_article_state(h.head_id)<>'draft';"
            )
        )
        if protected:
            raise ValueError("local_nonempty_content_requires_reconciliation")
        if count == 743:
            sql(
                "update private.rad_editorial_import_target set enabled=false where project_ref='epolbumcfbohtmgvomki';"
            )
            return {"status": "existing_verified_baseline", "heads": 743}
    sql(
        "insert into private.rad_editorial_import_target(project_ref,enabled) values('epolbumcfbohtmgvomki',true) on conflict(project_ref) do update set enabled=true;"
    )
    logs = (
        json.loads((output / "execution.json").read_text("utf-8"))
        if (output / "execution.json").exists()
        else []
    )
    completed = {row["file"] for row in logs if row.get("status") == "PASS"}
    pending = []
    try:
        for row in plan["batches"]:
            raw = (output / row["file"]).read_bytes()
            if hashlib.sha256(raw).hexdigest() != row["sha256"]:
                raise ValueError("baseline_batch_hash_changed")
            if row["file"] in completed:
                continue
            pending.append((row, raw.decode("utf-8")))
        # Reuse one local connection. Reconnecting for every small batch can
        # time out behind the Windows/Docker TCP proxy under corpus/build load.
        script = "\n".join(
            body + f"\nselect 'V4_BASELINE:{row['file']}';\n" for row, body in pending
        )
        result = ""
        failure = None
        try:
            result = sql(script, timeout=3600) if pending else ""
        except RuntimeError as error:
            result = getattr(error, "local_stdout", "")
            failure = error
        applied = {
            line.removeprefix("V4_BASELINE:")
            for line in result.splitlines()
            if line.startswith("V4_BASELINE:")
        }
        for row, _ in pending:
            if row["file"] not in applied:
                continue
            logs.append(
                {"file": row["file"], "locales": row["locales"], "status": "PASS"}
            )
            save_json(output / "execution.json", logs)
        if failure:
            raise failure
    finally:
        sql(
            "update private.rad_editorial_import_target set enabled=false where project_ref='epolbumcfbohtmgvomki';"
        )
    heads = int(sql("select count(*) from public.visa_article_heads;"))
    if heads != 743:
        raise ValueError("local_baseline_count_mismatch")
    receipt = {
        "status": "PASS",
        "heads": heads,
        "batches": len(logs),
        "runtime": str(runtime),
        "hosted_writes": 0,
        "publication_events": 0,
        "finished_at": datetime.now(UTC).isoformat(),
    }
    save_json(output / "baseline-receipt.json", receipt)
    return receipt


def apply_plan(runtime, directory):
    sql = connection(runtime)
    plan = json.loads((directory / "import-plan.json").read_text("utf-8"))
    if plan["project"] != PROJECT or plan["publication_allowed"]:
        raise ValueError("staging_draft_plan_only")
    if plan.get("blocked") or not plan["operations"]:
        raise ValueError("unblocked_full_local_plan_required")
    script = ROOT / "_scratch/v4-local-apply.sql"
    with script.open("w", encoding="utf-8", newline="\n") as stream:
        for index, operation in enumerate(plan["operations"]):
            raw = gzip.decompress((directory / operation["file"]).read_bytes())
            if hashlib.sha256(raw).hexdigest() != operation["sha256"]:
                raise ValueError("V4_reviewed_operation_hash_changed")
            stream.write(raw.decode("utf-8"))
            stream.write(f"\nselect 'V4_APPLIED:{index}';\n")
    result, failure = "", None
    try:
        result = sql(script, timeout=7200)
    except RuntimeError as error:
        result, failure = getattr(error, "local_stdout", ""), error
    completed = {
        int(line.removeprefix("V4_APPLIED:"))
        for line in result.splitlines()
        if line.startswith("V4_APPLIED:")
    }
    receipts = [
        {
            **operation,
            "executed_at": datetime.now(UTC).isoformat(),
            "status": "PASS",
            "environment": "local:rad_full_content_v4_20261028",
        }
        for index, operation in enumerate(plan["operations"])
        if index in completed
    ]
    save_json(directory / "local-execution.json", receipts)
    if failure:
        raise failure
    if len(receipts) != len(plan["operations"]):
        raise ValueError("missing_local_operation_receipts")
    return {"status": "PASS", "operations": len(receipts), "hosted_writes": 0}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("bootstrap", "apply"))
    parser.add_argument("--runtime", type=Path, default=ROOT / "_scratch/v4-runtime")
    parser.add_argument("--directory", type=Path, required=True)
    args = parser.parse_args()
    result = (
        bootstrap(args.runtime, args.directory)
        if args.mode == "bootstrap"
        else apply_plan(args.runtime, args.directory)
    )
    print(json.dumps(result))
