# RAD EMIGRATE — ROLLBACK & RELEASE RUNBOOK
**Date:** 2026-10-28  
**Scope:** Staging & Production Deployment Procedures, Rollback Triggers, and Safety Runbooks  

---

## 1. PRE-DEPLOYMENT GATES CHECKLIST

Before any hosted migration or content transaction is executed:
- [ ] Read-only backup manifest provided at `%LOCALAPPDATA%\RAD\staging-backup\connection.json`.
- [ ] Full encrypted database dump taken and verified on an isolated PostgreSQL test instance.
- [ ] Explicit Owner approval received in writing for the proposed import payload.
- [ ] Target confirmed to be Staging (`epolbumcfbohtmgvomki`), NOT Production.
- [ ] Verify SHA-256 of `PROPOSED_IMPORT_REVIEW_ONLY.sql.gz` matches `final-manifest.json`.

---

## 2. ROLLBACK PROCEDURE

If any assertion, constraint, or smoke check fails during the staging update:
1. Immediately execute `import-review/PROPOSED_ROLLBACK_REVIEW_ONLY.sql.gz`.
2. The transaction:
   - Sets lock timeout to `5s`.
   - Restores prior catalog pointers for all changed canonical pages.
   - Clears newly imported draft locale records.
   - Re-enables the staging gate lock.
3. Validate database state using `import-review/READ_ONLY_PREFLIGHT.sql`.
