# RAD Emigrate — not yet ready for manual deployment

This continues PR #89 after the owner reported manual application login. Firefox
automation and browser credentials/session storage are not used. No Restore,
recovery project, new backup workflow, paid resource or frontend deployment is
authorized by this delivery. No hosted write was performed.

## Corrected content and publication package

The original C9 package is immutable. A separately sealed version contains the
four supported Dubai-to-AE associations, preserving article identities, full draft
bodies, original sources and every existing head precondition:

`4beb6ba711c5b0243d69be29b32a76c13f5ebcc47ce131e7ca406bcd67e6c282`.

| Measure | Prepared / independently verified | Actually executed |
| --- | ---: | ---: |
| Article/locale operations | 1,100 | 0 imports |
| Body-preserving country corrections | 4 | 0 hosted updates |
| Initial / detached / mechanical draft operations | 406 / 443 / 249 | 0 |
| Selected draft imports | 1,098; 2 substantive alternatives retained | 0 |
| Publication candidates | 1,077 | 0 approvals / publications |
| Bounded batches | 44, maximum 25 members, article locales kept together | 0 |
| Current publication holds | 23 | All remain unpublished |
| Proposed countries / neutral Other Titles | 56 / 251 | 0 new published coverage |
| UAE-associated candidates | 11 | 0 published |
| Captured source identities / unique source blocks | 2,454 / 60,576 | Offline evidence |
| Source-to-destination occurrences | 61,991 | Proposed revision bindings |
| Changed source text / consolidation decisions | 0 / 0 | 0 |

All 27 former hold identities were reconsidered. Four routing exceptions are
resolved in the new package. The other 23 comprise the original 16 editorial
holds and seven article/locales affected by eight teaser indexes and one article
with a publisher update notice. The original 17 numeric candidates across 15
operations remain preserved with full source context; section-level number sets
do not establish equivalent competing claims. Source priority cannot erase a
different year, amount, qualification or condition. Both substantive current-body
alternatives remain preserved, including the UAE case whose 65 unmatched blocks
are globally represented but still require destination reconciliation.

The 23 holds do not declare the remaining candidates approved. They also do not
require 1,100 individual manual reviews: the rebuilt batches retain empty review
notes for the genuine editorial Admin. The original source policy remains
`RAD_CONTENT_PRECEDENCE_V4.1`, including independent RadMohajer identity.

The 38,269-known-URL register and original 421-gap ledger remain intact. Two prior
complete recoveries are reproved; 64 capture classifications and 355 URLs without
verified complete bodies remain separately accounted for. No new full body was
invented or recovered. Captured body records, teaser indexes and historically
complete authored articles are distinct categories. Previously reproduced raw
block/link evidence remains bound to its original captures.

Independent verification reads original and corrected operations separately,
checks every batch file/manifest/payload hash, rebuilds article associations, and
regenerates the complete source-to-proposed-revision crosswalk. All four corrected
revision IDs change; all unchanged operation payloads remain identical. No revised
source text or deduplication policy is introduced.

## Additional CMS protection, not installed

`20261103114340_rad_corrected_source_editorial_admission.sql` adds the exact new
package/source-proof admission plus immutable private publication holds: 27 for
the stale original package and 23 for the corrected package. A new invoker trigger
refuses a source-faithful event for an exactly held journaled revision. RLS is
enabled; client and service-role table/function grants are revoked. Existing
source approval, role, hash, factual-verification and media protections remain.
It approves and publishes nothing and introduces no SECURITY DEFINER function.

The migration bytes match the separately generated review SQL:
`577edecce2b0fe90bf2308c91add8a301976232b5a95d822374c7dae39c150b0`.
Native PostgreSQL regression checks reject held approval, verify no failed event
remains, reject hold mutation and confirm private grants/RLS. CI also runs this
regression against the complete clean schema rather than relying on a skipped
private fixture.

Required future order remains: approved core closure, allocator, guarded import,
exact preservation readback, original source-faithful publication migration,
this additional admission/hold migration, verified real Admin batch approval,
publication and actual public content acceptance. None was applied to Production.
The old 44-batch proposal set must not be used as the corrected release plan.

## No-Restore technical and authorization review

The current live catalog matches the earlier baseline across 100 function and 86
table metadata records. The reviewed core SQL hash remains
`ec77fd4bba84b703a0d2994c3ce8da8112ca969a8f2a478de8061b500f675f69`.
Its matching manifest identifies 76 new function definitions and 12 existing
function metadata changes; seven change the function body, while five retain the
body. The 83 function statements therefore do not mean a purely additive release.
An existing profile-role guard and public reader are among the changed bodies.
Production lacks `pg_trgm`, which the closure would create; six enabled event
callbacks remain bound only by metadata and hashes, without operator attestation.

