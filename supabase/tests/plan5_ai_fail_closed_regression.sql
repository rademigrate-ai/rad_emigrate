-- Plan 5: AI discovery fail-closed + runtime enabled filter + owner-scope regressions.
-- Disposable / CI clean-schema only. Never run destructive tests on Production.

begin;

-- 1) ingest_ai_model_catalogue must fail-closed: new models not auto-enabled
do $plan5$
declare
  src text;
begin
  select prosrc into src
  from pg_proc
  where proname = 'ingest_ai_model_catalogue'
    and pronamespace = 'public'::regnamespace
  limit 1;

  if src is null then
    raise notice 'SKIP: ingest_ai_model_catalogue absent';
    return;
  end if;

  -- Historical fail-open pattern: enabled = (capability = 'chat')
  if position('enabled = (x.capability' in src) > 0
     or position('enabled = (capability' in src) > 0 then
    raise exception 'ingest still uses capability-based auto-enable (fail-open)';
  end if;

  -- Require explicit disabled default for inserts
  if position('false' in src) = 0 then
    raise exception 'ingest missing enabled=false fail-closed literal';
  end if;
end
$plan5$;

-- 2) get_ai_runtime_chain must filter enabled models/providers
do $plan5$
declare
  src text;
begin
  select prosrc into src
  from pg_proc
  where proname = 'get_ai_runtime_chain'
    and pronamespace = 'public'::regnamespace
    and position('routing_score' in prosrc) > 0
  limit 1;

  if src is null then
    raise notice 'SKIP: get_ai_runtime_chain absent';
    return;
  end if;

  if position('enabled' in src) = 0 then
    raise exception 'runtime chain missing enabled filter';
  end if;
end
$plan5$;

-- 3) get_ai_access_decision must be owner-scoped (no cross-user quota reads)
do $plan5$
declare
  src text;
begin
  select prosrc into src
  from pg_proc
  where proname = 'get_ai_access_decision'
    and pronamespace = 'public'::regnamespace
  limit 1;

  if src is null then
    raise notice 'SKIP: get_ai_access_decision absent';
    return;
  end if;

  if position('auth.uid() is distinct from p_user_id' in lower(src)) = 0
     and position('auth.uid() is not distinct from p_user_id' in lower(src)) = 0 then
    raise exception 'get_ai_access_decision missing owner-scope check';
  end if;
end
$plan5$;

commit;