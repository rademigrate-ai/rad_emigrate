-- Matched legacy/v1 quota bridge. Atomic body preserved under a private name.
begin;
create function private.rad_consume_ai_quota_base(
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
REVOKE ALL ON FUNCTION private.rad_consume_ai_quota_base(uuid,text) FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE private.rad_ai_invocations ADD COLUMN IF NOT EXISTS protocol text NOT NULL DEFAULT 'v1' CHECK(protocol IN ('v1','legacy'));
CREATE OR REPLACE FUNCTION public.consume_ai_daily_quota(p_user_id uuid,p_role text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb; key uuid:=gen_random_uuid();
BEGIN
 IF coalesce(auth.jwt()->>'role','')<>'service_role' THEN RAISE EXCEPTION 'forbidden' USING errcode='PT403'; END IF;
 result:=public.reserve_rad_ai_request(p_user_id,key,encode(extensions.digest('legacy:'||key::text,'sha256'),'hex'),6144,null);
 IF result->>'allowed'='true' THEN UPDATE private.rad_ai_invocations SET protocol='legacy' WHERE request_id=(result->>'request_id')::uuid; END IF;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.consume_ai_daily_quota(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.consume_ai_daily_quota(uuid,text) TO service_role;
CREATE FUNCTION private.rad_legacy_quota_terminal() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF new.status IN ('succeeded','failed') THEN
  UPDATE private.rad_ai_invocations SET state=CASE new.status WHEN 'succeeded' THEN 'succeeded' ELSE 'failed' END,
   finished_at=coalesce(new.finished_at,now()),http_status=CASE new.status WHEN 'succeeded' THEN 200 ELSE 503 END
   WHERE request_id=new.id AND protocol='legacy' AND state='running';
  IF new.output_tokens IS NULL AND new.status='failed' THEN
   new.output_tokens:=(SELECT reserved_output_tokens FROM private.rad_ai_invocations WHERE request_id=new.id AND protocol='legacy');
  END IF;
 END IF;
 RETURN new;
END $$;
CREATE TRIGGER rad_legacy_quota_terminal BEFORE UPDATE OF status ON public.ai_requests FOR EACH ROW EXECUTE FUNCTION private.rad_legacy_quota_terminal();
COMMIT;
