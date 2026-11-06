-- Local synthetic queue regression. Every row and mutation rolls back.
-- Run against an isolated local schema; never a hosted or corpus database.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('79000000-0000-4000-8000-000000000001','research-lease-fixture@example.invalid','{}');
insert into private.rad_research_jobs(id,kind,request,created_by,status,attempts,lease_token,lease_until,created_at) values
 ('79000000-0000-4000-8000-000000000011','authority_discovery','{}','79000000-0000-4000-8000-000000000001','running',3,'79000000-0000-4000-8000-000000000101',now()-interval '1 minute',now()-interval '6 days'),
 ('79000000-0000-4000-8000-000000000012','authority_discovery','{}','79000000-0000-4000-8000-000000000001','running',4,'79000000-0000-4000-8000-000000000102',now()-interval '1 minute',now()-interval '5 days'),
 ('79000000-0000-4000-8000-000000000013','authority_discovery','{}','79000000-0000-4000-8000-000000000001','running',3,'79000000-0000-4000-8000-000000000103',now()+interval '5 minutes',now()-interval '4 days'),
 ('79000000-0000-4000-8000-000000000014','authority_discovery','{}','79000000-0000-4000-8000-000000000001','running',2,'79000000-0000-4000-8000-000000000104',now()-interval '1 minute',now()-interval '3 days'),
 ('79000000-0000-4000-8000-000000000015','authority_discovery','{}','79000000-0000-4000-8000-000000000001','queued',0,null,null,now()-interval '2 days'),
 ('79000000-0000-4000-8000-000000000016','authority_discovery','{}','79000000-0000-4000-8000-000000000001','succeeded',3,null,null,now()-interval '1 day');

select set_config('request.jwt.claims','{"role":"authenticated"}',true);
do $$begin
 assert not has_function_privilege('anon','public.claim_official_research_job()','EXECUTE');
 assert not has_function_privilege('authenticated','public.claim_official_research_job()','EXECUTE');
 assert has_function_privilege('service_role','public.claim_official_research_job()','EXECUTE');
 begin
  perform public.claim_official_research_job();
  raise exception 'FAIL nonservice claim accepted';
 exception when sqlstate 'PT403' then null;end;
 assert exists(select 1 from private.rad_research_jobs where id='79000000-0000-4000-8000-000000000011' and status='running'), 'nonservice caller mutated exhausted lease';
end $$;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$declare claimed jsonb;begin
 claimed:=public.claim_official_research_job();
 assert claimed->>'job_id'='79000000-0000-4000-8000-000000000014', 'oldest retryable lease must be reclaimed';
 assert (select count(*)=2 from private.rad_research_jobs where id in ('79000000-0000-4000-8000-000000000011','79000000-0000-4000-8000-000000000012')
  and status='failed' and safe_error_code='worker_failed' and lease_token is null and lease_until is null), 'expired exhausted leases must fail and release their lease';
 assert exists(select 1 from private.rad_research_jobs where id='79000000-0000-4000-8000-000000000013' and status='running' and attempts=3 and lease_token='79000000-0000-4000-8000-000000000103'), 'active third attempt must remain untouched';
 assert exists(select 1 from private.rad_research_jobs where id='79000000-0000-4000-8000-000000000016' and status='succeeded'), 'completed job must remain untouched';
 assert exists(select 1 from private.rad_research_jobs where id='79000000-0000-4000-8000-000000000014' and status='running' and attempts=3 and lease_token=(claimed->>'lease_token')::uuid and lease_until>now()), 'last retry must receive a fresh bounded lease';
 claimed:=public.claim_official_research_job();
 assert claimed->>'job_id'='79000000-0000-4000-8000-000000000015', 'next queued job must still be claimable';
end $$;
update private.rad_research_jobs set lease_until=now()-interval '1 minute' where id='79000000-0000-4000-8000-000000000014';
do $$begin
 assert public.claim_official_research_job() is null, 'empty eligible queue must return null';
 assert exists(select 1 from private.rad_research_jobs where id='79000000-0000-4000-8000-000000000014' and status='failed' and safe_error_code='worker_failed' and lease_token is null and lease_until is null), 'third attempt crash must become terminal even without another queued job';
end $$;
rollback;
