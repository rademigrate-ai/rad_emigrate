-- Synthetic fixtures and schema/data changes roll back. Never run against production.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email,raw_user_meta_data) values
 ('47100000-0000-4000-8000-000000000001','ocr-owner@example.invalid','{}'),
 ('47100000-0000-4000-8000-000000000002','ocr-other@example.invalid','{}');
insert into public.documents(id,user_id,name,file_path) values
 ('47100000-0000-4000-8000-000000000003','47100000-0000-4000-8000-000000000001','Synthetic PDF',
 '47100000-0000-4000-8000-000000000001/synthetic.pdf');

select set_config('request.jwt.claims','{"role":"authenticated","sub":"47100000-0000-4000-8000-000000000001"}',true);
select set_config('request.jwt.claim.sub','47100000-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin
 assert not has_table_privilege('authenticated','public.document_processing_jobs','INSERT');
 assert not has_column_privilege('authenticated','public.document_fields','field_value','UPDATE');
 assert not has_column_privilege('authenticated','public.document_fields','extraction_id','UPDATE');
 assert has_column_privilege('authenticated','public.document_fields','corrected_value','UPDATE');
 begin
  perform public.begin_document_processing('47100000-0000-4000-8000-000000000003','47100000-0000-4000-8000-000000000001',
   '47100000-0000-4000-8000-000000000001/synthetic.pdf');
  raise exception 'client claimed service lease';
 exception when insufficient_privilege then null; end;
 begin perform * from private.document_processing_leases; raise exception 'private lease exposed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('rad.ocr_claim',public.begin_document_processing('47100000-0000-4000-8000-000000000003',
 '47100000-0000-4000-8000-000000000001','47100000-0000-4000-8000-000000000001/synthetic.pdf')::text,true);
select set_config('rad.ocr_extraction','{"engine":"synthetic","engine_version":"fixture","extracted_text":"Synthetic text only","language_code":"en","overall_confidence":0.8,"page_count":1,"input_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}',true);
select set_config('rad.ocr_fields','[{"field_key":"synthetic_name","field_value":"Synthetic person","page_number":1,"confidence":0.8,"review_status":"accepted","bounding_box":{"untrusted":true}}]',true);
do $$ declare first jsonb:=current_setting('rad.ocr_claim')::jsonb; again jsonb; completed jsonb;
begin
 assert (first->>'claimed')::boolean;
 again:=public.begin_document_processing('47100000-0000-4000-8000-000000000003',
 '47100000-0000-4000-8000-000000000001','47100000-0000-4000-8000-000000000001/synthetic.pdf');
 assert again->>'claimed'='false' and again->>'job_id'=first->>'job_id';
 assert not (again ? 'lease_token');
 begin
  perform public.begin_document_processing('47100000-0000-4000-8000-000000000003','47100000-0000-4000-8000-000000000002',
   '47100000-0000-4000-8000-000000000001/synthetic.pdf');
  raise exception 'service wrong-owner claim passed';
 exception when insufficient_privilege then null; end;
 begin
  perform public.complete_document_processing((first->>'job_id')::uuid,(first->>'lease_token')::uuid,
   current_setting('rad.ocr_extraction')::jsonb,'[{"field_key":"duplicate"},{"field_key":"duplicate"}]');
  raise exception 'duplicate fields committed';
 exception when invalid_parameter_value then null; end;
 assert (select count(*) from public.document_extractions where job_id=(first->>'job_id')::uuid)=0;
 assert (select status from public.document_processing_jobs where id=(first->>'job_id')::uuid)='running';
 -- Force a late failure after extraction insertion; the whole completion must roll back.
 begin
  perform public.complete_document_processing((first->>'job_id')::uuid,(first->>'lease_token')::uuid,
   current_setting('rad.ocr_extraction')::jsonb,'[{"field_key":"bad_confidence","confidence":2}]');
  raise exception 'invalid field confidence committed';
 exception when check_violation then null; end;
 assert (select count(*) from public.document_extractions where job_id=(first->>'job_id')::uuid)=0;
 completed:=public.complete_document_processing((first->>'job_id')::uuid,(first->>'lease_token')::uuid,
  current_setting('rad.ocr_extraction')::jsonb,current_setting('rad.ocr_fields')::jsonb);
 assert completed->>'status'='review_required' and completed->>'field_count'='1';
 assert (select bool_and(review_status='unreviewed' and bounding_box is null) from public.document_fields
  where extraction_id=(completed->>'extraction_id')::uuid);
 perform set_config('rad.ocr_completed',completed::text,true);
 again:=public.complete_document_processing((first->>'job_id')::uuid,(first->>'lease_token')::uuid,
  current_setting('rad.ocr_extraction')::jsonb,current_setting('rad.ocr_fields')::jsonb);
 assert again->>'duplicate'='true' and again->>'extraction_id'=completed->>'extraction_id';
 assert not public.fail_document_processing((first->>'job_id')::uuid,(first->>'lease_token')::uuid,'processing_unavailable');
 begin
  perform public.complete_document_processing((first->>'job_id')::uuid,gen_random_uuid(),
   current_setting('rad.ocr_extraction')::jsonb,'[]');
  raise exception 'forged completion lease passed';
 exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claims','{"role":"authenticated","sub":"47100000-0000-4000-8000-000000000001"}',true);
