# Codex Phase 2 / Phase 4 execution record

Client date: 2026-10-19. New mission supersedes the earlier final-push workflow. No push, PR, merge, external deployment or production write is authorized. Do not access other agents' worktrees or modify Flutter presentation/Grok AI/domain code.

The requested RC `2e0d089781ef3de582143421a59817094e57ca78` is available. The earlier backend branch and RC share actual ancestor `0ef8e6d6bf433db3bb4c104d015c0f85cca0d96d`; neither branch is invented as the other's ancestor. The RC already contains most earlier tested backend checkpoints and newer verification fixes. A new isolated branch, `feat/codex-phase2-phase4-final-20261019`, starts directly from the requested RC at `rad_codex_phase2_phase4_20261019`. No other-agent commit was merged or cherry-picked. Preserve the old Codex worktree/commits as historical evidence; Freebuff should consume only the new branch's delta from the requested RC.

## Current Phase 2 work

Confirmed defect: the prior staging guide explicitly used the production API and the build accepted it with a staging label. Added a fail-closed staging configuration guard for API/ref/site/public-key binding, backend database/legacy service-key claims and ambiguous aliases/fallbacks. The Render build invokes it before dependency/Flutter commands. Replaced the unsafe guide with blank owner-supplied templates. A plan-only tool records immutable source/migration hashes and target-bound commands without executing cloud operations or persisting credentials.

Verification so far: **16 staging/plan unit tests PASS** (including grouped malicious/negative cases). An actual shell build invocation labelled staging and pointed at production exited **2**, `production_project_forbidden`, before Flutter. No public or backend real staging credentials are available. Activation, hosted backup/restore and actual staging smoke remain **BLOCKED_BY_OWNER**. See [staging procedure](STAGING_DEPLOYMENT_AND_ROLLBACK.md).

Remaining locally executable work includes final RC-based disposable replay/security/Auth/Storage/Edge checks, confirmed-email local signup coverage, initialization contracts, secret-finding classification and the final exact-HEAD evidence inventory. Existing earlier 57-file clean proof and 58-file proposal checks remain historical evidence, not an invented final RC-based pass.

First new integration-ready commit: `fc7c535` (staging guard/templates/plan). Local runtime reservation: project `rad_codex_phase24_20261019`, canonical ports 58320–58329 and historical ports 59320–59329. These are Docker test identifiers, not fabricated hosted Supabase project refs. Only this branch's dedicated marked runtimes may be started/reset. Signup-confirmation support is being added to the local harness; old default autoconfirm evidence will not be relabelled as confirmed signup.

## Current Phase 4 work

The RC contains the disabled-by-default synthetic signed-payment protocol, sandbox subscription ordering/deduplication/terminal states, CRM optimistic revisions/history and sandbox outbox leases/retries. Those checkpoints have earlier local SQL/HTTP/concurrency evidence. They do not establish payment creation or a real merchant, hosted notification transport or canonical paid-entitlement activation. Review and complete the missing mock checkout/confirmation/owner billing transitions, deployable authorized sandbox dispatch, search and operational negative/retry paths; re-run the combined backend tests before final handoff.

Merchant/provider selection, real plan/price/tax/legal/store rules, live credentials, real-service activation and external notifications are **BLOCKED_BY_OWNER**. No real transaction is permitted. Mock results must remain explicitly labelled and must not grant canonical paid AI access.

Notification contract reservation: add a default-disabled sandbox-only Edge entrypoint around the existing outbox worker. It requires a dedicated invocation token in addition to gateway JWT verification, accepts only a bounded batch limit, refuses production/ambiguous targets and reports sandbox receipts without invoking an external transport. Existing queue/claim/finish SQL contracts are retained. This adds no Flutter dependency and does not enable email/SMS/push.

## Implementation checkpoint

Implemented the missing mock checkout and owner billing API, bound signed confirmation/full refund/cancellation, per-owner idempotent creation and bounded literal admin CRM search in one CLI-created forward migration. Added authorized default-disabled sandbox notification entrypoint and payment persistence timeout/permanent semantic rejection handling. Contracts and activation dependencies are in [backend contracts](PHASE24_BACKEND_CONTRACTS.md). Mocks never charge, invoke external notification transport or grant canonical paid AI access.

Working-tree verification: all SQL regression groups and real two-user Auth/RLS/Storage suite PASS; confirmed-email signup, forged/replayed confirmation, mailbox recovery/OTP, expiry, refresh and logout PASS; actual Deno HTTP to real Auth/PostgREST/SQL mock create/confirm/cancel/refund, concurrent callbacks and notification endpoint PASS. Python tests 43 PASS. Earlier initial signup attempt returned local 504/context deadline exceeded; preserved its log and reran successfully. First HTTP attempt exposed `P0002` translating to 500 for foreign orders; changed the unpublished local migration to explicit `PT404` and verified actual 404 on rerun. These are working-tree results; the clean immutable replay and final evidence follow separately.

Added a read-only post-initialization SQL check and exact plan command. Canonical migrations initialize schema/config; no staging administrator or credentials are fabricated. Final verification must replay all 59 canonical files from the new immutable backend commit.

## Final handoff requirements

Produce separate Phase 2 and 4 completion matrices, new commit SHAs and exact changed-file inventory from the requested RC, test commands/exits on a clean final backend HEAD, schema/API contracts, precise owner dependencies, Freebuff integration instructions and an evidence-based GO/NO-GO. Passing unit fixtures do not establish remote integration. Continue implementation until no known locally fixable critical defect remains.
