-- Stage 9: revoke overly broad EXECUTE on privileged SECURITY DEFINER RPCs
REVOKE ALL ON FUNCTION public.create_user_notification(uuid, text, text, text, text, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_user_notification(uuid, text, text, text, text, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.get_ai_access_decision(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_ai_access_decision(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_ai_daily_quota_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_ai_daily_quota_status(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.consume_ai_guest_quota(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.consume_ai_guest_quota(text, integer) TO service_role;

REVOKE ALL ON FUNCTION public.retrieve_knowledge(text, text, text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.retrieve_knowledge(text, text, text, text, integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.configure_ai_provider(text, text, text, text, text, boolean, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.publish_content_draft(uuid, text, text) FROM PUBLIC, anon;

DROP POLICY IF EXISTS "service manages guest quota" ON public.ai_guest_quota;
CREATE POLICY "service manages guest quota" ON public.ai_guest_quota
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);
