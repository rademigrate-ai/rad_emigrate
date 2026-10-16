# Client-approved visual reconstruction - PR 54

This review supersedes the visual acceptance claims in the earlier redesign report. The client boards are binding. The previous 228 screenshots remain untouched in [redesign](../redesign/README.md).

Final application source: `c5eda9600018b5bf4ba0907169379ba6571c050d`; `lib` tree `1b61ae036430da3ff6221c3d3854e00c364619e9`. Existing captures use `5ddfecffc80f6c5b1785eef8e8f791dc8136b5c8` / `ef05b26462376bf15523121cb4d7c3e91d45ef31`. The only later presentation change fixes the selected desktop rail label from white to theme text color. It has a light/dark contrast regression check; mobile compositions and all captured page content are unchanged. No screenshot regeneration follows the owner stop directive.

For closeout, start with the [concise acceptance report](acceptance.md) and its focused set of existing captures. No further capture generation is planned. Individual PNGs and capture manifests are authoritative; overview indexes may predate the font-readiness correction.

## Review evidence

- [Before/after comparison gallery](comparisons/README.md)
- [Complete before discrepancy matrix](discrepancy-matrix.md)
- [Original client boards](references/README.md)
- [After screenshot matrix](screens/capture-manifest.json)
- [Detail, settings, 320 px / 200% text and focused-composer captures](details/manifest.json)
- [Real production-entrypoint guest interactions](real-app/verification.json)
- [Bird, dock surface and application-contract preservation proof](preservation-proof.json)
- [Verification results](verification.json)

The main captures render actual Flutter pages inside the actual AppShell for supported destinations. Supporting/authentication pages retain their real wrappers. Fixture repositories contain explicitly synthetic records and are excluded from production routing. The Persian fixture names and category labels are localized for visual review; they are not backend content or immigration advice.

Before captures generally showed pages without the shell. After captures include it. Compare the page hierarchy, components and content region rather than subtracting unlike screenshots. Device bezels and synthetic iPhone status bars in the reference are excluded from the implementation. No raw pixel similarity score is used as acceptance evidence.

## Screen-by-screen assessment

MATCHED means the illustrated composition is aligned within the stated real-app constraints and has been visually inspected. PARTIALLY MATCHED identifies the remaining differences explicitly. No screen is called pixel-perfect.

