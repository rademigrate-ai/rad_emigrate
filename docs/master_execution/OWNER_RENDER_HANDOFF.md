# Owner deployment handoff — NO-GO

31 October 2026. Do not deploy this candidate while the open gates below remain unresolved. This document prepares the owner operation; no Render deployment, hosted schema/data mutation, publication or temporary-project deletion occurred.

## Candidate identity and evidence

The authoritative working branch is `execution/master-completion-20261029`. It combines current main `0e8b8df206a3824d7a47f2c029e690ec072c6372` with Draft PR #89 and the tested fixes in the master ledger. The final candidate SHA is the Draft review branch HEAD recorded in the external execution receipt and GitHub checks; a document cannot contain its own commit hash. Do not substitute the old main SHA or a different branch's green checks.

Source and safe metadata are reviewable in Git. Source archives, raw captures, synthetic accounts, SQL corpus payloads, build configuration and generated artifacts remain outside Git under the shared workspace `_audit/RAD_MASTER_EXECUTION_20261029/`. `content/FINAL_CONTENT_VERDICT.json` pins the original content receipts; its local plan is **not** a hosted import package.

## Required GO gates before the owner deploys

1. Reconcile actual Production catalog and migration effects against the exact candidate, including dependencies and effective ACLs. The two new Research migrations depend on CMS/Stage7 objects missing from Production; never apply them alone or blindly replay 109 historical migrations.
2. Produce a current recoverable Production backup and independently verified isolated restore, including required Auth relationships, Storage bytes and configuration evidence. Native synthetic tests are not a Production restore. No approved/tested Production connection or recovery receipt was available to this execution; only dedicated Staging backup scripts were visible in the inspected operator folder.
3. Build and rehearse the minimal Production-specific forward and provenance-preserving draft reconciliation package against that restore. Bind current heads, source identities, the authorized import actor, hashes, retries and rollback. Preserve existing 738 articles/745 heads and all human work. The 3,806 CMS and 3,187 evidence archive rows already transferred must not be blindly reimported.
4. Resolve or explicitly disposition the 421 source URL limitations and obtain required editorial review. Offline captured-body preservation passes; complete hosted/application coverage does not. Published-head count remains zero in Production.
5. Configure and verify protected egress, explicit official source bindings, independently approved authorities, scheduled queue consumption and real Admin review. The owner permits no paid AI/search-provider calls; catalogue presence and stale provider health cannot certify fresh AI acceptance.
6. Complete real authenticated browser acceptance against the final populated backend and current client. Owner deferred this while Docker Secrets Engine startup is blocked. Native role tests and the 1,098 full SQL-body comparisons do not replace browser E2E.
7. Review Release A/B feature evidence and external dependencies in acceptance_gates.json. Payments are not certified live; OCR, email/SMS/push, signing/store identity, real devices and client UAT require their own evidence. The Android artifact is debug only; iOS signing was not performed on Windows.
8. Complete independent final review and exact-SHA CI, then integrate only authorized compatible changes. Keep Draft PR #89 and the execution review unmerged while release-critical gates remain open.

## Exact manual Render procedure after all gates pass

1. Confirm the reviewed release SHA is on GitHub main and that all required checks ran on that exact SHA. Record it in the deployment receipt.
2. Open [the existing RAD Render service](https://dashboard.render.com/static/srv-db0p4e9srm7s738jam10). Keep Auto Deploy disabled and use the existing service; do not create a replacement.
3. Verify repository `rademigrate-ai/rad_emigrate`, branch `main`, build command `bash scripts/build_web_render.sh`, publish directory `build/web`, and SPA deep-link fallback.
4. Verify `APP_ENV=production`, `SUPABASE_URL=https://inshddthftkhcdosoqcn.supabase.co` and the active public `SUPABASE_PUBLISHABLE_KEY`. Never put service-role keys, provider secrets or database credentials in frontend build variables.
5. Owner selects Manual Deploy → Deploy a specific commit and enters the reviewed SHA. Do not deploy an unmerged Draft branch or accept the latest commit without comparing it.
6. Record Render deploy ID, commit, timestamps and build result. Fetch `/version.json` without a cached response and require git_sha to equal the selected SHA. The build script writes this public identity file.

## Post-deployment smoke checks

Verify fresh and cached sessions, login/logout and role redirects; published-only Visa country/category/Other Titles/search routes; authorized Admin draft preview; Persian RTL/English LTR, tables/media/anchors; two-user private documents; actual Research proposal Accept/Edit/Reject; explicit publication boundaries; AI quotas/provider evidence where authorized; consultation, booking, notifications and honest unavailable states. Compare expected public revision IDs and body hashes. If content remains draft-only, public emptiness is expected and must not be called full public content completion.

## Recovery and rollback

The currently observed Render live deployment is `dep-dbd5794ipgvc73e51si0` at `ccf041a371baf029ba5a5bccc01cabf394628a43`. Preserve its identity as a fallback reference; it is substantially behind main. Before relying on web rollback, verify that the additive backend remains compatible with that client.

For client regression, the owner can use Render's existing rollback/redeploy controls for the verified compatible prior deploy. Database recovery is separate: use the reviewed manifest's journaled rollback only for untouched imported drafts, preserving later human edits, publication pointers, immutable evidence and audit history. Prefer compatible forward fixes for schema issues. A full backup restore is a separate irreversible recovery decision accounting for writes since the snapshot; never replace Production with Staging or drop evidence tables as a shortcut.

Staging and Security remain retained. Staging still contains unique operational source/provenance and backend objects; the inactive Security project's internals and recovery dependencies were not cleared. No project is certified for deletion.
