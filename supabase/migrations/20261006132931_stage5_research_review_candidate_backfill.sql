-- Stage 5: make research finding -> review candidate creation atomic and
-- backfill findings produced by the pre-Stage-1 research-sync deployment.
-- This migration only creates review-state drafts. It never creates or
-- publishes feed items.
begin;

create or replace function public.create_research_review_candidate(
  p_job_id uuid,
  p_finding_id uuid,
  p_title text,
  p_summary text,
  p_language_code text default 'en'
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if p_finding_id is not null then
    -- Serialize candidate creation for the same finding without deleting or
    -- rewriting any existing review work.
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(p_finding_id::text, 0)
    );

    select id
      into v_id
      from public.content_drafts
      where research_finding_id = p_finding_id
      order by created_at
      limit 1;

    if v_id is not null then
      return v_id;
    end if;
  end if;

  insert into public.content_drafts (
    research_job_id,
    research_finding_id,
    language_code,
    title,
    body,
    status
  ) values (
    p_job_id,
    p_finding_id,
    case when p_language_code = 'fa' then 'fa' else 'en' end,
    left(coalesce(nullif(btrim(p_title), ''), 'Research finding'), 300),
    coalesce(p_summary, ''),
    'review'
  )
  returning id into v_id;

  return v_id;
end
$$;

alter function public.create_research_review_candidate(uuid, uuid, text, text, text)
  owner to postgres;
revoke all on function public.create_research_review_candidate(uuid, uuid, text, text, text)
  from public, anon, authenticated;
grant execute on function public.create_research_review_candidate(uuid, uuid, text, text, text)
  to service_role;

do $$
declare
  v_finding record;
begin
  for v_finding in
    select
      rf.id,
      rf.research_job_id,
      rf.summary,
      rf.finding_type,
      sd.title as source_title,
      sd.language_code
    from public.research_findings rf
    join public.source_snapshots ss on ss.id = rf.snapshot_id
    join public.source_documents sd on sd.id = ss.document_id
    where not exists (
      select 1
      from public.content_drafts cd
      where cd.research_finding_id = rf.id
    )
    order by rf.created_at, rf.id
  loop
    perform public.create_research_review_candidate(
      v_finding.research_job_id,
      v_finding.id,
      concat_ws(': ', nullif(btrim(v_finding.source_title), ''), v_finding.finding_type),
      v_finding.summary,
      v_finding.language_code
    );
  end loop;
end
$$;

commit;
