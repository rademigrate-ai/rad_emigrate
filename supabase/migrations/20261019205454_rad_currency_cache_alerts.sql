begin;
create table public.fx_observations(
 id uuid primary key default gen_random_uuid(),provider text not null check(provider in ('frankfurter','fawazahmed0')),
 base text not null check(base ~ '^[A-Z]{3}$'),quote text not null check(quote ~ '^[A-Z]{3}$'),
 rate numeric(38,18) not null check(rate>0 and rate<1000000000000000000),
 observation_date date not null,fetched_at timestamptz not null default now(),
 rate_basis text not null default 'provider_reference' check(rate_basis='provider_reference'),
 source_url text not null,unique(provider,base,quote,observation_date,rate_basis)
);
create index fx_observations_pair_date_idx on public.fx_observations(base,quote,observation_date desc);
alter table public.fx_observations enable row level security;
revoke all on public.fx_observations from public,anon,authenticated,service_role;
create table public.currency_alerts(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),revision integer not null default 1,
 base text not null check(base ~ '^[A-Z]{3}$'),quote text not null check(quote ~ '^[A-Z]{3}$'),
 direction text not null check(direction in ('above','below')),threshold numeric(38,18) not null check(threshold>0 and threshold<1000000000000000000),
 enabled boolean not null default true,cooldown_seconds integer not null check(cooldown_seconds between 3600 and 2592000),
 last_side boolean,last_observation_id uuid references public.fx_observations(id),last_triggered_at timestamptz,
 created_at timestamptz not null default now()
);
create index currency_alerts_owner_idx on public.currency_alerts(user_id,id);
create index currency_alerts_pair_idx on public.currency_alerts(base,quote) where enabled;
alter table public.currency_alerts enable row level security;
revoke all on public.currency_alerts from public,anon,authenticated,service_role;
grant select on public.currency_alerts to authenticated;
create policy currency_alerts_owner_read on public.currency_alerts for select to authenticated using(user_id=(select auth.uid()));
create table private.currency_alert_events(
 alert_id uuid not null references public.currency_alerts(id),observation_id uuid not null references public.fx_observations(id),
 notification_id uuid references public.notifications(id),created_at timestamptz not null default now(),primary key(alert_id,observation_id)
);
alter table private.currency_alert_events enable row level security;
revoke all on private.currency_alert_events from public,anon,authenticated,service_role;

create function private.rad_fx_json(o public.fx_observations) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',o.id,'provider',o.provider,'base',o.base,'quote',o.quote,'rate',trim(trailing '.' from trim(trailing '0' from o.rate::text)),
  'observation_date',o.observation_date::text,'fetched_at',to_char(o.fetched_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'freshness_state',case when o.observation_date=current_date then 'fresh' else 'stale' end,
  'rate_basis','provider_reference','source_url',o.source_url);
