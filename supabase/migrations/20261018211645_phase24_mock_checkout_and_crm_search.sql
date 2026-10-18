-- Fictional local fixture: 100 TST units / 30 days, never a real price or entitlement.
begin;
create table private.mock_checkout_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_key uuid not null,
  status text not null default 'pending' check(status in ('pending','confirmed','cancelled','refunded','chargeback')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now()+interval '15 minutes',
  period_end timestamptz not null default date_trunc('second',now())+interval '30 days',
  cancellation_requested_at timestamptz,
  unique(user_id,request_key)
);
alter table private.mock_checkout_orders enable row level security;
revoke all on private.mock_checkout_orders from public,anon,authenticated;
-- Mutations must use the guarded RPCs/trigger, including for service clients.
revoke all on private.mock_checkout_orders from service_role;

create function public.get_mock_checkout(p_order_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare o private.mock_checkout_orders%rowtype; active boolean;
begin
  if auth.uid() is null then raise exception 'forbidden' using errcode='42501'; end if;
  select * into o from private.mock_checkout_orders where id=p_order_id and user_id=auth.uid();
  if not found then raise exception 'checkout_not_found' using errcode='PT404'; end if;
  select coalesce((select enabled from private.payment_sandbox_config where singleton),false)
    and o.status='confirmed' and exists(select 1 from public.sandbox_payment_subscriptions s
      where s.subscription_id='mock:'||o.id and s.user_id=auth.uid() and s.status='active' and s.period_end>now()) into active;
  return jsonb_build_object('mode','mock','no_charge',true,'order_id',o.id,'subscription_id','mock:'||o.id,
    'status',o.status,'amount_minor',100,'currency','TST','period_end',o.period_end,'expires_at',o.expires_at,
    'cancellation_requested',o.cancellation_requested_at is not null,'mock_access_active',active,
    'canonical_paid_access',false);
end $$;

create function public.create_mock_checkout(p_request_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare oid uuid; uid uuid:=auth.uid();
begin
  if uid is null or coalesce(auth.role(),'')<>'authenticated' then raise exception 'forbidden' using errcode='42501'; end if;
  if not coalesce((select enabled from private.payment_sandbox_config where singleton),false) then
    raise exception 'sandbox_disabled' using errcode='PT503'; end if;
  if p_request_key is null then raise exception 'invalid_request_key' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('rad-mock-checkout:'||uid,0));
  select id into oid from private.mock_checkout_orders where user_id=uid and request_key=p_request_key;
  if not found then
    if (select count(*) from private.mock_checkout_orders where user_id=uid and created_at>now()-interval '1 hour')>=10
      or (select count(*) from private.mock_checkout_orders where user_id=uid)>=100 then
      raise exception 'mock_checkout_limit' using errcode='PT429'; end if;
    insert into private.mock_checkout_orders(user_id,request_key) values(uid,p_request_key) returning id into oid;
  end if;
  return public.get_mock_checkout(oid);
end $$;

create function public.request_mock_checkout_cancellation(p_order_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or coalesce(auth.role(),'')<>'authenticated' then raise exception 'forbidden' using errcode='42501'; end if;
  if not coalesce((select enabled from private.payment_sandbox_config where singleton),false) then
    raise exception 'sandbox_disabled' using errcode='PT503'; end if;
  update private.mock_checkout_orders set cancellation_requested_at=coalesce(cancellation_requested_at,now()),
    status=case when status='pending' then 'cancelled' else status end
    where id=p_order_id and user_id=auth.uid();
  if not found then raise exception 'checkout_not_found' using errcode='PT404'; end if;
  -- Confirmed access ends only on a signed cancellation/refund or expiry.
  return public.get_mock_checkout(p_order_id);
end $$;

create function private.bind_mock_payment_event() returns trigger
language plpgsql set search_path='' as $$
declare o private.mock_checkout_orders%rowtype; oid uuid; kind text:=new.payload->>'type';
begin
  if new.subscription_id not like 'mock:%' then return new; end if;
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
  begin oid:=substring(new.subscription_id from 6)::uuid;
  exception when invalid_text_representation then raise exception 'invalid_mock_order' using errcode='22023'; end;
  select * into o from private.mock_checkout_orders where id=oid for update;
  if not found or new.subscription_id<>'mock:'||o.id or (new.payload->>'user_id')::uuid<>o.user_id
    or new.payload->>'currency'<>'TST' then raise exception 'mock_order_binding' using errcode='22023'; end if;
  if new.decision<>'applied' then return new; end if;
  if kind='payment_succeeded' then
    if o.status<>'pending' or o.expires_at<=now() or (new.payload->>'amount_minor')::bigint<>100
      or (new.payload->>'period_end')::timestamptz<>o.period_end then
      raise exception 'invalid_mock_confirmation' using errcode='22023'; end if;
  elsif kind in ('payment_refunded','payment_chargeback') then
    if o.status not in ('confirmed','cancelled') or (new.payload->>'amount_minor')::bigint<>100
      or not exists(select 1 from public.sandbox_payment_events e where e.subscription_id=new.subscription_id
        and e.decision='applied' and e.payload->>'type'='payment_succeeded') then
      raise exception 'invalid_mock_refund' using errcode='22023'; end if;
  elsif kind='subscription_cancelled' then
    if o.status not in ('pending','confirmed','cancelled') or (new.payload->>'amount_minor')::bigint<>0 then
      raise exception 'invalid_mock_cancellation' using errcode='22023'; end if;
  else raise exception 'invalid_mock_event' using errcode='22023'; end if;
  update private.mock_checkout_orders set status=case kind when 'payment_succeeded' then 'confirmed'
    when 'subscription_cancelled' then 'cancelled' when 'payment_refunded' then 'refunded' else 'chargeback' end where id=oid;
  return new;
end $$;
revoke all on function private.bind_mock_payment_event() from public,anon,authenticated,service_role;
create trigger bind_mock_payment_event before insert on public.sandbox_payment_events
  for each row execute function private.bind_mock_payment_event();

-- Literal substring search; percent/underscore are data, never SQL wildcards.
create function public.search_admin_consultations(p_query text default '',p_status text default null,
  p_limit integer default 25,p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if not private.has_role(array['admin','super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if p_query is null or length(p_query)>200 or p_limit is null or p_limit not between 1 and 100
    or p_offset is null or p_offset not between 0 and 10000
    or (p_status is not null and p_status not in ('submitted','in_review','contacted','closed')) then
    raise exception 'invalid_search' using errcode='22023'; end if;
  return coalesce((select jsonb_agg(to_jsonb(r) order by r.created_at desc,r.id desc) from (
    select c.id,c.user_id,c.topic,c.message,c.status,c.admin_note,c.assigned_to,c.revision,c.created_at,c.updated_at
    from public.consultation_requests c where (p_status is null or c.status=p_status)
      and (p_query='' or strpos(lower(c.topic),lower(p_query))>0 or strpos(lower(c.message),lower(p_query))>0)
    order by c.created_at desc,c.id desc limit p_limit offset p_offset
  ) r),'[]'::jsonb);
end $$;
revoke all on function public.get_mock_checkout(uuid),public.create_mock_checkout(uuid),
  public.request_mock_checkout_cancellation(uuid),public.search_admin_consultations(text,text,integer,integer)
  from public,anon,service_role;
grant execute on function public.get_mock_checkout(uuid),public.create_mock_checkout(uuid),
  public.request_mock_checkout_cancellation(uuid),public.search_admin_consultations(text,text,integer,integer) to authenticated;
notify pgrst,'reload schema';
commit;
