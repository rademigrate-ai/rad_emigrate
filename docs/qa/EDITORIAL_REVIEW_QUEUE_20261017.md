# RAD editorial review queue — live evidence audit, 2026-10-17

**Source:** READ-ONLY catalog queries on RAD production Supabase `inshddthftkhcdosoqcn`; parent [ONE MASTER TASK #57](https://github.com/rademigrate-ai/rad_emigrate/issues/57), E3-03/E3-04. **No draft bodies, private user data, IDs or unpublished research text are copied into this repository.**

| Check | Observed |
|---|---:|
| `research_findings` in review | 16 |
| `content_drafts` in review | 16 |
| Drafts linked to research finding | 16 |
| Findings linked to snapshot and source document | 16 |
| Source snapshots with HTTP 2xx | 16 |
| Source authority `rad_official` | 16 |
| Source documents marked removed | 0 |
| Distinct canonical source URLs | 3 |
| Drafts containing direct `source_url` | **0** |
| Drafts containing `primary_source_id` | **0** |
| Source documents with `content_sources.source_id` FK | **0** |
| Drafts previously reviewed by human `reviewed_by` | **0** |
| Drafts in Persian | 16 |
| Drafts in English | 0 |
| `feed_items` | **0** |
| Latest referenced snapshot | 2026-10-12 UTC |
| Earliest referenced snapshot | 2026-10-03 UTC |

## Interpretation and operational implications

**Pipeline existence proven:** all 16 research findings have associated review-state draft candidates and each has a captured source document/snapshot chain. This is independent of Feed, which remains empty. The existing reviewed publication RPC requires `private.has_role(['admin','super_admin'])` and is explicitly called only by a human-facing Admin action; **no AI/research auto-publish is authorized**.

**Confirmed metadata gap:** `create_research_review_candidate(uuid,uuid,text,text,text)` currently inserts only finding/job IDs, language, title, body and review status. It does **not** store a canonical source URL. Since `AdminReviewActions.loadDraftDetail` reads only `content_drafts.source_url` and `primary_source_id`, every current item lacks a direct source link in that UI even though its parent research finding has an authoritative snapshot.

**Schema distinction:** `source_documents.source_id` points to `content_sources`, **not** `research_sources`; all 16 linked source documents have a null `source_id`. Do not manufacture content-source FK IDs merely to fill a UI field.

## Exact no-mutation editorial initialization procedure

1. In a controlled Admin review session, load each of the 16 drafts and follow its `research_finding_id → research_findings.snapshot_id → source_snapshots.document_id → source_documents.canonical_url` chain. Ensure snapshot HTTP status 2xx, unchanged origin/currentness, URL scheme HTTPS and source not removed.
2. Open the official RAD canonical page and check the exact claim in context; verify if it is a commercial service claim or immigration/eligibility/fee/deadline claim requiring a current government/embassy/university source.
3. Record human-review status and corrections to the draft with provenance, language and validity date. If there is no authoritative evidence, **reject or keep in review**; never invent eligibility or processing times.
4. Populate optional `source_url` only from the actual verified document URL when safe. Do not set `primary_source_id` unless an existing, semantically matching `content_sources` row is verified. Do not bulk-publish or auto-approve.
5. Only an authorized human Admin may invoke the explicit publish action after reviewing the content and citations. Verify Feed content provenance and live access after publication.

## Acceptance

E3-03 **pipeline source-to-review linkage existence**: observed 16/16.  
E3-04 **editorial truth, approval and publication**: **OPEN** — all 16 require independent human editorial decisions.  
Code enhancement to surface the already-existing snapshot provenance in Admin is a separate proposed fix, not evidence of review acceptance.
