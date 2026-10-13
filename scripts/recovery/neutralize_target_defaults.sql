-- REVIEW/EXECUTE ONLY ON A NEW DISPOSABLE RESTORE TARGET.
-- This changes creation defaults; it does not authorize broad object grants.
-- Set rad.recovery_target_confirmed=yes only after checking target isolation.
DO $$
BEGIN
  IF current_setting('rad.recovery_target_confirmed', true) IS DISTINCT FROM 'yes' THEN
    RAISE EXCEPTION 'restore-target confirmation is required';
  END IF;
END;
$$;

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated, service_role, postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
  REVOKE ALL ON FUNCTIONS FROM anon, authenticated, service_role, postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated, service_role, postgres;
