"""Execute every V4 operation, retry and rollback on a passwordless owned clone.

All generated statements run inside ONE enclosing transaction which is finally
rolled back. Original heads/catalogs must also be restored by the generated
rollback before that enclosing rollback occurs. No hosted address is accepted.
"""

import argparse
import gzip
import hashlib
import json
import os
import re
import subprocess
import urllib.parse
from pathlib import Path

from tools.content_completion.full_pipeline_v4 import compile_operations
from tools.content_completion.phase_bundle import save_json

PSQL = r"C:\Program Files\PostgreSQL\17\bin\psql.exe"
HEAD_QUERY = """select coalesce(jsonb_agg(x),'[]') from(select h.article_id,h.locale,h.head_id,h.published_id,v.revision,v.content_hash,
encode(extensions.digest((rr.composition->'sections')::text,'sha256'),'hex') rich_sections_hash,j.batch_id,c.active catalog_active,c.content_class,c.country_codes,
encode(extensions.digest(to_jsonb(c)::text,'sha256'),'hex') catalog_hash,to_jsonb(a) identity,
(select coalesce(jsonb_agg(to_jsonb(ct) order by country_code),'[]') from private.rad_editorial_country_titles ct where ct.article_id=a.id) country_titles
from public.visa_article_heads h join public.visa_article_revisions v on v.id=h.head_id join public.visa_articles a on a.id=h.article_id
left join private.rad_editorial_catalog c on c.article_id=a.id left join private.rad_editorial_rich_revisions rr on rr.revision_id=v.id
left join private.rad_editorial_import_journal j on j.article_id=h.article_id and j.locale=h.locale order by h.article_id,h.locale)x;"""
SOURCE_QUERY = """select coalesce(jsonb_agg(x),'[]') from(select d.id source_id,d.canonical_url,s.id snapshot_id,s.content_hash,s.metadata->>'raw_html_sha256' raw_html_sha256
from public.source_documents d left join public.source_snapshots s on s.document_id=d.id order by d.id,s.id)x;"""


def local_environment():
    # libpq can prefer PGHOSTADDR over the explicit -h flag. Do not inherit
    # service files, passwords, socket endpoints or connection options.
    environment = {
        key: value
        for key, value in os.environ.items()
        if not key.upper().startswith("PG")
    }
    environment.update(
        PGHOSTADDR="127.0.0.1", PGCONNECT_TIMEOUT="5", PGCLIENTENCODING="UTF8"
    )
    return environment


def local_command(database, docker_container=None):
    if docker_container:
        # A matching container name does not establish locality: ambient Docker
        # settings can select a remote engine with that same name.
        if any(
            os.environ.get(key)
            for key in (
                "DOCKER_HOST",
                "DOCKER_CONTEXT",
                "DOCKER_CONFIG",
                "DOCKER_TLS_VERIFY",
                "DOCKER_CERT_PATH",
            )
        ):
            raise ValueError("local_default_docker_context_required")
        marker = json.loads(
            Path("_scratch/v4-runtime/RAD_DISPOSABLE_LOCAL_ONLY.json").read_text(
                "utf-8"
            )
        )
        if (
            marker["project"] != "rad_full_content_v4_20261028"
            or Path(marker["source"]).resolve() != Path.cwd().resolve()
            or docker_container != "supabase_db_" + marker["project"]
            or database != "postgres"
        ):
            raise ValueError("owned_v4_container_identity_required")
        try:
            endpoint = json.loads(
                subprocess.check_output(
                    [
                        "docker",
                        "--context",
                        "default",
                        "context",
                        "inspect",
                        "default",
                        "--format",
                        "{{json .Endpoints.docker.Host}}",
                    ],
                    text=True,
                    encoding="utf-8",
                    stderr=subprocess.PIPE,
                    timeout=10,
                )
            )
            if not isinstance(endpoint, str):
                raise ValueError("invalid_endpoint")
            parsed = urllib.parse.urlsplit(endpoint)
            local_unix = (
                parsed.scheme == "unix"
                and not parsed.netloc
                and parsed.path.startswith("/")
                and not parsed.path.startswith("//")
                and not parsed.query
                and not parsed.fragment
            )
            local_pipe = re.fullmatch(r"npipe:////\./pipe/[a-zA-Z0-9_.-]+", endpoint)
            if not (local_unix or local_pipe):
                raise ValueError("nonlocal_endpoint")
        except (OSError, ValueError, subprocess.SubprocessError):
            raise ValueError("local_default_docker_endpoint_required") from None
        return [
            "docker",
            "--context",
            "default",
            "exec",
            "-i",
            docker_container,
            "psql",
            "-U",
            "postgres",
            "-d",
            database,
            "-w",
            "-X",
            "-q",
            "-A",
            "-t",
            "-v",
            "ON_ERROR_STOP=1",
        ]
    if not database.startswith("rad_content_v4_"):
        raise ValueError("owned_v4_clone_database_required")
    return [
        PSQL,
        "-h",
        "127.0.0.1",
        "-p",
        "64139",
        "-U",
        "postgres",
        "-d",
        database,
        "-w",
        "-X",
        "-q",
        "-A",
        "-t",
        "-v",
        "ON_ERROR_STOP=1",
    ]


