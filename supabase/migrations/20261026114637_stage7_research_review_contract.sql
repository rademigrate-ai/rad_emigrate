-- Stage7: complete, server-bound proposal review; no automatic publication.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
alter table public.research_sources add column if not exists editorial_source_type text
 check(editorial_source_type in('government','embassy','university','professional_body','admin_reference'));
-- New objects deliberately fail on a name collision. No existing review
-- implementation, contract schema, or trigger may be replaced by this migration.
create table private.rad_research_review_versions(
 proposal_id uuid not null references public.visa_research_proposals(id),revision integer not null,
 base_revision_id uuid not null references public.visa_article_revisions(id),
 actor_id uuid not null references auth.users(id),mode text not null,decisions jsonb not null,note text not null,
 created_at timestamptz not null default now(),primary key(proposal_id,revision)
);
alter table private.rad_research_review_versions enable row level security;
revoke all on private.rad_research_review_versions from public,anon,authenticated,service_role;
create index if not exists rad_research_review_base_idx on private.rad_research_review_versions(base_revision_id);
create index if not exists rad_research_review_actor_idx on private.rad_research_review_versions(actor_id);
create trigger rad_research_review_immutable before update or delete on private.rad_research_review_versions
 for each row execute function private.rad_immutable();
insert into private.rad_contract_schemas(name,schema) values('save_research_review_request','{"type":"object","properties":{"proposal_id":{"$ref":"#/$defs/UUID"},"expected_proposal_revision":{"type":"integer","minimum":1},"expected_review_revision":{"type":"integer","minimum":0},"base_revision_id":{"$ref":"#/$defs/UUID"},"base_content_hash":{"$ref":"#/$defs/SHA256"},"mode":{"enum":["save_review","create_draft","reject_proposal"]},"decisions":{"type":"array","maxItems":100,"items":{"type":"object","properties":{"section_id":{"$ref":"#/$defs/UUID"},"decision":{"enum":["accept","reject","edit"]},"edited_text":{"anyOf":[{"type":"string","maxLength":20000},{"type":"null"}]}},"required":["section_id","decision","edited_text"],"additionalProperties":false}},"note":{"type":"string","maxLength":2000},"request_key":{"$ref":"#/$defs/UUID"}},"required":["proposal_id","expected_proposal_revision","expected_review_revision","base_revision_id","base_content_hash","mode","decisions","note","request_key"],"additionalProperties":false}'::jsonb);
insert into private.rad_contract_schemas(name,schema) values('upsert_editorial_research_source_request','{"type":"object","properties":{"source_id":{"anyOf":[{"$ref":"#/$defs/UUID"},{"type":"null"}]},"display_name":{"type":"string","minLength":1,"maxLength":200},"base_url":{"type":"string","minLength":8,"maxLength":2000},"source_type":{"enum":["government","embassy","university","professional_body","admin_reference"]},"country_code":{"anyOf":[{"type":"string","pattern":"^[A-Z]{2}$"},{"type":"null"}]},"visa_category":{"anyOf":[{"type":"string","maxLength":100},{"type":"null"}]},"request_key":{"$ref":"#/$defs/UUID"}},"required":["source_id","display_name","base_url","source_type","country_code","visa_category","request_key"],"additionalProperties":false}'::jsonb);

