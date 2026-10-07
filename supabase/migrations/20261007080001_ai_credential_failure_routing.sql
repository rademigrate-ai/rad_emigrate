-- Continue the existing routing architecture. Credential rejection is latched,
-- transient cooldowns recover, and stale concurrent outcomes cannot poison a new key.
begin;
alter table public.ai_sessions add column scope text not null default 'user' check (scope in ('user','admin'));
alter table public.ai_models
 add column cost_source text not null default 'unknown' check (cost_source in ('discovered','configured','unknown'));
alter table public.ai_providers add column credential_version bigint not null default 1;
alter table public.ai_provider_health add column credential_rejected boolean not null default false;
update public.ai_provider_health set credential_rejected=true,cooldown_until=null
where safe_error_code='provider_unauthorized';
-- Authentication is a provider credential property, not a model capability.
update public.ai_models set discovery_status=case when available then 'active' else 'stale' end,
  cooldown_until=null where last_error_code='provider_unauthorized';
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
;
end $$;

alter function public.get_ai_runtime_chain(text, text, boolean, boolean, integer) owner to postgres;
revoke all on function public.get_ai_runtime_chain(text, text, boolean, boolean, integer)
  from public, anon, authenticated;
grant execute on function public.get_ai_runtime_chain(text, text, boolean, boolean, integer)
  to service_role;

