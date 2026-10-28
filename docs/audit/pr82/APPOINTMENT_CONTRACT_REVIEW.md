# Interview correction: implementation and owner review handoff

Baseline F01: Flutter used Plan2 canonical request RPC names with incompatible
named arguments and response fields. A real SQL call reproduced 42883; success
mocks concealed it. The fix preserves those existing canonical functions and adds
an explicitly registered table-shaped adapter in
`supabase/contracts/appointments_v1.json`. It does not change `rad_v1.json` or its
closed p_request envelopes/generated Dart definitions.

| RPC | Named request parameters | Response |
|---|---|---|
| list_rad_appointments | none | owned receipt array, newest first |
| submit_rad_appointment | p_title text, p_start_utc timestamptz, p_end_utc nullable timestamptz, p_time_zone nullable text, p_notes text, p_idempotency_key uuid | exactly one persisted receipt |
| reschedule_rad_appointment | p_appointment_id uuid, p_start_utc timestamptz, p_end_utc nullable timestamptz, p_time_zone nullable text, p_notes text | one owned rescheduled receipt |
| cancel_rad_appointment | p_appointment_id uuid, p_reason text | one owned cancelled receipt with persisted cancellation_reason |

Auth: authenticated EXECUTE only; server subject ownership; Admin has no special
cross-owner appointment power; anon/service_role/PUBLIC denied. Private serializer
is not client executable. Table RLS and revoked direct mutation privileges remain.
Receipt ID/owner/kind/status/time/title/notes/zone are checked by Flutter; cancel
also checks the persisted reason. Empty/malformed/wrong-owner/wrong-operation
receipts cannot be acknowledged. Session changes fence late responses.

States: submitted→requested; pending_confirmation→inReview; remaining canonical
states retain their names. Preferred times are requests, never embassy availability
or confirmation. Owners can reschedule non-terminal requests and cancel all except
completed requests; they cannot confirm or complete. SQL tests cover named pg_proc
arguments, owner isolation, validation, retry conflict and terminal-state denial.

Retry: owner-scoped UUID key and transaction advisory lock serialize concurrent
submissions; identical requests return the persisted row, changed body conflicts
with PT409. Flutter retains the key after uncertain outcomes within repository
lifetime. Browser restart persistence is not implemented. After a request changes
state/time, list is the recovery path; a mismatched original submit retry fails
closed. Reschedule with null/blank time zone preserves the existing zone, matching
the canonical SQL semantics.

Errors: 42501 auth/privilege; 22023 invalid input/terminal state; P0002 hidden or
missing owner row; PT409 changed key/body; PostgreSQL 22P02 malformed UUID. Lists
retain existing unpaginated behavior. Legacy untimed canonical requests cannot be
represented by Flutter's required DateTime and remain fail-closed; no date is
invented. Optional legacy title falls back to a generic request label.

Coordination channel is this ChatGPT RAD project conversation. This concrete
implementation is submitted for Antigravity/frontend and backend owner review;
no peer response or approval is inferred. The owner authorized reviewed local
corrections to PR82, not merge/Ready/Production. Existing P2 CMS/UI findings and
authenticated browser gates remain open. Source PRs 78–81 are not modified.
