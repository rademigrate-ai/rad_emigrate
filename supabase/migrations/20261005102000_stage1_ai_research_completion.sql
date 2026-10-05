-- Stage 1 AI control plane, scoped runtime and research review completion.
-- Additive only: historical migrations remain immutable.
begin;

alter table public.ai_models
  add column if not exists available boolean not null default true,
  add column if not exists discovered_at timestamptz,
  add column if not exists last_seen_at timestamptz;

alter table public.research_sources
  add column if not exists display_name text,
  add column if not exists source_type text not null default 'external',
  add column if not exists trust_class text not null default 'general_web',
  add column if not exists country_code text,
  add column if not exists topic text,
  add column if not exists last_error_code text;

alter table public.research_sources
  add constraint research_sources_source_type_check
  check (source_type in ('rad_first_party','government','embassy','institution','external'));
alter table public.research_sources
  add constraint research_sources_trust_class_check
  check (trust_class in ('rad_official','authoritative_external','admin_defined','general_web'));

update public.research_sources
set display_name = case allowed_host
      when 'radvisa.com' then 'RAD Visa'
      when 'digivisa.ir' then 'DigiVisa'
      when 'radmohajer.ir' then 'RAD Mohajer'
      else allowed_host
    end,
    source_type = case when authority = 'rad_official' then 'rad_first_party' else 'external' end,
    trust_class = case when authority = 'rad_official' then 'rad_official' else 'admin_defined' end
where display_name is null;

alter table public.research_sources alter column display_name set not null;

revoke insert,update,delete on table public.research_sources from authenticated;
drop policy if exists "admins manage research sources" on public.research_sources;
create policy "admins read research sources" on public.research_sources for select to authenticated
  using ((select private.has_role(array['admin','super_admin'])));

create index if not exists ai_models_runtime_idx
  on public.ai_models(provider_id, capability, runtime_scope, enabled, available, priority);
create index if not exists research_sources_runtime_idx
  on public.research_sources(enabled, runtime_scope, source_type);

