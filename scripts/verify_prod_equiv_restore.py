#!/usr/bin/env python3
"""Read-only integrity comparison of two named, disposable PostgreSQL 17 stacks."""

import json
import subprocess


SOURCE = "supabase_db_rad-prod-equivalent-20261013"
RESTORE = "rad-prod-restore-secure-20261013"
SCHEMAS = "('public','private','auth','storage')"


def command(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=90)
    if result.returncode:
        raise RuntimeError(f"{' '.join(args[:3])}: {result.stderr[-500:]}")
    return result.stdout.strip()


def query(container, sql):
    if container not in (SOURCE, RESTORE):
        raise ValueError("unexpected container")
    return command("docker", "exec", container, "psql", "-X", "-v",
                   "ON_ERROR_STOP=1", "-U", "supabase_admin", "-d",
                   "postgres", "-Atc", sql)


def json_query(container, sql):
    return json.loads(query(container, sql))


def check(label, sql):
    source = json_query(SOURCE, sql)
    restored = json_query(RESTORE, sql)
    if source != restored:
        raise RuntimeError(f"{label} mismatch: {source[:2]!r} vs {restored[:2]!r}")
    return len(source)


def main():
    source_version = query(SOURCE, "select current_setting('server_version')")
    restore_version = query(RESTORE, "select current_setting('server_version')")
    assert source_version == restore_version == "17.11"
    network = command("docker", "inspect", RESTORE, "--format",
                      "{{.HostConfig.NetworkMode}}")
    assert network == "none"
    source_dump = command("docker", "exec", SOURCE, "sha256sum",
                          "/tmp/rad_prod_equiv_20261013.dump").split()[0]
    restore_dump = command("docker", "exec", RESTORE, "sha256sum",
                           "/tmp/rad_prod_equiv_20261013.dump").split()[0]
    assert source_dump == restore_dump

    ledger = check("ledger", "select json_agg(json_build_object('version',version,'name',name) "
                   "order by version) from supabase_migrations.schema_migrations")
    assert ledger == 52

    catalog = check("catalog", """select json_agg(x order by kind,schema_name,object_name) from (
      select 'constraint' kind,n.nspname schema_name,c.relname||':'||k.conname object_name,
        pg_get_constraintdef(k.oid,true) definition from pg_constraint k
        join pg_class c on c.oid=k.conrelid join pg_namespace n on n.oid=c.relnamespace
        where n.nspname in ('public','private','storage')
      union all select 'index',n.nspname,c.relname||':'||i.relname,pg_get_indexdef(i.oid)
        from pg_index z join pg_class i on i.oid=z.indexrelid
        join pg_class c on c.oid=z.indrelid join pg_namespace n on n.oid=c.relnamespace
        where n.nspname in ('public','private','storage')
      union all select 'default',n.nspname,c.relname||':'||a.attname,
        pg_get_expr(d.adbin,d.adrelid) from pg_attrdef d
        join pg_attribute a on a.attrelid=d.adrelid and a.attnum=d.adnum
        join pg_class c on c.oid=d.adrelid join pg_namespace n on n.oid=c.relnamespace
        where n.nspname in ('public','private','storage')
      union all select 'extension',e.extnamespace::regnamespace::text,e.extname,e.extversion
        from pg_extension e
      union all select 'bucket','storage',id,coalesce(public::text,'')||':'||
        coalesce(file_size_limit::text,'')||':'||
        coalesce(array_to_string(allowed_mime_types,','),'') from storage.buckets
    ) x""")

    semantic = check("semantic", """select json_agg(x order by kind,schema_name,object_name) from (
      select 'function' kind,n.nspname schema_name,
        p.proname||'('||pg_get_function_identity_arguments(p.oid)||')' object_name,
        md5(regexp_replace(pg_get_functiondef(p.oid),E'\\r','','g'))||':'||
        p.prosecdef::text||':'||coalesce(array_to_string(p.proconfig,','),'') definition
        from pg_proc p join pg_namespace n on n.oid=p.pronamespace
        where n.nspname in ('public','private')
      union all select 'policy',schemaname,tablename||':'||policyname,
        cmd||':'||coalesce(roles::text,'')||':'||coalesce(qual,'')||':'||
        coalesce(with_check,'') from pg_policies
        where schemaname in ('public','private','storage')
      union all select 'trigger',n.nspname,c.relname||':'||t.tgname,
        pg_get_triggerdef(t.oid,true) from pg_trigger t
        join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
        where not t.tgisinternal and n.nspname in ('public','private','storage')
      union all select 'column',n.nspname,c.relname||':'||a.attname,
        format_type(a.atttypid,a.atttypmod)||':'||a.attnotnull::text||':'||
        coalesce(a.attgenerated::text,'') from pg_attribute a
        join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace
        where a.attnum>0 and not a.attisdropped and c.relkind in ('r','p')
          and n.nspname in ('public','private')
      union all select 'rls',n.nspname,c.relname,
        c.relrowsecurity::text||':'||c.relforcerowsecurity::text from pg_class c
        join pg_namespace n on n.oid=c.relnamespace
        where c.relkind in ('r','p') and n.nspname in ('public','private')
    ) x""")

    constraints = check("constraints", """select json_agg(json_build_object(
      'key',n.nspname||'.'||c.relname||':'||k.conname,
      'definition',pg_get_constraintdef(k.oid,true),'validated',k.convalidated)
      order by n.nspname,c.relname,k.conname) from pg_constraint k
      join pg_class c on c.oid=k.conrelid join pg_namespace n on n.oid=c.relnamespace
      where n.nspname in ('public','private','auth','storage')""")
    unvalidated = query(RESTORE, "select count(*) from pg_constraint k "
                        "join pg_class c on c.oid=k.conrelid "
                        "join pg_namespace n on n.oid=c.relnamespace "
                        f"where n.nspname in {SCHEMAS} and not k.convalidated")
    assert unvalidated == "0"

    privileges = check("effective privileges", """select json_agg(x order by
      kind,schema_name,object_name,role_name) from (
      select 'function' kind,n.nspname schema_name,
        p.proname||'('||pg_get_function_identity_arguments(p.oid)||')' object_name,
        r.role_name,has_function_privilege(r.role_name,p.oid,'EXECUTE')::text rights
        from pg_proc p join pg_namespace n on n.oid=p.pronamespace
        cross join (values ('anon'),('authenticated'),('service_role'),('postgres')) r(role_name)
        where n.nspname in ('public','private','auth','storage')
      union all select 'table',n.nspname,c.relname::text,r.role_name,
        has_table_privilege(r.role_name,c.oid,'SELECT')::text||
        has_table_privilege(r.role_name,c.oid,'INSERT')::text||
        has_table_privilege(r.role_name,c.oid,'UPDATE')::text||
        has_table_privilege(r.role_name,c.oid,'DELETE')::text
        from pg_class c join pg_namespace n on n.oid=c.relnamespace
        cross join (values ('anon'),('authenticated'),('service_role'),('postgres')) r(role_name)
        where c.relkind in ('r','p')
          and n.nspname in ('public','private','auth','storage')
    ) x""")

    tables = json_query(SOURCE, "select json_agg(n.nspname||'.'||c.relname "
                        "order by n.nspname,c.relname) from pg_class c "
                        "join pg_namespace n on n.oid=c.relnamespace "
                        "where c.relkind in ('r','p') and n.nspname in "
                        "('public','private','auth','storage','supabase_migrations')")
    quoted = lambda value: '"' + value.replace('"', '""') + '"'
    rows_sql = "select json_agg(x order by key) from (" + " union all ".join(
        f"select '{name}'::text key,count(*)::bigint rows,"
        "md5(coalesce(string_agg(to_jsonb(t)::text,E'\\n' "
        "order by to_jsonb(t)::text),'')) hash "
        f"from {quoted(name.split('.')[0])}.{quoted(name.split('.')[1])} t"
        for name in tables) + ") x"
    source_rows = json_query(SOURCE, rows_sql)
    restored_rows = json_query(RESTORE, rows_sql)
    assert source_rows == restored_rows

    print(json.dumps({"result": "PASS_FULL_LOCAL_RESTORE",
                      "source_postgres": source_version,
                      "restore_postgres": restore_version,
                      "restore_network": network,
                      "dump_sha256": source_dump,
                      "ledger_rows": ledger,
                      "catalog_entries": catalog,
                      "semantic_entries": semantic,
                      "constraints_validated": constraints,
                      "effective_privilege_checks": privileges,
                      "tables_row_count_and_data_hash_equal": len(tables),
                      "total_rows": sum(int(x["rows"]) for x in source_rows)}, indent=2))


if __name__ == "__main__":
    main()
