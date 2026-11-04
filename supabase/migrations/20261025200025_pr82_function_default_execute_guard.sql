-- Supabase can have schema-specific anon/authenticated EXECUTE defaults.
-- Revoking global PUBLIC defaults does not revoke these separate ACL entries.
-- Existing RPC ACLs and trusted service-role defaults are intentionally retained.
-- Target whichever role ran this migration (postgres on managed, supabase_admin
-- on self-hosted); any other role's defaults require separate review.
begin;
do $defaults$
begin
 execute format('alter default privileges for role %I revoke execute on functions from public,anon,authenticated', current_user);
 execute format('alter default privileges for role %I in schema public revoke execute on functions from public,anon,authenticated', current_user);
 execute format('alter default privileges for role %I in schema private revoke execute on functions from public,anon,authenticated', current_user);
end
$defaults$;
commit;
