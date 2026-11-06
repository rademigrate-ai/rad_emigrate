# RAD production content release runbook

Updated 30 October 2026. Status: NO-GO pending final source-to-application certification, a reconciled and rehearsed Production forward package, current recoverable backup evidence, and human editorial clearance. The owner's master request authorizes safe consolidation work; the older Staging-only task restriction is historical. No imported article is currently approved for publication. Render deployment remains owner-operated.

## Pinned environments and evidence

| Environment | Project | Permitted current operation |
|---|---|---|
| Staging | `epolbumcfbohtmgvomki` | Guarded additive draft import after local rehearsal and backup |
| Production | `inshddthftkhcdosoqcn` | Catalog reconciliation now; hosted writes only after current backup, restore proof and minimal reviewed package |
| Existing local browser fixture | `rad_full_content_v4_20261028`, API `127.0.0.1:64521`, DB `64522` | Read-only browser checks of its existing corpus; preserve contributor state |
| Owned native acceptance | `rad_master_acceptance_20261029`, DB `127.0.0.1:64932` | Marked isolated migration, draft import/retry/rollback and SQL reader checks; managed Auth/Storage/Vault/cron are synthetic fixtures |

Use the RAD connector account `link_6ac0e1afbba081919b4e439b2381d04a`. Check the actual project ID before every hosted operation. Keep credentials and backup decryption material outside Git and chat.

Historical V4 evidence is in the original `rad_full_content_v4/artifacts/RAD_FULL_CONTENT_V4_20261028/`. Its earlier runbook reported Staging encrypted-backup SHA256 `169ccca86ee51596b9ba280ab6e54c5181bd8c49bf543df146153cbb4e06953d` and `backup-evidence/restore-verification.json`. That historical assertion is not a fresh verified Production recovery receipt. Require independently accessible current backup and isolated restore evidence before any hosted mutation. Native synthetic-schema tests cannot satisfy this gate.

Current execution records are `docs/RAD_MASTER_EXECUTION_LEDGER.md`, `docs/master_execution/live_baseline.json`, `docs/master_execution/integrity_and_lineage.json` and the local workspace's `_audit/RAD_MASTER_EXECUTION_20261029/`. Keep private backups, local QA accounts and public build configuration outside Git.

## 1. Freeze and verify the release candidate

Record `git rev-parse HEAD`, a clean worktree, composition manifest SHA256, import-plan SHA256, every operation hash, the source package manifest, independent audit and coverage receipts. Test evidence must identify that exact commit and data manifest. Require all mandatory gates in `RAD_FINAL_CONTENT_COMPLETION_VERDICT` to pass, with inaccessible source limitations explicitly resolved or accepted as a release limitation by the owner.

Run the repository's required formatting, analysis, Python/content tests, Flutter tests, web and supported Android builds on the pinned commit. Execute the complete local import, exact retry and generated rollback rehearsal; require original heads/catalogs restored, unchanged published pointers, no lost source blocks and disabled import gates.

Apply the same reviewed data plan to the marked local acceptance fixture. Generate independent expected payload hashes using `tools/content_completion/v4_database_evidence.py`; collect DB receipts and pass its `expected-ui-heads.json` to `test/browser/full_content_v4_smoke.cjs`. Require exhaustive destination selection, matching revision IDs, complete API body/media/link hashes, visible retained-body probes, country navigation, ordinary-user/anonymous denial and narrow-screen rich-structure regressions. Retain the stated visual probe scope; API equality alone does not prove every intermediate widget.

## 2. Reconcile Production before preparing executable forwards

The 29 October live baseline supersedes the old `production-read-only-metadata.json`: Production already has 72 migration entries, 738 articles, 747 revisions, 745 locale heads, 826 sections, 3,806 private CMS archive rows and 3,187 private evidence archive rows, with zero published heads. Do not repeat these imports. Operational source documents/snapshots remain 6/17 and origin/merge registries are empty. The compared public/private catalog has 175 Staging objects absent from Production and 32 differing definitions. These are drift indicators, not an approved migration list; bodies, effective ACLs, constraints, trigger behavior and dependencies must be reviewed individually.

