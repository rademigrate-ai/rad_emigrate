-- F04: bind legacy keyed retries to immutable request input. RPC signatures and
-- table-shaped receipts remain unchanged. Unkeyed legacy requests retain their
-- existing semantics; clients must supply a stable key for retry protection.
begin;
create table private.rad_legacy_request_receipts (
 user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check(kind in ('booking','interview')),
 request_key text not null,
 request_id uuid not null,
 request_body jsonb not null,
 created_at timestamptz not null default now(),
 primary key(user_id,kind,request_key)
);
alter table private.rad_legacy_request_receipts enable row level security;
revoke all on private.rad_legacy_request_receipts from public,anon,authenticated,service_role;

create or replace function public.submit_booking_request(
 p_service_id uuid,p_message text,p_preferred_start_utc timestamptz default null,
 p_preferred_end_utc timestamptz default null,p_time_zone text default null,
 p_idempotency_key text default null
) returns setof public.booking_requests
language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid(); k text:=nullif(btrim(coalesce(p_idempotency_key,'')),'');
 request jsonb; receipt private.rad_legacy_request_receipts; result public.booking_requests;
begin
 if actor is null or coalesce(auth.jwt()->>'role','')<>'authenticated' then
  raise exception 'authentication required' using errcode='42501';end if;
 if p_message is null or char_length(btrim(p_message)) not between 1 and 4000
    or char_length(k)>200 then raise exception 'invalid request' using errcode='22023';end if;
 request:=jsonb_build_array(p_service_id,btrim(p_message),extract(epoch from p_preferred_start_utc),
  extract(epoch from p_preferred_end_utc),nullif(btrim(coalesce(p_time_zone,'')),''));
 if k is not null then
  -- Same owner/key lock as the appointment adapter: nested calls are reentrant.
  perform pg_advisory_xact_lock(hashtextextended(actor::text||':'||k,0));
  select * into result from public.booking_requests where user_id=actor and idempotency_key=k;
  if found then
   select * into receipt from private.rad_legacy_request_receipts
    where user_id=actor and kind='booking' and request_key=k;
   if receipt.request_id is distinct from result.id or receipt.request_body is distinct from request then
    -- Historical keys have no attested original body. Do not invent a backfill.
    raise exception 'idempotency_conflict' using errcode='PT409';end if;
   return next result;return;
  end if;
 end if;
 if not exists(select 1 from public.service_catalog where id=p_service_id and enabled) then
  raise exception 'service unavailable' using errcode='P0002';end if;
 insert into public.booking_requests(user_id,service_id,message,status,preferred_start_utc,
  preferred_end_utc,time_zone,idempotency_key)
 values(actor,p_service_id,btrim(p_message),'submitted',p_preferred_start_utc,
  p_preferred_end_utc,nullif(btrim(coalesce(p_time_zone,'')),''),k) returning * into result;
 if k is not null then
  insert into private.rad_legacy_request_receipts(user_id,kind,request_key,request_id,request_body)
   values(actor,'booking',k,result.id,request);
 end if;
 return next result;
end $$;

create or replace function public.submit_interview_request(
 p_notes text default '',p_preferred_start_utc timestamptz default null,
 p_preferred_end_utc timestamptz default null,p_time_zone text default null,
 p_locale text default 'en',p_idempotency_key text default null
) returns setof public.interview_requests
language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid(); k text:=nullif(btrim(coalesce(p_idempotency_key,'')),'');
 lang text:=case when p_locale='fa' then 'fa' else 'en' end;
 request jsonb; receipt private.rad_legacy_request_receipts; result public.interview_requests;
begin
 if actor is null or coalesce(auth.jwt()->>'role','')<>'authenticated' then
  raise exception 'authentication required' using errcode='42501';end if;
 if char_length(coalesce(p_notes,''))>4000 or char_length(k)>200 then
  raise exception 'invalid request' using errcode='22023';end if;
 request:=jsonb_build_array(coalesce(p_notes,''),extract(epoch from p_preferred_start_utc),extract(epoch from p_preferred_end_utc),
  nullif(btrim(coalesce(p_time_zone,'')),''),lang);
 if k is not null then
  perform pg_advisory_xact_lock(hashtextextended(actor::text||':'||k,0));
  select * into result from public.interview_requests where user_id=actor and idempotency_key=k;
  if found then
   select * into receipt from private.rad_legacy_request_receipts
    where user_id=actor and kind='interview' and request_key=k;
   if receipt.request_id is distinct from result.id or receipt.request_body is distinct from request then
    raise exception 'idempotency_conflict' using errcode='PT409';end if;
   return next result;return;
  end if;
 end if;
 insert into public.interview_requests(user_id,notes,status,preferred_start_utc,
  preferred_end_utc,time_zone,locale,idempotency_key)
 values(actor,coalesce(p_notes,''),'submitted',p_preferred_start_utc,
  p_preferred_end_utc,nullif(btrim(coalesce(p_time_zone,'')),''),lang,k) returning * into result;
 if k is not null then
  insert into private.rad_legacy_request_receipts(user_id,kind,request_key,request_id,request_body)
   values(actor,'interview',k,result.id,request);
 end if;
 return next result;
end $$;
revoke all on function public.submit_booking_request(uuid,text,timestamptz,timestamptz,text,text),
 public.submit_interview_request(text,timestamptz,timestamptz,text,text,text) from public,anon,service_role;
grant execute on function public.submit_booking_request(uuid,text,timestamptz,timestamptz,text,text),
 public.submit_interview_request(text,timestamptz,timestamptz,text,text,text) to authenticated;
commit;
