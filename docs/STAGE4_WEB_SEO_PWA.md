# Stage 4 — Web SEO / PWA / SPA notes (Flutter)

## Honest SEO limitation

This application is a **Flutter Web SPA**. It does **not** provide full per-route server-side rendered (SSR) or static-site generated (SSG) HTML with unique crawlable metadata for every in-app route.

Search engines and social crawlers primarily see the content of `web/index.html` plus whatever the client hydrates after JavaScript runs. Deep links such as `/visa` or `/feed` share the same shell document metadata unless a separate SSR layer is introduced later.

Do **not** claim SSR/SSG behaviour for this build.

## What is configured (code-controlled)

| Item | Status |
|------|--------|
| `web/index.html` charset, viewport, theme-color | Present |
| Default `lang` / `dir` (fa / rtl) | Present |
| Title + description | RAD Emigrate branding |
| Open Graph + Twitter card tags | Present (relative icon image) |
| robots index,follow | Present |
| noscript fallback | Present |
| `web/manifest.json` name/short_name/icons/maskable | Present |
| Favicon + apple-touch-icon paths | Wired to `favicon.png` / `icons/*` |
| SPA rewrite for static hosts | `web/_redirects` → `/* /index.html 200` |

## Render / static hosting

For Render static sites (or similar), the repository includes:

```
/*    /index.html   200
```

in `web/_redirects` so direct route opens and refreshes do not 404.

Confirm the deploy step copies `web/_redirects` into the published web root (Flutter `build/web`). Owner deployment (Stage 5) must verify this on the live host.

## Owner follow-ups (not code blockers)

1. Replace web/PWA icon binaries with exact official RAD brand assets if current placeholders are not the final art.
2. Optionally add a production absolute `og:url` / canonical once the production domain is fixed in deployment config.
3. Enable Supabase leaked-password protection in the dashboard if still off.
4. Enter the real OpenRouter (or approved) provider API key via Admin AI config (Vault-backed).

## PWA

Manifest identity is RAD (not default Flutter). Display is `standalone`. Icons include maskable variants. Service worker behaviour follows Flutter’s default web bootstrap; no custom offline shell was added in Stage 4.
