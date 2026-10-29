# Master finalization: verified candidate and remaining release gates

Implementation candidate: `0a470a4a3ca21978b87b33fab204dd386b3f2c9b`.
Owned branch: `exec/pr82-backend-finalization-20261025`.
PR82 integration remains `7fe6710212b7d82cff2738f21f5d44dac49827d8`.
Main remains `16810a583ad4544d87f289bd16984c0e758a1515`.

**Production: NO-GO.** No Production writes, deployment, model toggle, history
repair, main merge, forced push or modification of peer worktrees occurred.
The owner conditionally authorized Production only after every release gate;
the conditions below remain unsatisfied. This is not a completed deployed release.

## Implemented and verified

Five new forward migrations supplement the existing F01/F02/F15 corrections:

| File under `supabase/migrations/` | Purpose | Operation-based regression |
|---|---|---|
| `20261025193232_pr82_profile_insert_policy_guard.sql` | F16 own-profile bootstrap permits only user, with owner/policy/RLS preconditions | `pr82_profile_bootstrap.sql` |
| `20261025195326_pr82_legacy_request_receipt_integrity.sql` | F04 private immutable original-input ledger; keyed Booking/Interview changed-body retry returns PT409 | `pr82_legacy_request_receipts.sql` |
| `20261025200025_pr82_function_default_execute_guard.sql` | Narrow postgres creator defaults globally and in public/private; retain explicit RPC grants | `pr82_function_defaults.sql` |
| `20261025202614_pr82_profile_upsert_compatibility_guard.sql` | F17 exact shipped profile upsert works with only INSERT(updated_at)/UPDATE(id); invoker trigger keeps client identity immutable, timestamp server-issued and role writes denied | `pr82_profile_upsert.sql` |
| `20261025211256_pr82_search_head_delete_invalidation.sql` | F10 internal head deletion removes only its locale projection and invalidates published search cursors | `pr82_search_head_delete.sql` |

F17 was reproduced as HTTP403 in actual Chromium profile completion and in exact
merge-upsert SQL before the fix. The same browser path persisted successfully
afterward. F10 was reproduced before correction, applied twice natively, and
tested with published/unpublished heads, independent locales and direct ACLs.
Historical migration files were not rewritten. Full eight-dimension core
fingerprints remain enforced; policy and trigger changes were independently
derived and the stale Python expectation was corrected.

Antigravity PR83 commit `94db36e6f1767646cbdcfb044c6628441b0c591a` was reviewed
and merged only into this isolated candidate, preserving its commit/author.
Codex did not edit Flutter files or the Antigravity/Grok worktrees. No final
independent reviewer approval is inferred from this integration review.

## Exact verification boundaries

Implementation CI: [8/8 success at 0a470a4](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/40234569594).
This includes clean Supabase, additive lineage reconstruction, actual
GoTrue/PostgREST/Storage/quota-concurrency acceptance, all five new SQL suites,
Flutter, Web, Android, content, routing and repository checks. The prior
combined candidate b766220 also passed 8/8. The earlier c45b5dc run failed on
a stale test hash; that failure is retained and not relabelled successful.

Local combined Dart tree b766220: format/analyze, 1,075 Flutter, 158 Deno and
127 Python tests, release Web configured for staging and Android arm64 debug
all passed. 0a470a4 changes SQL/CI only; its exact-SHA CI build passed. Native
PG17.11 reconstructed all 94 files and ran 28 SQL suites successfully. Native
Auth/Storage/Vault/cron are explicit fixtures. Shared WSL/Docker/PG services
were not restarted or reset.

Actual dedicated staging acceptance, using server-validated synthetic JWTs:

- User A/User B/Admin login, refresh and profile authorization; forged editable
  metadata does not grant Admin rights; A/B application isolation.
- Appointment UUID contracts, same-key concurrent replay, changed-body conflict,
  malformed UUID, owner fences and cancellation boundaries.
- Legacy Booking concurrent keyed replay and changed-body rejection; unkeyed
  calls intentionally retain legacy semantics.
