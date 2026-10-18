-- Forward-only proposal; validate in disposable local stacks before any rollout.
-- Provider calls occur outside transactions. A private lease fences completion.
create table private.document_processing_leases (
 job_id uuid primary key references public.document_processing_jobs(id) on delete cascade,
 lease_token uuid not null default gen_random_uuid(),
 expires_at timestamptz not null,
 file_path text not null,
 storage_snapshot jsonb not null,
 input_sha256 text check(input_sha256 is null or input_sha256 ~ '^[0-9a-f]{64}$')
);
alter table private.document_processing_leases enable row level security;
revoke all on private.document_processing_leases from public,anon,authenticated;
grant all on private.document_processing_leases to service_role;
create policy "service owns processing leases" on private.document_processing_leases
 for all to service_role using(true) with check(true);

-- Enqueue is mediated by the authenticated Edge handler and service-only claim.
revoke insert on public.document_processing_jobs from authenticated;
revoke update on public.document_fields from authenticated;
grant update(review_status,corrected_value,reviewed_by,reviewed_at) on public.document_fields to authenticated;

create function private.attribute_document_field_review()
returns trigger language plpgsql set search_path='' as $$
begin
 if coalesce(auth.jwt()->>'role','')='service_role' then return new; end if;
 -- Auth deletion may SET NULL a reviewer FK before cascading owned fields.
 -- Permit only that internal attribution nulling, never a client review/write.
 if coalesce(auth.jwt()->>'role','')='' and new.reviewed_by is null and old.reviewed_by is not null and
  (to_jsonb(new)-'reviewed_by') is not distinct from (to_jsonb(old)-'reviewed_by') then return new; end if;
 if auth.uid() is null then raise exception 'forbidden' using errcode='42501'; end if;
 if new.review_status='corrected' and nullif(btrim(new.corrected_value),'') is null then
  raise exception 'correction_required' using errcode='22023'; end if;
 if char_length(new.corrected_value)>4000 then raise exception 'correction_too_large' using errcode='22023'; end if;
 if new.review_status<>'corrected' then new.corrected_value:=null; end if;
 new.reviewed_by:=auth.uid(); new.reviewed_at:=now();
 insert into public.document_reviews(extraction_id,reviewer_id,decision,safe_notes)
 values(new.extraction_id,auth.uid(),case new.review_status when 'accepted' then 'approved'
  when 'rejected' then 'rejected' else 'changes_requested' end,'field_review:'||new.id::text);
 return new;
end $$;
revoke all on function private.attribute_document_field_review() from public,anon,authenticated;
grant execute on function private.attribute_document_field_review() to service_role;
create trigger attribute_document_field_review before update on public.document_fields
 for each row execute function private.attribute_document_field_review();

create function public.begin_document_processing(p_document_id uuid,p_user_id uuid,p_file_path text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d public.documents%rowtype; j public.document_processing_jobs%rowtype;
 l private.document_processing_leases%rowtype; snapshot jsonb;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('document-processing:'||p_user_id::text,0));
 select * into d from public.documents where id=p_document_id for update;
 if not found or d.user_id is distinct from p_user_id or d.file_path is distinct from p_file_path then
  raise exception 'document_not_owned' using errcode='42501'; end if;
 select coalesce((select jsonb_build_object('id',o.id,'version',o.version,'updated_at',o.updated_at)
  from storage.objects o where o.bucket_id='documents' and o.name=d.file_path),'{}'::jsonb) into snapshot;
 for j in select * from public.document_processing_jobs where document_id=d.id and status='running' order by created_at for update loop
  select * into l from private.document_processing_leases where job_id=j.id;
  if found and l.expires_at>clock_timestamp() and l.file_path=d.file_path and l.storage_snapshot=snapshot then
   return jsonb_build_object('job_id',j.id,'status','running','claimed',false,'retry_after_seconds',5);
  end if;
  update public.document_processing_jobs set status='failed',safe_error_code='lease_expired',finished_at=now() where id=j.id;
 end loop;
 if (select count(*) from public.document_processing_jobs where document_id=d.id and created_at>now()-interval '1 hour')>=5 or
  (select count(*) from public.document_processing_jobs where user_id=d.user_id and created_at>now()-interval '1 hour')>=20 then
  return jsonb_build_object('status','rate_limited','claimed',false,'retry_after_seconds',3600);
 end if;
 insert into public.document_processing_jobs(document_id,user_id,status,attempt_count,started_at)
 values(d.id,d.user_id,'running',1,now()) returning * into j;
 insert into private.document_processing_leases(job_id,expires_at,file_path,storage_snapshot)
 values(j.id,clock_timestamp()+interval '120 seconds',d.file_path,snapshot) returning * into l;
 return jsonb_build_object('job_id',j.id,'status','running','claimed',true,'lease_token',l.lease_token);
end $$;

