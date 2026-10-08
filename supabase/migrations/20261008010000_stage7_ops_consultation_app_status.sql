-- Stage 7: application status authority + consultation_requests + notification helpers
-- Applied to production as stage7_ops_consultation_app_status

CREATE OR REPLACE FUNCTION private.guard_application_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF private.has_role(ARRAY['admin'::text, 'super_admin'::text]) THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.status IS NULL OR NEW.status NOT IN ('draft', 'submitted') THEN
      NEW.status := 'draft';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF OLD.status = 'draft' AND NEW.status = 'submitted' THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'application status change forbidden' USING errcode = '42501';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_application_status ON public.applications;
CREATE TRIGGER trg_guard_application_status
  BEFORE INSERT OR UPDATE ON public.applications
  FOR EACH ROW EXECUTE FUNCTION private.guard_application_status();

CREATE TABLE IF NOT EXISTS public.consultation_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  topic text NOT NULL,
  message text NOT NULL,
  related_application_id uuid REFERENCES public.applications(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted','in_review','contacted','closed')),
  admin_note text,
  assigned_to uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS consultation_requests_user_idx ON public.consultation_requests (user_id);
CREATE INDEX IF NOT EXISTS consultation_requests_status_idx ON public.consultation_requests (status);

ALTER TABLE public.consultation_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users insert own consultations" ON public.consultation_requests;
CREATE POLICY "users insert own consultations" ON public.consultation_requests
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id AND status = 'submitted');

DROP POLICY IF EXISTS "users read own consultations" ON public.consultation_requests;
CREATE POLICY "users read own consultations" ON public.consultation_requests
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id OR private.has_role(ARRAY['admin'::text, 'super_admin'::text]));

DROP POLICY IF EXISTS "admins manage consultations" ON public.consultation_requests;
CREATE POLICY "admins manage consultations" ON public.consultation_requests
  FOR ALL TO authenticated
  USING (private.has_role(ARRAY['admin'::text, 'super_admin'::text]))
  WITH CHECK (private.has_role(ARRAY['admin'::text, 'super_admin'::text]));

GRANT SELECT, INSERT ON public.consultation_requests TO authenticated;
GRANT ALL ON public.consultation_requests TO service_role;

CREATE OR REPLACE FUNCTION private.guard_consultation_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF private.has_role(ARRAY['admin'::text, 'super_admin'::text]) THEN
    NEW.updated_at := now();
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'consultation update forbidden' USING errcode = '42501';
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.status := 'submitted';
    NEW.admin_note := NULL;
    NEW.assigned_to := NULL;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_consultation_fields ON public.consultation_requests;
CREATE TRIGGER trg_guard_consultation_fields
  BEFORE INSERT OR UPDATE ON public.consultation_requests
  FOR EACH ROW EXECUTE FUNCTION private.guard_consultation_fields();

CREATE OR REPLACE FUNCTION public.create_user_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_action_path text DEFAULT NULL,
  p_source_id uuid DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
BEGIN
  IF p_user_id IS NULL OR p_title IS NULL OR p_body IS NULL THEN
    RAISE EXCEPTION 'invalid_notification';
  END IF;
  IF NOT private.has_role(ARRAY['admin'::text, 'super_admin'::text]) THEN
    RAISE EXCEPTION 'forbidden' USING errcode = '42501';
  END IF;
  INSERT INTO public.notifications (user_id, type, title, body, action_path, source_id)
  VALUES (p_user_id, coalesce(nullif(p_type,''), 'operational'), p_title, p_body, p_action_path, p_source_id)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_user_notification(uuid, text, text, text, text, uuid) TO service_role;
