# Grok Independent Audit Incorporation — 2026-10-13

**Branch:** `handoff/codex-stage1-stage2-20261010`  
**Audited / incorporation HEAD (starting):** `4f9993c363c50ab70a187c79d7b52de8402b2f9c`  
**Production project:** `inshddthftkhcdosoqcn`  
**Mode:** Read-only production. No migrations applied. No deploy.

This document incorporates the independent Principal Engineer / Security Auditor findings (SEC-001–SEC-006) into the existing Stage 5 ONE TASK. Codex remains the sole implementation owner on this branch.

---

## 1. Finding disposition

| ID | Severity | Production | Repository fix | Negative tests | Disposition |
|----|----------|------------|----------------|----------------|-------------|
| SEC-001 | CRITICAL | Vulnerable (AI RPC IDOR) | `20261010010000` ownership checks | `verify_staging_definer_guards.py`, `verify_prod_equiv_rpc_acceptance.py` | **Code-complete; production-blocked** |
| SEC-002 | CRITICAL | Vulnerable (publish without approval; no human Feed trigger) | `20261010010000` approved-only + `trg_guard_human_feed_*` | Pipeline E2E S8–S10; prod-equiv feed_approval | **Code-complete; production-blocked** |
| SEC-003 | HIGH | Vulnerable (direct INSERT; admin_note SELECT; no rate limit) | `20261010010000` column grants + `20261012110945` RPC/index | Pipeline S14–S15; prepilot consultation; prod-equiv | **Code-complete; production-blocked** |
| SEC-004 | MEDIUM | Missing 3 AI model CHECKs | `20261012230000` idempotent ADD | Isolated migration check log | **Code-complete; production-blocked** |
| SEC-005 | CRITICAL (ops) | Free plan; backup/PITR ineligible; recovery UNVERIFIED | N/A (platform) | Local grant-safe restore only | **Owner-blocked** |
| SEC-006 | MEDIUM | Leaked-password protection disabled (prior advisor) | Auth setting | N/A | **Owner-blocked** |

---

## 2. Repository verification (this incorporation)

### SEC-001 — AI owner checks
- `get_ai_daily_quota_status`: `if not v_is_service and auth.uid() is distinct from p_user_id then raise forbidden`
- `get_ai_access_decision`: same ownership gate before profile/entitlement reads
- Grants: EXECUTE to authenticated + service_role only; revoked from public/anon

### SEC-002 — Human-only approved Feed publish
- `publish_content_draft` requires `v_draft.status = 'approved'`
- `private.guard_human_feed_mutation` + triggers on `feed_items` and `feed_item_localizations`
- Direct INSERT/UPDATE/DELETE revoked from authenticated on Feed tables
- `service_role` EXECUTE revoked on publish RPC (human authenticated admin only)

### SEC-003 — Consultation
- Flutter `consultation_page.dart` submits via `rpc('submit_consultation_request')` only; history SELECT limited to applicant-visible columns
- Migration revokes table INSERT; RPC enforces owner, topic/message length, related application ownership, advisory lock, 3/hour and 10/day
- `admin_note` removed from authenticated SELECT grant in `20261010010000`

### SEC-004 — AI model CHECKs
- Idempotent DO blocks; ADD only if absent; NOT VALID → VALIDATE
- No DROP CONSTRAINT

### Destructive scan
- Pending security path files contain no TRUNCATE, DELETE FROM data, DROP COLUMN, or unconditional DROP CONSTRAINT
- Conditional `DROP TRIGGER IF EXISTS` / `DROP POLICY IF EXISTS` only where replacing known objects

### Migration order (preserved — do not reorder)
1. `20261010010000_stage1_p0_security_completion.sql`
2. `20261010055013_stage1_atomic_ai_quota_reservation.sql`
3. `20261010070000_stage1_ssrf_ipv4_mapped_ipv6.sql`
4. `20261012110945_stage1_security_abuse_storage_alignment.sql`
5. `20261012230000_ai_models_check_constraints_alignment.sql`

SHA-256 values match `RAD_DEPLOYMENT_MANIFEST_20261012.md` (LF-normalized).

### Client paths
- Admin publish/approve: `AdminReviewActions` → `set_content_draft_status` / `publish_content_draft` RPCs only
- Consultation submit: RPC only

---

## 3. Tests status (code-controlled)

| Suite | Covers | Runnable in this environment |
|-------|--------|------------------------------|
| `scripts/verify_staging_definer_guards.py` | SEC-001 cross-owner + admin RPC denials | Requires disposable Docker PG — **NOT RUN** (no docker) |
| `scripts/verify_prod_equiv_rpc_acceptance.py` | SEC-001/002/003 behavioral | Requires disposable stack — **NOT RUN** |
| `tools/stage3_pipeline_e2e/run_pipeline_e2e.sh` S8–S15 | Unapproved publish, admin_note, direct insert, rate limit | Requires local PG — **NOT RUN** |
| `scripts/verify_prepilot_consultation.py` | Consultation RPC + negatives | Requires loopback stack — **NOT RUN** |
| Prior recorded PASS evidence | Same suites on ancestor SHAs | **Accepted as historical local PASS; not re-executed on this HEAD** |

Flutter toolchain and Docker are unavailable in the incorporation environment. Remote CI was not re-triggered from this agent.

---

## 4. Production remains NO-GO

Independent audit re-confirmed live defects via read-only SQL:

- AI RPCs lack ownership checks
- `publish_content_draft` does not require `approved`
- Authenticated INSERT on `consultation_requests` = true
- `admin_note` SELECT granted to authenticated
- Missing three AI model CHECK constraint names
- Free-plan backup/PITR ineligible; recovery point UNVERIFIED

No production migration, Auth change, or deploy is authorized by this incorporation.

---

## 5. Acceptance matrix update pointer

See `RAD_STAGE5_ACCEPTANCE_MATRIX_POST_AUDIT_20261013.md` in this directory.
