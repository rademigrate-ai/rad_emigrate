-- Local synthetic incident rehearsal. Everything, including policy enablement, rolls back.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email,raw_user_meta_data) values
 ('47200000-0000-4000-8000-000000000001','monitor-admin@example.invalid','{}'),
 ('47200000-0000-4000-8000-000000000002','monitor-user@example.invalid','{}');
update public.profiles set role='admin' where id='47200000-0000-4000-8000-000000000001';

do $$ declare sanitized jsonb; begin
 sanitized:=private.redact_safe_metadata('{"diagnostic":{"password":"NESTED_CANARY"},"status":[{"secret":"ARRAY_CANARY"}],"person@example.invalid":"KEY_CANARY","latency_ms":17,"retryable":true,"attempt_count":2,"safe_error_code":"provider_timeout"}');
 assert sanitized->>'latency_ms'='17' and sanitized->>'retryable'='true' and sanitized->>'attempt_count'='2';
 assert sanitized->>'safe_error_code'='provider_timeout';
 assert sanitized::text not like '%CANARY%' and sanitized::text not like '%example.invalid%';
 assert not (sanitized ? 'diagnostic') and not (sanitized ? 'status');
 assert private.redact_safe_metadata(sanitized)=sanitized,'sanitizing already-safe metrics changed them';
 assert private.redact_safe_metadata('null')->>'payload_rejected'='true';
 assert private.redact_safe_metadata('[]')->>'payload_rejected'='true';
 assert private.redact_safe_metadata(jsonb_build_object('status',repeat('X',17000)))->>'payload_rejected'='true';
 assert private.redact_safe_metadata('{"attempt_count":"2","latency_ms":-1,"failed_count":1.2,"mode":"RAW_CANARY"}')='{"redacted_fields":4}'::jsonb;
 assert private.safe_operational_code('secret_CANARY')='unspecified';
end $$;
insert into public.operational_events(severity,event_type,component_slug,user_id_hash,safe_metadata)
 values('error','raw_label_canary','raw_component_canary','person@example.invalid',
 '{"debug":{"nested_password":"NESTED_CANARY"},"status":"offline","latency_ms":5}');
do $$ declare event public.operational_events%rowtype; begin
 select * into event from public.operational_events where event_type='event.unspecified' order by id desc limit 1;
 assert event.component_slug='unknown' and event.user_id_hash is null;
 assert event.safe_metadata->>'status'='offline' and event.safe_metadata::text not like '%CANARY%';
 update public.operational_events set event_type='raw_update_canary' where id=event.id;
 assert (select event_type from public.operational_events where id=event.id)='event.unspecified','label-only update bypassed sanitizer';
end $$;

do $$ declare before_count bigint; begin
 assert (select enabled=false from private.health_alert_policy where singleton),'alert policy must default off';
 select count(*) into before_count from public.incidents;
 perform public.record_component_health('database','offline',10,'raw_secret_canary');
 assert (select count(*) from public.incidents)=before_count,'disabled policy opened incident';
 assert (select h.safe_code from public.component_health_checks h join public.system_components c on c.id=h.component_id
  where c.slug='database' order by h.id desc limit 1)='unspecified';
 begin perform public.record_component_health('does_not_exist','offline',1,null); raise exception 'unknown component accepted';
 exception when invalid_parameter_value then null; end;
 begin perform public.record_component_health('database','bad_status',1,null); raise exception 'bad status accepted';
 exception when invalid_parameter_value then null; end;
 begin perform public.record_component_health('database','healthy',600001,null); raise exception 'unbounded latency accepted';
 exception when invalid_parameter_value then null; end;
