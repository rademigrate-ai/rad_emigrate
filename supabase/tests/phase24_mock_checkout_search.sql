begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
create function pg_temp.denied(q text, expected text) returns void language plpgsql as $$
begin
  begin execute q; exception when others then
    if sqlstate=expected then return; end if;
    raise;
  end;
  raise exception 'expected rejection %',expected;
end $$;
grant execute on function pg_temp.denied(text,text) to anon,authenticated,service_role;
create temp table fixture(owner_id uuid,other_id uuid,admin_id uuid,request_key uuid,order_id uuid,ends timestamptz);
insert into fixture values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),null,null);
grant select,update on fixture to authenticated,service_role;
insert into auth.users(id,email,raw_user_meta_data)
  select u,u::text||'@example.invalid','{}'::jsonb from fixture,
    lateral unnest(array[owner_id,other_id,admin_id]) u;
update public.profiles set role='admin' where id=(select admin_id from fixture);
update private.payment_sandbox_config set enabled=true;
insert into public.consultation_requests(user_id,topic,message) select owner_id,'Literal % topic','Unique mock search' from fixture;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_id,'role','authenticated')::text,true) from fixture;
set local role authenticated;
do $$ declare a jsonb; b jsonb; begin
  a:=public.create_mock_checkout((select request_key from fixture));
  b:=public.create_mock_checkout((select request_key from fixture));
  assert a=b and a->>'mode'='mock' and a->>'currency'='TST';
  assert not (a->>'mock_access_active')::boolean and not (a->>'canonical_paid_access')::boolean;
  update fixture set order_id=(a->>'order_id')::uuid,ends=(a->>'period_end')::timestamptz;
end $$;
select pg_temp.denied('select * from private.mock_checkout_orders','42501');
select pg_temp.denied('select public.search_admin_consultations()','42501');
select set_config('request.jwt.claims',jsonb_build_object('sub',other_id,'role','authenticated')::text,true) from fixture;
select pg_temp.denied(format('select public.get_mock_checkout(%L)',order_id),'PT404') from fixture;
select pg_temp.denied(format('select public.request_mock_checkout_cancellation(%L)',order_id),'PT404') from fixture;
select set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true) from fixture;
do $$ begin
  assert jsonb_array_length(public.search_admin_consultations('%'))=1;
  assert jsonb_array_length(public.search_admin_consultations('_'))=0;
  assert jsonb_array_length(public.search_admin_consultations('Unique mock','closed'))=0;
  assert jsonb_array_length(public.search_admin_consultations('Unique mock','submitted',1,0))=1;
  assert jsonb_array_length(public.search_admin_consultations('Unique mock','submitted',1,1))=0;
end $$;
select pg_temp.denied('select public.search_admin_consultations('''',null,101,0)','22023');
select pg_temp.denied('select public.search_admin_consultations('''',''bad'')','22023');
select pg_temp.denied(format('select public.get_mock_checkout(%L)',order_id),'PT404') from fixture;
reset role;
create function pg_temp.event_for(oid uuid,uid uuid,ends timestamptz,kind text,seq integer,amount integer) returns jsonb
language sql as $$ select jsonb_build_object('mode','sandbox','event_id','fixture-'||gen_random_uuid(),
  'subscription_id','mock:'||oid,'user_id',uid,'type',kind,'sequence',seq,'amount_minor',amount,
  'currency','TST','occurred_at',now(),'period_end',ends) $$;
grant execute on function pg_temp.event_for(uuid,uuid,timestamptz,text,integer,integer) to service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select pg_temp.denied(format('select public.apply_sandbox_payment_event(%L::jsonb,%L)',
  pg_temp.event_for(order_id,other_id,ends,'payment_succeeded',1,100),repeat('a',64)),'22023') from fixture;
select pg_temp.denied(format('select public.apply_sandbox_payment_event(%L::jsonb,%L)',
  pg_temp.event_for(order_id,owner_id,ends,'payment_succeeded',1,99),repeat('a',64)),'22023') from fixture;
select pg_temp.denied(format('select public.apply_sandbox_payment_event(%L::jsonb,%L)',
  pg_temp.event_for(order_id,owner_id,ends+interval '1 day','payment_succeeded',1,100),repeat('a',64)),'22023') from fixture;
select pg_temp.denied(format('select public.apply_sandbox_payment_event(%L::jsonb,%L)',
  pg_temp.event_for(order_id,owner_id,ends,'payment_refunded',1,100),repeat('a',64)),'22023') from fixture;
select public.apply_sandbox_payment_event(pg_temp.event_for(order_id,owner_id,ends,'payment_succeeded',1,100),repeat('a',64)) from fixture;
select pg_temp.denied(format('select public.apply_sandbox_payment_event(%L::jsonb,%L)',
  pg_temp.event_for(order_id,owner_id,ends,'payment_succeeded',2,100),repeat('a',64)),'22023') from fixture;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_id,'role','authenticated')::text,true) from fixture;
set local role authenticated;
do $$ declare a jsonb; begin
  a:=public.get_mock_checkout((select order_id from fixture)); assert (a->>'mock_access_active')::boolean;
  a:=public.request_mock_checkout_cancellation((select order_id from fixture));
  assert (a->>'cancellation_requested')::boolean and (a->>'mock_access_active')::boolean;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select public.apply_sandbox_payment_event(pg_temp.event_for(order_id,owner_id,ends,'subscription_cancelled',2,0),repeat('b',64)) from fixture;
select public.apply_sandbox_payment_event(pg_temp.event_for(order_id,owner_id,ends,'payment_refunded',3,100),repeat('c',64)) from fixture;
select pg_temp.denied(format('select public.apply_sandbox_payment_event(%L::jsonb,%L)',
  pg_temp.event_for(order_id,owner_id,ends,'subscription_cancelled',4,0),repeat('a',64)),'22023') from fixture;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_id,'role','authenticated')::text,true) from fixture;
set local role authenticated;
do $$ declare a jsonb; begin
  a:=public.get_mock_checkout((select order_id from fixture));
  assert a->>'status'='refunded' and not (a->>'mock_access_active')::boolean;
  a:=public.create_mock_checkout(gen_random_uuid());
  a:=public.request_mock_checkout_cancellation((a->>'order_id')::uuid); assert a->>'status'='cancelled';
  update fixture set order_id=(public.create_mock_checkout(gen_random_uuid())->>'order_id')::uuid;
end $$;
reset role;
update private.mock_checkout_orders set expires_at=now()-interval '1 second' where id=(select order_id from fixture);
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select pg_temp.denied(format('select public.apply_sandbox_payment_event(%L::jsonb,%L)',
  pg_temp.event_for(order_id,owner_id,ends,'payment_succeeded',1,100),repeat('a',64)),'22023') from fixture;
reset role;
update private.payment_sandbox_config set enabled=false;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_id,'role','authenticated')::text,true) from fixture;
set local role authenticated;
select pg_temp.denied('select public.create_mock_checkout(gen_random_uuid())','PT503');
set local role anon;
select pg_temp.denied('select public.create_mock_checkout(gen_random_uuid())','42501');
reset role;
select 'PASS mock checkout creation/binding/cancellation/refund/expiry/owner isolation and literal CRM search';
rollback;
