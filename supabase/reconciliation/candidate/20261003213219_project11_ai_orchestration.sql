
create table public.ai_providers (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9_]+$'),
  display_name text not null,
  adapter text not null check (adapter in ('openai_compatible','anthropic','gemini')),
  base_url text not null check (base_url like 'https://%'),
  secret_id uuid,
  enabled boolean not null default false,
  priority integer not null default 100 check (priority between 1 and 1000),
  failure_threshold integer not null default 3 check (failure_threshold between 1 and 10),
  cooldown_seconds integer not null default 300 check (cooldown_seconds between 30 and 3600),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.ai_models (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.ai_providers(id) on delete cascade,
  slug text not null,
  display_name text not null,
  capability text not null check (capability in ('chat','vision','embedding','document')),
  enabled boolean not null default true,
  context_window integer check (context_window is null or context_window > 0),
  max_output_tokens integer not null default 2048 check (max_output_tokens between 64 and 32768),
  cost_input_per_million numeric(12,6),
  cost_output_per_million numeric(12,6),
  metadata jsonb not null default '{}'::jsonb,
  unique(provider_id,slug)
);

create table public.ai_provider_health (
  provider_id uuid primary key references public.ai_providers(id) on delete cascade,
  status text not null default 'unknown' check (status in ('unknown','healthy','degraded','offline','cooldown')),
  consecutive_failures integer not null default 0 check (consecutive_failures >= 0),
  last_success_at timestamptz,
  last_failure_at timestamptz,
  cooldown_until timestamptz,
  safe_error_code text,
  updated_at timestamptz not null default now()
);

create table public.ai_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid references public.ai_sessions(id) on delete set null,
  capability text not null check (capability in ('chat','vision','embedding','document')),
  status text not null default 'queued' check (status in ('queued','running','succeeded','failed','rate_limited')),
  provider_id uuid references public.ai_providers(id) on delete set null,
  model_id uuid references public.ai_models(id) on delete set null,
  attempt_count integer not null default 0 check (attempt_count between 0 and 5),
  input_tokens integer check (input_tokens is null or input_tokens >= 0),
  output_tokens integer check (output_tokens is null or output_tokens >= 0),
  latency_ms integer check (latency_ms is null or latency_ms >= 0),
  safe_error_code text,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create table public.ai_usage_limits (
  role text primary key check (role in ('user','admin','super_admin')),
  daily_requests integer not null check (daily_requests > 0),
  daily_output_tokens integer not null check (daily_output_tokens > 0)
);
insert into public.ai_usage_limits(role,daily_requests,daily_output_tokens)
values ('user',50,100000),('admin',500,1000000),('super_admin',1000,2000000);

