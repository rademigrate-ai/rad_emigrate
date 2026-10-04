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
