-- Plan 2 additive: interview *request* lifecycle (not embassy appointment booking).
-- Does not invent available slots, embassy capacity, or automatic confirmation.
-- RPCs: submit_interview_request, list_interview_requests,
--        reschedule_interview_request, cancel_interview_request.
begin;

create table if not exists public.interview_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  notes text not null default '' check (char_length(notes) <= 4000),
  status text not null default 'submitted'
    check (status in ('submitted','pending_confirmation','confirmed','rescheduled','cancelled','completed')),
  preferred_start_utc timestamptz null,
  preferred_end_utc timestamptz null,
  time_zone text null,
  locale text not null default 'en' check (locale in ('en','fa')),
  idempotency_key text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint interview_pref_order check (
    preferred_end_utc is null or preferred_start_utc is null
    or preferred_end_utc > preferred_start_utc
  )
);

create unique index if not exists interview_requests_user_idempotency_uidx
  on public.interview_requests (user_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists interview_requests_user_created_idx
  on public.interview_requests (user_id, created_at desc);

alter table public.interview_requests enable row level security;

drop policy if exists interview_requests_select_own on public.interview_requests;
create policy interview_requests_select_own on public.interview_requests
  for select to authenticated
  using (user_id = auth.uid());

revoke all on table public.interview_requests from public, anon, authenticated;
grant select on table public.interview_requests to authenticated;
grant all on table public.interview_requests to service_role;

create or replace function public.submit_interview_request(
  p_notes text default '',
  p_preferred_start_utc timestamptz default null,
  p_preferred_end_utc timestamptz default null,
  p_time_zone text default null,
  p_locale text default 'en',
  p_idempotency_key text default null
)
returns setof public.interview_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_existing public.interview_requests%rowtype;
  v_locale text := case when p_locale = 'fa' then 'fa' else 'en' end;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if p_idempotency_key is not null and length(btrim(p_idempotency_key)) > 0 then
    select * into v_existing
    from public.interview_requests
    where user_id = v_uid and idempotency_key = btrim(p_idempotency_key);
    if found then
      return next v_existing;
      return;
    end if;
  end if;

  return query
  insert into public.interview_requests (
    user_id, notes, status, preferred_start_utc, preferred_end_utc,
    time_zone, locale, idempotency_key
  ) values (
    v_uid,
    left(coalesce(p_notes,''), 4000),
    'submitted',
    p_preferred_start_utc,
    p_preferred_end_utc,
    nullif(btrim(coalesce(p_time_zone,'')), ''),
    v_locale,
    nullif(btrim(coalesce(p_idempotency_key,'')), '')
  )
  returning *;
end;
$$;

create or replace function public.list_interview_requests()
returns setof public.interview_requests
language sql
stable
security definer
set search_path = public
as $$
  select * from public.interview_requests
  where user_id = auth.uid()
  order by created_at desc;
$$;

create or replace function public.reschedule_interview_request(
  p_request_id uuid,
  p_preferred_start_utc timestamptz,
  p_preferred_end_utc timestamptz default null,
  p_time_zone text default null
)
returns setof public.interview_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.interview_requests%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_preferred_start_utc is null then
    raise exception 'preferred_start_utc required' using errcode = '22023';
  end if;

  select * into v_row from public.interview_requests
  where id = p_request_id and user_id = v_uid for update;
  if not found then
    raise exception 'request not found' using errcode = 'P0002';
  end if;
  if v_row.status in ('cancelled','completed') then
    raise exception 'request not reschedulable' using errcode = '22023';
  end if;

  return query
  update public.interview_requests set
    preferred_start_utc = p_preferred_start_utc,
    preferred_end_utc = p_preferred_end_utc,
    time_zone = coalesce(nullif(btrim(coalesce(p_time_zone,'')), ''), time_zone),
    status = 'rescheduled',
    updated_at = now()
  where id = p_request_id and user_id = v_uid
  returning *;
end;
$$;

create or replace function public.cancel_interview_request(p_request_id uuid)
returns setof public.interview_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.interview_requests%rowtype;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select * into v_row from public.interview_requests
  where id = p_request_id and user_id = v_uid for update;
  if not found then
    raise exception 'request not found' using errcode = 'P0002';
  end if;
  if v_row.status = 'completed' then
    raise exception 'request not cancellable' using errcode = '22023';
  end if;
  if v_row.status = 'cancelled' then
    return next v_row;
    return;
  end if;

  return query
  update public.interview_requests set
    status = 'cancelled',
    updated_at = now()
  where id = p_request_id and user_id = v_uid
  returning *;
end;
$$;

revoke all on function public.submit_interview_request(text, timestamptz, timestamptz, text, text, text) from public, anon;
grant execute on function public.submit_interview_request(text, timestamptz, timestamptz, text, text, text) to authenticated;

revoke all on function public.list_interview_requests() from public, anon;
grant execute on function public.list_interview_requests() to authenticated;

revoke all on function public.reschedule_interview_request(uuid, timestamptz, timestamptz, text) from public, anon;
grant execute on function public.reschedule_interview_request(uuid, timestamptz, timestamptz, text) to authenticated;

revoke all on function public.cancel_interview_request(uuid) from public, anon;
grant execute on function public.cancel_interview_request(uuid) to authenticated;

commit;
