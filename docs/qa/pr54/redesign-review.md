# RAD Emigrate implementation and audit reconciliation

Historical technical review. The client-approved [visual reconstruction and fidelity assessment](fidelity/README.md) supersedes the visual acceptance statements here. The original evidence remains unchanged.

Review date: 2026-10-16. Repository: `rademigrate-ai/rad_emigrate`.
Branch: `feature/premium-ui-ux-overhaul-20261016`. [Draft PR #54](https://github.com/rademigrate-ai/rad_emigrate/pull/54).

Baseline was fetched and verified at `c252b829a70235188f2722177ac58672d09552ec`, matching the remote branch. The checkout was clean; the only existing worktree was this checkout. Existing Dart processes belonged to the editor/tooling, not another running build. No other agent's work was overwritten.

Implementation commits:

- `a183375` — shared semantic surfaces, adaptive assistant, bilingual journeys, discoverable secondary destinations and regression coverage.
- `44625a2` — remaining adaptive admin/startup surfaces and map controls.

The attached third document was used as the execution brief. Grok and Freebuff were investigative evidence, independently checked against the fetched source. Mockups supplied visual direction; their sample users, case percentages and immigration details were not introduced into production. No Apple HIG, Liquid Glass, Flutter, or named design skill was found in the installed skill directories. No skill was installed, reinstalled, or claimed as used.

## Result and design system

`PremiumTokens` now supplies the canvas, content/elevated/glass surfaces, border, text, muted/disabled text, accent, contrast foreground, semantic statuses and focus colors. `AppTheme` consumes the same ramp for component surfaces, rail, input fills, dialog/sheet chrome and typography. The existing bundled Vazirmatn font remains in use.

| Role | Pearl Glass | Refined Glass |
|---|---|---|
| Canvas | `#F5F7FA` | `#070A0F` |
| Surface | `#FFFFFF` | `#10151D` |
| Elevated surface | `#EEF1F5` | `#171D27` |
| Border | `#DCE2E9` | `#29313D` |
| Primary text | `#17202B` | `#F8FAFC` |
| Secondary text | `#596575` | `#AAB2BF` |
| Action fill | `#D91F2B` | `#D91F2B` |
| Small accent foreground | `#D91F2B` | `#FF7685` |

The lighter dark-mode foreground is an accessibility variant for small red text, not another action fill. Semantic text/status foregrounds and disabled-send foregrounds are checked at >=4.5:1 against their surfaces in `premium_redesign_test.dart`.

The radius scale is 10 / 14 / 18 / 24 / 28 / pill. Feature card/input geometry uses `AppRadii`. The approved dock and bird geometry are excluded from this migration. Shared breakpoints remain 600 / 900 / 1200; readable content-width caps remain feature-specific. Existing `AppSpacing` and motion primitives are retained. Bird response timings now have named motion constants; authoritative bird animation implementation remains unchanged.

`RadGlassSurface` provides clipped, theme-aware elevated panels, with optional blur and an opaque Reduced Motion fallback. Auth forms and the visible secondary destination panel share it. Ordinary lists do not gain blur layers; existing dock blur remains unchanged. Material sits above painted surfaces so ListTile ink and selections stay visible. `InlineAlert` unifies persistent form failures; SnackBars remain transient confirmations. Known data transport/session failures are localized without exposing backend diagnostic text.

Primary navigation now says Explore / کاوش. Desktop uses Home, Explore, the actual bird, Cases and Profile, with a visible More group. Profile exposes World Time, Feed, Documents, Consultation and Notifications for both guests and signed-in users; Admin appears only when the existing authorization snapshot permits it. Existing route guards remain authoritative. The bird long-press menu remains available as an additional shortcut.

There are 62 new ARB keys, mirrored in English and Persian, covering editorial headings, continent names, World Time/planner controls, tooltips, assistant semantics and consultation labels. The custom localization facade remains the intentional repository architecture. Raw consultation statuses/timestamps are now presented through localized labels and date formatting. Source/user-authored content and IANA timezone identifiers retain their original values.

## Screen completion and evidence

“Matrix” below means actual product widget composition at 320 logical pixels / 200% text, EN/FA × light/dark. Normal mobile/tablet/desktop screenshots are separate browser evidence. Synthetic fixture records never represent production/customer testing.

| Screen/route | Implemented change | Theme/RTL/responsive evidence | Remaining boundary |
|---|---|---|---|
| Shell/mobile capsule | Explore label; filled selected icon; routes and semantics preserved | Existing geometry, labels, keyboard, safe-area, tab-state and RTL tests; shell screenshots | Physical safe-area/blur performance untested |
| Desktop rail | Adaptive ramp; actual bird; same five primaries; visible More | Existing rail tests and desktop screenshots | Native desktop app untested |
| Dashboard | Pearl/refined hero, authentic bird, adaptive metrics, localized kicker/shortcut | Matrix + screenshots | Synthetic summaries, not live account data |
| Explore/countries | Shared hero/radii/breakpoints; ARB continent/error labels; deliberate country plates | Matrix + screenshots; catalog resilience tests | Published content depends on service |
| Country detail | Removed ineffective Hero; consistent surface/radii | Existing Visa tests; source inspection | In-page stage, not a Hero route transition |
| Program detail | Shared geometry and localized headings/actions | Existing Visa tests; source inspection | No eligibility/fees/requirements invented |
| AI Assistant | Adaptive disclaimer, bubbles, loading text and composer; readable disabled-send; localized bird semantics | Matrix; assistant persistence/retry/guest tests; screenshots | Live provider session not exercised |
| Cases list/detail | Shared canvas; real status/progress contract preserved; fixed unbounded card-row layout | Matrix; application status tests; screenshots | Live account mutations not exercised |
| Profile/edit/settings | Adaptive hero, visible secondary links, correct edit tooltip; shared forms/preferences | Matrix; save-failure/session tests; screenshots | Actual user metadata sync not exercised |
| Documents/upload sheet | Shared canvas, component surfaces and safe failure labels; existing file actions retained | Matrix; storage/document tests; screenshots | Actual private upload/preview not exercised |
| World Time | Adaptive hero/cards/planner/manual sheet; localized controls; full-size remove/map targets; wrapping planner/timeline controls | Matrix; timezone/DST/geo/date/ticker tests; screenshots | External map tile availability varies |
| Login/register | Adaptive glass form; localized editorial chrome; shared alert; preserved `from=`; removed fabricated progress | Matrix; auth/guest/locale tests; screenshots | Real sign-in not exercised |
| OTP | Same cinematic shell; actual verification operation; no invented progress | Matrix; resend/OTP/auth tests; screenshots | Real OTP delivery not exercised |
| Forgot password | Same shell/alerts; account-neutral failure/success behavior preserved; return destination retained | Matrix; recovery retry/pending/rate-limit tests; screenshots | Real email delivery not exercised |
| Reset password | Same shell; recovery/session gate preserved | Matrix; recovery-state/session tests; screenshots show missing recovery state | Valid server recovery session untested |
| Profile completion | Same shell; real operation label; removed fake percentage | Matrix; auth redirect tests; screenshots | Live profile completion untested |
| Splash | Adaptive canvas/text with original branded loading scene | Existing scene/loading smoke tests | Native startup timings untested |
| Consultation/history | Shared header/radii/alerts; localized real statuses/date formatting | Matrix; draft/manual-submit/guest tests; screenshots | Live consultation history unavailable |
| Feed | Shared adaptive hero/components; localized editorial kicker | Existing reviewed-publish acceptance tests; screenshots | Live feed mutation not exercised |
| Notifications | Shared canvas, recoverable error/empty states, labeled compact actions, login return path | Matrix; screenshots show service-unavailable state | Real notification retrieval/read marking untested |
| Admin hub | Adaptive cards/canvas; localized editorial label; consistent geometry | Matrix + screenshots | Fixture hub is not authorization evidence |
| Admin config/operations/consultations/workspace | Shared canvas and component theme; readable status/date labels | Existing form-recovery and admin authorization/review/publish tests | Live privileged actions untested |
| Admin review/source dialogs | Shared dialog/sheet theme; existing review/publish gates preserved | Existing admin form/URL/review tests; source inspection | Live service-backed sheet content untested |
| Not Found | Branded, localized recovery card with Home action | Matrix + screenshots | None known in widget layout |

No separate onboarding or settings route was fabricated. Existing splash/entry and Profile settings implement those supported journeys.

## Freebuff and Grok reconciliation

Both reports' P0/P1 claims were confirmed at the fetched baseline, with the following qualifications: `PremiumTokens` was already registered on `AppTheme`, but was not driving its values; the `explore` localization getter already existed; source at this baseline still explicitly passed `dark: true` to the AI canvas. Historical claims were not used to create duplicate APIs.

| Finding | Baseline classification | Final disposition / evidence |
|---|---|---|
| P0-1 Explore label | CONFIRMED | FIXED — `app_shell.dart`, navigation regression test |
| P0-2 hidden secondary destinations | CONFIRMED | FIXED — `secondary_destinations.dart`, Profile and desktop More, direct-tap test |
| P0-3 assistant dark/contrast | CONFIRMED | FIXED — token-based assistant surfaces, matrix and contrast test |
| P1-1 token adoption | PARTIALLY FIXED at baseline (extension registered) | FIXED — shared theme/components/high-traffic consumers use semantic roles |
| P1-2 dark ramps | CONFIRMED | FIXED for application chrome — content photography/day-night illustration shaders remain intentionally distinct |
| P1-3 multiple reds | CONFIRMED | FIXED for feature action fills; documented readable small-text variant; approved bird/dock artwork retained |
| P1-4 radii | CONFIRMED | FIXED for migrated feature surfaces — `AppRadii`; platform/illustration geometry intentionally separate |
| P1-5 breakpoints | CONFIRMED | FIXED in shell/auth/Visa/World Time; content-width caps retain their different reading purposes |
| P1-6 World Time third system | CONFIRMED | FIXED — semantic cards/header/planner/sheet; deliberate city plates where photography absent |
| P1-7 photography gaps | CONFIRMED | FIXED via country-code/identity plates, without unlicensed photos; bundled licensed photo map retained |
| P1-8 split auth/fake progress | CONFIRMED | FIXED — all six pages share `AuthCinematicFrame`; unsupported percentages removed; real operation labels replace invented steps |
| P1-9 error styles | CONFIRMED | FIXED in auth/consultation and shared states/theme; transient repository failures retain SnackBars |
| P1-10 localization | CONFIRMED | FIXED for audited editorial/World Time/Visa/profile/assistant chrome — ARB/facade; user/source data remains original |
| P2-1 dead Hero | CONFIRMED | FIXED — removed unmatched in-page Hero |
| P2-2 register `from=` | CONFIRMED | FIXED — URI preserves destination |
| P2-3 edit tooltip | CONFIRMED | FIXED — localized Edit profile |
| P2-4 rail tooltip/contrast | CONFIRMED | FIXED — ARB tooltips and adaptive foreground |
| P2-5 desktop/mobile IA | CONFIRMED | FIXED — shared five primaries, visible grouped secondary access |
| P2-6 list/detail seam | CONFIRMED | FIXED — Cases detail and Documents canvas |
| P2-7 generic errors | CONFIRMED | PARTIALLY FIXED — known typed transport/session failures distinguished; unknown details remain private, intentionally generic |
| P2-8 404 recovery | CONFIRMED | FIXED — branded localized recovery action |
| P2-9 motion literals | CONFIRMED | FIXED in migrated city/map/carousel/assistant timing; authoritative bird rig remains unchanged |
| P2-10 suspected bird clipping artifact | UNVERIFIED | Unchanged original rig/artwork; not presented as a confirmed defect or on-device pass |
| P2-11 loading-bird contrast | UNVERIFIED | Semantic button disabled text verified; original secondary/ghost loading artwork preserved; native visual contrast still unverified |
| P2-12 component shapes | CONFIRMED | FIXED — shared card/input/chip/dialog/sheet/radius roles; icon/status pills retain deliberate compact geometry |
| P2-13 selected chip accent | CONFIRMED | FIXED — shared red selected chip fill through `chipTheme` |
| P2-14 consultation raw status/date | CONFIRMED | FIXED — `record_labels.dart`, including admin queue |
| P2-15 mixed-language long greeting | PARTIALLY REPRODUCIBLE (fixture content) | Auto-height hero and matrix prevent clipping; actual user names are not translated or shortened |
| IND-1 rail light mode | CONFIRMED | FIXED — adaptive rail surface |
| IND-2 selected accent | CONFIRMED | FIXED — semantic accent foreground |
| IND-3 collapse control | CONFIRMED | FIXED — localized visible tooltip/foreground |
| IND-4 secondary discovery | CONFIRMED | FIXED — Profile links and desktop More |
| IND-5 desktop robot identity | CONFIRMED | FIXED — original `RadAiBird` |
| IND-6 loading text | CONFIRMED | FIXED — semantic text on semantic card |
| IND-7 English editorial copy | CONFIRMED | FIXED — audited kickers and auth eyebrows localized |
| IND-8 NotFound | CONFIRMED | FIXED — recovery card |

## Verification and limitations

The screenshot manifest and verification record in [redesign/](redesign/) are authoritative for counts, source revision, command results, and browser errors. Screenshots use actual Flutter product pages with controlled fixture repositories. Widget tests verify 320 px / 200% text in both locales and themes; screenshots cover 390×844, 834×1112 and 1440×900. Existing tests continue to enforce routing, auth, roles, review gates, manual publishing and storage contracts.

No production Supabase account or data was used. Therefore document upload/preview, valid password recovery, actual OTP/email delivery, live AI replies, private notification/history data and privileged admin operations are not claimed as end-to-end passes. No physical Android device, Android emulator or native iOS run occurred. APK compilation is separate evidence from device execution.

The local Android toolchain emits existing SDK XML, Java native-access and `file_picker` Kotlin migration warnings. Web uses the established JavaScript renderer; no WebAssembly compatibility claim is made. Existing CI schema/reconstruction checks are left intact and must be evaluated on the final PR head.

## Safety

PR remains Draft and unmerged. No deployment occurred. No production database, Supabase configuration, secrets, migrations, functions or storage policies were modified. No backend publishing permission was widened. Original bird source/derivative files and its animation/nav rendering files were not changed. Approved capsule geometry, safe-area layout, keyboard hiding and tab-state architecture were preserved. No new photography, fonts or dependencies were installed.
