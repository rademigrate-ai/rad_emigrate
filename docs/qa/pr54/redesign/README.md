# Premium redesign visual evidence

Application source: `44625a24084f128f05ed7484d650fb1019528431`. Library tree: `247afad34e6a715cdf1db8759fedba8e71acc907`.
Final evidence/test commits retain this exact application library tree.

**228 original Flutter screenshots**, 19 screens x 2 locales x 2 themes x 3 viewports. Zero page/console errors. The contact sheets below are resized review indexes; all full-resolution PNGs are retained beside them and enumerated in the [capture manifest](capture-manifest.json).

| Device | English light | English dark | Persian light | Persian dark |
|---|---|---|---|---|
| Mobile | [EN light](mobile-en-light-overview.jpg) | [EN dark](mobile-en-dark-overview.jpg) | [FA light](mobile-fa-light-overview.jpg) | [FA dark](mobile-fa-dark-overview.jpg) |
| Tablet | [EN light](tablet-en-light-overview.jpg) | [EN dark](tablet-en-dark-overview.jpg) | [FA light](tablet-fa-light-overview.jpg) | [FA dark](tablet-fa-dark-overview.jpg) |
| Desktop | [EN light](desktop-en-light-overview.jpg) | [EN dark](desktop-en-dark-overview.jpg) | [FA light](desktop-fa-light-overview.jpg) | [FA dark](desktop-fa-dark-overview.jpg) |

Viewports: mobile 390x844, tablet 834x1112, desktop 1440x900. All 12 contact sheets were visually inspected. Layout/contrast tests separately cover 320 logical pixels and 200% text.

- [Implementation, every screen, and audit reconciliation](../redesign-review.md)
- [Verification record](verification.json)
- [Original bird and dock preservation proof](preservation-proof.json)
- [Actual guest browser interaction results](real-app/verification.json)
- [Visible More entry](real-app/visible-more-destinations.png)
- [Guest AI draft restored after login gating and refresh](real-app/guest-ai-draft-restored.png)

The 228-screen matrix uses actual application pages with synthetic repositories. Notification captures show the unavailable-service state; password-reset captures show the missing/invalid recovery-session state. Persian Feed shows its empty state; English Feed shows synthetic entries. Fixture text such as ?Visual QA traveler? is intentionally synthetic and is not a real user account.

The separate real-app captures use the production entrypoint with CI placeholder configuration, guest mode only. They verify primary navigation, visible access to World Time, persisted Persian/dark preferences and manual AI prompt/login-gate/draft restoration, with zero page errors. No account login, document upload, AI provider request, production Supabase change or privileged action was performed.

Reproduce with `tools/capture_premium_redesign.py`, `tools/build_premium_contact_sheets.py`, and `tools/test_premium_redesign_browser.py`, serving the fixture on port 8824 and the placeholder-configured product build on port 8825.
