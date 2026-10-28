-- READ ONLY metadata. Not a migration and not authorization to deploy.
select now() as inspected_at, current_setting('server_version') as server_version;
select version,name from supabase_migrations.schema_migrations order by version;
select r.name as role,t.name as table_name,p.name as privilege,
 has_table_privilege(r.name,'public.'||t.name,p.name) as effective_grant,
 has_any_column_privilege(r.name,'public.'||t.name,'REFERENCES') as column_references
from (values('anon'),('authenticated'),('service_role')) r(name)
cross join (values('admin_case_notes'),('admin_saved_views'),('admin_tasks'),
 ('ai_entitlements'),('application_status_history'),('consultation_requests')) t(name)
cross join (values('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),
 ('REFERENCES'),('TRIGGER'),('MAINTAIN')) p(name) order by t.name,r.name,p.name;
select n.nspname,c.relname,pg_get_userbyid(c.relowner) as owner,
 c.relrowsecurity,c.relforcerowsecurity,c.relacl::text
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('admin_case_notes','admin_saved_views',
 'admin_tasks','ai_entitlements','application_status_history','consultation_requests');
select n.nspname,pg_get_userbyid(d.defaclrole) as creator,d.defaclobjtype,d.defaclacl::text
from pg_default_acl d left join pg_namespace n on n.oid=d.defaclnamespace
where d.defaclnamespace=0 or n.nspname='public';
select pg_get_userbyid(member) as member,pg_get_userbyid(roleid) as granted_role
from pg_auth_members where member in ('anon'::regrole,'authenticated'::regrole,'service_role'::regrole);
select pg_get_functiondef('public.ingest_ai_model_catalogue(uuid,bigint,jsonb)'::regprocedure)
 as discovery_definition;
select n.nspname,c.relname,a.attname,format_type(a.atttypid,a.atttypmod)
from pg_attribute a join pg_class c on c.oid=a.attrelid
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('ai_models','ai_providers')
 and a.attnum>0 and not a.attisdropped order by c.relname,a.attnum;
select enabled,count(*) as models from public.ai_models group by enabled;
