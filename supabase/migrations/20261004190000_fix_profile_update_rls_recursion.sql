-- Prevent profile self-role escalation without recursively querying profiles
-- from the profiles RLS policy itself, and keep document Storage writes
-- compatible with current Supabase Storage metadata behavior while preserving
-- bucket MIME/size limits plus owner-folder isolation.
begin;

drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check (
    (select auth.uid()) = id
    and (select private.has_role(array[role]))
  );

drop policy if exists "documents storage upload own" on storage.objects;
create policy "documents storage upload own" on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

commit;
