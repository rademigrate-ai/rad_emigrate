-- Plan 2 regression tests (pgTAP-style assertions runnable in disposable env).
-- These are documentation + executable SQL checks, not applied to Production.
begin;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'trg_prevent_profile_role_escalation'
  ) then
    raise exception 'missing role escalation trigger';
  end if;
end $$;

do $$
declare src text;
begin
  select prosrc into src from pg_proc
  where proname = 'publish_content_draft'
    and pronamespace = 'public'::regnamespace;
  if src is null or position('approved' in src) = 0 then
    raise exception 'publish_content_draft missing approved gate';
  end if;
  if position('has_role' in src) = 0 then
    raise exception 'publish_content_draft missing role gate';
  end if;
end $$;

do $$
begin
  if to_regclass('public.booking_requests') is null then
    raise exception 'booking_requests missing';
  end if;
  if to_regclass('public.interview_requests') is null then
    raise exception 'interview_requests missing';
  end if;
end $$;

commit;
