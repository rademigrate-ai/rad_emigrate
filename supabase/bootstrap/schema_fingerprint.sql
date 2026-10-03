SELECT md5(jsonb_build_object(
  'columns', coalesce((
    SELECT jsonb_agg(jsonb_build_array(table_name, column_name, data_type, is_nullable, coalesce(column_default, '')) ORDER BY table_name, ordinal_position)
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages')
  ), '[]'::jsonb),
  'constraints', coalesce((
    SELECT jsonb_agg(jsonb_build_array(t.relname, c.conname, c.contype, pg_get_constraintdef(c.oid, true)) ORDER BY t.relname, c.conname)
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages')
  ), '[]'::jsonb),
  'indexes', coalesce((
    SELECT jsonb_agg(jsonb_build_array(tablename, indexname, indexdef) ORDER BY tablename, indexname)
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages')
  ), '[]'::jsonb),
  'functions', coalesce((
    SELECT jsonb_agg(jsonb_build_array(p.proname, pg_get_functiondef(p.oid), p.prosecdef, coalesce(p.proconfig, ARRAY[]::text[]), has_function_privilege('anon', p.oid, 'EXECUTE'), has_function_privilege('authenticated', p.oid, 'EXECUTE')) ORDER BY p.proname, p.oid)
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'handle_new_user'
  ), '[]'::jsonb),
  'triggers', coalesce((
    SELECT jsonb_agg(jsonb_build_array(n.nspname, t.relname, g.tgname, pg_get_triggerdef(g.oid, true), g.tgenabled) ORDER BY n.nspname, t.relname, g.tgname)
    FROM pg_trigger g
    JOIN pg_class t ON t.oid = g.tgrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE NOT g.tgisinternal
      AND ((n.nspname = 'auth' AND t.relname = 'users' AND g.tgname = 'on_auth_user_created')
        OR (n.nspname = 'public' AND t.relname IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages')))
  ), '[]'::jsonb),
  'policies', coalesce((
    SELECT jsonb_agg(jsonb_build_array(schemaname, tablename, policyname, permissive, roles, cmd, coalesce(qual, ''), coalesce(with_check, '')) ORDER BY schemaname, tablename, policyname)
    FROM pg_policies
    WHERE (schemaname = 'public' AND tablename IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages'))
       OR (schemaname = 'storage' AND tablename = 'objects' AND policyname LIKE 'documents storage %')
  ), '[]'::jsonb),
  'rls', coalesce((
    SELECT jsonb_agg(jsonb_build_array(t.relname, t.relrowsecurity, t.relforcerowsecurity) ORDER BY t.relname)
    FROM pg_class t
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname IN ('profiles', 'applications', 'documents', 'ai_sessions', 'ai_session_messages')
      AND t.relkind = 'r'
  ), '[]'::jsonb),
  'documents_bucket', coalesce((
    SELECT jsonb_agg(jsonb_build_array(id, public, file_size_limit, allowed_mime_types) ORDER BY id)
    FROM storage.buckets
    WHERE id = 'documents'
  ), '[]'::jsonb)
)::text);
