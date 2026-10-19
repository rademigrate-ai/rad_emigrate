# Phase 2 / Phase 4 final handoff to Freebuff

Client date: **2026-10-19**, Asia/Tehran. Evidence uses UTC on October 18. **GO for backend delta review and combined integration testing. NO-GO for hosted staging deployment, real payment/notification activation, production or a 47/47 release claim.** All code-controlled requirements in these assigned phases are implemented and locally tested; owner dependencies remain explicit below.

## Baseline, commits and boundaries

- Requested and available RC: `2e0d089781ef3de582143421a59817094e57ca78`.
- Branch: `feat/codex-phase2-phase4-final-20261019`.
- Isolated checkout: `rad_codex_phase2_phase4_20261019`.
- `fc7c5358af4a19856a566213bba058ab0cbd1f39`: staging safeguards/templates/plan/procedure.
- `1d5f5a9454aaef88a8a0142203b878bb31abd563`: billing mock, authorized notification dispatch, CRM search, Auth confirmation and initialization checks. **This is the clean implementation SHA used by all final runtime checks.**
- The subsequent handoff commit changes documentation/evidence only; discover its immutable SHA with `git log -1`. No backend behavior changed after the implementation checks.
- No other-agent worktree access, cherry-pick, merge, Flutter presentation/domain modification, push, PR, external deployment, real transaction or production write was performed. Production `inshddthftkhcdosoqcn` remained read-only.

Evidence is separate from the master acceptance ledger: [clean backend report bundle](releases/phase24_clean_1d5f5a9.json). All included final checks record clean implementation HEAD or are bound by the clean combined-driver report. Older working-tree results are not relabelled as clean proof.

## Phase 2 matrix

| Requirement | Result and evidence |
| --- | --- |
| 1. Existing chain/schema consistency | **LOCAL PASS.** 59 canonical SQL files replayed, source migration hashes retained; pinned core fingerprint and runtime ACL assertions pass. No hosted history repair performed. |
| 2. Empty isolated replay | **LOCAL PASS.** Dedicated marked project `rad_codex_phase24_20261019`, DB 58322/API 58321; fresh CLI start after own disposable stop, 59 migration hashes in `clean_canonical_start`. |
| 3. RLS/user/admin/service/cross-account | **LOCAL PASS.** SQL security groups and real two-user API suite; 67 active definers, zero PUBLIC execute grants; private mock table/client writes denied. |
| 4. Signup/login/logout/recovery/sessions/roles | **LOCAL PASS.** Required Mailpit signup confirmation, forged/replayed confirmation and recovery/OTP denial, recovery expiry, password replacement, refresh/logout revocation; untrusted role metadata does not escalate profile. |
| 5. Storage/documents/ownership | **LOCAL PASS.** Real private Storage upload/download and cross-owner denial, MIME/size/quota scenarios in full suite; actual Auth/Storage/PostgREST document HTTP with a labelled synthetic OCR adapter, human review attribution and cleanup. |
| 6. Edge/secrets/retries/idempotency | **LOCAL PASS.** 116 Edge tests; all entrypoints type-check; actual local Edge Runtime 1.77.1 JWT/disabled-entrypoint smoke; enabled notification factory to real PostgREST. Hosted activated behavior **BLOCKED_BY_OWNER**. |
| 7. Defects/regressions/static checks | **LOCAL PASS.** Staging production-target defect fixed; 43 Python tests; public/private error-level DB lint produces empty results. New negative, timeout, semantic rejection, owner isolation and concurrency coverage. |
| 8. Templates/initialization/commands | **LOCAL PASS.** Blank public/backend templates, fail-closed target guard, immutable plan, canonical initialization and read-only `supabase/staging/readiness.sql`; blank settings cannot produce a deployment plan. |
| 9. Production/staging separation | **LOCAL PASS.** Actual staging-labelled shell build with production target exits 2 before Flutter; target/alias/credential/URI/site negative tests pass. Opaque real key binding requires owner smoke. |
| 10. Exact staging/rollback | Local procedure and plan generation tests **PASS**. Actual isolated host/ref, keys, backup/restore, rollback artifact, provisioning/apply/deployment and hosted smoke are **BLOCKED_BY_OWNER**. No hosted deployment/restore is claimed. |

