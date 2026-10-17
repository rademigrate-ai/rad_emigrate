# RAD EMIGRATE — APPLICATION SECURITY DEPENDENCIES & COMPATIBILITY ARCHITECTURE

**Commit Reference:** `19127c6` (`feat(security): reconcile consultation RPCs and atomic AI quota reservation`)
**Target:** Client (Flutter Web/Mobile) and Edge Functions (Deno) compatibility with PR #48
**Release status:** NO-GO. Safe client/Edge/DB cutover has not been proven; no zero-downtime guarantee.

---

## 1. OVERVIEW & MOTIVATION

The Stage 1 Database Security Hardening enforces strict database-level security boundaries:
- Removal of public/authenticated direct table `INSERT` on `consultation_requests`.
- Removal of table-wide `SELECT` and `UPDATE` on `consultation_requests` to protect internal `admin_note` fields.
- Atomic reservation of daily AI quota within advisory transaction locks.

If these migrations were applied while legacy application code was running, end users would immediately experience HTTP 403 / PostgreSQL `42501 (insufficient_privilege)` errors.

The compatibility shims narrow some failures, but do NOT prove zero downtime. The new Edge quota-reservation handler requires an atomic database RPC returning request_id; deploying it against the current count-only Production quota function will fail closed. Follow the corrected NO-GO cutover runbook before any production release.

---

## 2. DETAILED FILE COMPATIBILITY SPECIFICATIONS

### 2.1 Applicant Consultation Intake
- **Target File:** `lib/features/consultation/presentation/pages/consultation_page.dart`
- **Helper Module:** `lib/core/supabase/rpc_compat.dart` (`isRpcMissingException`)
- **Database Dependency:** Migration 4 (`20261012110945_stage1_security_abuse_storage_alignment.sql`)
  - Revokes `INSERT` on `public.consultation_requests` from `authenticated`.
  - Introduces `public.submit_consultation_request(p_topic text, p_message text, p_related_application_id uuid)` with advisory lock serialization and 3/hour, 10/day rate limits.
- **Implemented Architecture (Narrow Capability Detection):**
  ```dart
  // Stage 1 Security Hardening: Submit consultation request via RPC.
  // Fail closed on authorization errors, validation errors, rate limits, timeouts, and network failures.
  // Only fall back to direct table insert if the RPC is positively confirmed missing (PGRST202 / 42883)
  // during pre-migration deployment window.
  try {
    await client.rpc(
      'submit_consultation_request',
      params: {'p_topic': topic, 'p_message': message},
    );
  } catch (e) {
    if (isRpcMissingException(e)) {
      await client.from('consultation_requests').insert({
        'user_id': uid,
        'topic': topic,
        'message': message,
        'status': 'submitted',
      });
    } else {
      // Re-throw permission denied (42501), validation error (22023),
      // rate limit (P0001), timeouts, and network drops
      rethrow;
    }
  }
  ```
- **Deployment Safety & Security Hardening:**
  - **Pre-Migration:** `client.rpc` throws `PGRST202` (function not found); `isRpcMissingException(e)` evaluates to `true`, falling back safely to direct table `insert`.
  - **Post-Migration:** `client.rpc` succeeds. Rate-limited errors (`consultation_rate_limited` / `P0001`), validation rejections (`22023`), or authorization failures (`42501`) return `false` from `isRpcMissingException(e)` and are re-thrown immediately. **No unauthorized fallback or bypass occurs.**

---

### 2.2 Admin Consultation Management Console
- **Target File:** `lib/features/admin/presentation/pages/admin_consultations_page.dart`
- **Helper Module:** `lib/core/supabase/rpc_compat.dart` (`isRpcMissingException`)
- **Database Dependency:** Migration 1 (`20261010010000_stage1_p0_security_completion.sql`)
  - Revokes table-wide `SELECT` on `public.consultation_requests` from `authenticated` (omits `admin_note` from column grants).
  - Revokes direct `UPDATE` on `public.consultation_requests` from `authenticated`.
  - Introduces SECURITY DEFINER RPCs: `public.list_admin_consultations()` and `public.update_admin_consultation(p_consultation_id uuid, p_status text, p_admin_note text)`.
- **Implemented Architecture (Fail-Closed Admin Operations):**
  1. **Listing Tickets (`_load`):**
     ```dart
     List<dynamic> rows;
     try {
       final rpcRes = await client.rpc('list_admin_consultations');
       rows = rpcRes as List<dynamic>;
     } catch (e) {
       if (isRpcMissingException(e)) {
         rows = await client
             .from('consultation_requests')
             .select('id, topic, message, status, admin_note, created_at, user_id')
             .order('created_at', ascending: false)
             .limit(100) as List<dynamic>;
       } else {
         rethrow;
       }
     }
     ```
  2. **Updating Ticket Status & Notes (`_update`):**
     ```dart
     try {
       await client.rpc(
         'update_admin_consultation',
         params: {
           'p_consultation_id': id,
           'p_status': status,
           'p_admin_note': (note != null && note.trim().isNotEmpty) ? note.trim() : null,
         },
       );
     } catch (e) {
       if (isRpcMissingException(e)) {
         await client
             .from('consultation_requests')
             .update({
               'status': status,
               'admin_note': note,
               'updated_at': DateTime.now().toIso8601String(),
             })
             .eq('id', id);
       } else {
         rethrow;
       }
     }
     ```
