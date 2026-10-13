#!/usr/bin/env python3
"""Read-only PostgreSQL 17 recovery snapshot and strict source/restore diff.

Production capture requires a separately signed-off approval JSON. This is a
procedural guard, not a substitute for DBA access control. Never commit output:
it contains schema names, privilege maps, Auth counts, and data digests.
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path


SCHEMAS = "('public','private','auth','storage','supabase_migrations')"
ROLES = "(select rolname from pg_roles where rolname not like 'pg_%')"
REQUIRED_SECTIONS = ('schema_scope', 'ledger', 'schemas', 'roles', 'memberships', 'tables',
    'columns', 'functions', 'constraints', 'indexes', 'policies', 'triggers', 'default_acls',
    'extensions', 'buckets', 'acls', 'effective_functions', 'effective_tables', 'effective_columns',
    'effective_schemas', 'effective_sequences', 'effective_types', 'effective_database',
    'views', 'types', 'domain_constraints', 'auth_counts', 'storage_counts', 'storage_inventory')
SNAPSHOT_SQL = f"""
with
ledger as (select coalesce(jsonb_agg(jsonb_build_object('version',version,'name',name,
  'statements_sha256',encode(sha256(convert_to(coalesce(to_jsonb(statements)::text,'null'),'UTF8')),'hex'))
  order by version),'[]'::jsonb) v
  from supabase_migrations.schema_migrations),
schemas as (select coalesce(jsonb_agg(jsonb_build_object('name',nspname,'owner',pg_get_userbyid(nspowner))
  order by nspname),'[]'::jsonb) v from pg_namespace where nspname in {SCHEMAS}),
roles as (select coalesce(jsonb_agg(jsonb_build_object('name',rolname,'login',rolcanlogin,
  'superuser',rolsuper,'bypassrls',rolbypassrls,'inherit',rolinherit,
  'config',rolconfig,'connection_limit',rolconnlimit) order by rolname),'[]'::jsonb) v
  from pg_roles where rolname not like 'pg_%'),
memberships as (select coalesce(jsonb_agg(jsonb_build_object('member',m.rolname,'role',r.rolname,
  'admin_option',a.admin_option,'inherit_option',a.inherit_option,'set_option',a.set_option)
  order by m.rolname,r.rolname),'[]'::jsonb) v from pg_auth_members a
  join pg_roles m on m.oid=a.member join pg_roles r on r.oid=a.roleid
  where m.rolname not like 'pg_%'),
tables as (select coalesce(jsonb_agg(jsonb_build_object('key',n.nspname||'.'||c.relname,
  'kind',c.relkind,'owner',pg_get_userbyid(c.relowner),'rls',c.relrowsecurity,
  'force_rls',c.relforcerowsecurity,'options',c.reloptions,'persistence',c.relpersistence,
  'replica_identity',c.relreplident,'partition_bound',pg_get_expr(c.relpartbound,c.oid))
  order by n.nspname,c.relname),'[]'::jsonb) v
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in {SCHEMAS} and c.relkind in ('r','p','v','m','S')),
columns as (select coalesce(jsonb_agg(jsonb_build_object('key',n.nspname||'.'||c.relname||'.'||a.attname,
  'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull,
  'generated',a.attgenerated,'default',pg_get_expr(d.adbin,d.adrelid))
  order by n.nspname,c.relname,a.attnum),'[]'::jsonb) v
  from pg_attribute a join pg_class c on c.oid=a.attrelid
  join pg_namespace n on n.oid=c.relnamespace
  left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
  where n.nspname in {SCHEMAS} and c.relkind in ('r','p','v','m')
    and a.attnum>0 and not a.attisdropped),
