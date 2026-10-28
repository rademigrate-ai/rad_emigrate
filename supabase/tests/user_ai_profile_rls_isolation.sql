-- Disposable-local RLS isolation checks for user_ai_profiles / checklists / reports.
-- Run only against disposable Postgres (not Production).
-- Requires migration 20261028200000_user_ai_profile_checklist_reports.sql applied.

begin;

do $$
declare
  u1 uuid := '11111111-1111-4111-8111-111111111111';
  u2 uuid := '22222222-2222-4222-8222-222222222222';
  seen int;
begin
  -- Simulate auth.uid() via set_config if using request.jwt claims is unavailable in bare SQL.
  -- Environments using auth.uid() from JWT need Supabase test harness; this block documents expectations.

  raise notice 'EXPECT: authenticated user can only select own user_ai_profiles rows';
  raise notice 'EXPECT: user % cannot read/update/delete rows owned by %', u1, u2;
  raise notice 'EXPECT: upsert_user_ai_profile uses auth.uid() and rejects anon';
  raise notice 'EXPECT: service_role may administer but product path uses invoker RLS';

  -- Structural checks
  if to_regclass('public.user_ai_profiles') is null then
    raise exception 'user_ai_profiles missing — apply 20261028200000 first';
  end if;
  if to_regclass('public.user_ai_checklists') is null then
    raise exception 'user_ai_checklists missing';
  end if;
  if to_regclass('public.user_ai_reports') is null then
    raise exception 'user_ai_reports missing';
  end if;

  select count(*) into seen
  from pg_policies
  where tablename in ('user_ai_profiles', 'user_ai_checklists', 'user_ai_reports')
    and policyname like '%owner%';
  if seen < 3 then
    raise exception 'expected owner policies on profile/checklist/report tables, found %', seen;
  end if;
end;
$$;

rollback;
