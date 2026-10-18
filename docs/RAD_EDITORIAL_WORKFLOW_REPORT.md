# RAD — Editorial Workflow & Regulatory Content Report (2026-10-18)

**Scope:** Gates 16 to 21 (Epic E3: Visa, Research, Knowledge, and Feed)  
**Author:** Codex (Senior Systems & Editorial Workflow Engineer)  
**Status:** IMPLEMENTED PIPELINE — EDITORIAL REVIEW PENDING HUMAN DISPOSITION

---

## 1. Executive Summary

The RAD immigration application enforces a strict, fail-closed editorial pipeline:
`research_findings → content_drafts → human editorial review → approved feed publication`

Under no circumstances does the system permit automated AI or background research workers to publish directly to user-facing feeds (`public.feed_items`).

---

## 2. Gate Verification & Technical Status

### Gate 16: RAD Official Source Ingestion & Snapshots (`IN_PROGRESS`)
- Three official RAD sources identified:
  - `https://radvisa.com/`
  - `https://digivisa.ir/`
  - `https://radmohajer.ir/fa/`
- `supabase/functions/research-sync/index.ts` creates immutable snapshots (`source_snapshots`) storing fetch timestamps, document titles, and source URLs.
- Deduplication prevents duplicate snapshot storage for identical content hashes.

### Gate 17: Authoritative Government Sources & Conflict Handling (`IN_PROGRESS`)
- `knowledge_citations` link claims directly to government portals (`.gov`, official embassies, immigration ministries).
- The `stage2_knowledge_completion` schema introduces `review_status = 'conflicting'` for claims with contradictory legal requirements, preventing one-sided assertions.

### Gate 18: Research Finding to Human-Approved Feed Pipeline (`IMPLEMENTED`)
- **Pipeline Architecture:**
  1. `research_jobs` extract findings and insert into `research_findings` with `review_status = 'review'`.
  2. `content_drafts` map 1:1 to research findings.
  3. The `public.publish_content_draft` RPC requires:
     - Caller has role `admin` or `super_admin`.
     - Target draft has status `review` and passes explicit approval.
     - Automatically creates a linked `feed_items` row and updates draft status to `published`.
  4. Direct `INSERT` into `feed_items` by client roles is completely revoked.
- Verified in isolated PostgreSQL test suites (PR #67).

### Gate 19: Production Drafts Review Status (`BLOCKED`)
- Read-only production JOIN audit confirms:
  - **16 findings** linked 1:1 to **16 distinct drafts**.
  - **0 unmatched drafts**, **0 duplicate draft candidates**.
  - **All 16 drafts remain in review status**; **0 published feed items**.
- **Prerequisite for PASS:** A licensed human editor must inspect and approve or reject each candidate draft before publishing. Auto-approval is strictly forbidden.

### Gate 20: Bilingual Visa Catalogue (`BLOCKED`)
- Database contains 22 destinations, 10 programs, and 18 structured pathway steps.
- Bilingual Persian/English titles, descriptions, and requirements are populated in code.
- Verification of legal immigration fees and processing timelines requires editorial sign-off from licensed immigration consultants.

### Gate 21: Bilingual Search, FAQ, and Feed Usability (`IMPLEMENTED`)
- Flutter `_CountriesStage` includes real-time search filtering with clear buttons and accessible empty states (`test/features/visa/visa_navigation_presentation_test.dart`).
- `FeedPage` includes universal pull-to-refresh (`RefreshIndicator` over `AlwaysScrollableScrollPhysics`) across empty, error, and loaded states (`test/features/feed/feed_flow_resilience_test.dart`).
- Editorial feed cards prevent duplicate bookmark clicks via stateful `_saving` guard locks.

---

## 3. Editorial Governance Verdict

- The technical workflow guarantees human-in-the-loop oversight.
- The pipeline is **IMPLEMENTED** and protected by database triggers and RLS policies.
- Publishing of real production items remains safely gated on human editorial review.

