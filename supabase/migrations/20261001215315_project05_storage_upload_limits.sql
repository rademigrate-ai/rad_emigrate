-- Enforce upload size and declared content type at the Storage RLS boundary.
-- Bucket-level server configuration remains preferable and is documented.

drop policy if exists "documents storage upload own" on storage.objects;

create policy "documents storage upload own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and metadata->>'mimetype' in (
      'application/pdf',
      'image/jpeg',
      'image/png'
    )
    and case
      when metadata->>'size' ~ '^[0-9]{1,12}$'
        then (metadata->>'size')::bigint between 1 and 10485760
      else false
    end
  );



