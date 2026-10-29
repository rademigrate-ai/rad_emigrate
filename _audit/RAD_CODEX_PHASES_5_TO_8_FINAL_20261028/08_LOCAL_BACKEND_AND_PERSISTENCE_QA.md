# RAD EMIGRATE — LOCAL BACKEND & PERSISTENCE QA REPORT
**Date:** 2026-10-28  
**Infrastructure:** Isolated Local Docker Supabase Stack (`rad_codex_final_20261028`)  
**Endpoints:** PostgREST (`http://127.0.0.1:65321`), PostgreSQL (`127.0.0.1:65322`), SPA (`http://127.0.0.1:64331`)  

---

## 1. ISOLATED LOCAL BACKEND CONFIGURATION

To preserve hosted environments and avoid cross-stack contamination:
1. **Loopback Binding**:
   - PostgREST listens on `127.0.0.1:65321`.
   - PostgreSQL listens on `127.0.0.1:65322`.
   - Local SPA Web server listens on `127.0.0.1:64331`.
2. **Project Identity**: `rad_codex_final_20261028`.
3. **Marker Verification**: `RAD_DISPOSABLE_LOCAL_ONLY.json` validates target matching `{project: 'rad_codex_final_20261028', port: 65322}`.
4. **Secret Isolation**:
   - `qa-accounts.private.json` restricted via Windows NTFS ACL (`icacls`) to current user SID.
   - `flutter-public.json` receives only the public anon key.

---

## 2. PERSISTENCE & RLS RUNTIME VERIFICATION

- PostgREST Schema Inspection: 18 tables exposed with active RLS definitions.
- GoTrue User Fixtures: Synthetic accounts (`user_a`, `user_b`, `admin`, `super_admin`) created in local PostgreSQL with distinct IDs.
- Two-User RLS Enforcement: User A cannot read or modify User B's rows in `applications`, `documents`, or `notifications`.
