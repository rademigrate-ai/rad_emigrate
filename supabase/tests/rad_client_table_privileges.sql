-- Application API roles need DML/RLS, never whole-table or schema privileges.
-- Synthetic rollback-only regression; execute only in the owned local harness.
begin;
do $test$
declare violations integer;
begin
  select count(*) into violations
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  cross join (values ('anon'),('authenticated')) roles(name)
  cross join (values ('TRUNCATE'),('REFERENCES'),('TRIGGER'),('MAINTAIN')) privileges(name)
  where n.nspname='public' and c.relkind in ('r','p')
    and c.relowner='postgres'::regrole
    and not exists(select 1 from pg_depend d where d.classid='pg_class'::regclass
                   and d.objid=c.oid and d.deptype='e')
    and has_table_privilege(roles.name,c.oid,privileges.name);
  if violations>0 then raise exception 'client_non_row_table_privileges: %',violations; end if;
  if exists(
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    cross join (values ('anon'),('authenticated')) roles(name)
    where n.nspname='public' and c.relkind in ('r','p')
      and c.relowner='postgres'::regrole
      and not exists(select 1 from pg_depend d where d.classid='pg_class'::regclass
                     and d.objid=c.oid and d.deptype='e')
      and has_any_column_privilege(roles.name,c.oid,'REFERENCES')
  ) then raise exception 'client_column_references_privilege'; end if;
  if not has_table_privilege('authenticated','public.profiles','SELECT')
     or exists(select 1 from (values ('INSERT'),('UPDATE'),('DELETE'),('SELECT')) p(name)
               where not has_table_privilege('service_role','public.profiles',p.name))
     or exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
               where n.nspname='public' and c.relkind='r' and not c.relrowsecurity)
  then raise exception 'DML_or_RLS_contract_changed'; end if;
end
$test$;

-- A newly created application table must not regain the revoked capabilities.
create table public.rad_client_acl_future_probe(id integer primary key);
alter table public.rad_client_acl_future_probe enable row level security;
do $test$
begin
  if exists(
    select 1 from (values ('anon'),('authenticated')) roles(name)
    cross join (values ('TRUNCATE'),('REFERENCES'),('TRIGGER'),('MAINTAIN')) privileges(name)
    where has_table_privilege(roles.name,'public.rad_client_acl_future_probe',privileges.name)
  ) then raise exception 'unsafe_future_table_defaults'; end if;
end
$test$;

-- Actual role-level negative, not a catalog-only assertion. No rows survive.
set local role anon;
do $test$
begin
  begin
    truncate table public.admin_saved_views;
    raise exception 'anonymous_truncate_admitted';
  exception when insufficient_privilege then null;
  end;
end
$test$;
reset role;
set local role authenticated;
do $test$
begin
  begin
    truncate table public.admin_saved_views;
    raise exception 'authenticated_truncate_admitted';
  exception when insufficient_privilege then null;
  end;
end
$test$;
reset role;
rollback;
