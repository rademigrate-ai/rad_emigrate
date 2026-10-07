-- Stage 2: Knowledge Base completion — retrieval, promotion, integrity, indexes.
-- Additive only. Does not rewrite migration history. Does not publish Feed.
-- Production mapping (project inshddthftkhcdosoqcn):
--   apply_migration stage2_knowledge_completion       → schema/columns/indexes/triggers
--   apply_migration stage2_promote_knowledge_fn       → promote_knowledge_from_evidence
--   apply_migration stage2_retrieve_and_conflict_fn   → retrieve_knowledge + register_knowledge_conflict
-- Repository representation: THIS single canonical file (replayable on clean pre-Stage-2 DB).
-- Seed of representative RAD knowledge is production data, not repeated here.

begin;

alter table public.knowledge_claims
  add column if not exists claim_key text,
  add column if not exists locale text,
  add column if not exists is_current boolean not null default true,
  add column if not exists superseded_by uuid references public.knowledge_claims(id) on delete set null,
  add column if not exists review_status text not null default 'unreviewed';

do $$ begin
  if not exists (
    select 1 from pg_constraint where conname = 'knowledge_claims_review_status_check'
  ) then
    alter table public.knowledge_claims
      add constraint knowledge_claims_review_status_check
      check (review_status in ('unreviewed','pending_review','approved','rejected','superseded','conflicting'));
  end if;
end $$;

update public.knowledge_claims
set claim_key = md5(lower(btrim(claim_text)))
where claim_key is null;

do $$ begin
  if not exists (select 1 from public.knowledge_claims where claim_key is null) then
    alter table public.knowledge_claims alter column claim_key set not null;
  end if;
end $$;

create unique index if not exists knowledge_claims_item_key_uidx
  on public.knowledge_claims (knowledge_item_id, claim_key)
  where is_current = true;

create index if not exists knowledge_claims_current_idx
  on public.knowledge_claims (knowledge_item_id, is_current)
  where is_current = true;

create unique index if not exists knowledge_citations_claim_snapshot_uidx
  on public.knowledge_citations (claim_id, snapshot_id);

alter table public.knowledge_items
  add column if not exists topic text,
  add column if not exists destination_code text,
  add column if not exists program_slug text,
  add column if not exists freshness_checked_at timestamptz,
  add column if not exists authority_priority integer not null default 50,
  add column if not exists search_vector tsvector;

create index if not exists knowledge_items_locale_status_idx
  on public.knowledge_items (language_code, review_status, updated_at desc);

create index if not exists knowledge_items_topic_idx
  on public.knowledge_items (topic)
  where topic is not null;

create index if not exists knowledge_items_destination_idx
  on public.knowledge_items (destination_code)
  where destination_code is not null;

create or replace function private.knowledge_items_search_vector_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.search_vector :=
    setweight(to_tsvector('simple', coalesce(new.title, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(new.summary, '')), 'B') ||
    setweight(to_tsvector('simple', coalesce(new.topic, '')), 'A');
  return new;
end;
$$;

drop trigger if exists knowledge_items_search_vector_trg on public.knowledge_items;
create trigger knowledge_items_search_vector_trg
  before insert or update of title, summary, topic
  on public.knowledge_items
  for each row execute function private.knowledge_items_search_vector_update();

create index if not exists knowledge_items_search_idx
  on public.knowledge_items using gin (search_vector);

create or replace function private.enforce_claim_citation_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.review_status = 'approved' then
    if not exists (
      select 1 from public.knowledge_citations c where c.claim_id = new.id
    ) then
      raise exception 'approved claim requires at least one citation'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists knowledge_claims_citation_integrity on public.knowledge_claims;
create trigger knowledge_claims_citation_integrity
  before update of review_status on public.knowledge_claims
  for each row
  when (new.review_status = 'approved' and old.review_status is distinct from 'approved')
  execute function private.enforce_claim_citation_integrity();

commit;
