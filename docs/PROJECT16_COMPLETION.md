# Project 16 — Final Release QA (Engineering)

Project 16 is the web engineering acceptance gate. Production hosting, domain/DNS, Auth redirect URLs for the owner-selected host, Android/iOS signing, paid provider keys, Super Admin bootstrap, and final legal text remain **external owner actions**.

## Work completed in this gate

| Item | Action |
|------|--------|
| Acceptance PR #12 | Squash-merged to main (auth roles, AI safety, documents, PWA assets) |
| `/admin` deep-link | Added to `_protectedRoutes` for session restore only; data access remains RLS/role |
| PWA branding | `web/manifest.json` name → **RAD International Institute** |
| Schema acceptance tests | Research publish gates, feed visibility, AI Vault secret isolation |
| Pending gates | Replaced obsolete PENDING markers with EXTERNAL/DEFERRED where accurate |

## Engineering acceptance matrix

| Area | Status | Evidence |
|------|--------|----------|
| Auth / session / profile | Complete | CI isolation + acceptance tests |
| Applications / documents / Storage | Complete | RLS + Storage policies + acceptance |
| Admin / Super Admin roles | Complete | Server role RPC; client reflects only |
| Knowledge / research review | Complete | Schema: draft→approved public read only |
| AI orchestration / Vault / fallback | Complete | `secret_id` + service_role runtime chain |
| Document intelligence | Complete | No OCR provider required for gate |
| Feed + notifications + PWA | Complete | Published-only public read; branded manifest |
| Observability / retention | Complete | Project 15 tables + cron |
| Acceptance suite | Complete | PR #12 + Project 16 schema tests |
| Clean schema / credential scan | CI on PR/main | |
| Super Admin accounts | External | No elevation without verified Auth users |
| Production deploy / DNS / signing | External | Not performed |

## Explicit non-goals

- Do not deploy the production web host.
- Do not configure final Auth redirect URLs until domain is chosen.
- Do not purchase or embed AI/OCR/search API keys.
- Do not elevate Super Admin without verified Auth accounts.
- Do not invent legal Terms/Privacy body text.

## Intended role identities (external bootstrap)

| Role | Email (owner-supplied) |
|------|------------------------|
| Super Admin | mehrshad.evol.b@gmail.com |
| Admin | B.rad14@yahoo.com |

Elevation must use server-side role RPC after Auth user verification — never client email allowlists alone.
