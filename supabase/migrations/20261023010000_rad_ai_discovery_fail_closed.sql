-- Discovery may refresh availability, but must never grant admin approval.
-- Newly discovered models start disabled; existing enabled/scope/priority settings
-- remain owned by explicit configuration and are not overwritten by discovery.
begin;

create or replace function public.ingest_ai_model_catalogue(
  p_provider_id uuid,
  p_credential_version bigint,
  p_models jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_version bigint;
  v_old integer;
  v_added integer;
  v_removed integer;
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select credential_version
    into v_version
    from public.ai_providers
   where id = p_provider_id
   for update;

  if v_version is distinct from p_credential_version then
    raise exception 'configuration changed' using errcode = '40001';
  end if;

  if jsonb_typeof(p_models) <> 'array'
     or jsonb_array_length(p_models) > 5000 then
    raise exception 'invalid catalogue' using errcode = '22023';
  end if;

  select count(*) into v_old
    from public.ai_models
   where provider_id = p_provider_id;

  insert into public.ai_models(
    provider_id, slug, display_name, capability, enabled, available,
    runtime_scope, priority, discovered_at, last_seen_at, discovery_status,
    context_window, supports_tools, supports_structured_output,
    capability_source, cost_input_per_million, cost_source
  )
  select
    p_provider_id, x.slug, x.slug, x.capability, false, true,
    'both', 100, now(), now(), 'active',
    x.context_window, x.supports_tools, x.supports_structured_output,
    x.capability_source, x.cost_input_per_million, x.cost_source
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

  select count(*) - v_old
    into v_added
    from public.ai_models
   where provider_id = p_provider_id;

  update public.ai_models m
     set available = false,
         discovery_status = 'stale'
   where provider_id = p_provider_id
     and not exists (
       select 1
         from jsonb_array_elements(p_models) x
        where x->>'slug' = m.slug
     );

  get diagnostics v_removed = row_count;

  return jsonb_build_object(
    'discovered', jsonb_array_length(p_models),
    'added', v_added,
    'removed', v_removed
  );
end
$function$;

revoke all on function public.ingest_ai_model_catalogue(uuid, bigint, jsonb)
  from public, anon, authenticated;
grant execute on function public.ingest_ai_model_catalogue(uuid, bigint, jsonb)
  to service_role;

commit;
