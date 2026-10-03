# Project 14 — Feed, Notifications, Localization and PWA

Project 14 adds a review-gated bilingual content feed with source attribution, effective/expiry dates, bookmarks, read state, notification preferences, per-user notifications, and private push subscriptions.

Only published, currently effective items are public. Admins manage drafts and localizations; users can access only their own interactions, preferences, notifications and subscriptions. Publishing creates in-app notifications only for users who opted into feed updates. No external email or push is sent without an enabled preference and a future provider configuration.

The Flutter `/feed` experience reads live Supabase content, supports Persian RTL and English LTR, exposes bookmark/read actions, and is linked from the dashboard. Empty/error/loading states are honest.

The web manifest and HTML metadata now identify RAD Emigrate, use the RAD palette, support installable standalone display and maskable icons, and carry Persian RTL defaults while the in-app feed can switch language.

## Production verification

- Merged SHA: `73de807bb7ad26fc354c1e70325f5572555e931e`; final CI passed format, analyze, tests, web, Android, clean schema, Auth/RLS/Storage and credential scan.
- Live migration applied; all 7 new tables have RLS and the publication trigger is active.
- Published items: 0. The product shows a truthful empty state until an administrator reviews and publishes sourced content.
