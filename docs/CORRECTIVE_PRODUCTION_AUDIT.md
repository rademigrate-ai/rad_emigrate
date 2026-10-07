# PR #26 corrective production audit

Work continues on the existing corrective branch; no merge is authorized before acceptance.

## Observed baseline (2026-10-07)

- PR head: `8b244a02a4d9e45be8011856861190006158c09c`.
- Production Render service: `srv-db0p4e9srm7s738jam10`, static site, branch `main`, auto-deploy off.
- Last observed live deploy: `dep-db2lfc7lot8c739kq28g`, commit `68f8919c771f0c7af82bfa88a8ac2f05c1abe292`.
- Production did not contain PR #26. Browser showed the old English login and clipped identity image.
- Supabase `inshddthftkhcdosoqcn`: ai-orchestrator v5, research-sync v1. The deployed Research worker was older than the reviewed branch.
- OpenRouter is the only configured provider. Its public discovery had marked it healthy; earlier authenticated requests failed with `provider_unauthorized`. Public catalogue access is not credential proof.
- Five real findings and five review drafts; zero Feed items. Visa has ten published summaries, 18 localized process steps across two programmes, and eight localized requirements for Canada study. The other structured sections remain incomplete.

## Corrective changes

Credential rejection is a persistent provider latch until the stored credential actually changes or an explicit authenticated inference succeeds. Versioned outcomes cannot let an older request poison a replacement credential. Every runtime overload uses the same eligibility contract. Transient cooldowns recover when due. Measured health, latency, success rate, configured preference and explicit cost metadata affect deterministic ranking. Runtime retains a five-attempt/45-second budget and preserves opportunities for another provider.

Model discovery is normalized into one transactional catalogue ingest. New models require Admin enablement, while existing enable/scope/preference values survive discovery. Disappeared models become stale, without deletion. Capabilities are only taken from explicit upstream metadata; otherwise provenance is unknown. No intelligence score is guessed from names.

Research captures exact source evidence and atomically creates a finding plus one human-review draft. Repeated document/hash ingestion is idempotent. Neither worker writes Feed. Fetches are HTTPS-only, host-constrained, redirect-bounded and stream-size-bounded. Errors use an explicit safe-code allowlist.

Add Source uses the existing Admin RPC, defaults to disabled external/admin-only trust, validates required fields and URLs, and refreshes the console. Research now exposes source state, attempts/success/errors, jobs, findings and drafts, and the review transition. Profile save preserves global authentication on ordinary failures. AI send acquires its guard before asynchronous persistence; User and Admin histories have separate scopes. The server controls quotas. Errors are localized and are not persisted as successful assistant answers.

The UI uses bundled Vazirmatn 33.003 (SIL OFL), zero letter spacing for shaping, readable navigation on navy, directional borders, real entry transitions that respect reduced motion, responsive auth, and a Home Visa entry plus real published Feed previews. The official logo and favicon were obtained from `radvisa.com`; the old image contained an already-clipped wordmark. The brand asset is preserved unchanged. The native SVG PWA icon contains that exact image rather than a generated replacement.

The design sources were inspected and relevant Apple, Emil, UI/UX Pro Max and redesign skills installed through personal-skill Git synchronization. VoltAgent/awesome-design-md is a reference collection rather than an installable SKILL; Apple and Linear references were studied.

## Verification boundaries

The Edge test suite currently covers the 16 named routing scenarios and extra credential/research safeguards using synthetic canaries only. Database integration tests exercise real eligibility, cooldowns, credential latch/versioning, atomic review creation and no Feed writes in a rolled-back disposable database. They must run through CI before production migrations.

CI and deployed browser acceptance are separate gates. No successful live AI, profile, Add Source, authenticated Research or rendered Persian acceptance is claimed by this document. Render dashboard authentication is required for deploying the corrective branch without merging; the connector exposes no branch/commit update. Secure browser authentication is also required for the authorized RAD test account. No passwords or server secrets are recorded here.

## Deployment sequence

1. Finish gates on one PR head, including reconstruction and security tests.
2. Apply only the two new additive migrations, matching reviewed repository contents. Do not rewrite prior migration history.
3. Deploy ai-orchestrator and research-sync from that same head; Research enforces its own Admin/worker authorization with gateway JWT verification disabled for scheduled token calls.
4. Deploy the existing Render service from the corrective branch/explicit head without merging. Auto-deploy remains off. The build requires Flutter 3.47.6 and emits public `version.json` with `git_sha`.
5. Verify Render reports that exact SHA, verify `version.json`, then reload a fresh browser and perform the requested screen-by-screen acceptance.
6. Use `responsive-preview.html` to render the actual same-origin application at 390/768/1280 px if browser viewport resizing is unavailable. This page contains no mock state, bypass or alternate backend.
7. Capture sanitized screenshots and record actual outcomes. Do not convert an unknown or blocked check into PASS.