| Screen / state | Evidence | Classification | Result and remaining difference |
|---|---|---|---|
| Entry / bootstrap | [FA light](screens/mobile-fa-light-splash.png), [dark](screens/mobile-fa-dark-splash.png) | PARTIALLY MATCHED | Atmospheric mountain scene, centered original bird, RAD Emigrate name and welcome hierarchy. Existing automatic bootstrap and restored destination are preserved. There is no staged onboarding flow: adding mock pagination or delaying routing behind new CTAs would invent behavior. |
| Dashboard | [FA light](screens/mobile-fa-light-dashboard.png), [dark](screens/mobile-fa-dark-dashboard.png), [image cards](details/fa-light-dashboard-image-cards.png) | PARTIALLY MATCHED | Avatar/greeting/notification header, compact scenic migration hero, red Explore CTA, four icon cards, actual case/document rows and two photographic information cards. Licensed mountain photography replaces the unavailable standalone scenic illustration; consultation uses project scenery rather than an invented advisor portrait. |
| Explore / Visa | [FA light](screens/mobile-fa-light-visa.png), [dark](screens/mobile-fa-dark-visa.png) | PARTIALLY MATCHED | Always-visible search, actual category shortcuts and two-column portrait photo grid with flags and tonal overlays. Wider screens gain more columns. Actual catalog categories/counts remain data-driven. Countries lacking project photos retain an explicit neutral fallback. |
| AI empty | [FA light](screens/mobile-fa-light-ai-empty.png), [dark](screens/mobile-fa-dark-ai-empty.png) | PARTIALLY MATCHED | Centered original bird, greeting, four colored suggested-question rows, chevrons and bottom composer. Disclaimer remains readable near the composer. No unsupported microphone control is added. Reference-specific alternative bird silhouettes are not executable supplied assets. |
| AI conversation | [FA light](screens/mobile-fa-light-ai.png), [dark](screens/mobile-fa-dark-ai.png) | PARTIALLY MATCHED | Real conversation, sources, retry, thinking feedback and composer are retained. The illustrative empty screen does not specify long/error conversations. Existing five functional visual states remain intact. |
| Cases list | [FA light](screens/mobile-fa-light-cases.png), [dark](screens/mobile-fa-dark-cases.png) | PARTIALLY MATCHED | Status filters, compact flag/title/status cards, red/green semantic stages and header create action. Stage segments reflect the existing status timeline; the model has no trustworthy numeric percentage. |
| Case detail | [FA detail](details/fa-light-case-detail.png), [dark](details/fa-dark-case-detail.png) | PARTIALLY MATCHED | Destination photo, metadata/status, vertical timeline and existing status-update actions. Persian timeline explicitly retains the bundled shaping font. Actual workflow stages replace invented checklist completion and percentage samples. |
| Profile summary | [FA light](screens/mobile-fa-light-profile.png), [dark](screens/mobile-fa-dark-profile.png) | PARTIALLY MATCHED | Centered avatar/name/email, compact colored account rows and grouped settings. Existing HTTP(S) avatar values render with a safe initials fallback. No reference user's portrait or private data is copied into the app. |
| Profile edit | [FA edit](details/fa-light-profile-edit.png), [dark](details/fa-dark-profile-edit.png) | PARTIALLY MATCHED | Real supported fields, compact input geometry, cancel/save and failure recovery. No unsupported avatar upload, country selector or biography field is invented. |
| Settings & More | [FA settings](details/fa-light-settings-more.png), [dark](details/fa-dark-settings-more.png) | PARTIALLY MATCHED | Language/appearance are compact expandable rows; secondary destinations remain visible without a long press. Real preferences persist. Unsupported security, translation or account settings pictured in mockups are not fake destinations. |
| Documents list | [FA light](screens/mobile-fa-light-documents.png), [dark](screens/mobile-fa-dark-documents.png) | PARTIALLY MATCHED | Category filters, colored file icons, compact metadata/status/date rows and full-width bottom add action. The existing action creates a document type, then uploads through its file sheet; its honest label remains. No invented file size is displayed. |
| Document actions | [FA actions](details/fa-light-document-actions.png), [dark](details/fa-dark-document-actions.png) | PARTIALLY MATCHED | Neutral document preview composition, actual kind/status, accepted formats, upload and confirmed deletion. No signed preview/download/share/rename API exists in the retained screen contract, so no sample passport thumbnail or dead action row is presented. |
| World Time list | [FA light](screens/mobile-fa-light-world-time.png), [dark](screens/mobile-fa-dark-world-time.png) | PARTIALLY MATCHED | Search, compact flag/city/time/date rows and red add button. Accurate existing city catalog and persisted favorites replace illustrative cities/times. Map and planner/scrubber remain available in expandable mobile sections and a wider desktop composition. |
| City detail | [FA clock](details/fa-light-city-detail.png), [dark](details/fa-dark-city-detail.png) | PARTIALLY MATCHED | Centered flag/city/timezone, analog dial and digital time from the same existing timezone engine. Existing favorite add/remove actions are exposed; unsupported comparison shortcuts are not invented. |
| Five-slot dock | [FA light](screens/mobile-fa-light-shell.png), [dark](screens/mobile-fa-dark-shell.png), [EN](screens/mobile-en-light-shell.png) | MATCHED | Existing glass capsule, raised original bird, five destinations, persistent labels, safe-area spacing, outline icons and active red underline. Existing RTL order and owner-approved bird geometry are preserved. The supplied closeups show different illustrative poses; no authoritative bird is replaced to imitate them. |
| Loading / bird states | [loading](screens/mobile-fa-dark-loading.png), [five states](screens/desktop-en-dark-bird-states.png) | PARTIALLY MATCHED | Existing six-stage natural wingbeat now renders pending operations instead of the Earth composition. Reduced Motion, disabled tickers, disposal and live announcements remain tested. The state artwork boards are conceptual PNGs, not the pictured JSON/WebP sequence files. |
| Login | [FA](screens/mobile-fa-light-login.png), [dark](screens/mobile-fa-dark-login.png) | PARTIALLY MATCHED | Pearl/refined fields and surfaces, original previously approved auth scene and real actions. No detailed login reference was supplied for full composition equivalence. |
| Register | [FA](screens/mobile-fa-light-register.png), [dark](screens/mobile-fa-dark-register.png) | PARTIALLY MATCHED | Shared reference tokens, real account form and locale resilience retained. No screen-specific approved registration layout exists. |
| OTP | [FA](screens/mobile-fa-light-otp.png), [dark](screens/mobile-fa-dark-otp.png) | PARTIALLY MATCHED | Real OTP form, resend and validation preserved; fixture does not claim code/email delivery. Component-level reference alignment only. |
| Forgot password | [FA](screens/mobile-fa-light-forgot-password.png), [dark](screens/mobile-fa-dark-forgot-password.png) | PARTIALLY MATCHED | Shared inputs/buttons and real reset-link request retained. No full approved reference screen exists. |
| Reset password | [FA](screens/mobile-fa-light-reset-password.png), [dark](screens/mobile-fa-dark-reset-password.png) | PARTIALLY MATCHED | Captures show the real missing/invalid recovery-session state; valid server recovery remains an external-session constraint. |
| Profile completion | [FA](screens/mobile-fa-light-profile-completion.png), [dark](screens/mobile-fa-dark-profile-completion.png) | PARTIALLY MATCHED | Shared surfaces and real completion/save behavior retained. No exact approved reference screen exists. |
| Consultation | [FA](screens/mobile-fa-light-consultation.png), [dark](screens/mobile-fa-dark-consultation.png) | PARTIALLY MATCHED | Real request form and draft/auth gating retained; image tile gives access from Dashboard. No detailed form reference exists. |
| Feed | [FA](screens/mobile-fa-light-feed.png), [dark](screens/mobile-fa-dark-feed.png) | PARTIALLY MATCHED | Real published-content route and shared card system retained. Fixture/service-unavailable content differs from illustrative news samples. |
| Notifications | [FA](screens/mobile-fa-light-notifications.png), [dark](screens/mobile-fa-dark-notifications.png) | PARTIALLY MATCHED | Real unavailable-service state and navigation retained; no notifications backend is fabricated for mock sample rows. |
| Admin | [FA](screens/mobile-fa-light-admin.png), [dark](screens/mobile-fa-dark-admin.png) | PARTIALLY MATCHED | Existing role gating, operations and adaptive components preserved; no approved admin board was supplied. |
| Not found | [FA](screens/mobile-fa-light-not-found.png), [dark](screens/mobile-fa-dark-not-found.png) | PARTIALLY MATCHED | Existing localized recovery and adaptive surfaces retained; no approved 404 board was supplied. |

