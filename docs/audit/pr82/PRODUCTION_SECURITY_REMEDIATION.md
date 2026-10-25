# PR82 restrictive security remediation — deployment NOT authorized

Baseline: PR82 `1f0a1733c411e4f58efab66b20a407ae1f737c6c`.
Production project: `inshddthftkhcdosoqcn`. This document grants no execution permission.

## F02: observed grants and minimal source correction

Read-only inspection at 2026-10-25 13:33:20 UTC independently found all combinations:

| Tables (public) | Client roles | Prohibited privileges | Count |
|---|---|---|---|
| admin_case_notes, admin_saved_views, admin_tasks, ai_entitlements, application_status_history, consultation_requests | anon, authenticated | TRUNCATE, REFERENCES, TRIGGER | 36 |
| same six tables | same two roles | MAINTAIN | 12 |

Total **48** observed grants; this expands the original 36-grant finding. Effective
column REFERENCES is also checked. No hosted destructive operation was attempted.
This is excessive SQL privilege, not proof of a direct PostgREST TRUNCATE endpoint.

`supabase/migrations/20261025133320_pr82_sensitive_nonrow_privileges.sql` changes
only non-row ACLs on these six postgres-owned, non-extension application tables
and the postgres creator's non-row defaults. It also revokes column REFERENCES.
It fails if ownership/type or inherited privilege assumptions differ. It preserves
row DML, RLS, policies, owners, data, function ACLs and explicit service_role grants.
The prior repository all-application ACL correction and H01 remain intact; this
forward migration supplies a small independent review unit for the hosted drift.
It does not attempt to replay H01 and its absent CMS dependencies on Production.

Application behavior depends on row DML and owner/Admin policies, not client DDL,
TRUNCATE or maintenance powers. Native rehearsals compare before/after data, DML,
policy and RLS snapshots, exercise Admin CRUD, ordinary A/B isolation, and execute
real SQL privilege probes for anon, A, B, Admin and service_role. REFERENCES probes
grant schema CREATE only inside rollback transactions so an unrelated CREATE
denial cannot mask the REFERENCES boundary. Service-role operations must succeed.

Managed `supabase_admin` defaults are deliberately unchanged and remain a residual
future-table risk requiring an operational ownership decision. The migration does
not claim to secure every Production table outside these six. PostgreSQL 17 is a
prerequisite for the explicit MAINTAIN privilege used here.

## F15: discovery preserves human approval

The fresh hosted function still sets new chat models enabled and can re-enable a
previously disabled model. The source already had a fail-closed replacement in
`20261023010000_rad_ai_discovery_fail_closed.sql`; it is absent from the hosted
lineage. The new forward correction is
`20261025133333_pr82_ai_discovery_preserve_approval.sql`.

It keeps the same `(uuid,bigint,jsonb)` signature and service-role-only EXECUTE.
New discoveries start disabled. Rediscovery changes availability and discovery
metadata, preserving existing enabled, runtime scope, priority, and configured
capability/cost decisions. Missing models become unavailable while their human
approval flags remain unchanged. Provider row locking and credential-version
validation fence configuration changes. Disabled/missing providers and null
catalogues fail closed. **It contains no bulk flag update on existing models.**
Neither the historical approximate enabled-model count nor any provider/model
content is an authorization to bulk-disable models. No provider was contacted by
the SQL rehearsals; all fixtures use example.invalid and synthetic labels.

## Separately authorized hosted execution prerequisites

1. Reconcile the actual 54-entry hosted migration ledger and SQL fingerprints.
   Existing version aliases/live-only records remain NO-GO for historical replay.
2. Run `supabase/reconciliation/pr82_security_preflight.sql` read-only; compare
   function definition, schema types/owners, effective and default ACLs, role
   memberships and counts to the reviewed evidence. Stop on new drift.
3. Approve a targeted manifest containing only the two security corrections, with
   hashes from the reviewed Git commit. The appointment migration depends on new
   Plan2 tables absent in Production and is **not** part of this minimal package.
4. Establish a current backup/restore proof and monitoring/recovery owner. Rehearse
   against an authorized isolated production-shaped copy without private exports.
5. Obtain explicit Production authorization and operator review. Existing audit or
   PR push authorization does not authorize hosted SQL or migration-history repair.
6. Execute through the separately approved deployment procedure; capture fresh
   postflight metadata, zero effective client non-row privileges on all six tables,
   retained DML/RLS/service boundaries, unchanged model approval flags, new-model
   disabled and disabled-model rediscovery assertions in safe test conditions.

Rollback must not blindly restore vulnerable grants or auto-enabling discovery.
For an application regression, stop rollout, retain restrictive ACLs where possible,
and review a narrowly scoped correction. No production rollback script is executed
or implicitly approved by this package.

## Evidence and outstanding gates

Source regressions: `supabase/tests/pr82_privilege_discovery.sql` and
`supabase/tests/pr82_appointment_contract.sql`. CI clean-schema executes both after
the active migration lineage and also uses real GoTrue/PostgREST appointment
receipts, concurrency and cross-user authorization checks. Native PostgreSQL tests
use explicit SQL claim fixtures and cannot substitute for those authenticated tests.

Historical E2E remains **31 weak / 5 failed**, independent earlier UI smoke **5
passes**, authenticated browser scenarios **8 blocked**. Do not restore 36/36 PASS.
Code remediation, remote disposable CI and hosted alignment are separate verdicts.
Production remains NO-GO until separately authorized deployment and verification.

References checked during remediation: [PostgreSQL privileges](https://www.postgresql.org/docs/17/ddl-priv.html),
[Supabase API grants and RLS](https://supabase.com/docs/guides/api/securing-your-api),
[explicit table exposure change](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically).
New tables already receive explicit grants and RLS. Managed creator defaults are
not changed based on self-hosted Studio guidance, which excludes hosted/CLI use.
