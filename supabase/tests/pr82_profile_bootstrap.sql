-- F16: real SQL operations against synthetic missing-profile Auth subjects.
-- All fixtures and ACL probes roll back. Never run this file on Production.
begin;
set local statement_timeout='30s';
insert into auth.users(id,email) values
 ('f1600000-0000-4000-8000-000000000001','pr82-f16-a@example.invalid'),
 ('f1600000-0000-4000-8000-000000000002','pr82-f16-b@example.invalid');
-- Simulate an interrupted provisioning/recovery path, not a signup exploit.
delete from public.profiles where id in
 ('f1600000-0000-4000-8000-000000000001','f1600000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"f1600000-0000-4000-8000-000000000001","user_metadata":{"role":"super_admin"}}',true);
do $$
begin
 begin
  insert into public.profiles(id,role) values('f1600000-0000-4000-8000-000000000001','admin');
  raise exception 'F16: missing-profile admin insert accepted';
 exception when insufficient_privilege then null;
 end;
 begin
  insert into public.profiles(id,role) values('f1600000-0000-4000-8000-000000000001','super_admin');
  raise exception 'F16: missing-profile super_admin insert accepted';
 exception when insufficient_privilege then null;
 end;
 begin
  insert into public.profiles(id,email) values('f1600000-0000-4000-8000-000000000002','pr82-f16-b@example.invalid');
  raise exception 'F16: cross-owner bootstrap accepted';
 exception when insufficient_privilege then null;
 end;
end $$;
insert into public.profiles(id,email) values('f1600000-0000-4000-8000-000000000001','pr82-f16-a@example.invalid');
do $$begin
 if not exists(select 1 from public.profiles where id=auth.uid() and role='user')
    or private.has_role(array['admin','super_admin']) then
  raise exception 'F16: normal user bootstrap or metadata isolation failed';
 end if;
end $$;
reset role;
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into public.profiles(id,email,role) values('f1600000-0000-4000-8000-000000000002','pr82-f16-b@example.invalid','admin');
do $$begin
 if not exists(select 1 from public.profiles where id='f1600000-0000-4000-8000-000000000002' and role='admin') then
  raise exception 'F16: authorized server provisioning failed';
 end if;
end $$;
reset role;
select 'PASS: F16 missing-profile admin/super_admin/cross-owner denied; user and trusted-server provisioning preserved' as result;
rollback;