functions as (select coalesce(jsonb_agg(jsonb_build_object(
  'key',n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',
  'body_sha256',encode(sha256(convert_to(replace(pg_get_functiondef(p.oid),E'\\r',''),'UTF8')),'hex'),
  'definer',p.prosecdef,
  'owner',pg_get_userbyid(p.proowner),'config',coalesce(p.proconfig::text,''))
  order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)),'[]'::jsonb) v
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in {SCHEMAS} and p.prokind in ('f','p')),
constraints as (select coalesce(jsonb_agg(jsonb_build_object(
  'key',n.nspname||'.'||c.relname||':'||k.conname,
  'definition',pg_get_constraintdef(k.oid,true),'validated',k.convalidated)
  order by n.nspname,c.relname,k.conname),'[]'::jsonb) v
  from pg_constraint k join pg_class c on c.oid=k.conrelid
  join pg_namespace n on n.oid=c.relnamespace where n.nspname in {SCHEMAS}),
indexes as (select coalesce(jsonb_agg(jsonb_build_object(
  'key',n.nspname||'.'||c.relname||':'||i.relname,'definition',pg_get_indexdef(i.oid))
  order by n.nspname,c.relname,i.relname),'[]'::jsonb) v
  from pg_index x join pg_class i on i.oid=x.indexrelid
  join pg_class c on c.oid=x.indrelid join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in {SCHEMAS}),
policies as (select coalesce(jsonb_agg(jsonb_build_object('key',schemaname||'.'||tablename||':'||policyname,
  'cmd',cmd,'roles',roles,'qual',qual,'with_check',with_check)
  order by schemaname,tablename,policyname),'[]'::jsonb) v
  from pg_policies where schemaname in {SCHEMAS}),
triggers as (select coalesce(jsonb_agg(jsonb_build_object('key',n.nspname||'.'||c.relname||':'||t.tgname,
  'definition',pg_get_triggerdef(t.oid,true),'enabled',t.tgenabled)
  order by n.nspname,c.relname,t.tgname),'[]'::jsonb) v
  from pg_trigger t join pg_class c on c.oid=t.tgrelid
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in {SCHEMAS} and not t.tgisinternal),
defaults as (select coalesce(jsonb_agg(jsonb_build_object('owner',r.rolname,
  'schema',coalesce(n.nspname,'<global>'),'type',d.defaclobjtype,
  'acl',(select jsonb_agg(jsonb_build_object('grantor',pg_get_userbyid(a.grantor),
    'grantee',case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
    'privilege',a.privilege_type,'grantable',a.is_grantable)
    order by pg_get_userbyid(a.grantor),case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
      a.privilege_type) from aclexplode(d.defaclacl) a))
  order by r.rolname,coalesce(n.nspname,'<global>'),d.defaclobjtype),'[]'::jsonb) v
  from pg_default_acl d join pg_roles r on r.oid=d.defaclrole
  left join pg_namespace n on n.oid=d.defaclnamespace),
extensions as (select coalesce(jsonb_agg(jsonb_build_object('name',extname,
  'schema',extnamespace::regnamespace::text,'version',extversion)
  order by extname),'[]'::jsonb) v from pg_extension),
buckets as (select coalesce(jsonb_agg(jsonb_build_object('id',id,'public',public,
  'file_size_limit',file_size_limit,'allowed_mime_types',allowed_mime_types)
  order by id),'[]'::jsonb) v from storage.buckets),
function_privileges as (select coalesce(jsonb_agg(jsonb_build_object(
  'key',n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',
  'role',r.role_name,'execute',has_function_privilege(r.role_name,p.oid,'EXECUTE'))
  order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid),r.role_name),'[]'::jsonb) v
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  cross join (select rolname role_name from pg_roles where rolname in {ROLES}) r
  where n.nspname in {SCHEMAS}),
table_privileges as (select coalesce(jsonb_agg(jsonb_build_object('key',n.nspname||'.'||c.relname,
  'role',r.role_name,'select',has_table_privilege(r.role_name,c.oid,'SELECT'),
  'insert',has_table_privilege(r.role_name,c.oid,'INSERT'),
  'update',has_table_privilege(r.role_name,c.oid,'UPDATE'),
  'delete',has_table_privilege(r.role_name,c.oid,'DELETE'))
  order by n.nspname,c.relname,r.role_name),'[]'::jsonb) v
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  cross join (select rolname role_name from pg_roles where rolname in {ROLES}) r
  where n.nspname in {SCHEMAS} and c.relkind in ('r','p','v','m')),
