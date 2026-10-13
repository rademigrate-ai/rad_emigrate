# Security matrix — post independent audit (2026-10-13)

Independent audit confirmed production remains **FAIL** for SEC-001–SEC-004 until the ordered security path is authorized and applied. Repository implementations and negative tests are **CODE-COMPLETE**.

| ID | Live production | Repository | Local negative evidence |
|----|-----------------|------------|-------------------------|
| SEC-001 AI RPC ownership | FAIL — no `auth.uid()=p_user_id` | Fixed `20261010010000` | definer_guards + prod_equiv cross-owner |
| SEC-002 Feed approval + human trigger | FAIL — non-approved publishable; no guard trigger | Fixed `20261010010000` | pipeline S8–S10; prod_equiv feed_approval |
| SEC-003 Consultation abuse + admin_note | FAIL — INSERT true; admin_note SELECT; no RPC | Fixed `20261010010000` + `20261012110945` | pipeline S14–S15; prepilot; prod_equiv |
| SEC-004 AI model CHECKs | FAIL — three named constraints absent | Fixed `20261012230000` | migration check log |
| SEC-005 Backup/PITR | FAIL — Free plan; inventory UNVERIFIED | N/A | Local grant-safe restore only |
| SEC-006 Leaked-password | Disabled (prior advisor) | Auth setting | Owner action |

See `RAD_GROK_INDEPENDENT_AUDIT_INCORPORATION_20261013.md` and `docs/SECURITY_ACCEPTANCE_20261012.md` (if present) for requirement-level evidence. No production writes were made during audit or incorporation.
