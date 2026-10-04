create table if not exists public.ai_session_messages (id uuid primary key default gen_random_uuid(), session_id uuid not null references public.ai_sessions(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade, role text not null check (role in ('user', 'assistant', 'system')), content text not null, created_at timestamptz not null default now());
create index if not exists ai_session_messages_session_idx on public.ai_session_messages (session_id, created_at);
alter table public.ai_session_messages enable row level security;
drop policy if exists "ai messages owner access" on public.ai_session_messages;
create policy "ai messages owner access" on public.ai_session_messages for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter table public.documents alter column application_id drop not null;

