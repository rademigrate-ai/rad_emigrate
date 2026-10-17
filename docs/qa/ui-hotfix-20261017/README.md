# Five-part UI hotfix acceptance — 2026-10-17

Baseline: `origin/main` at merged PR 55, `3b76c3bcff80d075bfb5000b139384fa7f1edca8`.
Implementation uses an isolated detached worktree. No other worktree, security branch, PR 48 or PR 49 is changed. The owner authorized normal direct integration into main, without a PR or deployment.

## Root causes and corrections

### Navigation interaction

The baseline was reproduced in actual Chrome mobile emulation, rather than inferred from unit tests. With semantics enabled at a 390 px viewport / DPR 3, Explore's invisible DOM button began at **x=470.44** while the painted item began at **x=80.44**. The semantics host's static origin inherited the HTML RTL direction. The old page CSS targeted `flt-semantics-host` inside the engine shadow root and therefore did not reach it. Setting physical coordinate direction on the light-DOM `flutter-view` ancestor fixes that origin while Flutter retains Persian RTL layout.

The original transparent Material covered the whole safe-area region and painted ink behind the glass. Its ink could be visible outside the opaque glass rather than on the intended item. Ink now paints above the glass on a locally aligned, rounded and clipped 64 px Material. Ordinary targets occupy that body; only the original bird retains its existing raised headroom. Icon, label and selection paint positions, glass styling, margins and the original bird animations are retained.

A separate real browser failure was then isolated: Chrome retargeted a touch at **(105,840)** to Explore ending at **y=836**, and emitted a click at **y=833**. In landscape it also selected a clipped body control through the navigation headroom. The small web pointer guard rejects only these native touch clicks when the recorded pointer started outside the navigation target's real DOM bounds or outside a real CSS scroll clip. It uses current layout bounds, with no arbitrary offsets or oversized hitboxes. Keyboard, screen-reader/synthetic activation without a physical pointer, ordinary content targeting and Flutter ink remain available. Six Node tests cover this guard; real browser touch testing covers both locales and viewport changes.

### Clock and Visa geometry

Global Time's old breakpoint forced one column below 600 px. `CityClockGrid` now provides two columns at normal mobile content widths of at least 304 px (336 px viewport with page margins). Exceptionally narrow widths or large system type use one column. Tablet and desktop arrangement remains responsive. Compact padding, two-line names and clock type fit the existing photographic cards. Favorite controls, providers, ticking, IANA/DST conversion, daylight calculations and planner logic are unchanged.

Visa used a fixed 210 px item height. The full grid item now has `childAspectRatio: 1`, retains its two-column mobile arrangement and uses `BoxFit.cover`. Long titles wrap to two lines; exceptionally narrow/large-type layouts fall back gracefully. Approved photo bytes and immigration content are unchanged.

### Destination photographs

The actual destination schema and repository select have no image or license field. Their contracts and database are untouched. The old Dart switch/map required a Flutter edit for each code.

The bundled [catalog](../../../assets/images/destinations/catalog.json) now supplies aliases, country mappings and optional destination-slug overrides. Resolution order is verified destination override → configured country photo → bundled `<iso2>.jpg` convention → neutral bundled travel photo → a styled globe plate if decoding also fails. Codes are trimmed, uppercased and common alpha-3/legacy aliases are normalized. Paths must be safe filenames present in Flutter's AssetManifest; arbitrary URLs and traversal are rejected. The catalog/manifest parse is shared once per session, and images use Flutter's bounded ImageCache. There is no network photo request, API, credential, scraping or endless loader.

Existing source/license records remain in [remote photography](../../design/remote-photography.md) and [Global Time photography](../../design/global-time-photography.json). This task adds no photo files or invented permissions. Future reviewed photography can be published through bundled assets/catalog data without modifying Dart. A newly inserted ISO country record automatically gets the existing matching photo or the neutral fallback. **Universal country-specific photography is not claimed:** an uncovered country needs an authentic, licensed asset in a later app build; production destination records currently cannot supply such a field. Invalid/offline/unknown input deterministically falls back.

### Back navigation audit

Corrected visible/system fallback behavior for these existing routes:

- `/world-clock`, `/consultation`, `/feed`, `/documents`, `/notifications`.
- `/admin`, `/admin/ai-config`, `/admin/operations`, `/admin/ai-research`, `/admin/consultations`.
- Login, registration/signup, OTP, password recovery/reset and profile completion. Only UI navigation changes; submission, session, authorization and recovery contracts are untouched. Profile completion falls back to public home, avoiding a login → incomplete-profile redirect loop.
- Profile's inline editing state has a leading Back action and consumes system Back locally using the existing cancel behavior. Primary root tabs receive no redundant Back button.
- Global Time city detail now exposes a leading Back control as well as its existing bottom Close. The planner remains inline, not a separate trapped route.
- Visa country and program details now use actual nested `/visa/:countryId` and `/visa/:countryId/programs/:programId` routes. Browser/system Back and direct entry share the same hierarchy, invalid IDs remain escapable, and the parent catalog page retains its state. Existing case-detail and document-preview Back/Close controls remain; Feed currently has no separate article-detail route to repair.

The shared Back control pops valid in-app history before using a fixed fallback. Secondary entry points push instead of replacing their caller. GoRouter's URL reflection option is enabled because every pushed secondary target is a declared, deep-linkable route; browser URLs and history therefore follow the actual view. Direct-entry secondary screens consume system Back into their fallback. Flutter's directional Back icon mirrors once; the legacy manually mirrored helper no longer double-flips it.

## Validation

Commands on the final source:

```text
dart format --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
node --test tools/test_pointer_alignment.cjs
flutter build web --no-pub --output build/app-hotfix --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_ci_placeholder
flutter build apk --debug --no-pub --target-platform android-arm64
git diff --cached --check
```

Format and analysis pass; **477 Flutter tests** and **6 pointer tests** pass. Web release and Android arm64 debug builds pass. [Validation results](validation-results.json) record the validated application tree. Regression tests cover actual coordinate taps, ink ancestry/clipping, insets, keyboard/resize, RTL/LTR, large text, clock grids at 280/320/390/744/1200 px, square Visa geometry, image resolution/cache/fallback and secondary/deep-link/system Back. A preexisting test was updated to use the same deliberate URL reflection setting as the application and additionally checks that pushed secondary history can be popped.

[Browser results](browser-results.json) record real Chrome touchscreen/CDP input on actual Flutter widgets with synthetic fixture repositories. All five destinations were tested at center/icon/label coordinates in EN/DPR3 and FA/DPR2 at 390×844, 844×390 and 390×700. Outside-margin/headroom taps, semantic activation, resize/search focus, Visa program direct entry and browser Back/Forward pass. A focused final replay checks secondary URL/history and visible Back in both languages, without capturing more images. One FA selector was corrected to Flutter Material's actual tooltip `برگشتن`; it was a test-selector error, not a missing Back button.

## Focused visual evidence

Exactly four images, inspected at original resolution:

- [Pressed navigation before](nav-press-before-en-dark.png) — ink exposed outside/behind the glass.
- [Pressed navigation after](nav-press-after-en-dark.png) — ink correctly aligned and clipped inside the capsule.
- [Square Visa grid, Persian/dark](visa-square-fa-dark.png).
- [Two-column clocks, English/light](clocks-two-column-en-light.png).

The valid images were preserved during targeted interaction fixes. Later changes to URL reflection and native-touch filtering affect behavior only, not those painted views. No screenshot matrix or repeated capture loop was generated. The original bird master remains SHA-256 `5922e4874cdcaaddfd4ec90e133d764733a7dfc7039b134ca66b8a59c0c22a06`; no branding image bytes change.

[Exact changed-file list](changed-files.txt) includes source, tests, web assets and this evidence. Existing approved loading, glass colors, photographs, typography and clock/planner calculations remain intact.

## Release limits and production boundaries

Chrome is real, but mobile viewports, DPR, orientation and viewport resizing are emulated. Physical Safari/iOS/Android, native PWA browser chrome, physical on-screen keyboards, pinch zoom and VoiceOver/TalkBack remain unverified. Automated Flutter tests simulate native insets/keyboard behavior. Android validation is debug arm64; no iOS build or release signing is performed. Existing Global Time 2D-map/photo-substitution limitations remain unchanged.

No Render deployment, production web publication, Supabase connection/data write, migration, Auth/RLS/Edge/Vault change, secret access, force-push or GitHub workflow dispatch is performed. A read-only Render metadata check confirms auto-deploy remains off before direct integration. Automatically configured GitHub main-push CI may run normally. Separate production release and physical-device acceptance remain owner-controlled.
