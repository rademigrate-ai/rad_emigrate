-- Synthetic local fixtures only; operator evidence here never authorizes Production.
\set rad_keep_source_fixture true
\ir source_editorial_release.sql
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a4100000-0000-4000-8000-000000000001"}',true);

do $$declare f record;result jsonb;retry jsonb;before_hash text;after_hash text;begin
 select * into f from source_release_fixture;
 select encode(extensions.digest(jsonb_agg(jsonb_build_object('id',r.id,'author',r.created_by,'body',r.body,'hash',r.content_hash)order by r.id)::text,'sha256'),'hex')
 into before_hash from public.visa_article_revisions r where r.article_id='a4100000-0000-4000-8000-000000000010';
 if has_function_privilege('anon','public.unpublish_source_editorial_batch(uuid,text,text)','EXECUTE')
 or has_function_privilege('service_role','public.reverse_release_function_state(bigint,text,text)','EXECUTE')
 or has_table_privilege('authenticated','private.rad_function_reversal_authorizations','INSERT')
 or has_table_privilege('authenticated','private.rad_source_unpublish_members','INSERT')then raise exception 'FAIL safety operation ACL';end if;
 begin perform public.unpublish_source_editorial_batch(f.batch,repeat('0',64),'Synthetic withdrawal with wrong manifest.');
  raise exception 'FAIL changed manifest accepted';exception when sqlstate 'PT409'then null;end;
 perform set_config('request.jwt.claims','{"role":"authenticated","sub":"a4100000-0000-4000-8000-000000000002"}',true);
 begin perform public.unpublish_source_editorial_batch(f.batch,encode(extensions.digest(f.manifest,'sha256'),'hex'),'Synthetic unauthorized withdrawal.');
  raise exception 'FAIL ordinary user withdrawal';exception when sqlstate 'PT403'then null;end;
 perform set_config('request.jwt.claims','{"role":"authenticated","sub":"a4100000-0000-4000-8000-000000000001"}',true);
 -- A hold imposed after publication must not prevent withdrawing unsafe content.
 insert into private.rad_source_publication_holds(package_sha256,operation_id,payload_sha256,article_id,locale,revision_id,reason)
 select package_sha256,operation_id,payload_sha256,article_id,locale,revision_id,'Synthetic post-publication safety hold'
 from private.rad_production_reconciliation_journal where article_id='a4100000-0000-4000-8000-000000000010';
 result:=public.unpublish_source_editorial_batch(f.batch,encode(extensions.digest(f.manifest,'sha256'),'hex'),'Synthetic source withdrawal reviewed locally.');
 retry:=public.unpublish_source_editorial_batch(f.batch,encode(extensions.digest(f.manifest,'sha256'),'hex'),'Synthetic source withdrawal reviewed locally.');
 if result->'data' is distinct from retry->'data' or result->'data'->>'unpublished_count'<>'2'then raise exception 'FAIL exact withdrawal retry';end if;
 if(select count(*)from private.rad_source_unpublish_members where batch_id=f.batch)<>2
 or(select count(*)from public.visa_article_revision_events where source_batch_id=f.batch and state='unpublished')<>2
 or(select count(*)from private.rad_source_unpublish_receipts where batch_id=f.batch)<>1 then raise exception 'FAIL duplicate or incomplete receipts';end if;
 begin perform public.unpublish_source_editorial_batch(f.batch,encode(extensions.digest(f.manifest,'sha256'),'hex'),'A different withdrawal note must fail.');
  raise exception 'FAIL changed retry request';exception when sqlstate 'PT409'then null;end;
 if exists(select 1 from public.visa_article_heads where article_id='a4100000-0000-4000-8000-000000000010'and published_id is not null)
 or exists(select 1 from public.visa_article_search_documents where article_id='a4100000-0000-4000-8000-000000000010')then raise exception 'FAIL public withdrawal';end if;
 if not exists(select 1 from public.visa_article_heads where article_id='a4100000-0000-4000-8000-000000000010'and locale='en'and head_id='a4100000-0000-4000-8000-000000000011')then raise exception 'FAIL withdrawal advanced head';end if;
 select encode(extensions.digest(jsonb_agg(jsonb_build_object('id',r.id,'author',r.created_by,'body',r.body,'hash',r.content_hash)order by r.id)::text,'sha256'),'hex')
 into after_hash from public.visa_article_revisions r where r.article_id='a4100000-0000-4000-8000-000000000010';
 if before_hash<>after_hash then raise exception 'FAIL body or author rewritten';end if;
 if(select count(*)from public.feed_items)<>(select n from source_release_feed_before)then raise exception 'FAIL automatic Feed write';end if;
 begin update public.visa_article_heads set published_id=(f.entry->>'revision_id')::uuid where article_id='a4100000-0000-4000-8000-000000000010'and locale='en';
  raise exception 'FAIL same-transaction publication replay';exception when sqlstate 'PT422'then null;end;
 begin delete from private.rad_source_unpublish_members where batch_id=f.batch;raise exception 'FAIL mutable withdrawal history';exception when sqlstate 'PT409'then
  if sqlerrm<>'immutable_history'then raise;end if;end;
 perform set_config('request.jwt.claims','{"role":"anon"}',true);
 begin perform public.get_editorial_article('a4100000-0000-4000-8000-000000000010','en',false);raise exception 'FAIL withdrawn draft exposed';exception when sqlstate 'PT404'then null;end;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a4100000-0000-4000-8000-000000000001"}',true);
