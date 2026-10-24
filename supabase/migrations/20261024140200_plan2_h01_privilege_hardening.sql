-- Plan 2 H01: narrow excessive table privileges for sensitive admin/ops tables.
-- Does not weaken RLS. Preserves service_role. Consultation writes stay via RPC.
begin;

do $$
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
      if t = 'application_status_history' then
        execute format('grant select on table public.%I to authenticated', t);
      end if;
      execute format('grant all on table public.%I to service_role', t);
    end if;
  end loop;

  if to_regclass('public.consultation_requests') is not null then
    execute 'revoke all on table public.consultation_requests from public, anon';
    execute 'revoke insert, update, delete, truncate, references, trigger on table public.consultation_requests from authenticated';
    execute 'grant select on table public.consultation_requests to authenticated';
    execute 'grant all on table public.consultation_requests to service_role';
  end if;
end
$$;

do $$
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
$$;

commit;