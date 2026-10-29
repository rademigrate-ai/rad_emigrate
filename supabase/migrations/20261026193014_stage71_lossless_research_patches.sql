-- Stage7.1 additive, held for explicit Staging approval. No historical rewrites.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
insert into private.rad_contract_schemas(name,schema) values('propose_structured_research_request','{"type":"object","properties":{"article_id":{"$ref":"#/$defs/UUID"},"locale":{"enum":["fa","en"]},"base_revision_id":{"$ref":"#/$defs/UUID"},"base_content_hash":{"$ref":"#/$defs/SHA256"},"base_rich_hash":{"$ref":"#/$defs/SHA256"},"source_id":{"$ref":"#/$defs/UUID"},"authority_id":{"$ref":"#/$defs/UUID"},"snapshot_id":{"$ref":"#/$defs/UUID"},"patches":{"type":"array","minItems":1,"maxItems":100,"items":{"type":"object","properties":{"id":{"$ref":"#/$defs/UUID"},"section_id":{"$ref":"#/$defs/UUID"},"block_id":{"$ref":"#/$defs/UUID"},"before_hash":{"$ref":"#/$defs/SHA256"},"operation":{"enum":["replace_text","add_after","remove"]},"path":{"type":"array","maxItems":30,"items":{"type":"string","maxLength":40}},"text":{"anyOf":[{"type":"string","minLength":1,"maxLength":40000},{"type":"null"}]},"new_block_id":{"anyOf":[{"$ref":"#/$defs/UUID"},{"type":"null"}]},"evidence":{"type":"object","properties":{"snapshot_id":{"$ref":"#/$defs/UUID"},"excerpt":{"type":"string","minLength":1,"maxLength":4000},"locator":{"type":"string","maxLength":1000}},"required":["snapshot_id","excerpt","locator"],"additionalProperties":false}},"required":["id","section_id","block_id","before_hash","operation","path","text","new_block_id","evidence"],"additionalProperties":false}},"request_key":{"$ref":"#/$defs/UUID"}},"required":["article_id","locale","base_revision_id","base_content_hash","base_rich_hash","source_id","authority_id","snapshot_id","patches","request_key"],"additionalProperties":false}'::jsonb);
insert into private.rad_contract_schemas(name,schema) values('save_structured_research_review_request','{"type":"object","properties":{"proposal_id":{"$ref":"#/$defs/UUID"},"expected_proposal_revision":{"type":"integer","minimum":1},"expected_review_revision":{"type":"integer","minimum":0},"base_revision_id":{"$ref":"#/$defs/UUID"},"base_content_hash":{"$ref":"#/$defs/SHA256"},"mode":{"enum":["save_review","create_draft","reject_proposal"]},"decisions":{"type":"array","maxItems":100,"items":{"type":"object","properties":{"section_id":{"$ref":"#/$defs/UUID"},"decision":{"enum":["accept","reject","edit"]},"edited_text":{"anyOf":[{"type":"string","maxLength":40000},{"type":"null"}]}},"required":["section_id","decision","edited_text"],"additionalProperties":false}},"note":{"type":"string","maxLength":2000},"request_key":{"$ref":"#/$defs/UUID"}},"required":["proposal_id","expected_proposal_revision","expected_review_revision","base_revision_id","base_content_hash","mode","decisions","note","request_key"],"additionalProperties":false}'::jsonb);
create table private.rad_structured_proposals(
 proposal_id uuid primary key references public.visa_research_proposals(id),
 base_revision_id uuid not null references public.visa_article_revisions(id),
 base_rich_hash text not null,source_id uuid not null references public.research_sources(id),patches jsonb not null
);
create table private.rad_structured_revision_ancestry(
 revision_id uuid primary key references public.visa_article_revisions(id),
 parent_revision_id uuid not null references public.visa_article_revisions(id),
 proposal_id uuid not null unique references public.visa_research_proposals(id),
 rich_hash text not null,decisions jsonb not null,created_at timestamptz not null default now()
);
alter table private.rad_structured_proposals enable row level security;
alter table private.rad_structured_revision_ancestry enable row level security;
revoke all on private.rad_structured_proposals,private.rad_structured_revision_ancestry from public,anon,authenticated,service_role;
create index rad_structured_base_idx on private.rad_structured_proposals(base_revision_id);
create index rad_structured_source_idx on private.rad_structured_proposals(source_id);
create index rad_structured_parent_idx on private.rad_structured_revision_ancestry(parent_revision_id);
create trigger rad_structured_proposals_immutable before update or delete on private.rad_structured_proposals for each row execute function private.rad_immutable();
create trigger rad_structured_ancestry_immutable before update or delete on private.rad_structured_revision_ancestry for each row execute function private.rad_immutable();

