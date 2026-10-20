# Security and RLS results

| Boundary | Status | Evidence |
|---|---|---|
| Privileged profile INSERT/UPDATE | PASS | HTTP role-column writes rejected; SQL forged user_metadata admin rejected; safe orphan completion still succeeds |
| User isolation | PASS | Profiles, notifications, reading state, comments and consultations isolated; cross-owner AI session/history insertion rejected |
| Quota races | PASS | Ten concurrent v1 requests admit two at a two-request cap; ten mixed legacy/v1 requests also admit two; same key reuses one row, changed body conflicts |
| Token accounting | PASS | Pending budget blocks oversubscription; actual settlement releases unused reservation; expiry charges unknown usage conservatively and fences late completion |
| Draft/publication boundary | PASS | Draft reads/search rejected; exact hash/revision review; worker/service cannot publish; legacy human marker/grants restored |
| Evidence/grounding | PASS | Missing proof, expiry, conflict, inactive root and revoked domain fail closed; exact quote/snapshot/citation required; no unrelated-query fallback |
| Research review | PASS | No-change sources create no proposal; leased change repeats deduplicate; acceptance creates a draft and leaves published pointer unchanged |
| Private helpers / defaults | PASS | Runtime catalog checks forbid PUBLIC execution and client execution except has_role; anonymous read definers are an explicit signature allowlist |
| Search | PASS | Published pointer recheck, filter/actor/version cursor binding, revocation invalidation, UTF-16 offsets and Persian normalization |
| Telemetry privacy | PASS | Nested/array/key canaries removed; allowed metrics retained; redaction idempotent; malformed payload rejected |
| Remote staging finding | BLOCKED | The captured staging schema has twelve RLS-disabled tables; no remediation was executed in this phase |

Captured RLS-disabled staging tables: admin_audit_logs, ai_entitlements, ai_models, ai_requests, ai_usage_limits, applications, consultation_requests, content_drafts, document_processor_config, feed_item_localizations, feed_items, profiles. This is a finding requiring investigation and fresh verification, not authorization to expose or change them.

Editorial approval is independent from factual verification. Trust is re-evaluated at read time. Authority roots/proofs are not seeded or activated by migrations. Anonymous published-read definers use private tables without granting raw draft/table access. RLS remains enabled on application tables.

Security scope does not claim a penetration test of deployed services, live provider behavior, or production-wide data retention/deletion acceptance. Service credentials remain server-only and were never printed, exported or committed.
