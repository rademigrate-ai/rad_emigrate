# Backend integration manifest for Freebuff

**Branch:** `feat/grok-independent-feature-completion`  
**Backend-complete HEAD:** run `git rev-parse HEAD` after final commit on this branch  
**Policy:** local only — no push/PR/production

## Source mapping (Codex → Grok cherry-picks)

| Codex SHA | Grok commit (after cherry-pick) | Topic |
|-----------|----------------------------------|--------|
| `4b083db` | `75e3f46` | Provider boundaries + local HTTP |
| `bb572b4` | `694c598` | Auth recovery / OTP mailbox tests |
| `cceebae` | `d0e8565` | Atomic OCR leases + human review |
| `c2e58b7` | `818484f` | Clean dual-stack verification docs |
| `269d1b1` | `2e78ff7` | Observability privacy + incident triage |
| `47835e8` | `7f15cba` | CRM + notification outbox + payment sandbox |

`4b9e0af` skipped: superseded by `cceebae` content already present (add/add conflict).

## Recommended Freebuff cherry-pick / merge order

Integrate this branch tip **or** apply in chronological dependency order:

1. `7f15cba` / migrations `20261018125432`, `20261018142313`, `20261018143455`  
2. `75e3f46` provider/HTTP  
3. `694c598` auth recovery scripts  
4. `d0e8565` + migration `20261018152513_local47_document_atomic_processing.sql`  
5. `818484f` evidence docs  
6. `2e78ff7` + migration `20261018154834_local47_observability_privacy_and_triage.sql`  
7. Grok domain commits already on integration (`1bac021` lineage) as needed  

**Migration timestamps (ascending):**  
`20261018125432` → `20261018142313` → `20261018143455` → `20261018152513` → `20261018154834`

Preserve order; do not renumber.

## Conflict notes during incorporation

- `docs/RAD_AGENT_COORDINATION.md` / `RAD_CODEX_BACKEND_PROGRESS.md`: Codex “theirs” preferred for backend narrative  
- `document-intelligence/handler.ts`: restored from Codex (was missing on domain branch)  
- `compare_local47_catalogs.py` / `verify_local_stack.py`: kept post-OCR versions when CRM commit conflicted  

## Independent verification (this worktree)

| Suite | Result |
|-------|--------|
| Deno Edge `supabase/functions/tests/` (container Deno 2.1.4, `--network none`, `--allow-env`) | **105 passed / 0 failed** |
| Domain Flutter (pathway, recommendation, knowledge, integrity, pipeline) | **41 passed** |
| Gitleaks (prior) | FINDINGS_REQUIRE_REVIEW; `graphify-out/` added to `.gitignore` |

Disposable full SQL dual-stack replay **not** re-run here (Codex stacks on 55320+/57320+ left undisturbed). Scripts and migrations are present for Freebuff/Codex-owned disposable ports.

## Fail-closed domain (unchanged)

- `EvidenceRegistry` / seed: `pendingReview` only  
- `CuratedRulesGate`: empty rules unless `editorialApproved`  
- Pathway / recommendations: empty rules → insufficient evidence  

## External blockers (not claimed done)

- Production migration apply  
- Real provider credentials  
- Editorial draft/Visa approval  
- Real payment merchant  
- Owner VERIFIED_PASS on Issue #57  

**Official count remains 3/47 VERIFIED_PASS.**