## Phase 4 matrix

| Requirement | Result and evidence |
| --- | --- |
| 1. Payment/subscription backend | **LOCAL PASS WITH DOCUMENTED MOCK.** Owner-derived idempotent checkout and private order state use the existing signed sandbox protocol. Fictional 100 TST / 30-day fixture; no card data or real checkout URL. |
| 2. Create/confirm/cancel/refund/access | **LOCAL PASS WITH MOCK.** Creation, bound confirmation, pending/confirmed cancellation semantics, full refunds, expiry and mock access transitions tested. Canonical paid-entitlement mapping and real merchant behavior **BLOCKED_BY_OWNER**. |
| 3. Signature/replay/idempotency | **LOCAL PASS.** HMAC timestamp/raw bytes, forged/stale denial, normalized payload hash, atomic event-ID/subscription locks and conflict rejection; timeout abort and fixed permanent 422 versus retryable 503. |
| 4. Concurrent/duplicate callbacks | **LOCAL PASS.** 16 HTTP create attempts => one order; 16 signed confirmations and 16 refunds => one insertion each; separate 20-duplicate SQL race and terminal/refund race pass. |
| 5. Authorization/entitlement isolation | **LOCAL PASS.** Original user JWT to owner RPC; foreign/admin order reads and foreign cancellation return 404; caller cannot supply price/owner; service/anon owner-RPC execution revoked. Canonical entitlements unchanged. |
| 6. CRM/outbox/retries/search/errors | **LOCAL PASS.** Admin-only bounded literal search; revision/assignment concurrency; 32 claims => 12 unique leases; 20 acknowledgements => one winner; opt-in/lease/retry/failure tests; safe fixed error responses. |
| 7. Privileged operations | **LOCAL PASS.** SQL ACL suite and actual HTTP denials; notification gateway JWT plus dedicated worker token; JWT alone cannot invoke enabled factory dispatch. Default activation false and production targets denied. |
| 8. Automated success/failure/malicious coverage | **LOCAL PASS.** Edge/Python/SQL/HTTP suites plus document, outbox/payment, CRM and observability races; test commands/exits below and raw reports in bundle. |
| 9. Sandbox integration | **LOCAL PASS WITH EXPLICIT MOCKS.** Real local Auth/PostgREST/SQL and signed callbacks, no-op notification receipts and synthetic OCR fixture. Zero external provider calls/real charges. |
| 10. Real activation requirements | Exact fields/contracts are documented. Merchant, prices/currency/tax/legal/store policy, canonical entitlement mapping, registered callback, provider credentials, real transport and activation approval are **BLOCKED_BY_OWNER**. |

## Exact validation commands and exits

Executed with Supabase CLI **2.119.0**, Deno **2.5.4**, PostgreSQL **17** client, Python **3.14**. Local Edge gateway smoke used **supabase-edge-runtime-1.77.1**, compatible Deno **2.1.4**. Native executable paths and literal argv arrays for the combined checks are retained in the evidence JSON.

The disposable environment was:

```powershell
$env:RAD_LOCAL47_PROJECT='rad_codex_phase24_20261019'
$env:RAD_LOCAL47_PORT='58322'
$env:RAD_LOCAL47_HIST_PORT='59322'
```

`<cli>`, `<psql>` and `<deno>` below denote the native pinned executable paths recorded in `clean_combined_checks.checks[].command`, not cloud connections.

