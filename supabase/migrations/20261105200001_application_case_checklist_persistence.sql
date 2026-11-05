-- Case milestones persisted on the authenticated backend, not only on
-- SharedPreferences. These are user-created planning notes, never official
-- immigration requirements or preassigned government deadlines.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create table public.application_case_checklists (
  application_id uuid primary key references public.applications(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  items jsonb not null default '[]'::jsonb,
  revision integer not null default 1 check (revision >= 1),
  updated_at timestamptz not null default now(),
  constraint application_case_checklist_items_array
    check (jsonb_typeof(items) = 'array'
      and jsonb_array_length(items) <= 100
      and octet_length(items::text) <= 65536)
);
create index application_case_checklists_owner_idx
  on public.application_case_checklists(owner_id, updated_at desc);
alter table public.application_case_checklists enable row level security;
-- No direct client table policy or grants: use owner-checked RPCs only.
revoke all on public.application_case_checklists from public, anon, authenticated;
grant select, insert, update, delete on public.application_case_checklists to postgres;

create function public.get_application_case_checklist(p_application_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_actor uuid := auth.uid();
  v_items jsonb;
  v_revision integer;
begin
  if v_actor is null or not exists (
    select 1 from public.applications
    where id = p_application_id and user_id = v_actor
  ) then
    raise exception 'application not accessible' using errcode='42501';
  end if;
  select items, revision into v_items, v_revision
  from public.application_case_checklists
  where application_id = p_application_id and owner_id = v_actor;
  if not found then return null; end if;
  return jsonb_build_object('items', v_items, 'revision', v_revision);
end $$;
alter function public.get_application_case_checklist(uuid) owner to postgres;
revoke all on function public.get_application_case_checklist(uuid)
  from public, anon;
grant execute on function public.get_application_case_checklist(uuid)
  to authenticated;

create function public.put_application_case_checklist(
  p_application_id uuid, p_items jsonb, p_expected_revision integer
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid := auth.uid();
  v_new_revision integer;
  v_item jsonb;
begin
  if v_actor is null or not exists (
    select 1 from public.applications
    where id = p_application_id and user_id = v_actor
  ) then
    raise exception 'application not accessible' using errcode='42501';
  end if;
  if p_expected_revision is null or p_expected_revision < 0 then
    raise exception 'invalid expected checklist revision' using errcode='22023';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'checklist items must be an array' using errcode='22023';
  end if;
  if jsonb_array_length(p_items) > 100
     or octet_length(p_items::text) > 65536 then
    raise exception 'checklist exceeds size or item limit' using errcode='22023';
  end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    if coalesce(jsonb_typeof(v_item),'') <> 'object'
       or coalesce(jsonb_typeof(v_item->'id'),'') <> 'string'
       or coalesce(jsonb_typeof(v_item->'title'),'') <> 'string'
       or coalesce(btrim(v_item->>'id'),'') = ''
       or length(v_item->>'id') > 160
       or coalesce(btrim(v_item->>'title'),'') = ''
       or length(v_item->>'title') > 300
       or coalesce(v_item->>'status','') not in
          ('notStarted','inProgress','completed','blocked','skipped') then
      raise exception 'invalid checklist item' using errcode='22023';
    end if;
  end loop;
  if exists (
    select 1 from jsonb_array_elements(p_items) item
    group by item->>'id' having count(*) > 1
  ) then
    raise exception 'duplicate checklist item identifier' using errcode='22023';
  end if;

  if p_expected_revision = 0 then
    insert into public.application_case_checklists
      (application_id, owner_id, items, revision)
    values (p_application_id, v_actor, p_items, 1)
    on conflict (application_id) do nothing
    returning revision into v_new_revision;
  else
    update public.application_case_checklists
    set items = p_items, revision = revision + 1, updated_at = now()
    where application_id = p_application_id and owner_id = v_actor
      and revision = p_expected_revision
    returning revision into v_new_revision;
  end if;
  if v_new_revision is null then
    raise exception 'stale checklist revision; reload before saving'
      using errcode='PT409';
  end if;
  return jsonb_build_object('revision', v_new_revision);
end $$;
alter function public.put_application_case_checklist(uuid, jsonb, integer)
  owner to postgres;
revoke all on function public.put_application_case_checklist(uuid, jsonb, integer)
  from public, anon;
grant execute on function public.put_application_case_checklist(uuid, jsonb, integer)
  to authenticated;

commit;
