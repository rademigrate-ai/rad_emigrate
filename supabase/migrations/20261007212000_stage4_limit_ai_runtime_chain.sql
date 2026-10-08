-- Stage 4: limit ranked runtime chain to top 8 models (prevent oversized secret-bearing payloads)
CREATE OR REPLACE FUNCTION public.get_ai_runtime_chain(
  p_capability text,
  p_scope text,
  p_require_tools boolean DEFAULT false,
  p_require_structured boolean DEFAULT false,
  p_min_context integer DEFAULT NULL::integer
)
RETURNS TABLE(
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
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'forbidden' using errcode='42501';
  end if;
  if p_scope not in ('user','admin') then
    raise exception 'invalid scope' using errcode='22023';
  end if;

  return query
  select * from (
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
      (least(p.priority, 1000) / 10)
      + (least(m.priority, 10000) / 10)
      + m.quality_tier
      + case when m.cost_source in ('discovered','configured') then least(coalesce(m.cost_input_per_million,0),20)::integer else 0 end
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
   and m.discovery_status = 'active'
  join vault.decrypted_secrets v on v.id = p.secret_id
  left join public.ai_provider_health h on h.provider_id = p.id
  where p.enabled
    and coalesce(p.runtime_scope, 'both') in (p_scope, 'both')
    and coalesce(m.runtime_scope, 'both') in (p_scope, 'both')
    and not coalesce(h.credential_rejected, false)
    and (coalesce(h.status, 'unknown') not in ('offline','cooldown')
         or (h.cooldown_until is not null and h.cooldown_until <= now()))
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
  limit 8
  ) ranked;
end
$function$;
