-- Local-first forward proposal. Never apply to Production without release approval.
begin;

alter table public.consultation_requests
  add column if not exists revision integer not null default 1 check (revision > 0);

create table public.consultation_request_events (
  id uuid primary key default gen_random_uuid(),
  consultation_id uuid not null references public.consultation_requests(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  event_type text not null check (event_type in ('created','status_changed','assignment_changed','note_changed')),
  from_status text,
  to_status text not null,
  revision integer not null,
  created_at timestamptz not null default now()
);
create index consultation_events_request_idx on public.consultation_request_events(consultation_id, created_at, id);
create index consultation_events_actor_idx on public.consultation_request_events(actor_id) where actor_id is not null;
alter table public.consultation_request_events enable row level security;
revoke all on public.consultation_request_events from public, anon, authenticated;
grant select(id, consultation_id, event_type, from_status, to_status, revision, created_at)
  on public.consultation_request_events to authenticated;
grant all on public.consultation_request_events to service_role;
create policy consultation_events_owner_read on public.consultation_request_events for select to authenticated
  using (exists (select 1 from public.consultation_requests c where c.id=consultation_id
    and (c.user_id=(select auth.uid()) or private.has_role(array['admin','super_admin']))));
create policy consultation_events_service on public.consultation_request_events for all to service_role
  using(true) with check(true);

create function private.consultation_revision() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op='INSERT' then new.revision := 1;
  elsif row(new.status,new.assigned_to,new.admin_note) is distinct from row(old.status,old.assigned_to,old.admin_note) then
    new.revision := old.revision + 1;
  else new.revision := old.revision;
  end if;
  return new;
end $$;
revoke all on function private.consultation_revision() from public, anon, authenticated;
create trigger trg_consultation_revision before insert or update on public.consultation_requests
  for each row execute function private.consultation_revision();

create function private.consultation_event() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_type text; v_from text;
begin
  if tg_op='INSERT' then v_type := 'created';
  elsif new.revision=old.revision then return new;
  else
    v_from := old.status;
    v_type := case when new.status is distinct from old.status then 'status_changed'
      when new.assigned_to is distinct from old.assigned_to then 'assignment_changed' else 'note_changed' end;
  end if;
  insert into public.consultation_request_events(consultation_id,actor_id,event_type,from_status,to_status,revision)
    values(new.id,auth.uid(),v_type,v_from,new.status,new.revision);
  return new;
end $$;
revoke all on function private.consultation_event() from public, anon, authenticated;
create trigger trg_consultation_event after insert or update on public.consultation_requests
  for each row execute function private.consultation_event();

create function public.transition_admin_consultation(
  p_consultation_id uuid, p_status text, p_expected_revision integer, p_admin_note text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_revision integer;
begin
  if not private.has_role(array['admin','super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if p_expected_revision is null or p_expected_revision<1 or p_status is null then
    raise exception 'invalid_transition' using errcode='22023';
  end if;
  select revision into v_revision from public.consultation_requests where id=p_consultation_id for update;
  if not found then raise exception 'consultation_not_found' using errcode='P0002'; end if;
  if v_revision<>p_expected_revision then raise exception 'consultation_version_conflict' using errcode='40001'; end if;
  perform public.update_admin_consultation(p_consultation_id,p_status,p_admin_note);
  select revision into v_revision from public.consultation_requests where id=p_consultation_id;
  return jsonb_build_object('revision',v_revision,'status',p_status);
end $$;
revoke all on function public.transition_admin_consultation(uuid,text,integer,text) from public,anon;
grant execute on function public.transition_admin_consultation(uuid,text,integer,text) to authenticated;

create function public.assign_admin_consultation(
  p_consultation_id uuid, p_assignee_id uuid, p_expected_revision integer
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_revision integer;
begin
  if not private.has_role(array['admin','super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if p_expected_revision is null or p_expected_revision<1 then raise exception 'invalid_revision' using errcode='22023'; end if;
  if p_assignee_id is not null and not exists(select 1 from public.profiles where id=p_assignee_id and role in ('admin','super_admin')) then
    raise exception 'assignee_must_be_admin' using errcode='22023';
  end if;
  select revision into v_revision from public.consultation_requests where id=p_consultation_id for update;
  if not found then raise exception 'consultation_not_found' using errcode='P0002'; end if;
  if v_revision<>p_expected_revision then raise exception 'consultation_version_conflict' using errcode='40001'; end if;
  update public.consultation_requests set assigned_to=p_assignee_id where id=p_consultation_id returning revision into v_revision;
  insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,safe_metadata)
    values(auth.uid(),'update','consultation_request',p_consultation_id::text,jsonb_build_object('assignment_changed',true,'assigned',p_assignee_id is not null));
  return jsonb_build_object('revision',v_revision,'assigned',p_assignee_id is not null);
end $$;
revoke all on function public.assign_admin_consultation(uuid,uuid,integer) from public,anon;
grant execute on function public.assign_admin_consultation(uuid,uuid,integer) to authenticated;

-- Real transports remain unconfigured. This outbox can record sandbox receipts
-- only; no sandbox receipt grants a paid entitlement or proves external delivery.
alter table public.notification_preferences add column if not exists sms_enabled boolean not null default false;
alter table public.notification_preferences add column if not exists time_zone text not null default 'UTC';
create function private.validate_notification_time_zone() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from pg_catalog.pg_timezone_names where name=new.time_zone) then
    raise exception 'invalid_time_zone' using errcode='22023';
  end if;
  return new;
end $$;
revoke all on function private.validate_notification_time_zone() from public,anon,authenticated;
create trigger trg_notification_time_zone before insert or update of time_zone on public.notification_preferences
  for each row execute function private.validate_notification_time_zone();

create table public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  channel text not null check(channel in ('email','sms','push')),
  transport text not null default 'sandbox' check(transport='sandbox'),
  status text not null default 'queued' check(status in ('queued','processing','sandbox_delivered','failed','cancelled')),
  attempts integer not null default 0 check(attempts between 0 and 3),
  available_at timestamptz not null default now(),
  lease_until timestamptz,
  lease_token uuid,
  safe_error_code text check(safe_error_code in ('sandbox_transport_failed','preference_disabled','lease_expired')),
  created_at timestamptz not null default now(),
  finished_at timestamptz,
  unique(notification_id,channel)
);
create index notification_deliveries_pending_idx on public.notification_deliveries(available_at,id) where status in ('queued','processing');
create index notification_deliveries_user_idx on public.notification_deliveries(user_id);
alter table public.notification_deliveries enable row level security;
revoke all on public.notification_deliveries from public,anon,authenticated;
grant select(id,notification_id,user_id,channel,transport,status,attempts,created_at,finished_at) on public.notification_deliveries to authenticated;
grant all on public.notification_deliveries to service_role;
create policy notification_deliveries_owner on public.notification_deliveries for select to authenticated
  using(user_id=(select auth.uid()));
create policy notification_deliveries_service on public.notification_deliveries for all to service_role using(true) with check(true);

create function private.notification_channel_enabled(p_user uuid,p_channel text) returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce((select case p_channel when 'email' then email_enabled when 'sms' then sms_enabled when 'push' then push_enabled else false end
    from public.notification_preferences where user_id=p_user),false)
$$;
revoke all on function private.notification_channel_enabled(uuid,text) from public,anon,authenticated;

create function private.notification_due_at(p_user uuid,p_at timestamptz) returns timestamptz
language plpgsql stable security definer set search_path='' as $$
declare p public.notification_preferences%rowtype; v_local timestamp; v_end timestamp;
begin
  select * into p from public.notification_preferences where user_id=p_user;
  if not found or p.quiet_hours_start is null or p.quiet_hours_end is null or p.quiet_hours_start=p.quiet_hours_end then return p_at; end if;
  v_local := p_at at time zone p.time_zone;
  if (p.quiet_hours_start<p.quiet_hours_end and v_local::time>=p.quiet_hours_start and v_local::time<p.quiet_hours_end)
    or (p.quiet_hours_start>p.quiet_hours_end and (v_local::time>=p.quiet_hours_start or v_local::time<p.quiet_hours_end)) then
    v_end := v_local::date + p.quiet_hours_end;
    if p.quiet_hours_start>p.quiet_hours_end and v_local::time>=p.quiet_hours_start then v_end:=v_end+interval '1 day'; end if;
    return v_end at time zone p.time_zone;
  end if;
  return p_at;
end $$;
revoke all on function private.notification_due_at(uuid,timestamptz) from public,anon,authenticated;

create function public.queue_notification_delivery(p_notification_id uuid,p_channel text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare n public.notifications%rowtype; v_id uuid;
begin
  if p_channel is null or p_channel not in ('email','sms','push') then raise exception 'invalid_channel' using errcode='22023'; end if;
  select * into n from public.notifications where id=p_notification_id;
  if not found then raise exception 'notification_not_found' using errcode='P0002'; end if;
  if coalesce(auth.jwt()->>'role','')<>'service_role' and auth.uid() is distinct from n.user_id
    and not private.has_role(array['admin','super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if not private.notification_channel_enabled(n.user_id,p_channel) then return jsonb_build_object('queued',false,'reason','preference_disabled'); end if;
  insert into public.notification_deliveries(notification_id,user_id,channel,available_at)
    values(n.id,n.user_id,p_channel,private.notification_due_at(n.user_id,now()))
    on conflict(notification_id,channel) do nothing returning id into v_id;
  if v_id is null then select id into v_id from public.notification_deliveries where notification_id=n.id and channel=p_channel; end if;
  return jsonb_build_object('queued',true,'delivery_id',v_id,'transport','sandbox');
end $$;
revoke all on function public.queue_notification_delivery(uuid,text) from public,anon;
grant execute on function public.queue_notification_delivery(uuid,text) to authenticated,service_role;

create function public.claim_sandbox_notification() returns setof public.notification_deliveries
language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
  update public.notification_deliveries d set status='cancelled',safe_error_code='preference_disabled',finished_at=now(),lease_token=null,lease_until=null
    where d.status in ('queued','processing') and not private.notification_channel_enabled(d.user_id,d.channel);
  update public.notification_deliveries d set available_at=private.notification_due_at(d.user_id,now())
    where d.status='queued' and d.available_at<=now() and private.notification_due_at(d.user_id,now())>now();
  update public.notification_deliveries set status='failed',safe_error_code='lease_expired',finished_at=now(),lease_token=null,lease_until=null
    where status='processing' and lease_until<=now() and attempts>=3;
  select d.id into v_id from public.notification_deliveries d where d.attempts<3 and d.available_at<=now()
    and (d.status='queued' or (d.status='processing' and d.lease_until<=now()))
    and private.notification_due_at(d.user_id,now())<=now()
    order by d.available_at,d.id for update skip locked limit 1;
  return query update public.notification_deliveries set status='processing',attempts=attempts+1,
    lease_until=now()+interval '60 seconds',lease_token=gen_random_uuid()
    where id=v_id returning *;
end $$;
revoke all on function public.claim_sandbox_notification() from public,anon,authenticated;
grant execute on function public.claim_sandbox_notification() to service_role;

create function public.finish_sandbox_notification(p_delivery_id uuid,p_lease_token uuid,p_success boolean) returns boolean
language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
  if p_success is null then raise exception 'result_required' using errcode='22023'; end if;
  update public.notification_deliveries d set status='cancelled',safe_error_code='preference_disabled',finished_at=now(),lease_token=null,lease_until=null
    where d.id=p_delivery_id and d.lease_token=p_lease_token and d.status='processing' and d.lease_until>now()
    and not private.notification_channel_enabled(d.user_id,d.channel);
  if found then return false; end if;
  update public.notification_deliveries set
    status=case when p_success then 'sandbox_delivered' when attempts<3 then 'queued' else 'failed' end,
    safe_error_code=case when p_success then null else 'sandbox_transport_failed' end,
    available_at=case when p_success then available_at else now()+attempts*interval '1 minute' end,
    finished_at=case when p_success or attempts>=3 then now() else null end,
    lease_token=null,lease_until=null
  where id=p_delivery_id and lease_token=p_lease_token and status='processing' and lease_until>now();
  return found;
end $$;
revoke all on function public.finish_sandbox_notification(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.finish_sandbox_notification(uuid,uuid,boolean) to service_role;

commit;