create function private.rad_rich_text(node jsonb) returns text language plpgsql immutable set search_path='' as $$
declare value jsonb;result text:='';begin
 if jsonb_typeof(node)='string' then return node#>>'{}';end if;
 if jsonb_typeof(node)='array' then
  for value in select x from jsonb_array_elements(node)x loop result:=concat_ws(E'\n',nullif(result,''),private.rad_rich_text(value));end loop;
 elsif jsonb_typeof(node)='object' then
  if node ? 'rows' then return concat_ws(E'\n',nullif(node->>'caption',''),private.rad_rich_text(node->'rows'));end if;
  if node ? 'items' then return private.rad_rich_text(node->'items');end if;
  result:=coalesce(node->>'text','');
  if node ? 'children' then result:=concat_ws(E'\n',nullif(result,''),nullif(private.rad_rich_text(node->'children'),''));end if;
 end if;
 return result;
end $$;

create function private.rad_apply_rich_patches(base jsonb,patches jsonb,decisions jsonb,require_all boolean)
returns jsonb language plpgsql set search_path='' as $$
declare result jsonb:=base;p jsonb;d jsonb;b jsonb;structure jsonb;updated jsonb;blocks jsonb;
 si integer;bi integer;path text[];value text;chosen text;begin
 if exists(select 1 from jsonb_array_elements(patches)x group by x->>'id' having count(*)>1)
 or exists(select 1 from jsonb_array_elements(patches)x group by x->>'block_id' having count(*)>1)
 or exists(select 1 from jsonb_array_elements(decisions)x group by x->>'section_id' having count(*)>1)
 or exists(select 1 from jsonb_array_elements(decisions)x where not exists(select 1 from jsonb_array_elements(patches)y where y->>'id'=x->>'section_id')) then
  raise exception 'duplicate_or_unknown_patch' using errcode='PT422';
 end if;
 for p in select x from jsonb_array_elements(patches)x loop
  select s.ordinality::integer-1,k.ordinality::integer-1,k.value into si,bi,b
  from jsonb_array_elements(result) with ordinality s cross join lateral jsonb_array_elements(s.value->'blocks') with ordinality k
  where s.value->>'id'=p->>'section_id' and k.value->>'id'=p->>'block_id';
  if b is null or encode(extensions.digest(b::text,'sha256'),'hex')<>p->>'before_hash' then raise exception 'rich_block_conflict' using errcode='PT409';end if;
  if not exists(select 1 from public.source_snapshots snap where snap.id=(p->'evidence'->>'snapshot_id')::uuid
   and length(p->'evidence'->>'excerpt')>0 and position(p->'evidence'->>'excerpt' in snap.normalized_text)>0) then
   raise exception 'patch_evidence_required' using errcode='PT422';end if;
  select x into d from jsonb_array_elements(decisions)x where x->>'section_id'=p->>'id';
  if d is null and require_all then raise exception 'each_patch_requires_explicit_decision' using errcode='PT422';end if;
  chosen:=coalesce(d->>'decision','accept');
  -- Validate even rejected patches; proposal storage must be internally valid.
  structure:=coalesce(b->'current_structure',b->'original_structure');
  path:=array(select jsonb_array_elements_text(p->'path'));
  value:=case when chosen='edit' then d->>'edited_text' else p->>'text' end;
  if p->>'operation'='replace_text' then
   if cardinality(path)=0 or exists(select 1 from unnest(path)x where x!~'^(text|caption|rows|items|children|[0-9]+)$')
    or jsonb_typeof(structure#>path) is distinct from 'string'
    or (path=array['text'] and structure->>'type' in('table','bullet_list','numbered_list'))
    or nullif(btrim(value),'') is null or length(value)>40000 then raise exception 'invalid_text_leaf_patch' using errcode='PT422';end if;
   structure:=jsonb_set(structure,path,to_jsonb(value),false);
   if structure=coalesce(b->'current_structure',b->'original_structure') then continue;end if;
   updated:=b||jsonb_build_object('current_structure',structure,'current_text',private.rad_rich_text(structure),
    'editorial_evidence',coalesce(b->'editorial_evidence','[]')||jsonb_build_array(p->'evidence'),
    'provenance_scope','original_structure_only; current_structure is human-edited and unverified');
  elsif p->>'operation'='add_after' then
   if cardinality(path)<>0 or p->>'new_block_id' is null or nullif(btrim(value),'') is null or length(value)>40000
    or exists(select 1 from jsonb_array_elements(result)s cross join lateral jsonb_array_elements(s->'blocks')k where k->>'id'=p->>'new_block_id') then
    raise exception 'invalid_added_block' using errcode='PT422';end if;
   structure:=jsonb_build_object('type','paragraph','text',value);
   updated:=jsonb_build_object('id',p->'new_block_id','type','paragraph','text',value,'original_structure',structure,
    'current_structure',structure,'current_text',value,'provenance','[]'::jsonb,'origin','human_editorial_addition',
    'editorial_evidence',jsonb_build_array(p->'evidence'));
  elsif p->>'operation'='remove' then
   if cardinality(path)<>0 or chosen='edit' then raise exception 'invalid_removed_block' using errcode='PT422';end if;
  else raise exception 'invalid_patch_operation' using errcode='PT422';end if;
  if chosen='reject' then continue;end if;
  select coalesce(jsonb_agg(x order by sort),'[]') into blocks from(
   select k.value x,k.ordinality::numeric sort from jsonb_array_elements(result->si->'blocks') with ordinality k
   where k.ordinality<>bi+1 or p->>'operation'='add_after'
   union all select updated,bi+1+case when p->>'operation'='add_after' then 0.5 else 0 end where p->>'operation'<>'remove'
  )q;
  result:=jsonb_set(result,array[si::text,'blocks'],blocks,false);
 end loop;
 return result;
end $$;

-- V1 is a derived searchable projection; the authoritative rich structure is
-- stored separately and is never reconstructed from this projection.
create function private.rad_project_rich(sections jsonb,base_sections jsonb,old_body jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare s jsonb;b jsonb;old_b jsonb;v jsonb;ref jsonb;ev jsonb;refs jsonb;flat jsonb:='[]';maps jsonb:='[]';
 output jsonb:='[]';part jsonb;typ text;txt text;pid uuid;i integer;j integer;idx integer:=0;ns uuid:='67ef6686-5f55-4ce9-9efa-d03045f46589';begin
 for s in select x from jsonb_array_elements(sections)x loop
  for b in select x from jsonb_array_elements(s->'blocks')x loop
   select k into old_b from jsonb_array_elements(base_sections)t cross join lateral jsonb_array_elements(t->'blocks')k where k->>'id'=b->>'id';
   refs:='[]';
   for ref in select x from jsonb_array_elements(coalesce(b->'provenance','[]'))x loop
    select jsonb_build_object('snapshot_id',snap.id,'claim_id',null,'excerpt',substring(snap.normalized_text from (ref->>'start')::integer+1 for least((ref->>'end')::integer-(ref->>'start')::integer,4000)),
     'locator','original source block; not verification of edited wording') into ev from public.source_snapshots snap where snap.id=(ref->>'snapshot_id')::uuid;
    if ev is not null and length(ev->>'excerpt')>0 and not refs @> jsonb_build_array(ev) then refs:=refs||jsonb_build_array(ev);end if;
   end loop;
   for ev in select x from jsonb_array_elements(coalesce(b->'editorial_evidence','[]'))x loop
    ev:=ev||jsonb_build_object('claim_id',null);if not refs @> jsonb_build_array(ev) then refs:=refs||jsonb_build_array(ev);end if;
   end loop;
   i:=0;
   if b=old_b then
    loop
     pid:=extensions.uuid_generate_v5(ns,(b->>'id')||':v1:'||i);
     select k into v from jsonb_array_elements(old_body->'sections')t cross join lateral jsonb_array_elements(t->'blocks')k where k->>'id'=pid::text;
     exit when v is null;
     flat:=flat||jsonb_build_array(jsonb_build_object('block',v,'refs',refs,'rich_id',b->'id'));i:=i+1;
    end loop;
   end if;
   if i=0 then
    txt:=coalesce(b->>'current_text',b->>'text',private.rad_rich_text(coalesce(b->'current_structure',b->'original_structure')));
    typ:=coalesce(b->'current_structure'->>'type',b->'original_structure'->>'type');
    if typ not in('paragraph','heading','callout') then typ:='callout';end if;
    for j in 0..greatest(0,(length(txt)-1)/11000) loop
     pid:=extensions.uuid_generate_v5(ns,(b->>'id')||':v1:'||j);
     v:=jsonb_build_object('id',pid,'type',typ,'text',substring(txt from j*11000+1 for 11000),'items','[]'::jsonb);
     flat:=flat||jsonb_build_array(jsonb_build_object('block',v,'refs',refs,'rich_id',b->'id'));
    end loop;
   end if;
  end loop;
 end loop;
 for v in select x from jsonb_array_elements(flat)x loop
  if part is null or jsonb_array_length(part->'blocks')>=100 then
   if part is not null then output:=output||jsonb_build_array(part);end if;
   pid:=extensions.uuid_generate_v5(ns,(old_body->>'article_id')||':projection:'||idx);
   part:=jsonb_build_object('id',pid,'anchor','content-'||(idx+1),'heading',old_body->'title','order',idx,'blocks','[]'::jsonb,'evidence_refs','[]'::jsonb);
   maps:=maps||jsonb_build_array(jsonb_build_object('section_id',pid,'anchor','content-'||(idx+1),'first_rich_block_id',v->'rich_id'));idx:=idx+1;
  end if;
  refs:=part->'evidence_refs';for ev in select x from jsonb_array_elements(v->'refs')x loop
   if not refs @> jsonb_build_array(ev) then refs:=refs||jsonb_build_array(ev);end if;
  end loop;
  part:=part||jsonb_build_object('blocks',(part->'blocks')||jsonb_build_array(v->'block'),'evidence_refs',refs);
 end loop;
 if part is not null then output:=output||jsonb_build_array(part);end if;
 return jsonb_build_object('sections',output,'projection_map',maps);
end $$;

create function public.get_structured_article_context(p_article_id uuid,p_locale text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.visa_article_revisions;rich jsonb;hashes jsonb;begin
 perform private.rad_require_admin();
 select v.* into r from public.visa_article_heads h join public.visa_article_revisions v on v.id=h.head_id where h.article_id=p_article_id and h.locale=p_locale;
 select composition into rich from private.rad_editorial_rich_revisions where revision_id=r.id;
 if r.id is null or rich is null then raise exception 'rich_baseline_unavailable' using errcode='PT404';end if;
 select jsonb_object_agg(b->>'id',encode(extensions.digest(b::text,'sha256'),'hex')) into hashes
 from jsonb_array_elements(rich->'sections')s cross join lateral jsonb_array_elements(s->'blocks')b;
 return private.rad_envelope(jsonb_build_object('article_id',r.article_id,'locale',r.locale,'revision_id',r.id,'revision',r.revision,
 'content_hash',r.content_hash,'rich_hash',encode(extensions.digest(rich::text,'sha256'),'hex'),'sections',rich->'sections','block_hashes',hashes),r.locale);
end $$;

create function public.propose_structured_research(p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();prior jsonb;r public.visa_article_revisions;rich jsonb;sid uuid;pid uuid;result jsonb;begin
 prior:=private.rad_begin_mutation('propose_structured_research',p_request);if prior is not null then return prior;end if;
 select v.* into r from public.visa_article_heads h join public.visa_article_revisions v on v.id=h.head_id
 where h.article_id=(p_request->>'article_id')::uuid and h.locale=p_request->>'locale' for update of h;
 select composition into rich from private.rad_editorial_rich_revisions where revision_id=r.id;
 if r.id is null or r.id<>(p_request->>'base_revision_id')::uuid or r.content_hash<>p_request->>'base_content_hash'
 or rich is null or encode(extensions.digest(rich::text,'sha256'),'hex')<>p_request->>'base_rich_hash' then raise exception 'baseline_conflict' using errcode='PT409';end if;
 sid:=(p_request->>'snapshot_id')::uuid;
 if not exists(select 1 from public.research_sources src join public.source_snapshots snap on snap.id=sid join public.source_documents doc on doc.id=snap.document_id
  join public.visa_articles a on a.id=r.article_id where src.id=(p_request->>'source_id')::uuid and src.country_code=a.country_code and src.topic=a.pathway_slug
  and doc.canonical_url=src.base_url)
 or not exists(select 1 from private.authority_entities ae join private.authority_domains ad on ad.authority_id=ae.id
  join public.source_snapshots snap on snap.id=sid join public.source_documents doc on doc.id=snap.document_id
  where ae.id=(p_request->>'authority_id')::uuid and ae.state in('candidate','verifying','verified')
  and ad.state in('candidate','verified') and ad.host=substring(doc.canonical_url from '^https://([^/:?#]+)')
  and starts_with(substring(doc.canonical_url from '^https://[^/]+(/[^?#]*)'),ad.path_prefix))
 or exists(select 1 from jsonb_array_elements(p_request->'patches')p where p->'evidence'->>'snapshot_id'<>sid::text) then
 raise exception 'source_scope_or_evidence_mismatch' using errcode='PT422';end if;
 perform private.rad_apply_rich_patches(rich->'sections',p_request->'patches','[]',false);
 insert into public.visa_research_proposals(article_id,locale,base_revision,authority_id,new_snapshot_id,changes,new_sections)
 values(r.article_id,r.locale,r.revision,(p_request->>'authority_id')::uuid,sid,'[]',r.body->'sections') returning id into pid;
 insert into private.rad_structured_proposals values(pid,r.id,p_request->>'base_rich_hash',(p_request->>'source_id')::uuid,p_request->'patches');
 result:=private.rad_envelope(jsonb_build_object('proposal_id',pid,'state','review','published',false),r.locale);
 return private.rad_finish_mutation('propose_structured_research',p_request,result);
end $$;

create function public.get_research_review_context_v2(p_proposal_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;structured private.rad_structured_proposals;begin
 result:=public.get_research_review_context(p_proposal_id);
 select * into structured from private.rad_structured_proposals where proposal_id=p_proposal_id;
 if found then result:=jsonb_set(result,'{data}',result->'data'||jsonb_build_object('structured_patches',structured.patches,'base_rich_hash',structured.base_rich_hash));end if;
 return result;
end $$;

create function private.rad_structured_accept_guard() returns trigger language plpgsql set search_path='' as $$
declare r_id uuid;
begin
 if new.state='approved' and old.state is distinct from new.state then
  if exists(select 1 from private.rad_structured_proposals where proposal_id=new.id)
   and not exists(select 1 from private.rad_structured_revision_ancestry where proposal_id=new.id) then
   raise exception 'structured_review_required' using errcode='PT409';end if;
  select h.head_id into r_id from public.visa_article_heads h where h.article_id=new.article_id and h.locale=new.locale;
  if exists(select 1 from private.rad_editorial_rich_revisions where revision_id=r_id)
   and not exists(select 1 from private.rad_structured_revision_ancestry where proposal_id=new.id) then
   raise exception 'rich_body_reconciliation_required' using errcode='PT422';end if;
 end if;
 return new;
end $$;
create trigger rad_structured_accept_guard before update on public.visa_research_proposals for each row execute function private.rad_structured_accept_guard();

create function public.save_structured_research_review(p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();prior jsonb;p public.visa_research_proposals;sp private.rad_structured_proposals;
 r public.visa_article_revisions;h public.visa_article_heads;rich jsonb;sections jsonb;projection jsonb;body jsonb;draft uuid;latest integer;result jsonb;capture private.rad_editorial_reference_maps;links jsonb;
begin
 prior:=private.rad_begin_mutation('save_structured_research_review',p_request);if prior is not null then return prior;end if;
 select * into p from public.visa_research_proposals where id=(p_request->>'proposal_id')::uuid for update;
 select * into sp from private.rad_structured_proposals where proposal_id=p.id;
 if p.id is null or sp.proposal_id is null then raise exception 'not_found' using errcode='PT404';end if;
 select coalesce(max(revision),0) into latest from private.rad_research_review_versions where proposal_id=p.id;
 if p.state<>'review' or p.revision<>(p_request->>'expected_proposal_revision')::integer or latest<>(p_request->>'expected_review_revision')::integer then raise exception 'review_conflict' using errcode='PT409';end if;
 select * into h from public.visa_article_heads where article_id=p.article_id and locale=p.locale for update;
 select * into r from public.visa_article_revisions where id=h.head_id;
 select composition into rich from private.rad_editorial_rich_revisions where revision_id=r.id;
 if r.id is null or r.id<>sp.base_revision_id or r.id<>(p_request->>'base_revision_id')::uuid or r.content_hash<>p_request->>'base_content_hash'
 or rich is null or encode(extensions.digest(rich::text,'sha256'),'hex')<>sp.base_rich_hash then raise exception 'baseline_conflict' using errcode='PT409';end if;
 sections:=private.rad_apply_rich_patches(rich->'sections',sp.patches,p_request->'decisions',p_request->>'mode'='create_draft');
 if p_request->>'mode'='create_draft' then
  if sections=rich->'sections' then raise exception 'no_content_change_use_review_or_reject' using errcode='PT422';end if;
  projection:=private.rad_project_rich(sections,rich->'sections',r.body);
  body:=r.body||jsonb_build_object('sections',projection->'sections','expected_revision',r.revision,'request_key',p_request->'request_key');
  perform private.rad_assert_request('save_visa_article_draft',body);
  if body->'sections'=r.body->'sections' then raise exception 'no_content_change_use_review_or_reject' using errcode='PT422';end if;
  draft:=private.rad_save_article(body);
  rich:=rich||jsonb_build_object('sections',sections,'projection_map',projection->'projection_map','parent_revision_id',r.id,'review_proposal_id',p.id);
  insert into private.rad_editorial_rich_revisions values(draft,rich);
  insert into private.rad_structured_revision_ancestry values(draft,r.id,p.id,encode(extensions.digest(rich::text,'sha256'),'hex'),p_request->'decisions',now());
  select * into capture from private.rad_editorial_reference_maps where revision_id=r.id and active;
  if found then
   select coalesce(jsonb_agg(case when x->>'target_block_id' is not null and not exists(select 1 from jsonb_array_elements(sections)s cross join lateral jsonb_array_elements(s->'blocks')b where b->>'id'=x->>'target_block_id')
    then x||jsonb_build_object('target_block_id',null,'target_anchor',null,'editorial_disposition','target explicitly removed; original source link retained') else x end),'[]') into links from jsonb_array_elements(capture.content->'links')x;
   capture.content:=capture.content||jsonb_build_object('links',links,'parent_revision_id',r.id,'editorial_evidence_status','unverified; source references retained');
   insert into private.rad_editorial_reference_maps(revision_id,input_hash,source_manifest_hash,content)
   values(draft,encode(extensions.digest(jsonb_build_array(capture.source_manifest_hash,capture.content)::text,'sha256'),'hex'),capture.source_manifest_hash,capture.content);
  end if;
  update public.visa_research_proposals set state='approved',revision=revision+1,reviewed_at=now(),reviewed_by=actor where id=p.id returning * into p;
 elsif p_request->>'mode'='reject_proposal' then
  if nullif(btrim(p_request->>'note'),'') is null then raise exception 'rejection_note_required' using errcode='PT422';end if;
  update public.visa_research_proposals set state='rejected',revision=revision+1,reviewed_at=now(),reviewed_by=actor where id=p.id returning * into p;
 end if;
 insert into private.rad_research_review_versions values(p.id,latest+1,r.id,actor,p_request->>'mode',p_request->'decisions',p_request->>'note',now());
 result:=private.rad_envelope(jsonb_build_object('proposal',private.rad_proposal_json(p),'review_revision',latest+1,'draft_revision',case when draft is null then null else private.rad_revision_result(draft) end,'published',false),p.locale);
 return private.rad_finish_mutation('save_structured_research_review',p_request,result);
end $$;

create or replace function public.review_research_proposal(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.visa_research_proposals; r public.visa_article_revisions; h public.visa_article_heads; prior jsonb; id uuid; result jsonb;
begin
 perform private.rad_require_admin();prior:=private.rad_begin_mutation('review_research_proposal',p_request);if prior is not null then return prior; end if;
 select * into p from public.visa_research_proposals where visa_research_proposals.id=(p_request->>'proposal_id')::uuid for update;
 if not found then raise exception 'not_found' using errcode='PT404'; end if;
 if p.revision<>(p_request->>'expected_revision')::integer or p.state<>'review' then raise exception 'proposal_conflict' using errcode='PT409'; end if;
 if p_request->>'decision'='reject' then
  if nullif(btrim(p_request->>'note'),'') is null then raise exception 'rejection_note_required' using errcode='PT422'; end if;
  update public.visa_research_proposals set state='rejected',revision=revision+1,reviewed_at=now(),reviewed_by=auth.uid() where visa_research_proposals.id=p.id returning * into p;
  result:=private.rad_envelope(jsonb_build_object('proposal',private.rad_proposal_json(p),'draft_revision',null),p.locale);
 else
  select * into h from public.visa_article_heads where article_id=p.article_id and locale=p.locale for update;
  select * into r from public.visa_article_revisions where visa_article_revisions.id=h.head_id;
  if r.revision is distinct from p.base_revision then raise exception 'revision_conflict' using errcode='PT409'; end if;
  if exists(select 1 from private.rad_editorial_rich_revisions where revision_id=r.id) then
   raise exception 'rich_body_reconciliation_required' using errcode='PT422';
  end if;
  id:=private.rad_save_article(r.body||jsonb_build_object('sections',p.new_sections,'expected_revision',p.base_revision,'request_key',p_request->'request_key'));
  update public.visa_research_proposals set state='approved',revision=revision+1,reviewed_at=now(),reviewed_by=auth.uid() where visa_research_proposals.id=p.id returning * into p;
  result:=private.rad_envelope(jsonb_build_object('proposal',private.rad_proposal_json(p),'draft_revision',private.rad_revision_result(id)),p.locale);
 end if;
 return private.rad_finish_mutation('review_research_proposal',p_request,result);
end $$;

revoke all on function private.rad_rich_text(jsonb),private.rad_apply_rich_patches(jsonb,jsonb,jsonb,boolean),private.rad_project_rich(jsonb,jsonb,jsonb),private.rad_structured_accept_guard(),
 public.get_structured_article_context(uuid,text),public.propose_structured_research(jsonb),public.get_research_review_context_v2(uuid),public.save_structured_research_review(jsonb),public.review_research_proposal(jsonb)
 from public,anon,authenticated,service_role;
grant execute on function public.get_structured_article_context(uuid,text),public.propose_structured_research(jsonb),public.get_research_review_context_v2(uuid),public.save_structured_research_review(jsonb),public.review_research_proposal(jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
