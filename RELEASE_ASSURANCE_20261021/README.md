# RAD final security, database and release assurance

The isolated Codex candidate is ready for integration review. The unified RC, Staging and Production remain **NO-GO**. No deployment, main merge, hosted SQL mutation, migration repair or force-push was performed. No operational rollout is authorized by this report.

Verified code: `747ab96daa38e303d10121e17c4d711fbb16fabe` on `fix/rad-release-assurance-20261021`. Report creation: 2026-10-21T17:07:46.185466+00:00. A later documentation commit contains this evidence; its SHA must not be confused with the code SHA tested by CI. [Exact code-SHA CI](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39639812325) passed all 7 jobs. [Machine verification matrix](evidence/verification_matrix.json), [F01–F21](FINDINGS.md), [source/evidence binding](evidence/source_proof.json), [Grok/Antigravity handoff](GROK_HANDOFF.md).

| Gate | Verdict | Reason |
| --- | --- | --- |
| Codex isolated candidate | Ready for integration review only | Local tests/builds and exact-SHA CI pass; peer/owner review not invented |
| Unified RC c611f2ac | NO-GO | Latest read-only fetch still c611; original CI4/7 and missing subsequent client/security fixes |
| New integrated RC | Pending Grok | No new integrated immutable SHA supplied; phase 5 cannot be claimed complete |
| Staging | NO-GO / not authorized | Reconciliation, foundation scope, operational evidence and integrated-SHA acceptance pending |
| Production | NO-GO / not authorized | Same blockers plus backup/restore, provider/deployed E2E and release acceptance |

## What was implemented

Original client contract/receipt/FX/search/privacy fixes remain. This phase closes 37 lint findings and adds the CI lint gate, rejects malformed provider catalogue/pagination/pricing/capacity, disables legacy research default network work without protected transport, closes additional owner-cache/controller/form/action receipt leaks, and removes fabricated runtime rule approval/attribution. See finding entries for concrete source paths and regressions. Backend wire contracts remain v1; internal Flutter owner/cache/model changes need frontend review.

## Verified tests and limits

Native Flutter 866/0, 18 new privacy/approval tests, focused booking/interview 32/0, format and analyzer clean. Deno 145/0, lint 0, all 8 Edge entrypoints typecheck, Python 43 pass, recovery redirect check passes. Native Web JavaScript and Android arm64 debug builds pass. Debug APK is not a signed release/AAB. Build-time Supabase values are public CI placeholders, not production readiness.

Nonblocking build notices remain: WebAssembly dry-run incompatibility in flutter_secure_storage_web (JavaScript output succeeded), and file_picker Kotlin Gradle plugin migration/future Java native-access warnings (current Android debug output succeeded). No Wasm or future toolchain compatibility pass is claimed. Local artifact hashes are in [build artifacts](evidence/native_build_artifacts.json).

Disposable clean: 80 migrations,19/19 SQL suites. Production-shaped: 54 recorded versions reconstructed, fresh 69 non-owner MAINTAIN ACL supplement,10 normalized catalog dimensions match;20 reviewed forward files,16 SQL suites pass and 3 NOT RUN because foundations are absent. Both shapes have zero effective client TRUNCATE/REFERENCES/TRIGGER/MAINTAIN capabilities and zero column REFERENCES. ACL correction applied twice in an isolated networkless PG17.11 container preserves 2 rows, RLS and all 4 service DML with identical final state. HTTP28 checks and two-user real local Auth/Storage acceptance pass, including quota concurrency, owner boundaries and synthetic human Feed publish. Owned stacks/ACL container stopped; no other runtime cleaned.

No actual hosted mutation tests, authenticated Flutter→deployed Edge→real provider→settlement, real official corpus correctness, provider health, signed Android release or owner/peer review is claimed. Native backend/SQL/HTTP evidence executed at earlier named immutable ancestors is reused only where [source proof](evidence/source_proof.json) confirms identical relevant sources. Final exact-SHA CI independently executes its supported7 gates. External raw logs are retained by [absolute path and SHA256](evidence/external_log_manifest.json). Earlier failed diagnostic attempts do not count as passes.

## Fresh hosted read-only findings

Production project `inshddthftkhcdosoqcn`, PostgreSQL17.11:54 ledger records; all captured statement hashes and 10 normalized catalog dimensions match the protected reconstruction baseline.48 effective client non-row table capabilities and 100 effective column REFERENCES capabilities remain. The latter is not a count of explicit column GRANT statements.0 public ordinary tables currently have RLS disabled. The historical12 staging tables are not authority for any change.

Raw MAINTAIN126 ACL rows comprise 57 owner,57 service and 12 client rows;69 is the non-owner subset used in rehearsal. information_schema omits MAINTAIN, hence raw ACL inspection. Managed creator defaults, including supabase_admin, require owner review. No client decrypted-Vault read was found. Hosted exposed-schema configuration is not proven by null current_setting; local HTTP private/vault denials prove only the tested local stack.

Metadata has3 AI providers,721 model rows,0 search providers; OCR enabled=false/has_secret=false. Configured rows do not prove credentials/health or approved production operation. Source review of active research-sync v4, ai-orchestrator v11 and document-intelligence v3 confirms deployment drift and F21; [fingerprints and line references](evidence/deployed_edge_review.json) preserve evidence without exporting source bodies or secrets. AI v11 has no v1 dispatch and swallows a quota RPC failure. Research v4 still direct-fetches. OCR v3 explicitly checks owner; do not misreport it as an IDOR. Its legacy service-path/fetch/buffering/error behavior remains conditional while disabled. Hosted functions were not changed.

Fresh advisor results: pg_net in public WARN and 17 authenticated-executable security-definer WARNs. The latter require function-by-function owner/argument/search_path/ACL review; intended guarded RPCs must not be blanket-revoked to silence a linter. Current local security suites cover the candidate's tested boundaries. [Extension guidance](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public), [definer guidance](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).

## Migration and operational handoff

[Owner-ready reconciliation package](migration_package/README.md) includes all 80 repository and 54 hosted inventories, exact version/alias/statement fingerprints, effect-review queue,20-file prospective forward manifest, read-only preflight/postflight SQL, protected input hashes, backup/PITR/restore requirements, stop/rollback design and owner checklist. Counts27 common/27 hosted-only/53 repo-only are not a pending migration list. No db push/repair or historical production replay is safe or authorized. Three additive-only suites lack payment event, document lease and incident foundations; design a reviewed additive foundation or explicitly exclude the disabled capability.

Backup/PITR and a restore test are NOT VERIFIED. [Supabase backups](https://supabase.com/docs/guides/platform/backups) cover database metadata, not Storage object bytes; preserve objects separately. Before rollout the owner must approve effect reconciliation, aliases/text/multipart differences, creator defaults, optional foundation scope, exact final integrated hashes, backup/restore/RPO/RTO and a separate authorized execution window. Official roots/proofs, pinned egress transport, live AI/search/notification provider acceptance, signed release setup and genuine curated rule approval remain operational dependencies. Research/AI cannot auto-publish; no unapproved Iranian free-market FX source was added.

The current chat is the authorized coordination channel. Grok and Antigravity review receipts are pending. When Grok publishes a new integrated SHA, fetch it, compare all Codex effects, repeat exact-SHA supported CI and critical security acceptance, and issue a new verdict. This report does not sign off unseen future code.
