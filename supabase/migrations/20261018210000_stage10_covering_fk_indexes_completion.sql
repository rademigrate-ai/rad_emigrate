-- Stage 10: Complete B-tree covering indexes for remaining uncovered foreign keys.
-- Resolves Supabase advisor 0001_unindexed_foreign_keys for knowledge_claims and consultation_requests.
-- Uses conditional execution to ensure safe forward-only migration.

DO $stage10_fk$
BEGIN
  -- 1. knowledge_claims.superseded_by -> knowledge_claims.id
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'knowledge_claims' AND column_name = 'superseded_by'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS knowledge_claims_superseded_by_idx ON public.knowledge_claims (superseded_by) WHERE superseded_by IS NOT NULL';
  END IF;

  -- 2. consultation_requests.assigned_to -> auth.users.id
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'consultation_requests' AND column_name = 'assigned_to'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS consultation_requests_assigned_to_idx ON public.consultation_requests (assigned_to) WHERE assigned_to IS NOT NULL';
  END IF;

  -- 3. consultation_requests.related_application_id -> applications.id
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'consultation_requests' AND column_name = 'related_application_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS consultation_requests_related_application_id_idx ON public.consultation_requests (related_application_id) WHERE related_application_id IS NOT NULL';
  END IF;
END $stage10_fk$;