set local role authenticated;
update public.document_fields set review_status='corrected',corrected_value='Human correction',
 reviewed_by='47100000-0000-4000-8000-000000000002',reviewed_at='2000-01-01'
 where extraction_id=(current_setting('rad.ocr_completed')::jsonb->>'extraction_id')::uuid;
do $$ begin
 assert (select bool_and(reviewed_by=auth.uid() and reviewed_at>now()-interval '1 minute' and field_value='Synthetic person')
  from public.document_fields where extraction_id=(current_setting('rad.ocr_completed')::jsonb->>'extraction_id')::uuid);
 assert (select count(*) from public.document_reviews where extraction_id=(current_setting('rad.ocr_completed')::jsonb->>'extraction_id')::uuid)=1;
 begin update public.document_fields set field_value='tampered'; raise exception 'raw extraction modified';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"47100000-0000-4000-8000-000000000002"}',true);
select set_config('request.jwt.claim.sub','47100000-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ declare changed integer; begin
 assert (select count(*) from public.document_extractions where document_id='47100000-0000-4000-8000-000000000003')=0;
 update public.document_fields set review_status='accepted' where extraction_id=(current_setting('rad.ocr_completed')::jsonb->>'extraction_id')::uuid;
 get diagnostics changed=row_count;
 assert changed=0,'cross-owner field review passed';
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$ declare claim jsonb; begin
 claim:=public.begin_document_processing('47100000-0000-4000-8000-000000000003','47100000-0000-4000-8000-000000000001',
  '47100000-0000-4000-8000-000000000001/synthetic.pdf');
 update public.documents set file_path='47100000-0000-4000-8000-000000000001/replacement.pdf' where id='47100000-0000-4000-8000-000000000003';
 begin
  perform public.complete_document_processing((claim->>'job_id')::uuid,(claim->>'lease_token')::uuid,
   current_setting('rad.ocr_extraction')::jsonb,'[]');
  raise exception 'changed document accepted stale extraction';
 exception when serialization_failure then null; end;
 claim:=public.begin_document_processing('47100000-0000-4000-8000-000000000003','47100000-0000-4000-8000-000000000001',
  '47100000-0000-4000-8000-000000000001/replacement.pdf');
 update private.document_processing_leases set expires_at=now()-interval '1 second' where job_id=(claim->>'job_id')::uuid;
 begin
  perform public.complete_document_processing((claim->>'job_id')::uuid,(claim->>'lease_token')::uuid,
   current_setting('rad.ocr_extraction')::jsonb,'[]');
  raise exception 'expired lease completed';
 exception when serialization_failure then null; end;
 claim:=public.begin_document_processing('47100000-0000-4000-8000-000000000003','47100000-0000-4000-8000-000000000001',
  '47100000-0000-4000-8000-000000000001/replacement.pdf');
 -- A replacement at the SAME path changes Storage identity/version metadata.
 insert into storage.objects(bucket_id,name) values('documents','47100000-0000-4000-8000-000000000001/replacement.pdf');
 begin
  perform public.complete_document_processing((claim->>'job_id')::uuid,(claim->>'lease_token')::uuid,
   current_setting('rad.ocr_extraction')::jsonb,'[]');
  raise exception 'same-path Storage replacement accepted';
 exception when serialization_failure then null; end;
 assert public.fail_document_processing((claim->>'job_id')::uuid,(claim->>'lease_token')::uuid,'private diagnostic should never persist');
 assert (select safe_error_code from public.document_processing_jobs where id=(claim->>'job_id')::uuid)='processing_unavailable';
 claim:=public.begin_document_processing('47100000-0000-4000-8000-000000000003','47100000-0000-4000-8000-000000000001',
  '47100000-0000-4000-8000-000000000001/replacement.pdf');
 assert public.fail_document_processing((claim->>'job_id')::uuid,(claim->>'lease_token')::uuid,'processing_unavailable');
 claim:=public.begin_document_processing('47100000-0000-4000-8000-000000000003','47100000-0000-4000-8000-000000000001',
  '47100000-0000-4000-8000-000000000001/replacement.pdf');
 assert claim->>'status'='rate_limited' and claim->>'claimed'='false';
 insert into public.documents(id,user_id,name,file_path) values('47100000-0000-4000-8000-000000000004',
  '47100000-0000-4000-8000-000000000001','Synthetic rate fixture','47100000-0000-4000-8000-000000000001/rate.pdf');
 insert into public.document_processing_jobs(document_id,user_id,status)
 select '47100000-0000-4000-8000-000000000003','47100000-0000-4000-8000-000000000001','failed' from generate_series(1,15);
 claim:=public.begin_document_processing('47100000-0000-4000-8000-000000000004','47100000-0000-4000-8000-000000000001',
  '47100000-0000-4000-8000-000000000001/rate.pdf');
 assert claim->>'status'='rate_limited','user could bypass the hourly cap with a new document';
end $$;
delete from public.documents where id='47100000-0000-4000-8000-000000000003';
do $$ begin
 assert (select count(*) from public.document_extractions where user_id='47100000-0000-4000-8000-000000000001')=0;
 assert (select count(*) from public.document_processing_jobs where user_id='47100000-0000-4000-8000-000000000001')=0;
 assert not exists(select 1 from private.document_processing_leases where job_id=(current_setting('rad.ocr_claim')::jsonb->>'job_id')::uuid);
end $$;
rollback;
