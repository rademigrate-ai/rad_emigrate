# Visa Domain Architecture

## Tables
- `destinations` (code, slug, status, display_order)
- `destination_localizations` (locale, name, summary)
- `visa_programs` (slug, destination_id, category_id, primary_source_id, status, processing_time_text, fees_text)
- `visa_program_localizations` (locale, title, summary, description)
- `visa_program_requirements` (program_id, locale, requirement, is_mandatory, display_order, source_id)
- `visa_program_steps` (program_id, locale, title, description, display_order, source_id)
- `program_categories` + localizations
- `content_sources` (RAD URLs used as primary_source_id)

## Flutter contract
- `VisaRepository.loadCatalog(locale)` → countries, categories, programs with nested requirements/steps filtered by locale
- Missing localization → FormatException (not silent empty)
- UI: `EmptyState` when requirements and steps both empty (`structuredDetailsPending`)

## Public read
- anon/authenticated SELECT on published rows via RLS
- Admin/super_admin mutation via `private.has_role`

## Authority model
- Catalog identity + RAD service framing: RAD sources
- Regulatory eligibility/fees/times: official authorities only; catalog text must caveat
