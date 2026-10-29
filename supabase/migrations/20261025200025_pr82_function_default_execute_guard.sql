-- Supabase can have schema-specific anon/authenticated EXECUTE defaults.
-- Revoking global PUBLIC defaults does not revoke these separate ACL entries.
-- Existing RPC ACLs and trusted service-role defaults are intentionally retained.
begin;
alter default privileges for role postgres revoke execute on functions from public,anon,authenticated;
alter default privileges for role postgres in schema public revoke execute on functions from public,anon,authenticated;
alter default privileges for role postgres in schema private revoke execute on functions from public,anon,authenticated;
commit;
