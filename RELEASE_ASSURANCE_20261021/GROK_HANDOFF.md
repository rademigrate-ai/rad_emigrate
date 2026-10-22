# Grok / Antigravity integration handoff

Ready branch: `fix/rad-release-assurance-20261021`; verified code `747ab96daa38e303d10121e17c4d711fbb16fabe`; [CI](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39639812325)7/7. Unified branch still `c611f2ac039079c0d3381f5e9cea23185c2f91f6` at latest fetch. No direct messaging channel exists; this chat is the agreed review channel. No review/receipt is claimed.

Code commits in order (apply effects once; branch already contains them):

- `2d49da301fa8667d707d48d0dd408a311e9d87bf` — client contracts/receipts/strict FX/search/current Flutter compatibility.
- `4d2c2158cb07d318d3652e6c4a2ff20dface73a6` — verified session, booking/history/AI/consultation draft isolation.
- `e6708ef214fcbf26917292ed74502a56ad05cea6` — catalogue validation, protected research default,37 lint fixes and CI gate.
- `1b636e21b645dd053d8937945057e95453b5a9e2` — malformed pricing/capacity coercion.
- `3b33f51793a0581148fd485a3c6956384b2f4c77` — explicit-owner caches/controllers/routes/forms/notification reader and genuine approval defaults.
- `747ab96daa38e303d10121e17c4d711fbb16fabe` — booking/appointment action receipt/late completion isolation and keyed private forms.

Grok owns unified integration. Preserve all 4 original847dd42 files and all 80 migration effects. Do not replay prior migrations or copy20 forward files into a hosted command without the owner-approved reconciliation process. No new duplicate SQL migration was added in this phase.

Antigravity review requirements: `DocumentLocalDataSource.readAll/writeAll` require explicit owner; document/application/profile caches reject unowned/wrong-owner rows and purge shared legacy keys. `authenticatedUserIdProvider` is authoritative for private state; `verifiedUserSessionProvider` only projects matching metadata. Profile/immigration/notification/booking/interview subtrees reset on actor change; action controllers drop disposed/stale results. Notification reader is an injectable pure SDK/owner-checked provider. `CuratedRulePackage.approvedAt` is nullable and approval gate rejects absent date; default package empty/unapproved; no synthetic approval dates or government rules in production defaults. These are internal Dart contracts; backend v1 HTTP shapes and SQL RPC names are retained. Review localization/UX unavailable states and existing guest handoff, retain regression coverage.

Operational dependencies are separated in F12/F14/F21 and the migration package. Hosted AIv 11 is incompatible with v1 and retains quota fail-open; researchv 4 lacks protected egress. Do not enable these based on green local CI. Source/provider credentials and real official evidence were not invented. No hosted intervention authorized.

After integration publish the exact SHA to this chat. Codex then verifies presence of every fix, runs supported CI against that exact branch/SHA and critical privacy/quota/RLS/migration checks, and issues a new integrated verdict. Until then unified/Staging/Production remain NO-GO.
