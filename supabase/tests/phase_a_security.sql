-- Disposable CI database only. Synthetic fixtures and all writes roll back.
-- Invoked solely by the loopback-guarded clean-schema / reconstruction jobs.
begin;

do $verify$
declare n integer;
begin
  if has_function_privilege('authenticated','public.consume_ai_daily_quota(uuid,text)','EXECUTE')
     or has_function_privilege('anon','public.consume_ai_daily_quota(uuid,text)','EXECUTE')
     or not has_function_privilege('service_role','public.consume_ai_daily_quota(uuid,text)','EXECUTE') then
    raise exception 'Atomic quota must be service-only';
  end if;
  if has_column_privilege('authenticated','public.consultation_requests','user_id','INSERT')
     or has_column_privilege('authenticated','public.consultation_requests','status','INSERT')
     or has_column_privilege('authenticated','public.consultation_requests','admin_note','SELECT') then
    raise exception 'Consultation direct write/internal note exposure';
  end if;
  if has_function_privilege('anon','public.submit_consultation_request(text,text,uuid)','EXECUTE')
     or has_function_privilege('service_role','public.submit_consultation_request(text,text,uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.submit_consultation_request(text,text,uuid)','EXECUTE') then
    raise exception 'Consultation submit grants invalid';
  end if;
  select count(*) into n from pg_policies where schemaname='storage' and tablename='objects'
    and policyname='documents storage update own' and cmd='UPDATE'
    and roles=array['authenticated']::name[] and qual like '%bucket_id%documents%'
    and qual like '%foldername%uid%' and with_check like '%bucket_id%documents%'
    and with_check like '%foldername%uid%';
  if n<>1 then raise exception 'Storage UPDATE must bind old/new bucket and owner path'; end if;
  select count(*) into n from pg_trigger where not tgisinternal and tgenabled='O'
    and ((tgrelid='public.feed_items'::regclass and tgname='trg_guard_human_feed_item_mutation')
      or (tgrelid='public.feed_item_localizations'::regclass and tgname='trg_guard_human_feed_localization_mutation'));
  if n<>2 then raise exception 'Both active human Feed guards required'; end if;
  select count(*) into n from pg_constraint where conrelid='public.ai_models'::regclass
    and contype='c' and convalidated and conname in ('ai_models_consecutive_failures_check',
      'ai_models_measured_latency_ms_check','ai_models_recent_success_rate_check');
  if n<>3 then raise exception 'Three validated model CHECK constraints required'; end if;
  if exists(select 1 from pg_proc p where p.oid in (
       'public.list_admin_consultations()'::regprocedure,
       'public.update_admin_consultation(uuid,text,text)'::regprocedure,
       'public.get_ai_access_decision(uuid,text)'::regprocedure,
       'public.get_ai_daily_quota_status(uuid,text)'::regprocedure,
       'public.submit_consultation_request(text,text,uuid)'::regprocedure,
       'public.publish_content_draft(uuid,text,text)'::regprocedure)
     and (not p.prosecdef or not p.proconfig @> array['search_path=""']::text[]
          or has_function_privilege('anon',p.oid,'EXECUTE'))) then
    raise exception 'SECURITY DEFINER hardening regressed';
  end if;
end
$verify$;

do $fixture$
declare u uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid();
begin
  perform set_config('request.jwt.claims','{"role":"service_role"}',true);
  insert into auth.users(id,email) values (u,u::text||'@example.invalid'),(other_user,other_user::text||'@example.invalid');
  perform set_config('rad.phase_a.user',u::text,true);
  perform set_config('rad.phase_a.other',other_user::text,true);
  perform set_config('rad.phase_a.feed_count',(select count(*)::text from public.feed_items),true);
  perform set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',u)::text,true);
  -- Support both legacy image auth.uid() and current GoTrue JSON-claim helpers.
  perform set_config('request.jwt.claim.sub',u::text,true);
end
$fixture$;