- CMS server hash/version conflicts; ordinary-user approval/publishing denial;
  unpublished public article/search exclusion and unapproved publish denial.
- Chromium Admin login/profile completion, dirty discard/back cancellation,
  save/review/explicit approval/explicit publication of a labelled synthetic
  non-legal fixture. Editorial approval preserves verification_state=unverified.
- Same-tab SPA A logout -> B login -> actual B Cases URL/empty state, with no A
  case. An earlier route-only harness result was rejected and preserved.
- AI Edge Function deployed **only to staging**, verify_jwt=true, exact source
  file hashes retained. Real v1 UUID replay/conflict/malformed requests,
  ordinary Admin-scope denial, no-JWT denial and B consent not authorizing A's
  case all pass. No configured providers/models or paid AI calls.
- Approved free FX fallback retrieval/caching/public conversion and IRR/toman
  arithmetic; source provenance retained. No Iranian free-market quote/provider.

Some browser actions required semantics activation, field focus, realistic input
delivery and navigation timing. Screenshots alone and routes displaying profile
completion are not accepted as successful business workflows. The evidence
package preserves rejected harness attempts separately from final assertions.

## Dedicated staging state

Project `epolbumcfbohtmgvomki`: 43 original ledger records were reproduced, then
missing source effects reconciled in one atomic staging-specific bundle with
SHA256 `a3e379b4e767a1a1256c25c705323c640067e5d2619003e810ec3daf92c7f482`.
The incompatible old empty search table was preserved in an inaccessible
schema. No reset, historical repair or RLS disable was used.

Final staging has 49 recorded migrations, 82 public application tables with RLS,
199 final application function bodies/contracts matching the clean native
source, zero of 656 prohibited non-row privileges and zero column REFERENCES
violations. Trusted service_role defaults explain the separately recorded ACL
differences; no anon/authenticated difference is hidden by that classification.
All original three Auth/profile rows and model/provider/Storage hashes are
preserved. Three additional owned synthetic users and clearly labelled workflow
fixtures are retained for review. All three cron definitions remain inactive.

The per-original-file matrix has 94 rows: 92 COMPLETE for reconciled final
schema effects, two PARTIAL because background scheduling is deliberately
deferred. Historical overridden policies/functions are not expected to remain
installed. Data equality is not inferred from object presence. Every source hash,
statement decision, applied chunk and transaction boundary is retained externally.
The F16 source acquired an additional RLS precondition after its first staging
application: predicate parity and independently verified RLS are proven; byte
identity of that earlier application is not claimed.

## Production reconciliation and security disposition

Fresh read-only evidence confirms 54 ledger rows, 57 public application tables
with RLS, three Auth/profile users, five Vault entries, two Storage objects,
721 models/702 enabled and three providers. Critical ledger/Auth/Vault/policy/
RPC/model/provider fingerprints remain unchanged from the prior forensic package.
Secret values were neither read into delivery artifacts nor exported.

The current repository has 94 files, compared with 89 at the earlier review.
Against the 54-row live ledger: 27 exact identities, 17 version/name aliases,
six embedded-version names, two semantic renames and 42 without a one-to-one
identity. The original 86/54 claim was a stale/different source baseline; neither
32 nor the current count difference is a safe replay queue. Live-only records,
SQL fingerprints and superseded effects are included in the forensic matrix.
Only 51 of 199 final application functions exist live; matching signatures are
not full schema compatibility. 34 raw bodies match; lexical variants are
separately classified by the original review, not treated as automatic defects.

