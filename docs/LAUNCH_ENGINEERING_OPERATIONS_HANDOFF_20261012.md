# Launch engineering / operations handoff — 2026-10-12

This handoff incorporates all five files in
`outputs/launch_operations_20261012/`. It does not authorize public-site
changes, production form submissions, deployment, or Feed publication.

## Radmohajer consultation-form finding

The public page is owned by an external Joomla/RSForm Pro implementation, not
this Flutter/Supabase repository. Evidence in the live HTML includes
`/media/com_rsform/`, `RSFormPro`, form id 4, and template
`tgl_radmohajer`; no matching implementation exists under `lib/`, `supabase/`,
`test/`, `tools/`, or `docs/`.

Read-only reproduction:

1. GET `https://radmohajer.ir/fa/درخواست-مشاوره-رایگان` without entering data.
2. Inspect the returned HTML. Fields contain messages such as `Invalid Input`,
   `نا معتبر`, and `معتبر نیست` inside spans with class `formNoError`.
3. GET `/media/com_rsform/css/front.css?...`; the live rule is
   `.formNoError { display:none; }`.
4. A text-only page extractor reproduces the strings because it ignores CSS.
   The initial visual error state itself was **not reproduced**. No form was
   submitted, so post-interaction and success behavior remain **NOT TESTED**.

Therefore L04 is not a confirmed Flutter defect. The responsible system is the
Radmohajer Joomla/RSForm Pro site. Its owner should run the controlled staging
test from the Manus acceptance report and also confirm that hidden validation
copy is excluded from the accessibility tree.

## Fourteen-item handoff

| ID | Owner | Current disposition | Acceptance needed |
|---|---|---|---|
| L01 P0 | Operations | **OPEN** — no shared owner/SLA evidenced | Sample leads all have Lead ID, owner, next action, due date, status, and callback SLA |
| L02 P0 | Operations + Management | **OPEN** — approved sensitive-document channel not evidenced | Publish approved channel policy; prohibit passwords, OTPs, bank credentials, and unnecessary originals |
| L03 P0 | Content + legal reviewer | **OPEN** — public-currentness control not evidenced | Every regulated article has reviewer, review date, official source, and `REVIEW_REQUIRED` where unresolved |
| L04 P0 | External web Engineering | **NOT CONFIRMED** — hidden RSForm copy is extractable; visible untouched error not reproduced; outside this repo | Staging visual/accessibility test shows no initial errors and specific interaction errors; clear success/failure result |
| L05 P1 | Operations + Content | **OPEN** — footer contacts exist; form-area failure fallback not confirmed | Place monitored phone/Telegram fallback and reconciliation reference beside the form |
| L06 P1 | External web Engineering | **NOT TESTED** — no authorized submission | Staging-only valid/invalid/duplicate/success/notification test with no secret leakage |
| L07 P1 | Operations + Management | **OPEN** — overlapping contact routes | Approved routing matrix with monitored owner and SLA for every channel |
| L08 P1 | Content + Operations | **OPEN** — broad service taxonomy | Plain-language route chooser and route-specific questions with no outcome promises |
| L09 P1 | Operations | **KIT PROVIDED / ADOPTION UNVERIFIED** | Staff use versioned Persian follow-up and missing-document templates |
| L10 P1 | Operations manager | **OPEN** — escalation process not evidenced | Internal matrix and incident log; same-day P0 privacy/complaint/deadline handling |
| L11 P2 | Engineering + QA | **NOT TESTED** — preserve Manus status | Authorized RTL mobile-width/device test has no clipped labels or unusable controls |
| L12 P2 | QA | **NOT TESTED** — Radvisa and Digivisa interactive journeys remain unverified | Read-only CTA/contact/error/broken-link coverage in a stable test environment |
| L13 P2 | Operations | **OPEN** — post-consultation responsibility model not evidenced | Every active case has owner, specialist, document controller, next action, and backup |
| L14 P2 | Management | **OPEN** — no signed go/no-go package | Explicitly sign P0/P1 controls and defer every unverified content/hosted change |

Registration/login, Radvisa and Digivisa interactive journeys, mobile flows,
actual form submissions, success acknowledgement, and broken-link coverage
remain **NOT TESTED**. No pass or failure is inferred for them.

## Remaining launch blockers

Unrestricted real-user intake remains **NO-GO** on L01–L03 plus the controlled
external-site verification in L04. L05 and L10 are also practical safeguards
for a supervised pilot. Management must own the launch decision; the repository
work does not close staffing, privacy-channel, content/legal-review, or public
website gates.

## Stage 3 ingestion readiness (separate decision)

Stage 3 tooling and disposable-database validation are engineering-ready, but
production ingestion remains **NO-GO**. Separate blockers remain: production
migration drift, live/package inventory drift, backup/rollback attestation,
human editorial decisions, and an authorized execution window. None of the
operations-board items authorizes ingestion, and no ingestion or Feed
publication was performed.
