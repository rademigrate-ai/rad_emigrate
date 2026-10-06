-- Additive AI dynamic routing architecture.
-- Extends model catalogue with capability provenance, health signals,
-- ranking inputs, and request-level sanitized routing telemetry.
-- Does NOT hardcode a single model; orchestrator selects from eligible pool.
begin;

-- Capability provenance: never invent from model name alone.
alter table public.ai_models
  add column if not exists supports_tools boolean not null default false,
  add column if not exists supports_structured_output boolean not null default false,
  add column if not exists capability_source text not null default 'unknown'
    check (capability_source in ('discovered','measured','configured','inferred','unknown')),
  add column if not exists quality_tier integer not null default 100
    check (quality_tier between 0 and 10000),
  add column if not exists measured_latency_ms integer
    check (measured_latency_ms is null or measured_latency_ms >= 0),
  add column if not exists recent_success_rate numeric(5,4)
    check (recent_success_rate is null or (recent_success_rate >= 0 and recent_success_rate <= 1)),
  add column if not exists consecutive_failures integer not null default 0
    check (consecutive_failures >= 0),
  add column if not exists cooldown_until timestamptz,
  add column if not exists last_success_at timestamptz,
  add column if not exists last_failure_at timestamptz,
  add column if not exists last_error_code text,
  add column if not exists discovery_status text not null default 'active'
    check (discovery_status in ('active','stale','unavailable','disabled'));

-- Routing telemetry on ai_requests (sanitized; no secrets).
alter table public.ai_requests
  add column if not exists routing_reason text,
  add column if not exists failover_occurred boolean not null default false,
  add column if not exists attempt_log jsonb not null default '[]'::jsonb,
  add column if not exists selected_provider_slug text,
  add column if not exists selected_model_slug text;

create index if not exists ai_models_eligible_idx
  on public.ai_models(provider_id, capability, enabled, available, discovery_status, priority, quality_tier)
  where enabled and available and discovery_status = 'active';

create index if not exists ai_models_cooldown_idx
  on public.ai_models(cooldown_until)
  where cooldown_until is not null;

-- Ranked runtime chain: capability fit + health + admin priority + measured signals.
-- Secrets stay server-side only (service_role).
create or replace function public.get_ai_runtime_chain(
  p_capability text,
  p_scope text,
  p_require_tools boolean default false,
  p_require_structured boolean default false,
  p_min_context integer default null
)
returns table(
  provider_id uuid,
  provider_slug text,
  adapter text,
  base_url text,
  model_id uuid,
  model_slug text,
  max_output_tokens integer,
  request_timeout_seconds integer,
  max_retries integer,
  api_key text,
  routing_score integer,
  capability_source text
)
language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'forbidden' using errcode='42501';
  end if;
  if p_scope not in ('user','admin') then
    raise exception 'invalid scope' using errcode='22023';
  end if;

  return query
  select
    p.id,
    p.slug,
    p.adapter,
    p.base_url,
    m.id,
    m.slug,
    m.max_output_tokens,
    p.request_timeout_seconds,
    p.max_retries,
    v.decrypted_secret,
    (
      -- Lower is better. Deterministic, explainable ranking.
      (p.priority * 1000)
      + (m.priority * 10)
      + m.quality_tier
      + case when coalesce(h.status,'unknown') = 'healthy' then 0
             when coalesce(h.status,'unknown') = 'degraded' then 50
             when coalesce(h.status,'unknown') = 'unknown' then 20
             else 200 end
      + case when m.cooldown_until is not null and m.cooldown_until > now() then 10000 else 0 end
      + coalesce(m.consecutive_failures, 0) * 15
      + case when m.measured_latency_ms is null then 5
             when m.measured_latency_ms < 1500 then 0
             when m.measured_latency_ms < 4000 then 10
             else 30 end
      + case when m.recent_success_rate is null then 5
             when m.recent_success_rate >= 0.95 then 0
             when m.recent_success_rate >= 0.8 then 10
             else 40 end
    )::integer as routing_score,
    m.capability_source
  from public.ai_providers p
  join public.ai_models m
    on m.provider_id = p.id
   and m.capability = p_capability
   and m.enabled
   and m.available
   and m.discovery_status in ('active','stale')
  join vault.decrypted_secrets v on v.id = p.secret_id
  left join public.ai_provider_health h on h.provider_id = p.id
  where p.enabled
    and coalesce(p.runtime_scope, 'both') in (p_scope, 'both')
    and coalesce(m.runtime_scope, 'both') in (p_scope, 'both')
    and coalesce(h.status, 'unknown') not in ('offline', 'cooldown')
    and (h.cooldown_until is null or h.cooldown_until <= now())
    and (m.cooldown_until is null or m.cooldown_until <= now())
    and (not p_require_tools or m.supports_tools = true)
    and (not p_require_structured or m.supports_structured_output = true)
    and (p_min_context is null or coalesce(m.context_window, 0) >= p_min_context)
  order by
    routing_score asc,
    p.priority asc,
    m.priority asc,
    m.slug asc,
    p.id asc,
    m.id asc
  limit 8;
