-- Disposable full-Supabase regression; never run against hosted projects.

begin;
do $signature$
begin
 if (select proargnames from pg_proc where oid='public.submit_rad_appointment(text,timestamptz,timestamptz,text,text,uuid)'::regprocedure)
   is distinct from array['p_title','p_start_utc','p_end_utc','p_time_zone','p_notes','p_idempotency_key'] then
  raise exception 'submit named-argument contract drift'; end if;
 if (select proargnames from pg_proc where oid='public.reschedule_rad_appointment(uuid,timestamptz,timestamptz,text,text)'::regprocedure)
   is distinct from array['p_appointment_id','p_start_utc','p_end_utc','p_time_zone','p_notes'] then
  raise exception 'reschedule named-argument contract drift'; end if;
 if (select proargnames from pg_proc where oid='public.cancel_rad_appointment(uuid,text)'::regprocedure)
   is distinct from array['p_appointment_id','p_reason'] then
  raise exception 'cancel named-argument contract drift'; end if;
end $signature$;
insert into auth.users(id,email) values
 ('a8200000-0000-4000-8000-000000000002','pr82-a@example.invalid'),
 ('a8200000-0000-4000-8000-000000000003','pr82-b@example.invalid');
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a8200000-0000-4000-8000-000000000002"}',true);
do $test$
declare r jsonb;r2 jsonb;id uuid;key uuid:=gen_random_uuid();n integer;
begin
 select * into r from public.submit_rad_appointment('SYNTHETIC request only','2027-01-01T00:00:00Z',null,null,'SYNTHETIC notes',key);
 id:=(r->>'id')::uuid;
 if r->>'title'<>'SYNTHETIC request only' or r->>'status'<>'requested' or r->>'kind'<>'radSession' or r->>'user_id'<>'a8200000-0000-4000-8000-000000000002' then raise exception 'receipt contract';end if;
 select * into r2 from public.submit_rad_appointment('SYNTHETIC request only','2027-01-01T00:00:00Z',null,null,'SYNTHETIC notes',key);
 if r<>r2 then raise exception 'same-key retry changed receipt';end if;
 begin perform public.submit_rad_appointment('CHANGED','2027-01-01T00:00:00Z',null,null,'SYNTHETIC notes',key);raise exception 'changed-body replay accepted';exception when sqlstate 'PT409' then null;end;
 select count(*) into n from public.list_rad_appointments();if n<>1 then raise exception 'own list';end if;
 perform set_config('request.jwt.claims','{"role":"authenticated","sub":"a8200000-0000-4000-8000-000000000003"}',true);
 select count(*) into n from public.list_rad_appointments();if n<>0 then raise exception 'cross-owner list leak';end if;
 begin perform public.cancel_rad_appointment(id,'SYNTHETIC cancellation');raise exception 'cross-owner cancel';exception when sqlstate 'P0002' then null;end;
 begin perform public.reschedule_rad_appointment(id,'2027-01-02',null,null,'SYNTHETIC');raise exception 'cross-owner reschedule';exception when sqlstate 'P0002' then null;end;
 perform set_config('request.jwt.claims','{"role":"authenticated","sub":"a8200000-0000-4000-8000-000000000002"}',true);
 select * into r from public.reschedule_rad_appointment(id,'2027-01-02',null,null,'SYNTHETIC changed notes');
 if r->>'status'<>'rescheduled' or r->>'notes'<>'SYNTHETIC changed notes' then raise exception 'reschedule receipt';end if;
 select * into r from public.cancel_rad_appointment(id,'SYNTHETIC cancellation');
 if r->>'status'<>'cancelled' then raise exception 'cancel receipt';end if;
 if r->>'cancellation_reason'<>'SYNTHETIC cancellation' then raise exception 'cancel reason receipt';end if;
 begin perform public.reschedule_rad_appointment(id,'2027-01-03',null,null,'SYNTHETIC');raise exception 'cancelled rescheduled';exception when sqlstate '22023' then null;end;
 begin update public.interview_requests set status='confirmed' where public.interview_requests.id=(r->>'id')::uuid;raise exception 'direct status escalation';exception when insufficient_privilege then null;end;
 begin perform public.submit_rad_appointment('SYNTHETIC',null,null,null,'SYNTHETIC',gen_random_uuid());raise exception 'null start accepted';exception when sqlstate '22023' then null;end;
 begin perform public.submit_rad_appointment('SYNTHETIC','infinity',null,null,'SYNTHETIC',gen_random_uuid());raise exception 'infinite start accepted';exception when sqlstate '22023' then null;end;
 begin perform public.submit_rad_appointment('SYNTHETIC','2030-01-02','2030-01-01',null,'SYNTHETIC',gen_random_uuid());raise exception 'reversed window accepted';exception when sqlstate '22023' then null;end;
 begin perform public.submit_rad_appointment('SYNTHETIC','2030-01-02',null,null,'SYNTHETIC',null);raise exception 'null key accepted';exception when sqlstate '22023' then null;end;
 begin perform public.submit_rad_appointment('','2030-01-02',null,null,'SYNTHETIC',gen_random_uuid());raise exception 'empty title accepted';exception when sqlstate '22023' then null;end;
 begin perform public.cancel_rad_appointment(id,'');raise exception 'empty reason accepted';exception when sqlstate '22023' then null;end;
end $test$;
reset role;
do $$begin
 if has_function_privilege('anon','public.submit_rad_appointment(text,timestamptz,timestamptz,text,text,uuid)','EXECUTE') or has_function_privilege('service_role','public.submit_rad_appointment(text,timestamptz,timestamptz,text,text,uuid)','EXECUTE') then raise exception 'incorrect function ACL';end if;
 if not exists(select 1 from public.interview_requests where cancellation_reason='SYNTHETIC cancellation' and notes='SYNTHETIC changed notes') then raise exception 'persisted cancellation missing';end if;
end $$;
rollback;
select 'PASS: appointment positive/negative/retry/owner/state assertions; transaction rolled back';