## Rebuilt presentation components

`ReferenceScenery`, `ReferenceJourneyHero`, `ReferenceSection`, `ReferenceQuickAction`, `ReferenceIcon` and truthful `ReferenceFlag`; dashboard header/activity/information tiles; Explore search/category/grid stage; assistant introduction/suggestion rows; compact case filters/cards/detail photograph; document filters/file rows/actions composition; centered profile/avatar and expandable preference rows; World Time city rows/detail analog clock; natural loading adapter; shared pearl/refined colors, translucent cards and clean canvas; active dock indicator and Persian timeline text inheritance.

## Preserved behavior

Domain models, repositories, providers, authorization, Supabase integration, routing contracts and service APIs are unchanged. The original coordinate-resolution/manual-timezone method was restored verbatim from the baseline, including Persian messages. Existing map, favorites, search, meeting planner, scrubber and reset-to-now calculations remain available. The analog and digital clock use the same real selected UTC instant.

AI request/history/retry/source behavior, auth gating, draft restoration and manual send remain intact. Listening feedback represents composer focus; no voice capture capability is asserted. Thinking follows the real pending operation; completion transitions through Responding and New Message to Idle/Listening. The five original state renderers and five bird PNG sizes are unchanged.

Document selection, size/type checks, controller upload, confirmation and deletion are retained. Profile hydration, save/rollback, auth display-name synchronization and failure recovery remain tested. Feed is accessible through the dashboard quick action and visible More destinations; no published production content is rewritten.

## Constraints requiring independent assets or product contracts

Exact scenic illustration, reference portrait, private passport preview and alternative state-specific bird poses are not standalone supplied production assets. The asset showcase and ZIP were inspected: the ZIP contains static logo PNG sizes and previews, not Lottie/Rive JSON or animated WebP sequences. No images were generated, no bird was regenerated, and no package filename pictured inside a PNG was treated as an actual file.

Numeric case progress, file sizes, staged onboarding pagination, voice input, secure document preview/download/share/rename, and unsupported settings were not invented to imitate the samples. These are documented differences, not hidden placeholders. There are no remaining known achievable P0/P1 composition defects after the corrections and visual review; exact artwork/data/feature equivalence remains PARTIALLY MATCHED as listed above.

## Validation and safety

See verification.json for final command results, exact test count, application-source identity and CI link. Coverage includes EN/FA, light/dark, mobile/tablet/desktop, 320 px / 200% text, navigation, real guest preference persistence and AI gating/draft restoration. Focused-composer evidence uses browser focus with a reduced viewport, not a native soft keyboard. No physical Android/iOS execution, real private-file access, production OTP delivery, live AI response or privileged production operation is claimed.

PR 54 remains Draft and unmerged. No deployment, migration, production Supabase/secret change, new dependency, bird replacement or skill installation was performed.