Production is missing the canonical editorial reader and the eight checked Research RPCs. Staging table counts or native fixture success do not prove production schema compatibility. Several migration ledger timestamps differ from repository filenames; preserve history rather than forcing name parity. Use `scripts/master_preflight.sql` and retain the exact target ID, observed timestamp and definition/ACL fingerprints.

Refresh the actual Production catalog and migration inventory using the read-only queries in `supabase/reconciliation/`. Compare function definitions, tables, columns, constraints, indexes, triggers, grants and RLS policies with the candidate schema. Match renamed migration entries by SQL/object fingerprints. Preserve original history. Do not run `db push`, replay all historical migrations, or repair ledger entries to force apparent parity.

Build a minimal forward-only Production package from this comparison, including the CMS dependencies and reader/library functions actually absent. Test it against an isolated restore of the current Production backup, with existing application security regressions. This executable Production package is a separate required artifact; the Staging import compiler deliberately rejects Production. Never change its target strings to create a Production importer.

The Production-specific data mechanism must independently bind its target project, existing identities, owner-approved actor, current heads, source identities, exact payload hashes and rollback journal. It must keep imported revisions as unverified drafts, preserve existing human edits/publication pointers, disable the gate after each transaction, and deny publication. Rehearse its exact SQL, retry and rollback on the restored Production clone before presenting it for final authorization.

## 3. Authorization record and backup gate

Record the concrete commit, schema-forward hash, data manifest, destination/source counts, unresolved-source report, rehearsal receipts, deployment changes, rollback package and existing owner authorization. The current master request covers safe in-scope additive consolidation; do not invent a second routine permission gate. Obtain new authorization only for destructive/irreversible decisions, changed scope, or actions reserved for the owner. Migration authority never authorizes public publication, and Render deployment remains owner-operated.

Immediately before execution, create and verify a current encrypted Production backup and perform an isolated restore with count, owner/ACL/RLS and application checks. Include the required Storage bytes and external Auth/SMTP/Edge configuration evidence where the release depends on them. Recheck heads and schema fingerprints against the reviewed preflight; stop on drift and regenerate a reviewable package.

## 4. Deploy schema and drafts, then reconcile

Apply only the reviewed forward migration package through the migration mechanism; record actual observed migration versions. Execute hash-checked bounded draft-import transactions and retain every receipt. On a timeout, first inspect the journal/current head, then retry the same exact payload with its stable request key. A changed payload is a new operation. Stop on protected human edits, source identity conflicts, incomplete body comparisons or unexpected publication changes.

Run independent Production DB and authorized application-preview reconciliation against the pinned expected payloads. The trace must reach each source snapshot, original block, retained equivalent, current revision and actual app route. Compare the published-head snapshot before/after and test anonymous/ordinary-user denial. Deploy the pinned frontend only through the separately authorized hosting operation after backward-compatibility smoke tests.

## 5. Separate editorial publication

Mechanical source-priority and semantic merge decisions need no routine owner approval. Preserve revision-bound official factual verification and documented clearance for sensitive claims. Use the existing CMS submit/approve/publish operations with the required role, exact revision and expected concurrency value. The importer, research tools and AI never publish Visa or Feed content.

For the explicitly authorized published subset, verify public UUID/deep-link routes, country/Other Titles collections, search visibility, source references and original-language availability. Check that all other drafts stay private. A draft-only release must be reported as draft-only.

## 6. Rollback and completion receipt

Before publication, use only the reviewed journaled rollback for this manifest. It may detach new untouched drafts and restore exact prior heads/catalog associations. It must preserve later human edits, reviewed/published revisions, immutable snapshots and history; review any preserved records explicitly. Run independent count/head/source and visibility checks afterward.

After publication, do not blindly run a draft rollback. Use the CMS's authorized unpublish/previous-published-revision procedure, verify public projections/search invalidation, then assess the forward schema separately. Prefer compatible forward fixes; never drop shared source/history tables as an emergency shortcut. Restoring a full backup is an explicitly authorized disaster-recovery operation that must account for writes since the snapshot.

The release receipt records exact commit and package hashes, observed migration versions, imports/retries/rollbacks, source-to-app counts, published subset, security/browser results, unresolved exceptions and owner authorization. Until these requirements pass, Production release readiness and completion remain pending.
