-- Read-only readiness after canonical initialization; no user data or secrets emitted.
begin read only;
do $$ declare signature text; begin
  assert exists(select 1 from supabase_migrations.schema_migrations where version='20261018211645'),
    'phase24 migration missing from canonical ledger';
  assert not (select enabled from private.payment_sandbox_config where singleton),
    'sandbox payment activation must remain disabled during initialization';
  assert (select relrowsecurity from pg_class where oid='private.mock_checkout_orders'::regclass);
  assert not has_table_privilege('authenticated','private.mock_checkout_orders','SELECT');
  assert not has_table_privilege('service_role','private.mock_checkout_orders','UPDATE');
  foreach signature in array array['public.get_mock_checkout(uuid)','public.create_mock_checkout(uuid)',
    'public.request_mock_checkout_cancellation(uuid)','public.search_admin_consultations(text,text,integer,integer)'] loop
    assert has_function_privilege('authenticated',signature,'EXECUTE');
    assert not has_function_privilege('anon',signature,'EXECUTE');
    assert not has_function_privilege('service_role',signature,'EXECUTE');
  end loop;
  assert has_function_privilege('service_role','public.apply_sandbox_payment_event(jsonb,text)','EXECUTE');
  assert not has_function_privilege('authenticated','public.apply_sandbox_payment_event(jsonb,text)','EXECUTE');
end $$;
select jsonb_build_object('status','PASS','scope','read_only_initialized_schema',
  'migration_count',(select count(*) from supabase_migrations.schema_migrations),
  'sandbox_payments_disabled',true,'remote_deployment_proven',false);
rollback;
