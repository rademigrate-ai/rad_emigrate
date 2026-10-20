# Exact remaining blockers

| Blocker / reproducible condition | Owner | Required action / acceptance gate |
|---|---|---|
| No fresh remote reconciliation approval | Project owner + Codex/Gemini reviewer | Refresh metadata/history evidence; reconcile exact forward manifest, ACL/default-ACL and dependencies; review locks/recovery; separately authorize any remote change |
| Twelve captured staging tables have RLS disabled | Project owner + security reviewer | Read-only investigate actual current staging state and intended access; approve a separate remediation; never expose/reset them as a shortcut |
| No approved real Visa corpus/inventory | Project/content owner | Supply/approve exact RadVisa+DigiVisa source snapshot set, locales, related-article separation and fragment accounting; run an isolated real-content review without auto-publication |
| Archived-fragment removal/supersession semantics undefined | Content owner + Antigravity + Codex | Approve an explicit evidence-backed supersession/versioned manifest contract; literal preservation remains fail-closed until then |
| No active authority trust roots/proof producer | Project owner + research/security owner | Approve identity/competence/freshness policy and protected egress verification; supply legitimate proofs; test expiry/revocation and prompt-injection boundaries live |
| Official discovery adapter / protected refresh unavailable | Research/Edge owner | Configure approved discovery and pinned egress; verify public-only DNS/redirect/size/time bounds; candidates must never auto-verify or auto-publish |
| Frontend contract sign-off pending | Antigravity + project owner | Review the committed schemas/fixtures in this chat; replace fake freshness/date defaults, double arithmetic and mismatched error/list assumptions; run combined branch tests |
| AI 2.0 orchestration integration/e2e pending | Grok + Antigravity + security reviewer | Bind existing text-only runtime to quota/retrieval contracts; test deadlines, provider denial/replay, personalization consent, cross-user tools, refusal/injection and settlement; do not infer live grounding from unit tests |
| Worker operational acceptance incomplete | Edge/operations owner | Currency worker needs bounded-read/deadline review and live provider acceptance; protected workers must retain purpose auth/default OFF; contract shapes are documented, no duplicate handler added |
| Real notification transports unconfigured | Product + operations owner | Approve provider/consent policy and receipt semantics; test targeting/timezone/revocation with approved sandbox endpoints before any external send |
| Reviewed bilingual search corpus / production-like capacity unapproved | Content + frontend + release owner | Agree gold cases and staging fixture/load target; test all filters, typo/alias recall, UTF-16 ranges and revoke races on the integrated release |
| New scheduling/cost/comparison business rules absent | Project owner + Freebuff | Approve services, appointment states/timezone/availability, cost sources/assumptions, comparison fields/dataset licensing. Proposed contracts are not implemented endpoints |
| Optional payment/OCR/incident dependency gaps in captured schema | Owners of C-003 R08/R09/incident work | Review their separate additive migration plans; keep corresponding features disabled; clean local availability is not proof of production availability |
| GitHub CI availability/result | Gemini/repository owner | Use the delivery commit run/check links in evidence; if dispatch/auth unavailable it remains NOT RUN, never assumed green |

These gates do not block consuming the tested local backend source for review. They do block claiming a production-ready or fully accepted end-to-end release.
