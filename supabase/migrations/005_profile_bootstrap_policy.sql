-- Project 05: allow an authenticated user to recreate only their own missing profile.
drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own" on public.profiles
  for insert to authenticated
  with check ((select auth.uid()) = id);
