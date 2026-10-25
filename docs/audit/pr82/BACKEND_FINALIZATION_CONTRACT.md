# Backend finalization contract and review handoff

Base integration: `7fe6710212b7d82cff2738f21f5d44dac49827d8`.
This is a backend change on an isolated Codex worktree. Antigravity owns Flutter.
Production remains unchanged and release is blocked pending the mandatory gates.

## Changes requiring independent review

* `20261025193232_pr82_profile_insert_policy_guard.sql`: F16 restricts the existing
  own-profile INSERT policy to `role=user`. It aborts on an unexpected owner or
  additional permissive INSERT/ALL policy. Existing column grants, UPDATE guards,
  RLS and user records remain unchanged. Trusted service provisioning bypasses
  RLS and still passes the server role trigger. This is suitable for review as a
  small forward change on the legacy schema; replaying the full foundation is
  unnecessary for this correction.
* `20261025195326_pr82_legacy_request_receipt_integrity.sql`: F04 binds new keyed
  Booking/Interview requests to original input in a private immutable-input
  ledger. Same-owner/key submissions serialize under the appointment adapter's
  existing advisory-lock convention. Changed input returns `PT409`. All original
  RPC argument names, default arguments and table-shaped results are retained.
* `20261025200025_pr82_function_default_execute_guard.sql`: remove global and
  schema-specific PostgreSQL creator defaults allowing client function EXECUTE.
  Supabase's explicit schema defaults are independent of global PUBLIC defaults.
  Existing RPC ACLs and service-role defaults remain unchanged. Managed creator
  defaults belonging to `supabase_admin` require a separate platform review.

## Booking and Interview compatibility

`submit_booking_request(p_service_id uuid, p_message text,
p_preferred_start_utc timestamptz = null, p_preferred_end_utc timestamptz = null,
p_time_zone text = null, p_idempotency_key text = null)` and
`submit_interview_request(p_notes text = '', p_preferred_start_utc timestamptz = null,
p_preferred_end_utc timestamptz = null, p_time_zone text = null,
p_locale text = 'en', p_idempotency_key text = null)` remain authenticated-owner
operations. Service and anonymous direct execution are denied.

Request keys are trimmed nonempty strings up to 200 characters. A UUID string
works for both these legacy operations and the existing UUID appointment adapter.
Frontend clients must retain the same key across uncertain retries and generate
a new key for changed input. Optional/unkeyed legacy calls remain supported and
do **not** receive idempotency protection. Antigravity must add this key to the
staff-scheduled Booking caller; this backend handoff does not claim that change.

The immutable input is normalized as follows: Booking message/zone are trimmed;
Interview notes retain exact text; locale preserves the existing fa/en fallback;
timestamps compare by Unix epoch, independent of session timezone. Inputs over
4,000 message/note characters are rejected instead of silently truncated.

Exact keyed replay returns the current persisted request with the same ID.
Later request status/rescheduling may be reflected in that receipt. The legacy
request ledger does not fabricate a confirmed slot or a historical price.
The appointment adapter keeps its existing stricter receipt comparison.

Historical keyed records without original-input evidence return `PT409` on
replay; no original request is guessed from a potentially edited row. Preserve
the old record, reload owner-scoped history and require an explicit new request
key if the user wants a distinct request. Error `42501` means unauthorized,
`22023` invalid input, and `P0002` unavailable service. Other original table
constraints remain enforced. No new public JSON field was introduced.

## Staging transition boundaries

### F17 profile completion compatibility

Real Chromium acceptance exposed an existing 403 in `completeProfile`:
the shipped PostgREST upsert includes `updated_at` on INSERT and `id` on conflict
UPDATE. Foundation grants intentionally excluded both. The forward migration
`20261025202614_pr82_profile_upsert_compatibility_guard.sql` grants exactly those
two column operations and adds an invoker trigger: client IDs are immutable and
client `updated_at` values are replaced with server time. Role write grants remain
denied; existing Admin role values survive the upsert; own missing-profile
bootstrap still defaults to user. The migration aborts if RLS/role-column ACL
prerequisites are absent. It neither changes existing rows nor grants table-wide
INSERT/UPDATE. No frontend file was edited.

The exact merge-upsert SQL shape fails before the correction and passes afterward,
including cross-owner, identity reassignment, timestamp spoofing and F16/privacy
regressions. Actual Chromium profile completion subsequently persisted and
restored the intended CMS route. This does not verify signup email delivery.

The appointment adapter retains the documented `P0002` missing/other-owner error.
Current PostgREST maps it to HTTP 500. Negative acceptance asserts that exact
SQLSTATE and absence of cross-owner changes; it does not count arbitrary 500s as
successful authorization tests. A coordinated future transport contract can use
an explicit not-found status without silently changing the existing error code.

Target: `epolbumcfbohtmgvomki`, never `inshddthftkhcdosoqcn`.
The historical 43-record staging lineage was reproduced using its recorded SQL,
then compared with a clean source reconstruction. The forward transition retains
the original users/profiles, preserves the incompatible old empty search table
in `staging_preserved_20261025`, constructs the canonical search shape, and maps
each original source file to reconciled effects. It does not reset schema or
repair migration history. All three job definitions are inactive pending worker,
secret, target and operational verification. The bundle is staging-specific and
must never be used as a Production migration.

Source SQL, transformed SQL, hashes, per-statement decisions, native/hosted
metadata and preservation receipts are retained in the finalization evidence
package outside the UI worktree. Native Auth/Storage/Vault/cron fixtures are
explicitly distinguished from hosted GoTrue/browser evidence.

## Required acceptance and remaining gates

CI runs `pr82_profile_bootstrap.sql`, `pr82_legacy_request_receipts.sql` and
`pr82_function_defaults.sql`; these use real operations with rolled-back
synthetic fixtures. F16 includes admin/super_admin, cross-owner, normal bootstrap,
user-metadata forgery and trusted provisioning. Receipt tests cover changed
input, exact replay, timezone-invariant instants, locale, private ledger denial
and owner-scoped keys.

Actual independent review is still required. Real staging-backed browser E2E,
remaining frontend P2 corrections, final integrated SHA/CI and practical
Production backup/restore proof remain release gates. Organization plan was
independently observed as Free; no upgrade or paid operation is authorized by
this document. Never treat native restore evidence as a Production restore.
