-- Synthetic sandbox only. No checkout, provider selection, real prices/taxes,
-- external charge, or write to ai_entitlements is implemented by this proposal.
begin;
create table private.payment_sandbox_config (
  singleton boolean primary key default true check(singleton),
  enabled boolean not null default false
);
insert into private.payment_sandbox_config(singleton) values(true);
alter table private.payment_sandbox_config enable row level security;
revoke all on private.payment_sandbox_config from public,anon,authenticated;
grant all on private.payment_sandbox_config to service_role;
create policy sandbox_config_service on private.payment_sandbox_config for all to service_role using(true) with check(true);

create table public.sandbox_payment_subscriptions (
  subscription_id text primary key check(subscription_id ~ '^[A-Za-z0-9_.:-]{1,128}$'),
  user_id uuid not null references auth.users(id) on delete cascade,
  currency text not null check(currency ~ '^[A-Z]{3}$'),
  status text not null check(status in ('active','cancelled','refunded','chargeback')),
  last_sequence bigint not null check(last_sequence>0),
  period_end timestamptz,
  updated_at timestamptz not null default now()
);
create index sandbox_payment_subscriptions_user_idx on public.sandbox_payment_subscriptions(user_id);
create table public.sandbox_payment_events (
  event_id text primary key,
  subscription_id text not null references public.sandbox_payment_subscriptions(subscription_id) on delete cascade,
  payload jsonb not null,
  payload_sha256 text not null check(payload_sha256 ~ '^[0-9a-f]{64}$'),
  decision text not null check(decision in ('applied','ignored_stale','ignored_terminal')),
  created_at timestamptz not null default now()
);
create index sandbox_payment_events_subscription_idx on public.sandbox_payment_events(subscription_id,created_at);
alter table public.sandbox_payment_subscriptions enable row level security;
alter table public.sandbox_payment_events enable row level security;
revoke all on public.sandbox_payment_subscriptions,public.sandbox_payment_events from public,anon,authenticated;
grant all on public.sandbox_payment_subscriptions,public.sandbox_payment_events to service_role;
create policy sandbox_subscriptions_service on public.sandbox_payment_subscriptions for all to service_role using(true) with check(true);
create policy sandbox_events_service on public.sandbox_payment_events for all to service_role using(true) with check(true);

create function public.apply_sandbox_payment_event(p_event jsonb,p_payload_sha256 text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_event_id text; v_subscription_id text; v_user uuid; v_type text; v_currency text;
  v_sequence bigint; v_amount bigint; v_occurred timestamptz; v_end timestamptz;
  v_existing public.sandbox_payment_events%rowtype;
  v_state public.sandbox_payment_subscriptions%rowtype;
  v_decision text := 'applied'; v_status text;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
  if not coalesce((select enabled from private.payment_sandbox_config where singleton),false) then
    raise exception 'sandbox_disabled' using errcode='55000';
  end if;
  if p_event is null or jsonb_typeof(p_event)<>'object' or p_event->>'mode' is distinct from 'sandbox'
    or p_payload_sha256 is null or p_payload_sha256 !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_sandbox_event' using errcode='22023';
  end if;
  v_event_id:=p_event->>'event_id'; v_subscription_id:=p_event->>'subscription_id';
  v_type:=p_event->>'type'; v_currency:=p_event->>'currency';
  if coalesce(v_event_id,'') !~ '^[A-Za-z0-9_.:-]{1,128}$' or coalesce(v_subscription_id,'') !~ '^[A-Za-z0-9_.:-]{1,128}$'
    or coalesce(v_currency,'') !~ '^[A-Z]{3}$' or v_type is null
    or v_type not in ('payment_succeeded','subscription_cancelled','payment_refunded','payment_chargeback')
    or coalesce(p_event->>'sequence','') !~ '^[1-9][0-9]{0,8}$'
    or coalesce(p_event->>'amount_minor','') !~ '^[0-9]{1,10}$' then
    raise exception 'invalid_sandbox_event' using errcode='22023';
  end if;
  begin
    v_user:=(p_event->>'user_id')::uuid; v_sequence:=(p_event->>'sequence')::bigint;
    v_amount:=(p_event->>'amount_minor')::bigint; v_occurred:=(p_event->>'occurred_at')::timestamptz;
    v_end:=nullif(p_event->>'period_end','')::timestamptz;
  exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow then
    raise exception 'invalid_sandbox_event' using errcode='22023';
  end;
  if v_user is null or v_occurred is null or not isfinite(v_occurred) or v_occurred>now()+interval '5 minutes' or v_amount>1000000000
    or (v_type<>'subscription_cancelled' and v_amount<1)
    or (v_type='payment_succeeded' and (v_end is null or not isfinite(v_end) or v_end<=v_occurred)) then
    raise exception 'invalid_sandbox_event' using errcode='22023';
  end if;
  -- Serialise event-id conflicts separately from each subscription's ordering.
  perform pg_advisory_xact_lock(hashtextextended('rad-sandbox-event:'||v_event_id,0));
  select * into v_existing from public.sandbox_payment_events where event_id=v_event_id;
  if found then
    if v_existing.payload_sha256<>p_payload_sha256 or v_existing.payload<>p_event then
      raise exception 'sandbox_event_conflict' using errcode='22023';
    end if;
    return jsonb_build_object('mode','sandbox','duplicate',true,'decision',v_existing.decision);
  end if;
  perform pg_advisory_xact_lock(hashtextextended('rad-sandbox-subscription:'||v_subscription_id,0));
  select * into v_state from public.sandbox_payment_subscriptions where subscription_id=v_subscription_id for update;
  if found then
    if v_state.user_id<>v_user or v_state.currency<>v_currency then
      raise exception 'sandbox_subscription_identity_conflict' using errcode='22023';
    end if;
    if v_sequence<=v_state.last_sequence then v_decision:='ignored_stale';
    elsif v_state.status<>'active' and v_type='payment_succeeded' then v_decision:='ignored_terminal';
    end if;
  end if;
  v_status:=case v_type when 'payment_succeeded' then 'active' when 'subscription_cancelled' then 'cancelled'
    when 'payment_refunded' then 'refunded' else 'chargeback' end;
  if v_decision='applied' then
    if v_state.subscription_id is not null and v_type='payment_succeeded' and v_end<v_state.period_end then
      raise exception 'sandbox_period_regression' using errcode='22023';
    end if;
    insert into public.sandbox_payment_subscriptions(subscription_id,user_id,currency,status,last_sequence,period_end)
      values(v_subscription_id,v_user,v_currency,v_status,v_sequence,case when v_status='active' then v_end else null end)
      on conflict(subscription_id) do update set status=excluded.status,last_sequence=excluded.last_sequence,
        period_end=excluded.period_end,updated_at=now();
  elsif v_decision='ignored_terminal' then
    update public.sandbox_payment_subscriptions set last_sequence=v_sequence,updated_at=now() where subscription_id=v_subscription_id;
  end if;
  insert into public.sandbox_payment_events(event_id,subscription_id,payload,payload_sha256,decision)
    values(v_event_id,v_subscription_id,p_event,p_payload_sha256,v_decision);
  return jsonb_build_object('mode','sandbox','duplicate',false,'decision',v_decision);
end $$;
revoke all on function public.apply_sandbox_payment_event(jsonb,text) from public,anon,authenticated;
grant execute on function public.apply_sandbox_payment_event(jsonb,text) to service_role;
notify pgrst,'reload schema';
commit;
