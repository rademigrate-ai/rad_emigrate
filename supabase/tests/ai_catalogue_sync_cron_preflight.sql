-- Preflight for eight-hour catalogue sync migration (disposable only).
-- Verifies schedule definition uniqueness and does not require live Edge.

begin;

do $$
declare
  job_count int := 0;
  has_fn boolean;
begin
  has_fn := to_regprocedure('private.enqueue_ai_catalogue_sync()') is not null
    or exists (
      select 1 from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'private' and p.proname = 'enqueue_ai_catalogue_sync'
    );

  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    select count(*) into job_count from cron.job where jobname = 'rad-ai-catalogue-sync-8h';
    if job_count > 1 then
      raise exception 'duplicate rad-ai-catalogue-sync-8h jobs: %', job_count;
    end if;
    raise notice 'pg_cron present; rad-ai-catalogue-sync-8h count=%', job_count;
  else
    raise notice 'pg_cron absent — schedule will be skipped; Edge sync_catalogues remains manual';
  end if;

  if to_regclass('private.ai_catalogue_sync_runs') is null then
    raise notice 'private.ai_catalogue_sync_runs not present until migration applied';
  end if;
end;
$$;

rollback;
