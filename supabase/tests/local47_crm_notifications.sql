-- Disposable loopback database only. Synthetic users and every write roll back.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email,raw_user_meta_data) values
 ('47000000-0000-4000-8000-000000000001','local47-owner@example.invalid','{}'),
 ('47000000-0000-4000-8000-000000000002','local47-other@example.invalid','{}'),
 ('47000000-0000-4000-8000-000000000003','local47-admin@example.invalid','{}');
update public.profiles set role='admin' where id='47000000-0000-4000-8000-000000000003';

select set_config('request.jwt.claims','{"role":"authenticated","sub":"47000000-0000-4000-8000-000000000001"}',true);
select set_config('request.jwt.claim.sub','47000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select set_config('rad.test_consultation',public.submit_consultation_request('Synthetic CRM','Synthetic local-only request',null)::text,true);
do $$ begin
  assert (select count(*) from public.consultation_request_events where consultation_id=current_setting('rad.test_consultation')::uuid)=1;
  assert not has_column_privilege('authenticated','public.consultation_request_events','actor_id','SELECT');
  begin
    perform public.transition_admin_consultation(current_setting('rad.test_consultation')::uuid,'contacted',1,null);
    raise exception 'ordinary user transitioned CRM';
  exception when insufficient_privilege then null; end;
  begin
    perform public.assign_admin_consultation(current_setting('rad.test_consultation')::uuid,null,1);
    raise exception 'ordinary user assigned CRM';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

select set_config('request.jwt.claims','{"role":"authenticated","sub":"47000000-0000-4000-8000-000000000002"}',true);
select set_config('request.jwt.claim.sub','47000000-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ begin
  assert (select count(*) from public.consultation_request_events where consultation_id=current_setting('rad.test_consultation')::uuid)=0, 'cross-owner history exposed';
end $$;
reset role;

select set_config('request.jwt.claims','{"role":"authenticated","sub":"47000000-0000-4000-8000-000000000003"}',true);
select set_config('request.jwt.claim.sub','47000000-0000-4000-8000-000000000003',true);
set local role authenticated;
do $$ declare v jsonb; begin
  v:=public.transition_admin_consultation(current_setting('rad.test_consultation')::uuid,'in_review',1,'Internal synthetic note');
  assert (v->>'revision')::int=2;
  begin
    perform public.transition_admin_consultation(current_setting('rad.test_consultation')::uuid,'closed',1,null);
    raise exception 'stale revision accepted';
  exception when serialization_failure then null; end;
  begin
    perform public.assign_admin_consultation(current_setting('rad.test_consultation')::uuid,'47000000-0000-4000-8000-000000000002',2);
    raise exception 'non-admin assignee accepted';
  exception when invalid_parameter_value then null; end;
  v:=public.assign_admin_consultation(current_setting('rad.test_consultation')::uuid,'47000000-0000-4000-8000-000000000003',2);
  assert (v->>'revision')::int=3 and (v->>'assigned')::boolean;
  -- Existing client RPC remains compatible and audited by the new trigger.
  perform public.update_admin_consultation(current_setting('rad.test_consultation')::uuid,'contacted','Internal synthetic note');
  assert (select count(*) from public.consultation_request_events where consultation_id=current_setting('rad.test_consultation')::uuid)=4;
end $$;
reset role;

insert into public.notifications(id,user_id,type,title,body) values
 ('47000000-0000-4000-9000-000000000001','47000000-0000-4000-8000-000000000001','system','Synthetic notice','No external recipient'),
 ('47000000-0000-4000-9000-000000000002','47000000-0000-4000-8000-000000000001','system','Synthetic retry','No external recipient'),
 ('47000000-0000-4000-9000-000000000003','47000000-0000-4000-8000-000000000001','system','Synthetic revocation','No external recipient');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"47000000-0000-4000-8000-000000000001"}',true);
select set_config('request.jwt.claim.sub','47000000-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ declare v jsonb; begin
  v:=public.queue_notification_delivery('47000000-0000-4000-9000-000000000001','email');
  assert v->>'reason'='preference_disabled';
end $$;
-- Current owner API uses revision-controlled full replacement.
do $$ declare prefs jsonb;begin
 prefs:=public.get_notification_preferences('{}')->'data';
 perform public.save_notification_preferences(jsonb_build_object('expected_revision',prefs->'revision','preferences',(prefs-'revision'-'updated_at')||'{"email_enabled":true,"time_zone":"Asia/Tehran"}','request_key',gen_random_uuid()));
end $$;

do $$ declare a jsonb; b jsonb; begin
  a:=public.queue_notification_delivery('47000000-0000-4000-9000-000000000001','email');
  b:=public.queue_notification_delivery('47000000-0000-4000-9000-000000000001','email');
  assert a->>'delivery_id'=b->>'delivery_id' and a->>'transport'='sandbox';
  assert (select count(*) from public.notification_deliveries)=1;
  begin perform public.claim_sandbox_notification(); raise exception 'owner claimed service-only outbox';
  exception when insufficient_privilege then null; end;
  begin
    perform public.save_notification_preferences(jsonb_build_object('expected_revision',1,'preferences',((public.get_notification_preferences('{}')->'data')-'revision'-'updated_at')||'{"time_zone":"not/a/timezone"}','request_key',gen_random_uuid()));
    raise exception 'invalid time zone accepted';
  exception when sqlstate 'PT422' then null; end;
end $$;
reset role;

select set_config('request.jwt.claims','{"role":"authenticated","sub":"47000000-0000-4000-8000-000000000002"}',true);
select set_config('request.jwt.claim.sub','47000000-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ begin
  assert (select count(*) from public.notification_deliveries)=0;
  begin perform public.queue_notification_delivery('47000000-0000-4000-9000-000000000001','email');
    raise exception 'cross-owner notification enqueue';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Explicit local-time quiet hours, including a midnight wrap, without a clock mock.
update public.notification_preferences set quiet_hours_start='22:00',quiet_hours_end='07:00'
 where user_id='47000000-0000-4000-8000-000000000001';
do $$ begin
  assert private.notification_due_at('47000000-0000-4000-8000-000000000001','2026-10-18T20:30:00Z')='2026-10-19T03:30:00Z'::timestamptz;
  assert private.notification_due_at('47000000-0000-4000-8000-000000000001','2026-10-18T10:30:00Z')='2026-10-18T10:30:00Z'::timestamptz;
end $$;
update public.notification_preferences set quiet_hours_start=null,quiet_hours_end=null
 where user_id='47000000-0000-4000-8000-000000000001';

select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.sub','',true);
set local role service_role;
do $$ declare d public.notification_deliveries%rowtype; begin
  select * into d from public.claim_sandbox_notification();
  assert d.attempts=1 and d.status='processing';
  assert (select count(*) from public.claim_sandbox_notification())=0, 'double lease';
  assert not public.finish_sandbox_notification(d.id,gen_random_uuid(),true), 'forged lease acknowledged';
  assert public.finish_sandbox_notification(d.id,d.lease_token,true);
  assert not public.finish_sandbox_notification(d.id,d.lease_token,true), 'replayed ack';
  assert (select status from public.notification_deliveries where id=d.id)='sandbox_delivered';
end $$;
select public.queue_notification_delivery('47000000-0000-4000-9000-000000000002','email');
do $$ declare d public.notification_deliveries%rowtype; i int; begin
  for i in 1..3 loop
    update public.notification_deliveries set available_at=now()-interval '1 minute' where notification_id='47000000-0000-4000-9000-000000000002';
    select * into d from public.claim_sandbox_notification();
    assert d.attempts=i;
    assert public.finish_sandbox_notification(d.id,d.lease_token,false);
  end loop;
  assert (select status from public.notification_deliveries where id=d.id)='failed';
  assert (select count(*) from public.claim_sandbox_notification())=0;
end $$;
select public.queue_notification_delivery('47000000-0000-4000-9000-000000000003','email');
do $$ declare d public.notification_deliveries%rowtype; begin
  select * into d from public.claim_sandbox_notification();
  update public.notification_preferences set email_enabled=false where user_id=d.user_id;
  assert not public.finish_sandbox_notification(d.id,d.lease_token,true), 'revoked opt-in acknowledged';
  assert (select status from public.notification_deliveries where id=d.id)='cancelled';
end $$;
reset role;

do $$ begin
  assert not has_function_privilege('anon','public.transition_admin_consultation(uuid,text,integer,text)','EXECUTE');
  assert not has_function_privilege('authenticated','public.finish_sandbox_notification(uuid,uuid,boolean)','EXECUTE');
  assert not has_column_privilege('authenticated','public.notification_deliveries','lease_token','SELECT');
  assert not has_table_privilege('authenticated','public.consultation_request_events','INSERT');
  assert not has_table_privilege('authenticated','public.notification_deliveries','UPDATE');
  raise notice 'PASS: local CRM revision/history/privacy and notification consent/quiet-hours/lease/retry/role regressions';
end $$;
rollback;
