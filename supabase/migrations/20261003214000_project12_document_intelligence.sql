-- Project 12: versioned document-intelligence pipeline with human review.
begin;

create table public.document_processor_config (
  singleton boolean primary key default true check (singleton),
  provider_slug text,
  endpoint_url text check (endpoint_url is null or endpoint_url like 'https://%'),
  secret_id uuid,
  enabled boolean not null default false,
  max_file_bytes integer not null default 10485760 check (max_file_bytes between 1024 and 20971520),
  timeout_ms integer not null default 30000 check (timeout_ms between 1000 and 60000),
  updated_at timestamptz not null default now()
);
insert into public.document_processor_config(singleton) values(true);

create table public.document_processing_jobs (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'queued' check (status in ('queued','running','succeeded','failed','cancelled','review_required')),
  source_version integer not null default 1 check (source_version > 0),
  attempt_count integer not null default 0 check (attempt_count between 0 and 5),
  safe_error_code text,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz
);

create table public.document_extractions (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references public.document_processing_jobs(id) on delete cascade,
  document_id uuid not null references public.documents(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  engine text not null,
  engine_version text,
  extracted_text text,
  language_code text,
  overall_confidence numeric(5,4) check (overall_confidence between 0 and 1),
  page_count integer check (page_count is null or page_count > 0),
  created_at timestamptz not null default now()
);

create table public.document_fields (
  id uuid primary key default gen_random_uuid(),
  extraction_id uuid not null references public.document_extractions(id) on delete cascade,
  field_key text not null,
  field_value text,
  confidence numeric(5,4) check (confidence between 0 and 1),
  page_number integer check (page_number is null or page_number > 0),
  bounding_box jsonb,
  review_status text not null default 'unreviewed' check (review_status in ('unreviewed','accepted','corrected','rejected')),
  corrected_value text,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  unique(extraction_id,field_key,page_number)
);

create table public.document_reviews (
  id uuid primary key default gen_random_uuid(),
  extraction_id uuid not null references public.document_extractions(id) on delete cascade,
  reviewer_id uuid not null references auth.users(id) on delete cascade,
  decision text not null check (decision in ('approved','changes_requested','rejected')),
  safe_notes text check (char_length(safe_notes) <= 2000),
  created_at timestamptz not null default now()
);

create index document_jobs_user_created_idx on public.document_processing_jobs(user_id,created_at desc);
create index document_jobs_document_idx on public.document_processing_jobs(document_id,created_at desc);
create index document_extractions_user_idx on public.document_extractions(user_id,created_at desc);
create index document_extractions_document_idx on public.document_extractions(document_id);
create index document_fields_extraction_review_idx on public.document_fields(extraction_id,review_status);
create index document_fields_reviewer_idx on public.document_fields(reviewed_by);
create index document_reviews_extraction_idx on public.document_reviews(extraction_id,created_at desc);
create index document_reviews_reviewer_idx on public.document_reviews(reviewer_id);

alter table public.document_processor_config enable row level security;
alter table public.document_processing_jobs enable row level security;
alter table public.document_extractions enable row level security;
alter table public.document_fields enable row level security;
alter table public.document_reviews enable row level security;

revoke all on table public.document_processor_config,public.document_processing_jobs,
 public.document_extractions,public.document_fields,public.document_reviews from anon,authenticated;
grant select on table public.document_processing_jobs,public.document_extractions,public.document_fields,public.document_reviews to authenticated;
grant insert on table public.document_processing_jobs to authenticated;
grant update on table public.document_fields to authenticated;
grant insert on table public.document_reviews to authenticated;
grant all privileges on table public.document_processor_config,public.document_processing_jobs,
 public.document_extractions,public.document_fields,public.document_reviews to service_role;

create policy "processor config service only" on public.document_processor_config for all to anon,authenticated using(false) with check(false);
create policy "users read own document jobs" on public.document_processing_jobs for select to authenticated
 using((select auth.uid())=user_id or (select private.has_role(array['admin','super_admin'])));
create policy "users enqueue owned documents" on public.document_processing_jobs for insert to authenticated
 with check((select auth.uid())=user_id and exists(select 1 from public.documents d where d.id=document_id and d.user_id=(select auth.uid())));
create policy "users read own extractions" on public.document_extractions for select to authenticated
 using((select auth.uid())=user_id or (select private.has_role(array['admin','super_admin'])));
create policy "users read own fields" on public.document_fields for select to authenticated
 using(exists(select 1 from public.document_extractions e where e.id=extraction_id and
   (e.user_id=(select auth.uid()) or (select private.has_role(array['admin','super_admin'])))));
create policy "users review own fields" on public.document_fields for update to authenticated
 using(exists(select 1 from public.document_extractions e where e.id=extraction_id and
   (e.user_id=(select auth.uid()) or (select private.has_role(array['admin','super_admin'])))))
 with check(exists(select 1 from public.document_extractions e where e.id=extraction_id and
   (e.user_id=(select auth.uid()) or (select private.has_role(array['admin','super_admin'])))));
create policy "users read own reviews" on public.document_reviews for select to authenticated
 using(exists(select 1 from public.document_extractions e where e.id=extraction_id and
   (e.user_id=(select auth.uid()) or (select private.has_role(array['admin','super_admin'])))));
create policy "users add own reviews" on public.document_reviews for insert to authenticated
 with check(reviewer_id=(select auth.uid()) and exists(select 1 from public.document_extractions e where e.id=extraction_id and
   (e.user_id=(select auth.uid()) or (select private.has_role(array['admin','super_admin'])))));

create policy "service writes document jobs" on public.document_processing_jobs for all to service_role using(true) with check(true);
create policy "service writes extractions" on public.document_extractions for all to service_role using(true) with check(true);
create policy "service writes fields" on public.document_fields for all to service_role using(true) with check(true);
create policy "service writes reviews" on public.document_reviews for all to service_role using(true) with check(true);
create policy "service writes processor config" on public.document_processor_config for all to service_role using(true) with check(true);

create or replace function public.get_document_processor_runtime()
returns table(provider_slug text,endpoint_url text,api_key text,max_file_bytes integer,timeout_ms integer)
language plpgsql security definer set search_path='' as $$
begin
 if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
 return query select c.provider_slug,c.endpoint_url,v.decrypted_secret,c.max_file_bytes,c.timeout_ms
 from public.document_processor_config c join vault.decrypted_secrets v on v.id=c.secret_id
 where c.singleton and c.enabled;
end $$;
alter function public.get_document_processor_runtime() owner to postgres;
revoke all on function public.get_document_processor_runtime() from public,anon,authenticated;
grant execute on function public.get_document_processor_runtime() to service_role;

commit;
