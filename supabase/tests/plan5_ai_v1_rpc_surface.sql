-- Plan 5: V1 copilot RPC surface must exist after migrations (CI clean-schema).
begin;

do $plan5$
begin
  if to_regprocedure('public.reserve_rad_ai_request(uuid, uuid, text, integer, uuid)') is null then
    raise exception 'missing reserve_rad_ai_request â€” Flutter contract v1 requires it';
  end if;
  if to_regprocedure('public.settle_rad_ai_request(uuid, integer, jsonb, integer)') is null then
    raise exception 'missing settle_rad_ai_request â€” Flutter contract v1 requires it';
  end if;
  if not exists (select 1 from pg_proc where pronamespace = 'public'::regnamespace and proname = 'get_ai_runtime_chain_versioned') then
    raise exception 'missing get_ai_runtime_chain_versioned';
  end if;
end
$plan5$;

-- Knowledge path must not be satisfied by content_drafts alone
do $plan5$
declare
  src text;
begin
  select prosrc into src from pg_proc
  where proname = 'retrieve_verified_official_claims'
    and pronamespace = 'public'::regnamespace
  limit 1;
  if src is null then
    raise notice 'SKIP: retrieve_verified_official_claims absent in this schema';
    return;
  end if;
  if position('content_drafts' in src) > 0 and position('status' in src) = 0 then
    raise exception 'retrieve_verified_official_claims references content_drafts without status guard';
  end if;
end
$plan5$;

commit;