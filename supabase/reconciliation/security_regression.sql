-- Disposable database only; never invoked against production.
do $verify$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
             where n.nspname='public' and c.relkind='r' and not c.relrowsecurity) then
    raise exception 'RLS missing';
  end if;
  if has_column_privilege('authenticated','public.profiles','role','UPDATE') then
    raise exception 'Profile role self-elevation permission';
  end if;
  if not exists (select 1 from pg_proc where oid='private.has_role(text[])'::regprocedure
                 and prosecdef and proconfig @> array['search_path=""']) then
    raise exception 'Role helper not hardened';
  end if;
  if has_function_privilege('anon','public.set_user_role(uuid,text)','EXECUTE') then
    raise exception 'Anonymous privileged RPC';
  end if;
  if has_table_privilege('anon','public.research_worker_config','SELECT')
     or has_table_privilege('authenticated','public.research_worker_config','SELECT') then
    raise exception 'Worker configuration client-readable';
  end if;
  if has_table_privilege('anon','vault.decrypted_secrets','SELECT')
     or has_table_privilege('authenticated','vault.decrypted_secrets','SELECT') then
    raise exception 'Vault client-readable';
  end if;
  if has_function_privilege('authenticated','public.get_ai_runtime_chain(text)','EXECUTE')
     or has_function_privilege('anon','public.get_ai_runtime_chain(text)','EXECUTE') then
    raise exception 'Provider runtime client exposure';
  end if;
  if has_function_privilege('authenticated','public.get_ai_runtime_chain(text,text)','EXECUTE')
     or has_function_privilege('anon','public.get_ai_runtime_chain(text,text)','EXECUTE')
     or has_function_privilege('authenticated','public.get_ai_provider_runtime(uuid)','EXECUTE')
     or has_function_privilege('anon','public.get_ai_provider_runtime(uuid)','EXECUTE')
     or has_function_privilege('authenticated','public.create_research_review_candidate(uuid,uuid,text,text,text)','EXECUTE')
     or has_function_privilege('anon','public.create_research_review_candidate(uuid,uuid,text,text,text)','EXECUTE') then
    raise exception 'Stage 1 service runtime client exposure';
  end if;
  -- Stage 2: publish/review RPCs must never be executable by anon.
  if has_function_privilege('anon','public.publish_content_draft(uuid,text,text)','EXECUTE')
     or has_function_privilege('anon','public.set_content_draft_status(uuid,text)','EXECUTE')
     or has_function_privilege('anon','public.update_content_draft(uuid,text,text,text,text)','EXECUTE')
     or has_function_privilege('anon','public.set_research_finding_status(uuid,text)','EXECUTE') then
    raise exception 'Stage 2 publish/review RPC exposed to anon';
  end if;
  if not exists (select 1 from pg_proc where oid='public.publish_content_draft(uuid,text,text)'::regprocedure
                 and prosecdef and proconfig @> array['search_path=""']
                 and position('admin' in prosrc)>0
                 and position('explicit approval' in prosrc)>0
                 and position('rad.human_publish_actor' in prosrc)>0) then
    raise exception 'Publish RPC lost human approval or mutation guard';
  end if;
  if has_table_privilege('authenticated','public.feed_items','INSERT')
     or has_table_privilege('authenticated','public.feed_items','UPDATE')
     or has_table_privilege('authenticated','public.feed_item_localizations','INSERT')
     or has_table_privilege('authenticated','public.content_drafts','UPDATE') then
    raise exception 'Direct draft approval or Feed mutation privilege remains';
  end if;
  if not exists (select 1 from pg_trigger
                 where tgrelid='public.feed_items'::regclass
                   and tgname='trg_guard_human_feed_item_mutation'
                   and not tgisinternal) then
    raise exception 'Feed human mutation trigger missing';
  end if;
  if has_column_privilege('authenticated','public.consultation_requests','admin_note','SELECT')
     or has_column_privilege('authenticated','public.consultation_requests','assigned_to','SELECT')
     or not has_column_privilege('authenticated','public.consultation_requests','status','SELECT') then
    raise exception 'Consultation internal/public column privilege boundary invalid';
  end if;
  if not exists (select 1 from pg_proc
                 where oid='public.get_ai_access_decision(uuid,text)'::regprocedure
                   and prosecdef and position('auth.uid() is distinct from p_user_id' in prosrc)>0)
     or not exists (select 1 from pg_proc
                    where oid='public.get_ai_daily_quota_status(uuid,text)'::regprocedure
                      and prosecdef and position('auth.uid() is distinct from p_user_id' in prosrc)>0) then
    raise exception 'Entitlement or quota RPC accepts arbitrary target user';
  end if;
  if not exists (
    select 1
    from pg_proc
    where oid = 'public.consume_ai_daily_quota(uuid,text)'::regprocedure
      and prosecdef
      and position('pg_advisory_xact_lock' in prosrc) > 0
      and position('insert into public.ai_requests' in lower(prosrc)) > 0
  ) then
    raise exception 'Authenticated AI quota reservation is not atomic';
  end if;
  if not exists (select 1 from pg_proc
                 where oid='private.prevent_profile_role_escalation()'::regprocedure
                   and prosecdef
                   and position('service_role' in prosrc)>0
                   and position('super_admin' in prosrc)>0) then
    raise exception 'Role bootstrap or authenticated escalation guard missing';
  end if;
  if private.is_safe_public_https_url('https://127.0.0.1/')
     or private.is_safe_public_https_url('https://10.0.0.1/')
     or private.is_safe_public_https_url('https://169.254.169.254/')
     or private.is_safe_public_https_url('https://metadata.google.internal/')
     or private.is_safe_public_https_url('https://[::ffff:169.254.169.254]/')
     or private.is_safe_public_https_url('https://[::ffff:127.0.0.1]/')
     or private.is_safe_public_https_url('https://[0:0:0:0:0:ffff:a9fe:a9fe]/')
     or private.is_safe_public_https_url('https://[0:0:0:0:0:0:7f00:1]/')
     or not private.is_safe_public_https_url('https://api.openai.com/v1') then
    raise exception 'Existing SSRF regression';
  end if;
  if not exists (select 1 from pg_proc where oid='public.configure_ai_provider(text,text,text,text,text,boolean,integer)'::regprocedure
                 and position('private.is_safe_public_https_url' in prosrc)>0
                 and position('super_admin' in prosrc)>0) then
    raise exception 'Privileged provider RPC lost SSRF/role gates';
  end if;
end
$verify$;