set local role authenticated;
do $negative$
declare u uuid:=current_setting('rad.phase_a.user')::uuid; other_user uuid:=current_setting('rad.phase_a.other')::uuid; i integer;
begin
  perform public.get_ai_daily_quota_status(u,'super_admin');
  perform public.get_ai_access_decision(u,null);
  begin perform public.get_ai_daily_quota_status(other_user,'super_admin'); raise exception 'Cross-owner quota accepted';
    exception when insufficient_privilege then null; end;
  begin perform public.get_ai_access_decision(other_user,null); raise exception 'Cross-owner entitlement accepted';
    exception when insufficient_privilege then null; end;
  begin perform public.list_admin_consultations(); raise exception 'Non-admin consultation list accepted';
    exception when insufficient_privilege then null; end;
  begin perform public.update_admin_consultation(gen_random_uuid(),'closed',null); raise exception 'Non-admin consultation update accepted';
    exception when insufficient_privilege then null; end;
  begin perform public.consume_ai_daily_quota(u,'super_admin'); raise exception 'Client quota reservation accepted';
    exception when insufficient_privilege then null; end;
  begin perform public.submit_consultation_request('x','too short',null); raise exception 'Invalid consultation accepted';
    exception when invalid_parameter_value then null; end;
  begin perform public.submit_consultation_request('Synthetic test','Synthetic message only',gen_random_uuid()); raise exception 'Foreign application accepted';
    exception when insufficient_privilege then null; end;
  for i in 1..3 loop perform public.submit_consultation_request('Synthetic test','Synthetic message only',null); end loop;
  begin perform public.submit_consultation_request('Synthetic test','Synthetic message only',null); raise exception 'Fourth hourly consultation accepted' using errcode='22023';
    exception when raise_exception then
      if sqlerrm<>'consultation_rate_limited' then raise; end if;
  end;
  begin insert into public.consultation_requests(user_id,topic,message,status) values(u,'Synthetic test','Synthetic message only','submitted');
    raise exception 'Direct consultation INSERT accepted'; exception when insufficient_privilege then null; end;
end
$negative$;
reset role;

do $daily$
declare u uuid:=current_setting('rad.phase_a.other')::uuid; p uuid; m uuid;
begin
  perform set_config('request.jwt.claims','{"role":"service_role"}',true);
  insert into public.consultation_requests(user_id,topic,message,status,created_at)
    select u,'Synthetic daily test','Synthetic message only','submitted',now()-interval '2 hours' from generate_series(1,10);
  insert into public.ai_providers(slug,display_name,adapter,base_url,enabled)
    values('phase_a_'||replace(u::text,'-',''),'Synthetic CHECK fixture','openai_compatible','https://example.invalid',false) returning id into p;
  insert into public.ai_models(provider_id,slug,display_name,capability,enabled)
    values(p,'phase-a','Synthetic CHECK fixture','chat',false) returning id into m;
  begin update public.ai_models set consecutive_failures=-1 where id=m; raise exception 'Negative failures accepted';
    exception when check_violation then null; end;
  begin update public.ai_models set measured_latency_ms=-1 where id=m; raise exception 'Negative latency accepted';
    exception when check_violation then null; end;
  begin update public.ai_models set recent_success_rate=1.1 where id=m; raise exception 'Invalid success rate accepted';
    exception when check_violation then null; end;
  perform set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',u)::text,true);
  perform set_config('request.jwt.claim.sub',u::text,true);
end
$daily$;
set local role authenticated;
do $daily_denial$
begin
  begin perform public.submit_consultation_request('Synthetic daily test','Synthetic message only',null);
    raise exception 'Eleventh daily consultation accepted' using errcode='22023';
  exception when raise_exception then if sqlerrm<>'consultation_rate_limited' then raise; end if; end;
end
$daily_denial$;
reset role;
do $no_publish$
begin
  if (select count(*) from public.feed_items)<>current_setting('rad.phase_a.feed_count')::integer then
    raise exception 'Consultation caused Feed publication';
  end if;
end
$no_publish$;
rollback;
