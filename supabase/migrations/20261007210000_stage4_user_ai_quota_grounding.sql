-- Stage 4: atomic AI quota consumption + anonymous guest quota (5 questions)
create table if not exists public.ai_guest_quota (
  guest_key_hash text primary key,
  question_count integer not null default 0 check (question_count >= 0),
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
alter table public.ai_guest_quota enable row level security;
revoke all on table public.ai_guest_quota from public, anon, authenticated;
grant all on table public.ai_guest_quota to service_role;

create or replace function public.consume_ai_guest_quota(p_guest_key_hash text, p_limit integer default 5)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_count integer;
begin
  if p_guest_key_hash is null or length(p_guest_key_hash) < 16 or length(p_guest_key_hash) > 128 then
    raise exception 'invalid_guest_key' using errcode = '22023';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 20 then p_limit := 5; end if;
  insert into public.ai_guest_quota (guest_key_hash, question_count)
  values (p_guest_key_hash, 1)
  on conflict (guest_key_hash) do update
    set question_count = public.ai_guest_quota.question_count + 1, last_seen_at = now()
    where public.ai_guest_quota.question_count < p_limit
  returning question_count into v_count;
  if v_count is null then
    select question_count into v_count from public.ai_guest_quota where guest_key_hash = p_guest_key_hash;
    return jsonb_build_object('allowed', false, 'count', coalesce(v_count, p_limit), 'limit', p_limit, 'error', 'anonymous_quota_exceeded');
  end if;
  return jsonb_build_object('allowed', true, 'count', v_count, 'limit', p_limit);
end; $$;
revoke all on function public.consume_ai_guest_quota(text, integer) from public, anon, authenticated;
grant execute on function public.consume_ai_guest_quota(text, integer) to service_role;

create or replace function public.consume_ai_daily_quota(p_user_id uuid, p_role text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_limit integer; v_token_limit integer; v_used integer; v_tokens integer;
  v_day timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
begin
  if p_user_id is null then raise exception 'user_required' using errcode = '22023'; end if;
  select daily_requests, daily_output_tokens into v_limit, v_token_limit from public.ai_usage_limits where role = coalesce(nullif(p_role, ''), 'user') limit 1;
  if v_limit is null then v_limit := 50; v_token_limit := 100000; end if;
  select count(*)::int, coalesce(sum(output_tokens), 0)::int into v_used, v_tokens from public.ai_requests where user_id = p_user_id and created_at >= v_day;
  if v_used >= v_limit or v_tokens >= v_token_limit then
    return jsonb_build_object('allowed', false, 'count', v_used, 'limit', v_limit, 'tokens_used', v_tokens, 'token_limit', v_token_limit, 'error', 'daily_limit_reached');
  end if;
  return jsonb_build_object('allowed', true, 'count', v_used, 'limit', v_limit, 'tokens_used', v_tokens, 'token_limit', v_token_limit);
end; $$;
revoke all on function public.consume_ai_daily_quota(uuid, text) from public, anon, authenticated;
grant execute on function public.consume_ai_daily_quota(uuid, text) to service_role;
