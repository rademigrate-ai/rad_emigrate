-- Metadata only. No Vault values or application/user data.
select jsonb_build_object(
'history', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select version, name from supabase_migrations.schema_migrations order by version) q),
'tables', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select table_schema, table_name
from information_schema.tables
where table_schema in ('public','private') and table_type='BASE TABLE'
order by 1,2) q),
'columns', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select table_schema, table_name, ordinal_position, column_name, data_type,
       udt_schema, udt_name, is_nullable, column_default
from information_schema.columns
where table_schema in ('public','private')
order by 1,2,3) q),
'constraints', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select n.nspname as schema_name, c.relname as table_name,
       con.conname, con.contype, pg_get_constraintdef(con.oid, true) as definition
from pg_constraint con
join pg_class c on c.oid=con.conrelid
join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','private')
order by 1,2,3) q),
'rls', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select n.nspname as schema_name, c.relname as table_name,
       c.relrowsecurity, c.relforcerowsecurity
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where c.relkind='r' and n.nspname in ('public','private')
order by 1,2) q),
'policies', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies where schemaname in ('public','private','storage')
order by 1,2,3) q),
'indexes', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select schemaname, tablename, indexname, indexdef
from pg_indexes where schemaname in ('public','private')
order by 1,2,3) q),
'functions', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select n.nspname as schema_name, p.proname,
       pg_get_function_identity_arguments(p.oid) as identity_args,
       p.prosecdef as security_definer, p.proconfig,
       pg_get_functiondef(p.oid) as definition
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','private')
order by 1,2,3) q),
'triggers', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select n.nspname as schema_name, c.relname as table_name, t.tgname,
       pg_get_triggerdef(t.oid, true) as definition
from pg_trigger t
join pg_class c on c.oid=t.tgrelid
join pg_namespace n on n.oid=c.relnamespace
where not t.tgisinternal and n.nspname in ('public','private','auth','storage')
order by 1,2,3) q),
'table_grants', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select grantee, table_schema, table_name, privilege_type
from information_schema.role_table_grants
where table_schema in ('public','private')
order by 1,2,3,4) q),
'column_grants', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select grantee, table_schema, table_name, column_name, privilege_type
from information_schema.column_privileges
where table_schema in ('public','private')
order by 1,2,3,4,5) q),
'buckets', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select id, public, file_size_limit, allowed_mime_types
from storage.buckets where id='documents') q),
'cron', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select jobid, jobname, schedule, command, active
from cron.job order by jobid) q),
'extensions', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select e.extname, n.nspname as schema_name, e.extversion
from pg_extension e join pg_namespace n on n.oid=e.extnamespace
where e.extname in ('pg_cron','pg_net','vault','uuid-ossp','pgcrypto')
order by e.extname) q),
'vault_metadata', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select name from vault.secrets order by name) q),
'ai_providers', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select count(*) as ai_provider_count from public.ai_providers) q),
'ai_models', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select count(*) as ai_model_count from public.ai_models) q),
'search_providers', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select count(*) as search_provider_count from public.search_providers) q),
'document_processor', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select enabled, secret_id is not null as has_secret
from public.document_processor_config where singleton) q),
'research_sources', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select base_url, allowed_host, authority, enabled, minimum_interval from public.research_sources order by base_url) q),
'schemas', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select nspname, pg_get_userbyid(nspowner) as owner, nspacl::text from pg_namespace where nspname in ('public','private') order by nspname) q),
'types', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select n.nspname, t.typname, e.enumsortorder, e.enumlabel from pg_type t join pg_namespace n on n.oid=t.typnamespace join pg_enum e on e.enumtypid=t.oid where n.nspname in ('public','private') order by 1,2,3) q),
'function_grants', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args, pg_get_userbyid(p.proowner) as owner, coalesce(p.proacl, acldefault('f',p.proowner))::text as acl from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') order by 1,2,3) q),
'table_acl', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select n.nspname,c.relname,pg_get_userbyid(c.relowner) as owner,coalesce(c.relacl,acldefault((case when c.relkind='S' then 's' else 'r' end)::"char",c.relowner))::text as acl from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind in ('r','p','S','v','m') order by 1,2) q),
'views', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select n.nspname,c.relname,c.reloptions,pg_get_viewdef(c.oid,true) as definition from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind in ('v','m') order by 1,2) q),
'sequences', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select schemaname,sequencename,data_type,start_value,min_value,max_value,increment_by,cycle,cache_size from pg_sequences where schemaname in ('public','private') order by 1,2) q),
'default_acl', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select pg_get_userbyid(d.defaclrole) as owner,n.nspname,d.defaclobjtype,d.defaclacl::text from pg_default_acl d left join pg_namespace n on n.oid=d.defaclnamespace where n.nspname in ('public','private') order by 1,2,3) q),
'vault_client_access', (select coalesce(jsonb_agg(to_jsonb(q) order by to_jsonb(q)::text),'[]'::jsonb) from (select r.rolname,has_schema_privilege(r.rolname,'vault','USAGE') as schema_usage,has_table_privilege(r.rolname,'vault.secrets','SELECT') as encrypted_read,has_table_privilege(r.rolname,'vault.decrypted_secrets','SELECT') as decrypted_read from pg_roles r where r.rolname in ('anon','authenticated') order by 1) q)
) as fingerprint;
