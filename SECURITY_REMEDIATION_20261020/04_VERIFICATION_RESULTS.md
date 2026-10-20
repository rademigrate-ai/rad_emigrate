# Verification results and precise limits

Current RC `b01f625` has since been independently tested. See [exact current review](07_CURRENT_RC_B01F625.md). The results below describe the standalone fix 847dd42 and its initial base unless explicitly labeled otherwise.

| Check | Result | Commit/scope |
|---|---|---|
| New ACL red/green | 48 forbidden rights before → 0 after, both shapes; actual anon/auth TRUNCATE denied | RC prefix + exact new migration bytes now committed as `847dd42bbb270755676104a63814dd6e2aab07dd` |
| Clean SQL | **19/19 PASS**, 80 ordered files | local clean replay 79 + append; exact-SHA CI independently clean replay PASS |
| Corrected production-shaped SQL | **16 PASS, 3 NOT RUN, 0 FAIL** | captured 54-version metadata + observed MAINTAIN + 20 additive files |
| Supplemental snapshot DELETE | **PASS on both shapes** | full synthetic evidence workflow with extra DELETE negative, rollback |
| Real HTTP security | **28 checks PASS** | local Auth/JWT, owner isolation, escalation, quota and settlement |
| Auth/Storage E2E | **PASS**, quota 2 accepted/16 rejected/2 unique rows | two real local Auth accounts, login/logout, RLS, Storage, synthetic human publication |
| Entitlement RPC privacy | **PASS exit 0** | owned local canonical |
| Python script tests | **43 PASS** | RC `2d86f55f9f802067cbc9cc97be121ab38f7bef9b`; no Python test/source changes in fix |
| Scoped-read Deno | **137 PASS, 0 FAIL** | rerun at exact `847dd42bbb270755676104a63814dd6e2aab07dd`, Deno 2.9.7 |
| Prior interview regression | **1 PASS** | exact named test at RC `2d86f55f9f802067cbc9cc97be121ab38f7bef9b` |
| Runtime false-fallback probe | **0 PASS, 3 FAIL** | committed RC `2d86f55f9f802067cbc9cc97be121ab38f7bef9b`; Grok corrections unpublished |
| Advisors | **exit 0, 1 WARN**: pg_net in public | local loopback only; initial SSL-incompatible attempt retained, then explicit loopback sslmode=disable |
| Gitleaks 8.30.1 pinned image | Automated **FINDINGS_REQUIRE_REVIEW**: 30 snapshot, 36 reachable-history | immutable `847dd42bbb270755676104a63814dd6e2aab07dd` snapshot/history; network off, read-only mounts, no custom ignores |
| Independent scanner review | **66/66 classified, no unresolved credential candidate** | 22 migration digest metadata, 16 stat-cache metadata, 2 preference identifiers, 26 synthetic UUIDs; values omitted, no policy/history changes |

The three unavailable production-shaped suites are payment sandbox, document/OCR processing leases and operations/incident observability. Their foundations are absent from captured production; those suites pass on clean shape. NOT RUN is not PASS.

Quota HTTP acceptance includes ten v1 concurrent reservations admitting exactly two and a separate ten-request mixed legacy/v1 race admitting exactly two with a bounded token budget. Auth/Storage acceptance uses eighteen authenticated requests admitting two. Idempotent replay, changed-body replay conflict, cross-owner sessions and terminal settlement fencing pass. These are local synthetic acceptance cases, not live LLM/provider tests.

## Exact-SHA GitHub CI

[Run 39484515979](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39484515979), head `847dd42bbb270755676104a63814dd6e2aab07dd`, completed **FAIL (6/7 jobs PASS)**.

| Job | Result |
|---|---|
| clean-schema | PASS |
| migration-reconstruction | PASS |
| repository-keyword-scan | PASS |
| flutter | PASS: analysis no issues; **835 tests passed** |
| web-build | PASS: build/web |
| android-build | PASS: debug APK, not a signed release bundle |
| routing | FAIL: **127 Deno pass / 10 fail**, all NotCapable/read permission; committed workflow lacks scoped filesystem read |

The corrected local Deno command passes; it does not turn CI green. Grok owns the active workflow correction. No current CI run exists for RC `2d86f55f9f802067cbc9cc97be121ab38f7bef9b` itself, and the older Core 7/7 run is not inherited. Full native Flutter was not repeated here; exact-code CI provides current 835-case suite, analysis and builds. Prior lint findings are not relabeled as current results.

Local harness records created while the fix was uncommitted honestly retain `source_head: 2d86f55f9f802067cbc9cc97be121ab38f7bef9b`. Their migration/test byte digests match committed `847dd42bbb270755676104a63814dd6e2aab07dd`; they are not rewritten to imply a checkout that did not yet exist. Exact-code Deno, scanner and CI are tied directly to `847dd42bbb270755676104a63814dd6e2aab07dd`. `evidence/external_evidence_manifest.json` records raw local logs and capture-tool digests without exporting secret values; published JSON is canonicalized UTF-8 from some native PowerShell UTF-16 logs.
