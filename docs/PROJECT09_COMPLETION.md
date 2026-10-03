# Project 09 — Visa / Product Data Layer

## Scope

Project 09 replaces the in-app static catalogue with a Supabase-backed, bilingual, source-traceable catalogue. Public queries can see only `published` content; `draft`, `review`, and `archived` records require an Admin or Super Admin role.

## Architecture

- Normalized destinations, categories, programmes, localizations, requirements, steps, and sources.
- `VisaRepository` is the only runtime catalogue source.
- Search and destination/category filters operate on repository-backed data.
- Every seeded programme links to a RAD-owned source URL and retrieval timestamp.
- No unsourced fee or processing-time claim is seeded.

## Migration

`20261003195210_project09_visa_catalog.sql` adds the catalogue, trusted server-side role resolution, content audit logs, RLS, grants, indexes, and an initial source-backed RAD dataset.

## Security

- `profiles.role` is excluded from user-updatable profile columns.
- Draft content is protected by RLS.
- Content writes require trusted `admin` or `super_admin` roles.
- Audit logs cannot be inserted or changed by client roles and are readable only by Super Admin.

## Source review

The initial dataset is deliberately conservative. It records service availability found on `radvisa.com`, `digivisa.ir`, and `radmohajer.ir/fa/`. Regulatory details remain empty unless explicitly supported. Content that may have changed is labeled for official-source verification rather than presented as current law.

## Tests and gates

- Added provenance model coverage.
- SQL structural checks cover RLS, policies, indexes, and privilege boundaries.
- Flutter/Dart executables are unavailable in the local workspace; CI is the executable Flutter gate.

## External actions

None for the Project 09 architecture. The two intended Super Admin identities require account existence before secure role assignment.

## Release

Final SHA, CI result, and tag are recorded in `MASTER_COMPLETION_STATUS.md` after merge.
