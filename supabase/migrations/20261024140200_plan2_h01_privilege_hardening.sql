-- Plan 2 H01: narrow excessive table privileges for sensitive admin/ops tables.
-- Does not weaken RLS. Preserves service_role. Consultation writes stay via RPC.
begin;

-- Admin-only operational tables: clients must not hold table-level DML/DDL.
do $h01$
declare
  t text;
begin
  foreach t in array array[
    'admin_case_notes',
    'admin_saved_views',
    'admin_tasks',
    'ai_entitlements',
    'application_status_history'
  ]
  loop
    if to_regclass(format('public.%I', t)) is not null then
      execute format('revoke all on table public.%I from public, anon, authenticated', t);
      -- Authenticated may need SELECT under RLS for own application history only.
      if t = 'application_status_history' then
        execute format('grant select on table public.%I to authenticated', t);
      end if;
      execute format('grant all on table public.%I to service_role', t);
    end if;
  end loop;
end
$h01$;

-- consultation_requests: keep SELECT for owner via RLS; no direct INSERT for clients
-- (submit goes through submit_consultation_request SECURITY DEFINER).
if to_regclass('public.consultation_requests') is not null then
  revoke all on table public.consultation_requests from public, anon;
  revoke insert, update, delete, truncate, references, trigger on table public.consultation_requests from authenticated;
  grant select on table public.consultation_requests to authenticated;
  grant all on table public.consultation_requests to service_role;
end if;

-- Defense in depth: strip non-row privileges that RLS cannot constrain (PG17).
do $nonrow$
declare
  r record;
begin
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p')
      and c.relname in (
        'admin_case_notes','admin_saved_views','admin_tasks',
        'ai_entitlements','application_status_history','consultation_requests',
        'booking_requests','interview_requests','service_catalog',
        'service_catalog_localizations'
      )
  loop
    execute format(
      'revoke truncate, references, trigger on table public.%I from public, anon, authenticated',
      r.relname
    );
  end loop;
end
$nonrow$;

commit;