create table public.search_providers (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9_]+$'),
  display_name text not null,
  adapter text not null,
  base_url text not null check (base_url like 'https://%'),
  secret_id uuid,
  enabled boolean not null default false,
  priority integer not null default 100 check (priority between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index ai_models_provider_capability_idx on public.ai_models(provider_id,capability,enabled);
create index ai_requests_user_created_idx on public.ai_requests(user_id,created_at desc);
create index ai_requests_provider_created_idx on public.ai_requests(provider_id,created_at desc);
create index ai_requests_model_idx on public.ai_requests(model_id);
create index ai_requests_session_idx on public.ai_requests(session_id);

alter table public.ai_providers enable row level security;
alter table public.ai_models enable row level security;
alter table public.ai_provider_health enable row level security;
alter table public.ai_requests enable row level security;
alter table public.ai_usage_limits enable row level security;
alter table public.search_providers enable row level security;

revoke all on table public.ai_providers, public.ai_models, public.ai_provider_health,
  public.ai_requests, public.ai_usage_limits, public.search_providers from anon,authenticated;
grant select on table public.ai_providers, public.ai_models, public.ai_usage_limits to authenticated;
grant select on table public.ai_provider_health, public.search_providers to authenticated;
grant select on table public.ai_requests to authenticated;
grant all privileges on table public.ai_providers, public.ai_models, public.ai_provider_health,
  public.ai_requests, public.ai_usage_limits, public.search_providers to service_role;

create policy "enabled provider metadata read" on public.ai_providers for select to authenticated
  using (enabled or (select private.has_role(array['admin','super_admin'])));
create policy "enabled model metadata read" on public.ai_models for select to authenticated
  using ((enabled and exists(select 1 from public.ai_providers p where p.id=provider_id and p.enabled))
    or (select private.has_role(array['admin','super_admin'])));
create policy "admins read provider health" on public.ai_provider_health for select to authenticated
  using ((select private.has_role(array['admin','super_admin'])));
create policy "users read own ai requests" on public.ai_requests for select to authenticated
  using ((select auth.uid())=user_id or (select private.has_role(array['admin','super_admin'])));
create policy "usage limits authenticated read" on public.ai_usage_limits for select to authenticated using (true);
create policy "admins read search provider metadata" on public.search_providers for select to authenticated
  using ((select private.has_role(array['admin','super_admin'])));

create policy "service writes providers" on public.ai_providers for all to service_role using (true) with check (true);
create policy "service writes models" on public.ai_models for all to service_role using (true) with check (true);
create policy "service writes health" on public.ai_provider_health for all to service_role using (true) with check (true);
create policy "service writes requests" on public.ai_requests for all to service_role using (true) with check (true);
create policy "service writes limits" on public.ai_usage_limits for all to service_role using (true) with check (true);
create policy "service writes search providers" on public.search_providers for all to service_role using (true) with check (true);

create or replace function public.configure_ai_provider(
  p_slug text,p_display_name text,p_adapter text,p_base_url text,p_api_key text,
  p_enabled boolean default false,p_priority integer default 100
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_secret_id uuid;
begin
  if not private.has_role(array['super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if p_slug !~ '^[a-z0-9_]+$' or p_adapter not in ('openai_compatible','anthropic','gemini')
    or p_base_url not like 'https://%' or length(coalesce(p_api_key,'')) < 8 then
    raise exception 'invalid provider configuration' using errcode='22023';
  end if;
  select secret_id into v_secret_id from public.ai_providers where slug=p_slug;
  if v_secret_id is null then
    v_secret_id := vault.create_secret(p_api_key,'ai_provider_'||p_slug,'RAD AI provider credential');
  else
    perform vault.update_secret(v_secret_id,p_api_key,'ai_provider_'||p_slug,'RAD AI provider credential');
  end if;
  insert into public.ai_providers(slug,display_name,adapter,base_url,secret_id,enabled,priority)
  values(p_slug,p_display_name,p_adapter,rtrim(p_base_url,'/'),v_secret_id,p_enabled,p_priority)
  on conflict(slug) do update set display_name=excluded.display_name,adapter=excluded.adapter,
    base_url=excluded.base_url,secret_id=excluded.secret_id,enabled=excluded.enabled,
    priority=excluded.priority,updated_at=now() returning id into v_id;
  insert into public.ai_provider_health(provider_id) values(v_id) on conflict do nothing;
  insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,safe_metadata)
  values(auth.uid(),'configure','ai_provider',v_id::text,jsonb_build_object('slug',p_slug,'enabled',p_enabled,'adapter',p_adapter));
  return v_id;
end $$;
alter function public.configure_ai_provider(text,text,text,text,text,boolean,integer) owner to postgres;
revoke all on function public.configure_ai_provider(text,text,text,text,text,boolean,integer) from public,anon;
grant execute on function public.configure_ai_provider(text,text,text,text,text,boolean,integer) to authenticated;

create or replace function public.get_ai_runtime_chain(p_capability text default 'chat')
returns table(provider_id uuid,provider_slug text,adapter text,base_url text,model_id uuid,model_slug text,
  max_output_tokens integer,api_key text)
language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
  return query
  select p.id,p.slug,p.adapter,p.base_url,m.id,m.slug,m.max_output_tokens,v.decrypted_secret
  from public.ai_providers p
  join public.ai_models m on m.provider_id=p.id and m.capability=p_capability and m.enabled
  join vault.decrypted_secrets v on v.id=p.secret_id
  left join public.ai_provider_health h on h.provider_id=p.id
  where p.enabled and (h.cooldown_until is null or h.cooldown_until <= now())
  order by p.priority,m.slug
  limit 5;
end $$;
alter function public.get_ai_runtime_chain(text) owner to postgres;
revoke all on function public.get_ai_runtime_chain(text) from public,anon,authenticated;
grant execute on function public.get_ai_runtime_chain(text) to service_role;



