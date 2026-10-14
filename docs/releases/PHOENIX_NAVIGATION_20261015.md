# Owner-approved Phoenix navigation publication scope

This integration is based on GitHub main
`6d79f810de7454a700b4cc6bacadccff008259ec`, not a merge of the shared UI branch.
The owner approved the six final Phoenix screenshots on 15 October 2026 and
subsequently authorized publishing finalized approved work. No production
deployment or Supabase mutation is authorized. Visual approval is not a
production release approval.

## Included application files

- `lib/core/routing/app_shell.dart`
- `lib/core/widgets/rad_ai_bird_nav_icon.dart`
- `lib/core/widgets/rad_phoenix_navigation_surface.dart`
- `assets/branding/rad_phoenix_final_master.png`
- `assets/branding/rad_phoenix_final_256.png`
- `assets/branding/rad_phoenix_final_512.png`
- `assets/branding/rad_phoenix_final_768.png`
- `web/index.html` — scoped semantics-host direction rule only.
- `test/core/app_shell_navigation_test.dart`
- `test/core/phoenix_final_asset_test.dart`
- `test/core/phoenix_navigation_layout_test.dart`
- `test/core/rad_ai_bird_nav_icon_test.dart`
- `pubspec.lock` — SDK dependency classification corrected by offline pub get;
  no package version changes.

The original shared worktree remains untouched. No unfinished Profile page,
Profile screenshot test, old bird assets, local preview tool, generated preview,
private files, historical evidence directories, or unrelated agent work is
included. The 51 historical branch commits ahead of main were not merged
wholesale or represented as approved by the Phoenix visual decision. Separately
validated client delivery/security work remains a separate reviewed integration;
this PR does not claim to publish all historical work or close its release gates.

## Artwork and source freeze

Master PNG (1536x1024, real RGBA) SHA-256:
`099791d3becc34888e9221e5782a8fa3bd1f05cb66435f8d91913cec74dad07b`.

256px variant:
`0ff9f09f28cf6b8700b9eb2e42b335026d68fee13c2f2298fd2f9ee601b3c3ca`.

512px variant, used untinted in both themes:
`4c85e5f842f66604b7e914c072d5af395b31de63841d790300f2ff0d64d56009`.

768px variant:
`9e7f18616ab7de160236523913dce696ce1efd635fff269838921a858e2f6b8f`.

The three navigation implementation files are byte-exact copies of the owner
freeze inputs before Git line-ending normalization. Geometry, artwork, glow,
glass, ordering, routes, Safe Area, desktop rail, semantics and reduced-motion
architecture were not redesigned. Git LF normalization, when applicable, is a
nonvisual integration-only representation change, not an artwork/source redesign.
`PHOENIX_INTEGRITY.json` binds the freeze hashes and canonical source hashes.

The tested historical Phoenix source fingerprint was
`3b4bb9aee63b6507dc9011dbfbf53bba8d4b208448849543cf89fe6e2a451ef7`.
The new main-based application/test snapshot is intentionally different:
`507b39bc621d084b862dc9f6c8563ed4cfe54e46928ad6c4230119ea4cc06547`.
Do not transfer historical full-product test counts or authenticated E2E claims
to this selective integration. Fresh validation is required on this fingerprint.

Integration-only test changes: remove the generated-preview dependency from
the layout test, exercise the actual AppShell fixture with semantics instead,
and format the existing bird test. No preview is shipped to satisfy a test.
The shared originals were not reformatted or edited.

## Fresh local validation

All native checks below ran on the main-based application fingerprint above:

| Check | Result |
| --- | --- |
| Full `lib` / `test` format dry run | PASS, 217 files, zero changes |
| Flutter analyze | PASS, no issues |
| Full Flutter tests | PASS, 282 tests |
| Web release build | PASS, native exit 0, JavaScript build |
| `git diff --check` | PASS |
| Frozen navigation/artwork and packaged PNG hashes | Bound by integrity receipt |

Flutter 3.47.6 / Dart 3.13.5 on Windows. Raw native logs and source inventory are
retained locally under `%LOCALAPPDATA%\RADPhoenixPublication-20261015`, not copied
into the repository. Command exits/fingerprint are included in the integrity
receipt. GitHub CI results must refer to the eventual exact branch commit, not
be inferred from main's previous green jobs. No authenticated production test
was executed.

Tooling incidents were not hidden: offline pub get succeeded but the local
wrapper initially asserted against its expected lockfile classification change;
the validation epoch began after dependency setup. Web compilation and evidence
writing succeeded, then printing the success glyph hit the Windows cp1252
console encoding. The local wrapper was corrected to UTF-8; native exit 0, raw
build log, fingerprint and packaged assets were independently checked. Neither
incident required or changed application code. Existing secure-storage Wasm
incompatibility warnings remain; no WebAssembly build PASS is claimed.

## Publication and deployment gates

Read-only Render metadata showed `rad_emigrate` following main with
`autoDeploy=no`, `autoDeployTrigger=off` and previews off. No Render deployment
was requested or performed.

Read-only Supabase branch metadata links Git branch main directly to production
project `inshddthftkhcdosoqcn` and reports `MIGRATIONS_FAILED`. The existing main
Supabase Preview check failed with "Remote migration versions not found in local
migrations directory." This is not proof that a new push is harmless.

The owner subsequently verified the dashboard: **Deploy to production ON**,
Automatic branching OFF (disabled; Pro required), and Supabase changes only OFF
(unavailable). The owner expressly permits the isolated branch push and PR but
prohibits merge or a direct push to main. This supersedes the initial main-publish
authorization. Main publication remains blocked until the owner clears the
production-deployment gate and grants fresh merge authorization. No production
settings will be changed to force this PR through. Render being manual does not
disable the separate Supabase integration.
Supabase documents Git-event migration and Edge Function deployments in its
[GitHub integration guide](https://supabase.com/docs/guides/deployment/branching/github-integration).

No migrations, Supabase configuration/functions, Auth settings, credentials,
signing material or CI workflows are changed here. No branch protection may be
bypassed. Merge is conditional on the applicable safety gate and required checks.

## Limitations retained after visual approval

- Real Android/iOS device acceptance and actual screen-reader testing are NOT RUN.
- Flutter web semantics DOM spatial rectangles were not certified; painted
  pointer navigation and automated semantics are not a substitute for AT testing.
- Web compilation uses non-production placeholder configuration, not a connected
  client acceptance or production runtime test.
- Production recovery, live security rollout, deployment configuration, release
  identity/signing and owner change-control gates remain separate. Production
  remains NO-GO.
