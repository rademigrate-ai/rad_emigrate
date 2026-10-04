-- Project 15: privacy-safe observability, retention, retry and incident records.
begin;

create table public.system_components (
 id uuid primary key default gen_random_uuid(),
 slug text not null unique check (slug ~ '^[a-z0-9_]+$'),
 display_name text not null,
 critical boolean not null default true,
 enabled boolean not null default true,
 created_at timestamptz not null default now()
);
create table public.component_health_checks (
 id bigint generated always as identity primary key,
 component_id uuid not null references public.system_components(id) on delete cascade,
 status text not null check (status in ('healthy','degraded','offline','unknown')),
 latency_ms integer check (latency_ms is null or latency_ms >= 0),
 safe_code text,
 checked_at timestamptz not null default now()
);
create table public.operational_events (
 id bigint generated always as identity primary key,
 severity text not null check (severity in ('debug','info','warning','error','critical')),
 event_type text not null check (event_type ~ '^[a-z0-9_.-]+$'),
 component_slug text not null,
 correlation_id uuid,
 user_id_hash text,
 safe_metadata jsonb not null default '{}'::jsonb,
 occurred_at timestamptz not null default now()
);
create table public.dead_letter_jobs (
 id uuid primary key default gen_random_uuid(),
 source_table text not null check (source_table in ('research_jobs','document_processing_jobs','ai_requests','notifications')),
 source_id uuid not null,
 component_slug text not null,
 safe_error_code text not null,
 attempt_count integer not null check (attempt_count > 0),
 retry_after timestamptz,
 resolved_at timestamptz,
 resolved_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 unique(source_table,source_id)
);
create table public.incidents (
 id uuid primary key default gen_random_uuid(),
 title text not null check (char_length(title) between 1 and 200),
 status text not null default 'investigating' check (status in ('investigating','identified','monitoring','resolved')),
 severity text not null check (severity in ('minor','major','critical')),
 component_slug text not null,
 public_message text check (char_length(public_message) <= 2000),
 internal_safe_notes text check (char_length(internal_safe_notes) <= 5000),
 opened_by uuid references auth.users(id) on delete set null,
 resolved_by uuid references auth.users(id) on delete set null,
 started_at timestamptz not null default now(),
 resolved_at timestamptz,
 updated_at timestamptz not null default now()
);

insert into public.system_components(slug,display_name,critical) values
 ('database','Database',true),('auth','Authentication',true),('storage','Document storage',true),
 ('research','Research ingestion',false),('ai','AI orchestration',false),
 ('document_intelligence','Document intelligence',false),('notifications','Notifications',false);

create index component_health_latest_idx on public.component_health_checks(component_id,checked_at desc);
create index operational_events_time_idx on public.operational_events(occurred_at desc);
create index operational_events_component_idx on public.operational_events(component_slug,severity,occurred_at desc);
create index operational_events_correlation_idx on public.operational_events(correlation_id) where correlation_id is not null;
create index dead_letter_open_idx on public.dead_letter_jobs(component_slug,created_at desc) where resolved_at is null;
create index dead_letter_resolver_idx on public.dead_letter_jobs(resolved_by);
create index incidents_status_idx on public.incidents(status,severity,started_at desc);
create index incidents_opened_by_idx on public.incidents(opened_by);
create index incidents_resolved_by_idx on public.incidents(resolved_by);

alter table public.system_components enable row level security;
alter table public.component_health_checks enable row level security;
alter table public.operational_events enable row level security;
alter table public.dead_letter_jobs enable row level security;
alter table public.incidents enable row level security;
revoke all on table public.system_components,public.component_health_checks,public.operational_events,
 public.dead_letter_jobs,public.incidents from anon,authenticated;
grant select on table public.system_components,public.component_health_checks,public.operational_events,
 public.dead_letter_jobs,public.incidents to authenticated;
grant insert,update on public.incidents to authenticated;
grant all privileges on table public.system_components,public.component_health_checks,public.operational_events,
 public.dead_letter_jobs,public.incidents to service_role;
