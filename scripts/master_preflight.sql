-- Read-only release inventory. Run with psql -XAt -v ON_ERROR_STOP=1 -f.
-- Intended project identities: Production inshddthftkhcdosoqcn;
-- Staging epolbumcfbohtmgvomki. SQL cannot attest a Supabase project identity:
-- independently verify the approved connection before running this file.
-- No content rows, credentials, migration statements or function bodies exported.
-- Lexical dependency candidates supplement pg_depend: PL/pgSQL does not record
-- every body dependency. Existence alone does not establish body equivalence.
begin read only;
set local statement_timeout='30s';
with required(name) as (values
 ('list_official_authorities'),('discover_official_authorities'),
 ('enqueue_research_refresh'),('list_research_proposals'),
 ('get_research_proposal'),('get_research_review_context'),
 ('review_research_proposal'),('approve_visa_source_inventory')
), app_functions as (
 select p.*,n.nspname schema_name,pg_get_function_identity_arguments(p.oid) identity_arguments
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in ('public','private') and p.prokind='f'
 and not exists(select 1 from pg_depend d where d.classid='pg_proc'::regclass
  and d.objid=p.oid and d.deptype='e')
), function_rows as (
 select schema_name,proname name,identity_arguments,pg_get_userbyid(proowner) owner,
 pg_get_function_result(oid) result,prosecdef security_definer,provolatile volatility,
 proconfig settings,proacl::text acl,md5(prosrc) body_md5,
 md5(pg_get_functiondef(oid)) definition_md5,
 (select jsonb_object_agg(rolname,has_function_privilege(rolname,app_functions.oid,'execute'))
  from pg_roles where rolname in ('anon','authenticated','service_role')) effective_execute,
 (select coalesce(jsonb_agg(distinct m[1]),'[]'::jsonb)
  from regexp_matches(prosrc,'\m((?:private|public|auth|storage|extensions)\.[a-z_][a-z_0-9]*)\s*\(','gi') m) lexical_call_candidates,
 (select coalesce(jsonb_agg(distinct m[1]),'[]'::jsonb)
  from regexp_matches(prosrc,'\m((?:private|public|auth|storage|extensions)\.[a-z_][a-z_0-9]*)','gi') m) lexical_object_candidates
 from app_functions
), relations as (
 select c.oid,n.nspname schema_name,c.relname name,c.relkind kind,
 pg_get_userbyid(c.relowner) owner,c.relrowsecurity rls,c.relforcerowsecurity force_rls,c.relacl::text acl
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname in ('public','private') and c.relkind in ('r','p','v','m','S')
), relation_rows as (
 select r.schema_name,r.name,r.kind,r.owner,r.rls,r.force_rls,r.acl,
 (select coalesce(jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),
  'not_null',a.attnotnull,'default',pg_get_expr(d.adbin,d.adrelid)) order by a.attnum),'[]'::jsonb)
  from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
  where a.attrelid=r.oid and a.attnum>0 and not a.attisdropped) columns,
 (select coalesce(jsonb_agg(jsonb_build_object('name',p.polname,'command',p.polcmd,'roles',
  (select jsonb_agg(case when role_oid=0 then 'public' else pg_get_userbyid(role_oid) end) from unnest(p.polroles) role_oid),
  'using',pg_get_expr(p.polqual,p.polrelid),'check',pg_get_expr(p.polwithcheck,p.polrelid)) order by p.polname),'[]'::jsonb)
  from pg_policy p where p.polrelid=r.oid) policies,
 (select coalesce(jsonb_agg(jsonb_build_object('name',c.conname,'definition',pg_get_constraintdef(c.oid,true)) order by c.conname),'[]'::jsonb)
  from pg_constraint c where c.conrelid=r.oid) constraints,
 (select coalesce(jsonb_agg(jsonb_build_object('name',t.tgname,'enabled',t.tgenabled,
  'definition',pg_get_triggerdef(t.oid,true)) order by t.tgname),'[]'::jsonb)
  from pg_trigger t where t.tgrelid=r.oid and not t.tgisinternal) triggers
 from relations r
)
select jsonb_build_object(
 'scope','read_only_catalog_inventory_not_backup_or_rollout_authority',
 'observed_at',clock_timestamp(),'database',current_database(),'database_user',current_user,
 'server_version',current_setting('server_version'),'transaction_read_only',current_setting('transaction_read_only'),
 'required_research_rpcs',(select jsonb_agg(jsonb_build_object('name',name,'expected_signature','public.'||name||'(jsonb)',
  'present',to_regprocedure('public.'||name||'(jsonb)') is not null) order by name) from required
  where name<>'get_research_review_context') || jsonb_build_array(jsonb_build_object(
   'name','get_research_review_context','expected_signature','public.get_research_review_context(uuid)',
   'present',to_regprocedure('public.get_research_review_context(uuid)') is not null)),
 'functions',(select coalesce(jsonb_agg(to_jsonb(f) order by schema_name,name,identity_arguments),'[]'::jsonb) from function_rows f),
 'relations',(select coalesce(jsonb_agg(to_jsonb(r) order by schema_name,name),'[]'::jsonb) from relation_rows r),
 'extensions',(select coalesce(jsonb_agg(jsonb_build_object('name',e.extname,'version',e.extversion,'schema',n.nspname) order by e.extname),'[]'::jsonb)
  from pg_extension e join pg_namespace n on n.oid=e.extnamespace),
 'default_privileges',(select coalesce(jsonb_agg(jsonb_build_object('owner',pg_get_userbyid(d.defaclrole),
  'schema',n.nspname,'object_type',d.defaclobjtype,'acl',d.defaclacl::text) order by n.nspname,d.defaclobjtype),'[]'::jsonb)
  from pg_default_acl d left join pg_namespace n on n.oid=d.defaclnamespace)
);
rollback;
