-- F16: close the missing-profile bootstrap path without replaying foundation SQL.
-- Additive policy restriction; preserve server provisioning, table/column grants,
-- UPDATE role guards and all existing profile data. Production execution remains
-- subject to the reviewed transition and backup/restore release gates.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
do $guard$
begin
 if (select relowner from pg_class where oid='public.profiles'::regclass)<>'postgres'::regrole then
  raise exception 'unexpected profile owner';end if;
 if not (select relrowsecurity from pg_class where oid='public.profiles'::regclass) then
  raise exception 'profile RLS must already be enabled';end if;
 if not exists(select 1 from pg_policy where polrelid='public.profiles'::regclass and polname='profiles insert own' and polcmd='a' and polpermissive) then
  raise exception 'expected profile INSERT policy absent';end if;
 if exists(select 1 from pg_policy where polrelid='public.profiles'::regclass and polcmd in ('a','*') and polpermissive and polname<>'profiles insert own') then
  raise exception 'additional permissive INSERT/ALL policies require review';end if;
end $guard$;
alter policy "profiles insert own" on public.profiles
 with check ((select auth.uid())=id and role='user');
commit;
