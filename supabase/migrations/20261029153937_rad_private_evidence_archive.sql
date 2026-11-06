-- Preserve Staging source-evidence rows as immutable, private JSONB.
-- This is NOT a publication path and does not touch Production Auth or articles.
BEGIN;
CREATE TABLE private.rad_evidence_import_archive (
  source_project_ref text NOT NULL
    CHECK (source_project_ref IN ('epolbumcfbohtmgvomki', 'kojogjkasconksifxkdg')),
  source_table text NOT NULL
    CHECK (source_table IN ('content_sources', 'source_documents', 'source_snapshots')),
  source_key text NOT NULL CHECK (length(source_key) BETWEEN 1 AND 128),
  payload jsonb NOT NULL
    CHECK (jsonb_typeof(payload) = 'object' AND payload ? 'id' AND payload->>'id' = source_key),
  payload_sha256 text NOT NULL
    CHECK (
      payload_sha256 ~ '^[0-9a-f]{64}$'
      -- Bind the extension schema explicitly during clean reconstruction.
      -- Existing hosted CHECK expressions already retain their function OID.
      AND payload_sha256 = encode(extensions.digest(payload::text, 'sha256'), 'hex')
    ),
  archived_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (source_project_ref, source_table, source_key)
);
ALTER TABLE private.rad_evidence_import_archive ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.rad_evidence_import_archive
  FROM PUBLIC, anon, authenticated, service_role;
COMMENT ON TABLE private.rad_evidence_import_archive IS
  'Quarantined, byte-checked source evidence from nonproduction projects. No client access, automatic publication or Auth identity remapping. Release requires independent provenance review.';
COMMIT;