end $$;

alter function public.get_ai_runtime_chain(text, text, boolean, boolean, integer) owner to postgres;
revoke all on function public.get_ai_runtime_chain(text, text, boolean, boolean, integer)
  from public, anon, authenticated;
grant execute on function public.get_ai_runtime_chain(text, text, boolean, boolean, integer)
  to service_role;

-- Keep prior 2-arg overload for backward compatibility (maps to new defaults).
create or replace function public.get_ai_runtime_chain(p_capability text, p_scope text)
returns table(
  provider_id uuid,
  provider_slug text,
  adapter text,
  base_url text,
  model_id uuid,
  model_slug text,
  max_output_tokens integer,
  request_timeout_seconds integer,
  max_retries integer,
  api_key text
)
language sql security definer set search_path='' as $$
  select provider_id, provider_slug, adapter, base_url, model_id, model_slug,
         max_output_tokens, request_timeout_seconds, max_retries, api_key
  from public.get_ai_runtime_chain(p_capability, p_scope, false, false, null);
$$;
alter function public.get_ai_runtime_chain(text, text) owner to postgres;
revoke all on function public.get_ai_runtime_chain(text, text) from public, anon, authenticated;
grant execute on function public.get_ai_runtime_chain(text, text) to service_role;

-- Model-level health update (circuit breaker / cooldown).
create or replace function public.record_ai_model_outcome(
  p_model_id uuid,
  p_success boolean,
  p_latency_ms integer default null,
  p_error_code text default null
) returns void language plpgsql security definer set search_path='' as $$
declare
  v_failures integer;
  v_now timestamptz := now();
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'forbidden' using errcode='42501';
  end if;

  if p_success then
    update public.ai_models set
      consecutive_failures = 0,
      cooldown_until = null,
      last_success_at = v_now,
      last_error_code = null,
      measured_latency_ms = coalesce(p_latency_ms, measured_latency_ms),
      recent_success_rate = least(1.0, coalesce(recent_success_rate, 0.9) * 0.85 + 0.15)
    where id = p_model_id;
  else
    select consecutive_failures into v_failures from public.ai_models where id = p_model_id;
    v_failures := least(coalesce(v_failures, 0) + 1, 1000);
    update public.ai_models set
      consecutive_failures = v_failures,
      last_failure_at = v_now,
      last_error_code = p_error_code,
      recent_success_rate = greatest(0.0, coalesce(recent_success_rate, 0.9) * 0.85),
      cooldown_until = case
        when p_error_code in ('provider_rate_limited','provider_unauthorized') then v_now + interval '5 minutes'
        when v_failures >= 3 then v_now + interval '3 minutes'
        else cooldown_until
      end,
      -- Permanent-ish auth failure on this model path: mark discovery unavailable until rediscovery
      discovery_status = case
        when p_error_code = 'provider_unauthorized' then 'unavailable'
        else discovery_status
      end
    where id = p_model_id;
  end if;
end $$;
alter function public.record_ai_model_outcome(uuid, boolean, integer, text) owner to postgres;
revoke all on function public.record_ai_model_outcome(uuid, boolean, integer, text)
  from public, anon, authenticated;
grant execute on function public.record_ai_model_outcome(uuid, boolean, integer, text)
  to service_role;

-- Expand eligible chat pool: enable a small diverse set of discovered chat models
-- so failover is real (not a single static model). Admin priority still wins.
-- Prefer known OpenRouter chat-capable ids when present; do not invent capabilities.
update public.ai_models m
set
  enabled = true,
  runtime_scope = coalesce(m.runtime_scope, 'both'),
  priority = case
    when m.slug = 'openai/gpt-4o-mini' then 10
    when m.slug like 'openai/gpt-4o%' then 20
    when m.slug like 'anthropic/claude-3.5%' then 25
    when m.slug like 'google/gemini-flash%' then 30
    when m.slug like 'meta-llama/%' then 40
    else least(coalesce(m.priority, 100), 80)
  end,
  capability_source = case
    when m.capability_source = 'unknown' then 'configured'
    else m.capability_source
  end,
  discovery_status = 'active'
where m.capability = 'chat'
  and m.available = true
  and m.slug in (
    'openai/gpt-4o-mini',
    'openai/gpt-4o',
    'openai/gpt-4o-2024-11-20',
    'anthropic/claude-3.5-sonnet',
    'anthropic/claude-3-haiku',
    'google/gemini-flash-1.5',
    'google/gemini-2.0-flash-001',
    'meta-llama/llama-3.1-8b-instruct',
    'meta-llama/llama-3.3-70b-instruct'
  );

-- Any remaining already-enabled models keep their settings.
update public.ai_models
set discovery_status = 'active'
where enabled and available and discovery_status = 'active';

commit;
