-- READ-ONLY reconciliation fingerprint. Never place secret values in output/artifacts.
-- Run against production only as SELECT/catalog inspection.

select version, name from supabase_migrations.schema_migrations order by version;

select table_schema, table_name
from information_schema.tables
where table_schema in ('public','private') and table_type='BASE TABLE'
order by 1,2;

select table_schema, table_name, ordinal_position, column_name, data_type,
       udt_schema, udt_name, is_nullable, column_default
from information_schema.columns
where table_schema in ('public','private')
order by 1,2,3;

select n.nspname as schema_name, c.relname as table_name,
       con.conname, con.contype, pg_get_constraintdef(con.oid, true) as definition
from pg_constraint con
join pg_class c on c.oid=con.conrelid
join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','private')
order by 1,2,3;

select n.nspname as schema_name, c.relname as table_name,
       c.relrowsecurity, c.relforcerowsecurity
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where c.relkind='r' and n.nspname in ('public','private')
order by 1,2;

select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies where schemaname in ('public','private','storage')
order by 1,2,3;

select schemaname, tablename, indexname, indexdef
from pg_indexes where schemaname in ('public','private')
order by 1,2,3;

select n.nspname as schema_name, p.proname,
       pg_get_function_identity_arguments(p.oid) as identity_args,
       p.prosecdef as security_definer, p.proconfig,
       pg_get_functiondef(p.oid) as definition
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','private')
order by 1,2,3;

select n.nspname as schema_name, c.relname as table_name, t.tgname,
       pg_get_triggerdef(t.oid, true) as definition
from pg_trigger t
join pg_class c on c.oid=t.tgrelid
join pg_namespace n on n.oid=c.relnamespace
where not t.tgisinternal and n.nspname in ('public','private','auth','storage')
order by 1,2,3;

select grantee, table_schema, table_name, privilege_type
from information_schema.role_table_grants
where table_schema in ('public','private')
order by 1,2,3,4;

select grantee, table_schema, table_name, column_name, privilege_type
from information_schema.column_privileges
where table_schema in ('public','private')
order by 1,2,3,4,5;

select id, public, file_size_limit, allowed_mime_types
from storage.buckets where id='documents';

select jobid, jobname, schedule, command, active
from cron.job order by jobid;

select e.extname, n.nspname as schema_name, e.extversion
from pg_extension e join pg_namespace n on n.oid=e.extnamespace
where e.extname in ('pg_cron','pg_net','vault','uuid-ossp','pgcrypto')
order by e.extname;

-- Metadata only. DO NOT select decrypted_secret or secret.
select name, description from vault.secrets order by name;

select count(*) as ai_provider_count from public.ai_providers;
select count(*) as ai_model_count from public.ai_models;
select count(*) as search_provider_count from public.search_providers;
select enabled, secret_id is not null as has_secret
from public.document_processor_config where singleton;
select id, name, base_url, enabled from public.research_sources order by id;
