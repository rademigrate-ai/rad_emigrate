create index if not exists applications_user_id_idx on public.applications(user_id);
create index if not exists applications_status_idx on public.applications(status);
create index if not exists documents_user_id_idx on public.documents(user_id);
create index if not exists documents_application_id_idx on public.documents(application_id);
create index if not exists ai_sessions_user_id_idx on public.ai_sessions(user_id);

