SELECT jsonb_build_object(
  'columns', md5(coalesce((
    SELECT jsonb_agg(jsonb_build_array(table_name, column_name, data_type, is_nullable, coalesce(column_default, '')) ORDER BY table_name, ordinal_position)::text
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages', 'content_sources', 'destinations', 'destination_localizations', 'program_categories', 'program_category_localizations', 'visa_programs', 'visa_program_localizations', 'visa_program_requirements', 'visa_program_steps', 'admin_audit_logs')
  ), '[]')),
  'constraints', md5(coalesce((
    SELECT jsonb_agg(jsonb_build_array(t.relname, c.conname, c.contype, pg_get_constraintdef(c.oid, true)) ORDER BY t.relname, c.conname)::text
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages', 'content_sources', 'destinations', 'destination_localizations', 'program_categories', 'program_category_localizations', 'visa_programs', 'visa_program_localizations', 'visa_program_requirements', 'visa_program_steps', 'admin_audit_logs')
  ), '[]')),
  'indexes', md5(coalesce((
    SELECT jsonb_agg(jsonb_build_array(tablename, indexname, indexdef) ORDER BY tablename, indexname)::text
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages', 'content_sources', 'destinations', 'destination_localizations', 'program_categories', 'program_category_localizations', 'visa_programs', 'visa_program_localizations', 'visa_program_requirements', 'visa_program_steps', 'admin_audit_logs')
  ), '[]')),
  'functions', md5(coalesce((
    SELECT jsonb_agg(jsonb_build_array(p.proname, p.prosrc, p.prosecdef, coalesce(p.proconfig, ARRAY[]::text[]), has_function_privilege('anon', p.oid, 'EXECUTE'), has_function_privilege('authenticated', p.oid, 'EXECUTE')) ORDER BY p.proname, p.oid)::text
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE (n.nspname = 'public' AND p.proname = 'handle_new_user')
       OR (n.nspname = 'private' AND p.proname IN ('has_role', 'set_updated_at', 'audit_content_change'))
  ), '[]')),
  'triggers', md5(coalesce((
    SELECT jsonb_agg(jsonb_build_array(n.nspname, t.relname, g.tgname, pg_get_triggerdef(g.oid, true), g.tgenabled) ORDER BY n.nspname, t.relname, g.tgname)::text
    FROM pg_trigger g
    JOIN pg_class t ON t.oid = g.tgrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE NOT g.tgisinternal
      AND ((n.nspname = 'auth' AND t.relname = 'users' AND g.tgname = 'on_auth_user_created')
        OR (n.nspname = 'public' AND t.relname IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages', 'content_sources', 'destinations', 'program_categories', 'visa_programs')))
  ), '[]')),
  'policies', md5(coalesce((
    SELECT jsonb_agg(jsonb_build_array(schemaname, tablename, policyname, permissive, roles, cmd, coalesce(qual, ''), coalesce(with_check, '')) ORDER BY schemaname, tablename, policyname)::text
    FROM pg_policies
    WHERE (schemaname = 'public' AND tablename IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages', 'content_sources', 'destinations', 'destination_localizations', 'program_categories', 'program_category_localizations', 'visa_programs', 'visa_program_localizations', 'visa_program_requirements', 'visa_program_steps', 'admin_audit_logs'))
       OR (schemaname = 'storage' AND tablename = 'objects' AND policyname LIKE 'documents storage %')
  ), '[]')),
  'rls', md5(coalesce((
    SELECT jsonb_agg(jsonb_build_array(t.relname, t.relrowsecurity, t.relforcerowsecurity) ORDER BY t.relname)::text
    FROM pg_class t
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages', 'content_sources', 'destinations', 'destination_localizations', 'program_categories', 'program_category_localizations', 'visa_programs', 'visa_program_localizations', 'visa_program_requirements', 'visa_program_steps', 'admin_audit_logs')
      AND t.relkind = 'r'
  ), '[]')),
  'bucket', md5(coalesce((
    SELECT jsonb_agg(jsonb_build_array(id, public, file_size_limit, allowed_mime_types) ORDER BY id)::text
    FROM storage.buckets
    WHERE id = 'documents'
  ), '[]'))
)::text;
