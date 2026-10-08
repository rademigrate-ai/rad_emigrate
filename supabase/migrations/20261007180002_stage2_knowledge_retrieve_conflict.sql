-- Stage 2: retrieve_knowledge + register_knowledge_conflict (production-parity).
-- Applied on production as stage2_retrieve_and_conflict_fn.

begin;

create or replace function public.register_knowledge_conflict(
  p_jurisdiction text, p_statement_a text, p_statement_b text,
  p_citation_a_id uuid default null, p_citation_b_id uuid default null,
  p_proposed_interpretation text default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if coalesce(auth.jwt()->>'role','') not in ('service_role', '')
     and not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if coalesce(auth.jwt()->>'role','') = '' and session_user not in ('postgres', 'supabase_admin')
     and not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if length(btrim(p_statement_a)) < 4 or length(btrim(p_statement_b)) < 4 then
    raise exception 'invalid statements' using errcode = '22023';
  end if;
  insert into public.knowledge_conflicts (jurisdiction, statement_a, statement_b, citation_a_id, citation_b_id, proposed_interpretation, status)
  values (p_jurisdiction, btrim(p_statement_a), btrim(p_statement_b), p_citation_a_id, p_citation_b_id, p_proposed_interpretation, 'open')
  returning id into v_id;
  if p_citation_a_id is not null then
    update public.knowledge_claims c set review_status = 'conflicting' from public.knowledge_citations kc
    where kc.id = p_citation_a_id and kc.claim_id = c.id and c.review_status = 'approved';
  end if;
  if p_citation_b_id is not null then
    update public.knowledge_claims c set review_status = 'conflicting' from public.knowledge_citations kc
    where kc.id = p_citation_b_id and kc.claim_id = c.id and c.review_status = 'approved';
  end if;
  return v_id;
end; $$;

revoke all on function public.register_knowledge_conflict(text, text, text, uuid, uuid, text) from public, anon;
grant execute on function public.register_knowledge_conflict(text, text, text, uuid, uuid, text) to authenticated, service_role;

create or replace function public.retrieve_knowledge(
  p_query text, p_locale text default 'en', p_destination_code text default null,
  p_program_slug text default null, p_limit integer default 8
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 8), 20));
  v_locale text := case when p_locale in ('fa','en') then p_locale else 'en' end;
  v_tsquery tsquery;
  v_result jsonb;
begin
  begin
    v_tsquery := plainto_tsquery('simple', coalesce(p_query, ''));
  exception when others then
    v_tsquery := null;
  end;
  select coalesce(jsonb_agg(row_data order by rank_score desc, updated_at desc), '[]'::jsonb)
  into v_result
  from (
    select jsonb_build_object(
      'knowledge_item_id', ki.id, 'slug', ki.slug, 'title', ki.title, 'summary', ki.summary,
      'language_code', ki.language_code, 'jurisdiction', ki.jurisdiction,
      'destination_code', ki.destination_code, 'program_slug', ki.program_slug, 'topic', ki.topic,
      'version', ki.version, 'review_status', ki.review_status, 'effective_date', ki.effective_date,
      'freshness_checked_at', ki.freshness_checked_at, 'authority_priority', ki.authority_priority,
      'updated_at', ki.updated_at,
      'claims', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'claim_id', kc.id, 'claim_text', kc.claim_text, 'confidence', kc.confidence,
          'review_status', kc.review_status, 'is_current', kc.is_current, 'locale', kc.locale,
          'citations', (
            select coalesce(jsonb_agg(jsonb_build_object(
              'citation_id', cit.id, 'excerpt', cit.excerpt, 'locator', cit.locator,
              'snapshot_id', ss.id, 'fetched_at', ss.fetched_at,
              'source', jsonb_build_object(
                'document_id', sd.id, 'title', sd.title, 'canonical_url', sd.canonical_url,
                'source_authority', sd.source_authority, 'language_code', sd.language_code,
                'jurisdiction', sd.jurisdiction
              )
            )), '[]'::jsonb)
            from public.knowledge_citations cit
            join public.source_snapshots ss on ss.id = cit.snapshot_id
            join public.source_documents sd on sd.id = ss.document_id
            where cit.claim_id = kc.id
          )
        )), '[]'::jsonb)
        from public.knowledge_claims kc
        where kc.knowledge_item_id = ki.id and kc.is_current = true
          and kc.review_status in ('approved', 'conflicting')
      ),
      'open_conflicts', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'conflict_id', conf.id, 'statement_a', conf.statement_a, 'statement_b', conf.statement_b,
          'status', conf.status, 'jurisdiction', conf.jurisdiction
        )), '[]'::jsonb)
        from public.knowledge_conflicts conf
        where conf.status = 'open'
          and (conf.jurisdiction is not distinct from ki.jurisdiction or conf.jurisdiction is null)
        limit 5
      ),
      'rank_score', (
        coalesce(case when v_tsquery is not null and ki.search_vector @@ v_tsquery then ts_rank_cd(ki.search_vector, v_tsquery) * 10 else 0 end, 0)
        + case when ki.language_code = v_locale then 2.0 else 0.5 end
        + case when p_destination_code is not null and ki.destination_code = p_destination_code then 3.0 else 0 end
        + case when p_program_slug is not null and ki.program_slug = p_program_slug then 2.0 else 0 end
        + (100.0 - least(ki.authority_priority, 100)) / 20.0
        + case when ki.review_status = 'approved' then 1.0 else 0 end
      )
    ) as row_data,
    ki.updated_at,
    (
      coalesce(case when v_tsquery is not null and ki.search_vector @@ v_tsquery then ts_rank_cd(ki.search_vector, v_tsquery) * 10 else 0 end, 0)
      + case when ki.language_code = v_locale then 2.0 else 0.5 end
      + case when p_destination_code is not null and ki.destination_code = p_destination_code then 3.0 else 0 end
      + case when p_program_slug is not null and ki.program_slug = p_program_slug then 2.0 else 0 end
      + (100.0 - least(ki.authority_priority, 100)) / 20.0
    ) as rank_score
    from public.knowledge_items ki
    where ki.review_status = 'approved'
      and (
        v_tsquery is null
        or ki.search_vector @@ v_tsquery
        or ki.title ilike '%' || left(coalesce(p_query, ''), 80) || '%'
        or ki.summary ilike '%' || left(coalesce(p_query, ''), 80) || '%'
        or exists (select 1 from public.knowledge_claims kc2 where kc2.knowledge_item_id = ki.id and kc2.is_current and kc2.claim_text ilike '%' || left(coalesce(p_query, ''), 80) || '%')
      )
    order by rank_score desc, ki.updated_at desc
    limit v_limit
  ) ranked;
  return jsonb_build_object('query', p_query, 'locale', v_locale, 'destination_code', p_destination_code, 'program_slug', p_program_slug, 'count', jsonb_array_length(v_result), 'results', v_result, 'retrieved_at', now());
end; $$;

revoke all on function public.retrieve_knowledge(text, text, text, text, integer) from public;
grant execute on function public.retrieve_knowledge(text, text, text, text, integer) to anon, authenticated, service_role;

commit;
