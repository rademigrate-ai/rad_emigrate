-- The captured production profile ACL already grants the trusted service role
-- these operations. Declare them explicitly for clean stacks whose platform
-- defaults no longer grant them. Client grants and RLS are unchanged.
begin;
grant select,insert,update,delete on public.profiles to service_role;
-- INSERT/UPDATE role changes still pass the audited server/bootstrap trigger;
-- ordinary clients cannot INSERT(role) or elevate through UPDATE.
commit;
