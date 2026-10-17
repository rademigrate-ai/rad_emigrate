-- DISPOSABLE CI DATABASE ONLY. Simulate the historical missing-CHECK case,
-- execute the unchanged fifth migration, and require exact schema restoration.
-- Not a production procedure. No rows or ledger entries are changed.
\set ON_ERROR_STOP on
\if :{?phase_a_migration}
\else
\set phase_a_migration ../migrations/20261012230000_ai_models_check_constraints_alignment.sql
\endif
create temporary table phase_a_checks_before as
  select conname,pg_get_constraintdef(oid,true) as definition
  from pg_constraint where conrelid='public.ai_models'::regclass
    and conname in ('ai_models_consecutive_failures_check',
      'ai_models_measured_latency_ms_check','ai_models_recent_success_rate_check');
create temporary table phase_a_counts_before as
  select (select count(*) from public.ai_models) as models,
         (select count(*) from supabase_migrations.schema_migrations) as ledger;
do $$ begin
  if (select count(*) from phase_a_checks_before)<>3 then raise exception 'Expected three baseline CHECKs'; end if;
end $$;
alter table public.ai_models drop constraint ai_models_consecutive_failures_check;
alter table public.ai_models drop constraint ai_models_measured_latency_ms_check;
alter table public.ai_models drop constraint ai_models_recent_success_rate_check;
\ir :phase_a_migration
do $$
declare n integer;
begin
  select count(*) into n from pg_constraint where conrelid='public.ai_models'::regclass
    and convalidated and conname in ('ai_models_consecutive_failures_check',
      'ai_models_measured_latency_ms_check','ai_models_recent_success_rate_check');
  if n<>3 then raise exception 'Backfill did not restore three validated CHECKs'; end if;
  if exists(select * from phase_a_checks_before except
      select conname,pg_get_constraintdef(oid,true) from pg_constraint where conrelid='public.ai_models'::regclass)
    then raise exception 'Backfilled CHECK definition differs'; end if;
  if (select count(*) from public.ai_models)<>(select models from phase_a_counts_before)
     or (select count(*) from supabase_migrations.schema_migrations)<>(select ledger from phase_a_counts_before)
    then raise exception 'Backfill changed rows or migration history'; end if;
end $$;
drop table phase_a_checks_before,phase_a_counts_before;
