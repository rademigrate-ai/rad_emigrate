# RAD EMIGRATE — PLAN 4 INTEGRATION HANDOFF
## Research Assistant, CMS Review Pipeline, Source Diff & User Change Highlight System

**Execution Date:** 2026-10-24  
**Author / Lead:** Antigravity (Principal Frontend/Integration Engineer & Architecture Gatekeeper)  
**Branch:** `feat/plan4-research-cms-20261024`  
**PR:** https://github.com/rademigrate-ai/rad_emigrate/pull/81 (Draft PR #81)  
**Base Commit SHA:** `16810a583ad4544d87f289bd16984c0e758a1515` (`origin/main`)  
**Delivered Final HEAD SHA:** `aa3b9ba5a1c96e611a75ab4fa68b116d70610bd2`  
**Verified GitHub CI Run:** Run 40118892566 (All 7/7 jobs succeeded) & Run 40119933729  
**Canonical Contract Registry:** `supabase/contracts/rad_v1.json`  

---

### 1. Executive Summary & Purpose

This handoff document provides cross-agent integration specifications for merging Plan 4 into the upcoming unified release candidate. It synthesizes architectural boundaries, cross-plan compatibility verification (with Codex Plan 3 PR #80, Grok Plan 5 PR #79, and Grok Plan 2 PR #78), shared-file conflict assessments, and unresolved backend staging requirements.

---

### 2. Delivered Plan 4 Scope & Architecture

Plan 4 implements the complete human-controlled editorial governance lifecycle, structured section diff engine, official authority monitoring, and public transparency change highlights banner:

1. **Human-Controlled CMS Review Lifecycle**:
   - `submit_visa_article_review`: Transitions `draft` -> `in_review`.
   - `approve_visa_article_revision`: Transitions `in_review` -> `approved`.
   - `reject_visa_article_revision`: Transitions `in_review` -> `rejected` (enforces non-empty rejection reason).
   - `publish_visa_article_revision`: Transitions `approved` -> `published` (or updates existing published head).
   - `rollback_visa_article`: Forward-rolling recovery revision with mandatory audit reason.
   - `list_visa_article_revisions`: Complete chronological audit trail with SHA-256 hashes, states, and actors.
   - Zero Autonomous AI Publishing: AI research proposals enter strictly as unapproved drafts (`editorial_state = 'draft'`).

2. **Structured Section Diff Engine**:
   - Section-by-section comparison (`add`, `replace`, `remove`) with block-level hashes.
   - Explicit isolation between raw source modifications and proposed editorial adaptations.
   - Evidence Inspector linking quotes, domain trust roots, canonical URLs, and freshness timestamps.
   - Raw JSON fail-safe fallback tab.

3. **Official Authority Monitor & Crawl Queueing**:
   - Dual-tab view: Research Proposals vs. Official Authorities.
   - Authority management across government, embassy, university, regulator, accreditor bodies.
   - On-demand crawl refresh queueing (`enqueue_research_refresh`).

4. **Public User Change Highlights Banner**:
   - Renders fact-checked freshness dates, primary government authority attribution, and direct legal citations.
   - Strict public projection: reads exclusively from `editorial_state = 'published' AND is_active = true`. Zero leakage of draft, review, or worker scratchpad data.

---

### 3. Cross-Plan Compatibility & Dependency Review

#### A. Codex Plan 3 (PR #80 — `feat/plan3-visa-content-library-20261024`)
- **Status:** Draft PR #80, HEAD `18900fecda36ff0ca23e7b204a4ecae20340879a`.
- **Review Findings (Read-Only):**
  - Reconstructed Visa article library from RAD websites (`radvisa.com`, `digivisa.ir`, `radmohajer.ir`).
  - Extracted 1,083 substantive source bodies, 830 exact-deduplicated canonical drafts, and 575 technically importable unapproved CMS drafts in `artifacts/RAD_PLAN3_VISA_CONTENT_20261024/`.
  - Preserved 6 existing production document IDs.
  - Zero autonomous publication: `Verified legal claims / human-approved / publication-ready: 0 / 0 / 0`. All content enters as unapproved drafts.
  - Source provenance and evidence manifest: Complete citation manifest in `09_CITATION_AND_EVIDENCE_MANIFEST.json`.
- **Plan 4 Alignment:**
  - Plan 4's CMS Canonical Editor and Source Diff Engine directly accept Plan 3's draft schema (`canonical_id`, `source_ids`, `body_sha256`, `structured_blocks`).
  - When Plan 3 drafts are imported into staging, they enter with `editorial_state = 'draft'`. Human editors will use Plan 4's UI to review, approve, and publish each article individually.
  - **Conflict Analysis:** Codex Plan 3 touched `.gitattributes`, `.github/workflows/ci.yml`, `requirements-plan3.txt`, `scripts/tests/test_plan3_content.py`, and `tools/plan3_content/`. PR #80 touched **ZERO Dart files** in `lib/` or `test/`. Conflict probability with Plan 4 Dart code is **0%**.

#### B. Grok Plan 5 (PR #79 — `feat/plan5-rad-ai2-finalization-20261024`)
- **Status:** Draft PR #79, HEAD `3a67eb4`.
- **Review Findings (Read-Only):**
  - AI model catalog ingest hardened to fail closed (`enabled = false` default).
  - Runtime chain filters on `enabled` models; owner-scoped access decision.
  - Authorization boundary tests in `test/ai_assistant/plan5_ai_authorization_boundaries_test.dart` prove role isolation across anonymous, authenticated user, and admin.
- **Plan 4 Alignment:**
  - Strict grounding boundary: Grok Plan 5 AI Assistant only grounds against published, active pathways. Plan 4 guarantees that unapproved drafts and in-review revisions are completely inaccessible to non-admin reader projections.
  - **Conflict Analysis:** Grok Plan 5 modified `lib/core/services/ai/supabase_ai_service.dart`, `lib/l10n/`, and `supabase/tests/plan5_*`. None of these files overlap with Plan 4's CMS repository, admin presentation pages, or Visa change highlights banner. Conflict probability is **0%**.

#### C. Grok Plan 2 (PR #78 — `feat/plan2-backend-security-20261024`)
- **Status:** Draft PR #78.
- **Review Findings (Read-Only):**
  - Added booking/interview request RPC contracts and H01 privilege hardening in `supabase/migrations/20261024140000*` and `supabase/tests/plan2*`.
- **Plan 4 Alignment:**
  - Plan 2 touches solely backend migrations and SQL tests.
  - **Conflict Analysis:** Completely disjoint file set. Conflict probability is **0%**.

---

### 4. Shared-File Conflict Ledger

| File | Plan 4 (`feat/plan4`) | Codex Plan 3 (`feat/plan3`) | Grok Plan 5 (`feat/plan5`) | Merge Strategy / Assessment |
| :--- | :---: | :---: | :---: | :--- |
| `lib/core/supabase/rad_contract_schemas.dart` | Added 20 Plan 4 RPC schemas | Untouched | Untouched | Clean merge (Plan 4 sole modifier) |
| `scripts/generate_dart_contracts.py` | Registered Plan 4 schemas | Untouched | Untouched | Clean merge (Plan 4 sole modifier) |
| `lib/features/admin/...` | Modified 4 CMS pages & repository | Untouched | Untouched | Clean merge (Plan 4 sole modifier) |
| `lib/features/visa/presentation/widgets/article_change_highlights_banner.dart` | Added new component | Untouched | Untouched | Clean merge (Plan 4 sole modifier) |
| `lib/features/visa/presentation/pages/canonical_pathway_page.dart` | Added banner import & placement | Untouched | Untouched | Clean merge (Plan 4 sole modifier) |
| `.github/workflows/ci.yml` | Untouched | Added pytest step | Added clean-schema step | Trivial additive merge |
| `lib/l10n/app_*.arb` | Untouched | Untouched | Added AI assistant strings | Clean merge (Grok sole modifier) |

---

### 5. Server-Side Security & Invariant Verification

1. **Admin Authorization Gate**:
   - `private.rad_article_mutate()` executes `perform private.rad_require_admin();` before processing any mutation.
   - All workflow tables (`visa_articles`, `visa_article_revisions`, `visa_article_heads`, `visa_research_proposals`, etc.) have RLS enabled and direct access revoked from `public`, `anon`, `authenticated`, and `service_role`.
   - Admin access is granted strictly through authenticated RPCs with verified admin JWT claims.

2. **Deterministic State Machine**:
   - `draft` -> `in_review` (via `submit_visa_article_review`)
   - `in_review` -> `approved` or `rejected` (via `approve_visa_article_revision` / `reject_visa_article_revision`)
   - `approved` -> `published` (via `publish_visa_article_revision`)
   - Arbitrary state jumps (e.g. `draft` -> `published`) trigger PostgreSQL exception `invalid_editorial_transition` (`PT409`), mapped to `CmsException('conflict')`.

3. **Concurrency & Rollback Safety**:
   - All mutations enforce optimistic locking via `expected_revision` and `content_hash`.
   - Concurrency conflicts trigger `PT409`, caught by `SupabaseAdminCmsRepository` as `CmsException('conflict')`.
   - Rollback operations create forward audit revisions rather than rewriting table history.

---

### 6. Unresolved Backend Requirements & Hosted Staging Preflight

> [!IMPORTANT]
> The hosted production Supabase instance (`inshddthftkhcdosoqcn`) has NOT yet had the Plan 4 or Plan 2 migrations applied. Do NOT claim production RPC availability until the following preflight steps are executed in staging:

1. **Staging Migration Application**:
   - Ensure migration `20261019205040_rad_visa_cms_official_evidence.sql` and `20261020103648_rad_backend_integrity_completion.sql` are applied on the hosted target.
   - Verify `private.rad_contract_schemas` contains all 20 Plan 4 contract definitions.
2. **Admin User Entitlement**:
   - Verify administrative user accounts have `app_metadata -> role = 'admin'` configured in `auth.users`.
3. **Crawl Queue Worker**:
   - In production, `enqueue_research_refresh` writes job rows to `private.rad_research_jobs`. The background research worker edge function must be scheduled to process these queued jobs.

---

### 7. Certification & Delivery Status

| Verification Axis | Result | Notes |
| :--- | :---: | :--- |
| **`dart analyze`** | **PASS** | 0 errors, 0 warnings, 0 infos |
| **`dart format --set-exit-if-changed .`** | **PASS** | 0 files changed (100% compliant) |
| **Repository Test Suite** | **PASS** | 1,032 / 1,032 tests passing |
| **Plan 4 Dedicated Tests** | **PASS** | 38 / 38 unit & widget tests passing |
| **Flutter Web Release Build** | **PASS** | Successful release compilation |
| **GitHub Actions CI** | **GREEN** | PR #81 Run 40118892566 (7/7 jobs passed) |
| **PR Branch Status** | **DRAFT PR #81** | `feat/plan4-research-cms-20261024` -> `main` |