$$;
create function public.get_fx_quote(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.fx_observations;
begin
 perform private.rad_assert_request('get_fx_quote',p_request);
 select * into o from public.fx_observations where base=p_request->>'base' and quote=p_request->>'quote'
  and observation_date>=current_date-7
  order by observation_date desc,case provider when 'frankfurter' then 0 else 1 end,fetched_at desc,id limit 1;
 if not found then raise exception 'rate_unavailable' using errcode='PT503'; end if;
 if not (p_request->>'allow_stale')::boolean and o.observation_date<current_date then raise exception 'stale_rate' using errcode='PT503'; end if;
 return private.rad_envelope(private.rad_fx_json(o));
end $$;

create function private.rad_half_even(amount numeric,places integer) returns numeric language sql immutable set search_path='' as $$
 select case when abs(amount*power(10::numeric,places)-trunc(amount*power(10::numeric,places)))=0.5
 then (trunc(amount*power(10::numeric,places))+case when mod(trunc(amount*power(10::numeric,places)),2)=0 then 0 else sign(amount) end)/power(10::numeric,places)
 else round(amount,places) end;
$$;
create function public.convert_currency(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare o jsonb; amount numeric; input_scale numeric:=1; output_scale numeric:=1; converted numeric;
begin
 perform private.rad_assert_request('convert_currency',p_request);
 amount:=(p_request->>'amount')::numeric;
 if amount>1000000000000000000 then raise exception 'amount_out_of_range' using errcode='PT422'; end if;
 if p_request->>'input_unit'='toman' then
  if p_request->>'base'<>'IRR' then raise exception 'toman_requires_irr' using errcode='PT422'; end if;input_scale:=10;
 end if;
 if p_request->>'output_unit'='toman' then
  if p_request->>'quote'<>'IRR' then raise exception 'toman_requires_irr' using errcode='PT422'; end if;output_scale:=10;
 end if;
 if p_request->>'base'=p_request->>'quote' then
  -- Identity is arithmetic; it is not a newly fetched provider observation.
  o:=null;
 else
  o:=public.get_fx_quote(jsonb_build_object('base',p_request->'base','quote',p_request->'quote','rate_basis','provider_reference','allow_stale',p_request->'allow_stale'))->'data';
 end if;
 converted:=private.rad_half_even(amount*input_scale*coalesce((o->>'rate')::numeric,1)/output_scale,(p_request->>'decimal_places')::integer);
 if converted>=power(10::numeric,20) then raise exception 'conversion_overflow' using errcode='PT422'; end if;
 return private.rad_envelope(jsonb_build_object('input_amount',p_request->'amount','output_amount',converted::text,'base',p_request->'base','quote',p_request->'quote',
  'input_unit',p_request->'input_unit','output_unit',p_request->'output_unit','input_scale_to_currency',input_scale::text,'output_scale_to_currency',output_scale::text,
  'unit_policy_version','irr-classic-toman-display-10-v1','rounding','HALF_EVEN','decimal_places',p_request->'decimal_places','observation',o,'conversion_kind',case when o is null then 'identity' else 'provider_reference' end));
end $$;

create function public.get_fx_history(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare items jsonb; pos jsonb; off integer; lim integer:=(p_request->>'limit')::integer; version text; total integer;
begin
 perform private.rad_assert_request('get_fx_history',p_request);
 if (p_request->>'date_to')::date-(p_request->>'date_from')::date not between 0 and 366 then raise exception 'invalid_history_range' using errcode='PT422'; end if;
 select coalesce(max(fetched_at)::text,'empty') into version from public.fx_observations where base=p_request->>'base' and quote=p_request->>'quote';
 pos:=private.rad_page_position(p_request,version);off:=coalesce((pos->>'offset')::integer,0);
 select count(*) into total from public.fx_observations where base=p_request->>'base' and quote=p_request->>'quote' and observation_date between (p_request->>'date_from')::date and (p_request->>'date_to')::date;
 select coalesce(jsonb_agg(private.rad_fx_json(o) order by o.observation_date,o.id),'[]') into items from (
  select * from public.fx_observations where base=p_request->>'base' and quote=p_request->>'quote' and observation_date between (p_request->>'date_from')::date and (p_request->>'date_to')::date order by observation_date,id offset off limit lim) o;
 return private.rad_envelope(jsonb_build_object('items',items),null,private.rad_page(p_request,version,jsonb_build_object('offset',off+lim),total>off+lim));
end $$;

create function private.rad_alert_json(a public.currency_alerts) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',a.id,'revision',a.revision,'base',a.base,'quote',a.quote,'rate_basis','provider_reference','direction',a.direction,
 'threshold',trim(trailing '.' from trim(trailing '0' from a.threshold::text)),'enabled',a.enabled,'cooldown_seconds',a.cooldown_seconds,
 'last_triggered_at',case when a.last_triggered_at is null then null else to_char(a.last_triggered_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') end,
 'created_at',to_char(a.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'));
$$;
create function private.rad_alert_mutate(operation text,body jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare owner uuid:=private.rad_require_owner(); prior jsonb; a public.currency_alerts; result jsonb;
begin
 prior:=private.rad_begin_mutation(operation,body);if prior is not null then return prior; end if;
 perform pg_advisory_xact_lock(hashtextextended('currency-alert:'||owner::text,0));
 if operation='create_currency_alert' then
  if (select count(*) from public.currency_alerts where user_id=owner and enabled and deleted_at is null)>=50 then raise exception 'alert_limit' using errcode='PT422'; end if;
  insert into public.currency_alerts(user_id,base,quote,direction,threshold,cooldown_seconds)
  values(owner,body->>'base',body->>'quote',body->>'direction',(body->>'threshold')::numeric,(body->>'cooldown_seconds')::integer) returning * into a;
 else
  select * into a from public.currency_alerts where id=(body->>'alert_id')::uuid and user_id=owner and deleted_at is null for update;
  if not found then raise exception 'not_found' using errcode='PT404'; end if;
  if a.revision<>(body->>'expected_revision')::integer then raise exception 'revision_conflict' using errcode='PT409'; end if;
  if operation='delete_currency_alert' then
   update public.currency_alerts set enabled=false,deleted_at=now(),revision=revision+1 where id=a.id;
   result:=private.rad_envelope(private.rad_ack());
  else
   update public.currency_alerts set threshold=(body->>'threshold')::numeric,direction=a.direction,enabled=(body->>'enabled')::boolean,
    cooldown_seconds=(body->>'cooldown_seconds')::integer,revision=revision+1,last_side=null where id=a.id returning * into a;
  end if;
 end if;
 if result is null then result:=private.rad_envelope(private.rad_alert_json(a)); end if;
 return private.rad_finish_mutation(operation,body,result);
end $$;

create function public.record_fx_observation(p_observation jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare o public.fx_observations; a public.currency_alerts; side boolean; notification uuid;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403'; end if;
 if (p_observation->>'provider'='frankfurter' and p_observation->>'source_url' !~ '^https://api[.]frankfurter[.]dev/v2/rate/[a-z]{3}/[a-z]{3}$')
 or (p_observation->>'provider'='fawazahmed0' and p_observation->>'source_url' !~ '^https://(cdn[.]jsdelivr[.]net/npm/@fawazahmed0/currency-api@latest|latest[.]currency-api[.]pages[.]dev)/v1/currencies/[a-z]{3}[.]min[.]json$')
 or (p_observation->>'observation_date')::date>current_date or (p_observation->>'observation_date')::date<current_date-7
 or p_observation->>'rate' !~ '^(0|[1-9][0-9]*)([.][0-9]{1,18})?$' then raise exception 'invalid_observation' using errcode='PT422'; end if;
 insert into public.fx_observations(provider,base,quote,rate,observation_date,source_url)
 values(p_observation->>'provider',p_observation->>'base',p_observation->>'quote',(p_observation->>'rate')::numeric,(p_observation->>'observation_date')::date,p_observation->>'source_url')
 on conflict(provider,base,quote,observation_date,rate_basis) do nothing returning * into o;
 if o.id is null then select * into o from public.fx_observations where provider=p_observation->>'provider' and base=p_observation->>'base' and quote=p_observation->>'quote' and observation_date=(p_observation->>'observation_date')::date;return o.id;end if;
 -- Only fresh observations advance threshold state. Lock each alert exactly once.
 if o.observation_date<current_date then return o.id; end if;
 for a in select * from public.currency_alerts where enabled and base=o.base and quote=o.quote order by id for update loop
  if a.last_observation_id is not null and exists(select 1 from public.fx_observations where id=a.last_observation_id and observation_date>=o.observation_date) then continue; end if;
  side:=case a.direction when 'above' then o.rate>=a.threshold else o.rate<=a.threshold end;
  if side and a.last_side=false and (a.last_triggered_at is null or a.last_triggered_at+make_interval(secs=>a.cooldown_seconds)<=now()) then
   insert into private.currency_alert_events(alert_id,observation_id) values(a.id,o.id) on conflict do nothing;
   if found then
    insert into public.notifications(user_id,type,title,body,action_path,source_id)
    values(a.user_id,'system','Currency reference alert',a.base||'/'||a.quote||' provider_reference: '||o.rate::text,'/profile/currency-alerts/'||a.id,a.id) returning id into notification;
    update private.currency_alert_events set notification_id=notification where alert_id=a.id and observation_id=o.id;
    update public.currency_alerts set last_triggered_at=now() where id=a.id;
   end if;
  end if;
  update public.currency_alerts set last_side=side,last_observation_id=o.id where id=a.id;
 end loop;
 return o.id;
end $$;
revoke all on function public.record_fx_observation(jsonb) from public,anon,authenticated;
grant execute on function public.record_fx_observation(jsonb) to service_role;
revoke all on function public.get_fx_quote(jsonb),public.convert_currency(jsonb),public.get_fx_history(jsonb) from public;
grant execute on function public.get_fx_quote(jsonb),public.convert_currency(jsonb),public.get_fx_history(jsonb) to anon,authenticated;
CREATE FUNCTION public.create_currency_alert(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_alert_mutate('create_currency_alert',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.create_currency_alert(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.create_currency_alert(jsonb) TO authenticated;
CREATE FUNCTION public.update_currency_alert(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_alert_mutate('update_currency_alert',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.update_currency_alert(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.update_currency_alert(jsonb) TO authenticated;
CREATE FUNCTION public.delete_currency_alert(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_alert_mutate('delete_currency_alert',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.delete_currency_alert(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.delete_currency_alert(jsonb) TO authenticated;
commit;
