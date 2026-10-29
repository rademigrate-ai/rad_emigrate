# ROADMAP UPDATE: EIGHT-STAGE ACCEPTANCE PLAN
The originally numbered seven-stage plan has been extended to EIGHT stages by adding a dedicated FULL FEATURE ACCEPTANCE & BUG FIXING gate between local automated QA and hosted Staging backup. Use the authoritative acceptance matrix at _audit/RAD_FULL_FEATURE_ACCEPTANCE_MATRIX_20261028.md for all 21 Flutter feature modules, 8 Edge Functions, all routes, roles, EN/FA, UI/UX, security, error states and hosted revalidation.
The stage numbering below remains the historical 7-stage baseline and is superseded where it differs from the linked 8-stage matrix.

# RAD Emigrate — Finalization Roadmap & Sequential Gates
Date: 2026-10-28
Rule: Execute ONE phase at a time, preserve all worktrees, no unapproved hosted writes/publication.

## Phase 1 — Verify baseline & lock acceptance criteria [DONE]
- GitHub PR #85 is Open, Draft, NOT merged. Remote HEAD: `2484537ce05c11bf7463d62b043851dc04a35057`.
- CI run 40650871013 completed SUCCESS (8/8). Baseline verified, NOT a guarantee that staged content is complete.
- Local Antigravity integration worktree at `_stage7/worktree` is still `a97b585` with untracked `_scratch/`. Do not reset or overwrite. Fetch remote safely in next code integration phase only after worktree inspection.
- Local isolated Stage 7 & Stage 7.1 SQL QA previously passed. NOT a hosted RA positive-path pass.
- Grok local intake currently contains 33 HTML/TXT pairs, 0 original 146 primary-source TXT files, missing original 100 manifest and mapping CSV. 67 of exact 100 body-ready IDs still not locally verified by latest independently hashed recovery.
- Content architecture: main canonical Visa page per Country × Visa Category combines RAD Visa + DigiVisa source-faithfully; all relevant RAD Mohajer independent articles (including visa-pathway topics) live in the ONE Other Titles section; keep review flags. No auto-publication.
- Hosted Staging backup private connection.json absent; hosted Staging import NO-GO. Production strictly untouched.

## Phase 2 — Close source recovery & de-duplicate evidence [NEXT]
Inputs: Codex 422-row inaccessible register, Antigravity 259 cached raw HTML / 206 substantive body corpus, Grok 100 body-ready frontier, Codex 146 primary-source records.
1. Preserve and checksum original raw assets and full-body/source maps. Obtain original Grok 355-file package via authorized sync where possible.
2. Reconcile exact source_id, canonical URL, hash and version. Existing 100 body_ready URLs have zero overlap with current 259 Antigravity URLs by exact normalized URL; do NOT claim semantic uniqueness yet.
3. Verify local 33 refetched pairs (done), recover/record precise blockers for remaining 67 without bypassing host limits.
4. Audit 53 zero-body cached pages for category/listing vs genuine extractable article; preserve evidence.
5. Verify availability and byte provenance of all 146 DigiVisa / RAD Visa bodies vs Codex intake; do not duplicate source material.
**Exit:** a closed, checksummed, source-level inventory of all three sites; every unresolved item with specific blocker and editorial flag. Nothing imported.

## Phase 3 — Build source-faithful import-ready drafts
- Consolidate 148 candidate canonical locales/coverage claims against real RAD Visa and DigiVisa evidence; do not conflate candidate packages with live data.
- Every canonical Visa category has exactly ONE continuous rich page, full unique paragraphs/tables/lists/document requirements/procedures/FAQs, versioned evidence and conflicts flagged.
- Exactly ONE Other Titles collection; full independent Mohajer bodies, and independent non-Visa RAD Visa/DigiVisa bodies.
- Preserve 29 proposed destinations as draft-only until evidence and editorial approval.
- Reconcile Codex 80-new/91-revised/20-hide suggested operations against exact source hashes; do not assume they are all approved.
**Exit:** versioned reproducible draft payloads + mapping + duplicate ledger + human review queue, regression-tested offline.

## Phase 4 — Local application and backend acceptance
- Validate existing integration branch remote HEAD vs local worktrees, preserve contributor edits; integrate necessary changes safely.
- Verify Admin Visa editing/readers, rich content, RTL Persian, full articles, per-country mapping, navigation and AI-research review to drafts with zero Feed auto-publishing.
- Run Flutter analyze + complete tests, Python delivery tests, local SQL Stage 7/7.1, web/Android builds, migration reconstruction and all CI on ONE commit SHA.
**Exit:** green local & GitHub gates plus recorded screenshots/role-flow evidence, with no claim of hosted success.

## Phase 5 — Hosted Staging backup & restore gate [OWNER ACTION REQUIRED]
- Configure read-only secure backup access with owner authorization; create encrypted hosted-data backup and actually test restore into an isolated environment.
- Verify DB/schema/migration ledger, ACL, content and rollback procedure before any hosted writes.
- No credentials in Git; no destructive changes; Production read-only.
**Exit:** evidence-backed signed-off backup/restore. Without this, hosted Staging import is BLOCKED.

## Phase 6 — Authorized hosted Staging import & E2E
- Obtain specific Owner authorization for exact Staging write/import scope only AFTER Phase 5.
- Import draft-only with idempotent journal and rollback; verify Admin review/edit/save, research findings→content drafts positive path, and negative Feed auto-publication checks. Test all real User/Admin flows, rich UI/UX and accessibility.
- Reconcile live counts, rendered full bodies, source hashes and human-review queue.
**Exit:** demonstrated hosted E2E and written content/render integrity evidence; only then consider Client Demo GO.

## Phase 7 — Final delivery / release decision
- Independent review of PR #85, final CI on same HEAD, no merge while Draft unless owner explicitly authorizes.
- Delivery checklist: exact source coverage, unresolved limitations, staging demo evidence, permissions/RLS, rollback, release notes, Android/web builds.
- Production deployment / publication only after a separate explicit owner GO and proven rollback.
**Exit:** documented GO/NO-GO, owner sign-off, controlled merge/deploy if authorized.

## Execution priorities and strict stop rules
- Finish Phase 2, then Phase 3, then Phase 4; do not hide or skip the Phase 5 gate.
- Source material and immigration claims require source citation; do not invent legal details.
- No silent article drops, no auto-approval, no Feed auto-publish.
- Do not modify currently active contributor worktrees or erase _scratch.
- No PC shutdown as a side effect of this review/roadmap.