end $$;
update private.health_alert_policy set enabled=true,consecutive_samples=2;
select public.record_component_health('database','offline',9,'synthetic_failure');
do $$ begin assert not exists(select 1 from private.health_alert_state where incident_id is not null), 'first sample opened incident'; end $$;
select public.record_component_health('database','offline',11,'synthetic_failure');
select set_config('rad.monitor_incident',(select incident_id::text from private.health_alert_state s join public.system_components c on c.id=s.component_id where c.slug='database'),true);
select public.record_component_health('database','degraded',12,'synthetic_failure');
do $$ begin
 assert (select status='investigating' and severity='critical' and opened_by is null from public.incidents where id=current_setting('rad.monitor_incident')::uuid);
 assert (select count(*) from public.operational_events where correlation_id=current_setting('rad.monitor_incident')::uuid and event_type='component.health_alert')=1,'duplicate health alert';
 assert (select count(*) from public.incident_events where incident_id=current_setting('rad.monitor_incident')::uuid)=1;
end $$;
select public.record_component_health('database','healthy',4,'ok');
select public.record_component_health('database','healthy',4,'ok');
do $$ begin
 assert (select status='monitoring' and resolved_at is null from public.incidents where id=current_setting('rad.monitor_incident')::uuid),'healthy sample silently resolved incident';
 assert (select count(*) from public.operational_events where correlation_id=current_setting('rad.monitor_incident')::uuid and event_type='component.health_recovered')=1;
end $$;

select set_config('request.jwt.claims','{"role":"authenticated","sub":"47200000-0000-4000-8000-000000000002"}',true);
select set_config('request.jwt.claim.sub','47200000-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ begin
 assert (select count(*) from public.incidents)=0;
 assert (select count(*) from public.incident_events)=0;
 assert (select count(*) from public.operational_events)=0;
 begin perform public.record_component_health('database','healthy',1,'ok'); raise exception 'ordinary user wrote health';
 exception when insufficient_privilege then null; end;
 begin insert into public.incidents(title,severity,component_slug) values('Unauthorized','minor','database');
  raise exception 'ordinary user created incident'; exception when insufficient_privilege then null; end;
 begin perform * from private.health_alert_policy; raise exception 'ordinary user read private policy';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

select set_config('request.jwt.claims','{"role":"authenticated","sub":"47200000-0000-4000-8000-000000000001"}',true);
select set_config('request.jwt.claim.sub','47200000-0000-4000-8000-000000000001',true);
set local role authenticated;
update public.incidents set status='resolved',resolved_by='47200000-0000-4000-8000-000000000002',resolved_at='2000-01-01',
 opened_by='47200000-0000-4000-8000-000000000002',started_at='2000-01-01'
 where id=current_setting('rad.monitor_incident')::uuid;
do $$ begin
 assert (select status='resolved' and opened_by is null and resolved_by=auth.uid() and resolved_at>now()-interval '1 minute'
  and started_at>now()-interval '1 minute' from public.incidents where id=current_setting('rad.monitor_incident')::uuid);
 assert (select actor_id=auth.uid() from public.incident_events where incident_id=current_setting('rad.monitor_incident')::uuid and to_status='resolved');
 begin update public.incident_events set actor_id='47200000-0000-4000-8000-000000000002'; raise exception 'history tampered';
 exception when insufficient_privilege then null; end;
end $$;
insert into public.incidents(id,title,status,severity,component_slug,opened_by,resolved_by,started_at)
 values('47200000-0000-4000-8000-000000000003','Human synthetic incident','investigating','minor','auth',
 '47200000-0000-4000-8000-000000000002','47200000-0000-4000-8000-000000000002','2000-01-01');
do $$ begin
 assert (select opened_by=auth.uid() and resolved_by is null and started_at>now()-interval '1 minute'
  from public.incidents where id='47200000-0000-4000-8000-000000000003');
end $$;
reset role;
-- Simulate Auth's internal reviewer-reference cleanup without a user JWT.
select set_config('request.jwt.claims','{}',true);
select set_config('request.jwt.claim.sub','',true);
delete from auth.users where id='47200000-0000-4000-8000-000000000001';
do $$ begin
 assert (select opened_by is null from public.incidents where id='47200000-0000-4000-8000-000000000003');
 assert not exists(select 1 from public.incident_events where actor_id='47200000-0000-4000-8000-000000000001');
end $$;
rollback;
