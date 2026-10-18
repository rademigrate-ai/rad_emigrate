-- Catalog metadata only. No Vault contents or application/user data.
with routines as (
  select p.oid,n.nspname,p.proname,p.proowner,p.proacl,p.proconfig,p.prorettype
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where p.prosecdef and n.nspname in ('public','private')
)
select jsonb_build_object(
  'scope','disposable_local_runtime_catalog',
  'captured_at',now(),
  'unique_runtime_definers',(select count(*) from routines),
  'untrusted_public_schema_create',jsonb_build_object(
    'anon',has_schema_privilege('anon','public','CREATE'),
    'authenticated',has_schema_privilege('authenticated','public','CREATE')),
  'functions',(select jsonb_agg(jsonb_build_object(
    'routine',r.oid::regprocedure::text,'schema',r.nspname,'owner',pg_get_userbyid(r.proowner),
    'search_path',r.proconfig,'trigger',r.prorettype='trigger'::regtype,
    'public_execute',exists(select 1 from aclexplode(coalesce(r.proacl,acldefault('f',r.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE'),
    'anon_execute',has_function_privilege('anon',r.oid,'EXECUTE'),
    'authenticated_execute',has_function_privilege('authenticated',r.oid,'EXECUTE'),
    'service_execute',has_function_privilege('service_role',r.oid,'EXECUTE')) order by r.nspname,r.proname,r.oid::regprocedure::text) from routines r)
);
