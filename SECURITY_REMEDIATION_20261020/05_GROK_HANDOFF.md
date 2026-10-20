# Grok integration handoff — project chat channel

**Integrate code commit `847dd42bbb270755676104a63814dd6e2aab07dd` from branch `fix/rad-final-security-remediation-20261020`.** It is based directly on `2d86f55f9f802067cbc9cc97be121ab38f7bef9b`, containing the already integrated Core `a24f492` corrections. This delivery does not change Grok's worktree or unpublished Flutter/workflow edits.

The commit changes only the four files listed in [security fix](02_SECURITY_FIX.md). No app models/RPC names or historical migration bytes change. Regression: `supabase/tests/rad_client_table_privileges.sql`; mandatory CI hooks added to both schema scripts. Proven result: 48→0 client nonrow rights on clean and faithful production shape, preserved DML/RLS/routines/service rights.

In Grok's owner-controlled integration checkout, after preserving its own active work:

```powershell
git fetch origin fix/rad-final-security-remediation-20261020
git show --stat 847dd42bbb270755676104a63814dd6e2aab07dd
git cherry-pick 847dd42bbb270755676104a63814dd6e2aab07dd
```

These are instructions only; no command above was run against Grok's checkout. If this exact fix or an equivalent is already integrated, compare migration/test digests and effective grants and verify it rather than duplicating the file. Preserve both mandatory regression hooks if resolving workflow/script conflicts. Documentation can be linked from this branch; it need not be cherry-picked into implementation.

**Latest independently reviewed integration SHA:** `b01f6255c9f10baff1ff12c1df07b1d995fad8a8`; it does not include847dd42. Exact CI 4/7, with Flutter/web/Android compile failures. Fix AI nullable scopes and restore the searchArticles API or update every caller. Set AI version header to1, use UUID keys and the complete closed request fixture. Original no-backend fixtures were removed; retain those improvements while rejecting malformed FX data and fabricated fact-check dates. Retain server UUIDs without untyped-result receipt fabrication, correct unpersisted intake fields, and subscribe caches to actual identity. These are Grok/frontend-owned changes; this task did not duplicate them. See current finding matrix and07_CURRENT_RC_B01F625.md.

Frontend/API coordination stays in this ChatGPT RAD project conversation: review actual `supabase/contracts/rad_v1.json`, `supabase/contracts/fixtures/rad_v1_synthetic.json` and `research_worker_base.json` with Antigravity. RPCs use p_request envelopes, closed schemas, required nulls, data.items pagination, actor-bound UUID request keys, revision/CAS, explicit private scopes and truthful unavailable errors. This ACL patch introduces no new contract. Booking/interview scheduling RPCs are absent; approve them before implementation and do not silently treat consultation intake as a scheduled appointment. Antigravity/owner approval is not claimed here.

Provide next **immutable final RC SHA** and its exact CI run. Independent verification then checks the integrated diff/ancestry, clean and additive rehearsals (including raw MAINTAIN ACLs), full SQL/HTTP/Auth security suite, human-only publication, research-to-draft, UI false-fallback/cache/AI contract regressions and exact-SHA CI. A different or merely dirty worktree is not a final candidate.

Delivery is published on the isolated branch and presented in the project chat; no verified direct Grok messaging channel exists. **Receipt and integration of 847dd42 remain unconfirmed. The b01f625 re-audit is complete with blockers; a re-audit after corrections remains pending.** No main merge, hosted migration or deployment is requested by this handoff.
