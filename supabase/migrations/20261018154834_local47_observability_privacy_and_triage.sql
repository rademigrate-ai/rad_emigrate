-- Local-tested forward proposal. Alert policy is OFF until an owner approves it.
create function private.safe_operational_code(value text)
returns text language sql immutable returns null on null input set search_path='' as $$
 select case when value in ('ok','unspecified','provider_timeout','provider_unavailable','provider_unauthorized',
  'provider_rate_limited','provider_request_failed','provider_malformed_response','provider_refused','provider_response_too_large',
  'provider_model_unavailable','provider_unreachable','unsafe_base_url','unsafe_redirect','database_unavailable',
  'storage_unavailable','source_fetch_failed','source_timeout','source_too_large','source_empty','lease_expired',
  'quota_check_failed','routing_unavailable','no_eligible_model','processing_unavailable','synthetic_failure')
  or value ~ '^(source_http|database)_[45][0-9]{2}$' then value else 'unspecified' end;
$$;
revoke all on function private.safe_operational_code(text) from public,anon,authenticated;
grant execute on function private.safe_operational_code(text) to service_role;

-- Known typed metrics only. Unknown keys are omitted, so PII cannot survive in
-- either an unexpected key name or nested values. No free-form payload storage.
create or replace function private.redact_safe_metadata(value jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare k text; v jsonb; result jsonb:='{}'; accepted boolean; removed integer:=0; n numeric; s text;
begin
 if value is null then return '{}'; end if;
 if jsonb_typeof(value)<>'object' or octet_length(value::text)>16384 then
  return '{"payload_rejected":true,"redacted_fields":1}'::jsonb; end if;
 if (select count(*) from jsonb_object_keys(value))>64 then
  return '{"payload_rejected":true,"redacted_fields":1}'::jsonb; end if;
 for k,v in select key,val from jsonb_each(value) e(key,val) loop
  accepted:=false;
  if k in ('attempt','attempt_count','max_attempts','duration_ms','latency_ms','source_count','changed_count','failed_count',
   'retry_count','consecutive_failure_count','schema_version','redacted_fields') and jsonb_typeof(v)='number' then
   n:=(v#>>'{}')::numeric;
   accepted:=n>=0 and n=trunc(n) and n<=case when k in ('duration_ms','latency_ms') then 600000 else 2147483647 end;
  elsif k in ('retryable','sandbox','payload_rejected') and jsonb_typeof(v)='boolean' then accepted:=true;
  elsif jsonb_typeof(v)='string' then
   s:=v#>>'{}';
   if k='status' then accepted:=s in ('healthy','degraded','offline','unknown','queued','running','succeeded','failed','cancelled',
    'review_required','sandbox_delivered','retry_scheduled','investigating','identified','monitoring','resolved');
   elsif k in ('safe_error_code','error_code') then
    accepted:=private.safe_operational_code(s)=s;
   elsif k in ('mode','transport') then accepted:=s in ('sandbox','local','disabled','test');
   elsif k='channel' then accepted:=s in ('email','sms','push');
   elsif k='operation' then accepted:=s in ('claim','dispatch','complete','retry','request','health_check','ingest','review','publish','release_validation');
   elsif k='component_slug' then accepted:=s in ('database','auth','storage','research','ai','document_intelligence','notifications','payments');
   end if;
  end if;
  if accepted then result:=result||jsonb_build_object(k,v); else removed:=removed+1; end if;
 end loop;
 if removed>0 then result:=result||jsonb_build_object('redacted_fields',
  least(2147483647::bigint,removed::bigint+coalesce((result->>'redacted_fields')::bigint,0))); end if;
 return result;
end $$;
revoke all on function private.redact_safe_metadata(jsonb) from public,anon,authenticated;
grant execute on function private.redact_safe_metadata(jsonb) to service_role;

create or replace function private.sanitize_operational_event()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 new.safe_metadata:=private.redact_safe_metadata(new.safe_metadata);
 if new.user_id_hash is not null and new.user_id_hash !~ '^[a-f0-9]{64}$' then new.user_id_hash:=null; end if;
 if new.event_type not in ('ai.request_failed','ai.request_succeeded','research.job_failed','research.job_succeeded',
  'document.processing_failed','document.processing_completed','notification.dispatch_failed','notification.sandbox_delivered',
  'payment.sandbox_event','component.health_alert','component.health_recovered','incident.transition','release.local_check','event.unspecified')
  then new.event_type:='event.unspecified'; end if;
 if not exists(select 1 from public.system_components where slug=new.component_slug) then new.component_slug:='unknown'; end if;
 return new;
end $$;
revoke all on function private.sanitize_operational_event() from public,anon,authenticated;
grant execute on function private.sanitize_operational_event() to service_role;
drop trigger sanitize_operational_events on public.operational_events;
create trigger sanitize_operational_events before insert or update on public.operational_events
 for each row execute function private.sanitize_operational_event();

create table public.incident_events (
 id uuid primary key default gen_random_uuid(),
 incident_id uuid not null references public.incidents(id) on delete cascade,
 actor_id uuid references auth.users(id) on delete set null,
 from_status text check(from_status in ('investigating','identified','monitoring','resolved')),
 to_status text not null check(to_status in ('investigating','identified','monitoring','resolved')),
 occurred_at timestamptz not null default now()
);
create index incident_events_incident_idx on public.incident_events(incident_id,occurred_at);
create index incident_events_actor_idx on public.incident_events(actor_id) where actor_id is not null;
alter table public.incident_events enable row level security;
revoke all on public.incident_events from public,anon,authenticated;
grant select on public.incident_events to authenticated;
grant all on public.incident_events to service_role;
create policy "admins read incident history" on public.incident_events for select to authenticated
 using((select private.has_role(array['admin','super_admin'])));
create policy "service owns incident history" on public.incident_events for all to service_role using(true) with check(true);
-- Prevent re-keying incidents through client updates while retaining form fields.
revoke update on public.incidents from authenticated;
grant update(title,status,severity,component_slug,public_message,internal_safe_notes,opened_by,resolved_by,started_at,resolved_at,updated_at)
 on public.incidents to authenticated;

create function private.attribute_incident_action()
returns trigger language plpgsql security definer set search_path='' as $$
declare actor uuid; prior text;
begin
 if tg_when='AFTER' and tg_op='UPDATE' then
  if new.status is not distinct from old.status then return new; end if;
 end if;
 if coalesce(auth.jwt()->>'role','')='service_role' then actor:=null;
 else
  if tg_when='BEFORE' and tg_op='UPDATE' and coalesce(auth.jwt()->>'role','')='' and
   (to_jsonb(new)-array['opened_by','resolved_by']) is not distinct from (to_jsonb(old)-array['opened_by','resolved_by']) and
   (new.opened_by is null or new.opened_by is not distinct from old.opened_by) and
   (new.resolved_by is null or new.resolved_by is not distinct from old.resolved_by) then return new; end if;
  if auth.uid() is null or not private.has_role(array['admin','super_admin']) then
   raise exception 'forbidden' using errcode='42501'; end if;
  actor:=auth.uid();
 end if;
 if tg_when='AFTER' then
  if tg_op='UPDATE' then prior:=old.status; end if;
  insert into public.incident_events(incident_id,actor_id,from_status,to_status) values(new.id,actor,prior,new.status);
  return new;
 end if;
 if actor is null then return new; end if;
 if tg_op='INSERT' then new.opened_by:=actor; new.started_at:=now();
 else new.opened_by:=old.opened_by; new.started_at:=old.started_at; new.component_slug:=old.component_slug; end if;
 if not exists(select 1 from public.system_components where slug=new.component_slug) then
  raise exception 'unknown_component' using errcode='22023'; end if;
 if new.status='resolved' then
  if tg_op='INSERT' then new.resolved_by:=actor; new.resolved_at:=now();
  elsif old.status<>'resolved' or old.resolved_by is null then new.resolved_by:=actor; new.resolved_at:=now();
  else new.resolved_by:=old.resolved_by; new.resolved_at:=old.resolved_at; end if;
 else new.resolved_by:=null; new.resolved_at:=null; end if;
 new.updated_at:=now();
 return new;
end $$;
revoke all on function private.attribute_incident_action() from public,anon,authenticated;
grant execute on function private.attribute_incident_action() to service_role;
create trigger attribute_incident_action before insert or update on public.incidents
 for each row execute function private.attribute_incident_action();
create trigger audit_incident_action after insert or update of status on public.incidents
 for each row execute function private.attribute_incident_action();

create table private.health_alert_policy (
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 consecutive_samples integer not null default 2 check(consecutive_samples between 1 and 10)
);
insert into private.health_alert_policy(singleton) values(true);
create table private.health_alert_state (
 component_id uuid primary key references public.system_components(id) on delete cascade,
 incident_id uuid references public.incidents(id) on delete set null,
 consecutive_failures integer not null default 0 check(consecutive_failures between 0 and 2147483647),
 last_status text not null default 'unknown' check(last_status in ('healthy','degraded','offline','unknown')),
 updated_at timestamptz not null default now()
);
create index health_alert_incident_idx on private.health_alert_state(incident_id) where incident_id is not null;
alter table private.health_alert_policy enable row level security;
alter table private.health_alert_state enable row level security;
revoke all on private.health_alert_policy,private.health_alert_state from public,anon,authenticated;
grant all on private.health_alert_policy,private.health_alert_state to service_role;
create policy "service owns alert policy" on private.health_alert_policy for all to service_role using(true) with check(true);
create policy "service owns alert state" on private.health_alert_state for all to service_role using(true) with check(true);
insert into public.system_components(slug,display_name,critical) values('payments','Payment sandbox',false) on conflict(slug) do nothing;

create or replace function public.record_component_health(p_component_slug text,p_status text,p_latency_ms integer default null,p_safe_code text default null)
returns void language plpgsql security definer set search_path='' as $$
declare c public.system_components%rowtype; a private.health_alert_state%rowtype;
 policy private.health_alert_policy%rowtype; existing public.incidents%rowtype; code text; sample_severity text;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
 if p_status is null or p_status not in ('healthy','degraded','offline','unknown') or p_latency_ms<0 or p_latency_ms>600000 then
  raise exception 'invalid_health_sample' using errcode='22023'; end if;
 select * into c from public.system_components where slug=p_component_slug and enabled for update;
 if not found then raise exception 'unknown_component' using errcode='22023'; end if;
 code:=private.safe_operational_code(p_safe_code);
 insert into public.component_health_checks(component_id,status,latency_ms,safe_code) values(c.id,p_status,p_latency_ms,code);
 select * into policy from private.health_alert_policy where singleton;
 if not coalesce(policy.enabled,false) then return; end if;
 insert into private.health_alert_state(component_id) values(c.id) on conflict(component_id) do nothing;
 select * into a from private.health_alert_state where component_id=c.id for update;
 select * into existing from public.incidents where id=a.incident_id for update;
 if p_status in ('offline','degraded') then
  a.consecutive_failures:=least(a.consecutive_failures::bigint+1,2147483647)::integer;
  if a.consecutive_failures>=policy.consecutive_samples then
   sample_severity:=case when p_status='offline' and c.critical then 'critical' when p_status='offline' then 'major' else 'minor' end;
   if existing.id is null or existing.status='resolved' then
    insert into public.incidents(title,status,severity,component_slug,public_message,internal_safe_notes)
    values('Component health: '||c.slug,'investigating',sample_severity,c.slug,'A service component is reporting a health issue.',
     'Created by the optional health monitor. Human triage and resolution are required.') returning * into existing;
    a.incident_id:=existing.id;
    insert into public.operational_events(severity,event_type,component_slug,correlation_id,safe_metadata)
    values(case when p_status='offline' then 'error' else 'warning' end,'component.health_alert',c.slug,existing.id,
     jsonb_build_object('status',p_status,'latency_ms',p_latency_ms,'error_code',code,'consecutive_failure_count',a.consecutive_failures));
   else
    update public.incidents set status=case when status='monitoring' then 'investigating' else status end,
     severity=case when public.incidents.severity='critical' or sample_severity='critical' then 'critical'
      when public.incidents.severity='major' or sample_severity='major' then 'major' else 'minor' end,updated_at=now() where id=existing.id;
   end if;
  end if;
 elsif p_status='healthy' then
  a.consecutive_failures:=0;
  if existing.id is not null and existing.status not in ('resolved','monitoring') then
   update public.incidents set status='monitoring',updated_at=now() where id=existing.id;
   insert into public.operational_events(severity,event_type,component_slug,correlation_id,safe_metadata)
    values('info','component.health_recovered',c.slug,existing.id,jsonb_build_object('status','healthy','latency_ms',p_latency_ms));
  end if;
 else a.consecutive_failures:=0; -- Unknown neither recovers nor opens an incident.
 end if;
 update private.health_alert_state set incident_id=a.incident_id,consecutive_failures=a.consecutive_failures,
  last_status=p_status,updated_at=now() where component_id=c.id;
end $$;
alter function public.record_component_health(text,text,integer,text) owner to postgres;
revoke all on function public.record_component_health(text,text,integer,text) from public,anon,authenticated;
grant execute on function public.record_component_health(text,text,integer,text) to service_role;
