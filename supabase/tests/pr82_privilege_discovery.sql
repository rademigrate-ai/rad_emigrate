-- Disposable synthetic regression. Never execute against hosted projects.
begin;
do $acl$
declare t text; r text; p text;
begin
 foreach t in array array['admin_case_notes','admin_saved_views','admin_tasks',
  'ai_entitlements','application_status_history','consultation_requests'] loop
  foreach r in array array['anon','authenticated'] loop
   foreach p in array array['TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'] loop
    if has_table_privilege(r,'public.'||t,p)
      or has_any_column_privilege(r,'public.'||t,'REFERENCES') then
     raise exception 'nonrow privilege % % %',r,t,p;
    end if;
   end loop;
  end loop;
 end loop;
 if not has_table_privilege('authenticated','public.admin_tasks','UPDATE')
   or not has_table_privilege('service_role','public.admin_tasks','TRUNCATE') then
  raise exception 'required application/service grant missing';
 end if;
end $acl$;

-- Real SQL execution denials; RLS is not used as a substitute for ACLs.
create table public.pr82_reference_probe(id uuid);
create function public.pr82_trigger_probe() returns trigger language plpgsql as
 $$begin return new; end$$;
grant create on schema public to anon,authenticated;
set local role anon;
do $deny$ begin
 begin truncate public.admin_tasks; raise exception 'anon truncate accepted';
 exception when insufficient_privilege then null; end;
 begin create table public.pr82_anon_fk(id uuid references public.admin_tasks(id));
  raise exception 'anon references accepted'; exception when insufficient_privilege then null; end;
 begin create trigger pr82_probe before insert on public.admin_tasks for each row execute function public.pr82_trigger_probe();
  raise exception 'anon trigger accepted'; exception when insufficient_privilege then null; end;
end $deny$;
reset role;
set local role authenticated;
do $deny$ begin
 begin truncate public.admin_tasks; raise exception 'authenticated truncate accepted';
 exception when insufficient_privilege then null; end;
 begin create table public.pr82_user_fk(id uuid references public.admin_tasks(id));
  raise exception 'authenticated references accepted'; exception when insufficient_privilege then null; end;
 begin create trigger pr82_probe before insert on public.admin_tasks for each row execute function public.pr82_trigger_probe();
  raise exception 'authenticated trigger accepted'; exception when insufficient_privilege then null; end;
end $deny$;
reset role;

insert into public.ai_providers(id,slug,display_name,adapter,base_url,enabled,credential_version)
 values('a8200000-0000-4000-8000-000000000015','pr82_synthetic_discovery',
 'SYNTHETIC NEVER CONTACT','openai_compatible','https://example.invalid',true,1);
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $discovery$
declare provider uuid:='a8200000-0000-4000-8000-000000000015';
 models jsonb:='[{"slug":"SYNTHETIC-CHAT","capability":"chat","context_window":8000,"supports_tools":false,"supports_structured_output":false,"capability_source":"discovered","cost_input_per_million":0,"cost_source":"unknown"}]';
begin
 perform public.ingest_ai_model_catalogue(provider,1,models);
 if (select enabled from public.ai_models where provider_id=provider and slug='SYNTHETIC-CHAT') then
  raise exception 'new discovery enabled'; end if;
 perform public.ingest_ai_model_catalogue(provider,1,models);
 if (select enabled from public.ai_models where provider_id=provider and slug='SYNTHETIC-CHAT') then
  raise exception 'disabled rediscovery enabled'; end if;
 update public.ai_models set enabled=true,runtime_scope='research',priority=17,
  capability_source='configured',context_window=12345,cost_source='configured',cost_input_per_million=7
  where provider_id=provider and slug='SYNTHETIC-CHAT';
 perform public.ingest_ai_model_catalogue(provider,1,models);
 if not exists(select 1 from public.ai_models where provider_id=provider and slug='SYNTHETIC-CHAT'
  and enabled and runtime_scope='research' and priority=17 and context_window=12345
  and capability_source='configured' and cost_input_per_million=7 and cost_source='configured') then
  raise exception 'explicit Admin decisions overwritten'; end if;
 perform public.ingest_ai_model_catalogue(provider,1,'[]');
 if not exists(select 1 from public.ai_models where provider_id=provider and slug='SYNTHETIC-CHAT'
  and enabled and not available and discovery_status='stale') then
  raise exception 'missing model changed approval or availability incorrect'; end if;
 perform public.ingest_ai_model_catalogue(provider,1,models);
 update public.ai_models set enabled=false where provider_id=provider and slug='SYNTHETIC-CHAT';
 perform public.ingest_ai_model_catalogue(provider,1,models);
 if (select enabled from public.ai_models where provider_id=provider and slug='SYNTHETIC-CHAT') then
  raise exception 'explicit disable lost'; end if;
 update public.ai_providers set enabled=false where id=provider;
 begin perform public.ingest_ai_model_catalogue(provider,1,models);
  raise exception 'disabled provider accepted'; exception when insufficient_privilege then null; end;
 if (select enabled from public.ai_models where provider_id=provider and slug='SYNTHETIC-CHAT') then
  raise exception 'provider disable changed model approval'; end if;
 update public.ai_providers set enabled=true where id=provider;
 begin perform public.ingest_ai_model_catalogue(provider,2,models);
  raise exception 'stale credential accepted'; exception when serialization_failure then null; end;
 begin perform public.ingest_ai_model_catalogue(provider,1,null);
  raise exception 'null catalogue accepted'; exception when invalid_parameter_value then null; end;
 perform set_config('request.jwt.claims','{"role":"authenticated"}',true);
 begin perform public.ingest_ai_model_catalogue(provider,1,models);
  raise exception 'ordinary user discovery accepted'; exception when insufficient_privilege then null; end;
 if has_function_privilege('anon','public.ingest_ai_model_catalogue(uuid,bigint,jsonb)','EXECUTE')
  or has_function_privilege('authenticated','public.ingest_ai_model_catalogue(uuid,bigint,jsonb)','EXECUTE') then
  raise exception 'discovery callable by clients'; end if;
end $discovery$;
rollback;
select 'PASS: targeted nonrow ACL and fail-closed discovery assertions; no provider contacted; rolled back';
