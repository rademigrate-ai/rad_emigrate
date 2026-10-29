-- F02: restricted, independently deployable correction for the six observed
-- application tables. No DML, function ACL, RLS, ownership or data changes.
-- Production execution still requires reconciliation and separate authorization.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
set local search_path = pg_catalog;
do $restrict$
declare t text; cols text;
begin
 foreach t in array array['admin_case_notes','admin_saved_views','admin_tasks',
   'ai_entitlements','application_status_history','consultation_requests'] loop
  if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname=t and c.relkind in ('r','p')
      and c.relowner='postgres'::regrole
      and not exists(select 1 from pg_depend d where d.classid='pg_class'::regclass
        and d.objid=c.oid and d.deptype='e')) then
   raise exception 'unexpected application table ownership/type: %',t;
  end if;
  execute format('revoke truncate,references,trigger,maintain on table public.%I from public,anon,authenticated',t);
  select string_agg(format('%I',attname),',' order by attnum) into cols
   from pg_attribute where attrelid=format('public.%I',t)::regclass
    and attnum>0 and not attisdropped;
  execute format('revoke references (%s) on table public.%I from public,anon,authenticated',cols,t);
  if exists(select 1 from (values('anon'),('authenticated')) r(name)
    cross join (values('TRUNCATE'),('REFERENCES'),('TRIGGER'),('MAINTAIN')) p(name)
    where has_table_privilege(r.name,format('public.%I',t),p.name)
       or has_any_column_privilege(r.name,format('public.%I',t),'REFERENCES')) then
   raise exception 'inherited prohibited privilege remains on %',t using errcode='42501';
  end if;
 end loop;
end $restrict$;
-- Existing all-table correction already limits postgres defaults. Reassert only
-- this application's creator defaults; do not change managed supabase_admin.
alter default privileges for role postgres
 revoke truncate,references,trigger,maintain on tables from public,anon,authenticated;
alter default privileges for role postgres in schema public
 revoke truncate,references,trigger,maintain on tables from public,anon,authenticated;
commit;