| Finding | Severity | Current status |
|---|---|---|
| F01 | P1 | Backend/client adapter, native and actual HTTP/CI contracts corrected; full interview UI acceptance remains distinct |
| F02 | P1 | Staging/source fixed; Production still has 48 prohibited effective grants across the six recorded tables |
| F03 | P2 | Historical weak evidence retained; new authenticated receipts/screenshots supersede only the scenarios actually rerun |
| F04 | P2 | Keyed backend integrity corrected; staff Booking client still omits stable p_idempotency_key |
| F05/F06 | P2 | Actual CMS lifecycle and dirty-state browser paths pass; browser reload/tab-close protection not claimed |
| F07 | P2 | OPEN frontend evidence/date/official-assurance contract and wording |
| F08 | P2 | Five operation-based SQL regressions wired and executed; weaker historical source checks remain complementary |
| F09 | P3 | This handoff supersedes stale app_metadata/in_review prose: authority is profiles.role and state is review |
| F10 | P3 | Corrected and tested, including staging rollback-only SQL; no public delete API added |
| F11 | P3 | CMS dialog disposal partly corrected; source-monitor discovery dialog, async fences and Admin localization remain frontend follow-up |
| F12 | P2 | OPEN legacy related-article tuple selector; UUID public selector remains compatible |
| F13 | P3 | pg_net remains in public; dependency-aware operational review required |
| F14 | P2 | Leaked-password screening disabled; actual signup/reset email delivery not verified |
| F15 | P1 | Source/staging preserves disabled approval/configuration; Production still uses old discovery body |
| F16 | P1 conditional | Missing-profile privileged insertion denied in source/staging; live legacy conditional gap remains unreconciled |
| F17 | P1 | Shipped profile completion compatibility corrected and tested; not installed in Production |
| H01 | P1 integration gate | Stage RLS/privileges/RPC boundaries pass; full Production dependency transition is not approved/rehearsed as a restored project |

Exact unresolved frontend references at PR83: `article_change_highlights_banner.dart:30,38,188`,
`canonical_pathway_entities.dart:340`, `canonical_pathway_repository.dart:92,107`,
`booking_repository.dart:230`, `admin_cms_canonical_editor_page.dart:788,808`.
Contracts and requested fixes were sent through the
[authorized PR83 coordination channel](https://github.com/rademigrate-ai/rad_emigrate/pull/83#issuecomment-6403425499).
No frontend-owner response or independent approval has been fabricated.

## Operational stop gates and next authorized handoff

1. Obtain an adequate Production recovery artifact and perform a practical,
   independently reviewed restore with Auth identities, Storage payloads,
   Vault encryption dependencies, roles/ACLs and approval state. Native restore
   of 110 synthetic tables passed; it is **not** a Production backup or RTO/RPO.
2. Independently review the exact forward SQL, Production preflight baseline,
   full dependency transition and restore/rollback procedure. The staging bundle
   must never be used on Production. No blanket migration push or history repair.
3. Antigravity corrects F04/F07/F12 and the remaining selected Web acceptance
   gaps through its PR. Rerun affected browser journeys and full integrated CI.
4. Verify signup/verification/reset using a controlled mailbox, redirect origins
   and supported Auth password screening. Free organization tier is verified;
   no upgrade, cost or unsupported Auth-setting claim is authorized here.
5. Configure/review required main protection and independent reviewer workflow:
   GitHub currently returns protection404 and an empty ruleset list. A green
   Actions run is not branch protection or independent approval.
6. Record exact artifact/build/environment/secret-name bindings, operational
   alerting, worker token rotation/consent/channel policy and rollback ownership.
   Workers stay inactive until their prerequisites pass. No push/email/SMS
   delivery, release Android signing or iOS/Xcode build is claimed.
7. Only after every gate, rebaseline live fingerprints and exact reviewed SHA,
   then use the owner's conditional release authorization through the normal
   protected mechanism. Any drift, failed test, unclear execution, privilege
   widening, legal-evidence ambiguity or missing recovery proof is an exact STOP.

The local final delivery package contains the 94-file matrices, raw metadata,
source/transformed SQL hashes, actual browser/API receipts, CI matrix, native
restore result, proposed minimal F02/F15/F16 procedure, incident runbook and owner
checklist. It deliberately excludes credentials, sessions, browser profiles,
private recovery dumps and service keys. This document does not authorize a
Production action while a gate remains open.