create function public.upsert_editorial_research_source(p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();prior jsonb;source_id_value uuid;legacy_type text;result jsonb;begin
 prior:=private.rad_begin_mutation('upsert_editorial_research_source',p_request);if prior is not null then return prior;end if;
 if btrim(p_request->>'display_name')='' or not private.is_safe_public_https_url(p_request->>'base_url')
 or p_request->>'base_url'~'[?#]' then raise exception 'invalid_source_url' using errcode='PT422';end if;
 legacy_type:=case p_request->>'source_type' when 'university' then 'institution' when 'professional_body' then 'institution'
 when 'admin_reference' then 'external' else p_request->>'source_type' end;
 source_id_value:=public.upsert_research_source((p_request->>'source_id')::uuid,btrim(p_request->>'display_name'),p_request->>'base_url',legacy_type,
 'admin_defined','admin',false,p_request->>'country_code',nullif(btrim(p_request->>'visa_category'),''));
 update public.research_sources set editorial_source_type=p_request->>'source_type' where research_sources.id=source_id_value;
 result:=private.rad_envelope(jsonb_build_object('source_id',source_id_value,'trust_class','admin_defined','enabled',false,
 'country_code',p_request->'country_code','visa_category',p_request->'visa_category','source_type',p_request->'source_type'));
 return private.rad_finish_mutation('upsert_editorial_research_source',p_request,result);
end $$;

create function public.get_research_review_context(p_proposal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.visa_research_proposals;r public.visa_article_revisions;h public.visa_article_heads;review private.rad_research_review_versions;begin
 perform private.rad_require_admin();
 select * into p from public.visa_research_proposals where id=p_proposal_id;
 if not found then raise exception 'not_found' using errcode='PT404';end if;
 select * into r from public.visa_article_revisions where article_id=p.article_id and locale=p.locale and revision=p.base_revision;
 if not found then raise exception 'baseline_unavailable' using errcode='PT409';end if;
 select * into h from public.visa_article_heads where article_id=p.article_id and locale=p.locale;
 select * into review from private.rad_research_review_versions where proposal_id=p.id order by revision desc limit 1;
 return private.rad_envelope(jsonb_build_object('proposal',private.rad_proposal_json(p),
 'base',jsonb_build_object('article_id',r.article_id,'locale',r.locale,'revision_id',r.id,'revision',r.revision,
 'content_hash',r.content_hash,'title',r.title,'body',r.body,
 'rich_sections',(select composition->'sections' from private.rad_editorial_rich_revisions where revision_id=r.id)),
 'stale',h.head_id is distinct from r.id,'review_revision',coalesce(review.revision,0),
 'decisions',coalesce(review.decisions,'[]'::jsonb),'note',coalesce(review.note,'')),p.locale);
end $$;

create function public.save_research_review(p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();prior jsonb;p public.visa_research_proposals;r public.visa_article_revisions;
 h public.visa_article_heads;latest integer;change jsonb;choice jsonb;existing jsonb;replacement jsonb;computed jsonb;
 body jsonb;draft uuid;result jsonb;begin
 prior:=private.rad_begin_mutation('save_research_review',p_request);if prior is not null then return prior;end if;
 select * into p from public.visa_research_proposals where id=(p_request->>'proposal_id')::uuid for update;
 if not found then raise exception 'not_found' using errcode='PT404';end if;
 select coalesce(max(revision),0) into latest from private.rad_research_review_versions where proposal_id=p.id;
 if p.state<>'review' or p.revision<>(p_request->>'expected_proposal_revision')::integer
 or latest<>(p_request->>'expected_review_revision')::integer then raise exception 'review_conflict' using errcode='PT409';end if;
 select * into h from public.visa_article_heads where article_id=p.article_id and locale=p.locale for update;
 select * into r from public.visa_article_revisions where id=h.head_id;
 if r.id is null or r.id<>(p_request->>'base_revision_id')::uuid or r.revision<>p.base_revision
 or r.content_hash<>p_request->>'base_content_hash' then raise exception 'baseline_conflict' using errcode='PT409';end if;
 if exists(select 1 from jsonb_array_elements(p_request->'decisions')d group by d->>'section_id' having count(*)>1)
 or exists(select 1 from jsonb_array_elements(p_request->'decisions')d where not exists(
 select 1 from jsonb_array_elements(p.changes)c where c->>'section_id'=d->>'section_id')) then
 raise exception 'invalid_section_decision' using errcode='PT422';end if;
 if p_request->>'mode'='create_draft' then
  computed:=r.body->'sections';
  for change in select value from jsonb_array_elements(p.changes) loop
   select value into choice from jsonb_array_elements(p_request->'decisions') where value->>'section_id'=change->>'section_id';
   if choice is null then raise exception 'each_change_requires_explicit_decision' using errcode='PT422';end if;
   select value into existing from jsonb_array_elements(computed) where value->>'id'=change->>'section_id';
   if change->>'operation'='add' then
    if existing is not null or change->>'before_hash' is not null then raise exception 'section_conflict' using errcode='PT409';end if;
   elsif existing is null or change->>'before_hash' is distinct from encode(extensions.digest(existing::text,'sha256'),'hex') then
    raise exception 'section_conflict' using errcode='PT409';end if;
   if choice->>'decision'='reject' then continue;end if;
   replacement:=change->'replacement';
   if choice->>'decision'='edit' then
    if change->>'operation'='remove' or jsonb_array_length(replacement->'blocks')<>1
    or replacement->'blocks'->0->>'type'<>'paragraph' or nullif(btrim(choice->>'edited_text'),'') is null then
     raise exception 'structured_section_requires_cms_editor' using errcode='PT422';end if;
    replacement:=jsonb_set(replacement,'{blocks,0,text}',choice->'edited_text');
   end if;
   if change->>'operation'<>'remove' then
    if replacement->>'id' is distinct from change->>'section_id' or not exists(
     select 1 from jsonb_array_elements(replacement->'evidence_refs')e join public.source_snapshots s on s.id=(e->>'snapshot_id')::uuid
     where s.id=p.new_snapshot_id and length(e->>'excerpt')>0 and position(e->>'excerpt' in s.normalized_text)>0) then
     raise exception 'proposal_evidence_required' using errcode='PT422';end if;
   end if;
   select coalesce(jsonb_agg(value),'[]') into computed from jsonb_array_elements(computed) where value->>'id'<>change->>'section_id';
   if change->>'operation'<>'remove' then computed:=computed||jsonb_build_array(replacement);end if;
  end loop;
  select coalesce(jsonb_agg(value order by (value->>'order')::integer),'[]') into computed from jsonb_array_elements(computed);
  -- Imported rich bodies have a lossy v1 projection. Until a proposal carries
  -- a reviewed, source-bound rich patch, never silently replace tables/lists
  -- with that projection. Saving decisions and rejecting remain available.
  if exists(select 1 from private.rad_editorial_rich_revisions where revision_id=r.id)
   and (select jsonb_agg(value-'evidence_refs' order by ordinality) from jsonb_array_elements(computed) with ordinality)
    is distinct from (select jsonb_agg(value-'evidence_refs' order by ordinality) from jsonb_array_elements(r.body->'sections') with ordinality) then
   raise exception 'rich_body_reconciliation_required' using errcode='PT422';
  end if;
  body:=r.body||jsonb_build_object('sections',computed,'expected_revision',r.revision,'request_key',p_request->'request_key');
  perform private.rad_assert_request('save_visa_article_draft',body);
  draft:=private.rad_save_article(body);
  update public.visa_research_proposals set state='approved',revision=revision+1,reviewed_at=now(),reviewed_by=actor where id=p.id returning * into p;
 elsif p_request->>'mode'='reject_proposal' then
  if nullif(btrim(p_request->>'note'),'') is null then raise exception 'rejection_note_required' using errcode='PT422';end if;
  update public.visa_research_proposals set state='rejected',revision=revision+1,reviewed_at=now(),reviewed_by=actor where id=p.id returning * into p;
 end if;
 insert into private.rad_research_review_versions values(p.id,latest+1,r.id,actor,p_request->>'mode',p_request->'decisions',p_request->>'note',now());
 result:=private.rad_envelope(jsonb_build_object('proposal',private.rad_proposal_json(p),'review_revision',latest+1,
 'draft_revision',case when draft is null then null else private.rad_revision_result(draft) end,'published',false),p.locale);
 return private.rad_finish_mutation('save_research_review',p_request,result);
end $$;
revoke all on function public.upsert_editorial_research_source(jsonb),public.get_research_review_context(uuid),public.save_research_review(jsonb)
 from public,anon,authenticated,service_role;
grant execute on function public.upsert_editorial_research_source(jsonb),public.get_research_review_context(uuid),public.save_research_review(jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
