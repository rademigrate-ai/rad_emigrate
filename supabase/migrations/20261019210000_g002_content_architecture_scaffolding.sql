-- Forward-only additive migration: G-002 / C-002 content architecture scaffolding
-- Date: 2026-10-19
-- Branch: feature/g002-c002-implementation-20261019
-- Rules: additive only; no destructive drops of live data;
-- does NOT populate production content; does NOT change Feed publish path;
-- does NOT apply automatically to production.

BEGIN;

ALTER TABLE public.knowledge_items
  ADD COLUMN IF NOT EXISTS article_role text NOT NULL DEFAULT 'related',
  ADD COLUMN IF NOT EXISTS canonical_key text;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'knowledge_items_article_role_check'
  ) THEN
    ALTER TABLE public.knowledge_items
      ADD CONSTRAINT knowledge_items_article_role_check
      CHECK (article_role IN ('main', 'related'));
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS knowledge_items_main_canonical_uidx
  ON public.knowledge_items (canonical_key)
  WHERE article_role = 'main' AND canonical_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS knowledge_items_canonical_key_idx
  ON public.knowledge_items (canonical_key)
  WHERE canonical_key IS NOT NULL;

COMMENT ON COLUMN public.knowledge_items.article_role IS
  'main = canonical merged RadVisa+DigiVisa article; related = independent related article (incl. RadMohajer)';
COMMENT ON COLUMN public.knowledge_items.canonical_key IS
  'Stable key country_iso:pathway for main articles; optional for related';

ALTER TABLE public.knowledge_claims
  ADD COLUMN IF NOT EXISTS factual_status text NOT NULL DEFAULT 'unverified',
  ADD COLUMN IF NOT EXISTS human_review_required boolean NOT NULL DEFAULT true;

DO $$ BEGIN
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

CREATE INDEX IF NOT EXISTS knowledge_claims_factual_status_idx
  ON public.knowledge_claims (factual_status)
  WHERE is_current IS TRUE;

COMMENT ON COLUMN public.knowledge_claims.factual_status IS
  'G-002 factual verification status; independent of editorial review_status';
COMMENT ON COLUMN public.knowledge_claims.human_review_required IS
  'True when claim requires human review before editorial approval or public use';

ALTER TABLE public.source_documents
  ADD COLUMN IF NOT EXISTS validation_status text NOT NULL DEFAULT 'candidate',
  ADD COLUMN IF NOT EXISTS verified_domain text,
  ADD COLUMN IF NOT EXISTS authority_category text;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'source_documents_validation_status_check'
  ) THEN
    ALTER TABLE public.source_documents
      ADD CONSTRAINT source_documents_validation_status_check
      CHECK (validation_status IN ('candidate', 'validated', 'rejected', 'inaccessible'));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'source_documents_authority_category_check'
  ) THEN
    ALTER TABLE public.source_documents
      ADD CONSTRAINT source_documents_authority_category_check
      CHECK (
        authority_category IS NULL OR authority_category IN (
          'government_immigration',
          'embassy_consulate',
          'education_ministry',
          'university',
          'professional_regulator',
          'credential_evaluator',
          'accreditation_org',
          'rad_official',
          'other'
        )
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS source_documents_validation_idx
  ON public.source_documents (validation_status, source_authority);

COMMENT ON COLUMN public.source_documents.validation_status IS
  'G-002: only validated authorities may supply evidence for factual verified claims';
COMMENT ON COLUMN public.source_documents.authority_category IS
  'Finer-grained category; complements legacy source_authority enum';

ALTER TABLE public.source_snapshots
  ADD COLUMN IF NOT EXISTS publication_date date,
  ADD COLUMN IF NOT EXISTS effective_date date,
  ADD COLUMN IF NOT EXISTS confidence_notes text;

COMMENT ON COLUMN public.source_snapshots.publication_date IS
  'Official page publication or last-updated date when known';
COMMENT ON COLUMN public.source_snapshots.effective_date IS
  'Rule effective-from date when the official source distinguishes it';

CREATE TABLE IF NOT EXISTS public.research_proposals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id uuid REFERENCES public.knowledge_claims(id) ON DELETE SET NULL,
  knowledge_item_id uuid REFERENCES public.knowledge_items(id) ON DELETE SET NULL,
  coverage_key text,
  reason text NOT NULL,
  priority integer NOT NULL DEFAULT 50,
  suggested_actions jsonb NOT NULL DEFAULT '[]'::jsonb,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_progress', 'resolved', 'dismissed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS research_proposals_status_idx
  ON public.research_proposals (status, priority, created_at DESC);

ALTER TABLE public.research_proposals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admins manage research proposals" ON public.research_proposals;
CREATE POLICY "admins manage research proposals"
  ON public.research_proposals
  FOR ALL TO authenticated
  USING (private.has_role(ARRAY['admin', 'super_admin']))
  WITH CHECK (private.has_role(ARRAY['admin', 'super_admin']));

COMMENT ON TABLE public.research_proposals IS
  'G-002 research proposal queue; never writes public content or Feed automatically';

COMMIT;