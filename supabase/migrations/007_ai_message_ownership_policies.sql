-- Project 05: bind AI messages to both the authenticated user and owner session.
drop policy if exists "ai messages owner access" on public.ai_session_messages;
drop policy if exists "ai messages select own session" on public.ai_session_messages;
drop policy if exists "ai messages insert own session" on public.ai_session_messages;
drop policy if exists "ai messages update own session" on public.ai_session_messages;
drop policy if exists "ai messages delete own session" on public.ai_session_messages;

create policy "ai messages select own session" on public.ai_session_messages
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.ai_sessions s
      where s.id = ai_session_messages.session_id
        and s.user_id = (select auth.uid())
    )
  );

create policy "ai messages insert own session" on public.ai_session_messages
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.ai_sessions s
      where s.id = ai_session_messages.session_id
        and s.user_id = (select auth.uid())
    )
  );

create policy "ai messages update own session" on public.ai_session_messages
  for update to authenticated
  using (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.ai_sessions s
      where s.id = ai_session_messages.session_id
        and s.user_id = (select auth.uid())
    )
  )
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.ai_sessions s
      where s.id = ai_session_messages.session_id
        and s.user_id = (select auth.uid())
    )
  );

create policy "ai messages delete own session" on public.ai_session_messages
  for delete to authenticated
  using (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.ai_sessions s
      where s.id = ai_session_messages.session_id
        and s.user_id = (select auth.uid())
    )
  );
