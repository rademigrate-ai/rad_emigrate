# Confirmed fix and security verification

The current RC already contains the seven reviewed Core migrations. Re-running those historical corrections or creating another publication/grounding implementation would duplicate work. The only new implementation is commit `847dd42bbb270755676104a63814dd6e2aab07dd`.

| File | Change |
|---|---|
| `supabase/migrations/20261020192732_rad_revoke_client_nonrow_table_privileges.sql` | Transactional, additive privilege reduction; native CLI generated migration name |
| `supabase/tests/rad_client_table_privileges.sql` | Catalog plus actual anon/authenticated TRUNCATE denial; column REFERENCES; future defaults; DML/RLS positive checks; rollback |
| `scripts/verify_clean_schema.sh` | Include regression in mandatory clean CI |
| `scripts/verify_migration_reconstruction.sh` | Include regression in mandatory reconstruction CI |

Fresh hosted SELECTs and both reconstructed local baselines show **48 effective capability rows**: six tables × two client roles × four privileges. The six tables are admin_case_notes, admin_saved_views, admin_tasks, ai_entitlements, application_status_history and consultation_requests. The previous 36 count omitted PG17 MAINTAIN. This is a privilege finding; no REST TRUNCATE exploit is asserted.

The migration targets postgres-owned public ordinary/partitioned application tables, excluding extension-owned relations. It revokes the four capabilities from PUBLIC, anon and authenticated, plus separately granted column REFERENCES. Both global and public-schema defaults for creator postgres are reduced, because schema-local revocation cannot subtract global defaults. The global change limits those four rights on all future postgres-created tables, including other schemas. It does not grant access or change managed supabase_admin defaults. A postcondition aborts if inherited grants still confer forbidden capabilities.

Red regression reproduced the 48 existing rows. After the patch, both local shapes report zero. `evidence/acl_invariants.json` proves exact before/after equality of client/service DML, RLS flags, policy definitions, routine definitions/configuration/ACLs and service nonrow privileges. Actual anon and authenticated TRUNCATE statements raise insufficient_privilege; a rollback-only future-table probe does not regain rights. No historical SQL file was edited.

Existing corrections were independently exercised: human-only legacy and v1 publication; immutable snapshot UPDATE and supplemental DELETE denial; exact authority projection; rejection of missing proof, conflict, stale/revoked evidence and unrelated retrieval; lease-bound idempotent research changes; human review producing a draft while published head stays fixed; profile INSERT/UPDATE escalation denial; cross-account consultation, history, Storage and entitlement isolation; quota reservation, legacy/v1 shared limits, replay-body conflicts, settlement/expiry fencing. SQL source additionally enforces snapshot hash and exact excerpt/scope checks; this report does not claim every predicate has a separately isolated adversarial DB test.

Booking/interview authorization is limited by actual implemented contracts. `submit_consultation_request(topic,message,related_application_id?) → UUID` is verified owner-isolated intake with rate limits. Scheduling/catalog RPCs requested by frontend modules are absent; no new appointments API or competing product contract was invented. Preserve existing intake until Antigravity/Grok and owner approve the scheduling model.

Managed creator defaults and unapplied hosted corrections remain operational blockers. The advisor's only local warning is pg_net in public; moving a managed extension is not part of this ACL fix. Review [PG17 REVOKE](https://www.postgresql.org/docs/17/sql-revoke.html), [RLS scope](https://www.postgresql.org/docs/17/ddl-rowsecurity.html), and [Supabase extension warning](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public).
