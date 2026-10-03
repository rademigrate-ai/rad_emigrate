-- Project 10: reviewed knowledge base and bounded RAD research ingestion.
begin;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net;

create table public.source_documents (
  id uuid primary key default gen_random_uuid(),
  canonical_url text not null unique,
  source_id uuid references public.content_sources(id) on delete set null,
  source_authority text not null check (source_authority in ('rad_official','government','embassy','institution','other')),
  title text not null,
  language_code text not null check (language_code in ('fa','en')),
  jurisdiction text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  removed_at timestamptz
);

create table public.source_snapshots (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.source_documents(id) on delete cascade,
  content_hash text not null,
  normalized_text text not null,
  http_status integer,
  fetched_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique (document_id, content_hash)
);

create table public.knowledge_items (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  language_code text not null check (language_code in ('fa','en')),
  jurisdiction text,
  title text not null,
  summary text not null,
  effective_date date,
  review_status text not null default 'draft'
    check (review_status in ('draft','review','approved','rejected','archived')),
  version integer not null default 1 check (version > 0),
  created_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.knowledge_claims (
  id uuid primary key default gen_random_uuid(),
  knowledge_item_id uuid not null references public.knowledge_items(id) on delete cascade,
  claim_text text not null,
  confidence text not null default 'unreviewed'
    check (confidence in ('unreviewed','low','medium','high')),
  effective_date date,
  created_at timestamptz not null default now()
);

create table public.knowledge_citations (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.knowledge_claims(id) on delete cascade,
  snapshot_id uuid not null references public.source_snapshots(id) on delete restrict,
  excerpt text check (char_length(excerpt) <= 1000),
  locator text,
  created_at timestamptz not null default now(),
  unique (claim_id, snapshot_id, locator)
);

create table public.knowledge_conflicts (
  id uuid primary key default gen_random_uuid(),
  jurisdiction text,
  statement_a text not null,
  statement_b text not null,
  citation_a_id uuid references public.knowledge_citations(id) on delete set null,
  citation_b_id uuid references public.knowledge_citations(id) on delete set null,
  proposed_interpretation text,
  status text not null default 'open'
    check (status in ('open','reviewing','resolved','dismissed')),
  resolved_by uuid references auth.users(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.research_jobs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null check (job_type in ('rad_site_sync','official_source_refresh','targeted_research')),
  status text not null default 'queued'
    check (status in ('queued','running','succeeded','failed','cancelled')),
  requested_by uuid references auth.users(id) on delete set null,
  trigger_type text not null check (trigger_type in ('manual','scheduled','system')),
  idempotency_key text not null unique,
  input jsonb not null default '{}'::jsonb,
  attempts integer not null default 0 check (attempts >= 0),
  max_attempts integer not null default 3 check (max_attempts between 1 and 5),
  next_attempt_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz,
  error_code text,
  safe_error text,
  created_at timestamptz not null default now()
);

create table public.research_findings (
  id uuid primary key default gen_random_uuid(),
  research_job_id uuid not null references public.research_jobs(id) on delete cascade,
  snapshot_id uuid references public.source_snapshots(id) on delete set null,
  finding_type text not null check (finding_type in ('new','changed','removed','agreement','conflict','error')),
  summary text not null,
  review_status text not null default 'review'
    check (review_status in ('review','approved','rejected')),
  created_at timestamptz not null default now()
);

create table public.content_drafts (
  id uuid primary key default gen_random_uuid(),
  knowledge_item_id uuid references public.knowledge_items(id) on delete set null,
  research_job_id uuid references public.research_jobs(id) on delete set null,
  language_code text not null check (language_code in ('fa','en')),
  title text not null,
  body text not null,
  status text not null default 'draft'
    check (status in ('draft','review','approved','rejected','published')),
  created_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.knowledge_versions (
  id uuid primary key default gen_random_uuid(),
  knowledge_item_id uuid not null references public.knowledge_items(id) on delete cascade,
  version integer not null,
  snapshot jsonb not null,
  changed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (knowledge_item_id, version)
);

create table public.research_sources (
  id uuid primary key default gen_random_uuid(),
  base_url text not null unique,
  allowed_host text not null unique,
  authority text not null,
  enabled boolean not null default true,
  minimum_interval interval not null default interval '24 hours',
  last_attempt_at timestamptz,
  last_success_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.research_worker_config (
  singleton boolean primary key default true check (singleton),
  invocation_token text not null default gen_random_uuid()::text,
  max_sources_per_run integer not null default 3 check (max_sources_per_run between 1 and 10),
  request_timeout_ms integer not null default 12000 check (request_timeout_ms between 1000 and 30000),
  updated_at timestamptz not null default now()
);

insert into public.research_sources (base_url, allowed_host, authority)
values
  ('https://radvisa.com/','radvisa.com','rad_official'),
  ('https://digivisa.ir/','digivisa.ir','rad_official'),
  ('https://radmohajer.ir/fa/','radmohajer.ir','rad_official')
on conflict (base_url) do nothing;
insert into public.research_worker_config(singleton) values (true) on conflict do nothing;

create index source_snapshots_document_fetched_idx on public.source_snapshots(document_id, fetched_at desc);
create index knowledge_items_review_idx on public.knowledge_items(review_status, language_code, updated_at desc);
create index knowledge_claims_item_idx on public.knowledge_claims(knowledge_item_id);
create index knowledge_citations_claim_idx on public.knowledge_citations(claim_id);
create index knowledge_conflicts_status_idx on public.knowledge_conflicts(status, created_at desc);
create index research_jobs_queue_idx on public.research_jobs(status, next_attempt_at, created_at);
create index research_findings_review_idx on public.research_findings(review_status, created_at desc);
create index content_drafts_review_idx on public.content_drafts(status, created_at desc);

alter table public.source_documents enable row level security;
alter table public.source_snapshots enable row level security;
alter table public.knowledge_items enable row level security;
alter table public.knowledge_claims enable row level security;
alter table public.knowledge_citations enable row level security;
alter table public.knowledge_conflicts enable row level security;
alter table public.research_jobs enable row level security;
alter table public.research_findings enable row level security;
alter table public.content_drafts enable row level security;
alter table public.knowledge_versions enable row level security;
alter table public.research_sources enable row level security;
alter table public.research_worker_config enable row level security;

revoke all on table public.source_documents, public.source_snapshots,
  public.knowledge_items, public.knowledge_claims, public.knowledge_citations,
  public.knowledge_conflicts, public.research_jobs, public.research_findings,
  public.content_drafts, public.knowledge_versions, public.research_sources,
  public.research_worker_config from anon, authenticated;

grant select on table public.source_documents, public.source_snapshots,
  public.knowledge_items, public.knowledge_claims, public.knowledge_citations
to anon, authenticated;
grant select, insert, update, delete on table public.source_documents,
  public.source_snapshots, public.knowledge_items, public.knowledge_claims,
  public.knowledge_citations, public.knowledge_conflicts, public.research_jobs,
  public.research_findings, public.content_drafts, public.knowledge_versions,
  public.research_sources to authenticated;
grant all privileges on table public.source_documents, public.source_snapshots,
  public.knowledge_items, public.knowledge_claims, public.knowledge_citations,
  public.knowledge_conflicts, public.research_jobs, public.research_findings,
  public.content_drafts, public.knowledge_versions, public.research_sources,
  public.research_worker_config to service_role;

create policy "approved knowledge public read" on public.knowledge_items
  for select to anon, authenticated
  using (review_status = 'approved' or (select private.has_role(array['admin','super_admin'])));
create policy "approved claims public read" on public.knowledge_claims
  for select to anon, authenticated
  using (exists (select 1 from public.knowledge_items k where k.id = knowledge_item_id
    and (k.review_status = 'approved' or (select private.has_role(array['admin','super_admin'])))));
create policy "approved citations public read" on public.knowledge_citations
  for select to anon, authenticated
  using (exists (select 1 from public.knowledge_claims c join public.knowledge_items k on k.id=c.knowledge_item_id
    where c.id=claim_id and (k.review_status='approved' or (select private.has_role(array['admin','super_admin'])))));
create policy "approved source documents public read" on public.source_documents
  for select to anon, authenticated
  using (exists (select 1 from public.source_snapshots s join public.knowledge_citations kc on kc.snapshot_id=s.id
    join public.knowledge_claims c on c.id=kc.claim_id join public.knowledge_items k on k.id=c.knowledge_item_id
    where s.document_id=source_documents.id and k.review_status='approved')
    or (select private.has_role(array['admin','super_admin'])));
create policy "approved snapshots public read" on public.source_snapshots
  for select to anon, authenticated
  using (exists (select 1 from public.knowledge_citations kc join public.knowledge_claims c on c.id=kc.claim_id
    join public.knowledge_items k on k.id=c.knowledge_item_id
    where kc.snapshot_id=source_snapshots.id and k.review_status='approved')
    or (select private.has_role(array['admin','super_admin'])));

create policy "admins manage sources" on public.source_documents for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage snapshots" on public.source_snapshots for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage knowledge" on public.knowledge_items for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage claims" on public.knowledge_claims for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage citations" on public.knowledge_citations for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage conflicts" on public.knowledge_conflicts for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage research jobs" on public.research_jobs for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage findings" on public.research_findings for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage drafts" on public.content_drafts for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage versions" on public.knowledge_versions for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));
create policy "admins manage research sources" on public.research_sources for all to authenticated
  using ((select private.has_role(array['admin','super_admin'])))
  with check ((select private.has_role(array['admin','super_admin'])));

create or replace function private.enqueue_scheduled_rad_sync()
returns uuid language plpgsql security definer set search_path = '' as $$
declare job_id uuid;
begin
  insert into public.research_jobs(job_type,trigger_type,idempotency_key,input)
  values ('rad_site_sync','scheduled','rad-sync-' || to_char(now() at time zone 'utc','YYYY-MM-DD'),
    jsonb_build_object('scheduled_at',now()))
  on conflict (idempotency_key) do update set input=excluded.input
  returning id into job_id;
  return job_id;
end $$;
alter function private.enqueue_scheduled_rad_sync() owner to postgres;
revoke all on function private.enqueue_scheduled_rad_sync() from public, anon, authenticated;

select cron.schedule('rad-daily-research-enqueue','17 3 * * *',
  $$select private.enqueue_scheduled_rad_sync();$$);

commit;
