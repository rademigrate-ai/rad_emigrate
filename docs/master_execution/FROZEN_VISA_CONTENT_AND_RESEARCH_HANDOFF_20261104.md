# RAD Emigrate — Phase 1 source-content delivery / Phase 2 assistant handoff

**Scope:** immutable, read-only delivery of the three RAD source websites in existing
Visa, country, article reader and Other Titles routes, followed by preparation
of the employer-controlled research update workflow.

## Evidence-bound phase 1

Source package: `RAD_CONTENT_PRECEDENCE_V4.1`, corrected package
`4beb6ba711c5b0243d69be29b32a76c13f5ebcc47ce131e7ca406bcd67e6c282`.

- 1,100 original article/locale operations; 44 corrected release batches.
- **1,077 immutable frontend source-display candidates** from the exact sealed
  44-batch membership; 23 held versions excluded.
- Coverage: 56 countries, 251 independent countryless Other Titles, original
  source languages (primarily Persian), plus associated multi-country articles.
- Source block text and original table/list/headline structure are preserved
  as captured. No machine translation, legal claim rewriting or invented facts.
- Each article is a separate gzip asset with two SHA-256 checks; the small index
  is loaded first and article bodies load only when opened.
- Original primary-source URLs and capture/revision hashes remain available.
  Unapproved third-party media and private raw-capture assets are not shipped.
- Captured author text has **not** been independently legally/factually verified.
  The reader displays a source-faithful and editorial-status notice.
- The static snapshot is a temporary **read-only presentation layer**, not a
  second writable CMS and **not** an editorial approval, Production import,
  Supabase publication, or a replacement for authentication.

### Source of truth and behavior

Frontend implementation:

- `scripts/frozen_visa_delivery.py`: fail-closed candidate generator, validates
  payload/manifest hashes, membership, body hashes, 23 holds and 56/251 coverage.
- `assets/visa_frozen_content/index.json` plus `articles/*.json.gz`:
  deterministic, integrity-bound public display snapshot.
- `lib/features/visa/data/frozen_visa_content.dart`: read-only loader.
- `lib/features/visa/data/editorial_repository.dart`: the **live public CMS
  reader takes priority**. A frozen asset fallback is allowed only for a public
  missing-RPC error (`PGRST202`/`42883`) or unconfigured backend. Do not use
  frozen data to mask auth/permission errors, invalid server responses or
  genuinely unpublished content once the CMS public reader is installed.
- Admin preview still requires the genuine server-side Admin RPC; no static
  preview/authentication bypass is allowed.
- Country article cards and source cross-links preserve the actual original
  source language. Missing translations are never synthesized.
- `source_payload_sha256` and immutable `revision_id` bind each frozen article
  for eventual editorial synchronization.

The original corrected-release plan reports **zero human approvals**. Treat
this snapshot as unverified source reproduction, not 1,077 CMS publications.
The owner must make an explicit release/content-rights decision before
public frontend deployment, especially because these are captured website
texts. This change does not run Supabase migrations or modify Production.

### Verification

In the authorized Windows worktree:

```powershell
py -3.14 -m unittest scripts.tests.test_frozen_visa_delivery -v
flutter test --no-pub test/features/visa/frozen_visa_content_test.dart
flutter test --no-pub test/features/visa/frozen_visa_ui_test.dart
flutter analyze
flutter test --no-pub
```

To regenerate **locally only** from the preserved private corrected package,
generate into a fresh destination; never overwrite or silently replace a
shipped signed-in-content baseline:

```powershell
py -3.14 -m scripts.frozen_visa_delivery --package "D:\RAD - Emigrate\_audit\RAD_MASTER_CONVERGENCE_20261031\final-publication-readiness-20261103\corrected-package-v1" --output "assets\visa_frozen_content_next"
```

To ship a regenerated version, explicitly review and adopt it in the Flutter
asset manifest, run the integrity checks and obtain a new release decision.
No private audit corpus or operator receipt belongs in the public repository.

## Phase 2 — research assistant, employer-controlled updating

**Prepared but not activated.** Existing Admin Research UI and the production
`research_findings -> content_drafts(status=review)` path are reusable.

The additive `SourceUpdateReviewContract` and
`ResearchReviewRepository.prepareFrozenSourceUpdate` support immutable,
text-exact source comparison for human-review candidates:

1. Bind source article, locale, revision, original payload hash, exact block ID
   and unchanged original passage.
2. Require the exact original source URL, HTTPS, new captured body hash,
   timestamp and a replacement literally present in that captured body.
3. Produce a **local review candidate only**; block all direct writes to the
   frozen snapshot, AI-driven approval and auto-publishing to Feed.
4. The source body hash proves *integrity*, **not independent authenticity**.
   Before server persistence, the backend must retrieve/prove the authoritative
   source capture and re-check its currency, ownership, destination placement,
   claims, factual official references and original CMS revision.
5. Once the authoritative CMS contains these articles and its current revision
   is bound, an authenticated employer Admin can inspect the original and new
   source side by side, accept/edit/reject the exact proposed changes and
   authorize a new immutable CMS revision through the existing secured RPCs.
6. Server-side verification, concurrency refusal, review receipts and separate
   publication authorization remain mandatory. Research/AI never auto-publishes
   or overwrites the originally captured content.

**Not yet delivered:** authenticated employer source-update UI for these frozen
articles, true live source-authority verification, CMS import/migration of their
authoritative revisions, controlled re-publication and production-API acceptance.
Do not call Phase 2 "operational" until those gates genuinely pass.

### Manual functional acceptance

After a *separately authorized* frontend deployment, use the public routes:

- `/visa/content-countries`: show the country set from the source snapshot.
- `/visa/content-countries/AE`: verify the four Dubai/UAE corrections.
- `/visa/other-titles`: browse sourced independent titles with pagination.
- `/visa/content/<actual-article-uuid>?locale=fa`: read full rich bodies,
  source links, exact language and unverified-source notice.
- Admin preview must still require authenticated Admin authorization.

**No Restore, Production write, CMS merge, browser credential capture or
frontend deployment was undertaken for this phase-1 delivery work.**
