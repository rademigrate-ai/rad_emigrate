-- Project 05: tighten table privileges, ownership checks, and private storage policies.
-- No user data is modified or deleted.

begin;

revoke all on table
  public.profiles,
  public.applications,
  public.documents,
  public.ai_sessions,
  public.ai_session_messages
from public, anon, authenticated;

grant select, insert, update, delete on table
  public.profiles,
  public.applications,
  public.documents,
  public.ai_sessions,
  public.ai_session_messages
to authenticated;

drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own" on public.profiles
  for insert to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "documents select own" on public.documents;
drop policy if exists "documents insert own" on public.documents;
drop policy if exists "documents update own" on public.documents;
drop policy if exists "documents delete own" on public.documents;

create policy "documents select own" on public.documents
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    and (
      application_id is null
      or exists (
        select 1 from public.applications a
        where a.id = documents.application_id
          and a.user_id = (select auth.uid())
      )
    )
  );

create policy "documents insert own" on public.documents
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and (
      application_id is null
      or exists (
        select 1 from public.applications a
        where a.id = documents.application_id
          and a.user_id = (select auth.uid())
      )
    )
  );

create policy "documents update own" on public.documents
  for update to authenticated
  using (
    (select auth.uid()) = user_id
    and (
      application_id is null
      or exists (
        select 1 from public.applications a
        where a.id = documents.application_id
          and a.user_id = (select auth.uid())
      )
    )
  )
  with check (
    (select auth.uid()) = user_id
    and (
      application_id is null
      or exists (
        select 1 from public.applications a
        where a.id = documents.application_id
          and a.user_id = (select auth.uid())
      )
    )
  );

create policy "documents delete own" on public.documents
  for delete to authenticated
  using (
    (select auth.uid()) = user_id
    and (
      application_id is null
      or exists (
        select 1 from public.applications a
        where a.id = documents.application_id
          and a.user_id = (select auth.uid())
      )
    )
  );

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

create index if not exists ai_session_messages_user_id_idx
  on public.ai_session_messages (user_id);

drop policy if exists "Users can delete own documents" on storage.objects;
drop policy if exists "Users can upload own documents" on storage.objects;
drop policy if exists "Users can view own documents" on storage.objects;
drop policy if exists "documents storage read own" on storage.objects;
drop policy if exists "documents storage upload own" on storage.objects;
drop policy if exists "documents storage delete own" on storage.objects;

create policy "documents storage read own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "documents storage upload own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "documents storage delete own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

alter function public.handle_new_user() set search_path = '';
revoke execute on function public.handle_new_user() from public, anon, authenticated;
grant execute on function public.handle_new_user() to postgres;

commit;



