# Feature completion matrix

PASS means the stated local backend behavior was exercised. PARTIAL does not claim end-to-end feature completion.

| Feature/scope | Status | Implemented and exercised | Remaining gate |
|---|---|---|---|
| Auth/RLS/privileges | PASS | Role INSERT/UPDATE denial, forged metadata denial, owner isolation, internal schemas, explicit grants, hardened definers, human publication | Fresh remote review before any release |
| 1 — Visa CMS | PARTIAL | Country×pathway main uniqueness; independent related articles; structured sections, immutable revisions/events; CAS review/approval/publish/rollback; locale, provenance, complete source manifests; bookmark/resume | Approved real RadVisa/DigiVisa corpus/inventory; frontend acceptance; approved supersession policy if editing removes archived source fragments |
| 2 — Research | PARTIAL | Authority/proof/evidence storage; checksum/freshness/conflict/revocation enforcement; query-relevant verified retrieval; leased change detection, deduplicated proposals, human review into draft | Approved trust-root policy and records; protected egress/proof producer; discovery provider; live-source acceptance |
| 3 — Currency | PARTIAL | Approved-provider cache contract; exact decimal conversion/HALF_EVEN; IRR/toman display policy; single-provider history with missing dates; alerts, consent, tombstones, owner isolation | Live provider acceptance and operational refresh ownership/deadlines; no Iranian free-market provider authorized |
| 9 — Feed/notifications | PARTIAL | Exact-revision human publishing; saved/read state; pending comments/replies, human moderation and audit; owner-bound preferences/typed notification targets; sandbox outbox lease/consent/retry | Frontend review of moderation default; external delivery provider/consent operational acceptance. Sandbox receipt is not external delivery |
| 10 — Visa search | PARTIAL | Full published bodies/related articles; Persian/English normalization; typo fallback; human-curated aliases; metadata/filters; safe UTF-16 ranges; stable versioned pagination and revocation | Reviewed bilingual gold corpus and agreed staging capacity test |
| 11 — AI security | PASS | Shared legacy/v1 reservations, concurrent count/token ceilings, idempotency, same-row settlement/release, conservative expiry, owned sessions/history, official-only retrieval | Orchestrator integration/e2e remains a separate owner gate |
| 11 — RAD AI 2.0 end-to-end | PARTIAL | Existing text-only integration retained; backend quota/retrieval/tool contracts provided | Grok orchestration and adversarial live integration review; Antigravity UI acceptance |
| Consultation/service intake foundation | PASS | Existing owned intake, 3/hour and 10/day controls, narrow reads, admin CAS transition/assignment and history | Product owner must define services, availability and appointment semantics |
| Interview scheduling | BLOCKED | Existing intake can collect a request | No approved slots, timezone/cancellation/availability rules; appointment API proposed only |
| Cost calculator | BLOCKED | Decimal FX and sourced content primitives available | Approved cost data, line items, assumptions, validity periods and calculation rules |
| Country/visa comparison | PARTIAL | Published canonical articles and catalog metadata can be read without inventing eligibility | Comparison fields/normalization and missing-data rules await product approval; no comparison RPC implemented |
| University comparison | NOT IMPLEMENTED | No verified university comparison dataset added | Approved dataset, fields, evidence/licensing and comparison rules |
| Payment/OCR/incident feature expansion | BLOCKED | Existing clean-lineage code retained; optional captured-baseline gaps recorded | C-003 R08/R09 and optional incident migrations need their own review; keep features disabled |

No prices, service packages, legal eligibility, university partnerships, appointment guarantees, live immigration claims, voice or image workflows were invented.
