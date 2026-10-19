# Phase 2 and 4 backend contracts

All additions are additive to RC `2e0d089781ef3de582143421a59817094e57ca78`. No presentation/AI-domain change is required. Migration `20261018211645_phase24_mock_checkout_and_crm_search.sql` was created with Supabase CLI 2.119.0. Its fixture is **100 fictional TST units for 30 days**, with a 15-minute confirmation window. These values are test inputs, not a price, currency offering, financial promise or merchant contract.

## Owner billing mock

Call through PostgREST with the original authenticated user's JWT and a public API key:

| RPC | JSON arguments | Behavior |
| --- | --- | --- |
| `create_mock_checkout` | `p_request_key`: caller-generated UUID | Derives owner from `auth.uid()`. Same owner/key returns the same order; concurrent creation is serialized per owner. Maximum 10 new orders/hour and 100 total per user. Caller cannot supply identity, price, currency or duration. |
| `get_mock_checkout` | `p_order_id`: UUID | Owner-only order/billing state. Another owner, including an admin, receives the same 404 as an unknown order. |
| `request_mock_checkout_cancellation` | `p_order_id`: UUID | Idempotent owner request. Pending order becomes cancelled immediately. Confirmed order records the request and retains mock access until signed cancellation/refund or expiry. |

Response fields: `mode: mock`, `no_charge: true`, `order_id`, `subscription_id: mock:<UUID>`, `status`, `amount_minor`, `currency`, `period_end`, `expires_at`, `cancellation_requested`, `mock_access_active`, `canonical_paid_access: false`. There is no checkout URL or card-data collection. Direct private-table access and service-role execution of owner RPCs are revoked. Authentication failure is 401/403; missing/foreign order 404; invalid argument 400; limit 429; disabled creation/cancellation 503. Explicit `PTxxx` errors follow the [PostgREST error contract](https://docs.postgrest.org/en/stable/references/errors.html).

`private.payment_sandbox_config.enabled` defaults false and gates creation, cancellation and computed access. Reading an existing order does not require activation. `mock_access_active` additionally requires a confirmed order, matching active sandbox subscription and future period end. It grants no canonical paid AI quota. `public.ai_entitlements` is never written by these flows.

Confirmation reuses the existing **loopback-only**, default-disabled `/payment` synthetic HMAC callback. See `supabase/functions/payment-sandbox/handler.ts` for the strict event schema. The signature is `x-rad-sandbox-signature: t=<Unix seconds>,v1=<hex HMAC-SHA256(secret,timestamp.raw_body)>`, accepted within 300 seconds. Identity, amount, currency and stored period are bound to the mock order. Exactly one capture is permitted per order. Renewal requires a new mock order. Full refund/chargeback requires a previous capture; pending refunds and partial refunds are rejected. Cancellation events use amount zero. Terminal refund/chargeback cannot be changed to cancellation. Stale/terminal callbacks cannot activate access. Event ID/hash conflicts are rejected; exact retries deduplicate atomically.

Malformed callback 400, bad/stale signature 401, semantic database rejection 422 with fixed `sandbox_event_rejected`, unavailable/timeout 503 with fixed diagnostics. Persistence has a 15-second deadline and abort signal. A timeout after commit is ambiguous; retry the **same event ID and payload**, never invent a replacement transaction. SQLSTATE 22023/23503 are permanent semantic rejections; unexpected database errors remain retryable 503. Raw database details never leave the handler.

## CRM search

`search_admin_consultations(p_query text='', p_status text=null, p_limit integer=25, p_offset integer=0)` returns a bounded JSON array of existing consultation fields plus revision. Only profile-authorized admin/super_admin callers may use it. Query length is at most 200, limit 1-100, offset 0-10000, status one of submitted/in_review/contacted/closed. Case-insensitive **literal** topic/message substring search treats `%` and `_` as data. Results order by created_at descending then UUID descending. Existing revision-checked transition/assignment APIs and their audits remain unchanged.

## Sandbox notification dispatch

`notification-dispatch` now has an Edge entrypoint with gateway `verify_jwt=true`. POST additionally requires purpose header `x-rad-notification-token`, matching `RAD_NOTIFICATION_WORKER_TOKEN` (32-512 characters). A user/service JWT alone cannot dispatch. `RAD_NOTIFICATION_SANDBOX_ENABLED` defaults false. The handler accepts only loopback targets or `APP_ENV=staging` plus explicit nonproduction `RAD_STAGING_PROJECT_REF` matching the canonical Supabase URL. No production target is accepted.

JSON is empty object or `{ "limit": 1..20 }`, default 10, maximum 4 KiB, no other keys. Existing SKIP LOCKED leases, attempt limits, consent rechecks and fenced acknowledgements remain authoritative. Dispatch has a 10-second database deadline and abort signal. It uses a no-op transport and records **sandbox receipts**, never actual email/SMS/push delivery. Disabled/unsafe target 503; missing/wrong purpose token 403; malformed 400; oversized 413; unavailable/timeout 503. Responses do not contain lease tokens or raw database errors. After ambiguous timeout, allow the existing lease expiry/retry policy to recover work.

The loopback test harness exercises the enabled handler factory with Auth/PostgREST/outbox through ordinary Deno HTTP. A separate actual local Edge Runtime 1.77.1 smoke verifies forged-JWT 401 and default-disabled 503 with valid anon/service JWTs. Hosted Edge behavior and external transport delivery remain unverified.

## Owner activation dependencies

Every item below is **BLOCKED_BY_OWNER**. No external action has been executed.

- Isolated staging project/ref, public/backend keys, TLS DB URI, Auth site/reset/native redirects, synthetic smoke accounts, backup/restore record, rollback artifact and deployment authorization.
- Selected merchant/provider and versioned create/confirm/cancel/refund/webhook API contracts; supported currencies/countries, prices, taxes, invoicing/legal/store rules, renewal/proration/refund policy and webhook acknowledgement/retry policy.
- Sandbox merchant account, server API key, webhook signing secret/algorithm/timestamp tolerance, registered callback URL, provider event/transaction IDs and idempotency scopes. Supply secrets outside Git/frontend builds.
- Explicit approved mapping from verified merchant products/statuses to canonical paid entitlements, expiry, revocation, chargeback and reconciliation. Mock access cannot be used as that mapping.
- Notification provider/channel, credentials, verified sender, recipients/consent, regional policy, provider idempotency, delivery receipts/bounce/retry classification and activation approval. A sandbox receipt cannot be reported as real delivery.
- Hosted Edge gateway smoke, real staging combined frontend/backend tests and final owner acceptance. Production remains read-only; no real transaction is permitted.
