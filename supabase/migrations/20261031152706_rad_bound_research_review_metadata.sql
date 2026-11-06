begin;
-- Presentation context is read from the current registry, separately from the
-- immutable captured source evidence. It does not attest capture-time trust,
-- legal meaning, source publication dates, or legal effective dates.
create or replace function public.get_research_review_context_v2(p_proposal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;structured private.rad_structured_proposals;bound jsonb;begin
 -- The existing context reader performs the server-side Admin authorization
 -- before any private proposal, binding, authority or snapshot metadata is read.
 result:=public.get_research_review_context(p_proposal_id);
 select * into structured from private.rad_structured_proposals where proposal_id=p_proposal_id;
 if found then result:=jsonb_set(result,'{data}',result->'data'||jsonb_build_object('structured_patches',structured.patches,'base_rich_hash',structured.base_rich_hash));end if;
 select capture.evidence||jsonb_build_object('review_metadata',jsonb_build_object(
  'publisher_name',authority.name,'jurisdiction',authority.jurisdiction,'authority_state',authority.state,
  'context_scope','current_registry_context_not_capture_verification',
  'old_fetched_at',old_snapshot.fetched_at,'new_fetched_at',new_snapshot.fetched_at,
  'source_published_at',null::timestamptz,'effective_date',null::date,
  'uncertainty_code','human_legal_review_required','change_classification','bound_source_text_change'
 )) into bound
 from private.rad_bound_proposal_evidence capture
 join private.rad_official_refresh_bindings binding on binding.id=capture.binding_id
 left join private.authority_entities authority on authority.id=binding.authority_id
 left join public.source_snapshots old_snapshot on old_snapshot.id=(capture.evidence->>'old_snapshot_id')::uuid and old_snapshot.document_id=binding.document_id
 left join public.source_snapshots new_snapshot on new_snapshot.id=(capture.evidence->>'new_snapshot_id')::uuid and new_snapshot.document_id=binding.document_id
 where capture.proposal_id=p_proposal_id;
 if found then result:=jsonb_set(result,'{data}',result->'data'||jsonb_build_object('bound_source_change',bound));end if;
 return result;
end $$;
revoke all on function public.get_research_review_context_v2(uuid) from public,anon,service_role;
grant execute on function public.get_research_review_context_v2(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
