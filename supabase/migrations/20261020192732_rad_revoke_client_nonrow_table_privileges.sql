-- Remove API-role whole-table/DDL capabilities left by legacy ALL grants.
-- PostgreSQL 17: TRUNCATE and REFERENCES are not constrained by row policies.
-- Application tables only; preserve DML, service_role, RLS and function ACLs.
begin;
set local search_path=pg_catalog;

do $revoke_client_nonrow$
declare target record; column_names text;
begin
  for target in
    select c.oid,n.nspname,c.relname
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind in ('r','p')
      and c.relowner='postgres'::regrole
      and not exists(select 1 from pg_depend d where d.classid='pg_class'::regclass
                     and d.objid=c.oid and d.deptype='e')
    order by c.relname
  loop
    execute format(
      'revoke truncate,references,trigger,maintain on table %I.%I from public,anon,authenticated',
      target.nspname,target.relname
    );
    -- Table-level REVOKE does not remove an independently granted column ACL.
    select string_agg(format('%I',a.attname),',' order by a.attnum)
      into column_names from pg_attribute a
      where a.attrelid=target.oid and a.attnum>0 and not a.attisdropped;
    if column_names is not null then
      execute format('revoke references (%s) on table %I.%I from public,anon,authenticated',
                     column_names,target.nspname,target.relname);
    end if;
  end loop;
end
$revoke_client_nonrow$;

-- Schema-local REVOKE cannot subtract privileges from global defaults.
-- Limit the application creator's defaults; managed supabase_admin defaults
-- require separate operational ownership review and are not changed here.
alter default privileges for role postgres
  revoke truncate,references,trigger,maintain on tables from public,anon,authenticated;
alter default privileges for role postgres in schema public
  revoke truncate,references,trigger,maintain on tables from public,anon,authenticated;

-- Fail the transaction rather than claim protection if an inherited grant
-- outside these direct ACLs still confers a forbidden application capability.
do $verify_client_nonrow$
begin
  if exists(
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    cross join (values ('anon'),('authenticated')) roles(name)
    cross join (values ('TRUNCATE'),('REFERENCES'),('TRIGGER'),('MAINTAIN')) privileges(name)
    where n.nspname='public' and c.relkind in ('r','p')
      and c.relowner='postgres'::regrole
      and not exists(select 1 from pg_depend d where d.classid='pg_class'::regclass
                     and d.objid=c.oid and d.deptype='e')
      and (has_table_privilege(roles.name,c.oid,privileges.name)
           or has_any_column_privilege(roles.name,c.oid,'REFERENCES'))
  ) then raise exception 'unexpected_client_nonrow_privilege' using errcode='42501'; end if;
end
$verify_client_nonrow$;
commit;
