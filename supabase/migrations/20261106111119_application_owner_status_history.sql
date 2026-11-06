-- Read-only, owner-scoped status history sourced from the existing immutable
-- application_status_history trigger. No fabricated case events or staff data.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create index if not exists application_status_history_owner_cursor_idx
  on public.application_status_history (application_id, id desc);

create function public.list_application_status_history(
  p_application_id uuid,
  p_before_id bigint default null,
  p_limit integer default 50
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_items jsonb;
begin
  if v_actor is null or not exists (
    select 1 from public.applications
    where id = p_application_id and user_id = v_actor
  ) then
    raise exception 'application history not accessible'
      using errcode = '42501';
  end if;

  if (p_before_id is not null and p_before_id <= 0)
     or p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'invalid history cursor or page size'
      using errcode = '22023';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', h.id,
        'from_status', h.from_status,
        'to_status', h.to_status,
        'changed_at', to_char(
          h.changed_at at time zone 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
        )
      )
      order by h.id desc
    ), '[]'::jsonb
  ) into v_items
  from (
    select id, from_status, to_status, changed_at
    from public.application_status_history
    where application_id = p_application_id
      and (p_before_id is null or id < p_before_id)
    order by id desc
    limit p_limit
  ) h;
  return v_items;
end $$;

alter function public.list_application_status_history(uuid, bigint, integer)
  owner to postgres;
revoke all on function public.list_application_status_history(uuid, bigint, integer)
  from public, anon, authenticated;
grant execute on function public.list_application_status_history(uuid, bigint, integer)
  to authenticated;

commit;