-- Credential replacement is optional on update. A new provider still requires
-- a key, and no response ever contains the stored value.
create or replace function public.configure_ai_provider(
  p_slug text,p_display_name text,p_adapter text,p_base_url text,p_api_key text,
  p_enabled boolean default false,p_priority integer default 100
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_secret_id uuid; v_key text := nullif(btrim(p_api_key),'');
begin
  if not private.has_role(array['super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if p_slug !~ '^[a-z0-9_]+$' or p_adapter not in ('openai_compatible','anthropic','gemini')
    or not private.is_safe_public_https_url(p_base_url) or p_priority not between 1 and 1000 then
    raise exception 'invalid provider configuration' using errcode='22023';
  end if;
  select id,secret_id into v_id,v_secret_id from public.ai_providers where slug=p_slug;
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
  insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,safe_metadata)
  values(auth.uid(),'configure','ai_provider',v_id::text,
    jsonb_build_object('slug',p_slug,'enabled',p_enabled,'adapter',p_adapter,'credential_replaced',v_key is not null));
  return v_id;
end $$;
alter function public.configure_ai_provider(text,text,text,text,text,boolean,integer) owner to postgres;
revoke all on function public.configure_ai_provider(text,text,text,text,text,boolean,integer) from public,anon;
grant execute on function public.configure_ai_provider(text,text,text,text,text,boolean,integer) to authenticated;

create or replace function public.set_ai_model_configuration(
  p_model_id uuid,p_enabled boolean,p_runtime_scope text,p_priority integer,p_max_output_tokens integer
) returns void language plpgsql security definer set search_path='' as $$
begin
  if not private.has_role(array['admin','super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if p_runtime_scope not in ('user','admin','both') or p_priority not between 0 and 10000
    or p_max_output_tokens not between 64 and 32768 then raise exception 'invalid model configuration' using errcode='22023'; end if;
  update public.ai_models set enabled=p_enabled,runtime_scope=p_runtime_scope,priority=p_priority,
    max_output_tokens=p_max_output_tokens where id=p_model_id;
  if not found then raise exception 'model not found' using errcode='P0002'; end if;
  insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,safe_metadata)
  values(auth.uid(),'configure','ai_model',p_model_id::text,
    jsonb_build_object('enabled',p_enabled,'runtime_scope',p_runtime_scope,'priority',p_priority));
end $$;
alter function public.set_ai_model_configuration(uuid,boolean,text,integer,integer) owner to postgres;
revoke all on function public.set_ai_model_configuration(uuid,boolean,text,integer,integer) from public,anon;
grant execute on function public.set_ai_model_configuration(uuid,boolean,text,integer,integer) to authenticated;

create or replace function public.set_research_source_configuration(
  p_source_id uuid,p_display_name text,p_enabled boolean,p_runtime_scope text,p_trust_class text,
  p_country_code text default null,p_topic text default null
) returns void language plpgsql security definer set search_path='' as $$
begin
  if not private.has_role(array['admin','super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if p_runtime_scope not in ('user','admin','both') or p_trust_class not in
    ('rad_official','authoritative_external','admin_defined','general_web') then
    raise exception 'invalid source configuration' using errcode='22023';
  end if;
  if p_trust_class='rad_official' and not private.has_role(array['super_admin']) then
    raise exception 'forbidden' using errcode='42501';
  end if;
  update public.research_sources set display_name=btrim(p_display_name),enabled=p_enabled,
    runtime_scope=p_runtime_scope,trust_class=p_trust_class,country_code=nullif(upper(btrim(p_country_code)),''),
    topic=nullif(btrim(p_topic),'') where id=p_source_id;
  if not found then raise exception 'source not found' using errcode='P0002'; end if;
end $$;
alter function public.set_research_source_configuration(uuid,text,boolean,text,text,text,text) owner to postgres;
revoke all on function public.set_research_source_configuration(uuid,text,boolean,text,text,text,text) from public,anon;
grant execute on function public.set_research_source_configuration(uuid,text,boolean,text,text,text,text) to authenticated;

create or replace function public.upsert_research_source(
  p_source_id uuid,p_display_name text,p_base_url text,p_source_type text,p_trust_class text,
  p_runtime_scope text,p_enabled boolean default false,p_country_code text default null,p_topic text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_host text;
begin
  if not private.has_role(array['admin','super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if not private.is_safe_public_https_url(p_base_url)
    or p_source_type not in ('rad_first_party','government','embassy','institution','external')
    or p_trust_class not in ('rad_official','authoritative_external','admin_defined','general_web')
    or p_runtime_scope not in ('user','admin','both') then
    raise exception 'invalid source configuration' using errcode='22023';
  end if;
  if (p_source_type='rad_first_party' or p_trust_class='rad_official')
    and not private.has_role(array['super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  v_host := lower(split_part(split_part(substring(p_base_url from 9),'/',1),':',1));
  if p_source_id is null then
    insert into public.research_sources(base_url,allowed_host,authority,enabled,display_name,source_type,
      trust_class,runtime_scope,country_code,topic)
    values(rtrim(p_base_url,'/'),v_host,
      case when p_trust_class='rad_official' then 'rad_official'
           when p_source_type='government' then 'government'
           when p_source_type='embassy' then 'embassy'
           when p_source_type='institution' then 'institution' else 'other' end,
      p_enabled,btrim(p_display_name),p_source_type,p_trust_class,p_runtime_scope,
      nullif(upper(btrim(p_country_code)),''),nullif(btrim(p_topic),'')) returning id into v_id;
  else
    update public.research_sources set base_url=rtrim(p_base_url,'/'),allowed_host=v_host,
      display_name=btrim(p_display_name),source_type=p_source_type,trust_class=p_trust_class,
      runtime_scope=p_runtime_scope,enabled=p_enabled,country_code=nullif(upper(btrim(p_country_code)),''),
      topic=nullif(btrim(p_topic),'') where id=p_source_id returning id into v_id;
    if v_id is null then raise exception 'source not found' using errcode='P0002'; end if;
  end if;
  return v_id;
end $$;
alter function public.upsert_research_source(uuid,text,text,text,text,text,boolean,text,text) owner to postgres;
revoke all on function public.upsert_research_source(uuid,text,text,text,text,text,boolean,text,text) from public,anon;
grant execute on function public.upsert_research_source(uuid,text,text,text,text,text,boolean,text,text) to authenticated;

-- Runtime credentials remain service-role only. Scope is enforced here, not
-- in Flutter, and unhealthy/cooldown/unavailable candidates are excluded.
create or replace function public.get_ai_runtime_chain(p_capability text,p_scope text)
returns table(provider_id uuid,provider_slug text,adapter text,base_url text,model_id uuid,model_slug text,
  max_output_tokens integer,request_timeout_seconds integer,max_retries integer,api_key text)
language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
  if p_scope not in ('user','admin') then raise exception 'invalid scope' using errcode='22023'; end if;
  return query
  select p.id,p.slug,p.adapter,p.base_url,m.id,m.slug,m.max_output_tokens,
    p.request_timeout_seconds,p.max_retries,v.decrypted_secret
  from public.ai_providers p
  join public.ai_models m on m.provider_id=p.id and m.capability=p_capability and m.enabled and m.available
  join vault.decrypted_secrets v on v.id=p.secret_id
  left join public.ai_provider_health h on h.provider_id=p.id
  where p.enabled
    and p.runtime_scope in (p_scope,'both') and m.runtime_scope in (p_scope,'both')
    and coalesce(h.status,'unknown') not in ('offline','cooldown')
    and (h.cooldown_until is null or h.cooldown_until <= now())
  order by p.priority,m.priority,m.slug,p.id,m.id
  limit 5;
end $$;
alter function public.get_ai_runtime_chain(text,text) owner to postgres;
revoke all on function public.get_ai_runtime_chain(text,text) from public,anon,authenticated;
grant execute on function public.get_ai_runtime_chain(text,text) to service_role;

create or replace function public.get_ai_provider_runtime(p_provider_id uuid)
returns table(provider_id uuid,provider_slug text,adapter text,base_url text,request_timeout_seconds integer,api_key text)
language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
  return query select p.id,p.slug,p.adapter,p.base_url,p.request_timeout_seconds,v.decrypted_secret
  from public.ai_providers p join vault.decrypted_secrets v on v.id=p.secret_id where p.id=p_provider_id;
end $$;
alter function public.get_ai_provider_runtime(uuid) owner to postgres;
revoke all on function public.get_ai_provider_runtime(uuid) from public,anon,authenticated;
grant execute on function public.get_ai_provider_runtime(uuid) to service_role;

-- Stage 1 research produces a review candidate only; there is intentionally
-- no Feed write or publish transition in this function.
create or replace function public.create_research_review_candidate(
  p_job_id uuid,p_finding_id uuid,p_title text,p_summary text,p_language_code text default 'en'
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
  insert into public.content_drafts(research_job_id,language_code,title,body,status)
  values(p_job_id,case when p_language_code='fa' then 'fa' else 'en' end,left(p_title,300),p_summary,'review')
  returning id into v_id;
  return v_id;
end $$;
alter function public.create_research_review_candidate(uuid,uuid,text,text,text) owner to postgres;
revoke all on function public.create_research_review_candidate(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.create_research_review_candidate(uuid,uuid,text,text,text) to service_role;

commit;
