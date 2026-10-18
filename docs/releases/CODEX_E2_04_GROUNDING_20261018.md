# Codex E2-04 grounding regression evidence — 2026-10-18

Master [Issue #57](https://github.com/rademigrate-ai/rad_emigrate/issues/57). Backend-only candidate on dedicated branch `fix/ai-approved-grounding-20261018`, based on main `2739567cc0c228c0b190da177266de9df811be5a`, in isolated worktree `rad_ai_grounding_20261018`. Antigravity PR #68 and combined PR #71 remain separate and unchanged.

## Reproduced behavior

The original loader queried unrelated recent Knowledge when retrieval returned no matches or failed. It accepted absent review statuses and did not require current claims. Open conflicts could coexist with a response reporting `uncertain: false`. Citation URLs were passed through without scheme/embedded-credential checks, and retrieved text could close the surrounding XML content delimiter.

An initial 11-test regression run against the original implementation produced **2 PASS, 9 FAIL**. This included the locale test failing because the unexpected fallback invoked its RPC-only fixture. This is regression evidence, not a live-provider attack or a claim that private production data was exposed.

## Candidate behavior

- Empty/unavailable/malformed retrieval produces insufficient evidence and no unrelated fallback query.
- Explicit parent approval and explicit current/approved claim metadata are required. Current conflicting claims stay labelled; conflict-only claims never become approved citations.
- Any included open conflict forces response uncertainty, including mixed approved/conflicting evidence.
- Absolute HTTP(S) citation URLs without user credentials are normalized and deduplicated. Other schemes and malformed URLs are dropped.
- Retrieved XML delimiters are escaped, preserving the wrapper boundary. Semantic prompt-injection resistance is not established by this change.
- Existing response fields and Persian/English locale handling remain compatible with the Flutter client.

## Local verification

Runtime: Deno **2.5.4**, matching the repository CI pin, invoked through `npx --yes deno@2.5.4`.

`deno test --allow-env supabase/functions/tests`: **43 PASS, 0 FAIL** (26 orchestrator request tests, 13 grounding tests, 4 Research tests). The suite denies network access; upstream/DB calls use fixtures and only synthetic credential canaries. New request tests verify conflict uncertainty with real handler composition, positive current-citation behavior with Persian locale, and missing/unavailable retrieval without fallback.

No Flutter source, migration, infrastructure, production SQL, Auth, Storage, Edge deployment, Feed publication, payment charge or shared-main merge is part of this candidate. Other writers' newly appearing files in the earlier Codex worktree were not staged or reverted. The four owned AI files were copied into this clean worktree to avoid branch changes under another writer.

Initial candidate CI [39127673456](https://github.com/rademigrate-ai/rad_emigrate/actions/runs/39127673456) on `c0954fc` passed 6/7 jobs. Flutter reported 500 PASS / 1 FAIL: the existing backend-source audit required the removed fallback query's literal `review_status=eq.approved`. That assertion is updated to check all three explicit approval/current guards; behavioral tests remain in Deno. This is an existing backend contract audit file, not a UI/widget change. Final CI must rerun; the initial run is not reported as all green.

After updating that audit, `flutter test --no-pub test/acceptance/stage1_ai_research_completion_test.dart` passed **9/9** locally; Dart format check passed with zero changes. No dependency versions were upgraded.

## Acceptance limits

E2-04 remains **IN_PROGRESS**, canonical **3/47 VERIFIED_PASS** unchanged. CI must independently pass on this candidate's exact commit before combined acceptance is considered. Actual provider output quality, evidence freshness, authoritative-source review, multilingual factual evaluation and deployed end-to-end behavior remain open. Release remains **NO-GO**. Unavailable retrieval now deliberately reduces answer specificity instead of silently using unrelated evidence.

Documentation checked: [Supabase changelog](https://supabase.com/changelog) and [Edge Function unit testing](https://supabase.com/docs/guides/functions/unit-test). No Supabase API, SDK or schema change is introduced.
