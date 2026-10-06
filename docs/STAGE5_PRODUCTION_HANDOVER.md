# Stage 5 production handover

This document is the owner-run activation package for the Stage 5 release
candidate. Engineering prepares and verifies the release; it does not merge the
pull request, mutate production, or deploy Render from this task.

## Architecture and trust boundaries

- Flutter Web/Android uses only the Supabase project URL and a public
  publishable (or legacy anon) key. RLS is the client-data security boundary.
- Supabase Auth owns sessions. Database RLS owns user, Admin, and Super Admin
  authorization. Role changes and privileged operations are server-audited.
- Edge Functions hold service-role access. AI provider credentials are
  write-only from Admin and stored in Supabase Vault; they are never returned to
  Flutter or placed in Render.
- RAD research sources are untrusted input even when first-party. A changed
  source creates `research_findings` and a `content_drafts.status = 'review'`
  candidate. Only the separately Admin-gated `publish_content_draft` RPC can
  create/update a published Feed item. Research and AI never auto-publish.

## Production configuration matrix

| Value | Location | Classification | Required action |
|---|---|---|---|
| `SUPABASE_URL` | Render build / mobile `--dart-define` | Repository-safe public project URL | Set for the production project |
| `SUPABASE_PUBLISHABLE_KEY` | Render build / mobile `--dart-define` | Public client key | Set an enabled publishable key; never use service role |
| `APP_ENV=production` | Render build / mobile `--dart-define` | Repository-safe | Blueprint and build script default to production |
| Provider base URL | Admin → AI configuration | Repository-safe metadata | For OpenRouter use `https://openrouter.ai/api/v1` |
| Provider API key | Admin → AI configuration → Vault | Secret | Enter once through the write-only field |
| Supabase service-role key | Supabase-managed Edge Function environment | Secret | Never expose to Render or Flutter |
| Research worker token | Supabase Edge Function secret | Secret | Keep server-side; rotate if exposure is suspected |
| Auth Site URL / redirects | Supabase Auth dashboard | Owner configuration | Set to the final HTTPS host and permitted callbacks |
| `RAD_ANDROID_APPLICATION_ID` | Android release environment | Owner configuration | Choose the permanent ID before the first release |
| Android signing values | Android release environment/secret store | Secret | Configure the four `RAD_RELEASE_*` values; never commit them |

## Release order

Use the final green commit from PR #23. Do not deploy a mixture of files from
different commits.

1. Review and merge PR #23 only when the owner authorizes it.
2. Back up production and record the currently deployed Render commit and Edge
   Function versions.
3. Apply repository migrations in order with the Supabase CLI. Do not repair,
   rename, or edit production migration history. The pending Visa migration is
   `20261005130000_stage2_visa_structured_steps.sql`; the Stage 5 review-candidate
   repair is `20261006132931_stage5_research_review_candidate_backfill.sql`.
4. Deploy the exact release-candidate sources for `research-sync`,
   `ai-orchestrator`, and `document-intelligence`. Production currently has older
   function bundles; database migration alone does not fix future research runs.
5. Run the read-only verification queries below.
6. Configure Auth URLs, leaked-password protection, AI provider/model scopes,
   and any owner-approved branding/signing values.
7. Create/update the Render Static Site from `render.yaml`, then execute the
   smoke test.

Example owner commands from a clean checkout at the final SHA:

```bash
supabase link --project-ref inshddthftkhcdosoqcn
supabase db push --dry-run
supabase db push
supabase functions deploy research-sync
supabase functions deploy ai-orchestrator
supabase functions deploy document-intelligence
```

Confirm the linked project before every command. Do not use `db reset` against
production.

## Research repair verification

The Stage 5 migration safely creates review candidates for existing orphan
findings and serializes repeated candidate creation per finding. It never calls
the publish RPC and never writes `feed_items`.

```sql
select
  count(*) as findings,
  count(cd.id) as review_candidates,
  count(*) filter (where cd.status = 'published') as published_candidates
from public.research_findings rf
left join public.content_drafts cd on cd.research_finding_id = rf.id;

select count(*) as feed_items from public.feed_items;
```

Expected immediately after migration: every existing finding has at least one
candidate, all newly backfilled candidates are `review`, and the Feed count is
unchanged. After one controlled research run, a newly changed snapshot must
produce both a finding and one review candidate; it must not produce a Feed item.

## Visa initialization package

Production was audited with 22 destinations, 10 published programmes, 0 steps,
44 blank destination summaries, 20 blank programme descriptions, and eight
requirements belonging to `study-canada`.

The pending migration intentionally initializes only evidence-backed structured
steps for:

| Programme | Locales | Steps per locale | Primary RAD evidence |
|---|---:|---:|---|
| `study-canada` | `fa`, `en` | 5 | DigiVisa study-in-Canada source already registered in `content_sources` |
| `work-germany` | `fa`, `en` | 4 | DigiVisa work-in-Germany source already registered in `content_sources` |

It does **not** invent generic requirements for the other eight programmes.
Their existing sourced summaries remain visible, while the UI explicitly says
that verified structured details are awaiting review. Destination summaries and
programme descriptions are optional fields and are not treated as verified
content merely to make non-null counts look complete.

Verify after migration:

```sql
select p.slug,
       count(distinct s.id) as steps,
       count(distinct r.id) as requirements
from public.visa_programs p
left join public.visa_program_steps s on s.program_id = p.id
left join public.visa_program_requirements r on r.program_id = p.id
group by p.id, p.slug
order by p.slug;
```

