-- G-002/C-002 content architecture scaffolding (additive, forward-only)
-- Source: C002_G002 schema alignment + MASTER implementation draft
-- NOT applied to production by this commit; requires authorized staging/disposable apply first.

-- 1. knowledge_items: article_role + canonical_key
ALTER TABLE public.knowledge_items
  ADD COLUMN IF NOT EXISTS article_role text,
  ADD COLUMN IF NOT EXISTS canonical_key text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'knowledge_items_article_role_check'
  ) THEN
    ALTER TABLE public.knowledge_items
      ADD CONSTRAINT knowledge_items_article_role_check
      CHECK (article_role IS NULL OR article_role IN ('main', 'related'));
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS knowledge_items_main_canonical_key_uidx
  ON public.knowledge_items (canonical_key)
  WHERE article_role = 'main' AND canonical_key IS NOT NULL;

COMMENT ON COLUMN public.knowledge_items.article_role IS
  'G-002: main = canonical merged RadVisa+DigiVisa subject; related = independent. RadMohajer must only be related.';
COMMENT ON COLUMN public.knowledge_items.canonical_key IS
  'G-002: country_iso:pathway for main articles only (e.g. GB:study).';

-- 2. knowledge_claims: factual_status (six values) + human_review_required
ALTER TABLE public.knowledge_claims
  ADD COLUMN IF NOT EXISTS factual_status text NOT NULL DEFAULT 'unverified',
  ADD COLUMN IF NOT EXISTS human_review_required boolean NOT NULL DEFAULT true;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'knowledge_claims_factual_status_check'
  ) THEN
    ALTER TABLE public.knowledge_claims
      ADD CONSTRAINT knowledge_claims_factual_status_check
      CHECK (factual_status IN (
        'verified', 'incorrect', 'incomplete', 'outdated', 'conflicting', 'unverified'
      ));
  END IF;
END $$;

COMMENT ON COLUMN public.knowledge_claims.factual_status IS
  'G-002 six-status claim classification. Default unverified. verified requires validated authority evidence.';

-- 3. source_documents: authority validation fields
ALTER TABLE public.source_documents
  ADD COLUMN IF NOT EXISTS validation_status text,
  ADD COLUMN IF NOT EXISTS authority_category text,
  ADD COLUMN IF NOT EXISTS verified_domain text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'source_documents_validation_status_check'
  ) THEN
    ALTER TABLE public.source_documents
      ADD CONSTRAINT source_documents_validation_status_check
      CHECK (validation_status IS NULL OR validation_status IN (
        'candidate', 'validated', 'rejected', 'inaccessible'
      ));
  END IF;
END $$;

-- 4. source_snapshots: freshness metadata
ALTER TABLE public.source_snapshots
  ADD COLUMN IF NOT EXISTS publication_date date,
  ADD COLUMN IF NOT EXISTS effective_date date,
  ADD COLUMN IF NOT EXISTS confidence_notes text;

-- 5. research_proposals (never auto-publishes)
CREATE TABLE IF NOT EXISTS public.research_proposals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id uuid,
  coverage_key text,
  reason text NOT NULL,
  priority integer NOT NULL DEFAULT 50,
  suggested_actions jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_progress', 'resolved', 'dismissed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  created_by uuid
);

CREATE INDEX IF NOT EXISTS research_proposals_status_idx
  ON public.research_proposals (status, priority);

ALTER TABLE public.research_proposals ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.research_proposals FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.research_proposals TO authenticated;
GRANT ALL ON TABLE public.research_proposals TO service_role;

DROP POLICY IF EXISTS research_proposals_admin_all ON public.research_proposals;
CREATE POLICY research_proposals_admin_all ON public.research_proposals
  FOR ALL TO authenticated
  USING (private.has_role(ARRAY['admin', 'super_admin']))
  WITH CHECK (private.has_role(ARRAY['admin', 'super_admin']));

COMMENT ON TABLE public.research_proposals IS
  'G-002 research queue. Never writes public knowledge or Feed. Admin-only RLS.';
