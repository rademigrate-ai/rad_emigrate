# RAD — Payment Architecture & Financial Integrity Report (2026-10-18)

**Scope:** Gates 36 to 38 (Epic E7: Payments and Subscriptions)  
**Author:** Codex (Financial Systems & Security Engineer)  
**Status:** ARCHITECTURE DESIGNED — REAL CHARGES STRICTLY NO-GO

---

## 1. Executive Summary

This report defines the security, idempotency, and regulatory compliance requirements for payments and subscriptions within RAD Emigrate. Per owner authorization rules:
**Zero live financial transactions or paid infrastructure provisioning are authorized.** All activities remain restricted to sandbox designs and mock verifications.

---

## 2. Gate Verification & Technical Status

### Gate 36: Payment Provider Selection & Store Compliance (`BLOCKED`)
- **Regulatory & Geography Context:**
  - Services catering to international Iranian applicants must comply with international payment compliance, sanctioned territory rules, and local merchant regulations (e.g. Shaparak / Shepa / ZarinPal for domestic IRR transactions, or licensed international PSPs for diaspora users).
  - Apple App Store Guideline 3.1.1 (In-App Purchase) and Google Play Billing requirements apply if digital AI question quotas are sold within native apps.
- **Current State:** No merchant contract, payment gateway agreement, or banking credentials exist in current evidence.

### Gate 37: Subscriptions, Billing, Webhooks, and Taxes (`BLOCKED`)
- **Architecture Requirements:**
  1. **Webhook Signature Validation:** Secret HMAC-SHA256 verification of all incoming webhook payloads before processing.
  2. **Idempotency Keying:** Webhook events record `event_id` in a dedicated `payment_webhook_events` table with unique constraint to prevent replay attacks and duplicate credit allocations.
  3. **Cancellation & Expiry Lifecycle:** Synchronized downgrading of AI tiers upon subscription lapse.
- **Current State:** Sandbox webhook handlers and plans are staged in architectural contracts (`docs/AI_ENTITLEMENT_CONTRACT.md`); live test endpoints await approved merchant sandbox credentials.

### Gate 38: Entitlement Financial Integrity (`IN_PROGRESS`)
- **Core Security Rule:** **No client-controlled payment success flags.**
  - An authenticated client cannot directly toggle its own quota or subscription status via client-side Supabase updates.
  - Entitlement grants are strictly server-controlled through database RPCs callable only by `service_role`.
- **Integrity Edge Cases Addressed in Design:**
  - Out-of-order webhook delivery (subscription charge before account creation).
  - Refund / chargeback revocations immediately reset the user's quota tier.
  - Concurrent webhook retries fail closed on unique transaction constraints.

---

## 3. Financial Safety Assessment

- The financial isolation and server-side entitlement architecture prevent unauthorized privilege escalation.
- Real payment processing remains strictly **NO-GO** until approved merchant contracts and sandbox credentials are provided by the business owner.