column_privileges as (select coalesce(jsonb_agg(jsonb_build_object(
  'key',n.nspname||'.'||c.relname||'.'||a.attname,'role',r.role_name,
  'select',has_column_privilege(r.role_name,c.oid,a.attnum,'SELECT'),
  'update',has_column_privilege(r.role_name,c.oid,a.attnum,'UPDATE'))
  order by n.nspname,c.relname,a.attnum,r.role_name),'[]'::jsonb) v
  from pg_attribute a join pg_class c on c.oid=a.attrelid
  join pg_namespace n on n.oid=c.relnamespace
  cross join (select rolname role_name from pg_roles where rolname in {ROLES}) r
  where n.nspname in {SCHEMAS} and c.relkind in ('r','p','v','m')
    and a.attnum>0 and not a.attisdropped),
views as (select coalesce(jsonb_agg(jsonb_build_object('key',n.nspname||'.'||c.relname,
  'definition',pg_get_viewdef(c.oid,true)) order by n.nspname,c.relname),'[]'::jsonb) v
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in {SCHEMAS} and c.relkind in ('v','m')),
types as (select coalesce(jsonb_agg(jsonb_build_object('key',n.nspname||'.'||t.typname,
  'kind',t.typtype,'owner',pg_get_userbyid(t.typowner),'base',format_type(t.typbasetype,t.typtypmod),
  'not_null',t.typnotnull,'default',t.typdefault,
  'enum_labels',(select jsonb_agg(e.enumlabel order by e.enumsortorder) from pg_enum e where e.enumtypid=t.oid),
  'range_subtype',(select format_type(r.rngsubtype,null) from pg_range r where r.rngtypid=t.oid))
  order by n.nspname,t.typname),'[]'::jsonb) v from pg_type t
  join pg_namespace n on n.oid=t.typnamespace where n.nspname in {SCHEMAS} and t.typrelid=0),
domain_constraints as (select coalesce(jsonb_agg(jsonb_build_object(
  'key',n.nspname||'.'||t.typname||':'||k.conname,'definition',pg_get_constraintdef(k.oid,true),
  'validated',k.convalidated) order by n.nspname,t.typname,k.conname),'[]'::jsonb) v
  from pg_constraint k join pg_type t on t.oid=k.contypid
  join pg_namespace n on n.oid=t.typnamespace where n.nspname in {SCHEMAS}),
type_privileges as (select coalesce(jsonb_agg(jsonb_build_object('key',n.nspname||'.'||t.typname,
  'role',r.rolname,'usage',has_type_privilege(r.rolname,t.oid,'USAGE'))
  order by n.nspname,t.typname,r.rolname),'[]'::jsonb) v from pg_type t
  join pg_namespace n on n.oid=t.typnamespace cross join pg_roles r
  where n.nspname in {SCHEMAS} and t.typrelid=0 and r.rolname in {ROLES}),
database_privileges as (select coalesce(jsonb_agg(jsonb_build_object('role',r.rolname,
  'connect',has_database_privilege(r.rolname,current_database(),'CONNECT'),
  'create',has_database_privilege(r.rolname,current_database(),'CREATE'),
  'temp',has_database_privilege(r.rolname,current_database(),'TEMP')) order by r.rolname),'[]'::jsonb) v
  from pg_roles r where r.rolname in {ROLES}),
