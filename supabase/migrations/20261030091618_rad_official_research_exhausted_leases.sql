-- Close expired final-attempt leases before claiming another official job.
-- No new queue or worker authority; failed jobs require an explicit new request.
begin;
create or replace function public.claim_official_research_job() returns jsonb
language plpgsql security definer set search_path='' as $$
declare j private.rad_research_jobs;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403';end if;
 with exhausted as (
  select id from private.rad_research_jobs
  where status='running' and lease_until<now() and attempts>=3
  for update skip locked
 )
 update private.rad_research_jobs jobs
 set status='failed',safe_error_code='worker_failed',lease_token=null,lease_until=null,updated_at=now()
 from exhausted where jobs.id=exhausted.id;
 select * into j from private.rad_research_jobs
 where attempts<3 and (status='queued' or (status='running' and lease_until<now()))
 order by created_at,id for update skip locked limit 1;
 if not found then return null;end if;
 update private.rad_research_jobs
 set status='running',attempts=attempts+1,lease_token=gen_random_uuid(),lease_until=now()+interval '60 seconds',updated_at=now()
 where id=j.id returning * into j;
 return jsonb_build_object('job_id',j.id,'lease_token',j.lease_token,'kind',j.kind,'request',j.request);
end $$;
alter function public.claim_official_research_job() owner to postgres;
revoke all on function public.claim_official_research_job() from public,anon,authenticated;
grant execute on function public.claim_official_research_job() to service_role;
commit;
