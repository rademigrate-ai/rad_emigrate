# Render staging — Supabase Flutter Web

## How configuration is injected

Flutter reads **compile-time** defines only (see `lib/core/supabase/supabase_config.dart`):

| Dart define | Source | Purpose |
|-------------|--------|--------|
| `SUPABASE_URL` | `String.fromEnvironment('SUPABASE_URL')` | Project API URL |
| `SUPABASE_PUBLISHABLE_KEY` | `String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY')` with fallback to `SUPABASE_ANON_KEY` | Browser publishable / legacy anon key |

If either value is empty, the app sets `supabase_not_configured` and login fails intentionally.

**Never** pass `service_role`, Vault secrets, or AI provider keys into the web build.

## Exact Render settings

| Setting | Value |
|---------|--------|
| **Service type** | Static Site |
| **Build Command** | `bash scripts/build_web_render.sh` |
| **Publish Directory** | `build/web` |
| **Rewrite rule** | Source `/*` → Destination `/index.html` (Rewrite) |

### Environment variables (Build)

| Name | Maps to | Type | Notes |
|------|---------|------|--------|
| `SUPABASE_URL` | Supabase Project URL | Normal | e.g. `https://inshddthftkhcdosoqcn.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | Publishable key **or** legacy anon key | Normal | Public by design; RLS is the security boundary |
| `APP_ENV` | Optional `APP_ENV` define | Normal | Use `staging` |

Optional legacy alias: `SUPABASE_ANON_KEY` (used only if `SUPABASE_PUBLISHABLE_KEY` is unset).

### Values for project `inshddthftkhcdosoqcn`

- **SUPABASE_URL:** `https://inshddthftkhcdosoqcn.supabase.co`
- **SUPABASE_PUBLISHABLE_KEY:** Dashboard → Project Settings → API → **Publishable** key (preferred) or **anon** **public** key

Do not use the **service_role** key.

## Supabase Auth URLs (Dashboard)

Authentication → URL Configuration:

- **Site URL:** `https://rad-emigrate.onrender.com` (or keep production and add redirect)
- **Redirect URLs:** include `https://rad-emigrate.onrender.com/**` and `https://rad-emigrate.onrender.com`

## Local parity

```bash
export SUPABASE_URL=https://inshddthftkhcdosoqcn.supabase.co
export SUPABASE_PUBLISHABLE_KEY='<publishable-or-anon-public-key>'
export APP_ENV=staging
bash scripts/build_web_render.sh
```

## After deploy checklist

1. App loads without `supabase_not_configured`
2. Email + password login reaches Supabase Auth
3. Session restore after refresh
4. `/dashboard` after login
5. `/admin` for `super_admin` profiles
6. Direct refresh on `/admin` does not 404 (SPA rewrite)
7. Logout clears session
