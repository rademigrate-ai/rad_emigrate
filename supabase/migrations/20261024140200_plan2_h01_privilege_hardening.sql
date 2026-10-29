-- Plan 2 H01: narrow excessive table privileges for sensitive admin/ops tables.
-- Does not weaken RLS. Preserves service_role. Consultation writes stay via RPC.
-- Consultation SELECT is column-scoped (Stage1 P0): applicants never see admin_note/assigned_to.
begin;

do $$
declare
  t text;
begin
  foreach t in array array[
    'admin_case_notes',
    'admin_saved_views',
    'admin_tasks',
    'ai_entitlements',
    'application_status_history'
  ]
  loop
    if to_regclass(format('public.%I', t)) is not null then
      execute format('revoke all on table public.%I from public, anon, authenticated', t);
      if t in ('admin_case_notes', 'admin_saved_views', 'admin_tasks') then
        execute format('grant select, insert, update, delete on table public.%I to authenticated', t);
      elsif t = 'application_status_history' then
        execute format('grant select on table public.%I to authenticated', t);
      end if;
      execute format('grant all on table public.%I to service_role', t);
    end if;
  end loop;

  -- consultation_requests: restore Stage1 P0 column boundary.
  -- Public columns only for authenticated; internal columns remain service/admin via DEFINER RPCs.
  -- Direct INSERT already removed in 20261012110945 (submit_consultation_request path).
  if to_regclass('public.consultation_requests') is not null then
    execute 'revoke all on table public.consultation_requests from public, anon';
    execute 'revoke all on table public.consultation_requests from authenticated';
    execute 'grant select (id, user_id, topic, message, related_application_id, status, created_at, updated_at) on table public.consultation_requests to authenticated';
    execute 'grant all on table public.consultation_requests to service_role';
  end if;
end
$$;

do $$
declare
  r record;
begin
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p')
      and c.relname in (
        'admin_case_notes','admin_saved_views','admin_tasks',
        'ai_entitlements','application_status_history','consultation_requests',
        'booking_requests','interview_requests','service_catalog',
        'service_catalog_localizations'
      )
  loop
    execute format(
      'revoke truncate, references, trigger on table public.%I from public, anon, authenticated',
      r.relname
    );
  end loop;
end
$$;

-- Ensure search index maintenance satisfies PostgreSQL safeupdate requiring WHERE clause.
CREATE OR REPLACE FUNCTION private.rad_index_article()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.visa_article_revisions;
begin
 if tg_op='INSERT' then
  if new.published_id is null then return new; end if;
 elsif new.published_id is not distinct from old.published_id then return new;
 end if;
 delete from public.visa_article_search_documents where article_id=new.article_id and locale=new.locale;
 select * into r from public.visa_article_revisions where id=new.published_id;
 if found then
  insert into public.visa_article_search_documents
  select r.article_id,r.id,s.id,r.locale,r.title,s.heading,s.anchor,private.rad_blocks_text(s.blocks),
   private.rad_search_normalize(r.title||' '||s.heading||' '||private.rad_blocks_text(s.blocks)||' '||private.rad_search_metadata(r.article_id,r.locale)),
   setweight(to_tsvector('simple',private.rad_search_normalize(r.title)),'A')||setweight(to_tsvector('simple',private.rad_search_normalize(private.rad_search_metadata(r.article_id,r.locale))),'B')||setweight(to_tsvector('simple',private.rad_search_normalize(s.heading)),'B')||setweight(to_tsvector('simple',private.rad_search_normalize(private.rad_blocks_text(s.blocks))),'C')
  from public.visa_article_sections s where s.revision_id=r.id;
 end if;
 update private.rad_search_version set version=version+1 where id = true;
 return new;
end $function$;

commit;
