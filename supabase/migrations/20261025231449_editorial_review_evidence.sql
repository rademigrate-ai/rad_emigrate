-- Original immutable source bodies are an Admin review surface, never a public
-- bypass around article approval/publication or the published search index.
begin;
create or replace function public.get_editorial_source_snapshot(p_article_id uuid,p_snapshot_id uuid,p_revision_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;begin
 perform private.rad_require_admin();
 if not exists(select 1 from public.visa_article_revisions r
 left join private.rad_editorial_rich_revisions rich on rich.revision_id=r.id
 where r.article_id=p_article_id and (p_revision_id is null or r.id=p_revision_id) and (
  exists(select 1 from jsonb_array_elements(rich.composition->'sections')sec
   cross join lateral jsonb_array_elements(sec->'blocks')b
   cross join lateral jsonb_array_elements(b->'provenance')ref where (ref->>'snapshot_id')::uuid=p_snapshot_id)
  or exists(select 1 from public.visa_article_sections sec cross join lateral jsonb_array_elements(sec.evidence_refs)e
   where sec.revision_id=r.id and (e->>'snapshot_id')::uuid=p_snapshot_id))) then
 raise exception 'snapshot_not_bound_to_article_revision' using errcode='PT404';end if;
 select jsonb_build_object('snapshot_id',s.id,'source_document_id',d.id,'url',d.canonical_url,'title',d.title,
 'locale',d.language_code,'body_text',s.normalized_text,'body_sha256',s.content_hash,'fetched_at',s.fetched_at,
 'official_verification_status','not_inferred_from_source_retrieval') into result
 from public.source_snapshots s join public.source_documents d on d.id=s.document_id where s.id=p_snapshot_id;
 if result is null then raise exception 'not_found' using errcode='PT404';end if;
 return private.rad_envelope(result);
end $$;
revoke all on function public.get_editorial_source_snapshot(uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_editorial_source_snapshot(uuid,uuid,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
