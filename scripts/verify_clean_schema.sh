#!/usr/bin/env bash
set -euo pipefail

DB_URL="${SUPABASE_DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

AUTO_STARTED=0
MIGRATION_BACKUP=""
restore_migrations() {
  if [[ -n "$MIGRATION_BACKUP" && -d "$MIGRATION_BACKUP" ]]; then
    rm -rf supabase/migrations
    mv "$MIGRATION_BACKUP" supabase/migrations
    rmdir "$(dirname "$MIGRATION_BACKUP")"
    MIGRATION_BACKUP=""
  fi
}
cleanup() {
  restore_migrations
  if [[ "$AUTO_STARTED" == "1" && "${KEEP_SUPABASE_RUNNING:-0}" != "1" ]]; then
    supabase stop --no-backup >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [[ "${1:-}" != "--no-start" ]]; then
  MIGRATION_BACKUP="$(mktemp -d)/migrations"
  mv supabase/migrations "$MIGRATION_BACKUP"
  mkdir -p supabase/migrations
  AUTO_STARTED=1
  supabase start
  # `supabase start` replays a project's migrations. Restore them only after
  # the empty local Supabase stack is ready, then explicitly apply the guarded
  # bootstrap followed by each tracked SQL file.
  restore_migrations
fi

psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/bootstrap/clean_schema.sql
while IFS= read -r migration; do
  psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$migration"
done < <(find supabase/migrations -maxdepth 1 -type f -name '*.sql' -print | LC_ALL=C sort)

psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
DO $verify$
DECLARE
  table_count integer;
  column_count integer;
  primary_key_count integer;
  foreign_key_count integer;
  index_count integer;
  function_count integer;
  hardened_function_count integer;
  rls_count integer;
  app_policy_count integer;
  storage_policy_count integer;
  trigger_count integer;
  bucket_count integer;
BEGIN
  SELECT count(*) INTO table_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN (
      'profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages',
      'content_sources', 'destinations', 'destination_localizations',
      'program_categories', 'program_category_localizations', 'visa_programs',
      'visa_program_localizations', 'visa_program_requirements',
      'visa_program_steps', 'admin_audit_logs'
    );

  SELECT count(*) INTO column_count
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name IN (
      'profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages',
      'content_sources', 'destinations', 'destination_localizations',
      'program_categories', 'program_category_localizations', 'visa_programs',
      'visa_program_localizations', 'visa_program_requirements',
      'visa_program_steps', 'admin_audit_logs'
    );

  SELECT count(*) INTO primary_key_count
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  WHERE n.nspname = 'public'
    AND c.contype = 'p'
    AND t.relname IN (
      'profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages',
      'content_sources', 'destinations', 'destination_localizations',
      'program_categories', 'program_category_localizations', 'visa_programs',
      'visa_program_localizations', 'visa_program_requirements',
      'visa_program_steps', 'admin_audit_logs'
    );

  SELECT count(*) INTO foreign_key_count
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  WHERE n.nspname = 'public'
    AND c.contype = 'f'
    AND t.relname IN (
      'profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages',
      'content_sources', 'destinations', 'destination_localizations',
      'program_categories', 'program_category_localizations', 'visa_programs',
      'visa_program_localizations', 'visa_program_requirements',
      'visa_program_steps', 'admin_audit_logs'
    );

  SELECT count(*) INTO index_count
  FROM pg_indexes
  WHERE schemaname = 'public'
    AND tablename IN (
      'profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages',
      'content_sources', 'destinations', 'destination_localizations',
      'program_categories', 'program_category_localizations', 'visa_programs',
      'visa_program_localizations', 'visa_program_requirements',
      'visa_program_steps', 'admin_audit_logs'
    );

  SELECT count(*) INTO function_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE (n.nspname = 'public' AND p.proname = 'handle_new_user')
     OR (n.nspname = 'private' AND p.proname IN ('has_role', 'set_updated_at', 'audit_content_change'));

  SELECT count(*) INTO hardened_function_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE ((n.nspname = 'public' AND p.proname = 'handle_new_user')
      OR (n.nspname = 'private' AND p.proname = 'audit_content_change'))
    AND p.prosecdef
    AND p.proconfig @> ARRAY['search_path=""']::text[]
    AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
    AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE');

  SELECT count(*) INTO rls_count
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND c.relname IN (
      'profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages',
      'content_sources', 'destinations', 'destination_localizations',
      'program_categories', 'program_category_localizations', 'visa_programs',
      'visa_program_localizations', 'visa_program_requirements',
      'visa_program_steps', 'admin_audit_logs'
    )
    AND c.relrowsecurity;

  SELECT count(*) INTO app_policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN (
      'profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages',
      'content_sources', 'destinations', 'destination_localizations',
      'program_categories', 'program_category_localizations', 'visa_programs',
      'visa_program_localizations', 'visa_program_requirements',
      'visa_program_steps', 'admin_audit_logs'
    );

  SELECT count(*) INTO storage_policy_count
  FROM pg_policies
  WHERE schemaname = 'storage'
    AND tablename = 'objects'
    AND policyname LIKE 'documents storage %';

  SELECT count(*) INTO trigger_count
  FROM information_schema.triggers
  WHERE (event_object_schema = 'auth'
      AND event_object_table = 'users'
      AND trigger_name = 'on_auth_user_created')
     OR (event_object_schema = 'public'
      AND event_object_table IN ('content_sources', 'destinations', 'program_categories', 'visa_programs'));

  SELECT count(*) INTO bucket_count
  FROM storage.buckets
  WHERE id = 'documents'
    AND public = false
    AND file_size_limit = 10485760
    AND allowed_mime_types = ARRAY['application/pdf', 'image/jpeg', 'image/png']::text[];

  IF table_count <> 15 THEN RAISE EXCEPTION 'Expected 15 public RAD tables, got %', table_count; END IF;
  IF column_count <> 113 THEN RAISE EXCEPTION 'Expected 113 public RAD columns, got %', column_count; END IF;
  IF primary_key_count <> 15 THEN RAISE EXCEPTION 'Expected 15 primary keys, got %', primary_key_count; END IF;
  IF foreign_key_count <> 22 THEN RAISE EXCEPTION 'Expected 22 foreign keys, got %', foreign_key_count; END IF;
  IF index_count <> 37 THEN RAISE EXCEPTION 'Expected 37 public RAD indexes, got %', index_count; END IF;
  IF function_count <> 4 OR hardened_function_count <> 2 THEN RAISE EXCEPTION 'Expected four trusted functions and two hardened definers, got % function(s), % hardened', function_count, hardened_function_count; END IF;
  IF rls_count <> 15 THEN RAISE EXCEPTION 'Expected RLS on all 15 public RAD tables, got %', rls_count; END IF;
  IF app_policy_count <> 36 THEN RAISE EXCEPTION 'Expected 36 public policies, got %', app_policy_count; END IF;
  IF storage_policy_count <> 3 THEN RAISE EXCEPTION 'Expected 3 documents Storage policies, got %', storage_policy_count; END IF;
  IF trigger_count <> 17 THEN RAISE EXCEPTION 'Expected auth, update, and audit trigger events, got %', trigger_count; END IF;
  IF bucket_count <> 1 THEN RAISE EXCEPTION 'Expected private 10 MiB documents bucket with MIME allowlist, got %', bucket_count; END IF;
END
$verify$;
SQL

expected_fingerprint='{"rls":"f774d2521876438405d177897df727d3","bucket":"4082dda1bd1da983bda51a025c66ac93","columns":"4cb165bb35113539b9f0784afffcb2ea","indexes":"b1904e5964974b6a2a671adb37848570","policies":"b68066327e03a413999b751b68aa6e20","triggers":"710a7b535cb9f1c2bd959fe1b854ae88","functions":"e05d93ee347104597a7b8b458b0d03da","constraints":"dc92252b3c76792ba111f39572be43aa"}'
actual_fingerprint="$(psql "$DB_URL" -XAt -v ON_ERROR_STOP=1 -f supabase/bootstrap/schema_fingerprint.sql | tr -d '[:space:]')"
if [[ "$actual_fingerprint" != "$expected_fingerprint" ]]; then
  echo "Reconstructed schema fingerprint differs from the verified live RAD schema." >&2
  echo "Expected: $expected_fingerprint" >&2
  echo "Actual:   $actual_fingerprint" >&2
  exit 1
fi

echo "Clean RAD schema bootstrap and forward migrations verified against the live structural fingerprint."
