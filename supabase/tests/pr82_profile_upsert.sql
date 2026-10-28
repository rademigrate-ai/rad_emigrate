-- Match the shipped client's PostgREST resolution=merge-duplicates payload.
-- Synthetic subjects, grants, roles and metadata writes all roll back.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values
 ('f1800000-0000-4000-8000-000000000001','pr82-profile-admin@example.invalid'),
 ('f1800000-0000-4000-8000-000000000002','pr82-profile-user@example.invalid');
update public.profiles set role='admin' where id='f1800000-0000-4000-8000-000000000001';
delete from public.profiles where id='f1800000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"f1800000-0000-4000-8000-000000000001"}',true);
insert into public.profiles(id,email,phone,full_name,country,updated_at)
 values('f1800000-0000-4000-8000-000000000001','pr82-profile-admin@example.invalid',null,'SYNTHETIC ADMIN',null,'1900-01-01')
 on conflict(id) do update set id=excluded.id,email=excluded.email,phone=excluded.phone,
 full_name=excluded.full_name,country=excluded.country,updated_at=excluded.updated_at;
do $$begin
 if not exists(select 1 from public.profiles where id=auth.uid() and role='admin'
  and full_name='SYNTHETIC ADMIN' and updated_at>=now()-interval '1 second') then
  raise exception 'existing Admin profile upsert changed role or accepted client timestamp';end if;
 begin update public.profiles set id='f1800000-0000-4000-8000-000000000002' where id=auth.uid();
  raise exception 'profile identity reassignment admitted';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"f1800000-0000-4000-8000-000000000002","user_metadata":{"role":"super_admin"}}',true);
insert into public.profiles(id,email,phone,full_name,country,updated_at)
 values('f1800000-0000-4000-8000-000000000002','pr82-profile-user@example.invalid',null,'SYNTHETIC USER',null,'1900-01-01')
 on conflict(id) do update set id=excluded.id,email=excluded.email,phone=excluded.phone,
 full_name=excluded.full_name,country=excluded.country,updated_at=excluded.updated_at;
do $$begin
 if not exists(select 1 from public.profiles where id=auth.uid() and role='user'
  and updated_at>=now()-interval '1 second') then raise exception 'user bootstrap or server timestamp failed';end if;
 if has_column_privilege('authenticated','public.profiles','role','INSERT')
    or has_column_privilege('authenticated','public.profiles','role','UPDATE') then
  raise exception 'profile role write grant widened';end if;
 begin
  insert into public.profiles(id,full_name,updated_at) values('f1800000-0000-4000-8000-000000000001','SYNTHETIC CROSS OWNER',now())
  on conflict(id) do update set full_name=excluded.full_name;
  raise exception 'cross-owner upsert admitted';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'PASS: shipped profile upsert works; server timestamp, identity, owner and role protections hold' as result;
rollback;
