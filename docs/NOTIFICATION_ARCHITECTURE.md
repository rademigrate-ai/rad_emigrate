# Notification Architecture
IN_APP: notifications table + /notifications UI + mark read
EMAIL_TRANSACTIONAL: not product-implemented beyond Auth
SMS_TRANSACTIONAL: not configured (Stage 6 otp_disabled)
PUSH: push_subscriptions table exists; delivery provider external
create_user_notification RPC for admin/service

Local proposal: `notification_deliveries` is a sandbox-only outbox. Owners may enqueue their own notifications after explicit channel opt-in; workers claim/finish through service-only RPCs with leases, capped retries and idempotent keys. Preferences add `sms_enabled` (false) and `time_zone` (UTC); quiet hours use that explicit IANA zone, including midnight wraps. Revocation is rechecked at claim and acknowledgement. No email/SMS/push network adapter or external delivery is enabled. Sandbox receipts are explicitly labelled `sandbox_delivered`. See `releases/LOCAL47_BACKEND_CHECKPOINT.md` and the local SQL/Deno tests.
