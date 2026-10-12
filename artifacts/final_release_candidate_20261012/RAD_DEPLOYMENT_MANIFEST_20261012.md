# RAD Supabase deployment manifest — verified engineering package

**Date:** 2026-10-12  
**Branch:** `handoff/codex-stage1-stage2-20261010`  
**Parent commit:** `3cb2b01fd63247efa94650ac95a57a239135de74`  
**Production project:** `inshddthftkhcdosoqcn`  
**Production writes:** none  
**Recommendation:** **NO-GO** until owner approvals below

---

## 1. Migration file under test (corrected)

| File | SHA-256 |
|------|---------|
| `supabase/migrations/20261012230000_ai_models_check_constraints_alignment.sql` | `d4563930461176e6481df29cf587c9dca0eb7b4987395c05af2f613758452fbc` |

2026-10-13 rehearsal clarification: the value above is the repository's
LF-normalized SHA-256. Windows checkout supplied CRLF bytes for this one file,
so the **executed local file bytes** hashed to
`303b6ba4382453ab682297f57336922050344ef5e800268cd8b4cb221711d149`.
The other four files had identical worktree and LF-normalized hashes. A
production operator must hash the exact bytes being applied and compare the
reviewed SQL content, rather than assume the prior manifest hash describes a
Windows checkout byte-for-byte.

**Fix applied:** removed unconditional `DROP CONSTRAINT IF EXISTS` + re-ADD.  
Now uses `DO` blocks that **ADD only when the named constraint is absent**.  
No catalog churn on environments that already have the constraints.  
Still uses NOT VALID → VALIDATE for safe validation.

---

## 2. Chronological order proof

Repository migration filenames are strictly ascending by version prefix (51 files after this commit).  
Last file: `20261012230000_ai_models_check_constraints_alignment.sql`.

**Security path apply order (timestamp order — required for Supabase ledger):**

| # | Version | File | SHA-256 |
|--:|---------|------|---------|
| 1 | 20261010010000 | stage1_p0_security_completion.sql | `76a28a9aa6294f6a8ca8f108394b801a2ee85f85827104246324f69787610bd5` |
| 2 | 20261010055013 | stage1_atomic_ai_quota_reservation.sql | `51ab2b39fb63655fea7e67e1a7aef69bb1ba15297877bc39168b90b2b1c8b646` |
| 3 | 20261010070000 | stage1_ssrf_ipv4_mapped_ipv6.sql | `b94878391d4fddb9887e74d9a2a1dc809360de46f989a3d599a5471cc7c42fc5` |
| 4 | 20261012110945 | stage1_security_abuse_storage_alignment.sql | `9de2fdb764aae7068c9355b07cd3593823bd66b5da73448687693fe5cc535119` |
| 5 | 20261012230000 | ai_models_check_constraints_alignment.sql | `d4563930461176e6481df29cf587c9dca0eb7b4987395c05af2f613758452fbc` |

**Migration history safety:**

- Production ledger currently ends at `20261007212140` (47 rows).
- These five version strings are **all greater** than the live max and **do not collide** with any live version ID.
- Applying them via Supabase migration machinery inserts **five new rows** only. It does **not** rewrite, rename, or delete the existing 47 historical rows (including the 16 timestamp aliases and 4 live-only names).
- Historical aliases remain preserved as historical records. Do not mark repo alias files as applied.
- Do **not** run `supabase db push` blindly across divergent ledgers; apply these five approved versions in order after backup attestation.

Excluded from this path: `20261007220000_stage5_visa_editorial_summaries.sql` (editorial data UPDATE; separate approval).

---

## 3. Isolated tests executed

### 3.1 CHECK constraint migration (`migration_check_test.log`)

| Case | Result |
|------|--------|
| Production-like: columns present, CHECKs absent, valid rows | **PASS** — 3 constraints added |
| Valid insert after apply | **PASS** |
| Invalid consecutive_failures / latency / success_rate | **PASS** (rejected) |
| Repeat execution (idempotent, no DROP) | **PASS** — still 3 constraints, rows preserved |
| Repo-like: constraints already present | **PASS** — no-op ADD, data preserved |
| Bad existing data → VALIDATE fails | **PASS** (expected failure; protects data) |

### 3.2 Security sequence rehearsal (`security_rehearsal.log`)

Minimal skeleton + P0 + abuse/storage + CHECK applied on isolated PostgreSQL 16.

| Probe | Result |
|-------|--------|
| Own AI daily quota | **PASS** (allowed) |
| Cross-user AI daily quota | **PASS** (`forbidden`) |
| Cross-user AI access decision | **PASS** (`forbidden`) |
| Consultation submit (3/hour) | **PASS** |
| Consultation 4th within hour | **PASS** (`consultation_rate_limited`) |
| Ordinary user publish draft | **PASS** (`forbidden`) |
| Admin publish `review` status | **PASS** (`draft requires explicit approval`) |
| Admin publish `approved` | **PASS** (feed item created) |
| Direct INSERT consultation | **PASS** (`false`) |
| `admin_note` SELECT by authenticated | **PASS** (`false`) |
| Human Feed mutation trigger | **PASS** (present) |
| Three AI model CHECKs | **PASS** (present) |
| All four security RPCs present | **PASS** |

**Not covered in this isolated skeleton:** full 50-migration chain from empty DB, Edge Function integration, Storage HTTP signed-URL path (prior local prepilot PASS remains the evidence for those), concurrent multi-session quota reservation under load, hosted staging.

---

## 4. Acceptance matrix

| Area | Status | Evidence |
|------|--------|----------|
| CHECK migration fixed (no unnecessary DROP) | **PASS** | File + tests |
| Chronological order / ledger non-corruption | **PASS** | Version proof above |
| CHECK migration isolated tests | **PASS** | `migration_check_test.log` |
| Security sequence (AI / Feed / Consultation) | **PASS** (isolated skeleton) | `security_rehearsal.log` |
| Historical aliases preserved | **PASS** (by design; no rewrite) | Manifest |
| Production data modified | **PASS** (none) | No prod writes |
| Hosted staging full chain | **BLOCKED** | No non-prod project |
| Atomic quota concurrency under load | **NOT RUN** (this turn) | Prior local evidence only |
| Storage HTTP cross-owner (this turn) | **NOT RUN** | Prior local PASS |
| Off-machine backup/PITR attested | **BLOCKED** | Owner |
| Production apply | **BLOCKED** | Owner authorization |
| **Production GO** | **NO-GO** | |

---

## 5. Owner approvals still required

1. Explicit authorization to apply the five ordered security migrations to production.  
2. Attested restorable off-machine backup or PITR recovery point.  
3. Product/AI decision on discovery auto-enable vs keep-disabled behavior.  
4. Auth: enable leaked-password protection (or written risk acceptance).  
5. Hosted staging project or cost approval if further hosted verification is required before GO.  
6. Separate: Stage 5 Visa editorial; Stage 3 baseline reconciliation.

---

## 6. Files in this delivery

- `supabase/migrations/20261012230000_ai_models_check_constraints_alignment.sql` (corrected)
- `artifacts/final_release_candidate_20261012/RAD_DEPLOYMENT_MANIFEST_20261012.md`
- `artifacts/final_release_candidate_20261012/migration_check_test.log`
- `artifacts/final_release_candidate_20261012/security_rehearsal.log`

Production remains **NO-GO**.
