-- Additive: optional user immigration profile, checklists, and saved AI reports.
-- Owner-scoped RLS. No Production apply without separate authorization.
-- Does not auto-publish or grant cross-user access.

create table if not exists public.user_ai_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  education text,
  field_of_study text,
  work_experience text,
  language_level text,
  preferred_destinations text[] not null default '{}',
  interested_pathways text[] not null default '{}',
  budget_range text,
  notes text,
  consent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_ai_profiles_notes_len check (notes is null or char_length(notes) <= 4000)
);

alter table public.user_ai_profiles enable row level security;

drop policy if exists "user_ai_profiles_owner" on public.user_ai_profiles;
create policy "user_ai_profiles_owner" on public.user_ai_profiles
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on table public.user_ai_profiles from public, anon;
grant select, insert, update, delete on table public.user_ai_profiles to authenticated;
grant all on table public.user_ai_profiles to service_role;

create table if not exists public.user_ai_checklists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 200),
  items jsonb not null default '[]'::jsonb,
  source_session_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_ai_checklists_items_is_array check (jsonb_typeof(items) = 'array')
);

create index if not exists user_ai_checklists_user_idx
  on public.user_ai_checklists (user_id, updated_at desc);

alter table public.user_ai_checklists enable row level security;

drop policy if exists "user_ai_checklists_owner" on public.user_ai_checklists;
create policy "user_ai_checklists_owner" on public.user_ai_checklists
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on table public.user_ai_checklists from public, anon;
grant select, insert, update, delete on table public.user_ai_checklists to authenticated;
grant all on table public.user_ai_checklists to service_role;

create table if not exists public.user_ai_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 200),
  report_type text not null default 'summary'
    check (report_type in ('summary', 'country_comparison', 'pathway', 'checklist_export', 'other')),
  body_markdown text not null check (char_length(body_markdown) <= 100000),
  source_session_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists user_ai_reports_user_idx
  on public.user_ai_reports (user_id, updated_at desc);

alter table public.user_ai_reports enable row level security;

drop policy if exists "user_ai_reports_owner" on public.user_ai_reports;
create policy "user_ai_reports_owner" on public.user_ai_reports
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on table public.user_ai_reports from public, anon;
grant select, insert, update, delete on table public.user_ai_reports to authenticated;
grant all on table public.user_ai_reports to service_role;

-- Upsert profile helper (owner-only via RLS + auth.uid())
create or replace function public.upsert_user_ai_profile(
  p_education text default null,
  p_field_of_study text default null,
  p_work_experience text default null,
  p_language_level text default null,
  p_preferred_destinations text[] default null,
  p_interested_pathways text[] default null,
  p_budget_range text default null,
  p_notes text default null,
  p_consent boolean default false
) returns public.user_ai_profiles
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_row public.user_ai_profiles;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  insert into public.user_ai_profiles as t (
    user_id, education, field_of_study, work_experience, language_level,
    preferred_destinations, interested_pathways, budget_range, notes, consent_at, updated_at
  ) values (
    auth.uid(),
    nullif(trim(p_education), ''),
    nullif(trim(p_field_of_study), ''),
    nullif(trim(p_work_experience), ''),
    nullif(trim(p_language_level), ''),
    coalesce(p_preferred_destinations, '{}'),
    coalesce(p_interested_pathways, '{}'),
    nullif(trim(p_budget_range), ''),
    nullif(trim(p_notes), ''),
    case when p_consent then now() else null end,
    now()
  )
  on conflict (user_id) do update set
    education = excluded.education,
    field_of_study = excluded.field_of_study,
    work_experience = excluded.work_experience,
    language_level = excluded.language_level,
    preferred_destinations = excluded.preferred_destinations,
    interested_pathways = excluded.interested_pathways,
    budget_range = excluded.budget_range,
    notes = excluded.notes,
    consent_at = coalesce(excluded.consent_at, t.consent_at),
    updated_at = now()
  returning * into v_row;
  return v_row;
end;
$$;

revoke all on function public.upsert_user_ai_profile from public, anon;
grant execute on function public.upsert_user_ai_profile to authenticated;

comment on table public.user_ai_profiles is
  'Optional user-supplied immigration context for AI; owner RLS; not used for auto-eligibility guarantees.';
