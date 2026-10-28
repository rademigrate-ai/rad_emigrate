-- The shipped PostgREST upsert includes id in its conflict UPDATE and updated_at
-- in its INSERT. Authorize exactly those columns, while enforcing their meaning
-- on the server. Never widen role writes or table-wide INSERT/UPDATE grants.
begin;
do $$begin
 if not (select relrowsecurity from pg_class where oid='public.profiles'::regclass)
 or has_column_privilege('authenticated','public.profiles','role','INSERT')
 or has_column_privilege('authenticated','public.profiles','role','UPDATE') then
  raise exception 'profile RLS and role column ACL prerequisites missing';
 end if;
end $$;
create function private.guard_profile_write_metadata() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='UPDATE' and new.id is distinct from old.id
    and coalesce(auth.jwt()->>'role','')<>'service_role' then
  raise exception 'profile_identity_immutable' using errcode='42501';
 end if;
 if coalesce(auth.jwt()->>'role','')='authenticated' then
  new.updated_at:=clock_timestamp();
 end if;
 return new;
end $$;
revoke all on function private.guard_profile_write_metadata() from public,anon,authenticated,service_role;
create trigger rad_profile_write_metadata_guard before insert or update on public.profiles
 for each row execute function private.guard_profile_write_metadata();
grant insert(updated_at),update(id) on public.profiles to authenticated;
commit;
