-- Synthetic local payment sandbox. No financial account or real entitlement writes.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.sub','',true);
insert into auth.users(id,email,raw_user_meta_data) values
 ('47000000-0000-4000-8100-000000000001','local47-payment-owner@example.invalid','{}'),
 ('47000000-0000-4000-8100-000000000002','local47-payment-other@example.invalid','{}');
select set_config('rad.sandbox_entitlement_hash',
 (select md5(coalesce(jsonb_agg(to_jsonb(e) order by e.id)::text,'[]')) from public.ai_entitlements e),true);

create function pg_temp.payment_event(p_id text,p_sequence int,p_type text default 'payment_succeeded',p_subscription text default 'synthetic-subscription')
returns jsonb language sql as $$
 select jsonb_build_object('mode','sandbox','event_id',p_id,'subscription_id',p_subscription,
   'user_id','47000000-0000-4000-8100-000000000001','type',p_type,'sequence',p_sequence,
   'amount_minor',case when p_type='subscription_cancelled' then 0 else 100 end,'currency','TST',
   'occurred_at','2026-10-18T00:00:00Z','period_end','2026-11-18T00:00:00Z')
$$;
-- Fixture hashes are stable 64-character test digests. The HTTP layer separately
-- verifies the raw-body HMAC and computes the canonical SHA-256.
do $$ begin
  begin
    perform public.apply_sandbox_payment_event(pg_temp.payment_event('disabled',1),repeat('a',64));
    raise exception 'sandbox enabled by default';
  exception when object_not_in_prerequisite_state then null; end;
end $$;
update private.payment_sandbox_config set enabled=true;

set local role service_role;
do $$ declare v jsonb; payload jsonb; begin
  payload:=pg_temp.payment_event('paid-one',1);
  v:=public.apply_sandbox_payment_event(payload,repeat('a',64));
  assert v->>'decision'='applied' and not (v->>'duplicate')::boolean;
  v:=public.apply_sandbox_payment_event(payload,repeat('a',64));
  assert (v->>'duplicate')::boolean;
  assert (select count(*) from public.sandbox_payment_events where event_id='paid-one')=1;
  begin
    perform public.apply_sandbox_payment_event(payload||'{"amount_minor":101}',repeat('a',64));
    raise exception 'same event id accepted changed financial data';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.apply_sandbox_payment_event(pg_temp.payment_event('owner-forgery',2)||'{"user_id":"47000000-0000-4000-8100-000000000002"}',repeat('b',64));
    raise exception 'subscription owner rebound';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.apply_sandbox_payment_event(pg_temp.payment_event('currency-forgery',2)||'{"currency":"XXX"}',repeat('b',64));
    raise exception 'subscription currency rebound';
  exception when invalid_parameter_value then null; end;
  v:=public.apply_sandbox_payment_event(pg_temp.payment_event('refund-one',3,'payment_refunded'),repeat('b',64));
  assert v->>'decision'='applied';
  v:=public.apply_sandbox_payment_event(pg_temp.payment_event('delayed-renewal',2),repeat('c',64));
  assert v->>'decision'='ignored_stale';
  v:=public.apply_sandbox_payment_event(pg_temp.payment_event('terminal-renewal',4),repeat('d',64));
  assert v->>'decision'='ignored_terminal';
  assert (select status from public.sandbox_payment_subscriptions where subscription_id='synthetic-subscription')='refunded';
  assert (select period_end from public.sandbox_payment_subscriptions where subscription_id='synthetic-subscription') is null;
end $$;

do $$ declare v jsonb; begin
  -- Revocation arriving first must not be resurrected by an older success.
  perform public.apply_sandbox_payment_event(pg_temp.payment_event('early-chargeback',8,'payment_chargeback','out-of-order'),repeat('e',64));
  v:=public.apply_sandbox_payment_event(pg_temp.payment_event('late-payment',1,'payment_succeeded','out-of-order'),repeat('f',64));
  assert v->>'decision'='ignored_stale';
  assert (select status from public.sandbox_payment_subscriptions where subscription_id='out-of-order')='chargeback';
  perform public.apply_sandbox_payment_event(pg_temp.payment_event('new-paid',1,'payment_succeeded','cancelled-case'),repeat('a',64));
  perform public.apply_sandbox_payment_event(pg_temp.payment_event('new-cancelled',2,'subscription_cancelled','cancelled-case'),repeat('b',64));
  assert (select status from public.sandbox_payment_subscriptions where subscription_id='cancelled-case')='cancelled';
  begin
    perform public.apply_sandbox_payment_event(pg_temp.payment_event('bad-money',1,'payment_succeeded','invalid-case')||'{"amount_minor":-1}',repeat('a',64));
    raise exception 'negative minor-unit amount accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.apply_sandbox_payment_event(pg_temp.payment_event('bad-mode',1,'payment_succeeded','invalid-case')||'{"mode":"live"}',repeat('a',64));
    raise exception 'live mode accepted by sandbox';
  exception when invalid_parameter_value then null; end;
end $$;
reset role;

select set_config('request.jwt.claims','{"role":"authenticated","sub":"47000000-0000-4000-8100-000000000001"}',true);
select set_config('request.jwt.claim.sub','47000000-0000-4000-8100-000000000001',true);
set local role authenticated;
do $$ begin
  begin
    perform public.apply_sandbox_payment_event('{}',repeat('a',64));
    raise exception 'client can apply a payment event';
  exception when insufficient_privilege then null; end;
  begin
    perform count(*) from public.sandbox_payment_events;
    raise exception 'client can read sandbox financial events';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ declare v_hash text; begin
  select md5(coalesce(jsonb_agg(to_jsonb(e) order by e.id)::text,'[]')) into v_hash from public.ai_entitlements e;
  assert v_hash=current_setting('rad.sandbox_entitlement_hash'), 'sandbox mutated canonical AI entitlements';
  assert not has_function_privilege('anon','public.apply_sandbox_payment_event(jsonb,text)','EXECUTE');
  assert (select count(*) from public.sandbox_payment_events where event_id in ('owner-forgery','currency-forgery','bad-money','bad-mode'))=0;
  raise notice 'PASS: sandbox payment defaults, replay, identity, currency, ordering, revocation and entitlement separation';
end $$;
rollback;
