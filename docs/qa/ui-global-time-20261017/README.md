# UI correction and RAD Global Time acceptance

Baseline: latest verified main `5257ca5b95fc7caa9612da29a9b207420778e01b`. One branch: `feature/approved-ui-global-time-20261017`. This coordinated task covers navigation, unified loading, destination photography and the client-approved Global Time dashboard. **Owner visual acceptance is required; do not merge or deploy this PR automatically.**

## Baseline audit and root causes

- Render's latest deployment is **live at the same baseline SHA**, confirmed through the approved Rad workspace in a strictly read-only inspection. Public HTML returned HTTP 200 and still referenced the alternate `rad_phoenix_final_256.png`, circular spinner and both languages. See [deployment metadata](deployment-audit.json). No deployment or service configuration was changed. This does not prove that a particular preexisting Safari cache/session has refreshed.
- Web bootstrap and Flutter loading had separate presentations. The bootstrap used another bird, a spinner and simultaneous FA/EN copy. `LoadingState.splash` painted an opaque radial rectangle on the scenic parent. Six asynchronous controls still used Material circular spinners.
- The merged dock had a 48 px glass body and 44 px bird frame. The newly approved balance calls for a 60–64 px body. Text boxes, bird and active highlight need corresponding spacing. Keyboard insets previously left the dock visible alongside the keyboard.
- AE, OM, NO and MY were absent from the destination image map; unsupported codes intentionally returned an identity plate. Three columns started at 600 px, compressing a 793 px browser viewport. The card gradient used opaque theme surfaces that obscured photography and changed contrast in light mode.
- Global Time rendered flat rows, with the planner and timeline behind an expansion tile. Clock initialization awaited optional geographic boundaries, then initialized them again through the resolver. Favorites could be read before preferences finished loading; an intentionally empty saved list was treated as missing data. City photographs were mapped by country, potentially using a country's photo for the wrong city. The planner lacked a user-selected civil time and explicit handling for missing/repeated DST times; partial working-hour matches were presented among suggestions.

## Overlapping PRs preserved

