-- Prevent profile self-role escalation without recursively querying profiles
-- from the profiles RLS policy itself.
begin;

drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check (
    (select auth.uid()) = id
    and (select private.has_role(array[role]))
  );

commit;