| Candidate mechanism | Verified value | Limit for this release |
| --- | --- | --- |
| Consistent read-only preflight | Eight source/editorial rowset fingerprints plus catalog/endpoint bindings | Hashes cannot recreate data; no complete Auth/Storage recovery capability is established |
| Transaction, locks and exact preconditions | Existing native tests exercise atomic failure, immutable imports and exact retry | Protects the transaction before commit; does not prove reversal of committed schema/callback effects |
| Ordinary existing CMS APIs | Actual function definitions reviewed | Save advances a head; existing creation/publication cannot replace the detached, neutral source-faithful contract |
| Existing guarded import compensation | **Supported**, with exact fingerprints and ownership/FK checks | Refuses later writes/references or catalog drift, requires separate authorization, and temporarily disables five append-only guards for owned-row deletion; it is not a full CMS/publication reverse procedure |
| Standard article rollback | Actual private implementation calls draft save | Advances a head and does not restore an originally NULL publication pointer |
| Source batch unpublication | No supported RPC installed | No accepted post-publication compensating path for this case |
| New no-Restore operational policy | Investigation and conditional execution are authorized | Independent full-scope equivalence acceptance and operation-specific callback review are absent |

The available evidence does **not** establish an equally protective, fully
authorized no-Restore execution procedure. The existing renderer's real checkpoint
and Restore receipt checks remain unchanged; no alternative success flag or
synthetic approval was introduced. A Restore is not asserted to be a universal
PostgreSQL requirement. Replacing this particular release policy requires genuine
independent acceptance of the actual full-scope compensating design and callback
effects, followed by a correctly enforced execution contract. Owner agreement to
an unproved draft cannot supply that technical evidence.

PostgreSQL documents that [ROLLBACK aborts the current transaction](https://www.postgresql.org/docs/17/sql-rollback.html)
and [event triggers run for their configured database events](https://www.postgresql.org/docs/17/event-trigger-definition.html).
Those mechanisms alone do not establish this release's after-commit recovery
acceptance. Supabase also distinguishes [database backups and Storage object bytes](https://supabase.com/docs/guides/platform/backups).
No Restore or backup experiment was performed to fill those gaps.

The minimum unresolved dependency is an independently accepted no-Restore
operational procedure covering the changed functions, extension/callback effects,
import and publication reversal, with exact package/endpoint authorization and
genuine editorial actor receipts. No approved replacement procedure was found in
the inspected private evidence; synthetic callback policies are not substitutes.

## Authentication, public acceptance and security

The owner reports successful manual login. Supported server inspection confirms
two existing editorial Admin profiles, while the management connection has
`auth.uid() = NULL`. This neither identifies nor disproves an existing browser
session. No browser tokens are read and no JWT/GUC actor is forged. A real CMS
operation receipt must establish the actual authenticated editorial actor.

Production still has 72 migration entries, 745 heads, 747 revisions and zero
publications. The country, library, rich reader and source approval/publication
RPCs are absent. No migration, import, approval, publication or Feed write was
performed. Anonymous public API readback is recorded separately from unit tests;
the absence of published content prevents full application acceptance.

Current provider advisors include private RLS tables with no client policy,
expected callable definer RPCs, existing `pg_net` in `public`, and disabled leaked
password protection. These are recorded rather than reported as zero findings.
The callable RPC findings require the actual auth/published-only contracts tested
here, not a blanket grant/revoke change. References:
[private RLS findings](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
[extension placement](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public),
[anonymous definer RPCs](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable),
[authenticated definer RPCs](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable),
[password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## Build preparation and conditional owner deployment

The Render build now validates public-only configuration before compilation and
checks the compiled origin/key class, exact commit metadata, SPA fallback, every
artifact for credential patterns and a deterministic artifact tree hash. CI runs
the same script using non-Production configuration. A local Production-configured
build is a prepared artifact, not a deployment or proof of published content.

After all Production/public acceptance gates pass and PR #89 is legitimately
merged, the owner selects the exact merged commit on the existing Render service,
sets `APP_ENV=production`, the exact Production Supabase URL and public publishable
key, runs `bash scripts/build_web_render.sh`, and publishes `build/web` manually.
Retain the configured `/*` rewrite to `/index.html`; verify `/version.json`, deep
links, country/Other Titles discovery and full public bodies after deployment.
Do not deploy this candidate while the release gates above remain open.

Android debug and signed release acceptance remain distinct. CI's Android debug
build is not a signed release; permanent application identity and signing are
separate Android delivery requirements, not falsely certified by a web-only build.

Final commit, test/build logs, exact CI run, branch-rule readback limitations and
unmerged PR status are bound in the private `FINAL_READINESS_REGISTER.json` under
`D:\RAD - Emigrate\_audit\RAD_MASTER_CONVERGENCE_20261031\final-publication-readiness-20261103`.
That directory also holds the corrected package, independent crosswalk,
`package-independent-verification.json`, and `NO_RESTORE_TECHNICAL_REVIEW_V2.json`.
The preliminary no-Restore review's false support-flag statement is explicitly
superseded by V2; guarded import compensation is supported within its stated scope.
