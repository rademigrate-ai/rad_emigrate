-- Additive: schedule eight-hour AI model catalogue synchronization.
-- Safe to apply on disposable/staging; Production requires separate owner authorization.
-- Does NOT modify migration history of other environments.
-- Distinct from continuous provider health telemetry.

create table if not exists private.ai_catalogue_sync_runs (
  id uuid primary key default gen_random_uuid(),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running'
    check (status in ('running', 'succeeded', 'failed', 'partial')),
  result jsonb not null default '{}'::jsonb,
  error_text text
);

revoke all on table private.ai_catalogue_sync_runs from public, anon, authenticated;
grant all on table private.ai_catalogue_sync_runs to service_role;

-- Advisory lock prevents overlapping sync jobs.
create or replace function private.enqueue_ai_catalogue_sync()
returns void
language plpgsql
security definer
set search_path = public, private, extensions
as $$
declare
  got_lock boolean;
begin
  got_lock := pg_try_advisory_xact_lock(87201428);
  if not got_lock then
    return;
  end if;
  insert into private.ai_catalogue_sync_runs(status, result)
  values ('running', jsonb_build_object('queued_at', now()));
  -- Actual HTTP discovery is performed by Edge Function invoked by platform scheduler
  -- or ops runbook calling ai-orchestrator action=sync_catalogues with service role.
  -- This function only records the schedule tick and prevents duplicate ticks.
end;
$$;

revoke all on function private.enqueue_ai_catalogue_sync() from public, anon, authenticated;
grant execute on function private.enqueue_ai_catalogue_sync() to service_role;

-- 00:00, 08:00, 16:00 UTC
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid)
    from cron.job
    where jobname = 'rad-ai-catalogue-sync-8h';

    perform cron.schedule(
      'rad-ai-catalogue-sync-8h',
      '0 0,8,16 * * *',
      $cron$select private.enqueue_ai_catalogue_sync();$cron$
    );
  end if;
exception when others then
  -- Environments without pg_cron remain functional; ops can invoke Edge action manually.
  raise notice 'pg_cron schedule skipped: %', sqlerrm;
end;
$$;

comment on function private.enqueue_ai_catalogue_sync() is
  'Eight-hour AI catalogue sync tick; Edge Function action=sync_catalogues performs discovery.';
