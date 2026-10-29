# RAD EMIGRATE — AUTH, RLS & SECURITY QA REPORT
**Date:** 2026-10-28  
**Scope:** Row-Level Security, Role Escalation Protection, Private Data View Isolation, Local GoTrue Fixtures  
**Execution:** `test/security/`, `test/acceptance/`, Real Local GoTrue/PostgREST Stack (`rad_codex_final_20261028`)  

---

## 1. ACCESS CONTROL & ROLE BOUNDARIES

| Role Identifier | Permissions Matrix | Prohibited Operations | Enforcement Mechanism |
|---|---|---|---|
| `GUEST` (Anon) | Read public Visa catalog, Explore, News Feed, World Clock, Calculator | Cannot write to any table; cannot access `/applications`, `/documents`, `/notifications`, `/admin/*` | Supabase RLS (`auth.uid() IS NOT NULL` policies) & Flutter Router Redirects |
| `USER` | Read/write own profile, documents, applications, appointments, notification status | Cannot read other users' cases or storage; cannot access `/admin/*` or trigger administrative RPCs | Database RLS (`user_id = auth.uid()`), SECURITY DEFINER authorization checks |
| `ADMIN` | Read/write editorial CMS drafts, review candidates, operational metrics, consultations | Cannot elevate roles to `SUPER_ADMIN`; cannot perform direct unlogged database catalog overrides | Role-based RLS on `private.rad_editorial_catalog` & audit event triggers |
| `SUPER_ADMIN` | Full administrative visibility, source monitor configuration, audit ledger inspection | Cannot bypass immutable source evidence ledgers | Immutable append-only audit tables |

---

## 2. KEY SECURITY VERIFICATIONS (EVIDENCE FROM PRELIMINARY QA)

1. **Role Escalation via Profile Update Blocked**:
   - Migration `20261006180000_fix_profile_update_with_check_role_escalation.sql` strictly enforces that `role` cannot be updated via user-initiated `PATCH /rest/v1/profiles`.
   - Verified by `admin_role_authorization_test.dart: USER cannot become ADMIN through client-side role mutation model ... PASS`.

2. **Private Document Storage Isolation**:
   - `private_view_assurance_test.dart`:
     - User A uploading a document cannot be accessed or listed by User B.
     - Logout immediately purges local caches, cached drafts, and sensitive tokens.

3. **Database Fingerprint Consistency**:
   - Confirmed by `local-real-auth-rls.json`:
     - RLS Fingerprint: `f774d2521876438405d177897df727d3`
     - Policies Fingerprint: `55e8a4ebace6d08cdf6581783d56ed8c`
     - Constraints Fingerprint: `d67f6384ff0ec977d106e5ada5bf711d`
     - Triggers Fingerprint: `9be9b50fb51f41c9e9dacb7e0ef56509`
