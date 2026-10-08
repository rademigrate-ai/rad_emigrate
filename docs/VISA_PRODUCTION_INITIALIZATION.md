# Visa Production Initialization

## Method
1. Additive migration `20261007220000_stage5_visa_editorial_summaries.sql`
2. Updates only empty summaries/descriptions (idempotent)
3. No destructive deletes; no status flips; no Feed writes

## Re-run
Re-applying the migration SQL does not duplicate rows and does not overwrite non-empty editorial text.

## Manual editorial path
Admin/super_admin may update localizations via existing RLS policies without schema changes.