| Command | Exit/result |
| --- | --- |
| `python scripts/verify_local_stack.py stop --supabase <cli>` then `start --confirm-email --supabase <cli>` with separate report paths | **0 / 0**, own disposable stack only, empty 59-migration replay. |
| `python scripts/verify_local_stack.py verify --supabase <cli> --psql <psql> --report <outside>/clean_backend.json` | **0**, full SQL groups, initialization readiness, real two-user Auth/RLS/Storage and catalog. |
| `python scripts/verify_local47_auth_recovery.py --supabase <cli> --psql <psql> --report <outside>/clean_auth_confirmation.json` | **0**, signup confirmation actually required/tested; synthetic users/messages removed. |
| `python scripts/verify_local47_http.py --supabase <cli> --psql <psql> --deno <deno> --report <outside>/clean_payment_notification_http.json` | **0**, mock billing and enabled notification factory through real PostgREST. |
| `python scripts/verify_local47_ops_concurrency.py --psql <psql> --report <outside>/clean_ops_concurrency.json` | **0**, outbox/CRM/payment concurrency. |
| `python scripts/verify_local47_document_concurrency.py --psql <psql> --report <outside>/clean_document_concurrency.json` | **0**, atomic claim/persistence/failure fencing and resource cap. |
| `python scripts/verify_local47_document_http.py --supabase <cli> --psql <psql> --deno <deno> --report <outside>/clean_document_http.json` | **0**, real Storage/Auth/DB with synthetic OCR; owned fixtures/secret removed. |
| `python scripts/verify_local47_observability_concurrency.py --psql <psql> --report <outside>/clean_observability_concurrency.json` | **0**, 32 failures => one incident/opening alert; 20 healthy samples => one recovery; human resolution required. |
| `<cli> --workdir <owned-runtime> db lint --local --schema public,private --level error --fail-on error` | **0**, empty lint results. |
| `<cli> --workdir <owned-runtime> db push --db-url <owned-loopback-disposable-URI-with-sslmode=disable> --dry-run` | **0**, up to date, zero pending migrations/seeds/roles. TLS disable applies only to this disposable localhost server; hosted staging requires TLS. |
| `python -m unittest discover -s scripts/tests` | **0**, **43 PASS**. |
| `<deno> check <all tracked Edge index.ts paths>` | **0**. |
| `<deno> test --allow-env --allow-read supabase/functions/tests` | **0**, **116 PASS / 0 FAIL**. |
| `bash scripts/build_web_render.sh` with staging label and known production target plus an explicit noncredential key placeholder | **2 expected**, `production_project_forbidden` before Flutter. |
| `python scripts/prepare_staging.py --env-file .env.staging.backend.example --output <outside>/NOT_A_STAGING_DEPLOYMENT_PLAN.json` | **2 expected**, blank target rejected, no plan created. |
| `<cli> --workdir <owned-runtime> functions serve notification-dispatch --env-file <temporary-private-disabled-fixture>` | Local only, JWT verification retained; forged JWT **401**, valid anon/service JWT **503 notification_sandbox_disabled**. Native process and only its own Edge container stopped; temporary token file removed. |
| `python scripts/verify_local47_secret_scan.py --report <outside>/clean_secret_scan.json` | Runner **0**; pinned scanner snapshot **1 / 15 findings**, history **1 / 15 findings**, original `FINDINGS_REQUIRE_REVIEW` retained. |

Private exact finding review: six canonical migration SHA256 values, eight generated index SHA256 values, one SharedPreferences namespace. The 15 historical lines exactly match the snapshot and predate the RC. Scoped comparison used temporary private unredacted values, printed none, and deleted raw JSON. No suppression, allow-comment, custom rule or baseline was added. Review result: **NO CREDENTIAL VALUES IDENTIFIED IN SCANNED SCOPE**, not a zero-finding scan. Ignored envfiles, deployed assets and external secret stores are outside scope. Earlier failed attempts/corrections remain described in the bundle; none are promoted to passing evidence.

## Schema/API integration contract

