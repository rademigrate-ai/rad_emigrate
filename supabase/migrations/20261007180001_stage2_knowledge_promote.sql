-- Stage 2: promote_knowledge_from_evidence (production-parity).
-- Applied on production as stage2_promote_knowledge_fn.

begin;

create or replace function public.promote_knowledge_from_evidence(
  p_slug text, p_language_code text, p_title text, p_summary text, p_claim_text text,
  p_snapshot_id uuid, p_excerpt text default null, p_topic text default null,
  p_jurisdiction text default null, p_destination_code text default null,
  p_program_slug text default null, p_confidence text default 'medium', p_approve boolean default false
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_role text; v_item_id uuid; v_claim_id uuid; v_citation_id uuid; v_version int;
  v_claim_key text; v_snapshot_ok boolean; v_authority text; v_doc_id uuid;
  v_created_item boolean := false; v_created_claim boolean := false;
begin
  v_role := coalesce(auth.jwt()->>'role', '');
  if v_role not in ('service_role', '') and not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if v_role = '' and session_user not in ('postgres', 'supabase_admin')
     and not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_slug is null or length(btrim(p_slug)) < 2 then raise exception 'invalid slug' using errcode = '22023'; end if;
  if p_language_code not in ('fa','en') then raise exception 'invalid language' using errcode = '22023'; end if;
  if length(btrim(p_claim_text)) < 8 then raise exception 'claim too short' using errcode = '22023'; end if;
  if p_confidence not in ('unreviewed','low','medium','high') then raise exception 'invalid confidence' using errcode = '22023'; end if;
  select true, d.source_authority, s.document_id into v_snapshot_ok, v_authority, v_doc_id
  from public.source_snapshots s join public.source_documents d on d.id = s.document_id where s.id = p_snapshot_id;
  if not coalesce(v_snapshot_ok, false) then raise exception 'snapshot not found' using errcode = '22023'; end if;
  v_claim_key := md5(lower(btrim(p_claim_text)));
  select id, version into v_item_id, v_version from public.knowledge_items where slug = p_slug for update;
  if v_item_id is null then
    insert into public.knowledge_items (slug, language_code, jurisdiction, title, summary, topic, destination_code, program_slug, review_status, version, published_at, reviewed_at, authority_priority)
    values (p_slug, p_language_code, p_jurisdiction, p_title, p_summary, p_topic, p_destination_code, p_program_slug,
      case when p_approve then 'approved' else 'review' end, 1,
      case when p_approve then now() else null end, case when p_approve then now() else null end,
      case v_authority when 'rad_official' then 40 when 'government' then 10 when 'embassy' then 15 when 'institution' then 25 else 50 end)
    returning id, version into v_item_id, v_version;
    v_created_item := true;
    insert into public.knowledge_versions (knowledge_item_id, version, snapshot, changed_by)
    values (v_item_id, 1, jsonb_build_object('title', p_title, 'summary', p_summary, 'slug', p_slug, 'event', 'created', 'claim_key', v_claim_key), auth.uid());
  else
    if (select title from public.knowledge_items where id = v_item_id) is distinct from p_title
       or (select summary from public.knowledge_items where id = v_item_id) is distinct from p_summary then
      v_version := v_version + 1;
      update public.knowledge_items set title = p_title, summary = p_summary, topic = coalesce(p_topic, topic),
        jurisdiction = coalesce(p_jurisdiction, jurisdiction), destination_code = coalesce(p_destination_code, destination_code),
        program_slug = coalesce(p_program_slug, program_slug), version = v_version, updated_at = now(),
        review_status = case when p_approve then 'approved' else review_status end,
        published_at = case when p_approve and published_at is null then now() else published_at end,
        reviewed_at = case when p_approve then now() else reviewed_at end where id = v_item_id;
      insert into public.knowledge_versions (knowledge_item_id, version, snapshot, changed_by)
      values (v_item_id, v_version, jsonb_build_object('title', p_title, 'summary', p_summary, 'slug', p_slug, 'event', 'updated', 'claim_key', v_claim_key), auth.uid());
    elsif p_approve then
      update public.knowledge_items set review_status = 'approved', published_at = coalesce(published_at, now()), reviewed_at = now(), updated_at = now()
      where id = v_item_id and review_status is distinct from 'approved';
    end if;
  end if;
  select id into v_claim_id from public.knowledge_claims where knowledge_item_id = v_item_id and claim_key = v_claim_key and is_current for update;
  if v_claim_id is null then
    insert into public.knowledge_claims (knowledge_item_id, claim_text, claim_key, confidence, locale, review_status, is_current)
    values (v_item_id, btrim(p_claim_text), v_claim_key, p_confidence, p_language_code, case when p_approve then 'approved' else 'pending_review' end, true)
    returning id into v_claim_id;
    v_created_claim := true;
  else
    update public.knowledge_claims set confidence = p_confidence, review_status = case when p_approve then 'approved' else review_status end where id = v_claim_id;
  end if;
  insert into public.knowledge_citations (claim_id, snapshot_id, excerpt)
  values (v_claim_id, p_snapshot_id, left(coalesce(nullif(btrim(p_excerpt), ''), p_claim_text), 2000))
  on conflict (claim_id, snapshot_id) do update set excerpt = excluded.excerpt
  returning id into v_citation_id;
  if p_approve then
    update public.knowledge_claims set review_status = 'approved' where id = v_claim_id and review_status is distinct from 'approved';
  end if;
  return jsonb_build_object('knowledge_item_id', v_item_id, 'claim_id', v_claim_id, 'citation_id', v_citation_id, 'version', v_version, 'created_item', v_created_item, 'created_claim', v_created_claim, 'snapshot_id', p_snapshot_id, 'authority', v_authority);
end; $$;

revoke all on function public.promote_knowledge_from_evidence(text, text, text, text, text, uuid, text, text, text, text, text, text, boolean) from public, anon;
grant execute on function public.promote_knowledge_from_evidence(text, text, text, text, text, uuid, text, text, text, text, text, text, boolean) to authenticated, service_role;

commit;
