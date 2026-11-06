-- Individual owner-requested conversation management; no timed retention purge.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

alter table public.ai_sessions add column title text;
alter table public.ai_sessions add constraint ai_sessions_title_valid
  check (title is null or (length(btrim(title))>0 and char_length(title)<=120));
grant update(title),delete on public.ai_sessions to authenticated;

create policy "ai sessions delete own" on public.ai_sessions
  for delete to authenticated using ((select auth.uid())=user_id);

-- The existing owner UPDATE policy fences title changes. The existing message
-- FK cascades only messages from the deleted session; quota/request records keep
-- their existing FK/audit behavior. No service-role proxy bypass is introduced.
notify pgrst,'reload schema';
commit;
