# Visa evidence and safe initialization procedure

Audit date: 2026-10-07. This is an editorial initialization package, not published immigration advice. The live catalogue has ten programme summaries. Canada study has four requirements and five steps per language; Germany work has four steps per language. Eight programmes lack requirements and steps. All twenty localized descriptions and forty-four destination summaries are blank. Empty structured sections must continue to say they are pending review.

The existing “investment Canada” label is too broad to determine a legal route. IRCC says the Start-Up Visa Program was paused on June 30, 2026. Do not interpret this label as an available Start-Up Visa offer. Other provincial/business routes require their own exact programme scope and evidence. No replacement eligibility, financial threshold, processing time or guarantee is supplied here.

## Evidence map

| Existing slug | Primary authority | Editorial decision before initialization |
|---|---|---|
| study-canada | [IRCC document guide](https://www.canada.ca/en/immigration-refugees-citizenship/services/study-canada/study-permit/get-documents.html) and [PAL/TAL exceptions](https://www.canada.ca/en/immigration-refugees-citizenship/services/study-canada/study-permit/get-documents/provincial-attestation-letter.html) | Preserve exemptions, Quebec distinctions and local-office instructions; do not make conditional documents universally mandatory. |
| work-germany | [Federal qualified-professional route](https://www.make-it-in-germany.com/en/visa-residence/types/work-qualified-professionals) | Select the exact residence route before writing a checklist; distinguish regulated-profession recognition. |
| investment-canada | [IRCC Start-Up Visa status](https://www.canada.ca/en/immigration-refugees-citizenship/services/immigrate-canada/start-visa/about.html) | Route identity unresolved; pause review of any Start-Up Visa availability claim. |
| study-australia | [Home Affairs subclass 500](https://immi.homeaffairs.gov.au/visas/getting-a-visa/visa-listing/student-500) and [official checklist tool](https://immi.homeaffairs.gov.au/visas/web-evidentiary-tool) | Use applicant/provider-specific checklist; review current in-country eligibility and family rules. |
| study-united-kingdom | [GOV.UK Student documents](https://www.gov.uk/student-visa/documents-you-must-provide) | Distinguish passport/CAS from conditional financial, ATAS, age and TB evidence. |
| medical-study-germany | [DAAD programme search](https://www.study-in-germany.com/en/plan-your-studies/study-options/programme/) | Select degree, language and institution; obtain admissions evidence from that institution. A general country page is insufficient. |
| medical-work-united-kingdom | [GMC international graduate registration](https://www.gmc-uk.org/registration-and-licensing/join-our-registers/registration-applications/application-guides/full-registration-for-international-medical-graduates) | Separate professional registration from immigration permission; choose registration route and relevant UK visa source. |
| credential-recognition-germany | [German government Recognition Finder](https://www.anerkennung-in-deutschland.de/en/interest/finder/result?arrangement=Nein&location=2051&nationality=Drittstaat&profession=412&qualification=null&success=Ja&whereabouts=Ausland&zipSearch=0) | This retrieved example is location-specific; select intended profession and competent state authority before using its checklist. |
| medical-work-sweden | [Socialstyrelsen doctor licensing outside EU/EEA](https://legitimation.socialstyrelsen.se/en/licence-application/outside-eu-eea/doctor-of-medicine-educated-outside-eu-eea/) | Choose licensing route; add separate Migration Agency evidence for residence/work permission. |
| tourist-canada | [IRCC visitor eligibility](https://www.canada.ca/en/immigration-refugees-citizenship/services/visit-canada/eligibility.html) and [application documents](https://www.canada.ca/en/immigration-refugees-citizenship/services/visit-canada/apply-visitor-visa.html) | Select travel purpose and applicant situation; no universal fee/timeline promise. |

RAD first-party service context remains separate from government eligibility: [radvisa.com](https://radvisa.com/), [digivisa.ir](https://digivisa.ir/), [radmohajer.ir/fa](https://radmohajer.ir/fa/). A RAD service description does not establish statutory visa requirements.

## Exact safe procedure

1. Inventory the existing programme by slug; retain its UUID, source, revision and localized text. Do not overwrite existing reviewed work with generic templates.
2. An Admin adds the selected authority URL through Add Source. The source starts disabled with external/admin-only trust. A Super Admin classifies its authority/trust/scope using existing source configuration. No trust is inferred from a display name.
3. Enable that source and run Research. Inspect source status, final URL, fetch time, preserved source snapshot and the real excerpt. A failed fetch is a failed fetch, not evidence. Reviewable evidence creates a draft, never Feed.
4. For each proposed requirement or step, record exact source URL, retrieved date, supporting excerpt, applicable route/applicant conditions, `locale`, `display_order` and whether it is mandatory. Translate Persian faithfully while preserving conditional language. Keep unknown fees and processing times null.
5. Use the existing authenticated Admin editorial permissions on `content_sources`, `visa_program_localizations`, `visa_program_requirements` and `visa_program_steps`; work in a draft/review programme revision. Each requirement/step must retain its `source_id`. Use UUIDs resolved from the selected slug/source, not fabricated IDs. The relevant schemas and RLS are defined in `20261003210302_project09_visa_catalog.sql`.
6. Before any publication, a human Admin compares both translations with each captured authority source, verifies the exact route and exceptions, and records `reviewed_by` and `effective_date` on the programme. Explicitly publish only the reviewed revision. Do not run a bulk SQL script that changes every programme to published.
7. Reload Visa and detail in English and Persian. Confirm ordering, mandatory/conditional labels, source attribution and pending states. Recheck official availability before publishing time-sensitive information.

No production content rows were inserted merely to fill empty screens. This package deliberately leaves route-specific editorial choices unresolved where the source evidence is insufficient.