- [PR 48](https://github.com/rademigrate-ai/rad_emigrate/pull/48), head `cc74b338`: security migration review, no UI assets. No migration, contract or production changes are taken from it; it remains open and untouched.
- [PR 49](https://github.com/rademigrate-ai/rad_emigrate/pull/49), head `ab503ed2`: reviewed its actual two-file patch. Its single-flight timezone future and removal of unawaited page initialization already exist in main. They are preserved. This task separates essential timezone data from optional map polygons and withholds clocks if the essential data is unavailable, rather than introducing a competing bootstrap.
- [PR 51](https://github.com/rademigrate-ai/rad_emigrate/pull/51), head `25614157`: public auth routing and locale-resilient forms. These route protections, aliases, draft retention and existing regression coverage remain. Only pending visuals in OTP/reset controls change; submission callbacks and disabled conditions stay intact. PR 51 remains open and untouched.

## Implementation

Navigation uses a continuous 64 px pearl/smoky capsule within a 76 px destination area, 16 px side margins and 8 px clearance outside device-safe insets. All five labels remain, with larger text allowed to grow the surface. The original bird is raised in a 52 px presentation frame without an orb. The dock hides while the keyboard occupies the view, restoring the existing route/tab afterwards.

Startup uses the verified master bird with restrained layered wing motion, Reduced Motion support and one locale-selected live status. Splash feedback is transparent over its scene; full/section/inline tiers retain the established six-stage Flutter wingbeat. Legacy pending controls now use the shared localized RAD adapter, preserving disabled callbacks and duplicate-submission protection.

Visa cards use full photographs, white text over a black bottom gradient and two columns on suitable mobile/tablet widths, increasing columns only with space. Four newly mapped destination photos and authentic Tehran/Berlin city photos are bundled. Every supported destination JPEG is decoded in regression tests. Unknown countries receive a clearly neutral travel fallback, not a falsely named city's image. [Photography sources, licenses and hashes](../../design/global-time-photography.json).

Global Time follows the supplied dark dashboard composition: blue world geography with red city connections, photographic clock cards, an international planner, UTC comparison timeline and favorite-city controls. The map overview uses locally bundled public-domain Natural Earth land geometry; the existing interactive coordinate/timezone lookup remains available separately. Mobile defaults to clocks with a map toggle; desktop shows the overview and a six-card row when space allows. City names and interface labels are bilingual; time/date/offset values are computed live from the existing IANA timezone database.

The planner validates civil time against all real matching instants. DST gaps are rejected; repeated times require selecting the first or second occurrence. Conversion includes destination date and offset. Suggestions require the entire requested duration inside **09:00–18:00 local in both cities, every day**, without holiday or personal-calendar checks. These are suggested working-hour overlaps, never claimed availability. The 24-hour comparison axis is UTC, so each position is an unambiguous instant across DST/date changes. Daylight bands and sun/moon indicators use the [NOAA solar-position approximation](https://gml.noaa.gov/grad/solcalc/solareqns.PDF), including the -0.833 degree threshold; they are estimates, not weather or precision sunrise predictions.

Favorites preserve ordering, additions, removals and intentionally empty lists after reload. Persistence initializes before the page publishes clocks. Optional map-boundary downloads no longer block the clock dashboard.

## Acceptance gates and evidence budget

Nine focused captures are planned: mobile navigation FA/light and EN/dark; actual web startup; in-app splash; the four previously missing destinations in FA/dark mobile and EN/light tablet; Global Time desktop overview, desktop planner/timeline and mobile clocks. This is one bounded pass, not a locale/theme/viewport matrix. Actual Flutter widgets and synthetic fixture repositories are used; no production customer data or fabricated immigration requirements are used.

Canonical format, analysis, complete Flutter tests, web release, Android arm64 debug and all seven GitHub CI jobs must pass on the final source. Results and final commit identity will be recorded in the PR for owner review.

## Focused visual evidence

All nine views below were inspected at original resolution against the owner's defect screenshots and approved references. There are no rendering/console errors in the captured views. Seven images were captured initially. The planner step then stopped before producing an image because the test queried individual text while Flutter grouped the result in one ARIA label. A read-only DOM diagnosis confirmed the correct result and zero application errors. Only the planner and unattempted mobile view were then completed; no existing image was overwritten or recaptured.

| View | Actual application evidence |
|---|---|
| Navigation, Persian / light | [Image](screens/navigation-fa-light.png) |
| Navigation, English / dark | [Image](screens/navigation-en-dark.png) |
| Web bootstrap, Persian / dark | [Image](screens/startup-fa-dark.png) |
| In-app splash, English / light | [Image](screens/splash-en-light.png) |
| Four repaired destinations, Persian / dark mobile | [Image](screens/visa-fa-dark.png) |
| Four repaired destinations, English / light tablet | [Image](screens/visa-tablet-en-light.png) |
| Global Time desktop, Persian / dark | [Image](screens/global-desktop-fa-dark.png) |
| Real planner conversion, timeline and favorites, English / dark | [Image](screens/global-planner-en-dark.png) |
| Global Time mobile, English / light | [Image](screens/global-mobile-en-light.png) |

[Capture manifest](screens/manifest.json) records the exact application tree, image hashes, viewports and successful browser conversion. The startup image deliberately pauses the real HTML before Flutter runs; normal views verify that the startup overlay is removed. The in-app splash visibly has no rectangular panel. The two Visa views show all four repaired photographs with two columns and readable labels. Global Time shows six live photographic clocks on desktop, compact photographic mobile clocks, explicit date/offset conversion, genuine shared working-hour windows, solar daylight bands and favorite controls. No clocks, offsets, weather or availability values are copied from the mockup.

The original bird master remains byte-identical at SHA-256 `5922e4874cdcaaddfd4ec90e133d764733a7dfc7039b134ca66b8a59c0c22a06`. The six-stage Flutter kinetics and Reduced Motion behavior are retained. No further screenshots or cosmetic iteration are planned in this acceptance task.

## Limits

The reference's photorealistic 3D globe and exact city photographs are not supplied as standalone production assets. The implementation uses real offline vector geography with red connections and licensed authentic photo substitutes. The existing shared desktop NavigationRail remains; World Time is a secondary destination under More rather than replacing the rail with the reference's separate full sidebar. Additional cities without an authentic matching photograph use a neutral city plate. Native physical Android/iOS, Safari browser chrome and native keyboards are not physically tested; inset, keyboard and resize regressions simulate their geometry. Browser fixture tests do not assert production Auth/Supabase operations. Android validation uses the debug variant; no iOS build, release signing, deployment, production Supabase modification, destructive cleanup or change to the second clone is part of this task.
