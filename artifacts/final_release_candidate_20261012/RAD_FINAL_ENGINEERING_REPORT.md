# RAD engineering handoff — 2026-10-12

Branch: `handoff/codex-stage1-stage2-20261010`. This evidence was assembled on the integrated working tree descended from `7ae0a467e6e82bf0a83799e9ad67b6ab541435f0`; the exact resulting commit is reported in the final handoff. Production was not modified.

The browser/Android validation turn began at `1d84d3f71eb6d1db90360076af839b169a757042`. Flutter application files did not change during these checks. Browser harness and diagnostic/evidence files did change; their hashes are in the evidence manifest. Backend Stage 3 tests remain prior RC evidence, not a newly unified run across every repository file.

## Outcome

The repository has a secured consultation submission RPC, aligned private-document Storage UPDATE policy, Flutter consultation/profile and overflow repairs, and regression coverage. Full Flutter tests pass (325, 4 skipped), static analysis passes, the web release build passes, 90 Stage 3 Python tests pass, and disposable PostgreSQL pipeline/security scenarios S1–S17 pass. A real debug APK now builds through a documented Flutter artifact mirror. The earlier real Chrome E2E captured 41 routes but skipped consultation submission. A later isolated stack applied all 50 repository migrations and a targeted real Chrome consultation submission passed; see `RAD_PREPILOT_ACCEPTANCE_20261012.md`. No Android device was available. Production migrations and submissions were not performed. This is an engineering candidate, **not production-ready**.

## Gate decision

| Gate | Status | Owner / exact next action |
|---|---|---|
| G1 production security migrations | FAIL | DBA/release owner: review, back up, authorize and apply pending migrations |
| G2 production RLS/RPC/triggers | FAIL | Security owner: verify live grants, functions, policies and triggers after authorized deployment |
| G3 migration reconciliation | OPEN | DBA: reconcile repository history with live objects without altering history blindly |
| G4 Stage 3 baseline drift | OPEN | Content/data owner: decide 5/5 baseline versus live 6/14 and approve regeneration |
| G5 Flutter current source | PASS local | Engineering: preserve this commit and rerun after any source change |
| G6 browser E2E | PASS local consultation; assistive technology UNVERIFIED | QA: complete controlled screen-reader review before pilot |
| G7 Android build/device | PASS debug APK; device BLOCKED | Release owner: approve app ID/signing, provide device/AVD, then run release build and device smoke test |
| G8 off-machine backup | UNVERIFIED | DBA: attest restorable backup |
| G9 Visa editorial approval | OPEN | Editorial/legal: review draft package, sources and structured gaps |
| G10 consultation/client operations | OPEN | Operations: close launch L01–L04 and pilot safeguards |
| G11 legal/privacy/consent | UNVERIFIED | Legal/privacy owner: sign policy and consent gate |
| G12 pilot owner approval | UNVERIFIED | Management: approve bounded pilot after gates |
| G13 production human-only Feed | FAIL | Security/release owner: deploy guard only after authorization; verify live |
| G14 deployment/rollback readiness | OPEN | Release owner: approved runbook, rollback and window |

See `RAD_FINAL_SECURITY_MATRIX.md`, `RAD_FINAL_TEST_MATRIX.json`, `RAD_FINAL_RELEASE_BLOCKERS.json`, and `docs/LAUNCH_ENGINEERING_OPERATIONS_HANDOFF_20261012.md`. No production writes, public-site edits, form submissions, deployment, or Feed publication occurred.

## Final staging / live-read audit addendum

At source HEAD `bc60f377990737fec182525545778694fe2a7e09`, a local
volume-preserving staging restart enabled Storage with all 50 repository
migrations still applied. Targeted Chrome guest/login/document upload,
signed-view and delete passed, as did 13 read-only local SECURITY DEFINER
denial regressions. The live project has 47 migration records ending at
`20261007212140`; its catalog and advisor were inspected read-only. The two
AI access/quota functions lack owner checks and the live Feed publication RPC
does not require an approved draft. The repository's local security migration
addresses these gaps, but production has not received it. No hosted staging
branch exists. Android emulator provisioning was attempted but the official
1.6 GB system-image transfer was too slow to complete; no device journey was
run. See `RAD_STAGING_RELEASE_BLOCKERS_20261012.md`,
`RAD_LIVE_DEFINER_REVIEW_20261012.md`, and
`RAD_PRODUCTION_MIGRATION_RECONCILIATION_PLAN_20261012.md`. Production remains
**NO-GO**.

## Production-equivalent local rehearsal — 2026-10-13

A new PostgreSQL 17.11 stack replayed the **47 actual live-ledger SQL bodies**
in order. Before pending migrations, inspected application schema and ACL
catalogs matched live; no production client data was copied. All five
security files then applied in chronological order, preserving the 47 ledger
rows and appending five. Concurrent AI quota, cross-user authorization,
approved-only Feed, Consultation limits, and Storage HTTP isolation passed
on that reconstructed stack. A custom-format backup restored into a separate
network-isolated PostgreSQL 17.11 cluster with matching application schema,
row/data hashes, constraints and effective grants **after** a hardened
restore procedure. A plain restore produced unsafe excess grants and must
not be used as the recovery runbook. See
`RAD_PROD_EQUIV_REHEARSAL_REPORT_20261013.md` and its signed-off local
evidence matrix. Production backup/PITR and release authorization are still
unverified; **production remains NO-GO**.

## 2026-10-13 checkpoint

The expanded read-only catalog check found four local-only application CHECK
constraints and the consultation rate-limit index beyond the earlier
function/policy/trigger inventory. Three AI model constraints belong to a
historically aliased migration and require DBA reconciliation; the pending P0
and abuse-control files supply the other constraint and index. Storage
service internals and a live-only `LOGO` bucket remain separate. Exact
signatures/grants and dependency order are in the linked reconciliation and
SECURITY DEFINER reports. A targeted local Storage denial regression passed
cross-owner signed URL/upsert/path and unsupported MIME cases, then cleaned
all fixtures. The smaller official AOSP ATD Android image also downloaded too
slowly (2.6 MB of 658.4 MB; ETA about 4.7 hours), so no AVD or device
journeys exist. No application or migration source changed. Production stays
**NO-GO**.