Additional Visa content must use a current RAD primary source plus the relevant
destination authority, retain a source ID per row, be reviewed bilingually, and
be delivered in a new additive migration. Do not convert unsourced prose into
mandatory requirements, fees, processing times, or eligibility guarantees.

## Render and web

- Service type: Static Site
- Build command: `bash scripts/build_web_render.sh`
- Publish directory: `build/web`
- Rewrite: `/*` → `/index.html`
- Required build values: `APP_ENV=production`, `SUPABASE_URL`, and
  `SUPABASE_PUBLISHABLE_KEY`
- Keep provider keys and service-role keys out of Render.

The web entry point and manifest already contain RAD bilingual/RTL branding,
titles, descriptions, favicons, and install icons. Social URLs remain relative
until the owner chooses a canonical production domain; set domain-specific
canonical/OG URLs only after that decision.

## Android release

`com.example.rad_emigrate` is a development placeholder. No owner-approved
production application ID exists in repository or project configuration, so the
release build now refuses to package with it. The owner must choose the
permanent ID and export `RAD_ANDROID_APPLICATION_ID`. Once an app is published,
changing this ID creates a different application and is not an ordinary rename.

Configure these secrets outside git:

```text
RAD_ANDROID_APPLICATION_ID
RAD_RELEASE_STORE_FILE
RAD_RELEASE_STORE_PASSWORD
RAD_RELEASE_KEY_ALIAS
RAD_RELEASE_KEY_PASSWORD
```

Then build with production Supabase defines and verify the signed artifact,
version code/name, launcher icons, and Play/App Distribution identity before
upload. No keystore or signing password belongs in this repository.

## AI activation

Production had zero providers and zero models at audit time. In a Super Admin
session: Admin → AI configuration → configure provider → enter write-only key →
Save → Test provider → Discover models → enable the approved model → select
USER, ADMIN, or BOTH scope → set priority. Confirm both a grounded User AI answer
and the broader Admin research answer. Until activation, the app displays a
localized safe-unavailable response and infers no immigration requirements.

## Auth, secrets, and known limitations

- Set the final HTTPS Site URL and exact login/recovery redirects in Supabase
  Auth. Test direct callback refreshes.
- Enable leaked-password protection in Supabase Dashboard → Authentication →
  password/security settings. It was disabled at audit time.
- Verify the canonical transparent RAD logo binaries visually/against the
  owner-provided originals before release; repository references and PWA/Android
  icon wiring are present, but byte identity is not asserted here.
- The `pg_net` extension remains in `public` because it is non-relocatable in
  this project. Treat the advisor warning as accepted P2 and keep its grants
  restricted.
- Wildcard Edge CORS is intentional for browser/mobile bearer-token calls with
  no credentialed cookies. Allowed headers include `authorization`,
  `x-client-info`, `apikey`, and `content-type`; the research function also
  permits its worker-token header.

## Rollback

1. Render: redeploy the recorded previous known-good commit.
2. Edge Functions: redeploy the recorded previous function bundle if a function
   regression is isolated.
3. Database: do not reset or delete production data. These migrations are
   additive; prefer a forward corrective migration. Backfilled review drafts are
   safe to leave pending and must not be mass-published.
4. Auth: restore the previous Site URL/redirect set only if callbacks fail, then
   retest recovery and login.
5. Secrets: rotate the affected provider/worker credential, update Vault or the
   Edge Function secret, test it, and revoke the old value.

## Exact remaining owner actions

1. Approve/merge the final green PR, back up production, then apply migrations
   and deploy all three Edge Functions from that one SHA.
2. Set final Auth Site/redirect/recovery URLs and enable leaked-password
   protection.
3. Add the provider key through Admin/Vault; Test, Discover, enable models,
   scopes, and priorities.
4. Choose `RAD_ANDROID_APPLICATION_ID`, configure release signing, and verify
   canonical logo/icon binaries.
5. Set Render production build values, deploy the Static Site, and run the smoke
   test below.

## Post-deploy smoke test

1. Load `/`: branded shell renders with no console error or asset 404.
2. Log in: valid user reaches the protected dashboard; invalid credentials are
   localized and reveal no account details.
3. Switch Persian/English: navigation, empty/error/configuration states, and
   content use the selected language; Persian is RTL.
4. Switch Light/Dark and test desktop/mobile widths: no clipping, inaccessible
   controls, or broken navigation.
5. Visa: all published summaries and sources render; Canada/Germany show ordered
   sourced steps; thin programmes show the localized pending-review state.
6. Feed: an empty Feed says no reviewed updates; it never exposes review drafts.
7. User AI: a configured model returns a grounded answer with sources; an
   unavailable provider returns the localized safe state.
8. Applications and Documents: create/read/update flows remain owner-scoped;
   upload accepts only allowed types/sizes and another user cannot read them.
9. Admin login: Admin operations load with bounded lists; ordinary users are
   denied. Super Admin-only role/config/audit controls remain denied to Admin.
10. Admin AI: provider Test and model discovery return sanitized outcomes; no key
    is readable in UI, network responses, or logs.
11. Research: queue one run; a changed source creates a finding and exactly one
    review draft. Review, edit, approve/keep/reject all work without Feed change.
12. Explicit publish: only the Admin publish action creates/updates the Feed
    item; repeat is idempotent.
13. Refresh direct protected routes and Auth/recovery callbacks: SPA rewrite and
    session restore work without 404 or redirect loops.
14. Inspect browser console/network, then logout/login: no mixed content, secret,
    unexpected 4xx/5xx flood, or stale session remains.

