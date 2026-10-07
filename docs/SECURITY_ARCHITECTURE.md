# Security Architecture
Canonical authorization: private.has_role / SECURITY DEFINER RPCs with role checks
RLS on user-owned tables; Storage path = auth.uid()
Edge: ai-orchestrator verify_jwt=true; research-sync verify_jwt=false (worker/cron; service key internal)
Service-role only for privileged writes