- **Deployment Safety:**
  - Before Migration 1: Admin console loads and updates via legacy table operations if the RPC does not exist.
  - After Migration 1: Role-verified SECURITY DEFINER RPCs are required. Non-admin callers attempting access receive `42501` / permission denied, which fails closed and is rethrown. Direct table updates are rejected.

---

### 2.3 AI Orchestrator Atomic Quota Accounting & Strict Fail-Closed Policy
- **Target File:** `supabase/functions/ai-orchestrator/handler.ts`
- **Database Dependency:** Migration 2 (`20261010055013_stage1_atomic_ai_quota_reservation.sql`)
  - `public.consume_ai_daily_quota(p_user_id uuid, p_role text)` returns:
    ```json
    {
      "allowed": true,
      "count": 12,
      "limit": 50,
      "tokens_used": 1500,
      "token_limit": 100000,
      "request_id": "c1f8d9e2-..."
    }
    ```
- **Previous Fail-Open & Duplicate Insertion Flaws (Resolved):**
  The old handler swallowed quota errors, ignored the returned `request_id`, and then executed a duplicate direct `POST` to `ai_requests?select=id`. This caused quota bypasses on error and double accounting when successful.
- **Implemented Architecture (Fail Closed & Authoritative Reservation):**
  ```ts
  let requestId: string | null = null;
  if (user) {
    let quota: any;
    try {
      quota = await db("rpc/consume_ai_daily_quota", {
        method: "POST",
        body: JSON.stringify({ p_user_id: user.id, p_role: role }),
      });
    } catch (err) {
      // Fail closed on quota RPC infrastructure failure
      return safeJson(503, {
        error: "quota_check_failed",
        code: "quota_check_failed",
        message: "Failed to enforce AI daily quota reservation. Please retry.",
      });
    }

    if (!quota || typeof quota !== "object") {
      return safeJson(500, {
        error: "quota_reservation_invalid",
        code: "quota_reservation_invalid",
        message: "Malformed response received from quota reservation service.",
      });
    }

    if (quota.allowed === false) {
      return safeJson(429, {
        error: "daily_limit_reached",
        code: "daily_limit_reached",
        limit: quota.limit,
        count: quota.count
      });
    }

    if (typeof quota.request_id !== "string" || !quota.request_id) {
      // Strict fail-closed: require authoritative reservation ID
      return safeJson(500, {
        error: "quota_reservation_invalid",
        code: "quota_reservation_invalid",
        message: "Quota reservation succeeded but did not return a valid reservation request_id.",
      });
    }

    requestId = quota.request_id;
  }
  ...
  if (user) {
    ...
    if (requestId) {
      // Stage 1 Atomic Quota: attach session_id and update routing reason on the reserved row via PATCH
      try {
        await db(`ai_requests?id=eq.${encodeURIComponent(requestId)}`, {
          method: "PATCH",
          body: JSON.stringify(sessionId ? { session_id: sessionId, routing_reason: "ranked_eligible_pool" } : { routing_reason: "ranked_eligible_pool" }),
        });
      } catch {
        /* non-fatal metadata update error */
      }
    }
    // Note: Duplicate direct INSERT fallback into ai_requests has been completely removed.
  }
  ```
- **Deployment Safety & Invariant Guarantees:**
  - **No Quota Bypass:** Quota service failures fail closed with 503 instead of allowing unmetered inference.
  - **No Duplicate Records:** Exactly 1 `ai_requests` row is created per user interaction (by the atomic PostgreSQL RPC).
  - **Authoritative Lifecycle:** The reservation row transitions from `running` to `succeeded` or `failed` at the end of the inference pipeline.
  - **Independent Guest Quota:** Unauthenticated guest users continue through the independent guest quota check (`checkGuestQuota`).

---

## 3. REGRESSION TESTING COVERAGE

1. **Flutter Unit & Negative Acceptance Tests:**
   - `test/core/supabase/rpc_compat_test.dart`: 10 comprehensive tests verifying `isRpcMissingException`:
     - Positive matching: `PGRST202`, `42883`, "Could not find the function".
     - Fail-closed negative assertions: Rejects `42501` (permission denied), `22023` (invalid parameter), `P0001` (rate limit), `P0002` (no data found), `SocketException`, `TimeoutException`, `FormatException`, generic `Exception`.
   - `test/features/consultation/consultation_security_rpc_test.dart`: Verifies narrow RPC missing checks and removal of broad `catch (_)` fallbacks.
   - Full suite passes: **446 tests passing (100% green)**.
2. **Deno Edge Function Tests:**
   - `supabase/functions/tests/ai_orchestrator_test.ts`:
     - Test 17: Verifies atomic quota reservation reuses `request_id` and avoids duplicate insertion.
     - Test 18: Verifies quota limit exceeded returns HTTP 429.
     - Test 19: Verifies quota check RPC error fails closed with HTTP 503 (`quota_check_failed`).
     - Test 20: Verifies malformed quota reservation response fails closed with HTTP 500 (`quota_reservation_invalid`).
