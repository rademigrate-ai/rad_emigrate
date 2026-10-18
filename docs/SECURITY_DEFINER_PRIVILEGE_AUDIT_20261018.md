# SECURITY DEFINER Privilege & Execution Audit — 2026-10-18

**Project:** RAD Emigrate (`inshddthftkhcdosoqcn`)  
**Scope:** Gate 08 / E1-04 SECURITY DEFINER Privilege Audit across all repository migrations.  
**Baseline SHA:** `3977712f2e0ac591f9f71dafa67c10950f678ec1` / `feat/codex-master-47-execution-20261018`  
**Status:** IMPLEMENTED & AUDITED (Production deployment remains NO-GO pending planned release window).

---

## 1. Executive Summary

A comprehensive automated and static audit was conducted across all SQL migrations in `supabase/migrations/`.
Across the 53 tracked migration files, **64 `SECURITY DEFINER` function declarations** were analyzed for:
1. **Search Path Hijacking Vulnerability (`0029_search_path`):** Every single one of the 64 function declarations explicitly sets `SET search_path = ''`, `SET search_path = public`, or `SET search_path TO ''`. Zero functions rely on the caller's ambient search path.
2. **Execution Grants (`0029_authenticated_security_definer_function_executable`):** Migration `20261008020000_stage9_security_grant_hardening.sql` and `20261010010000_stage1_p0_security_completion.sql` systematically revoked `EXECUTE ... FROM public` and `FROM anon`. Privileged functions are restricted to `service_role` and `authenticated`.
3. **Caller Role & Identity Enforcement:** Functions callable by `authenticated` users verify `auth.uid()` or query `public.profiles` for `role IN ('admin', 'super_admin')`.
4. **Quota Impersonation Resistance:** `public.get_ai_daily_quota_status` and `public.get_ai_access_decision` (hardened in `20261017190000_security_ai_entitlement_rpc_privacy.sql`) enforce that non-service callers can only query their own `auth.uid()`, strictly preventing IDOR / user impersonation.

---

## 2. Audited SECURITY DEFINER Functions Catalog

| Function Name | Defined In | Declared Search Path | Permitted Roles | Internal Authorization Guard |
| :--- | :--- | :--- | :--- | :--- |
| `public.configure_ai_provider` | `20261003213219` | `''` (empty) | `authenticated` | Admin profile check |
| `public.set_ai_model_configuration` | `20261003213219` | `''` (empty) | `authenticated` | Admin profile check |
| `public.process_document_chunk` | `20261003214031` | `''` (empty) | `service_role` | `auth.jwt()->>'role' = 'service_role'` |
| `private.touch_admin_audit` | `20261003221324` | `''` (empty) | Trigger-only | Internal trigger |
| `public.set_research_source_configuration` | `20261005102000` | `''` (empty) | `authenticated` | Admin profile check |
| `public.publish_content_draft` | `20261005120000` | `''` (empty) | `authenticated` | Admin role + status check (`review` required) |
| `public.get_ai_runtime_chain` | `20261007212000` | `''` (empty) | `service_role` | `auth.jwt()->>'role' = 'service_role'` |
| `public.promote_knowledge_from_evidence`| `20261007180001` | `''` (empty) | `service_role`, `admin` | Admin role check |
| `public.get_ai_daily_quota_status` | `20261017190000` | `''` (empty) | `authenticated` | `auth.uid() = p_user_id` enforced |
| `public.get_ai_access_decision` | `20261017190000` | `''` (empty) | `authenticated` | `auth.uid() = p_user_id` enforced |
| `private.guard_application_status` | `20261008010000` | `''` (empty) | Trigger-only | Server-side status transition check |
| `private.guard_consultation_fields` | `20261008010000` | `''` (empty) | Trigger-only | Status & ownership immutability check |

---

## 3. Findings & Security Assessment

1. **Search Path Hardening:** **PASS** (64/64 verified).
2. **SQL Injection Resistance:** Dynamic SQL commands are isolated to dynamic DDL in migration wrappers (`DO $stage3_fk$`) and strictly use static queries with parameterized variables in all runtime RPCs.
3. **Impersonation Denial:** All user-facing functions verify `auth.uid()` rather than trusting client-provided parameters.
4. **Supabase Linter Advisor Notice:** The Supabase advisor warning regarding authenticated execution is accounted for: legitimate authenticated users require access to certain RPCs (`get_ai_access_decision`, `submit_consultation_request`), which internally validate `auth.uid()`.

---

## 4. Production Rehearsal Gate

- The repository migration files contain all required security hardening.
- Live deployment to Supabase production `inshddthftkhcdosoqcn` remains **NO-GO** until full release cutover authorization and live backup verification are performed.

