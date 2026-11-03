-- Disposable synthetic data; no hosted database or source website is contacted.
begin;
set local statement_timeout='60s';
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email)values('cccccccc-1111-4111-8111-111111111111','held-fixture@example.invalid');
insert into public.profiles(id,role)values('cccccccc-1111-4111-8111-111111111111','admin')
 on conflict(id)do update set role=excluded.role;
insert into public.visa_articles(id,kind,country_code,pathway_slug,slug,created_by)values(
 'cccccccc-2222-4222-8222-222222222222','related',null,'topic-held','editorial-held','cccccccc-1111-4111-8111-111111111111');
insert into public.visa_article_revisions(id,article_id,locale,revision,title,summary,content_hash,body,created_by)values(
 'cccccccc-3333-4333-8333-333333333333','cccccccc-2222-4222-8222-222222222222','en',1,'Held','',repeat('a',64),'{"sections":[]}',
 'cccccccc-1111-4111-8111-111111111111');
insert into private.rad_production_reconciliation_journal(package_sha256,operation_id,payload_sha256,article_id,locale,revision_id,actor_id)values(
 repeat('a',64),repeat('b',64),repeat('c',64),'cccccccc-2222-4222-8222-222222222222','en',
 'cccccccc-3333-4333-8333-333333333333','cccccccc-1111-4111-8111-111111111111');
insert into private.rad_source_publication_holds values(repeat('a',64),repeat('b',64),repeat('c',64),
 'cccccccc-2222-4222-8222-222222222222','en','cccccccc-3333-4333-8333-333333333333','Index requires original full-article evidence');

do $$begin
 begin
  insert into public.visa_article_revision_events(revision_id,state,actor_id,publication_basis)values(
   'cccccccc-3333-4333-8333-333333333333','approved','cccccccc-1111-4111-8111-111111111111','source_faithful');
  raise exception 'held revision was incorrectly accepted';
 exception when sqlstate 'PT422' then
  if sqlerrm<>'source_publication_hold_requires_evidence_reconciliation' then raise;end if;
 end;
 if exists(select 1 from public.visa_article_revision_events where revision_id='cccccccc-3333-4333-8333-333333333333')then
  raise exception 'failed held approval left an event';end if;
 begin
  update private.rad_source_publication_holds set reason='silently cleared';
  raise exception 'hold mutation was incorrectly accepted';
 exception when others then
  if position('immutable' in lower(sqlerrm))=0 then raise;end if;
 end;
 if has_table_privilege('authenticated','private.rad_source_publication_holds','SELECT')
 or has_table_privilege('service_role','private.rad_source_publication_holds','INSERT')
 or has_function_privilege('anon','private.rad_source_hold_event_guard()','EXECUTE')then
  raise exception 'private hold privilege boundary failed';end if;
 if not(select relrowsecurity from pg_class where oid='private.rad_source_publication_holds'::regclass)then
  raise exception 'private hold RLS missing';end if;
 if(select prosecdef from pg_proc where oid='private.rad_source_hold_event_guard()'::regprocedure)then
  raise exception 'hold trigger must not add a security definer';end if;
end $$;
rollback;