create function public.complete_document_processing(p_job_id uuid,p_lease_token uuid,p_extraction jsonb,p_fields jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.document_processing_jobs%rowtype; d public.documents%rowtype;
 l private.document_processing_leases%rowtype; e public.document_extractions%rowtype;
 f jsonb; field_count integer;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
 -- Same document -> job lock order as claim; deletion uses the parent first too.
 select d0.* into d from public.documents d0 join public.document_processing_jobs j0 on j0.document_id=d0.id where j0.id=p_job_id for update of d0;
 select * into j from public.document_processing_jobs where id=p_job_id for update;
 select * into l from private.document_processing_leases where job_id=p_job_id for update;
 if j.id is null or l.job_id is null or l.lease_token is distinct from p_lease_token then
  raise exception 'processing_lease_invalid' using errcode='42501'; end if;
 if j.status in ('review_required','succeeded') then
  select * into e from public.document_extractions where job_id=j.id;
  if e.id is null then raise exception 'processing_invariant_failed'; end if;
  return jsonb_build_object('job_id',j.id,'extraction_id',e.id,'status',j.status,'field_count',
    (select count(*) from public.document_fields where extraction_id=e.id),'duplicate',true);
 end if;
 if j.status<>'running' or l.expires_at<=clock_timestamp() or d.id is null or
  d.user_id<>j.user_id or d.file_path is distinct from l.file_path or l.storage_snapshot is distinct from
   coalesce((select jsonb_build_object('id',o.id,'version',o.version,'updated_at',o.updated_at)
    from storage.objects o where o.bucket_id='documents' and o.name=d.file_path),'{}'::jsonb) then
  raise exception 'processing_lease_stale' using errcode='40001'; end if;
 if jsonb_typeof(p_extraction) is distinct from 'object' or jsonb_typeof(p_fields) is distinct from 'array' then
  raise exception 'invalid_extraction_shape' using errcode='22023'; end if;
 if octet_length(p_extraction::text)>1000000 or octet_length(p_fields::text)>1000000 or jsonb_array_length(p_fields)>200 or
  jsonb_typeof(p_extraction->'extracted_text') is distinct from 'string' or
  nullif(btrim(p_extraction->>'extracted_text'),'') is null or char_length(p_extraction->>'extracted_text')>200000 or
  char_length(p_extraction->>'engine') not between 1 and 100 or char_length(p_extraction->>'engine_version')>100 or
  char_length(p_extraction->>'language_code')>10 or coalesce(p_extraction->>'input_sha256','') !~ '^[0-9a-f]{64}$' then
  raise exception 'invalid_extraction' using errcode='22023'; end if;
 if exists(select 1 from jsonb_array_elements(p_fields) x where jsonb_typeof(x)<>'object' or
  coalesce(x->>'field_key','') !~ '^[a-zA-Z0-9_.-]{1,100}$' or char_length(x->>'field_value')>4000) then
  raise exception 'invalid_extraction_field' using errcode='22023'; end if;
 if exists(select 1 from jsonb_array_elements(p_fields) x group by x->>'field_key',x->>'page_number' having count(*)>1) then
  raise exception 'duplicate_extraction_field' using errcode='22023'; end if;
 insert into public.document_extractions(job_id,document_id,user_id,engine,engine_version,extracted_text,language_code,overall_confidence,page_count)
 values(j.id,j.document_id,j.user_id,p_extraction->>'engine',p_extraction->>'engine_version',p_extraction->>'extracted_text',
  p_extraction->>'language_code',(p_extraction->>'overall_confidence')::numeric,(p_extraction->>'page_count')::integer) returning * into e;
 for f in select value from jsonb_array_elements(p_fields) loop
  insert into public.document_fields(extraction_id,field_key,field_value,confidence,page_number,bounding_box,review_status)
  values(e.id,f->>'field_key',f->>'field_value',(f->>'confidence')::numeric,(f->>'page_number')::integer,null,'unreviewed');
 end loop;
 select count(*) into field_count from public.document_fields where extraction_id=e.id;
 update private.document_processing_leases set input_sha256=p_extraction->>'input_sha256' where job_id=j.id;
 update public.document_processing_jobs set status='review_required',safe_error_code=null,finished_at=now() where id=j.id;
 return jsonb_build_object('job_id',j.id,'extraction_id',e.id,'status','review_required','field_count',field_count,'duplicate',false);
end $$;

create function public.fail_document_processing(p_job_id uuid,p_lease_token uuid,p_error_code text)
returns boolean language plpgsql security definer set search_path='' as $$
declare changed integer;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
 if p_error_code is null or p_error_code not in ('no_ocr_provider_configured','invalid_ocr_configuration','storage_redirect_forbidden',
  'document_file_unavailable','unsupported_file_type','file_too_large','invalid_file_signature','provider_redirect_forbidden',
  'provider_rate_limited','provider_request_failed','provider_timeout','provider_response_too_large','provider_malformed_response','database_unavailable','processing_unavailable')
  then p_error_code:='processing_unavailable'; end if;
 update public.document_processing_jobs j set status='failed',safe_error_code=p_error_code,finished_at=now()
 where j.id=p_job_id and j.status='running' and exists(select 1 from private.document_processing_leases l
  where l.job_id=j.id and l.lease_token=p_lease_token);
 get diagnostics changed=row_count;
 return changed=1;
end $$;

alter function public.begin_document_processing(uuid,uuid,text) owner to postgres;
alter function public.complete_document_processing(uuid,uuid,jsonb,jsonb) owner to postgres;
alter function public.fail_document_processing(uuid,uuid,text) owner to postgres;
revoke all on function public.begin_document_processing(uuid,uuid,text),public.complete_document_processing(uuid,uuid,jsonb,jsonb),
 public.fail_document_processing(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.begin_document_processing(uuid,uuid,text),public.complete_document_processing(uuid,uuid,jsonb,jsonb),
 public.fail_document_processing(uuid,uuid,text) to service_role;
