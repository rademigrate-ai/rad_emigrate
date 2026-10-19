-- Synthetic, transaction-rolled-back role and content integration regression.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values
 ('a0000000-0000-4000-8000-000000000001','rad-admin@example.invalid'),
 ('a0000000-0000-4000-8000-000000000002','rad-user@example.invalid'),
 ('a0000000-0000-4000-8000-000000000003','rad-other@example.invalid');
update public.profiles set role='admin' where id='a0000000-0000-4000-8000-000000000001';
insert into public.destinations(code,slug) values('ZZ','synthetic-test-only');

set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a0000000-0000-4000-8000-000000000002","user_metadata":{"role":"super_admin"}}',true);
do $$ begin
 begin
  update public.profiles set role='super_admin' where id=auth.uid();
  raise exception 'SECURITY FAILURE: UPDATE escalation admitted';
 exception when insufficient_privilege then null; end;
 begin
  perform public.create_visa_article('{"article_id":"b0000000-0000-4000-8000-000000000001","kind":"related","country_code":"ZZ","pathway_slug":"test","slug":"test","request_key":"c0000000-0000-4000-8000-000000000001"}');
  raise exception 'SECURITY FAILURE: forged metadata admin admitted';
 exception when sqlstate 'PT403' then null; end;
 begin
  perform * from public.visa_article_revisions;
  raise exception 'SECURITY FAILURE: direct draft access';
 exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claims','{"role":"authenticated","sub":"a0000000-0000-4000-8000-000000000001"}',true);
do $$
declare created jsonb; draft jsonb; result jsonb; request jsonb; publication jsonb;
begin
 request:='{"article_id":"b0000000-0000-4000-8000-000000000001","kind":"related","country_code":"ZZ","pathway_slug":"test","slug":"test","request_key":"c0000000-0000-4000-8000-000000000001"}';
 created:=public.create_visa_article(request);
 if created<>public.create_visa_article(request) then raise exception 'idempotent create differs'; end if;
 begin perform public.create_visa_article(request||'{"slug":"different"}');raise exception 'changed-key replay admitted';exception when sqlstate 'PT409' then null;end;
 request:='{"article_id":"b0000000-0000-4000-8000-000000000001","locale":"en","expected_revision":0,"title":"Synthetic source-neutral article","summary":"Test content, no immigration rules.","sections":[{"id":"d0000000-0000-4000-8000-000000000001","anchor":"overview","heading":"Synthetic overview","order":0,"blocks":[{"id":"e0000000-0000-4000-8000-000000000001","type":"paragraph","text":"This synthetic paragraph contains a searchable full body marker alphabravo.","items":[]}],"evidence_refs":[]}],"related_article_ids":[],"merge_manifest_id":null,"request_key":"c0000000-0000-4000-8000-000000000002"}';
 draft:=public.save_visa_article_draft(request)->'data';
 if draft->>'verification_state'<>'unverified' then raise exception 'draft acquired factual trust'; end if;
 begin perform public.save_visa_article_draft(request||'{"expected_revision":99,"request_key":"c0000000-0000-4000-8000-000000000099"}');raise exception 'stale revision admitted';exception when sqlstate 'PT409' then null;end;
 begin perform public.get_visa_article('{"selector":{"article_id":"b0000000-0000-4000-8000-000000000001"},"locale":"en"}');raise exception 'draft leaked';exception when sqlstate 'PT404' then null;end;
 request:=jsonb_build_object('article_id',draft->'article_id','revision_id',draft->'revision_id','expected_revision',draft->'revision','content_hash',draft->'content_hash','note','','request_key','c0000000-0000-4000-8000-000000000003');
 perform public.submit_visa_article_review(request);
 result:=public.approve_visa_article_revision(request||'{"request_key":"c0000000-0000-4000-8000-000000000004"}');
 if result->'data'->>'verification_state'<>'unverified' then raise exception 'editorial approval acquired factual trust'; end if;
 publication:=public.publish_visa_article_revision((request-'expected_revision'-'note')||'{"request_key":"c0000000-0000-4000-8000-000000000005"}');
 result:=public.get_visa_article('{"selector":{"article_id":"b0000000-0000-4000-8000-000000000001"},"locale":"en"}');
 if result->'data'->>'editorial_state'<>'published' or result->'data'->>'verification_state'<>'unverified' then raise exception 'publication state mismatch'; end if;
 result:=public.search_visa_articles('{"query":"alphabravo","locale":"en","country_codes":["ZZ"],"pathway_slugs":[],"article_kind":null,"allow_locale_fallback":false,"cursor":null,"limit":20}');
 if jsonb_array_length(result->'data'->'items')<>1 then raise exception 'full body search failed'; end if;
end $$;

reset role;
do $$ begin
 if (select count(*) from public.visa_article_revision_events where state='published')<>1 then raise exception 'duplicate publish event'; end if;
 if has_column_privilege('authenticated','public.profiles','role','INSERT') then raise exception 'role INSERT grant retained'; end if;
 if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and not c.relrowsecurity) then raise exception 'RLS disabled table'; end if;
end $$;
rollback;
