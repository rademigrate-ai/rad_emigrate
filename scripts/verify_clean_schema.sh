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
  if [[ "$AUTO_STARTED" == "1" ]]; then
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
  rls_count integer;
  app_policy_count integer;
  storage_policy_count integer;
  trigger_count integer;
  bucket_count integer;
BEGIN
  SELECT count(*) INTO table_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages');

  SELECT count(*) INTO rls_count
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND c.relname IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages')
    AND c.relrowsecurity;

  SELECT count(*) INTO app_policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages');

  SELECT count(*) INTO storage_policy_count
  FROM pg_policies
  WHERE schemaname = 'storage'
    AND tablename = 'objects'
    AND policyname LIKE 'documents storage %';

  SELECT count(*) INTO trigger_count
  FROM information_schema.triggers
  WHERE event_object_schema = 'auth'
    AND event_object_table = 'users'
    AND trigger_name = 'on_auth_user_created';

  SELECT count(*) INTO bucket_count
  FROM storage.buckets
  WHERE id = 'documents'
    AND public = false
    AND file_size_limit = 10485760
    AND allowed_mime_types = ARRAY['application/pdf', 'image/jpeg', 'image/png']::text[];

  IF table_count <> 5 THEN RAISE EXCEPTION 'Expected 5 public RAD tables, got %', table_count; END IF;
  IF rls_count <> 5 THEN RAISE EXCEPTION 'Expected RLS on all 5 public RAD tables, got %', rls_count; END IF;
  IF app_policy_count <> 17 THEN RAISE EXCEPTION 'Expected 17 public owner policies, got %', app_policy_count; END IF;
  IF storage_policy_count <> 3 THEN RAISE EXCEPTION 'Expected 3 documents Storage policies, got %', storage_policy_count; END IF;
  IF trigger_count <> 1 THEN RAISE EXCEPTION 'Expected auth signup trigger, got %', trigger_count; END IF;
  IF bucket_count <> 1 THEN RAISE EXCEPTION 'Expected private 10 MiB documents bucket with MIME allowlist, got %', bucket_count; END IF;
END
$verify$;
SQL

echo "Clean RAD schema bootstrap and forward migrations verified."
