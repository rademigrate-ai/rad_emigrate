-- F10: internal publication-head deletion must invalidate the search projection.
-- Clients receive no new table or function privileges. Existing rows are untouched.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

create or replace function private.rad_remove_article_search()
returns trigger language plpgsql security definer set search_path = '' as $$
declare removed integer;
begin
  delete from public.visa_article_search_documents
    where article_id = old.article_id and locale = old.locale;
  get diagnostics removed = row_count;
  if old.published_id is not null or removed > 0 then
    update private.rad_search_version set version = version + 1 where id = true;
  end if;
  return old;
end $$;
revoke all on function private.rad_remove_article_search()
  from public, anon, authenticated, service_role;

drop trigger if exists rad_article_deletion_search on public.visa_article_heads;
create trigger rad_article_deletion_search after delete on public.visa_article_heads
  for each row execute function private.rad_remove_article_search();
commit;
