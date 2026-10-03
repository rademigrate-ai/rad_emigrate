-- Project 05: enforce ownership at the Storage RLS boundary.
-- MIME type and size are enforced by storage.buckets, where the Storage API
-- validates the uploaded object before inserting its metadata row.
drop policy if exists "documents storage upload own" on storage.objects;
create policy "documents storage upload own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
