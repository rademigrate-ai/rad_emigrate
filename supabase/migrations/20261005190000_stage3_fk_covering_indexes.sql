-- Stage 3: additive covering indexes for unindexed foreign keys.
-- Column-safe via dynamic EXECUTE so reconstruction of the historical
-- candidate lineage remains valid before Stage 1/2 additive migrations
-- introduce columns that may not yet exist.

DO $stage3_fk$
BEGIN
  -- Admin audit actor lookups
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'admin_audit_logs' AND column_name = 'actor_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS admin_audit_logs_actor_id_idx ON public.admin_audit_logs (actor_id)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'application_status_history' AND column_name = 'changed_by'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS application_status_history_changed_by_idx ON public.application_status_history (changed_by)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'content_drafts' AND column_name = 'created_by'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS content_drafts_created_by_idx ON public.content_drafts (created_by)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'content_drafts' AND column_name = 'reviewed_by'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS content_drafts_reviewed_by_idx ON public.content_drafts (reviewed_by)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'content_drafts' AND column_name = 'knowledge_item_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS content_drafts_knowledge_item_id_idx ON public.content_drafts (knowledge_item_id) WHERE knowledge_item_id IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'content_drafts' AND column_name = 'research_finding_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS content_drafts_research_finding_id_idx ON public.content_drafts (research_finding_id) WHERE research_finding_id IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'content_drafts' AND column_name = 'research_job_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS content_drafts_research_job_id_idx ON public.content_drafts (research_job_id) WHERE research_job_id IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'content_drafts' AND column_name = 'primary_source_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS content_drafts_primary_source_id_idx ON public.content_drafts (primary_source_id) WHERE primary_source_id IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'destinations' AND column_name = 'created_by'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS destinations_created_by_idx ON public.destinations (created_by) WHERE created_by IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'destinations' AND column_name = 'reviewed_by'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS destinations_reviewed_by_idx ON public.destinations (reviewed_by) WHERE reviewed_by IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'knowledge_citations' AND column_name = 'snapshot_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS knowledge_citations_snapshot_id_idx ON public.knowledge_citations (snapshot_id) WHERE snapshot_id IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'knowledge_conflicts' AND column_name = 'citation_a_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS knowledge_conflicts_citation_a_id_idx ON public.knowledge_conflicts (citation_a_id)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'knowledge_conflicts' AND column_name = 'citation_b_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS knowledge_conflicts_citation_b_id_idx ON public.knowledge_conflicts (citation_b_id)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'knowledge_conflicts' AND column_name = 'resolved_by'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS knowledge_conflicts_resolved_by_idx ON public.knowledge_conflicts (resolved_by) WHERE resolved_by IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'knowledge_items' AND column_name = 'created_by'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS knowledge_items_created_by_idx ON public.knowledge_items (created_by) WHERE created_by IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'knowledge_items' AND column_name = 'reviewed_by'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS knowledge_items_reviewed_by_idx ON public.knowledge_items (reviewed_by) WHERE reviewed_by IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'knowledge_versions' AND column_name = 'changed_by'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS knowledge_versions_changed_by_idx ON public.knowledge_versions (changed_by) WHERE changed_by IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'research_findings' AND column_name = 'research_job_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS research_findings_research_job_id_idx ON public.research_findings (research_job_id)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'research_findings' AND column_name = 'snapshot_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS research_findings_snapshot_id_idx ON public.research_findings (snapshot_id) WHERE snapshot_id IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'research_jobs' AND column_name = 'requested_by'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS research_jobs_requested_by_idx ON public.research_jobs (requested_by) WHERE requested_by IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'source_documents' AND column_name = 'source_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS source_documents_source_id_idx ON public.source_documents (source_id)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'visa_program_requirements' AND column_name = 'source_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS visa_program_requirements_source_id_idx ON public.visa_program_requirements (source_id)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'visa_program_steps' AND column_name = 'source_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS visa_program_steps_source_id_idx ON public.visa_program_steps (source_id) WHERE source_id IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'visa_programs' AND column_name = 'category_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS visa_programs_category_id_idx ON public.visa_programs (category_id)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'visa_programs' AND column_name = 'primary_source_id'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS visa_programs_primary_source_id_idx ON public.visa_programs (primary_source_id)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'visa_programs' AND column_name = 'created_by'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS visa_programs_created_by_idx ON public.visa_programs (created_by) WHERE created_by IS NOT NULL';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'visa_programs' AND column_name = 'reviewed_by'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS visa_programs_reviewed_by_idx ON public.visa_programs (reviewed_by) WHERE reviewed_by IS NOT NULL';
  END IF;
END
$stage3_fk$;
