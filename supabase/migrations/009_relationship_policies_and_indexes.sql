-- Project 06: enforce application ownership when documents are linked to cases.
create index if not exists applications_user_id_idx on public.applications (user_id);
create index if not exists applications_status_idx on public.applications (status);
create index if not exists documents_user_id_idx on public.documents (user_id);
create index if not exists documents_application_id_idx on public.documents (application_id);
create index if not exists ai_sessions_user_id_idx on public.ai_sessions (user_id);
create index if not exists ai_session_messages_user_id_idx on public.ai_session_messages (user_id);

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
