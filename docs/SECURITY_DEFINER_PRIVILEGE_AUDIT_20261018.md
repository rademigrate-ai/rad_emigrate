# SECURITY DEFINER Privilege & Execution Audit — 2026-10-18

**Project:** RAD Emigrate (`inshddthftkhcdosoqcn`)  
**Scope:** Gate 08 / E1-04 SECURITY DEFINER Privilege Audit across all repository migrations.  
**Baseline SHA:** `3977712f2e0ac591f9f71dafa67c10950f678ec1` / `feat/codex-master-47-execution-20261018`  
**Status:** Local runtime ACL regressions PASS; Production privilege and release acceptance remain open.

**Local runtime supplement:** `releases/local47_runtime_definers.json` inventories **59 unique active definers** after the local proposals. `supabase/tests/local47_definer_acl.sql` checks every active definer's pinned search path, owner, PUBLIC/anonymous ACL and private-helper exposure, then exercises the notification caller matrix and anonymous Feed RLS. Historical declaration counts below are not unique-runtime counts or proof of every business authorization guard.

---

## 1. Executive Summary

The original source-only audit at the baseline checkpoint examined 53 migration files and **64 `SECURITY DEFINER` declarations**, including superseded definitions. It analyzed declarations for:
1. **Search Path Hijacking Vulnerability (`0029_search_path`):** Every single one of the 64 function declarations explicitly sets `SET search_path = ''`, `SET search_path = public`, or `SET search_path TO ''`. Zero functions rely on the caller's ambient search path.
2. **Execution Grants (`0029_authenticated_security_definer_function_executable`):** Migration `20261008020000_stage9_security_grant_hardening.sql` and `20261010010000_stage1_p0_security_completion.sql` systematically revoked `EXECUTE ... FROM public` and `FROM anon`. Privileged functions are restricted to `service_role` and `authenticated`.
3. **Caller Role & Identity Enforcement:** Privacy, CRM, notification, payment and Feed caller matrices have executable local negative tests. Approved Knowledge retrieval intentionally permits authenticated readers. ACL metadata alone does not prove all business guards.
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
2. **SQL Injection Resistance:** No blanket SQL-injection clearance is inferred from source scanning. Runtime privilege and caller tests supplement the declared search-path checks.
3. **Impersonation Denial:** Cross-owner quota, consultation, document, Storage, history and notification cases are tested on synthetic users; this is not universal proof for every future RPC.
4. **Supabase Linter Advisor Notice:** The previously recorded live advisor warning has not been cleared by these local tests. Legitimate authenticated RPCs still need deployed-schema review and acceptance.

## Local privilege alignment

The forward proposal `20261018143455_local47_notification_privilege_alignment.sql` removes client execution of private internals except `private.has_role`, which is required by client RLS policies. It prevents future PUBLIC function-execute defaults and repairs the notification helper's service/admin guard, invalid default type and unsafe action paths. The runtime inventory shows **0 PUBLIC EXECUTE grants** across the 59 active definers; untrusted roles cannot CREATE in public.

This also intentionally revokes anon/auth EXECUTE on the invoker trigger routine `private.set_updated_at`. The core function fingerprint changes from `e05d93ee347104597a7b8b458b0d03da` to `fc57d0f49dfab1be19b4469a05b19cf8`. Restoring only those two effective flags in a diagnostic query reproduces the original hash exactly. All other seven pinned dimensions and function bodies remain unchanged; the full local RLS/trigger/caller suite passes with the new permissions.

---

## 4. Production Rehearsal Gate

- The repository migration files contain all required security hardening.
- Live deployment to Supabase production `inshddthftkhcdosoqcn` remains **NO-GO** until full release cutover authorization and live backup verification are performed.

