-- Clients and service workers must use the public role-checking ingestion RPC,
-- never the internal proof-lock helper directly. All probes roll back.
begin;
do $$begin
 assert not has_function_privilege('anon','private.rad_lock_bound_refresh_authority(private.rad_official_refresh_bindings,text)','EXECUTE'),'anonymous must not lock authority rows';
 assert not has_function_privilege('authenticated','private.rad_lock_bound_refresh_authority(private.rad_official_refresh_bindings,text)','EXECUTE'),'Admin client must not bypass worker ingestion';
 assert not has_function_privilege('service_role','private.rad_lock_bound_refresh_authority(private.rad_official_refresh_bindings,text)','EXECUTE'),'worker must use guarded public ingestion';
 assert has_function_privilege('service_role','public.ingest_bound_official_refresh(uuid,uuid,uuid,uuid,uuid,text,text,text,integer)','EXECUTE'),'worker ingestion remains available';
end $$;
set local role authenticated;
do $$begin
 begin
  perform private.rad_lock_bound_refresh_authority(null::private.rad_official_refresh_bindings,'https://synthetic.example.invalid/');
  raise exception 'FAIL direct client authority lock';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role service_role;
do $$begin
 begin
  perform private.rad_lock_bound_refresh_authority(null::private.rad_official_refresh_bindings,'https://synthetic.example.invalid/');
  raise exception 'FAIL direct worker authority lock';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
