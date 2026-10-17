-- F-04: reserve an authenticated AI request inside the same transaction that
-- checks the daily quota.  The earlier implementation only counted existing
-- rows, so concurrent callers could all observe the same available slot before
-- the Edge Function inserted any request row.
create or replace function public.consume_ai_daily_quota(
  p_user_id uuid,
  p_role text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_role text;
  v_limit integer;
  v_token_limit integer;
  v_used integer;
  v_tokens integer;
  v_request_id uuid;
  v_day timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
begin
  if p_user_id is null then
    raise exception 'user_required' using errcode = '22023';
  end if;

  -- The database role is authoritative.  Keep p_role only for backwards RPC
  -- compatibility; a trusted caller cannot accidentally grant a larger quota.
  select coalesce(p.role, 'user')
  into v_role
  from public.profiles p
  where p.id = p_user_id;
  v_role := coalesce(v_role, 'user');

  select l.daily_requests, l.daily_output_tokens
  into v_limit, v_token_limit
  from public.ai_usage_limits l
  where l.role = v_role
  limit 1;
  if v_limit is null then
    v_limit := 50;
    v_token_limit := 100000;
  end if;

  -- Serialize reservations per user and UTC day.  Because both the count and
  -- insert happen before this transaction releases the lock, the next caller
  -- observes the newly reserved row.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text || ':' || v_day::text, 0)
  );

  select count(*)::integer, coalesce(sum(r.output_tokens), 0)::integer
  into v_used, v_tokens
  from public.ai_requests r
  where r.user_id = p_user_id and r.created_at >= v_day;

  if v_used >= v_limit or v_tokens >= v_token_limit then
    return jsonb_build_object(
      'allowed', false,
      'count', v_used,
      'limit', v_limit,
      'tokens_used', v_tokens,
      'token_limit', v_token_limit,
      'error', 'daily_limit_reached'
    );
  end if;

  insert into public.ai_requests(
    user_id,
    capability,
    status,
    routing_reason
  ) values (
    p_user_id,
    'chat',
    'running',
    'atomic_quota_reservation'
  )
  returning id into v_request_id;

  return jsonb_build_object(
    'allowed', true,
    'count', v_used + 1,
    'limit', v_limit,
    'tokens_used', v_tokens,
    'token_limit', v_token_limit,
    'request_id', v_request_id
  );
end
$function$;

alter function public.consume_ai_daily_quota(uuid,text) owner to postgres;
revoke all on function public.consume_ai_daily_quota(uuid,text)
  from public, anon, authenticated;
grant execute on function public.consume_ai_daily_quota(uuid,text)
  to service_role;
