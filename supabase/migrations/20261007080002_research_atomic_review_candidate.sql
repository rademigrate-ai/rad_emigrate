-- Atomic source evidence -> finding -> human review candidate. No Feed writes.
begin;
alter table public.source_documents add column last_content_hash text;
update public.source_documents d set last_content_hash=(select content_hash from public.source_snapshots where document_id=d.id order by fetched_at desc limit 1);
create function private.research_finding_review_candidate() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_title text; v_language text;
begin
 select d.title,d.language_code into v_title,v_language
 from public.source_snapshots s join public.source_documents d on d.id=s.document_id
 where s.id=new.snapshot_id;
 perform public.create_research_review_candidate(new.research_job_id,new.id,
  concat_ws(': ',v_title,new.finding_type),new.summary,v_language);
 return new;
end $$;
revoke all on function private.research_finding_review_candidate() from public,anon,authenticated;
create trigger research_finding_review_candidate after insert on public.research_findings
 for each row execute function private.research_finding_review_candidate();

create function public.ingest_research_snapshot(
 p_job_id uuid,p_document_id uuid,p_content_hash text,p_normalized_text text,
 p_http_status integer,p_metadata jsonb
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_snapshot uuid; v_finding uuid; v_url text; v_prior text;
begin
 if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
 if p_http_status not between 200 and 299 or length(btrim(p_normalized_text))=0
   or length(p_normalized_text)>100000 then raise exception 'invalid evidence' using errcode='22023'; end if;
 select canonical_url,last_content_hash into strict v_url,v_prior from public.source_documents where id=p_document_id for update;
 if v_prior=p_content_hash then return null; end if;
 -- Retry after an ambiguous network result is idempotent by document/hash.
 select id into v_snapshot from public.source_snapshots where document_id=p_document_id and content_hash=p_content_hash;
 if v_snapshot is null then
  insert into public.source_snapshots(document_id,content_hash,normalized_text,http_status,metadata)
  values(p_document_id,p_content_hash,p_normalized_text,p_http_status,p_metadata) returning id into v_snapshot;
 end if;
 insert into public.research_findings(research_job_id,snapshot_id,finding_type,summary)
 values(p_job_id,v_snapshot,case when v_prior is null then 'new' else 'changed' end,
  'Unreviewed source excerpt from '||v_url||E'\n\n'||left(p_normalized_text,4000)) returning id into v_finding;
 update public.source_documents set last_content_hash=p_content_hash,last_seen_at=now() where id=p_document_id;
 -- The trigger creates a review draft in this same transaction; a failure rolls
 -- back snapshot and finding too, so the next worker run can safely retry.
 return v_finding;
end $$;
revoke all on function public.ingest_research_snapshot(uuid,uuid,text,text,integer,jsonb) from public,anon,authenticated;
grant execute on function public.ingest_research_snapshot(uuid,uuid,text,text,integer,jsonb) to service_role;
commit;
