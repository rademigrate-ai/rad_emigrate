# Stage 5 production handover

> 2026-10-13 closure update: production remains NO-GO. Current evidence is in
> `artifacts/engineering_closure_20261013/ACCEPTANCE.md`. Historical inventory
> paragraphs below are not a current production attestation. The exact-five
> security deployment/recovery instructions below supersede the former generic
> whole-directory CLI push procedure.

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

Use one owner-approved SHA on `handoff/codex-stage1-stage2-20261010` with all
seven CI jobs green. This engineering task does not authorize a merge or deploy.

1. Obtain owner/DBA approval, verify a real restorable recovery point in an
   isolated target, and record the current Web/Edge versions. The Free-plan
   entitlement gap is established; synthetic logical restore tests are not PITR
   evidence. Use `scripts/recovery/README.md` only after actual DBA sign-off and
   the explicit production export, Storage-copy and retention authorizations.
2. Recheck the live 47-entry ledger (last `20261007212140`), catalog, grants,
   constraints and invalid-row preflights against the approved rehearsal.
   Stop on drift, failed backup integrity, missing sign-off or mismatched hashes.
3. Apply ONLY the five reviewed security files, each transactionally with its
   correct ledger entry, preserving all historical versions/aliases. Follow
   `RAD_PROD_EQUIV_REHEARSAL_REPORT_20261013.md`,
   `RAD_PRODUCTION_READONLY_PREFLIGHT_20261013.md` and
   `RAD_DEPLOYMENT_MANIFEST_20261012.md` in the final RC artifacts. Order:
   `20261010010000`, `20261010055013`, `20261010070000`,
   `20261012110945`, `20261012230000`. Do not use whole-directory `db push`.
   Knowledge aliases and Visa editorial SQL are outside this security scope.
4. Deploy the exact release-candidate sources for `research-sync`,
   `ai-orchestrator`, and `document-intelligence`. Production currently has older
   function bundles; database migration alone does not fix future research runs.
5. Run the read-only verification queries below.
6. Under separate authorization, configure Auth URLs and enable leaked-password
   protection after compatibility assessment. Newly discovered models MUST remain
   disabled pending administrator approval. The live catalogue function still
   auto-enables new chat models in the 47+5 rehearsal: the five security files do
   not resolve that divergence. Require a DBA-reviewed forward alignment and
   a disabled-by-default discovery test before activating discovery/inference.
   Do not invent provider credentials, application identity or signing values.
7. Create/update the Render Static Site from `render.yaml`, then execute the
   smoke test.

Edge commands below require separate deployment authorization, from a clean
checkout at the approved SHA, only after successful DB postflight:

```bash
supabase link --project-ref inshddthftkhcdosoqcn
supabase functions deploy research-sync
supabase functions deploy ai-orchestrator
supabase functions deploy document-intelligence
```

Confirm the linked project before every command. Do not use `db reset`,
`migration repair`, or generic `db push` against production. Nothing above is
an instruction for an agent to execute without the separate approvals.

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

The older zero-provider inventory is superseded by the read-only preflight
(three providers and 682 models); counts do not establish usable credentials or
an approved inference canary. In an authorized Super Admin
session: Admin → AI configuration → configure provider → enter write-only key →
Save → Test provider → Discover models → enable the approved model → select
USER, ADMIN, or BOTH scope → set priority. Confirm both a grounded User AI answer
and the broader Admin research answer. Until activation, the app displays a
localized safe-unavailable response and infers no immigration requirements.

## Auth, secrets, and known limitations

- Set the final HTTPS Site URL and exact login/recovery redirects in Supabase
  Auth. Test direct callback refreshes.
- Owner decision: enable leaked-password protection after compatibility
  assessment, under separate Auth authorization. It remains disabled in the
  recorded production evidence; no setting was changed by this task.
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
3. Database: stop writes and escalation on any failed postflight. Prefer an
   approved forward correction; never restore vulnerable grants/approval paths
   just to roll back application code. A point restore loses later writes and
   does not restore Storage bytes. Use a separately authorized, fenced target,
   neutralize target default privileges before object creation, retain explicit
   archive ACLs, and require exact effective-privilege parity before exposure.
   The earlier naive restore had 86 excess ACL grants. Never waive that diff or
   use `--no-acl` as an unverified shortcut. Reconcile Storage bytes separately.
4. Auth: restore the previous Site URL/redirect set only if callbacks fail, then
   retest recovery and login.
5. Secrets: rotate the affected provider/worker credential, update Vault or the
   Edge Function secret, test it, and revoke the old value.

## Exact remaining owner actions

1. Authorize/review independent recovery, encrypted off-machine custody and
   isolated real-point restore with DBA sign-off. Then separately approve the
   exact-five-file apply and three Edge deployments from one green SHA. No merge
   is authorized by this document.
2. Set final Auth Site/redirect/recovery URLs and approve enabling leaked-password
   protection after compatibility testing; approve the discovery function alignment.
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