do $$declare rid bigint;expected text;before_frame jsonb;result jsonb;retry jsonb;begin
 before_frame:=private.rad_release_function_frame(private.rad_reviewed_function_signatures());
 expected:=encode(extensions.digest(before_frame::text,'sha256'),'hex');
 if not private.rad_catalog_lock_executor_available()then
  begin perform private.rad_capture_function_state(repeat('6',64),'manual_review',private.rad_reviewed_function_signatures(),expected,
   'SYNTHETIC managed operator lock denial must fail closed.');
   raise exception 'FAIL managed catalog-lock safety bypass';exception when sqlstate 'PT403'then
    if sqlerrm<>'provider_approved_catalog_lock_executor_required'then raise;end if;end;
  if exists(select 1 from private.rad_function_state_receipts where package_sha256=repeat('6',64))
   then raise exception 'FAIL denied capture wrote receipt';end if;
  raise notice 'Managed catalog lock unavailable: capture/inverse remain blocked; no privileges granted.';
  return;
 end if;
 rid:=private.rad_capture_function_state(repeat('6',64),'manual_review',private.rad_reviewed_function_signatures(),expected,
  'SYNTHETIC local fixture, never an independent Production attestation.');
 if rid<>private.rad_capture_function_state(repeat('6',64),'manual_review',private.rad_reviewed_function_signatures(),expected,
  'SYNTHETIC local fixture, never an independent Production attestation.')then raise exception 'FAIL capture retry';end if;
 execute 'create or replace function private.rad_page_position(body jsonb,version text)returns jsonb language plpgsql set search_path=''''as $change$begin return null;end$change$';
 expected:=encode(extensions.digest(private.rad_release_function_frame(private.rad_reviewed_function_signatures())::text,'sha256'),'hex');
 begin perform public.reverse_release_function_state(rid,expected,'SYNTHETIC inverse reviewed only for a local fixture.');
  raise exception 'FAIL Admin self-authorized inverse';exception when sqlstate 'PT403'then null;end;
 -- Only the local fixture owner can insert this synthetic record. Client/Admin
 -- grants cannot create independent operational authorization in Production.
 insert into private.rad_function_reversal_authorizations(source_receipt_id,actor_id,expected_current_state_sha256,
  request_sha256,independent_reviewer_ref,approval_evidence_sha256,expires_at)
 values(rid,'a4100000-0000-4000-8000-000000000001',expected,
  encode(extensions.digest(jsonb_build_object('source_receipt_id',rid,'actor_id','a4100000-0000-4000-8000-000000000001'::uuid,
   'expected_current_state_sha256',expected,'note','SYNTHETIC inverse reviewed only for a local fixture.')::text,'sha256'),'hex'),
  'SYNTHETIC-LOCAL-REVIEWER',repeat('7',64),clock_timestamp()+interval '5 minutes');
 result:=public.reverse_release_function_state(rid,expected,'SYNTHETIC inverse reviewed only for a local fixture.');
 retry:=public.reverse_release_function_state(rid,expected,'SYNTHETIC inverse reviewed only for a local fixture.');
 if result is distinct from retry or result->>'restored_count'<>'7'
 or private.rad_release_function_frame(private.rad_reviewed_function_signatures())is distinct from before_frame
 then raise exception 'FAIL exact inverse or idempotent receipt';end if;
 if(select count(*)from private.rad_function_reversal_receipts where source_receipt_id=rid)<>1 then raise exception 'FAIL duplicate inverse audit';end if;
end $$;
rollback;
\unset rad_keep_source_fixture
