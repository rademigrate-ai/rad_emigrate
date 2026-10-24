-- Plan 5: AI discovery fail-closed + runtime enabled filter regressions.
begin;

do $$$
declare
  src text;
begin
  select prosrc into src from pg_proc
  where proname = 'ingest_ai_model_catalogue'
    and pronamespace = 'public'::regnamespace
  limit 1;
  if src is null then
    raise notice 'SKIP: ingest_ai_model_catalogue absent';
    return;
  end if;
  if position('enabled = (' in src) > 0 and position('capability' in src) > 0 and position('chat' in src) > 0 and position('enabled = false' in src) = 0 then
    raise exception 'ingest may still auto-enable models without fail-closed literal';
  end if;
  if position('false' in src) = 0 then
    raise exception 'ingest missing enabled=false fail-closed literal';
  end if;
end
$$$;

do $$$
declare
  src text;
begin
  select prosrc into src from pg_proc
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
$$$;

do $$$
declare
  src text;
begin
  select prosrc into src from pg_proc
  where proname = 'get_ai_access_decision'
    and pronamespace = 'public'::regnamespace
  limit 1;
  if src is null then return; end if;
  if position('auth.uid() is distinct from p_user_id' in lower(src)) = 0 then
    raise exception 'get_ai_access_decision missing owner scope';
  end if;
end
$$$;

commit;