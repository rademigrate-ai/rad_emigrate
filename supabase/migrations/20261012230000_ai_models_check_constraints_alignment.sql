-- Forward-only alignment: add missing CHECK constraints on public.ai_models
-- that exist in the repository historical alias of ai_dynamic_routing_architecture
-- but were not present as named constraints on production (columns already exist).
-- Safe, additive, NOT VALID then VALIDATE pattern to avoid long exclusive locks
-- on large tables. Does not alter data, columns, or existing constraints.
--
-- Preflight (run before apply):
--   select count(*) from public.ai_models
--     where consecutive_failures < 0
--        or (measured_latency_ms is not null and measured_latency_ms < 0)
--        or (recent_success_rate is not null
--            and (recent_success_rate < 0 or recent_success_rate > 1));
-- Expect 0 rows. Abort if non-zero.
begin;

alter table public.ai_models
  drop constraint if exists ai_models_consecutive_failures_check;
alter table public.ai_models
  add constraint ai_models_consecutive_failures_check
  check (consecutive_failures >= 0) not valid;
alter table public.ai_models
  validate constraint ai_models_consecutive_failures_check;

alter table public.ai_models
  drop constraint if exists ai_models_measured_latency_ms_check;
alter table public.ai_models
  add constraint ai_models_measured_latency_ms_check
  check (measured_latency_ms is null or measured_latency_ms >= 0) not valid;
alter table public.ai_models
  validate constraint ai_models_measured_latency_ms_check;

alter table public.ai_models
  drop constraint if exists ai_models_recent_success_rate_check;
alter table public.ai_models
  add constraint ai_models_recent_success_rate_check
  check (
    recent_success_rate is null
    or (recent_success_rate >= 0 and recent_success_rate <= 1)
  ) not valid;
alter table public.ai_models
  validate constraint ai_models_recent_success_rate_check;

commit;
