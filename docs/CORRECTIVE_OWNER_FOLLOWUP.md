# Owner correction follow-up — PR 26

Scope: continuation of `feature/corrective-production-audit`, baseline `5a0aa564eed391656736401715f8dd8ef8daf8de`. No Render mutation, new branch, merge, production credential change or production data mutation in this follow-up. Owner deploys the final green PR head.

## Implemented corrections

- Canonical branding is derived from the exact owner-uploaded 1254px transparent WebP. Original bytes and SHA-256 are retained in `assets/branding/provenance.json`; square application logo, web favicon/touch/PWA icons and Android density launchers preserve identity. Shared `RadBrand` covers Splash/Auth/Home/shell/navigation/AI and inherited Admin chrome.
- Filled/Outlined/TextButton and desktop Rail label overrides explicitly retain bundled Vazirmatn and zero letter spacing. Their previous partial TextStyles replaced Material typography and could route Persian labels into renderer fallbacks. Existing valid ZWNJs remain unchanged. Bundled fonts cover the Persian ARB characters and joining substitutions. This source/font audit is not all-screen rendered acceptance.
- AI requests carry previous conversation turns. Initial send waits for history restoration, and restoration selects the latest bounded 200-message page in chronological order. Failed requests stay actionable with Retry; retry reuses the saved user question, replaces the failure notice, and excludes failure notices from provider context and saved assistant replies. A supplementary question-count failure cannot turn a committed insert into an apparent save failure. The informational count can lag; server request quotas are unchanged.
- Profile mutation errors retain the populated form for retry. Supplementary profile-name lookup transport failures no longer discard an otherwise valid auth session; actual auth failures retain normal behavior.
- Sources accepts supported public HTTPS DNS page addresses, normalizes host/default port/trailing path separators for duplicate checks, and rejects local/IP/internal/credential-bearing/fragment/nonstandard-port addresses before mutation. Query addresses are explicitly rejected because the current RPC/worker cannot preserve them safely. The source is created disabled with external/admin-defined/Admin defaults; existing role and database uniqueness enforcement remain authoritative.
- Admin model settings remain in the dialog after a failed save, with localized recovery and a pending guard. Provider credential rejection is distinct from a stored credential. Known Admin scope/health/errors are localized; arbitrary provider/database diagnostic text is never displayed by the diagnostics card.

## Verification and limits

New regressions cover actual widget form recovery, AI history/restore races/retry persistence, session preservation, effective Persian RenderParagraph typography at 390px/1440px and both themes, canonical assets and narrow brand semantics, URL validation and safe localized diagnostics. Tests use isolated fixtures; they do not prove production inference or protected UI saves.

The resumed local runtime lost 136/142 app dependency package directories and 101/102 Flutter-tool package directories. Dart formatting and diff checks remain runnable; full Flutter gates run through GitHub CI on the final head.

The secure browser sign-in request on 7 October 2026 returned `declined`. No credentials were read/entered/logged and no lower-level fallback was used. Protected app manual acceptance (Home, Feed, Visa/detail, AI/Admin, Research/Sources, Profile, Applications/Documents and their states) is still pending. The currently deployed app predates these corrections; its screenshot cannot prove the corrected logo or typography.

Read-only production evidence on 7 October: 6 findings, 6 review drafts, 0 orphan findings, 0 Feed items. Latest successful official-source job finished at 07:55:44.776 UTC. OpenRouter remains offline with `credential_rejected=true`, safe code `provider_unauthorized`; no successful new inference is claimed. Research/AI still require human review and explicit publish. No new production research run was submitted in this follow-up.

Visa editorial gaps remain subject to `docs/CORRECTIVE_VISA_EVIDENCE.md`: verify official evidence, record source/date, edit and review real content, and publish explicitly. No immigration claims were invented to fill blanks.

Final commit/CI identity and complete acceptance limits are supplied in the dated handoff report after CI finishes. Device-installed PWA/launcher appearance and all-screen Persian pixels require actual acceptance after owner deployment.
