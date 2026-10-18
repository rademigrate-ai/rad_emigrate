-- Runtime catalog and caller checks. Local synthetic fixture, all writes roll back.
begin;
do $$ declare f record; begin
  assert not has_schema_privilege('anon','public','CREATE');
  assert not has_schema_privilege('authenticated','public','CREATE');
  for f in select p.*,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.prosecdef and n.nspname in ('public','private') loop
    assert exists(select 1 from unnest(f.proconfig) c where c in ('search_path=""','search_path=public')),
      format('untrusted or ambient search path: %s',f.oid::regprocedure);
    assert not exists(select 1 from aclexplode(coalesce(f.proacl,acldefault('f',f.proowner))) a
      where a.grantee=0 and a.privilege_type='EXECUTE'),format('PUBLIC execute remains: %s',f.oid::regprocedure);
    if f.nspname='private' and f.proname<>'has_role' then
      assert not has_function_privilege('anon',f.oid,'EXECUTE') and not has_function_privilege('authenticated',f.oid,'EXECUTE'),
        format('client execute on internal helper: %s',f.oid::regprocedure);
    end if;
    if f.nspname='public' then assert not has_function_privilege('anon',f.oid,'EXECUTE'),format('anonymous definer API: %s',f.oid::regprocedure); end if;
    assert f.proowner not in ('anon'::regrole,'authenticated'::regrole);
  end loop;
end $$;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email,raw_user_meta_data) values
 ('47000000-0000-4000-8200-000000000001','local47-notification-owner@example.invalid','{}'),
 ('47000000-0000-4000-8200-000000000002','local47-notification-admin@example.invalid','{}');
update public.profiles set role='admin' where id='47000000-0000-4000-8200-000000000002';
set local role service_role;
do $$ declare v uuid; begin
  v:=public.create_user_notification('47000000-0000-4000-8200-000000000001',null,'Synthetic service notice','Synthetic body','/notifications',null);
  assert (select type from public.notifications where id=v)='system';
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"47000000-0000-4000-8200-000000000001"}',true);
select set_config('request.jwt.claim.sub','47000000-0000-4000-8200-000000000001',true);
set local role authenticated;
do $$ begin
  begin
    perform public.create_user_notification('47000000-0000-4000-8200-000000000001','system','Synthetic','Synthetic',null,null);
    raise exception 'ordinary user created notification';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"47000000-0000-4000-8200-000000000002"}',true);
select set_config('request.jwt.claim.sub','47000000-0000-4000-8200-000000000002',true);
set local role authenticated;
do $$ declare v uuid; begin
  v:=public.create_user_notification('47000000-0000-4000-8200-000000000001','system','Synthetic admin notice','Synthetic body','/notifications',null);
  assert v is not null;
  begin
    perform public.create_user_notification('47000000-0000-4000-8200-000000000001','system','Synthetic','Synthetic','//external.example.invalid',null);
    raise exception 'notification open redirect accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.create_user_notification('47000000-0000-4000-8200-000000000001','operational','Synthetic','Synthetic',null,null);
    raise exception 'unsupported notification type accepted';
  exception when invalid_parameter_value then null; end;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"anon"}',true);
select set_config('request.jwt.claim.sub','',true);
set local role anon;
do $$ begin
  assert not private.has_role(array['admin','super_admin']);
  perform count(*) from public.feed_items; -- anonymous public Feed policy still works
  begin perform private.guard_application_status(); raise exception 'anonymous direct trigger call';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin raise notice 'PASS: runtime SECURITY DEFINER ACL inventory, trusted schemas, RLS helper and notification caller matrix'; end $$;
rollback;
