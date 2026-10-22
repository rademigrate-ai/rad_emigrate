begin;
create table private.rad_ai_invocations(
 actor text not null,request_key uuid not null,body_hash text not null,request_id uuid not null unique references public.ai_requests(id),
 reserved_output_tokens integer not null check(reserved_output_tokens between 1 and 8192),
 state text not null default 'running' check(state in ('running','succeeded','failed')),
 response jsonb,http_status integer,created_at timestamptz not null default now(),finished_at timestamptz,
 primary key(actor,request_key)
);
alter table private.rad_ai_invocations enable row level security;
revoke all on private.rad_ai_invocations from public,anon,authenticated,service_role;
create function public.reserve_rad_ai_request(p_user_id uuid,p_request_key uuid,p_body_hash text,p_reserved_output_tokens integer,p_session_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare prior private.rad_ai_invocations;quota jsonb;v_role text;budget integer;used bigint;reserved bigint;
 day timestamptz:=date_trunc('day',now() at time zone 'utc') at time zone 'utc';
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403'; end if;
 if p_user_id is null or p_request_key is null or p_body_hash !~ '^[0-9a-f]{64}$' or p_reserved_output_tokens not between 1 and 8192 then raise exception 'invalid_reservation' using errcode='PT422'; end if;
 if p_session_id is not null and not exists(select 1 from public.ai_sessions where id=p_session_id and user_id=p_user_id) then raise exception 'session_forbidden' using errcode='PT403'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_user_id::text||':'||day::text,0));
 select * into prior from private.rad_ai_invocations where actor=p_user_id::text and request_key=p_request_key;
 if found then
  if prior.body_hash<>p_body_hash then raise exception 'idempotency_conflict' using errcode='PT409'; end if;
  if prior.created_at<now()-interval '24 hours' then raise exception 'request_expired' using errcode='PT409'; end if;
  return jsonb_build_object('allowed',true,'request_id',prior.request_id,'replayed',true,'state',prior.state,'response',prior.response,'http_status',prior.http_status);
 end if;
 select p.role into v_role from public.profiles p where id=p_user_id;
 if not found then raise exception 'user_not_found' using errcode='PT403'; end if;
 select daily_output_tokens into budget from public.ai_usage_limits l where l.role=v_role;
 if budget is null then raise exception 'quota_unavailable' using errcode='PT503'; end if;
 select coalesce(sum(output_tokens),0) into used from public.ai_requests where user_id=p_user_id and created_at>=day;
 select coalesce(sum(reserved_output_tokens),0) into reserved from private.rad_ai_invocations where actor=p_user_id::text and state='running' and created_at>=day;
 if used+reserved+p_reserved_output_tokens>budget then return jsonb_build_object('allowed',false,'error','daily_token_limit_reached'); end if;
 quota:=private.rad_consume_ai_quota_base(p_user_id,v_role);
 if quota->>'allowed'<>'true' or quota->>'request_id' is null then return quota; end if;
 insert into private.rad_ai_invocations(actor,request_key,body_hash,request_id,reserved_output_tokens)
 values(p_user_id::text,p_request_key,p_body_hash,(quota->>'request_id')::uuid,p_reserved_output_tokens);
 update public.ai_requests set session_id=p_session_id where id=(quota->>'request_id')::uuid;
 return quota||jsonb_build_object('replayed',false,'state','running');
end $$;

create function public.settle_rad_ai_request(p_request_id uuid,p_http_status integer,p_response jsonb,p_output_tokens integer)
returns boolean language plpgsql security definer set search_path='' as $$
declare invocation private.rad_ai_invocations;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403'; end if;
 select * into invocation from private.rad_ai_invocations where request_id=p_request_id for update;
 if not found then raise exception 'reservation_required' using errcode='PT409'; end if;
 if invocation.state<>'running' then return false; end if;
 if p_output_tokens not between 0 and invocation.reserved_output_tokens or p_http_status not between 200 and 599 or octet_length(p_response::text)>150000 then raise exception 'invalid_settlement' using errcode='PT422'; end if;
 update private.rad_ai_invocations set state=case when p_http_status=200 then 'succeeded' else 'failed' end,
 response=p_response,http_status=p_http_status,finished_at=now() where request_id=p_request_id;
 update public.ai_requests set status=case when p_http_status=200 then 'succeeded' else 'failed' end,output_tokens=p_output_tokens,
 safe_error_code=case when p_http_status=200 then null else 'copilot_failed' end,finished_at=now() where id=p_request_id;
 return true;
end $$;

create function public.expire_rad_ai_reservations() returns integer language plpgsql security definer set search_path='' as $$
declare count integer;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403'; end if;
 with expired as (update private.rad_ai_invocations set state='failed',finished_at=now(),http_status=503,
 response=jsonb_build_object('error','request_expired') where state='running' and created_at<now()-interval '2 minutes' returning request_id,reserved_output_tokens)
 update public.ai_requests r set status='failed',finished_at=now(),safe_error_code='request_expired',output_tokens=e.reserved_output_tokens from expired e where r.id=e.request_id;
 get diagnostics count=row_count;
 -- The request identity/hash is retained; sensitive cached replies expire.
 update private.rad_ai_invocations set response=null where created_at<now()-interval '24 hours' and response is not null;
 return count;
end $$;
revoke all on function public.reserve_rad_ai_request(uuid,uuid,text,integer,uuid),public.settle_rad_ai_request(uuid,integer,jsonb,integer),public.expire_rad_ai_reservations() from public,anon,authenticated;
grant execute on function public.reserve_rad_ai_request(uuid,uuid,text,integer,uuid),public.settle_rad_ai_request(uuid,integer,jsonb,integer),public.expire_rad_ai_reservations() to service_role;
commit;
