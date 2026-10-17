-- Forward-only alignment: add missing CHECK constraints on public.ai_models
-- that exist in the repository historical alias of ai_dynamic_routing_architecture
-- but were not present as named constraints on production (columns already exist).
--
-- Idempotent: adds a constraint only when it does not already exist.
-- Does NOT drop or recreate existing constraints (avoids unnecessary catalog churn
-- and lock windows on environments that already applied the historical alias DDL).
-- Uses NOT VALID then VALIDATE to keep validation outside a long exclusive lock.
-- Does not alter data, columns, defaults, or existing constraints.
--
-- Preflight (run before apply; abort if non-zero):
--   select count(*) from public.ai_models
--     where consecutive_failures < 0
--        or (measured_latency_ms is not null and measured_latency_ms < 0)
--        or (recent_success_rate is not null
--            and (recent_success_rate < 0 or recent_success_rate > 1));
begin;

do $body$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'ai_models_consecutive_failures_check'
      and conrelid = 'public.ai_models'::regclass
  ) then
    alter table public.ai_models
      add constraint ai_models_consecutive_failures_check
      check (consecutive_failures >= 0) not valid;
    alter table public.ai_models
      validate constraint ai_models_consecutive_failures_check;
  end if;
end
$body$;

do $body$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'ai_models_measured_latency_ms_check'
      and conrelid = 'public.ai_models'::regclass
  ) then
    alter table public.ai_models
      add constraint ai_models_measured_latency_ms_check
      check (measured_latency_ms is null or measured_latency_ms >= 0) not valid;
    alter table public.ai_models
      validate constraint ai_models_measured_latency_ms_check;
  end if;
end
$body$;

do $body$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'ai_models_recent_success_rate_check'
      and conrelid = 'public.ai_models'::regclass
  ) then
    alter table public.ai_models
      add constraint ai_models_recent_success_rate_check
      check (
        recent_success_rate is null
        or (recent_success_rate >= 0 and recent_success_rate <= 1)
      ) not valid;
    alter table public.ai_models
      validate constraint ai_models_recent_success_rate_check;
  end if;
end
$body$;

commit;
