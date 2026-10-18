# Local backend checkpoint — 2026-10-18

Codex worktree: `rad_codex_master_47_20261018`. Local commits only; no intermediate GitHub push, PR or issue update. Production and other writers' worktrees remain untouched. Accepted count remains **3/47**; the integration owner alone updates the canonical gate ledger.

## Working backend changes

- OCR checkpoint `4b9e0af`: bounded owner-only processing, fixed failure codes, safe Storage paths, MIME/signature checks, no credential-following redirects, importable handler and 18 synthetic tests. Successful jobs still require human review.
- CRM: optional optimistic `transition_admin_consultation` and `assign_admin_consultation` RPCs, monotonic revision, row-locked updates and owner-visible status history. Internal notes and actor IDs are excluded from owner history grants. Existing submit/list/update signatures remain compatible.
- Notifications: existing preferences gain SMS opt-in and explicit IANA time zone (UTC default). A sandbox-only outbox provides idempotent enqueue, quiet-hour deferral, revocable consent, expiring leases and three-attempt retry limits. Receipts are labelled `sandbox_delivered`, never externally delivered. The worker exposes only identifiers to the injected sandbox transport.
- Payments: a disabled-by-default HMAC protocol accepts synthetic events only, refuses hosted Supabase targets, verifies signature age and raw-body integrity, and persists normalized allowlisted event data. Subscription/event identity, currency, duplicate hashes, stale ordering and terminal revocations are enforced atomically. Sandbox state never writes `ai_entitlements`. This is not a chosen payment-provider integration, checkout, price/tax model or real financial settlement system.
- Runtime security: 59 active definers inventoried; PUBLIC execution removed, private client helper access limited to the RLS role helper, future default PUBLIC function grants removed, and notification service/admin authorization repaired. See the runtime inventory and executable ACL tests.

## Local database proof

The native cross-platform runner `scripts/verify_local_stack.py` uses marked external temporary directories, native psql, pinned Supabase CLI 2.119.0 and Docker. Canonical stack: `rad_codex_local47`, ports 55320–55329. Historical reconstruction: `rad_codex_local47_reconstruct`, ports 57320–57329. It neither links nor targets a hosted project, and does not move source migrations out of a working tree.

Windows fixes preserve the strict checks: replay SQL uses canonical LF bytes (PostgreSQL preserves CRLF in function bodies), and the catalog comparer explicitly reads UTF-8 instead of CP1252. The Unicode tests prove an actual SQL text change still fails comparison. The initial reconstruction port conflict was resolved by choosing unused ports; the unrelated project at 56322 was left running.

Verified local results:

| Check | Result | Evidence |
|---|---|---|
| Full Edge unit/request suites | 82 PASS, 0 FAIL | 26 AI, 18 OCR, 13 grounding, 8 notification worker, 13 payment sandbox, 4 Research cases |
| Existing Python regressions before Unicode fix | 25 PASS | All existing `scripts/tests` suites |
| Unicode comparison regressions | 2 PASS | `test_catalog_unicode_comparison.py` |
| Canonical database fingerprint and SQL/caller matrix | PASS | `local47_acl_verify.json` |
| Two-user Auth/RLS/Storage/quota/human Feed | PASS on both stacks | canonical and historical verification reports |
| Historical reconstruction | PASS: 25 captured versions + 31 forward SQL files | `local47_historical_verify.json` |
| Local catalog equivalence | 27 groups MATCH; history differs by replay method | `local47_catalog_equivalence.json`; no SQL/ACL drift excused |
| Concurrent outbox claims | 32 requests, 12 unique leases | `local47_ops_concurrency.json` |
| Concurrent receipt acknowledgements | 20 requests, 1 winner | same report |
| Concurrent CRM revision | 20 requests, 1 winner | same report |
| Concurrent duplicate payment | 20 requests, 1 persisted event | same report |
| Payment/refund race | 13 requests, final state refunded | same report; canonical entitlements unchanged |
| Supabase local advisors | 0 ERROR; 24 WARN | 23 existing multiple-permissive-policy warnings, 1 extension-in-public warning; `local47_advisors.json` |

The full eight-dimension fingerprint remains pinned. The intentional private trigger EXECUTE revocation changes only the function dimension (`e05d93...` → `fc57d0...`); restoring exactly the two previous flags reproduces the old hash. No permissive exception or skipped dimension was added.

Reports correctly mark the tested working snapshot as dirty while proposals were being implemented. They are local engineering evidence, not exact final integrated-HEAD acceptance. A fresh full candidate replay and the integrated checks remain required before final delivery.

## Remaining acceptance limits

Production's recorded 47-entry SQL/content drift is still unresolved. A 25-version synthetic reconstruction is not proof of Production equivalence, backup/PITR recovery or a Production restore. Real provider routing/OCR/notification/payment credentials and consent, merchant/store/tax decisions, human regulatory/editorial review, deployment authorization, physical device tests and owner/client acceptance remain open. Browser, native build and final integrated regression evidence belong to the integration/frontend checkpoint. Release remains **NO-GO**.
