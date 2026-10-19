"""Production-shaped metadata reconstruction. Refuses hosted DBs and unowned runtimes.

This NEVER executes historical migration SQL. It rebuilds captured objects without
business data, installs a synthetic local-only copy of the observed ledger, and
compares the same catalog queries. Cron is deliberately inactive; no live secret
or production URL is copied into executable schedules. Existing stacks are untouched.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PROJECT = "rad_c002_c003_rehearsal"
PORT = 59322


def q(s: str) -> str:
    return '"' + s.replace('"', '""') + '"'


def lit(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def acl_grants(acl: str | None, target: str, kind: str = "") -> list[str]:
    result = []
    mapping = {"r": "SELECT", "a": "INSERT", "w": "UPDATE", "d": "DELETE",
               "D": "TRUNCATE", "x": "REFERENCES", "t": "TRIGGER", "X": "EXECUTE",
               "U": "USAGE", "C": "CREATE"}
    for entry in (acl or "{}").strip("{}").split(","):
        if "=" not in entry:
            continue
        role, rest = entry.split("=", 1)
        role = q(role) if role else "PUBLIC"
        for privilege, grantable in re.findall(r"([arwdDxtXUC])([*]?)", rest.split("/")[0]):
            result.append(f"GRANT {mapping[privilege]} ON {kind}{target} TO {role}"
                          + (" WITH GRANT OPTION" if grantable else "") + ";")
    return result


def reconstruct(c: dict, history: list[dict]) -> str:
    sql = ["BEGIN;", "SET check_function_bodies = off;", "CREATE SCHEMA IF NOT EXISTS private;"]
    for e in c["extensions"]:
        if e["name"] != "plpgsql":
            if e['schema'] != 'pg_catalog':
                sql.append(f"CREATE SCHEMA IF NOT EXISTS {q(e['schema'])};")
            sql.append(f"CREATE EXTENSION IF NOT EXISTS {q(e['name'])} WITH SCHEMA {q(e['schema'])};")
    by_table = defaultdict(list)
    for a in c["columns"]:
        col = q(a["column_name"]) + " " + a["data_type"]
        if a["identity"]:
            col += " GENERATED " + ("ALWAYS" if a["identity"] == "a" else "BY DEFAULT") + " AS IDENTITY"
        elif a["generated"]:
            col += " GENERATED ALWAYS AS (" + a["default_expression"] + ") STORED"
        if a["not_null"]:
            col += " NOT NULL"
        by_table[(a["schema"], a["table_name"])].append(col)
    for (schema, table), columns in by_table.items():
        sql.append(f"CREATE TABLE {q(schema)}.{q(table)} (" + ",\n".join(columns) + ");")
    for f in c["functions"]:
        sql.append(f["definition"].rstrip(";\n") + ";")
        target = f"{q(f['schema'])}.{q(f['name'])}({f['args']})"
        sql.append(f"ALTER FUNCTION {target} OWNER TO {q(f['owner'])};")
        if f['acl'] is not None:
            sql.append(f"REVOKE ALL ON FUNCTION {target} FROM PUBLIC, anon, authenticated, service_role;")
            sql += acl_grants(f["acl"], target, "FUNCTION ")
    for a in c["columns"]:
        if a["default_expression"] and not a["identity"] and not a["generated"]:
            sql.append(f"ALTER TABLE {q(a['schema'])}.{q(a['table_name'])} ALTER COLUMN {q(a['column_name'])} SET DEFAULT {a['default_expression']};")
    # Primary/unique constraints must precede foreign keys.
    for k in sorted(c["constraints"], key=lambda k: k["type"] == "f"):
        sql.append(f"ALTER TABLE {q(k['schema'])}.{q(k['table_name'])} ADD CONSTRAINT {q(k['name'])} {k['definition']};")
    constraint_indexes = {k["name"] for k in c["constraints"] if k["type"] in ("p", "u", "x")}
    for i in c["indexes"]:
        if i["name"] not in constraint_indexes:
            sql.append(i["definition"] + ";")
    for t in c["tables"]:
        name = f"{q(t['schema'])}.{q(t['name'])}"
        if t["kind"] == "r":
            sql.append(f"ALTER TABLE {name} OWNER TO {q(t['owner'])};")
            if t["rls"]:
                sql.append(f"ALTER TABLE {name} ENABLE ROW LEVEL SECURITY;")
            if t["force_rls"]:
                sql.append(f"ALTER TABLE {name} FORCE ROW LEVEL SECURITY;")
        sql.append(f"REVOKE ALL ON {'SEQUENCE' if t['kind'] == 'S' else 'TABLE'} {name} FROM PUBLIC,anon,authenticated,service_role;")
    for g in c["table_grants"]:
        sql.append(f"GRANT {g['privilege_type']} ON {q(g['schema'])}.{q(g['table_name'])} TO {q(g['grantee'])}"
                   + (" WITH GRANT OPTION" if g["is_grantable"] == "YES" else "") + ";")
    for g in c["column_grants"]:
        cols = ",".join(q(x) for x in g["columns"])
        sql.append(f"GRANT {g['privilege_type']} ({cols}) ON {q(g['schema'])}.{q(g['table_name'])} TO {q(g['grantee'])};")
    for p in c["policies"]:
        table = f"{q(p['schema'])}.{q(p['table_name'])}"
        sql.append(f"DROP POLICY IF EXISTS {q(p['name'])} ON {table};")
        roles = p["roles"] if isinstance(p["roles"], list) else p["roles"].strip("{}").split(",")
        command = "ALL" if p["cmd"] == "*" else p["cmd"]
        stmt = f"CREATE POLICY {q(p['name'])} ON {table} AS {p['permissive']} FOR {command} TO " + ",".join("PUBLIC" if x == "public" else q(x) for x in roles)
        if p["qual"]:
            stmt += f" USING ({p['qual']})"
        if p["with_check"]:
            stmt += f" WITH CHECK ({p['with_check']})"
        sql.append(stmt + ";")
    for t in c["triggers"]:
        sql.append(f"DROP TRIGGER IF EXISTS {q(t['name'])} ON {q(t['schema'])}.{q(t['table_name'])};")
        sql.append(t["definition"] + ";")
        if t["enabled"] == "D":
            sql.append(f"ALTER TABLE {q(t['schema'])}.{q(t['table_name'])} DISABLE TRIGGER {q(t['name'])};")
    for s in c["schemas"]:
        if s["name"] in ("public", "private"):
            sql.append(f"REVOKE ALL ON SCHEMA {q(s['name'])} FROM PUBLIC,anon,authenticated,service_role;")
            sql += acl_grants(s["acl"], q(s["name"]), "SCHEMA ")
    for b in c["storage"]:
        mime = "NULL" if b["allowed_mime_types"] is None else "ARRAY[" + ",".join(lit(m) for m in b["allowed_mime_types"]) + "]::text[]"
        sql.append("INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES ("
                   + f"{lit(b['id'])},{lit(b['id'])},{str(b['public']).lower()},{b['file_size_limit'] or 'NULL'},{mime}) ON CONFLICT(id) DO NOTHING;")
    # Preserve metadata identities, but NEVER install live commands/credentials.
    for job in c["cron"]:
        sql.append(f"SELECT cron.alter_job(cron.schedule({lit(job['jobname'])},{lit(job['schedule'])},'SELECT 1 /* inactive synthetic rehearsal */'),active:=false);")
    sql.append("CREATE SCHEMA IF NOT EXISTS supabase_migrations;")
    sql.append("CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations(version text PRIMARY KEY, statements text[], name text);")
    for h in history:
        statements = "ARRAY[" + ",".join(lit(x) for x in h["statements"]) + "]::text[]"
        sql.append(f"INSERT INTO supabase_migrations.schema_migrations(version,name,statements) VALUES ({lit(h['version'])},{lit(h['name'])},{statements});")
    return "\n".join(sql + ["COMMIT;"])


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("operation", choices=["start", "reconstruct", "compare", "apply", "test", "stop"])
    p.add_argument("--evidence", type=Path, required=True)
    p.add_argument("--runtime", type=Path, required=True)
    p.add_argument("--supabase", type=Path, required=True)
    p.add_argument("--psql", type=Path, default=Path(r"C:\Program Files\PostgreSQL\17\bin\psql.exe"))
    p.add_argument("--sql", type=Path)
    args = p.parse_args()
    runtime = args.runtime.resolve()
    assert runtime != ROOT and ROOT not in runtime.parents, "runtime must be external"
    marker = runtime / "RAD_DISPOSABLE_LOCAL_ONLY.json"
    identity = {"project": PROJECT, "port": PORT, "owner_checkout": str(ROOT)}
    if marker.exists():
        assert json.loads(marker.read_text()) == identity, "wrong runtime owner"
    else:
        assert args.operation == "start" and (not runtime.exists() or not any(runtime.iterdir())), "unowned runtime"
        runtime.mkdir(parents=True, exist_ok=True)
        marker.write_text(json.dumps(identity))
    env = os.environ.copy()
    env["PGPASSWORD"] = "postgres"  # synthetic public local default only
    cli = [str(args.supabase), "--workdir", str(runtime), "--agent", "no"]
    db = [str(args.psql), "-X", "-v", "ON_ERROR_STOP=1", "-h", "127.0.0.1", "-p", str(PORT), "-U", "postgres", "-d", "postgres"]

    def run(command: list[str], input: str | None = None) -> str:
        result = subprocess.run(command, input=input, cwd=runtime, env=env, capture_output=True,
                                text=True, encoding="utf-8", errors="replace", timeout=1800)
        if result.returncode:
            # SQL and CLI logs may contain local keys. Keep raw logs external.
            (runtime / "failure.log").write_text(result.stdout + result.stderr, encoding="utf-8")
            raise RuntimeError(f"command failed, exit={result.returncode}; inspect external failure.log")
        return result.stdout

    catalog = json.loads((args.evidence / "prod_catalog.json").read_text(encoding="utf-8"))
    history = json.loads((args.evidence / "production_recorded_migration_sql.json").read_text(encoding="utf-8"))
    report: dict = {"operation": args.operation, "project": PROJECT, "port": PORT,
                    "source_head": run(["git", "-C", str(ROOT), "rev-parse", "HEAD"]).strip(),
                    "production_mutations": False, "at": datetime.now(timezone.utc).isoformat()}
    try:
        if args.operation == "start":
            sb = runtime / "supabase"
            sb.mkdir(exist_ok=True)
            (sb / "migrations").mkdir(exist_ok=True)
            (sb / "config.toml").write_text(f'''project_id = "{PROJECT}"
[api]
port = {PORT-1}
[db]
port = {PORT}
shadow_port = {PORT-2}
major_version = 17
[studio]
port = {PORT+1}
[inbucket]
port = {PORT+2}
smtp_port = {PORT+3}
pop3_port = {PORT+4}
[auth]
site_url = "http://127.0.0.1:{PORT-1}"
''', encoding="utf-8")
            run([*cli, "start", "--exclude", "studio,postgres-meta,realtime,imgproxy,edge-runtime,logflare,vector,supavisor"])
        elif args.operation == "reconstruct":
            assert run([*db, "-Atc", "select count(*) from information_schema.tables where table_schema='public'"]).strip() == "0", "requires empty owned DB"
            sql = reconstruct(catalog, history)
            (runtime / "production_metadata_baseline.sql").write_text(sql, encoding="utf-8")
            run(db, sql)
            # Observed history files are markers, never executable historical SQL.
            for h in history:
                (runtime / "supabase/migrations" / f"{h['version']}_{h['name']}.sql").write_text("-- Local observed ledger marker; NO historical replay.\n")
            report["baseline_sha256"] = hashlib.sha256(sql.encode()).hexdigest()
            report["observed_versions"] = len(history)
        elif args.operation == "compare":
            queries = json.loads((args.evidence / "catalog_queries.json").read_text(encoding="utf-8"))
            queries['functions'] = """select n.nspname schema,p.proname name,
              pg_get_function_identity_arguments(p.oid) args,pg_get_function_result(p.oid) result,
              p.prosecdef security_definer,p.provolatile volatility,p.proconfig config,
              pg_get_userbyid(p.proowner) owner,p.proacl::text acl,
              has_function_privilege('anon',p.oid,'EXECUTE') anon_exec,
              has_function_privilege('authenticated',p.oid,'EXECUTE') auth_exec,
              has_function_privilege('service_role',p.oid,'EXECUTE') service_exec,
              md5(pg_get_functiondef(p.oid)) definition_md5,pg_get_functiondef(p.oid) definition
              from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname in ('public','private') order by 1,2,3"""
            differences = {}
            dimensions = ["tables", "columns", "constraints", "indexes", "policies", "table_grants", "column_grants", "functions", "triggers", "storage"]
            for dimension in dimensions:
                query = queries[dimension].rstrip().rstrip(";")
                actual = json.loads(run([*db, "-Atc", f"select coalesce(json_agg(r),'[]'::json) from ({query}) r"]))
                expected = json.loads(json.dumps(catalog[dimension]))
                if dimension in ('table_grants','column_grants','triggers'):
                    # Local Storage has newer Iceberg/versioning platform
                    # objects. They are recorded separately, never mistaken for
                    # application parity or silently changed to old definitions.
                    expected_storage = {x.get('table_name') for x in expected if x['schema']=='storage'}
                    platform_extra = [x for x in actual if x['schema']=='storage' and (
                        x.get('table_name') not in expected_storage or x.get('name')=='enforce_versioning_status_transition')]
                    report.setdefault('platform_storage_extras',{})[dimension] = platform_extra
                    actual = [x for x in actual if x not in platform_extra]
                if dimension == 'column_grants':
                    grouped = defaultdict(list)
                    for row in actual:
                        grouped[(row['schema'],row['table_name'],row['grantee'],row['privilege_type'])].append(row['column_name'])
                    actual = [dict(zip(['schema','table_name','grantee','privilege_type'],key),columns=sorted(set(cols))) for key,cols in sorted(grouped.items())]
                if dimension == 'functions':
                    # NULL ACL is PostgreSQL's default owner+PUBLIC execute.
                    for row in expected+actual:
                        acl = row['acl'] or '{postgres=X/postgres,=X/postgres}'
                        row['acl'] = sorted(acl.strip('{}').split(','))
                # MCP serializes PostgreSQL role arrays as {role,...}; psql's
                # row_to_json uses JSON arrays. Normalize representation only.
                if dimension == 'policies':
                    for row in expected:
                        if isinstance(row['roles'],str):
                            row['roles'] = row['roles'].strip('{}').split(',')
                # Catalog row order and duplicate effective grants from distinct
                # grantors do not change effective rights. Preserve full rows.
                canonical = lambda rows: sorted({json.dumps(row,sort_keys=True) for row in rows})
                if canonical(actual) != canonical(expected):
                    differences[dimension] = {"expected": expected, "actual": actual}
            (runtime / "catalog_differences.json").write_text(json.dumps(differences, ensure_ascii=False, indent=2), encoding="utf-8")
            report["dimensions_compared"] = dimensions
            report["different_dimensions"] = list(differences)
            report["deliberate_environment_differences"] = ["extension patch versions", "inactive no-op cron commands", "no Vault secret values", "platform auth/storage schema owned by local Supabase", "no business/user data"]
            if differences:
                raise AssertionError("catalog parity failed: " + ",".join(differences))
            result = run([*cli, "db", "push", "--db-url", f"postgresql://postgres:postgres@127.0.0.1:{PORT}/postgres", "--dry-run"])
            report["zero_historical_pending"] = "up to date" in result.lower()
        elif args.operation in ("apply", "test"):
            assert args.sql and args.sql.resolve().is_relative_to(ROOT), "SQL must belong to this checkout"
            run(db, args.sql.read_text(encoding="utf-8"))
            report["sql"] = str(args.sql.relative_to(ROOT))
            report["sql_sha256"] = hashlib.sha256(args.sql.read_bytes()).hexdigest()
        elif args.operation == "stop":
            run([*cli, "stop", "--no-backup"])
        report["status"] = "PASS"
    except Exception as e:
        report["status"] = "FAIL"
        report["error"] = str(e)
        raise
    finally:
        (runtime / (args.operation + "_report.json")).write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps({k:v for k,v in report.items() if k!='platform_storage_extras'}, indent=2), flush=True)


if __name__ == "__main__":
    main()
