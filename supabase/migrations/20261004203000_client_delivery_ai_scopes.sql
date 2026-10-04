alter table public.ai_providers add column if not exists runtime_scope text not null default 'both';
alter table public.ai_providers add column if not exists request_timeout_seconds integer not null default 30;
alter table public.ai_providers add column if not exists max_retries integer not null default 1;
alter table public.ai_models add column if not exists runtime_scope text not null default 'both';
alter table public.ai_models add column if not exists priority integer not null default 100;
alter table public.research_sources add column if not exists runtime_scope text not null default 'both';

alter table public.ai_providers add constraint ai_providers_runtime_scope_check check (runtime_scope in ('user','admin','both'));
alter table public.ai_providers add constraint ai_providers_timeout_check check (request_timeout_seconds between 5 and 120);
alter table public.ai_providers add constraint ai_providers_retries_check check (max_retries between 0 and 3);
alter table public.ai_models add constraint ai_models_runtime_scope_check check (runtime_scope in ('user','admin','both'));
alter table public.ai_models add constraint ai_models_priority_check check (priority between 0 and 10000);
alter table public.research_sources add constraint research_sources_runtime_scope_check check (runtime_scope in ('user','admin','both'));

create or replace function public.get_ai_runtime_chain(p_capability text, p_runtime_scope text default 'user')
returns table(provider_id uuid, provider_slug text, adapter text, base_url text, model_id uuid, model_slug text, max_output_tokens integer, provider_priority integer, model_priority integer, request_timeout_seconds integer, max_retries integer)
language sql security definer set search_path = public, private as $$
  select p.id, p.slug, p.adapter, p.base_url, m.id, m.slug, m.max_output_tokens,
         p.priority, m.priority, p.request_timeout_seconds, p.max_retries
  from public.ai_providers p
  join public.ai_models m on m.provider_id = p.id
  left join public.ai_provider_health h on h.provider_id = p.id
  where p.enabled and m.enabled and m.capability = p_capability
    and p.runtime_scope in (p_runtime_scope, 'both')
    and m.runtime_scope in (p_runtime_scope, 'both')
    and (h.cooldown_until is null or h.cooldown_until <= now())
    and (p_runtime_scope <> 'admin' or private.has_role(array['admin','super_admin']))
  order by p.priority, m.priority, p.slug, m.slug;
$$;
revoke all on function public.get_ai_runtime_chain(text,text) from public, anon;
grant execute on function public.get_ai_runtime_chain(text,text) to authenticated;
