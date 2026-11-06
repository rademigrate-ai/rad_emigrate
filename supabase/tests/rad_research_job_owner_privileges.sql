-- Regression for the self-hosted-only gap in claim_official_research_job:
-- on a byte-for-byte fresh install, its SECURITY DEFINER owner must hold
-- an EXPLICIT grant on the table it touches, or the function errors for
-- every legitimate service_role caller. A CLI dev/CI Supabase stack's own
-- bootstrap gives postgres broad ambient table privileges no RAD migration
-- grants; has_table_privilege can't distinguish "this migration's grant"
-- from "ambient bootstrap privilege" once both exist, so this check only
-- has teeth where postgres carries no such ambient access -- a genuine
-- self-hosted install (verified directly there: supabase/self_host_stack.py
-- migrate against an empty database, grant reverted/restored). CI passing
-- this file is necessary but not sufficient proof of the self-hosted fix;
-- the EXECUTE/PUBLIC checks below hold in every environment regardless.
-- Local synthetic fixture, all writes roll back.
begin;

do $$
declare owner regrole;
begin
  select proowner into owner from pg_proc
    where pronamespace='public'::regnamespace and proname='claim_official_research_job';
  assert owner is not null, 'claim_official_research_job must exist';

  -- Owner must not be an elevated migration-runner identity (postgres on
  -- managed, supabase_admin on self-hosted); it must stay the narrowly
  -- privileged role this migration explicitly provisions.
  assert owner::text='postgres', format('unexpected function owner: %s',owner);
  assert not (select rolsuper from pg_roles where oid=owner), 'function owner must not be superuser';

  assert has_table_privilege(owner,'private.rad_research_jobs','SELECT')
     and has_table_privilege(owner,'private.rad_research_jobs','UPDATE'),
    format('owner %s must hold SELECT and UPDATE on private.rad_research_jobs',owner);

  assert has_function_privilege('service_role','public.claim_official_research_job()','EXECUTE'),
    'service_role must retain EXECUTE';
  assert not has_function_privilege('anon','public.claim_official_research_job()','EXECUTE'),
    'anon must not gain EXECUTE';
  assert not has_function_privilege('authenticated','public.claim_official_research_job()','EXECUTE'),
    'authenticated must not gain EXECUTE';
  assert not exists(
    select 1 from aclexplode(coalesce(
      (select proacl from pg_proc where pronamespace='public'::regnamespace and proname='claim_official_research_job'),
      acldefault('f',owner)
    )) a where a.grantee=0 and a.privilege_type='EXECUTE'
  ), 'PUBLIC must not retain EXECUTE';
end
$$;

rollback;
