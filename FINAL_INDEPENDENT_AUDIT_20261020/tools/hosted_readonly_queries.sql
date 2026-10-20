-- Metadata-only queries used by the final audit. NEVER a migration/repair script.
-- Intended hosted project: inshddthftkhcdosoqcn. No business rows or Vault values.
select version,name,cardinality(statements) statement_count,
       length(statements[1]) first_length,md5(statements[1]) md5_first,
       md5(btrim(statements[1])) md5_trim,
       md5(replace(statements[1],E'\r\n',E'\n')) md5_lf,
       md5(btrim(replace(statements[1],E'\r\n',E'\n'))) md5_lf_trim,
       md5(rtrim(replace(statements[1],E'\r\n',E'\n'),E' \t\r\n')) md5_tail_trim
from supabase_migrations.schema_migrations order by version;

select n.nspname,c.relname,c.relrowsecurity,c.relforcerowsecurity
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','private') and c.relkind='r' order by 1,2;

select table_name,grantee,privilege_type
from information_schema.role_table_grants
where table_schema='public' and grantee in ('anon','authenticated')
  and privilege_type in ('TRUNCATE','TRIGGER','REFERENCES')
order by 1,2,3;

select n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) args,
       p.prosecdef,p.proconfig,md5(pg_get_functiondef(p.oid)) definition_md5,
       has_function_privilege('anon',p.oid,'execute') anon_exec,
       has_function_privilege('authenticated',p.oid,'execute') authenticated_exec,
       has_function_privilege('service_role',p.oid,'execute') service_exec
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','private') order by 1,2,3;

-- The full catalog metadata capture used the existing catalog_queries.json
-- definitions with jsonb aggregation, plus function signatures/config/ACL/hash.
-- Compare representation-normalized rows, not row order or JSON array syntax.
