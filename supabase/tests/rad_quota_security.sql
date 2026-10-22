begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values('a7000000-0000-4000-8000-000000000001','synthetic-quota@example.invalid');
insert into public.ai_usage_limits(role,daily_requests,daily_output_tokens) values('user',100,8000) on conflict(role) do update set daily_requests=100,daily_output_tokens=8000;
do $$ declare a jsonb;b jsonb;id uuid;begin
 begin perform public.reserve_rad_ai_request('a7000000-0000-4000-8000-000000000001',gen_random_uuid(),null,4096,null);raise exception 'NULL hash admitted';exception when sqlstate 'PT422' then null;end;
 a:=public.reserve_rad_ai_request('a7000000-0000-4000-8000-000000000001',gen_random_uuid(),repeat('a',64),4096,null);id:=(a->>'request_id')::uuid;
 b:=public.reserve_rad_ai_request('a7000000-0000-4000-8000-000000000001',gen_random_uuid(),repeat('b',64),4096,null);
 if b->>'allowed'<>'false' then raise exception 'pending token budget oversubscribed';end if;
 begin perform public.settle_rad_ai_request(id,200,null,1);raise exception 'NULL settlement admitted';exception when sqlstate 'PT422' then null;end;
 if not public.settle_rad_ai_request(id,200,'{"synthetic":true}',1) then raise exception 'settlement failed';end if;
 b:=public.reserve_rad_ai_request('a7000000-0000-4000-8000-000000000001',gen_random_uuid(),repeat('c',64),4096,null);
 if b->>'allowed'<>'true' then raise exception 'unused token reservation not released';end if;
 update private.rad_ai_invocations set created_at=now()-interval '3 minutes' where request_id=(b->>'request_id')::uuid;
 if public.expire_rad_ai_reservations()<1 then raise exception 'lease expiry not settled';end if;
 if (select output_tokens from public.ai_requests where ai_requests.id=(b->>'request_id')::uuid)<>4096 then raise exception 'unknown provider usage not conservatively charged';end if;
 if public.settle_rad_ai_request((b->>'request_id')::uuid,200,'{"synthetic":true}',0) then raise exception 'expired reservation resurrected';end if;
end $$;
rollback;
