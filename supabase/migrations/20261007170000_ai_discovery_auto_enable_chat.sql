-- AI high-availability: discovered chat models become eligible by default.
-- Admin can still disable individual models via set_ai_model_configuration.
-- Does not touch credential-rejected providers; routing still excludes them.

CREATE OR REPLACE FUNCTION public.ingest_ai_model_catalogue(
  p_provider_id uuid,
  p_credential_version bigint,
  p_models jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  v_version bigint;
  v_old integer;
  v_added integer;
  v_removed integer;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'forbidden' using errcode='42501';
  end if;
  select credential_version into v_version
  from public.ai_providers where id = p_provider_id for update;
  if v_version is distinct from p_credential_version then
    raise exception 'configuration changed' using errcode='40001';
  end if;
  if jsonb_typeof(p_models) <> 'array' or jsonb_array_length(p_models) > 5000 then
    raise exception 'invalid catalogue' using errcode='22023';
  end if;

  select count(*) into v_old from public.ai_models where provider_id = p_provider_id;

  -- New chat models are enabled by default so discovery produces a non-empty
  -- runtime pool without requiring Admin to hand-enable every slug.
  -- Non-chat (e.g. embedding) stays disabled until explicitly enabled.
  insert into public.ai_models(
    provider_id, slug, display_name, capability, enabled, available, runtime_scope, priority,
    discovered_at, last_seen_at, discovery_status, context_window,
    supports_tools, supports_structured_output, capability_source,
    cost_input_per_million, cost_source
  )
  select
    p_provider_id,
    x.slug,
    x.slug,
    x.capability,
    (x.capability = 'chat'),
    true,
    'both',
    100,
    now(),
    now(),
    'active',
    x.context_window,
    x.supports_tools,
    x.supports_structured_output,
    x.capability_source,
    x.cost_input_per_million,
    x.cost_source
  from jsonb_to_recordset(p_models) as x(
    slug text,
    capability text,
    context_window integer,
    supports_tools boolean,
    supports_structured_output boolean,
    capability_source text,
    cost_input_per_million numeric,
    cost_source text
  )
  on conflict (provider_id, slug) do update set
    available = true,
    last_seen_at = now(),
    discovery_status = 'active',
    -- Preserve Admin-disabled state: only auto-enable when still at default disabled
    -- and capability is chat. Never force-enable a model Admin turned off.
    enabled = case
      when ai_models.enabled = false
        and ai_models.capability = 'chat'
        and excluded.capability = 'chat'
        and ai_models.discovery_status in ('active', 'stale')
        and ai_models.last_success_at is null
        and coalesce(ai_models.consecutive_failures, 0) = 0
        and ai_models.priority = 100
      then true
      else ai_models.enabled
    end,
    context_window = case
      when ai_models.capability_source = 'configured' then ai_models.context_window
      else excluded.context_window
    end,
    supports_tools = case
      when ai_models.capability_source = 'configured' then ai_models.supports_tools
      else excluded.supports_tools
    end,
    supports_structured_output = case
      when ai_models.capability_source = 'configured' then ai_models.supports_structured_output
      else excluded.supports_structured_output
    end,
    capability_source = case
      when ai_models.capability_source = 'configured' then 'configured'
      else excluded.capability_source
    end,
    cost_input_per_million = case
      when ai_models.cost_source = 'configured' then ai_models.cost_input_per_million
      else excluded.cost_input_per_million
    end,
    cost_source = case
      when ai_models.cost_source = 'configured' then 'configured'
      else excluded.cost_source
    end;

  select count(*) - v_old into v_added from public.ai_models where provider_id = p_provider_id;

  update public.ai_models m
  set available = false, discovery_status = 'stale'
  where provider_id = p_provider_id
    and not exists (
      select 1 from jsonb_array_elements(p_models) x where x->>'slug' = m.slug
    );
  get diagnostics v_removed = row_count;

  return jsonb_build_object(
    'discovered', jsonb_array_length(p_models),
    'added', v_added,
    'removed', v_removed
  );
end;
$function$;

-- One-time backfill: enable available active chat models that were never used
-- and never explicitly prioritized (priority still default 100).
-- Does not override Admin-tuned priorities or models with failure history.
UPDATE public.ai_models m
SET enabled = true
WHERE m.capability = 'chat'
  AND m.available = true
  AND m.discovery_status = 'active'
  AND m.enabled = false
  AND m.priority = 100
  AND m.last_success_at IS NULL
  AND coalesce(m.consecutive_failures, 0) = 0;
