-- Read-only discovery/compatibility check. Never an activation authorization.
-- The operator must first bind the connection to project inshddthftkhcdosoqcn
-- through supported provider evidence; a SQL string cannot authenticate a project.
begin read only;
set local statement_timeout='30s';
select jsonb_build_object(
 'checked_at',clock_timestamp(),'database',current_database(),'executor',current_user,
 'server_version',current_setting('server_version'),
 'system_identifier',(select system_identifier::text from pg_control_system()),
 'editorial_actor',auth.uid(),
 'catalog_lock_capability',has_table_privilege(current_user,'pg_catalog.pg_proc','MAINTAIN')
  or has_table_privilege(current_user,'pg_catalog.pg_proc','UPDATE')
  or has_table_privilege(current_user,'pg_catalog.pg_proc','DELETE')
  or has_table_privilege(current_user,'pg_catalog.pg_proc','TRUNCATE'),
 'migration_count',(select count(*)from supabase_migrations.schema_migrations),
 'heads',(select count(*)from public.visa_article_heads),
 'revisions',(select count(*)from public.visa_article_revisions),
 'published_heads',(select count(*)from public.visa_article_heads where published_id is not null),
 'legacy_findings',(select count(*)from public.research_findings),
 'legacy_drafts',(select count(*)from public.content_drafts),
 'visa_proposals',(select count(*)from public.visa_research_proposals),
 'review_context',to_regprocedure('public.get_research_review_context_v2(uuid)')is not null,
 'structured_review',to_regprocedure('public.save_structured_research_review(jsonb)')is not null,
 'cms_draft',to_regprocedure('public.get_cms_article_draft(jsonb)')is not null,
 'source_approval',to_regprocedure('public.approve_source_editorial_batch(uuid,text,text,text,text)')is not null,
 'source_publication',to_regprocedure('public.publish_source_editorial_batch(uuid,text)')is not null,
 'source_withdrawal',to_regprocedure('public.unpublish_source_editorial_batch(uuid,text,text)')is not null
)preflight;

-- Permissions/policies only: no Vault values, Auth credentials, user rows,
-- cron commands, request JWTs or provider secrets are read by this check.
select n.nspname,c.relname,c.relrowsecurity,c.relforcerowsecurity,
 has_table_privilege('anon',c.oid,'SELECT')anon_select,
 has_table_privilege('authenticated',c.oid,'INSERT')authenticated_insert,
 has_table_privilege('authenticated',c.oid,'UPDATE')authenticated_update
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname in('public','private')and c.relkind='r'
 and(c.relname like 'rad_%'or c.relname like 'visa_%'or c.relname in('profiles','research_findings','content_drafts','source_snapshots'))
order by n.nspname,c.relname;
select schemaname,tablename,policyname,roles,cmd,qual,with_check from pg_policies
where schemaname in('public','private')order by schemaname,tablename,policyname;
select n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)arguments,
 pg_get_userbyid(p.proowner)owner,p.prosecdef,p.proconfig,
 has_function_privilege('anon',p.oid,'EXECUTE')anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE')authenticated_execute,
 has_function_privilege('service_role',p.oid,'EXECUTE')service_execute,
 encode(extensions.digest(pg_get_functiondef(p.oid),'sha256'),'hex')definition_sha256
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in('public','private')and p.prokind='f'
order by n.nspname,p.proname,arguments;
select e.evtname,e.evtevent,e.evtenabled,e.evttags,pg_get_userbyid(e.evtowner)owner,
 e.evtfoid::regprocedure::text callback,
 encode(extensions.digest(pg_get_functiondef(e.evtfoid),'sha256'),'hex')definition_sha256
from pg_event_trigger e order by e.evtname;
commit;