sequence_privileges as (select coalesce(jsonb_agg(jsonb_build_object('key',n.nspname||'.'||c.relname,
  'role',r.rolname,'usage',has_sequence_privilege(r.rolname,c.oid,'USAGE'),
  'select',has_sequence_privilege(r.rolname,c.oid,'SELECT'),
  'update',has_sequence_privilege(r.rolname,c.oid,'UPDATE')) order by n.nspname,c.relname,r.rolname),'[]'::jsonb) v
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  cross join pg_roles r where r.rolname in {ROLES} and c.relkind='S' and n.nspname in {SCHEMAS}),
acl_items as (
  select 'relation' kind,n.nspname||'.'||c.relname key,a.* from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    cross join lateral aclexplode(coalesce(c.relacl,acldefault(
      case when c.relkind='S' then 'S'::"char" else 'r'::"char" end,c.relowner))) a
    where n.nspname in {SCHEMAS} and c.relkind in ('r','p','v','m','S')
  union all select 'function',n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',a.*
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
    where n.nspname in {SCHEMAS}
  union all select 'column',n.nspname||'.'||c.relname||'.'||x.attname,a.*
    from pg_attribute x join pg_class c on c.oid=x.attrelid
    join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(x.attacl) a
    where n.nspname in {SCHEMAS} and x.attnum>0 and not x.attisdropped
  union all select 'schema',n.nspname,a.* from pg_namespace n
    cross join lateral aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) a
    where n.nspname in {SCHEMAS}
  union all select 'type',n.nspname||'.'||t.typname,a.* from pg_type t
    join pg_namespace n on n.oid=t.typnamespace
    cross join lateral aclexplode(coalesce(t.typacl,acldefault('T',t.typowner))) a
    where n.nspname in {SCHEMAS} and t.typrelid=0
  union all select 'database','<current>',a.* from pg_database d
    cross join lateral aclexplode(coalesce(d.datacl,acldefault('d',d.datdba))) a
    where d.datname=current_database()),
acls as (select coalesce(jsonb_agg(jsonb_build_object('kind',kind,'key',key,
  'grantor',pg_get_userbyid(grantor),'grantee',case when grantee=0 then 'PUBLIC' else pg_get_userbyid(grantee) end,
  'privilege',privilege_type,'grantable',is_grantable)
  order by kind,key,pg_get_userbyid(grantor),grantee=0,pg_get_userbyid(grantee),privilege_type),'[]'::jsonb) v
  from acl_items),
schema_privileges as (select coalesce(jsonb_agg(jsonb_build_object('schema',n.nspname,
  'role',r.role_name,'usage',has_schema_privilege(r.role_name,n.oid,'USAGE'),
  'create',has_schema_privilege(r.role_name,n.oid,'CREATE'))
  order by n.nspname,r.role_name),'[]'::jsonb) v
  from pg_namespace n cross join (select rolname role_name from pg_roles where rolname in {ROLES}) r
  where n.nspname in {SCHEMAS})
select jsonb_build_object('postgres',current_setting('server_version'),
  'database',current_database(),'ledger',ledger.v,'schemas',schemas.v,'roles',roles.v,
  'memberships',memberships.v,'tables',tables.v,'columns',columns.v,
  'functions',functions.v,'constraints',constraints.v,'indexes',indexes.v,
  'policies',policies.v,'triggers',triggers.v,'default_acls',defaults.v,
  'extensions',extensions.v,'buckets',buckets.v,
  'effective_functions',function_privileges.v,
  'effective_tables',table_privileges.v,'effective_columns',column_privileges.v,
  'effective_schemas',schema_privileges.v,'effective_sequences',sequence_privileges.v,'acls',acls.v,
  'effective_types',type_privileges.v,'effective_database',database_privileges.v,
  'views',views.v,'types',types.v,'domain_constraints',domain_constraints.v,
  'auth_counts',jsonb_build_object('users',(select count(*) from auth.users),
    'identities',(select count(*) from auth.identities),
    'sessions',(select count(*) from auth.sessions)),
  'storage_counts',(select coalesce(jsonb_object_agg(bucket_id,cnt),'{{}}'::jsonb)
    from (select bucket_id,count(*) cnt from storage.objects group by bucket_id) s),
  'storage_inventory',(select coalesce(jsonb_agg(jsonb_build_object(
    'key',o.bucket_id||'/'||o.name,'id',o.id::text,'bytes',(o.metadata->>'size')::bigint,
    'mime',o.metadata->>'mimetype','owner',to_jsonb(o)->'owner','owner_id',to_jsonb(o)->'owner_id')
    order by o.bucket_id,o.name),'[]'::jsonb) from storage.objects o))
