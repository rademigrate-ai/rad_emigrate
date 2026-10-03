-- Storage inserts return the inserted metadata row. Keep that readback
-- scoped to the authenticated owner as well as the existing user-folder policy.
CREATE POLICY "documents storage readback own" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'documents'
    AND owner_id = (SELECT auth.uid()::text)
  );
