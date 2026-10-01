-- Project 05: enforce upload type and size at the Storage policy boundary.
drop policy if exists "documents storage upload own" on storage.objects;
create policy "documents storage upload own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (metadata ->> 'mimetype') in ('application/pdf', 'image/jpeg', 'image/png')
    and (metadata ->> 'size') ~ '^[0-9]{1,12}$'
    and (metadata ->> 'size')::bigint between 1 and 10485760
  );
