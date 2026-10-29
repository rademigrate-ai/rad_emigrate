-- Disposable-schema regression; transaction rolls back fixture rows.
BEGIN;
DO $$
DECLARE
  archive_oid oid := to_regclass('private.rad_evidence_import_archive');
BEGIN
  IF archive_oid IS NULL THEN
    RAISE EXCEPTION 'private evidence archive missing';
  END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = archive_oid) THEN
    RAISE EXCEPTION 'private evidence archive must enable RLS';
  END IF;
  IF has_table_privilege('anon', archive_oid, 'SELECT')
     OR has_table_privilege('authenticated', archive_oid, 'SELECT')
     OR has_table_privilege('authenticated', archive_oid, 'INSERT')
     OR has_table_privilege('service_role', archive_oid, 'SELECT') THEN
    RAISE EXCEPTION 'private evidence archive is exposed to client or service role';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_policies
             WHERE schemaname='private' AND tablename='rad_evidence_import_archive') THEN
    RAISE EXCEPTION 'unexpected client-facing evidence archive policy';
  END IF;
END $$;

DO $$
DECLARE
  item_id constant text := '11111111-1111-4111-8111-111111111111';
  body jsonb := jsonb_build_object('id', item_id, 'title', 'Source fixture');
BEGIN
  BEGIN
    INSERT INTO private.rad_evidence_import_archive
      (source_project_ref, source_table, source_key, payload, payload_sha256)
    VALUES ('epolbumcfbohtmgvomki', 'content_sources', item_id, body, repeat('0',64));
    RAISE EXCEPTION 'invalid source SHA was accepted';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
  INSERT INTO private.rad_evidence_import_archive
    (source_project_ref, source_table, source_key, payload, payload_sha256)
  VALUES (
    'epolbumcfbohtmgvomki', 'content_sources', item_id,
    body, encode(digest(body::text,'sha256'),'hex')
  );
  IF NOT EXISTS (
    SELECT 1 FROM private.rad_evidence_import_archive
    WHERE source_project_ref='epolbumcfbohtmgvomki'
      AND source_table='content_sources' AND source_key=item_id
  ) THEN
    RAISE EXCEPTION 'valid source archive fixture missing';
  END IF;
END $$;
ROLLBACK;
