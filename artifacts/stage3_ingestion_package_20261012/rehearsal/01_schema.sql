-- Local rehearsal schema: faithful subset of production DDL for the tables the
-- Stage 3 bulk ingestion touches (from project09/project10 migrations + the
-- last_content_hash column added by 20261007080002). auth.users FKs are
-- omitted locally (auth schema does not exist outside Supabase) — they do not
-- affect ingestion semantics.

create schema if not exists public;

create table public.content_sources (
  id uuid primary key default gen_random_uuid(),
  publisher text not null,
  source_type text not null check (
    source_type in ('rad_official', 'government', 'embassy', 'institution', 'other')),
  title text not null,
  url text not null unique,
  language_code text not null default 'fa' check (language_code in ('fa', 'en')),
  published_at timestamptz,
  retrieved_at timestamptz not null default now(),
  content_hash text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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
  removed_at timestamptz,
  last_content_hash text
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
  created_by uuid,
  reviewed_by uuid,
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

-- Feed tables (project14 DDL, auth.users FKs omitted). The rehearsal adds a
-- STRICT local stand-in for the Stage 1 guard trigger: production's trigger
-- permits only the human-authorized publish RPC; locally ANY feed mutation
-- raises, so an accidental Feed write by the ingestion package fails loudly
-- instead of silently committing.
create table public.feed_items (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  category text not null check (category in ('update','guide','deadline','event','success_story','announcement')),
  status text not null default 'draft' check (status in ('draft','review','published','archived')),
  primary_source_id uuid references public.content_sources(id) on delete set null,
  source_url text check (source_url is null or source_url like 'https://%'),
  hero_image_url text check (hero_image_url is null or hero_image_url like 'https://%'),
  effective_date date,
  published_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.feed_item_localizations (
  feed_item_id uuid not null references public.feed_items(id) on delete cascade,
  locale text not null check (locale in ('fa','en')),
  title text not null,
  summary text not null,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (feed_item_id, locale)
);

create or replace function private_rehearsal_guard_feed_mutation()
returns trigger
language plpgsql
as $function$
begin
  raise exception 'rehearsal guard: ingestion must never mutate feed tables'
    using errcode = '42501';
end
$function$;

create trigger trg_rehearsal_guard_feed_item
before insert or update or delete on public.feed_items
for each row execute function private_rehearsal_guard_feed_mutation();

create trigger trg_rehearsal_guard_feed_localization
before insert or update or delete on public.feed_item_localizations
for each row execute function private_rehearsal_guard_feed_mutation();
