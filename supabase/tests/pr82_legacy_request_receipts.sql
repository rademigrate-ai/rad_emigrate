-- No real services or booking slots: transaction-scoped synthetic fixtures only.
begin;
insert into auth.users(id,email) values
 ('f0400000-0000-4000-8000-000000000001','pr82-f04-a@example.invalid'),
 ('f0400000-0000-4000-8000-000000000003','pr82-f04-b@example.invalid');
insert into public.service_catalog(id,slug,category,fulfillment,enabled)
 values('f0400000-0000-4000-8000-000000000002','synthetic-not-a-real-service','other','staffScheduled',true);
-- Existing records are retained; original request input is not reconstructed
-- from mutable historical rows merely to make a retry pass.
insert into public.interview_requests(user_id,notes,idempotency_key)
 values('f0400000-0000-4000-8000-000000000001','SYNTHETIC legacy','pr82-f04-legacy');
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"f0400000-0000-4000-8000-000000000001"}',true);
do $$declare original_id uuid; retry_id uuid;
begin
 select id into original_id from public.submit_booking_request('f0400000-0000-4000-8000-000000000002','SYNTHETIC initial',null,null,null,'pr82-f04-booking');
 select id into retry_id from public.submit_booking_request('f0400000-0000-4000-8000-000000000002','SYNTHETIC initial',null,null,null,'pr82-f04-booking');
 if original_id is distinct from retry_id or original_id is null then raise exception 'booking exact replay receipt changed';end if;
 begin
  perform public.submit_booking_request('f0400000-0000-4000-8000-000000000002','SYNTHETIC changed',null,null,null,'pr82-f04-booking');
  raise exception 'booking acknowledged a different payload with the old receipt';
 exception when sqlstate 'PT409' then null;
 end;
 begin
  perform public.submit_interview_request('SYNTHETIC legacy',null,null,null,'en','pr82-f04-legacy');
  raise exception 'historical original input was silently invented';
 exception when sqlstate 'PT409' then null;
 end;
 if not exists(select 1 from public.submit_interview_request('SYNTHETIC unkeyed')) then
  raise exception 'optional-key legacy compatibility changed';end if;
 begin
  perform public.submit_booking_request('f0400000-0000-4000-8000-000000000002',repeat('x',4001),null,null,null,'pr82-f04-overlong');
  raise exception 'overlong booking input silently truncated';
 exception when invalid_parameter_value then null;
 end;
 select id into original_id from public.submit_interview_request('SYNTHETIC initial',null,null,null,'en','pr82-f04-interview');
 select id into retry_id from public.submit_interview_request('SYNTHETIC initial',null,null,null,'en','pr82-f04-interview');
 if original_id is distinct from retry_id or original_id is null then raise exception 'interview exact replay receipt changed';end if;
 begin
  perform public.submit_interview_request('SYNTHETIC changed',null,null,null,'en','pr82-f04-interview');
  raise exception 'interview acknowledged a different payload with the old receipt';
 exception when sqlstate 'PT409' then null;
 end;
end $$;
do $$declare original_id uuid; retry_id uuid;
begin
 select id into original_id from public.submit_booking_request('f0400000-0000-4000-8000-000000000002','SYNTHETIC instant','2030-01-01T10:00:00Z',null,'UTC','pr82-f04-instant');
 perform set_config('TimeZone','Asia/Tehran',true);
 select id into retry_id from public.submit_booking_request('f0400000-0000-4000-8000-000000000002','SYNTHETIC instant','2030-01-01T13:30:00+03:30',null,'UTC','pr82-f04-instant');
 if original_id is distinct from retry_id then raise exception 'equal instant failed replay after timezone change';end if;
 begin
  perform public.submit_interview_request('SYNTHETIC initial',null,null,null,'fa','pr82-f04-interview');
  raise exception 'interview locale change accepted under the old key';
 exception when sqlstate 'PT409' then null;
 end;
 begin
  perform 1 from private.rad_legacy_request_receipts;
  raise exception 'client can read immutable private receipt inputs';
 exception when insufficient_privilege then null;
 end;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"f0400000-0000-4000-8000-000000000003"}',true);
do $$declare own_id uuid;
begin
 select id into own_id from public.submit_booking_request('f0400000-0000-4000-8000-000000000002','SYNTHETIC other owner',null,null,null,'pr82-f04-booking');
 if not exists(select 1 from public.booking_requests where id=own_id and user_id=auth.uid())
    or (select count(*) from public.booking_requests where idempotency_key='pr82-f04-booking')<>1 then
  raise exception 'booking same key is not scoped to owner';end if;
end $$;
reset role;
select 'PASS: legacy keyed booking/interview replay matches exact body and rejects changed body' as result;
rollback;