grant usage,select on sequence public.component_health_checks_id_seq,public.operational_events_id_seq to service_role;

create policy "admins read components" on public.system_components for select to authenticated using((select private.has_role(array['admin','super_admin'])));
create policy "admins read health" on public.component_health_checks for select to authenticated using((select private.has_role(array['admin','super_admin'])));
create policy "admins read operational events" on public.operational_events for select to authenticated using((select private.has_role(array['admin','super_admin'])));
create policy "admins read dead letters" on public.dead_letter_jobs for select to authenticated using((select private.has_role(array['admin','super_admin'])));
create policy "admins manage incidents" on public.incidents for all to authenticated
 using((select private.has_role(array['admin','super_admin']))) with check((select private.has_role(array['admin','super_admin'])));
create policy "service writes components" on public.system_components for all to service_role using(true) with check(true);
create policy "service writes health" on public.component_health_checks for all to service_role using(true) with check(true);
create policy "service writes events" on public.operational_events for all to service_role using(true) with check(true);
create policy "service writes dead letters" on public.dead_letter_jobs for all to service_role using(true) with check(true);
create policy "service writes incidents" on public.incidents for all to service_role using(true) with check(true);

create or replace function private.redact_safe_metadata(value jsonb)
returns jsonb language sql immutable set search_path='' as $$
 select coalesce(jsonb_object_agg(key,
  case when lower(key) ~ '(password|secret|token|api.?key|authorization|cookie|email|phone|prompt|content|document|file|text)'
   then '"[redacted]"'::jsonb else
   case when jsonb_typeof(val)='string' and length(val#>>'{}')>500 then to_jsonb(left(val#>>'{}',500)||'…') else val end
  end),'{}'::jsonb)
 from jsonb_each(coalesce(value,'{}'::jsonb)) as e(key,val);
$$;
revoke all on function private.redact_safe_metadata(jsonb) from public,anon,authenticated;

create or replace function private.sanitize_operational_event()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 new.safe_metadata:=private.redact_safe_metadata(new.safe_metadata);
 if new.user_id_hash is not null and new.user_id_hash !~ '^[a-f0-9]{64}$' then new.user_id_hash:=null; end if;
 return new;
end $$;
alter function private.sanitize_operational_event() owner to postgres;
revoke all on function private.sanitize_operational_event() from public,anon,authenticated;
create trigger sanitize_operational_events before insert or update of safe_metadata,user_id_hash on public.operational_events
 for each row execute function private.sanitize_operational_event();

create or replace function public.record_component_health(p_component_slug text,p_status text,p_latency_ms integer default null,p_safe_code text default null)
returns void language plpgsql security definer set search_path='' as $$
begin
 if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
 insert into public.component_health_checks(component_id,status,latency_ms,safe_code)
 select id,p_status,p_latency_ms,left(p_safe_code,100) from public.system_components where slug=p_component_slug and enabled;
end $$;
alter function public.record_component_health(text,text,integer,text) owner to postgres;
revoke all on function public.record_component_health(text,text,integer,text) from public,anon,authenticated;
grant execute on function public.record_component_health(text,text,integer,text) to service_role;

create or replace function private.observability_retention()
returns void language plpgsql security definer set search_path='' as $$
begin
 delete from public.component_health_checks where checked_at < now()-interval '90 days';
 delete from public.operational_events where occurred_at < now()-interval '30 days' and severity not in ('critical');
 delete from public.operational_events where occurred_at < now()-interval '365 days';
 update public.research_jobs set status='failed',finished_at=now(),safe_error='Worker lease expired',error_code='lease_expired'
  where status='running' and started_at<now()-interval '20 minutes';
 update public.document_processing_jobs set status='failed',finished_at=now(),safe_error_code='lease_expired'
  where status='running' and started_at<now()-interval '10 minutes';
end $$;
alter function private.observability_retention() owner to postgres;
revoke all on function private.observability_retention() from public,anon,authenticated;

select cron.schedule('rad-observability-retention','41 2 * * *',$$select private.observability_retention();$$);

commit;