create or replace function public.configure_ai_provider(
  p_slug text,p_display_name text,p_adapter text,p_base_url text,p_api_key text,
  p_enabled boolean default false,p_priority integer default 100
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_secret_id uuid; v_key text := nullif(btrim(p_api_key),''); v_changed boolean := false; v_old_key text;
begin
  if not private.has_role(array['super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if p_slug !~ '^[a-z0-9_]+$' or p_adapter not in ('openai_compatible','anthropic','gemini')
    or not private.is_safe_public_https_url(p_base_url) or p_priority not between 1 and 1000 then
    raise exception 'invalid provider configuration' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('ai_provider:'||p_slug,0));
  select id,secret_id into v_id,v_secret_id from public.ai_providers where slug=p_slug for update;
  if v_secret_id is not null and v_key is not null then
    select decrypted_secret into v_old_key from vault.decrypted_secrets where id=v_secret_id;
  end if;
  v_changed := v_key is not null and v_key is distinct from v_old_key;
  if v_secret_id is null and length(coalesce(v_key,'')) < 8 then
    raise exception 'credential required' using errcode='22023';
  end if;
  if v_key is not null and length(v_key) < 8 then
    raise exception 'invalid credential' using errcode='22023';
  elsif v_key is not null and v_secret_id is null then
    v_secret_id := vault.create_secret(v_key,'ai_provider_'||p_slug,'RAD AI provider credential');
  elsif v_key is not null then
    perform vault.update_secret(v_secret_id,v_key,'ai_provider_'||p_slug,'RAD AI provider credential');
  end if;
  insert into public.ai_providers(slug,display_name,adapter,base_url,secret_id,enabled,priority)
  values(p_slug,btrim(p_display_name),p_adapter,rtrim(p_base_url,'/'),v_secret_id,p_enabled,p_priority)
  on conflict(slug) do update set display_name=excluded.display_name,adapter=excluded.adapter,
    base_url=excluded.base_url,secret_id=excluded.secret_id,enabled=excluded.enabled,
    priority=excluded.priority,updated_at=now() returning id into v_id;
  insert into public.ai_provider_health(provider_id) values(v_id) on conflict do nothing;
  if v_changed then
    update public.ai_providers set credential_version=credential_version+1 where id=v_id;
    update public.ai_provider_health set credential_rejected=false,status='unknown',
      consecutive_failures=0,cooldown_until=null,safe_error_code=null where provider_id=v_id;
  end if;
  insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,safe_metadata)
  values(auth.uid(),'configure','ai_provider',v_id::text,
    jsonb_build_object('slug',p_slug,'enabled',p_enabled,'adapter',p_adapter,'credential_replaced',v_key is not null));
  return v_id;
end $$;
alter function public.configure_ai_provider(text,text,text,text,text,boolean,integer) owner to postgres;
revoke all on function public.configure_ai_provider(text,text,text,text,text,boolean,integer) from public,anon;
grant execute on function public.configure_ai_provider(text,text,text,text,text,boolean,integer) to authenticated;


-- New internal versioned envelope; existing RPC contracts remain intact.
create function public.get_ai_runtime_chain_versioned(
 p_capability text,p_scope text,p_require_tools boolean,p_require_structured boolean,p_min_context integer
) returns setof jsonb language sql security definer set search_path='' as $$
 select to_jsonb(c) || jsonb_build_object('credential_version',p.credential_version)
 from public.get_ai_runtime_chain(p_capability,p_scope,p_require_tools,p_require_structured,p_min_context) c
 join public.ai_providers p on p.id=c.provider_id;
$$;
revoke all on function public.get_ai_runtime_chain_versioned(text,text,boolean,boolean,integer) from public,anon,authenticated;
grant execute on function public.get_ai_runtime_chain_versioned(text,text,boolean,boolean,integer) to service_role;
create function public.get_ai_provider_runtime_versioned(p_provider_id uuid)
returns setof jsonb language sql security definer set search_path='' as $$
 select to_jsonb(c) || jsonb_build_object('credential_version',p.credential_version)
 from public.get_ai_provider_runtime(p_provider_id) c join public.ai_providers p on p.id=c.provider_id;
$$;
revoke all on function public.get_ai_provider_runtime_versioned(uuid) from public,anon,authenticated;
grant execute on function public.get_ai_provider_runtime_versioned(uuid) to service_role;

create function public.record_ai_provider_outcome(p_provider_id uuid,p_credential_version bigint,
 p_error_code text default null,p_revalidated boolean default false)
returns void language plpgsql security definer set search_path='' as $$
declare v_version bigint; v_failures integer;
begin
 if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
 select credential_version into v_version from public.ai_providers where id=p_provider_id for update;
 if v_version is distinct from p_credential_version then return; end if;
 select consecutive_failures into v_failures from public.ai_provider_health where provider_id=p_provider_id for update;
 v_failures:=least(coalesce(v_failures,0)+1,1000);
 if p_error_code='provider_unauthorized' then
  update public.ai_provider_health set credential_rejected=true,status='offline',
   safe_error_code=p_error_code,last_failure_at=now(),cooldown_until=null,
   consecutive_failures=v_failures,updated_at=now() where provider_id=p_provider_id;
 elsif p_error_code is null then
  update public.ai_provider_health set credential_rejected=false,status='healthy',
   safe_error_code=null,last_success_at=now(),cooldown_until=null,
   consecutive_failures=0,updated_at=now() where provider_id=p_provider_id
   and (not credential_rejected or p_revalidated);
 else
  update public.ai_provider_health set status=case when p_error_code='provider_rate_limited' or v_failures>=3 then 'cooldown' else 'degraded' end,
   safe_error_code=p_error_code,last_failure_at=now(),
   cooldown_until=case when p_error_code='provider_rate_limited' or v_failures>=3 then now()+interval '5 minutes' else null end,
   consecutive_failures=v_failures,updated_at=now()
   where provider_id=p_provider_id and not credential_rejected;
 end if;
end $$;
revoke all on function public.record_ai_provider_outcome(uuid,bigint,text,boolean) from public,anon,authenticated;
grant execute on function public.record_ai_provider_outcome(uuid,bigint,text,boolean) to service_role;
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
        when p_error_code in ('provider_rate_limited','provider_timeout','provider_unavailable','provider_invalid_request','provider_malformed_response','provider_unreachable') then v_now + interval '5 minutes'
        when v_failures >= 3 then v_now + interval '3 minutes'
        else cooldown_until
      end,
      -- Permanent-ish auth failure on this model path: mark discovery unavailable until rediscovery
      discovery_status = case
        when p_error_code = 'provider_model_unavailable' then 'unavailable'
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


-- Every runtime overload delegates to the same eligibility contract.
create or replace function public.get_ai_runtime_chain(p_capability text default 'chat')
returns table(provider_id uuid,provider_slug text,adapter text,base_url text,model_id uuid,model_slug text,max_output_tokens integer,api_key text)
language sql security definer set search_path='' as $$
 select c.provider_id,c.provider_slug,c.adapter,c.base_url,c.model_id,c.model_slug,c.max_output_tokens,c.api_key
 from public.get_ai_runtime_chain(p_capability,'user',false,false,null) c;
$$;
revoke all on function public.get_ai_runtime_chain(text) from public,anon,authenticated;
grant execute on function public.get_ai_runtime_chain(text) to service_role;

-- One bounded transaction instead of hundreds of separate network writes.
-- Discovery preserves all Admin enable/scope/preference settings.
create function public.ingest_ai_model_catalogue(p_provider_id uuid,p_credential_version bigint,p_models jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_version bigint; v_old integer; v_added integer; v_removed integer;
begin
 if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
 select credential_version into v_version from public.ai_providers where id=p_provider_id for update;
 if v_version is distinct from p_credential_version then raise exception 'configuration changed' using errcode='40001'; end if;
 if jsonb_typeof(p_models) <> 'array' or jsonb_array_length(p_models)>5000 then raise exception 'invalid catalogue' using errcode='22023'; end if;
 select count(*) into v_old from public.ai_models where provider_id=p_provider_id;
 insert into public.ai_models(provider_id,slug,display_name,capability,enabled,available,runtime_scope,priority,
  discovered_at,last_seen_at,discovery_status,context_window,supports_tools,supports_structured_output,capability_source,cost_input_per_million,cost_source)
 select p_provider_id,x.slug,x.slug,x.capability,false,true,'both',100,now(),now(),'active',x.context_window,
  x.supports_tools,x.supports_structured_output,x.capability_source,x.cost_input_per_million,x.cost_source
 from jsonb_to_recordset(p_models) as x(slug text,capability text,context_window integer,supports_tools boolean,supports_structured_output boolean,
  capability_source text,cost_input_per_million numeric,cost_source text)
 on conflict(provider_id,slug) do update set available=true,last_seen_at=now(),discovery_status='active',
  context_window=case when ai_models.capability_source='configured' then ai_models.context_window else excluded.context_window end,
  supports_tools=case when ai_models.capability_source='configured' then ai_models.supports_tools else excluded.supports_tools end,
  supports_structured_output=case when ai_models.capability_source='configured' then ai_models.supports_structured_output else excluded.supports_structured_output end,
  capability_source=case when ai_models.capability_source='configured' then 'configured' else excluded.capability_source end,
  cost_input_per_million=case when ai_models.cost_source='configured' then ai_models.cost_input_per_million else excluded.cost_input_per_million end,
  cost_source=case when ai_models.cost_source='configured' then 'configured' else excluded.cost_source end;
 select count(*)-v_old into v_added from public.ai_models where provider_id=p_provider_id;
 update public.ai_models m set available=false,discovery_status='stale' where provider_id=p_provider_id
  and not exists(select 1 from jsonb_array_elements(p_models) x where x->>'slug'=m.slug);
 get diagnostics v_removed = row_count;
 return jsonb_build_object('discovered',jsonb_array_length(p_models),'added',v_added,'removed',v_removed);
end $$;
revoke all on function public.ingest_ai_model_catalogue(uuid,bigint,jsonb) from public,anon,authenticated;
grant execute on function public.ingest_ai_model_catalogue(uuid,bigint,jsonb) to service_role;

commit;
