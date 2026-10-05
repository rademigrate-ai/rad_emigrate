-- Stage 3: additive covering indexes for unindexed foreign keys that
-- participate in admin joins, cascade checks, or research/visa review flows.
-- Intentionally selective: do not index every advisor suggestion blindly.
-- Prefer CONCURRENTLY-compatible simple CREATE INDEX (migration runner is
-- transactional; concurrent create is not used here).

-- Admin audit actor lookups
CREATE INDEX IF NOT EXISTS admin_audit_logs_actor_id_idx
  ON public.admin_audit_logs (actor_id);

-- Application status history actor
CREATE INDEX IF NOT EXISTS application_status_history_changed_by_idx
  ON public.application_status_history (changed_by);

-- Content drafts join/filter columns used by review queue
CREATE INDEX IF NOT EXISTS content_drafts_created_by_idx
  ON public.content_drafts (created_by);
CREATE INDEX IF NOT EXISTS content_drafts_reviewed_by_idx
  ON public.content_drafts (reviewed_by);
CREATE INDEX IF NOT EXISTS content_drafts_knowledge_item_id_idx
  ON public.content_drafts (knowledge_item_id)
  WHERE knowledge_item_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS content_drafts_research_finding_id_idx
  ON public.content_drafts (research_finding_id)
  WHERE research_finding_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS content_drafts_research_job_id_idx
  ON public.content_drafts (research_job_id)
  WHERE research_job_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS content_drafts_primary_source_id_idx
  ON public.content_drafts (primary_source_id)
  WHERE primary_source_id IS NOT NULL;

-- Destinations author/reviewer
CREATE INDEX IF NOT EXISTS destinations_created_by_idx
  ON public.destinations (created_by)
  WHERE created_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS destinations_reviewed_by_idx
  ON public.destinations (reviewed_by)
  WHERE reviewed_by IS NOT NULL;

-- Knowledge graph join keys
CREATE INDEX IF NOT EXISTS knowledge_citations_snapshot_id_idx
  ON public.knowledge_citations (snapshot_id)
  WHERE snapshot_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS knowledge_conflicts_citation_a_id_idx
  ON public.knowledge_conflicts (citation_a_id);
CREATE INDEX IF NOT EXISTS knowledge_conflicts_citation_b_id_idx
  ON public.knowledge_conflicts (citation_b_id);
CREATE INDEX IF NOT EXISTS knowledge_conflicts_resolved_by_idx
  ON public.knowledge_conflicts (resolved_by)
  WHERE resolved_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS knowledge_items_created_by_idx
  ON public.knowledge_items (created_by)
  WHERE created_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS knowledge_items_reviewed_by_idx
  ON public.knowledge_items (reviewed_by)
  WHERE reviewed_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS knowledge_versions_changed_by_idx
  ON public.knowledge_versions (changed_by)
  WHERE changed_by IS NOT NULL;

-- Research pipeline joins
CREATE INDEX IF NOT EXISTS research_findings_research_job_id_idx
  ON public.research_findings (research_job_id);
CREATE INDEX IF NOT EXISTS research_findings_snapshot_id_idx
  ON public.research_findings (snapshot_id)
  WHERE snapshot_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS research_jobs_requested_by_idx
  ON public.research_jobs (requested_by)
  WHERE requested_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS source_documents_source_id_idx
  ON public.source_documents (source_id);

-- Visa catalog FKs used by published reads and admin filters
CREATE INDEX IF NOT EXISTS visa_program_requirements_source_id_idx
  ON public.visa_program_requirements (source_id);
CREATE INDEX IF NOT EXISTS visa_program_steps_source_id_idx
  ON public.visa_program_steps (source_id)
  WHERE source_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS visa_programs_category_id_idx
  ON public.visa_programs (category_id);
CREATE INDEX IF NOT EXISTS visa_programs_primary_source_id_idx
  ON public.visa_programs (primary_source_id);
CREATE INDEX IF NOT EXISTS visa_programs_created_by_idx
  ON public.visa_programs (created_by)
  WHERE created_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS visa_programs_reviewed_by_idx
  ON public.visa_programs (reviewed_by)
  WHERE reviewed_by IS NOT NULL;
