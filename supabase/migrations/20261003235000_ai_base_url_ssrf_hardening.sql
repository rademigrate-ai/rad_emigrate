-- Parallel reconciliation: SSRF hardening for configurable AI provider base_url.
-- HTTPS-only is insufficient; reject private/loopback/link-local/metadata hosts.
begin;

create or replace function private.is_safe_public_https_url(p_url text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $function$
declare
  v_host text;
begin
  if p_url is null or p_url !~* '^https://' then
    return false;
  end if;
  -- Extract host (lowercase): after scheme, before port/path/query
  v_host := lower(split_part(split_part(substring(p_url from 9), '/', 1), ':', 1));
  if v_host = '' or v_host is null then
    return false;
  end if;
  -- Explicit blocklist
  if v_host in (
    'localhost',
    'localhost.localdomain',
    'metadata.google.internal',
    'metadata',
    '0.0.0.0'
  ) then
    return false;
  end if;
  if v_host like '%.localhost' or v_host like '%.local' then
    return false;
  end if;
  -- IPv4 literal checks
  if v_host ~ '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' then
    -- loopback 127.0.0.0/8
    if v_host like '127.%' then
      return false;
    end if;
    -- RFC1918 private
    if v_host like '10.%' then
      return false;
    end if;
    if v_host ~ '^172\.(1[6-9]|2[0-9]|3[0-1])\.' then
      return false;
    end if;
    if v_host like '192.168.%' then
      return false;
    end if;
    -- link-local 169.254.0.0/16 (includes cloud metadata 169.254.169.254)
    if v_host like '169.254.%' then
      return false;
    end if;
    -- CGNAT / other reserved
    if v_host like '100.64.%' or v_host like '100.6[5-9].%' or v_host like '100.[7-9]%.%' or v_host like '100.1[0-2][0-7].%' then
      return false;
    end if;
  end if;
  -- IPv6 loopback / unique-local / link-local (simplified string checks)
  if v_host = '::1' or v_host like 'fe80:%' or v_host like 'fc%' or v_host like 'fd%' then
    return false;
  end if;
  return true;
end
$function$;

alter function private.is_safe_public_https_url(text) owner to postgres;
revoke all on function private.is_safe_public_https_url(text) from public, anon, authenticated;

create or replace function public.configure_ai_provider(
  p_slug text,p_display_name text,p_adapter text,p_base_url text,p_api_key text,
  p_enabled boolean default false,p_priority integer default 100
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_secret_id uuid;
begin
  if not private.has_role(array['super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if p_slug !~ '^[a-z0-9_]+$' or p_adapter not in ('openai_compatible','anthropic','gemini')
    or not private.is_safe_public_https_url(p_base_url) or length(coalesce(p_api_key,'')) < 8 then
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

commit;
