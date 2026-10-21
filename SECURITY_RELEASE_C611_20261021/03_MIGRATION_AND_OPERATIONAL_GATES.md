# Migration and operational gates

The additive rehearsal uses the dated **2026-10-20T19:21:48Z** read-only production capture for project `inshddthftkhcdosoqcn`; no hosted access or mutation occurred in this phase. The reconstruction is evidence-backed, not proof of today's unchanged hosted state. Its 10 compared metadata dimensions pass before the forward files. Supabase platform Storage extras are recorded separately, not silently treated as application drift.

PostgreSQL 17 MAINTAIN grants are absent from information_schema.table_privileges. The native production-shaped reconstruction additionally restored the **69 observed raw-catalog MAINTAIN rows** from the preceding read-only capture (12 client, 57 service). Both final privilege probes include that right. The older four-privilege information_schema view alone was not accepted as proof of zero effective grants. Only disposable local objects were altered.

The 80-file clean sequence is not a production migration plan. The captured hosted ledger has 54 versions; 27 exact versions overlap, 27 are hosted-only and 53 are repository-only. Earlier fingerprint/effect reconciliation found aliases and multipart/formatting differences: do not interpret repository-only counts as unapplied changes. The standalone ACL correction is now included once. Neither historical files nor applied versions were rewritten. Public app RLS remains enabled; the earlier 12 RLS-disabled staging tables are not authorization to expose, repair or change hosted tables.

Production prerequisite sequence:

1. Take an explicitly authorized, fresh read-only ledger + SQL/effect + full raw ACL/default-ACL/schema capture and compare it to the dated source. Include MAINTAIN, inherited/PUBLIC rights and creator defaults.
2. Resolve each hosted-only/repository-only alias by effect and dependency. Approve an additive-only ordered manifest with exact file hashes, rollback/restore and owner signoff. Do not use db push, migration repair, or historical replay to force ledgers to match.
3. Resolve or explicitly exclude payment/OCR lease/incident foundations. Three optional additive SQL suites are NOT RUN because those foundations are absent, not silently passed or created by history replay. See [upgrade_sql_results.json](evidence/upgrade_sql_results.json).
4. Review managed supabase_admin default ACLs with the database/platform owner; local correction deliberately narrows application postgres defaults only. Preserve service DML, fixed definer search paths and RLS; no disabled-RLS shortcut.
5. Rehearse the approved manifest and full security checks on a fresh isolated disposable copy; capture zero effective non-row rights and negative real-role operations. Independently verify the final owner-integrated exact SHA in CI.
6. Owner separately approves operational official roots/proof corpus/pinned egress, real AI/FX/provider health, notification transport and signed release configuration. Keep dependent workers/features disabled until then. No Iranian free-market provider was added and no evidence or immigration content was fabricated.
7. Staging/production require new explicit deployment authorization and their own hosted acceptance. This report does not provide it.

Operational blockers are F12 (ledger/effect/default/foundation reconciliation) and F14 (real sources, provider/transport/release setup). Real approved catalogs/corpus, deployment E2E, legacy slug compatibility, signed Android release/device testing and frontend-owner review remain acceptance limitations. Deno lint has 37 existing findings and needs a separately reviewed cleanup; supported CI passing does not erase them.
