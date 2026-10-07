-- Disposable CI database only. All fixtures roll back.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$
declare a uuid; b uuid; m uuid; n uuid; secret uuid; doc uuid; job uuid; finding uuid;
 v_count int; v_score int; old_score int; feed_count int; actor uuid := gen_random_uuid();
begin
 secret:=vault.create_secret('test-only-routing-credential');
 insert into public.ai_providers(slug,display_name,adapter,base_url,secret_id,enabled,priority)
 values('regression_a','Regression A','openai_compatible','https://a.example.com',secret,true,100) returning id into a;
 insert into public.ai_providers(slug,display_name,adapter,base_url,secret_id,enabled,priority)
 values('regression_b','Regression B','openai_compatible','https://b.example.com',secret,true,100) returning id into b;
 insert into public.ai_provider_health(provider_id,status) values(a,'healthy'),(b,'healthy');
 insert into public.ai_models(provider_id,slug,display_name,capability,enabled,available,priority,supports_tools,context_window)
 values(a,'first','First','chat',true,true,10,true,64000) returning id into m;
 insert into public.ai_models(provider_id,slug,display_name,capability,enabled,available,priority)
 values(b,'second','Second','chat',true,true,10) returning id into n;
 select count(*) into v_count from public.get_ai_runtime_chain('chat','user',true,false,32000) where provider_id in(a,b);
 if v_count<>1 then raise exception '10 incompatible capability/context admitted'; end if;
 update public.ai_models set available=false where id=m;
 if exists(select from public.get_ai_runtime_chain('chat','user',false,false,null) where model_id=m) then raise exception '02 unavailable model admitted'; end if;
 update public.ai_models set available=true where id=m;
 select routing_score into old_score from public.get_ai_runtime_chain('chat','user',false,false,null) where model_id=m;
 update public.ai_models set measured_latency_ms=9000,recent_success_rate=0.1 where id=m;
 select routing_score into v_score from public.get_ai_runtime_chain('chat','user',false,false,null) where model_id=m;
 if v_score<=old_score then raise exception 'Measured signals did not affect ranking'; end if;
 perform public.record_ai_provider_outcome(a,1,'provider_unauthorized',false);
 if exists(select from public.get_ai_runtime_chain('chat','user',false,false,null) where provider_id=a) then raise exception '08 rejected credential admitted'; end if;
 if not exists(select from public.get_ai_runtime_chain('chat','user',false,false,null) where provider_id=b) then raise exception '08 healthy alternate lost'; end if;
 perform public.record_ai_provider_outcome(a,1,null,false);
 if not (select credential_rejected from public.ai_provider_health where provider_id=a) then raise exception 'Normal success cleared auth latch'; end if;
 perform public.record_ai_provider_outcome(a,1,null,true);
 if (select credential_rejected from public.ai_provider_health where provider_id=a) then raise exception 'Explicit revalidation failed'; end if;
 update public.ai_providers set credential_version=2 where id=a;
 perform public.record_ai_provider_outcome(a,1,'provider_unauthorized',false);
 if (select credential_rejected from public.ai_provider_health where provider_id=a) then raise exception 'Old in-flight outcome poisoned new credential'; end if;
 perform public.record_ai_provider_outcome(a,2,'provider_rate_limited',false);
 if exists(select from public.get_ai_runtime_chain('chat','user',false,false,null) where provider_id=a) then raise exception '11 cooldown not enforced'; end if;
 update public.ai_provider_health set cooldown_until=now()-interval '1 second' where provider_id=a;
 if not exists(select from public.get_ai_runtime_chain('chat','user',false,false,null) where provider_id=a) then raise exception '12 expired provider cooldown did not recover'; end if;
 perform public.record_ai_model_outcome(m,false,10,'provider_timeout');
 if exists(select from public.get_ai_runtime_chain('chat','user',false,false,null) where model_id=m) then raise exception '11 model cooldown not enforced'; end if;
 update public.ai_models set cooldown_until=now()-interval '1 second' where id=m;
 if not exists(select from public.get_ai_runtime_chain('chat','user',false,false,null) where model_id=m) then raise exception '12 model did not recover'; end if;
 if has_function_privilege('authenticated','public.get_ai_runtime_chain_versioned(text,text,boolean,boolean,integer)','execute')
 or has_function_privilege('anon','public.get_ai_provider_runtime_versioned(uuid)','execute')
 or has_function_privilege('authenticated','public.record_ai_provider_outcome(uuid,bigint,text,boolean)','execute')
 or has_function_privilege('authenticated','public.ingest_research_snapshot(uuid,uuid,text,text,integer,jsonb)','execute') then raise exception '16 privileged RPC exposed'; end if;
 -- Exercise catalogue upsert against real SQL, preserving configured facts.
 update public.ai_models set runtime_scope='admin',priority=7,capability_source='configured',
  context_window=64000,supports_tools=true,cost_source='configured',cost_input_per_million=3 where id=m;
 perform public.ingest_ai_model_catalogue(a,2,
  '[{"slug":"first","capability":"chat","context_window":1000,"supports_tools":false,"supports_structured_output":false,"capability_source":"discovered","cost_input_per_million":9,"cost_source":"discovered"},
    {"slug":"new-model","capability":"chat","context_window":8000,"supports_tools":false,"supports_structured_output":false,"capability_source":"discovered","cost_input_per_million":null,"cost_source":"unknown"}]'::jsonb);
 if not exists(select from public.ai_models where id=m and enabled and runtime_scope='admin' and priority=7
  and context_window=64000 and supports_tools and capability_source='configured' and cost_input_per_million=3 and cost_source='configured')
 then raise exception 'Discovery overwrote configured capabilities or preferences'; end if;
 if not exists(select from public.ai_models where provider_id=a and slug='new-model' and not enabled and available)
 then raise exception 'Discovery did not safely add disabled model'; end if;
 perform public.ingest_ai_model_catalogue(a,2,'[]'::jsonb);
 if not exists(select from public.ai_models where id=m and enabled and not available and discovery_status='stale')
 then raise exception 'Missing discovered model was deleted or remained eligible'; end if;
 -- Disposable trusted-role fixture; no JWT metadata authorizes this role.
 insert into auth.users(id,email) values(actor,'corrective-regression@example.invalid');
 delete from public.profiles where id=actor;
 insert into public.profiles(id,email,role) values(actor,'corrective-regression@example.invalid','super_admin');
 perform set_config('request.jwt.claims',jsonb_build_object('role','service_role','sub',actor)::text,true);
 perform public.record_ai_provider_outcome(a,2,'provider_unauthorized',false);
 perform public.configure_ai_provider('regression_a','Regression A','openai_compatible','https://a.example.com','',true,100);
 if not (select credential_rejected from public.ai_provider_health where provider_id=a)
 then raise exception 'Blank key cleared rejection latch'; end if;
 perform public.configure_ai_provider('regression_a','Regression A','openai_compatible','https://a.example.com','test-only-routing-credential',true,100);
 if not (select credential_rejected from public.ai_provider_health where provider_id=a)
  or (select credential_version from public.ai_providers where id=a)<>2
 then raise exception 'Unchanged key cleared rejection latch or changed version'; end if;
 perform public.configure_ai_provider('regression_a','Regression A','openai_compatible','https://a.example.com','test-only-new-credential',true,100);
 if (select credential_rejected from public.ai_provider_health where provider_id=a)
  or (select credential_version from public.ai_providers where id=a)<>3
 then raise exception 'Changed key failed to renew eligibility'; end if;
 select count(*) into feed_count from public.feed_items;
 insert into public.source_documents(canonical_url,source_authority,title,language_code)
 values('https://evidence.example.com/test','other','Regression evidence','en') returning id into doc;
 insert into public.research_jobs(job_type,trigger_type,idempotency_key)
 values('official_source_refresh','manual','corrective-regression') returning id into job;
 finding:=public.ingest_research_snapshot(job,doc,'hash1','Actual fixture evidence',200,'{}');
 if (select count(*) from public.content_drafts where research_finding_id=finding and status='review')<>1 then raise exception 'Finding did not atomically create review draft'; end if;
 perform public.ingest_research_snapshot(job,doc,'hash1','Actual fixture evidence',200,'{}');
 if (select count(*) from public.content_drafts where research_finding_id=finding)<>1 then raise exception 'Duplicate candidate'; end if;
 if (select count(*) from public.feed_items)<>feed_count then raise exception 'Research auto-published'; end if;
end $$;
rollback;
