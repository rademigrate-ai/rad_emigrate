-- Minimal additive repair migration for consultation RPCs
-- Restores canonical SECURITY DEFINER functions for:
-- 1. public.list_admin_consultations()
-- 2. public.update_admin_consultation(uuid, text, text)
-- 3. public.submit_consultation_request(text, text, uuid)
--
-- Purely additive: does not drop tables, alter schema destructively, or revoke
-- table-level permissions prematurely. Safe for live production application.

begin;

-- 0. Performance index for consultation queries and rate-limit lookups
create index if not exists consultation_requests_user_created_idx
  on public.consultation_requests (user_id, created_at desc);

-- 1. Admin consultation listing RPC
create or replace function public.list_admin_consultations()
returns setof public.consultation_requests
language plpgsql
security definer
stable
set search_path = ''
as $function$
begin
  if not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select c.*
    from public.consultation_requests c
    order by c.created_at desc
    limit 100;
end
$function$;

alter function public.list_admin_consultations() owner to postgres;
revoke all on function public.list_admin_consultations() from public, anon;
grant execute on function public.list_admin_consultations() to authenticated;

comment on function public.list_admin_consultations() is
  'Admin-only listing of consultation requests with search_path safety.';

-- 2. Admin consultation update RPC
create or replace function public.update_admin_consultation(
  p_consultation_id uuid,
  p_status text,
  p_admin_note text default null
) returns void
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_status not in ('submitted','in_review','contacted','closed') then
    raise exception 'invalid consultation status' using errcode = '22023';
  end if;
  if char_length(coalesce(p_admin_note,'')) > 4000 then
    raise exception 'admin note too long' using errcode = '22023';
  end if;

  update public.consultation_requests
  set status = p_status,
      admin_note = nullif(btrim(p_admin_note),''),
      updated_at = now()
  where id = p_consultation_id;
  if not found then
    raise exception 'consultation not found' using errcode = 'P0002';
  end if;

  insert into public.admin_audit_logs(
    actor_id, action, resource_type, resource_id, safe_metadata
  ) values (
    auth.uid(), 'update', 'consultation_request', p_consultation_id::text,
    jsonb_build_object('status', p_status, 'has_internal_note', nullif(btrim(p_admin_note),'') is not null)
  );
end
$function$;

alter function public.update_admin_consultation(uuid,text,text) owner to postgres;
revoke all on function public.update_admin_consultation(uuid,text,text) from public, anon;
grant execute on function public.update_admin_consultation(uuid,text,text) to authenticated;

comment on function public.update_admin_consultation(uuid,text,text) is
  'Admin-only update of consultation request status and internal note with audit logging.';

-- 3. Authenticated consultation submission RPC
create or replace function public.submit_consultation_request(
  p_topic text,
  p_message text,
  p_related_application_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_topic text := nullif(btrim(p_topic), '');
  v_message text := nullif(btrim(p_message), '');
  v_request_id uuid;
  v_hour_count integer;
  v_day_count integer;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if v_topic is null or char_length(v_topic) not between 3 and 200 then
    raise exception 'invalid_consultation_topic' using errcode = '22023';
  end if;
  if v_message is null or char_length(v_message) not between 10 and 5000 then
    raise exception 'invalid_consultation_message' using errcode = '22023';
  end if;
  if p_related_application_id is not null and not exists (
    select 1
    from public.applications a
    where a.id = p_related_application_id
      and a.user_id = v_user_id
  ) then
    raise exception 'related_application_forbidden' using errcode = '42501';
  end if;

  -- Serialize a user's submissions so concurrent requests cannot overshoot.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('consultation:' || v_user_id::text, 0)
  );

  select
    count(*) filter (where c.created_at >= now() - interval '1 hour')::integer,
    count(*) filter (where c.created_at >= now() - interval '1 day')::integer
  into v_hour_count, v_day_count
  from public.consultation_requests c
  where c.user_id = v_user_id
    and c.created_at >= now() - interval '1 day';

  if v_hour_count >= 3 or v_day_count >= 10 then
    raise exception 'consultation_rate_limited' using errcode = 'P0001';
  end if;

  insert into public.consultation_requests (
    user_id, topic, message, related_application_id, status
  ) values (
    v_user_id, v_topic, v_message, p_related_application_id, 'submitted'
  )
  returning id into v_request_id;

  return v_request_id;
end
$function$;

alter function public.submit_consultation_request(text,text,uuid) owner to postgres;
revoke all on function public.submit_consultation_request(text,text,uuid) from public, anon, service_role;
grant execute on function public.submit_consultation_request(text,text,uuid) to authenticated;

comment on function public.submit_consultation_request(text,text,uuid) is
  'Owner-bound consultation intake with validation and per-user 3/hour, 10/day limits.';

commit;

