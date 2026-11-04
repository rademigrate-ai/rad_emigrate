-- Regression for the self-hosted-only gap in claim_official_research_job:
-- on a byte-for-byte fresh install (no CLI-dev-stack ambient grants), its
-- SECURITY DEFINER owner must hold an EXPLICIT grant on the table it
-- touches. A session running as a superuser-equivalent role can silently
-- pass every other check here while the function itself is broken for a
-- genuine non-superuser owner; assert this migration's own explicit
-- SELECT/UPDATE grant exists, not the owner's full effective privilege
-- set (a CLI dev/CI stack's bootstrap grants postgres broader ambient
-- table privileges than any RAD migration does; that ambient grant is
-- environment setup, not something this migration can or should assert
-- the absence of).
-- Local synthetic fixture, all writes roll back.
begin;

do $$
declare owner regrole; granted text[];
begin
  select proowner into owner from pg_proc
    where pronamespace='public'::regnamespace and proname='claim_official_research_job';
  assert owner is not null, 'claim_official_research_job must exist';

  -- Owner must not be an elevated migration-runner identity (postgres on
  -- managed, supabase_admin on self-hosted); it must stay the narrowly
  -- privileged role this migration explicitly provisions.
  assert owner::text='postgres', format('unexpected function owner: %s',owner);
  assert not (select rolsuper from pg_roles where oid=owner), 'function owner must not be superuser';

  select array_agg(privilege_type order by privilege_type) into granted
    from information_schema.role_table_grants
    where table_schema='private' and table_name='rad_research_jobs'
      and grantee=owner::text and is_grantable='NO';
  assert granted @> array['SELECT','UPDATE'],
    format('owner %s must explicitly hold SELECT,UPDATE on private.rad_research_jobs, found %s',owner,granted);

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
