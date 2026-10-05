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
                 and position('rejected draft cannot be published' in prosrc)>0) then
    raise exception 'Stage 2 publish RPC lost admin gate or rejection guard';
  end if;
  if private.is_safe_public_https_url('https://127.0.0.1/')
     or private.is_safe_public_https_url('https://10.0.0.1/')
     or private.is_safe_public_https_url('https://169.254.169.254/')
     or private.is_safe_public_https_url('https://metadata.google.internal/')
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
