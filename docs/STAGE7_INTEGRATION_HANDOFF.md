# Stage 7 unified integration

This branch preserves backend PR82 `7fe6710212b7d82cff2738f21f5d44dac49827d8`, frontend PR83 `94db36e6f1767646cbdcfb044c6628441b0c591a`, Research PR84 `074dfd7bed6f344884ee1fc4f9565f039c033daa`, and content consolidation `8a090c5387aba51c4677743a4885c8a7bb890d2a` through ancestry. It does not replace peer worktrees or authorize publication or deployment.

## Semantic conflict decisions

- Canonical page retains identity deduplication, UUID navigation and one localized Other Titles section.
- Verification banner retains honest missing-date/source states; an unverified body is not described as legally verified or human approved.
- Legacy independent reader retains the published-only slug resolver and the closed v1 `article_id` selector. PR84's unsupported `id` selector is not used.

## Additive Research contracts

`supabase/contracts/stage7_research_requests.json` specifies new requests without changing closed v1 schemas. `get_research_review_context(p_proposal_id uuid)` returns the exact immutable proposal baseline, full body, locale, revision UUID/hash, optional original rich sections, stale-head flag and saved review decisions/version. Baseline failure is an error, never generated immigration text.

`save_research_review(p_request jsonb)` accepts expected proposal/review versions, base revision/hash, UUID request key, mode, explicit section decisions and note. Modes: `save_review`, `create_draft`, `reject_proposal`. Accepted manual edits are single paragraph text only. The server reconstructs from the full baseline, validates source snapshot excerpts and section hashes, preserves unchanged/rejected content and requires an explicit decision for every change. Partial review is resumable. Exact retries return the prior receipt; changed payload under the same key, stale revisions or baseline hashes conflict. No caller-supplied whole replacement body is accepted.

Proposal approval creates an **unpublished, unverified draft**, not an approved article. Article review, approval and publication remain distinct existing human Admin operations. Research/service-role/ordinary users cannot call the human review mutation. Private review history is append-only and has no direct client privileges. Client repositories and page state are bound to their authenticated owner across awaits/logout.

`upsert_editorial_research_source(p_request jsonb)` supports government, embassy, university, professional_body and admin_reference, with optional country/category. Legacy storage mapping is preserved; new editorial type round-trips through a nullable column. New sources are disabled, admin-defined and Admin-scope. HTTPS validation, closed schema and UUID idempotency prevent trust-field injection and unsafe URL input. No official verification is inferred from the source class or retrieval date.

## Hosted migration HOLD

The owner requires review before any further hosted migration request. Staging `epolbumcfbohtmgvomki` has **not** received the Stage7 migration. One connector request failed with invalid requestState and the next was declined. Read-only checks show no Stage7 objects/ledger entry. Do not bypass this hold through SQL, CLI or another tool.

The revised migration is additive: no DROP TRIGGER, no existing function replacement, no contract-schema upsert, no article-data DML. Security REVOKEs target newly created objects only. Object-name collisions abort; do not repair history or force replay. Lock and statement limits bound contention. Unrelated index additions were deferred.

Review package: project `_audit/RAD_STAGE7_20261026/migration_review/`, including exact SQL, original submitted SQL, dependency/preflight receipts, risks, rollback and owner checklist. Local populated additive tests are not a hosted backup/restore rehearsal. Fresh backup/recovery evidence and explicit authorization are required before application.

## Known integration limitation

Imported articles have richer structures than their closed v1 projection. Research body changes on such revisions fail closed with `rich_body_reconciliation_required`, preventing silent loss of tables/nested lists. The original rich body can be inspected and review decisions saved. A reviewed rich patch/provenance reconciliation contract is still required before those body changes can create a CMS draft. Do not describe this safeguard as complete imported-content Research editing. Existing real content remains unapproved/unpublished.

Because the new RPCs/column are absent, real authenticated Stage7 Research E2E is blocked. Public readers, existing CMS read paths and other independent contracts can still be tested. Mocked/native tests do not count as real Auth/browser E2E. Production remains NO-GO; Staging Engineering cannot be GO while these required gates remain incomplete.

## Regression coverage

- `supabase/tests/stage7_research_review.sql`: full unchanged body, granular edit/reject/add/remove, explicit decisions, exact retries, stale versions/hashes, source mapping/URL/trust boundaries, ordinary/forged-metadata denial, rich-body fail-closed behavior, private ACLs and public draft isolation.
- `test/admin/research_review_repository_test.dart`: UUID retry stability, granular payload, late response rejection after logout, malformed baseline and safe conflict errors.
- `test/admin/research_comparison_safety_test.dart`: phone/tablet/desktop layout, all citations, manual edit display, no invented approval or verification labels.
- Existing canonical/content reader, CMS, booking, isolation and security regressions remain required.

Final build/test/CI receipts are stored outside the Git worktree under the Stage7 evidence directory, tagged with the exact source SHA and dirty-tree status. Earlier successful content-phase results are not reused as Stage7 certification.
