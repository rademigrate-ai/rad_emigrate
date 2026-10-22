-- Observe only. A zero count is necessary, never sufficient for release.
begin transaction read only;
select count(*) prohibited_effective_client_table_capabilities
from pg_class c join pg_namespace n on n.oid=c.relnamespace
cross join(values('anon'),('authenticated'))r(name)
cross join(values('TRUNCATE'),('REFERENCES'),('TRIGGER'),('MAINTAIN'))p(name)
where n.nspname='public' and c.relkind in('r','p') and has_table_privilege(r.name,c.oid,p.name);

select count(*) tables_with_effective_client_column_references
from pg_class c join pg_namespace n on n.oid=c.relnamespace
cross join(values('anon'),('authenticated'))r(name)
where n.nspname='public' and c.relkind in('r','p') and has_any_column_privilege(r.name,c.oid,'REFERENCES');

select count(*) public_tables_with_rls_disabled from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind in('r','p') and not c.relrowsecurity;

select count(*) definers_without_fixed_search_path from pg_proc p
join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','private')
and p.prosecdef and not exists(select 1 from unnest(p.proconfig) x where x like 'search_path=%');

select r.rolname,has_table_privilege(r.rolname,'vault.decrypted_secrets','SELECT') vault_decrypted_read
from pg_roles r where r.rolname in('anon','authenticated');
select id,public,file_size_limit,allowed_mime_types from storage.buckets where id='documents';
select count(*) ledger_versions from supabase_migrations.schema_migrations;
select 'REQUIRED: exact approved ledger+catalog parity, client/worker RPC ACL allowlist, human publish, quota, real two-user Auth/Storage and evidence regressions under separately authorized acceptance' remaining_gates;
commit;
