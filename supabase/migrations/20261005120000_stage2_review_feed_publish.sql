-- Stage 2: review → edit → explicit publish → feed.
-- Research/AI never auto-publishes. Only admin/super_admin via this RPC.
begin;

-- Link content_drafts to published feed items for idempotent publish.
alter table public.content_drafts
  add column if not exists feed_item_id uuid references public.feed_items(id) on delete set null,
  add column if not exists category text
    check (category is null or category in ('update','guide','deadline','event','success_story','announcement')),
  add column if not exists primary_source_id uuid references public.content_sources(id) on delete set null,
  add column if not exists source_url text
    check (source_url is null or source_url like 'https://%');

create unique index if not exists content_drafts_feed_item_uidx
  on public.content_drafts(feed_item_id) where feed_item_id is not null;

-- Admin sets review status without publishing.
create or replace function public.set_content_draft_status(
  p_draft_id uuid,
  p_status text
) returns void language plpgsql security definer set search_path='' as $$
begin
  if not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode='42501';
  end if;
  if p_status not in ('draft','review','approved','rejected') then
    raise exception 'invalid status' using errcode='22023';
  end if;
  update public.content_drafts
  set status = p_status,
      reviewed_by = auth.uid(),
      updated_at = now()
  where id = p_draft_id
    and status is distinct from 'published';
  if not found then
    raise exception 'draft not found or already published' using errcode='P0002';
  end if;
  insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,safe_metadata)
  values(auth.uid(),'review','content_draft',p_draft_id::text,
    jsonb_build_object('status',p_status));
end $$;
alter function public.set_content_draft_status(uuid,text) owner to postgres;
revoke all on function public.set_content_draft_status(uuid,text) from public,anon;
grant execute on function public.set_content_draft_status(uuid,text) to authenticated;

-- Edit publication copy without destroying provenance fields.
create or replace function public.update_content_draft(
  p_draft_id uuid,
  p_title text,
  p_body text,
  p_language_code text default null,
  p_category text default null
) returns void language plpgsql security definer set search_path='' as $$
begin
  if not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode='42501';
  end if;
  if length(btrim(coalesce(p_title,''))) < 3 or length(btrim(coalesce(p_body,''))) < 3 then
    raise exception 'invalid content' using errcode='22023';
  end if;
  if p_language_code is not null and p_language_code not in ('fa','en') then
    raise exception 'invalid language' using errcode='22023';
  end if;
  if p_category is not null and p_category not in
    ('update','guide','deadline','event','success_story','announcement') then
    raise exception 'invalid category' using errcode='22023';
  end if;
  update public.content_drafts
  set title = left(btrim(p_title),300),
      body = btrim(p_body),
      language_code = coalesce(p_language_code, language_code),
      category = coalesce(p_category, category),
      updated_at = now()
  where id = p_draft_id
    and status is distinct from 'published';
  if not found then
    raise exception 'draft not found or already published' using errcode='P0002';
  end if;
end $$;
alter function public.update_content_draft(uuid,text,text,text,text) owner to postgres;
revoke all on function public.update_content_draft(uuid,text,text,text,text) from public,anon;
grant execute on function public.update_content_draft(uuid,text,text,text,text) to authenticated;

-- Explicit publish: idempotent, admin-only, never called by research worker.
create or replace function public.publish_content_draft(
  p_draft_id uuid,
  p_category text default 'update',
  p_slug text default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare
  v_draft public.content_drafts%rowtype;
  v_feed_id uuid;
  v_slug text;
  v_category text;
begin
  if not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode='42501';
  end if;

  select * into v_draft from public.content_drafts where id = p_draft_id for update;
  if not found then
    raise exception 'draft not found' using errcode='P0002';
  end if;

  -- Idempotent: already published returns existing feed item.
  if v_draft.status = 'published' and v_draft.feed_item_id is not null then
    return v_draft.feed_item_id;
  end if;

  if v_draft.status = 'rejected' then
    raise exception 'rejected draft cannot be published' using errcode='22023';
  end if;

  v_category := coalesce(nullif(btrim(p_category),''), v_draft.category, 'update');
  if v_category not in ('update','guide','deadline','event','success_story','announcement') then
    raise exception 'invalid category' using errcode='22023';
  end if;

  v_slug := coalesce(
    nullif(lower(regexp_replace(btrim(coalesce(p_slug,'')), '[^a-z0-9]+', '-', 'g')), ''),
    lower(regexp_replace(left(v_draft.title, 48), '[^a-zA-Z0-9]+', '-', 'g')) || '-' || substr(v_draft.id::text, 1, 8)
  );
  v_slug := trim(both '-' from v_slug);
  if v_slug !~ '^[a-z0-9-]+$' then
    v_slug := 'rad-update-' || substr(v_draft.id::text, 1, 12);
  end if;

  -- Avoid slug collision without failing the publish.
  if exists (select 1 from public.feed_items where slug = v_slug and (v_draft.feed_item_id is null or id <> v_draft.feed_item_id)) then
    v_slug := v_slug || '-' || substr(gen_random_uuid()::text, 1, 8);
  end if;

  if v_draft.feed_item_id is null then
    insert into public.feed_items(
      slug, category, status, primary_source_id, source_url,
      published_at, created_by, reviewed_by
    ) values (
      v_slug, v_category, 'published', v_draft.primary_source_id, v_draft.source_url,
      now(), auth.uid(), auth.uid()
    ) returning id into v_feed_id;
  else
    v_feed_id := v_draft.feed_item_id;
    update public.feed_items
    set status = 'published',
        category = v_category,
        published_at = coalesce(published_at, now()),
        reviewed_by = auth.uid(),
        updated_at = now()
    where id = v_feed_id;
  end if;

  insert into public.feed_item_localizations(feed_item_id, locale, title, summary, body)
  values (
    v_feed_id,
    v_draft.language_code,
    v_draft.title,
    left(v_draft.body, 500),
    v_draft.body
  )
  on conflict (feed_item_id, locale) do update
  set title = excluded.title,
      summary = excluded.summary,
      body = excluded.body;

  update public.content_drafts
  set status = 'published',
      feed_item_id = v_feed_id,
      category = v_category,
      reviewed_by = auth.uid(),
      updated_at = now()
  where id = p_draft_id;

  insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,safe_metadata)
  values(auth.uid(),'publish','content_draft',p_draft_id::text,
    jsonb_build_object('feed_item_id',v_feed_id,'slug',v_slug,'category',v_category));

  return v_feed_id;
end $$;
alter function public.publish_content_draft(uuid,text,text) owner to postgres;
revoke all on function public.publish_content_draft(uuid,text,text) from public,anon;
grant execute on function public.publish_content_draft(uuid,text,text) to authenticated;

-- Research findings status (still never publishes).
create or replace function public.set_research_finding_status(
  p_finding_id uuid,
  p_status text
) returns void language plpgsql security definer set search_path='' as $$
begin
  if not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode='42501';
  end if;
  if p_status not in ('review','approved','rejected') then
    raise exception 'invalid status' using errcode='22023';
  end if;
  update public.research_findings
  set review_status = p_status
  where id = p_finding_id;
  if not found then
    raise exception 'finding not found' using errcode='P0002';
  end if;
end $$;
alter function public.set_research_finding_status(uuid,text) owner to postgres;
revoke all on function public.set_research_finding_status(uuid,text) from public,anon;
grant execute on function public.set_research_finding_status(uuid,text) to authenticated;

commit;