from ledger,schemas,roles,memberships,tables,columns,functions,constraints,indexes,
  policies,triggers,defaults,extensions,buckets,function_privileges,table_privileges,
  column_privileges,schema_privileges,sequence_privileges,acls,views,types,
  domain_constraints,type_privileges,database_privileges;
"""


def psql_command(args, sql):
    if args.docker_container:
        if not re.fullmatch(r"[A-Za-z0-9_.-]+", args.docker_container):
            raise ValueError("invalid local container name")
        prefix = ["docker", "exec", "-e", "PGTZ=UTC", "-e",
                  "PGOPTIONS=-c default_transaction_read_only=on", args.docker_container,
                  "psql", "-U", "supabase_admin", "-d", args.database]
    else:
        from encrypted_backup import approval, validate_service
        approval(args, "metadata_snapshot")
        validate_service(args)
        prefix = ["psql", "-d", f"service={args.service}"]
    return prefix + ["-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1", "-c", sql]


def run_psql(args, sql):
    env = os.environ.copy()
    env["PGTZ"] = "UTC"
    env["PGOPTIONS"] = env.get("PGOPTIONS", "") + " -c default_transaction_read_only=on"
    result = subprocess.run(psql_command(args, sql), text=True, capture_output=True, env=env,
                            timeout=args.timeout)
    if result.returncode:
        raise RuntimeError(f"psql failed ({result.returncode}): {result.stderr[-1000:]}")
    return result.stdout.strip()


def data_hashes(args):
    listing = run_psql(args, f"select n.nspname||E'\\t'||c.relname from pg_class c "
                       "join pg_namespace n on n.oid=c.relnamespace "
                       f"where n.nspname in {args.schema_sql} and c.relkind in ('r','p') "
                       "and not c.relispartition order by 1")
    result = {}
    for line in listing.splitlines():
        schema, table = line.split("\t", 1)
        qualified = '.'.join('"' + part.replace('"', '""') + '"' for part in (schema, table))
        values = run_psql(args, f"select encode(sha256(convert_to(to_jsonb(t)::text,'UTF8')),'hex') "
                         f"from {qualified} t order by 1")
        dig = hashlib.sha256()
        count = 0
        for value in values.splitlines():
            if not re.fullmatch(r"[0-9a-f]{64}", value):
                raise ValueError(f"unexpected digest output for {schema}.{table}")
            dig.update(value.encode("ascii") + b"\n")
            count += 1
        result[f"{schema}.{table}"] = {"rows": count, "sha256_of_row_sha256s": dig.hexdigest()}
    return result


def sequence_states(args):
    listing = run_psql(args, "select n.nspname||E'\\t'||c.relname from pg_class c "
                       "join pg_namespace n on n.oid=c.relnamespace "
                       f"where n.nspname in {args.schema_sql} and c.relkind='S' order by 1")
    result = {}
    for line in listing.splitlines():
        schema, sequence = line.split("\t", 1)
        qualified = '.'.join('"' + part.replace('"', '""') + '"' for part in (schema, sequence))
        result[f"{schema}.{sequence}"] = json.loads(run_psql(args,
            f"select json_build_object('last_value',last_value,'is_called',is_called) from {qualified}"))
    return result


def capture(args):
    if bool(args.docker_container) == bool(args.service):
        raise ValueError("choose exactly one of --docker-container or --service")
    if args.service and (not args.project_ref or not args.approval_file):
        raise ValueError("service capture requires --project-ref and --approval-file")
    if args.data_hashes and not args.writes_frozen:
        raise ValueError("--data-hashes requires --writes-frozen; DBA must quiesce writers first")
    if args.all_user_schemas:
        scope = json.loads(run_psql(args, "select json_agg(nspname order by nspname) from pg_namespace "
                                   "where nspname not like 'pg_%' and nspname<>'information_schema'"))
    else:
        scope = ['public', 'private', 'auth', 'storage', 'supabase_migrations']
    args.schema_sql = '(' + ','.join("'" + name.replace("'", "''") + "'" for name in scope) + ')'
    value = json.loads(run_psql(args, SNAPSHOT_SQL.replace(SCHEMAS, args.schema_sql)))
    value["format"] = "rad-postgres-recovery-snapshot-v1"
    value["schema_scope"] = scope
    if value["postgres"] != "17.11":
        raise ValueError(f"expected PostgreSQL 17.11, got {value['postgres']}")
    if args.data_hashes:
        value["data_hashes"] = data_hashes(args)
        value["sequence_states"] = sequence_states(args)
        value["large_object_hashes"] = json.loads(run_psql(args,
            "select coalesce(json_agg(json_build_object('oid',oid,"
            "'sha256',encode(sha256(lo_get(oid)),'hex')) order by oid),'[]'::json) from pg_largeobject_metadata"))
    output = json.dumps(value, sort_keys=True, separators=(",", ":"))
    if args.output:
        path = Path(args.output)
        if args.service and path.resolve().is_relative_to(Path(__file__).resolve().parents[2]):
            raise ValueError("production snapshots must be outside the repository")
        if path.exists():
            raise FileExistsError(path)
        with path.open("x", encoding="utf-8") as stream:
            stream.write(output + "\n")
    else:
        print(output)


def compare(args):
    source = json.loads(Path(args.source).read_text(encoding="utf-8"))
    target = json.loads(Path(args.target).read_text(encoding="utf-8"))
    for value in (source, target):
        if value.get("format") != "rad-postgres-recovery-snapshot-v1" or value.get("postgres") != "17.11":
            raise ValueError("unexpected or incomplete snapshot format")
        if any(key not in value for key in REQUIRED_SECTIONS):
            raise ValueError("snapshot is missing required catalog/privilege sections")
    differences = {}
    for key in sorted(set(source) | set(target)):
        if key == "database":
            continue
        if source.get(key) != target.get(key):
            a, b = source.get(key), target.get(key)
            if isinstance(a, list) and isinstance(b, list):
                sa = {json.dumps(v, sort_keys=True) for v in a}
                sb = {json.dumps(v, sort_keys=True) for v in b}
                differences[key] = {"source_only": len(sa - sb), "target_only": len(sb - sa),
                                    "source_only_examples": sorted(sa - sb)[:3],
                                    "target_only_examples": sorted(sb - sa)[:3]}
            else:
                differences[key] = {"source": a, "target": b}
    print(json.dumps({"status": "PASS" if not differences else "FAIL",
                      "verification_scope": "catalog_and_data" if all(k in source and k in target
                        for k in ('data_hashes','sequence_states','large_object_hashes')) else "catalog_only",
                      "differences": differences}, indent=2, sort_keys=True))
    return 0 if not differences else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    cap = sub.add_parser("capture")
    conn = cap.add_mutually_exclusive_group(required=True)
    conn.add_argument("--docker-container")
    conn.add_argument("--service")
    cap.add_argument("--project-ref")
    cap.add_argument("--approval-file")
    cap.add_argument("--database", default="postgres", help="local Docker database name")
    cap.add_argument("--data-hashes", action="store_true")
    cap.add_argument("--all-user-schemas", action="store_true",
                     help="include every non-pg schema; required for a full independent backup")
    cap.add_argument("--writes-frozen", action="store_true")
    cap.add_argument("--output", help="restricted local file; omit to pipe stdout directly into age")
    cap.add_argument("--timeout", type=int, default=300)
    cmp = sub.add_parser("compare")
    cmp.add_argument("--source", required=True)
    cmp.add_argument("--target", required=True)
    args = parser.parse_args()
    try:
        return compare(args) if args.command == "compare" else capture(args)
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