Apply only the new additive migration `20261018211645_phase24_mock_checkout_and_crm_search.sql` after the RC chain, through the approved integration/release process. Do not rewrite existing migration contents/history. It adds private mock orders, three owner RPCs, a service-callback binding trigger and admin search. Existing CRM revision, notification lease and signed payment APIs remain compatible. Default payment/notification activation stays disabled.

Complete signatures, return fields, fixture semantics, error statuses, timeouts, purpose headers and provider requirements are in [backend contracts](PHASE24_BACKEND_CONTRACTS.md). Exact guarded initialization/deployment/rollback commands are in [staging procedure](STAGING_DEPLOYMENT_AND_ROLLBACK.md). No frontend or AI-domain source is changed here.

## Remaining dependencies and combined acceptance

1. **BLOCKED_BY_OWNER ? staging:** actual isolated project/ref/host, key binding, TLS DB URI, Auth redirects/smoke accounts, initial authorized administrator identity, backup/restore record, rollback release and deployment authorization. Provisioning, deployment and hosted backup restore were not executed.
2. **BLOCKED_BY_OWNER ? real merchant/paid access:** provider/versioned contracts and sandbox account, secrets/signature rules/callback registration, country/currency/price/tax/legal/store and recurring/refund rules, approved product-to-canonical-entitlement mapping and real-provider reconciliation tests. No live transaction is authorized.
3. **BLOCKED_BY_OWNER ? operational delivery:** provider credentials/sender/consent/policy, idempotency and delivery/bounce/retry contracts, registered endpoints and explicit activation. Sandbox receipts prove no real delivery.
4. **Frontend/combined owner gate:** the RC [QA manifest](../qa/QA_RELEASE_MANIFEST.md) records Antigravity's unscoped legacy checklist-key account-switch leak and handoff regression. The affected controller was absent from that QA integration base. Its owning fix and combined retest are required before accepting that frontend branch; no claim is made about a later uninspected owner branch.
5. **Global acceptance:** browser/assistive technology/device/store/signing, human evidence review, actual staging/backup tests and client acceptance remain with their owners. The master ledger remains **3/47 VERIFIED_PASS** as recorded in the RC; this handoff does not upgrade it.

Freebuff should review the delta from the exact RC, resolve shared API/acceptance gates in a separate owner-controlled integration checkout, and run the combined frontend/backend tests after the owner fixes above. Use a new local project ID/port range; the runtime marker deliberately rejects another checkout. Preserve source-agent branches/evidence and obtain the separately required authorization before any push, PR, merge or deployment. No automatic integration operation was performed here.

## Exact changed-file inventory from the RC

- `.env.staging.backend.example`
- `.env.staging.example`
- `.gitignore`
- `docs/CODEX_PHASE2_PHASE4_20261019.md`
- `docs/PHASE24_BACKEND_CONTRACTS.md`
- `docs/PHASE24_FREEBUFF_HANDOFF_20261019.md`
- `docs/RENDER_STAGING.md`
- `docs/STAGING_DEPLOYMENT_AND_ROLLBACK.md`
- `docs/releases/phase24_clean_1d5f5a9.json`
- `scripts/build_web_render.sh`
- `scripts/local47_http_harness.ts`
- `scripts/prepare_staging.py`
- `scripts/staging_environment.py`
- `scripts/tests/test_prepare_staging.py`
- `scripts/tests/test_staging_environment.py`
- `scripts/verify_local47_auth_recovery.py`
- `scripts/verify_local47_http.py`
- `scripts/verify_local_stack.py`
- `supabase/config.toml`
- `supabase/functions/notification-dispatch/handler.ts`
- `supabase/functions/notification-dispatch/index.ts`
- `supabase/functions/payment-sandbox/handler.ts`
- `supabase/functions/tests/notification_dispatch_handler_test.ts`
- `supabase/functions/tests/payment_sandbox_test.ts`
- `supabase/migrations/20261018211645_phase24_mock_checkout_and_crm_search.sql`
- `supabase/staging/readiness.sql`
- `supabase/tests/phase24_mock_checkout_search.sql`
