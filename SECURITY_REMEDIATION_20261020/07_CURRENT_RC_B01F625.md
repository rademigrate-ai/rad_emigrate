# Independent review of newly published RC

Candidate **`b01f6255c9f10baff1ff12c1df07b1d995fad8a8`**, branch `feat/rad-final-unified-release-candidate`; reviewed from a separate owned checkout/branch `rad_security_verify_b01f625` / `audit/rad-security-rc-b01f625-20261020`. Grok's active worktree was never changed. Captured `2026-10-20T19:58:55.265926+00:00`.

Grok published this commit while initial fix evidence was being packaged. It changes17 Flutter/test/workflow files. Supabase sources, migrations and security harnesses are byte-identical to initial RC `2d86f55f9f802067cbc9cc97be121ab38f7bef9b`. **Standalone fix `847dd42bbb270755676104a63814dd6e2aab07dd` is not an ancestor and its new migration/test are absent.** Both new disposable local shapes independently reproduce `client_non_row_table_privileges:48` with the published regression, without applying the patch or modifying the candidate.

| Exact current-SHA check | Result |
|---|---|
| Clean-schema replay | **79 files PASS**, existing SQL **18/18 PASS** |
| Faithful production-shaped additive | fresh reconstructed54-row ledger + observed 69 MAINTAIN grants + **19 forward files PASS**; SQL **15 PASS/3 NOT RUN** |
| Missing-fix regression from published847dd42 | **FAIL as expected on both shapes**,48 forbidden privilege rows |
| HTTP security | **28 PASS**, including two separate10-request quota races admitting exactly2, owner isolation/profile escalation/settlement fencing |
| Auth/Storage E2E | **PASS**,18 concurrent quota calls yield 2 accepted/16 rejected/2 rows; real local login/logout, owner RLS/Storage and synthetic human Feed publication |
| Human review / immutable evidence / research-to-draft | **PASS** in both existing SQL suites; no real official content/Feed publication |
| Deno | **137 PASS,0 FAIL** native; current routing CI PASS |
| Python | **43 PASS** native |
| Interview mobile regression | **1 PASS** native |
| Cost/pathway/university targeted suites | **7 PASS**, empty/unavailable catalogs; no real approved corpus supplied |
| Original unavailable fallback expectations | **3 PASS**, search invocation adapted to the new interface solely in external audit probe |
| New malformed FX decoder expectation | **1 FAIL**: empty payload accepted as fresh quote with default currency/provider/zero/current timestamps |
| AI contract observation | **3 observations confirmed**: actual emittedv1 header is rejected422; numeric 1 reaches schema validation; timestamp default fails UUID contract. These passing observation tests confirm a defect, not AI acceptance. |
| Gitleaks pinned 8.30.1 | automated FINDINGS_REQUIRE_REVIEW: 30 snapshot/36 history candidates; independent review PASS, no unresolved credential candidates |

The old external fallback probe initially failed to compile because b01f625 removed searchArticles. Its log is retained; this is not counted as an executed expectation. The adapted probe changes only that API call and adds a new malformed FX case;3 pass/1 fail. Local startup first encountered a native CLI exit3221226505 during memory pressure and a partial stop failure; the owned stop was recovered and stacks were started sequentially. Terminal successful start/replay/test records are published. The interrupted initial Flutter process was only this task's process tree. Other stacks/processes were not stopped.

## CI on this exact SHA

[Run 39486415013](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39486415013): **FAIL,4/7**.

| Job | Result |
|---|---|
| clean-schema | PASS |
| migration-reconstruction | PASS |
| repository-keyword-scan | PASS |
| routing | PASS; Deno read permission now present |
| flutter | FAIL during analysis; no current full-suite pass claimed |
| web-build | FAIL to compile |
| android-build | FAIL to compile |

Confirmed compiler errors: `lib/core/services/ai/supabase_ai_service.dart:71` nullable authorizedScopes.isNotEmpty; `lib/features/visa/presentation/providers/visa_search_controller.dart:64` and `test/visa/visa_search_test.dart:56,66` call removed searchArticles. Analysis also reports unused route import and other warnings. No fresh835-case success/build artifacts are attributed to this SHA.

## Contract/privacy review for Grok and Antigravity

The client at AI Dart54-87 sends x-rad-contract-version=`v1`; `ai-orchestrator/handler.ts:35-37` accepts`1` and otherwise returns 422 before auth/provider activity. A source-extracted version was passed to the actual dispatcher in a no-network probe. After correcting that header, the body still violates `ai_orchestrator_request`: non-UUID default key, extra contract_version/modality, omitted required context, omitted empty authorized_data_scopes and omitted nullable guest_key/locale in default calls. Coordinate full request/response fixtures; do not loosen backend validation to accept malformed clients.

FX decoder `fx_rate.dart:49-82` accepts empty/malformed maps with synthesized provider, currencies, zero rate and fresh/current dates. Quote requests/responses must match the actual nested observation/decimal model and preserve unavailable states. Visa canonical/related decoders still use updated_at/current time for missing fact-check dates. Do not interpret content modification time as verification time.

Booking now honors the normal returned UUID but retains a timestamp receipt fallback and preferred date/timezone not submitted to backend. Caches use autoDispose and watch a Provider returning a constant singleton; this does not subscribe to auth state or clear an actively listened cache on logout. A UI disclosure is not dynamically asserted. Add actual identity-bound A/logout/B tests and keep pending guest draft semantics approved.

F01/F02/F03/F09 existing backend corrections remain verified; F05's invented offline catalogs were removed; F06's original mobile failure passes; F10's Deno permission defect is corrected. F04/F07/F11/F15 are partially fixed, F08 still fails, F12/F14 are operational blockers, F13 needs integration of the delivered fix. Full matrix is authoritative in01_FINDING_MATRIX.md.

**Verdict:** Integration Review GO; Staging NO-GO; Production NO-GO. Current RC review complete with blockers. After Grok integrates the security fix and corrects its client changes, another immutable SHA and exact-SHA CI/security verification are required. This report grants no hosted deployment or migration authorization.
