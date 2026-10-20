# Integration owner handoff — current project conversation

Audited source: `1fe44f63d179263c5e719578bf7ebad0e17868d1`. Audit/report branch: `audit/final-independent-20261020`. Candidate CI: https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39471824017 — four failing / three successful jobs.

No application fix or new migration was authored in this independent audit: the confirmed backend defects already have existing Codex-owned corrections; UI/Edge/CI defects are within explicitly assigned Antigravity/Freebuff/Grok/Gemini areas. Dirty worktrees were not overwritten, and unfinished changes were not cherry-picked or merged. This is an ownership decision, not a claim that defects were fixed.

| Priority / owner | Concrete next task | Acceptance |
| --- | --- | --- |
| P0 — Antigravity integration + Codex | Reconcile existing seven-file backend delta `9736540` + `24b3f6b` with candidate; include contract fixtures and tests, not only SQL | Human publish, evidence immutability, input errors, ACLs and all mandatory SQL gates pass on combined commit |
| P0 — Antigravity | Remove FX fresh and Visa/search verified fixture fallbacks, generated fact-check dates, and hard-coded official fee/tuition/rank/pathway claims | Three added no-network fallback regressions and malformed-contract checks pass; unavailable states or reviewed provenance |
| P0 — Antigravity + Grok | Wire actual v1 AI payload/header/consent and agree exact contracts | Real UI → handler → Auth/RPC → reservation/grounding/settlement test; no image/voice activation |
| P1 — Freebuff + Antigravity | Fix 345px interview overflow; consolidate two scheduling routes/contracts; correct booking UUID and return routes | Full 835-case suite green plus narrow/RTL/large-label regression |
| P1 — Grok + Gemini | Correct Deno read permission and agreed lint scope; preserve meaningful lifecycle tests | Pinned toolchain local and GitHub gates pass |
| P1 — Antigravity privacy | Key cached booking/appointment/private drafts to authenticated identity | Account A → logout → B cannot see/use A data; pending guest-draft behavior approved |
| Prerequisite — Codex + owner | Reconcile ledger aliases, existing effects and missing optional backend foundations into approved additive manifest | Fresh hosted reads + clean/additive rehearsals + reviewed initialization/rollback |
| Prerequisite — owner / operations | Approve authority roots, pinned egress, evidence corpus, providers/transports and deployment procedure | Staging prerequisites verified before explicit deployment approval |

For the frontend contract review, use existing backend `supabase/contracts/rad_v1.json`, SQL-generated wire fixtures and `research_worker_base.json` from Codex's completed branch. The review must cover endpoint/RPC names, closed request/response shapes, auth/RLS, errors, pagination, revision/idempotency keys and null/unavailable semantics. Antigravity and the project owner have not signed off through this audit session. Present this document in the current chat; no unverified external agent channel was used.

Production and staging remain NO-GO. Integration review remains GO. The next integration owner should report the new combined SHA, not reuse test claims from either source branch.