def run(
    composition,
    output,
    database="rad_content_v4_20261028",
    docker_container=None,
    runtime=None,
):
    output.mkdir(parents=True, exist_ok=True)
    execute = None
    if runtime is not None:
        from tools.content_completion.v4_local_import import connection

        if docker_container:
            raise ValueError("runtime_and_docker_transport_are_exclusive")
        execute = connection(runtime)
        marker = json.loads(
            (runtime / "RAD_DISPOSABLE_LOCAL_ONLY.json").read_text("utf-8")
        )
        database = marker.get("database", "postgres")
        command = None
    else:
        command = local_command(database, docker_container)
    environment = local_environment()

    def query(sql):
        if execute is not None:
            return json.loads(execute(sql))
        return json.loads(
            subprocess.check_output(
                [*command, "-c", sql], text=True, encoding="utf-8", env=environment
            )
        )

    save_json(output / "staging-heads-before.json", query(HEAD_QUERY))
    save_json(output / "staging-sources-before.json", query(SOURCE_QUERY))
    compiled = output / "import"
    compile_operations(composition, output, compiled)
    plan = json.loads((compiled / "import-plan.json").read_text("utf-8"))
    if plan["blocked"]:
        raise ValueError(
            "full_rehearsal_has_blocked_operations:" + str(plan["blocked"])
        )
    count = sum(
        r["operation"] in ("new_draft", "guarded_revision") for r in plan["operations"]
    )
    script = output / "full-import-retry-rollback.sql"
    with script.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write("""begin;
set local standard_conforming_strings=on;
create temp table v4_baseline_heads as select article_id,locale,head_id,published_id from public.visa_article_heads where head_id is not null or published_id is not null;
create temp table v4_baseline_catalogs as select article_id,to_jsonb(c) original from private.rad_editorial_catalog c;
""")
        for phase in ("first_import", "idempotent_retry"):
            for index, operation in enumerate(plan["operations"]):
                raw = gzip.decompress((compiled / operation["file"]).read_bytes())
                if hashlib.sha256(raw).hexdigest() != operation["sha256"]:
                    raise ValueError("operation_changed_since_review")
                content = raw.decode("utf-8")
                if not content.endswith("commit;\n") or "begin;\n" not in content:
                    raise ValueError("unexpected_operation_transaction_shape")
                stream.write(content.split("begin;\n", 1)[1].removesuffix("commit;\n"))
                if index % 50 == 0:
                    stream.write(
                        f"\nselect '{phase}:{index}/{len(plan['operations'])}';\n"
                    )
            stream.write(f"""do $$begin
if (select count(*) from public.visa_article_heads h join private.rad_editorial_rich_revisions rr on rr.revision_id=h.head_id where rr.composition->'content_full_v4'->>'manifest'='{plan["manifest_sha256"]}')<>{count} then raise exception 'full_rehearsal_missing_latest_V4_locale';end if;
if exists(select 1 from public.visa_article_heads h full join v4_baseline_heads b on b.article_id=h.article_id and b.locale=h.locale where h.published_id is distinct from b.published_id) then raise exception 'full_rehearsal_unauthorized_publication';end if;
end $$;\n""")
        rollback = (compiled / "rollback.sql").read_text("utf-8")
        stream.write(rollback.split("begin;\n", 1)[1].removesuffix("commit;\n"))
        stream.write("""do $$begin
if exists(select 1 from v4_baseline_heads b left join public.visa_article_heads h on h.article_id=b.article_id and h.locale=b.locale where h.head_id is distinct from b.head_id or h.published_id is distinct from b.published_id) then raise exception 'full_rehearsal_rollback_changed_original_head';end if;
if exists(select 1 from v4_baseline_catalogs b left join private.rad_editorial_catalog c on c.article_id=b.article_id where to_jsonb(c) is distinct from b.original) then raise exception 'full_rehearsal_rollback_changed_original_catalog';end if;
if exists(select 1 from public.visa_article_heads h where h.head_id is not null and not exists(select 1 from v4_baseline_heads b where b.article_id=h.article_id and b.locale=h.locale)) then raise exception 'full_rehearsal_rollback_left_active_new_locale';end if;
if exists(select 1 from private.rad_editorial_import_target where enabled) then raise exception 'full_rehearsal_import_gate_left_enabled';end if;
end $$;
rollback;
select 'PASS_ALL_OPERATIONS_RETRIED_AND_ROLLED_BACK';
""")
    if execute is not None:
        try:
            result = execute(script, timeout=7200)
        except RuntimeError as error:
            (output / "rehearsal.log").write_text(
                getattr(error, "local_stdout", "") + "\n" + str(error), encoding="utf-8"
            )
            raise ValueError("full_corpus_SQL_rehearsal_failed_see_log") from error
        (output / "rehearsal.log").write_text(result, encoding="utf-8")
    else:
        with (
            (output / "rehearsal.log").open("w", encoding="utf-8") as log,
            script.open("rb") as stream,
        ):
            result = subprocess.run(
                command,
                stdin=stream,
                stdout=log,
                stderr=subprocess.STDOUT,
                check=False,
                env=environment,
            )
        if result.returncode:
            raise ValueError("full_corpus_SQL_rehearsal_failed_see_log")
    receipt = {
        "status": "PASS",
        "database": database,
        "docker_container": docker_container,
        "runtime": str(runtime) if runtime is not None else None,
        "operations": len(plan["operations"]),
        "article_locales": count,
        "every_operation_retried": True,
        "original_heads_and_catalogs_restored_by_generated_rollback": True,
        "enclosing_transaction_rolled_back": True,
        "unauthorized_publications": 0,
        "manifest_sha256": plan["manifest_sha256"],
        "log_sha256": hashlib.sha256(
            (output / "rehearsal.log").read_bytes()
        ).hexdigest(),
        "hosted_writes": 0,
    }
    save_json(output / "rehearsal-receipt.json", receipt)
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--composition", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--database", default="rad_content_v4_20261028")
    parser.add_argument("--docker-container")
    parser.add_argument("--runtime", type=Path)
    args = parser.parse_args()
    print(
        json.dumps(
            run(
                args.composition,
                args.output,
                args.database,
                args.docker_container,
                args.runtime,
            )
        )
    )
