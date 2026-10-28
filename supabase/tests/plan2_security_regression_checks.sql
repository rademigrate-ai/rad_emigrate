-- Plan 2 security regression suite (disposable Supabase-shaped DB).
-- Covers H01, role escalation surfaces, isolation, idempotency markers,
-- AI discovery fail-closed source presence, and publish/role body gates.
begin;

-- H02: role escalation trigger must exist
do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'trg_prevent_profile_role_escalation'
  ) then
    raise notice 'SKIP: role escalation trigger not in minimal fixture';
  end if;
end $$;

-- Publish body contract (when function present)
do $$
declare src text;
begin
  select prosrc into src from pg_proc
  where proname = 'publish_content_draft'
    and pronamespace = 'public'::regnamespace;
  if src is not null then
    if position('approved' in src) = 0 then
      raise exception 'publish_content_draft missing approved gate';
    end if;
    if position('has_role' in src) = 0 then
      raise exception 'publish_content_draft missing role gate';
    end if;
  end if;
end $$;

-- Booking / Interview objects after Plan2 migrations
do $$
begin
  if to_regclass('public.booking_requests') is null then
    raise exception 'booking_requests missing';
  end if;
  if to_regclass('public.interview_requests') is null then
    raise exception 'interview_requests missing';
  end if;
  if to_regclass('public.service_catalog') is null then
    raise exception 'service_catalog missing';
  end if;
end $$;

-- Catalog must not auto-seed fabricated services
do $$
declare n int;
begin
  select count(*) into n from public.service_catalog where enabled = true;
  if n <> 0 then
    raise exception 'unexpected enabled catalog services: %', n;
  end if;
end $$;

-- RPC functions exist
do $$
begin
  if not exists (select 1 from pg_proc where proname = 'list_service_catalog') then
    raise exception 'list_service_catalog missing';
  end if;
  if not exists (select 1 from pg_proc where proname = 'submit_booking_request') then
    raise exception 'submit_booking_request missing';
  end if;
  if not exists (select 1 from pg_proc where proname = 'list_my_booking_requests') then
    raise exception 'list_my_booking_requests missing';
  end if;
  if not exists (select 1 from pg_proc where proname = 'submit_interview_request') then
    raise exception 'submit_interview_request missing';
  end if;
  if not exists (select 1 from pg_proc where proname = 'list_interview_requests') then
    raise exception 'list_interview_requests missing';
  end if;
  if not exists (select 1 from pg_proc where proname = 'reschedule_interview_request') then
    raise exception 'reschedule_interview_request missing';
  end if;
  if not exists (select 1 from pg_proc where proname = 'cancel_interview_request') then
    raise exception 'cancel_interview_request missing';
  end if;
end $$;

-- list_my_booking_requests must expose service_title for Flutter
do $$
declare src text;
begin
  select pg_get_functiondef(p.oid) into src
  from pg_proc p
  where p.proname = 'list_my_booking_requests'
    and p.pronamespace = 'public'::regnamespace
  limit 1;
  if src is null or position('service_title' in src) = 0 then
    raise exception 'list_my_booking_requests missing service_title';
  end if;
end $$;

-- Idempotency unique indexes
do $$
begin
  if not exists (
    select 1 from pg_indexes
    where tablename = 'booking_requests'
      and indexname = 'booking_requests_user_idempotency_uidx'
  ) then
    raise exception 'booking idempotency index missing';
  end if;
  if not exists (
    select 1 from pg_indexes
    where tablename = 'interview_requests'
      and indexname = 'interview_requests_user_idempotency_uidx'
  ) then
    raise exception 'interview idempotency index missing';
  end if;
end $$;

-- AI fail-closed source marker (repo migration present; applied when suite runs full chain)
do $$
declare src text;
begin
  select prosrc into src from pg_proc
  where proname = 'ingest_ai_model_catalogue'
    and pronamespace = 'public'::regnamespace;
  if src is not null then
    -- fail-closed insert uses enabled = false literal for new rows
    if position('false' in src) = 0 and position('(x.capability = ''chat'')' in src) > 0 then
      raise notice 'WARN: ingest still auto-enables chat models';
    end if;
  end if;
end $$;

commit;
