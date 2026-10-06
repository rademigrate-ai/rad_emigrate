-- Simplify profiles UPDATE WITH CHECK to ownership only.
-- Role escalation is blocked by a BEFORE UPDATE trigger (no RLS recursion).
begin;

create or replace function private.prevent_profile_role_escalation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if new.role is distinct from old.role then
    if not private.has_role(array['super_admin']) then
      raise exception 'role change forbidden' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_prevent_profile_role_escalation on public.profiles;
create trigger trg_prevent_profile_role_escalation
  before update on public.profiles
  for each row
  execute function private.prevent_profile_role_escalation();

drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

commit;
