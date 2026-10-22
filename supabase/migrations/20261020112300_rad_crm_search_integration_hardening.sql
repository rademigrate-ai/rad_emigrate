-- Reviewed R05 consultation-only delta; notification v1/outbox contracts are retained.
begin;

alter table public.consultation_requests
  add column if not exists revision integer not null default 1 check (revision > 0);

create table if not exists public.consultation_request_events (
  id uuid primary key default gen_random_uuid(),
  consultation_id uuid not null references public.consultation_requests(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  event_type text not null check (event_type in ('created','status_changed','assignment_changed','note_changed')),
  from_status text,
  to_status text not null,
  revision integer not null,
  created_at timestamptz not null default now()
);
create index if not exists consultation_events_request_idx on public.consultation_request_events(consultation_id, created_at, id);
create index if not exists consultation_events_actor_idx on public.consultation_request_events(actor_id) where actor_id is not null;
alter table public.consultation_request_events enable row level security;
revoke all on public.consultation_request_events from public, anon, authenticated;
grant select(id, consultation_id, event_type, from_status, to_status, revision, created_at)
  on public.consultation_request_events to authenticated;
grant all on public.consultation_request_events to service_role;
drop policy if exists consultation_events_owner_read on public.consultation_request_events;
create policy consultation_events_owner_read on public.consultation_request_events for select to authenticated
  using (exists (select 1 from public.consultation_requests c where c.id=consultation_id
    and (c.user_id=(select auth.uid()) or private.has_role(array['admin','super_admin']))));
drop policy if exists consultation_events_service on public.consultation_request_events;
create policy consultation_events_service on public.consultation_request_events for all to service_role
  using(true) with check(true);

create or replace function private.consultation_revision() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op='INSERT' then new.revision := 1;
  elsif row(new.status,new.assigned_to,new.admin_note) is distinct from row(old.status,old.assigned_to,old.admin_note) then
    new.revision := old.revision + 1;
  else new.revision := old.revision;
  end if;
  return new;
end $$;
revoke all on function private.consultation_revision() from public, anon, authenticated;
drop trigger if exists trg_consultation_revision on public.consultation_requests;
create trigger trg_consultation_revision before insert or update on public.consultation_requests
  for each row execute function private.consultation_revision();

create or replace function private.consultation_event() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_type text; v_from text;
begin
  if tg_op='INSERT' then v_type := 'created';
  elsif new.revision=old.revision then return new;
  else
    v_from := old.status;
    v_type := case when new.status is distinct from old.status then 'status_changed'
      when new.assigned_to is distinct from old.assigned_to then 'assignment_changed' else 'note_changed' end;
  end if;
  insert into public.consultation_request_events(consultation_id,actor_id,event_type,from_status,to_status,revision)
    values(new.id,auth.uid(),v_type,v_from,new.status,new.revision);
  return new;
end $$;
revoke all on function private.consultation_event() from public, anon, authenticated;
drop trigger if exists trg_consultation_event on public.consultation_requests;
create trigger trg_consultation_event after insert or update on public.consultation_requests
  for each row execute function private.consultation_event();

create or replace function public.transition_admin_consultation(
  p_consultation_id uuid, p_status text, p_expected_revision integer, p_admin_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_revision integer;
begin
  if not private.has_role(array['admin','super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if p_expected_revision is null or p_expected_revision<1 or p_status is null then
    raise exception 'invalid_transition' using errcode='22023';
  end if;
  select revision into v_revision from public.consultation_requests where id=p_consultation_id for update;
  if not found then raise exception 'consultation_not_found' using errcode='P0002'; end if;
  if v_revision<>p_expected_revision then raise exception 'consultation_version_conflict' using errcode='40001'; end if;
  perform public.update_admin_consultation(p_consultation_id,p_status,p_admin_note);
  select revision into v_revision from public.consultation_requests where id=p_consultation_id;
  return jsonb_build_object('revision',v_revision,'status',p_status);
end $$;
revoke all on function public.transition_admin_consultation(uuid,text,integer,text) from public,anon;
grant execute on function public.transition_admin_consultation(uuid,text,integer,text) to authenticated;

create or replace function public.assign_admin_consultation(
  p_consultation_id uuid, p_assignee_id uuid, p_expected_revision integer
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_revision integer;
begin
  if not private.has_role(array['admin','super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if p_expected_revision is null or p_expected_revision<1 then raise exception 'invalid_revision' using errcode='22023'; end if;
  if p_assignee_id is not null and not exists(select 1 from public.profiles where id=p_assignee_id and role in ('admin','super_admin')) then
    raise exception 'assignee_must_be_admin' using errcode='22023';
  end if;
  select revision into v_revision from public.consultation_requests where id=p_consultation_id for update;
  if not found then raise exception 'consultation_not_found' using errcode='P0002'; end if;
  if v_revision<>p_expected_revision then raise exception 'consultation_version_conflict' using errcode='40001'; end if;
  update public.consultation_requests set assigned_to=p_assignee_id where id=p_consultation_id returning revision into v_revision;
  insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,safe_metadata)
    values(auth.uid(),'update','consultation_request',p_consultation_id::text,jsonb_build_object('assignment_changed',true,'assigned',p_assignee_id is not null));
  return jsonb_build_object('revision',v_revision,'assigned',p_assignee_id is not null);
end $$;
revoke all on function public.assign_admin_consultation(uuid,uuid,integer) from public,anon;
grant execute on function public.assign_admin_consultation(uuid,uuid,integer) to authenticated;


alter table public.visa_article_search_documents add column title_heading_normalized text generated always as (private.rad_search_normalize(title||' '||heading)) stored;
-- Materialize narrow keys/scores instead of 10,000 wide body/vector rows.
-- Resolve publication/filter metadata once per revision, before section ranking.
create or replace function public.search_visa_articles(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare query text;normalized_query text;terms tsquery;version text;off integer;lim integer:=(p_request->>'limit')::integer;hits jsonb;total integer;
begin
 perform private.rad_assert_request('search_visa_articles',p_request);
 normalized_query:=private.rad_search_normalize(p_request->>'query');
 if normalized_query='' or cardinality(string_to_array(normalized_query,' '))>8 then raise exception 'invalid_query' using errcode='PT422';end if;
 select coalesce((select canonical from private.rad_search_aliases where locale=p_request->>'locale' and alias=normalized_query and enabled),normalized_query) into query;
 terms:=plainto_tsquery('simple',query);
 select rad_search_version.version::text into version from private.rad_search_version;
 off:=coalesce((private.rad_page_position(p_request,version)->>'offset')::integer,0);
 with published as materialized(
  select h.published_id,h.article_id,h.locale,r.revision,a.kind
  from public.visa_article_heads h join public.visa_article_revisions r on r.id=h.published_id and r.article_id=h.article_id and r.locale=h.locale
  join public.visa_articles a on a.id=h.article_id
  where (h.locale=p_request->>'locale' or (p_request->>'allow_locale_fallback')::boolean)
  and (jsonb_array_length(p_request->'country_codes')=0 or p_request->'country_codes' ? a.country_code)
  and (jsonb_array_length(p_request->'pathway_slugs')=0 or p_request->'pathway_slugs' ? a.pathway_slug)
  and (p_request->>'article_kind' is null or a.kind=p_request->>'article_kind')
 ), matches as materialized(
  select d.article_id,d.revision_id,d.section_id,
  case when position(query in d.title_heading_normalized)>0 then 3 when d.vector @@ terms then 2 else 1 end bucket,
  case when d.vector @@ terms then ts_rank_cd(d.vector,terms)::numeric else extensions.similarity(d.normalized,query)::numeric end score
  from public.visa_article_search_documents d join published p on p.published_id=d.revision_id and p.article_id=d.article_id and p.locale=d.locale
  where d.vector @@ terms or position(query in d.normalized)>0 or (length(query)>=4 and d.normalized operator(extensions.%>) query)
 ), page as materialized(select * from matches order by bucket desc,score desc,article_id,section_id offset off limit lim),
 trust as materialized(select revisions.revision_id,private.rad_article_verification(revisions.revision_id) state from (select distinct revision_id from page) revisions)
 select (select count(*) from matches),coalesce(jsonb_agg(jsonb_build_object(
 'article_id',d.article_id,'revision_id',d.revision_id,'revision',p.revision,'article_kind',p.kind,'title',d.title,
 'section_id',d.section_id,'section_anchor',d.anchor,'match_locale',d.locale,
 'match_kind',case when query<>normalized_query then 'synonym' when page.bucket=3 then 'exact' when page.bucket=2 then 'full_text' else 'typo' end,
 'score',round(page.score,8)::text,'verification_state',trust.state,'freshness_state','unknown',
 'target',jsonb_build_object('kind','visa_article','id',d.article_id,'section_id',d.section_id))||private.rad_snippet(d.body,query)
 order by page.bucket desc,page.score desc,page.article_id,page.section_id),'[]') into total,hits
 from page join public.visa_article_search_documents d on d.revision_id=page.revision_id and d.section_id=page.section_id
 join published p on p.published_id=d.revision_id join trust on trust.revision_id=d.revision_id;
 return private.rad_envelope(jsonb_build_object('items',hits,'index_version',version,'query_normalized',normalized_query,'evidence_state','unknown'),p_request->>'locale',
 private.rad_page(p_request,version,jsonb_build_object('offset',off+lim),total>off+lim));
end $$;
update private.rad_search_version set version=version+1;
revoke all on function public.transition_admin_consultation(uuid,text,integer,text),public.assign_admin_consultation(uuid,uuid,integer) from public,anon,service_role;
grant execute on function public.transition_admin_consultation(uuid,text,integer,text),public.assign_admin_consultation(uuid,uuid,integer) to authenticated;
revoke execute on all functions in schema private from public,anon,authenticated;
grant execute on function private.has_role(text[]) to anon,authenticated;
notify pgrst,'reload schema';
commit;
