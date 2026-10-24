-- Plan 2 additive: booking request infrastructure + catalog (no fabricated services).
-- Flutter contracts: list_service_catalog, submit_booking_request, list_my_booking_requests.
-- Prices, slots, and automatic confirmation are intentionally absent.
begin;

create table if not exists public.service_catalog (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  category text not null check (category in ('consultation','documentReview','applicationSupport','interviewPreparation','other')),
  fulfillment text not null check (fulfillment in ('humanConsultation','staffScheduled')),
  duration_minutes integer null check (duration_minutes is null or duration_minutes > 0),
  enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.service_catalog_localizations (
  service_id uuid not null references public.service_catalog(id) on delete cascade,
  locale text not null check (locale in ('en','fa')),
  title text not null,
  description text not null default '',
  primary key (service_id, locale)
);

create table if not exists public.booking_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  service_id uuid not null references public.service_catalog(id),
  message text not null check (char_length(btrim(message)) between 1 and 4000),
  status text not null default 'submitted'
    check (status in ('submitted','inReview','confirmed','rescheduled','cancelled','completed')),
  preferred_start_utc timestamptz null,
  preferred_end_utc timestamptz null,
  time_zone text null,
  idempotency_key text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint booking_pref_order check (
    preferred_end_utc is null or preferred_start_utc is null
    or preferred_end_utc > preferred_start_utc
  )
);

create unique index if not exists booking_requests_user_idempotency_uidx
  on public.booking_requests (user_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists booking_requests_user_created_idx
  on public.booking_requests (user_id, created_at desc);

alter table public.service_catalog enable row level security;
alter table public.service_catalog_localizations enable row level security;
alter table public.booking_requests enable row level security;

-- Catalog: public read of enabled rows only
drop policy if exists service_catalog_select_enabled on public.service_catalog;
create policy service_catalog_select_enabled on public.service_catalog
  for select to anon, authenticated
  using (enabled = true);

drop policy if exists service_catalog_loc_select on public.service_catalog_localizations;
create policy service_catalog_loc_select on public.service_catalog_localizations
  for select to anon, authenticated
  using (exists (
    select 1 from public.service_catalog s
    where s.id = service_id and s.enabled = true
  ));

-- Booking requests: owner read only; writes via SECURITY DEFINER RPCs
drop policy if exists booking_requests_select_own on public.booking_requests;
create policy booking_requests_select_own on public.booking_requests
  for select to authenticated
  using (user_id = auth.uid());

revoke all on table public.service_catalog from public, anon, authenticated;
revoke all on table public.service_catalog_localizations from public, anon, authenticated;
revoke all on table public.booking_requests from public, anon, authenticated;
grant select on table public.service_catalog to anon, authenticated;
grant select on table public.service_catalog_localizations to anon, authenticated;
grant select on table public.booking_requests to authenticated;
grant all on table public.service_catalog to service_role;
grant all on table public.service_catalog_localizations to service_role;
grant all on table public.booking_requests to service_role;

create or replace function public.list_service_catalog(p_locale text default 'en')
returns table (
  id uuid,
  slug text,
  title text,
  description text,
  category text,
  fulfillment text,
  duration_minutes integer
)
language sql
stable
security definer
set search_path = public
as $$
  select s.id, s.slug,
    coalesce(l.title, s.slug) as title,
    coalesce(l.description, '') as description,
    s.category, s.fulfillment, s.duration_minutes
  from public.service_catalog s
  left join public.service_catalog_localizations l
    on l.service_id = s.id and l.locale = case when p_locale = 'fa' then 'fa' else 'en' end
  where s.enabled = true
  order by s.slug;
$$;

create or replace function public.submit_booking_request(
  p_service_id uuid,
  p_message text,
  p_preferred_start_utc timestamptz default null,
  p_preferred_end_utc timestamptz default null,
  p_time_zone text default null,
  p_idempotency_key text default null
)
returns setof public.booking_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_svc public.service_catalog%rowtype;
  v_existing public.booking_requests%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_message is null or char_length(btrim(p_message)) < 1 then
    raise exception 'message required' using errcode = '22023';
  end if;

  select * into v_svc from public.service_catalog where id = p_service_id and enabled = true;
  if not found then
    raise exception 'service unavailable' using errcode = 'P0002';
  end if;

  if p_idempotency_key is not null and length(btrim(p_idempotency_key)) > 0 then
    select * into v_existing
    from public.booking_requests
    where user_id = v_uid and idempotency_key = btrim(p_idempotency_key);
    if found then
      return next v_existing;
      return;
    end if;
  end if;

  return query
  insert into public.booking_requests (
    user_id, service_id, message, status,
    preferred_start_utc, preferred_end_utc, time_zone, idempotency_key
  ) values (
    v_uid, p_service_id, left(btrim(p_message), 4000), 'submitted',
    p_preferred_start_utc, p_preferred_end_utc,
    nullif(btrim(coalesce(p_time_zone,'')), ''),
    nullif(btrim(coalesce(p_idempotency_key,'')), '')
  )
  returning *;
end;
$$;

create or replace function public.list_my_booking_requests()
returns setof public.booking_requests
language sql
stable
security definer
set search_path = public
as $$
  select * from public.booking_requests
  where user_id = auth.uid()
  order by created_at desc;
$$;

revoke all on function public.list_service_catalog(text) from public, anon, authenticated;
grant execute on function public.list_service_catalog(text) to anon, authenticated;

revoke all on function public.submit_booking_request(uuid, text, timestamptz, timestamptz, text, text) from public, anon;
grant execute on function public.submit_booking_request(uuid, text, timestamptz, timestamptz, text, text) to authenticated;

revoke all on function public.list_my_booking_requests() from public, anon;
grant execute on function public.list_my_booking_requests() to authenticated;

-- No seed rows: catalog stays empty until Admin enables real RAD services.
-- Built-in consultation path remains via submit_consultation_request.

commit;
