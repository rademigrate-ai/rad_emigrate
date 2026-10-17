# E1-02 — Production-Recorded Migration SQL Fingerprints (2026-10-18)

**Master objective:** [RAD ONE TASK #57](https://github.com/rademigrate-ai/rad_emigrate/issues/57).  
**Production project:** `inshddthftkhcdosoqcn`. **Repository baseline:** `a9dc7b14d611efe7f7195d51308ab8a3a1f3f4f1`.  
**Production access:** SELECT-only metadata; no SQL statements were executed. **Release decision: NO-GO.**

## New evidence beyond migration filename comparisons

Unlike a filename-only reconciliation, this audit inspects **read-only fingerprints of the actual SQL text retained in** `supabase_migrations.schema_migrations.statements`. The committed JSON contains version/name, number of recorded SQL chunks, SQL length, and MD5 of text under explicit newline/end-of-file normalization. **It contains NO raw migration SQL or credentials** and is deliberately a historical snapshot, not a live-current status assertion.

| Observed fact | Count |
|---|---:|
| Recorded Production migrations | 47 |
| Current repository migration files | 52 |
| Exact version/name identifiers | 27 |
| Same logical name but different version | 16 |
| Live-only migration names | 4 |
| Repository-only names | 9 |
| Same-name single-chunk SQL with matching recorded fingerprint under file-tail/EOL normalization | **29** |
| Same-name single-chunk SQL **not** matching recorded fingerprints | **12** |
| Same-name records stored as multiple SQL statement chunks, not yet reconstructable by this checker | **2** |
| Recorded versions with no matching repository file name | **4** |

Five of the 29 matched SQL bodies have timestamp aliases: `stage2_visa_structured_steps`, `stage5_research_review_candidate_backfill`, `fix_profile_update_with_check_role_escalation`, `ai_credential_failure_routing` and `research_atomic_review_candidate`. Matching hash is **not** a safe instruction to repair the migration ledger.

### Twelve mismatched same-name migrations

`project15_observability`, `client_delivery_ai_scopes`, `stage1_ai_research_completion`, `stage2_review_feed_publish`, `stage3_fk_covering_indexes`, `ai_dynamic_routing_architecture`, `stage2_knowledge_completion`, `stage4_user_ai_quota_grounding`, `stage4_limit_ai_runtime_chain`, `stage6_entitlement_access_decision`, `stage7_ops_consultation_app_status` and `stage9_security_grant_hardening`.

Examples of material source-layout differences:
- The repository `project15_observability` file contains **additional reconstruction SQL after** the closing `commit;` recorded in Production. Do not replay it as an identical historical migration without verifying those policy effects.
- The live `stage6_entitlement_access_decision` statement is 8,452 characters whereas the earlier repository migration file is 5,617 characters. Later hardening migration(s) may supersede its current function behavior, but original SQL text is **not equal**.
- The live `stage4_user_ai_quota_grounding` starts at `create table`; repository copy starts with explanatory comments, and further content differences remain unclassified. Raw SQL equality is not established.
- `stage9_security_grant_hardening` differs at its initial explanatory comment; the rest may be the same, but that would require parser-aware canonicalization or source-to-object comparison, not blind assumptions.

### Two multi-chunk entries

`ai_base_url_ssrf_hardening`: **9** recorded SQL chunks.  
`fix_profile_update_rls_recursion`: **6** recorded SQL chunks.  
This checker explicitly reports `MULTI_OR_EMPTY_STATEMENTS_NOT_COMPARABLE` rather than asserting that joining stored chunks recreates the original file byte-for-byte.

### Four live-only entries

`ai_discovery_auto_enable_chat`, `stage2_promote_knowledge_fn`, `stage2_retrieve_and_conflict_fn`, `stage4_guest_quota_advisory_lock`.

Prior read-only comparison of the **current function bodies** showed whitespace-normalized parity for `promote_knowledge_from_evidence`, `register_knowledge_conflict`, `retrieve_knowledge`, and (with comments removed) `consume_ai_guest_quota` respectively. This proves only current function text, **not the complete historic SQL effects or past data mutations**.

### Nine repository-only entries

`stage2_knowledge_promote`, `stage2_knowledge_retrieve_conflict`, `stage5_visa_editorial_summaries`, `stage1_p0_security_completion`, `stage1_atomic_ai_quota_reservation`, `stage1_ssrf_ipv4_mapped_ipv6`, `stage1_security_abuse_storage_alignment`, `ai_models_check_constraints_alignment`, `security_ai_entitlement_rpc_privacy`.

The last six are new code-controlled security migrations including the post-Stage-1 entitlement privacy gate. **Do not apply them through an unreconciled direct `db push`**. Three earlier repo-only names require independent semantic evidence; 44/44 destination summaries populated does not prove the exact source SQL was run.

## Repeatable non-mutating verification

```bash
python3 -m unittest discover -s scripts/tests -p test_live_migration_sql_fingerprints.py -v
python3 scripts/verify_live_migration_sql_fingerprints.py \
  --repo-root . \
  --observed supabase/reconciliation/production_statement_fingerprints_20261018.json
# Expected: status NO_GO, exit code 2
```

These tools run only local Python, read the committed metadata and repository SQL files, and do not connect to Supabase or mutate files. A passing unit test confirms the **NO-GO safeguard** remains intact, **not** that Production can be migrated.

## Hard gates before E1-02 / Production acceptance

1. Reconstruct or independently verify both multi-chunk SQL histories; inspect all 12 mismatched same-name versions and four live-only SQL sources, including data/DML, policies, grants, triggers and extension effects.
2. Compare all 57 public RLS tables, indexes, constraints, functions, grants, triggers, cron, Storage, Vault, and data invariants against an isolated catalog reconstructed from the pinned repository at the SAME HEAD.
3. Rehearse the exact minimum forward-only operational cutover on a production-equivalent clone with rollback/PITR verified by the operator. Do not fabricate backups.
4. Resolve the 47-live/52-repository migration version ledger without destructive repair or forged history.
5. Only then allow owner-approved coordinated DB / Edge Function / client deployment, real two-user role tests and post-rollout monitoring.

**Hash limitation:** MD5 is a diagnostic fingerprint, not a cryptographic attestation. A hash mismatch could result from formatting, rewritten historical SQL or material changes. A match does not automatically prove all schema or regulatory data state. Production remains **NO-GO**.
