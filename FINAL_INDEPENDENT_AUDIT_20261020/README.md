# Independent final release audit — RAD Emigrate

**Integration Review: GO. Staging: NO-GO. Production: NO-GO.** Integration review permits examining and reconciling this evidence; it is not acceptance of the candidate or permission to deploy.

Application candidate tested independently: `1fe44f63d179263c5e719578bf7ebad0e17868d1` (`feat/rad-unified-release-candidate`). Isolated audit branch: `audit/final-independent-20261020`. All application/migration tests refer to that immutable source commit. Later audit commits contain reports and reproduction tools only and must not inherit a fictitious full-suite PASS.

The candidate lacks Codex's completed security follow-ups. Local and GitHub Flutter suites both have **834 passes / 1 failure** (interview mobile overflow). GitHub CI has **3 successful jobs / 4 failed jobs**. All 72 candidate migrations replay, but security acceptance fails afterward. A production-shaped local reconstruction matches ten catalog dimensions, applies twelve forward files, then also fails required acceptance. No hosted SQL was applied.

An additional no-network regression probe reproduced three failures: ordinary FX returns a fabricated fresh quote, canonical Visa returns verified fixture content, and search returns verified fixture hits. Canonical fixtures also synthesize fact-check dates. Together with hard-coded cost/comparison assertions, this blocks evidence-backed product readiness.

Positive evidence: format 394 files unchanged; analysis no issues; 43 Python tests; corrected-scope 132 Deno tests; 28 real Auth/RLS/HTTP checks; mixed legacy/v1 concurrency admits exactly two of ten at a limit of two; real loopback Deno handlers pass four Auth/reservation/no-evidence checks. These do not cancel the failing gates.

Read [branch and ownership inventory](01_BRANCH_OWNERSHIP.md), [security findings](02_SECURITY.md), [migration reconciliation](03_MIGRATIONS.md), [feature and contract audit](04_FEATURES_CONTRACTS.md), [test evidence](05_TESTS.md), [release checklist](06_RELEASE_GATES.md), and [integration owner handoff](07_OWNER_HANDOFF.md).

Scope limits: fresh hosted reads queried catalog/ledger metadata, not user/business rows or secret stores. No hosted mutation, Edge deployment, Feed publication, production deployment, shared-branch merge, main merge, force-push, or dirty-agent reset occurred. All synthetic SQL/HTTP writes used dedicated loopback containers owned by this audit.

Evidence captured on 2026-10-20. Branches/worktrees can move later. Uncommitted work is inventory evidence, never treated as an integrated commit. No Antigravity/Grok live messaging session is verified; this packet and the current project conversation are the authorized review channel.
