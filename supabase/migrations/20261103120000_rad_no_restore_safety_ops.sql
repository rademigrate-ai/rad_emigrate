-- No-Restore safety operations. Prepared for independent review; this migration
-- performs no Production content import, approval, publication or reversal.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

create table if not exists private.rad_function_state_receipts(
 id bigint generated always as identity primary key,
 package_sha256 text not null check(package_sha256~'^[a-f0-9]{64}$'),
 scope text not null check(scope in('reviewed_forward','manual_review')),
 actor_id uuid not null references auth.users(id),
 state jsonb not null,
 state_sha256 text not null check(state_sha256~'^[a-f0-9]{64}$'),
 created_at timestamptz not null default now(),
 unique(package_sha256,scope)
);
alter table private.rad_function_state_receipts enable row level security;
revoke all on private.rad_function_state_receipts from public,anon,authenticated,service_role;
create trigger rad_function_state_receipts_immutable before update or delete
 on private.rad_function_state_receipts for each row execute function private.rad_immutable();

create table if not exists private.rad_function_state_members(
 receipt_id bigint not null references private.rad_function_state_receipts(id),
 identity text not null,
 definition text not null,
 owner_name text not null,
 language_name text not null,
 security_definer boolean not null,
 volatile_code "char" not null,
 config text[] not null default '{}',
 grants jsonb not null,
 dependencies jsonb not null,
 definition_sha256 text not null check(definition_sha256~'^[a-f0-9]{64}$'),
 primary key(receipt_id,identity)
);
alter table private.rad_function_state_members enable row level security;
revoke all on private.rad_function_state_members from public,anon,authenticated,service_role;
create trigger rad_function_state_members_immutable before update or delete
 on private.rad_function_state_members for each row execute function private.rad_immutable();

create table if not exists private.rad_function_reversal_receipts(
 receipt_id bigint generated always as identity primary key,
 source_receipt_id bigint not null references private.rad_function_state_receipts(id),
 actor_id uuid not null references auth.users(id),
 action text not null check(action='reviewed_function_state_restore'),
 note text not null check(length(btrim(note))>=20),
 restored_count integer not null check(restored_count>=0),
 created_at timestamptz not null default now()
);
alter table private.rad_function_reversal_receipts enable row level security;
revoke all on private.rad_function_reversal_receipts from public,anon,authenticated,service_role;
create trigger rad_function_reversal_receipts_immutable before update or delete
 on private.rad_function_reversal_receipts for each row execute function private.rad_immutable();

create table if not exists private.rad_source_unpublish_receipts(
 id bigint generated always as identity primary key,
 batch_id uuid not null references private.rad_source_editorial_batches(id),
 actor_id uuid not null references auth.users(id),
 operation text not null check(operation='unpublish_source_editorial_batch'),
 manifest_sha256 text not null check(manifest_sha256~'^[a-f0-9]{64}$'),
 reversed_count integer not null check(reversed_count>=0),
 created_at timestamptz not null default now(),
 unique(batch_id)
);
alter table private.rad_source_unpublish_receipts enable row level security;
revoke all on private.rad_source_unpublish_receipts from public,anon,authenticated,service_role;
create trigger rad_source_unpublish_receipts_immutable before update or delete
 on private.rad_source_unpublish_receipts for each row execute function private.rad_immutable();

alter table public.visa_article_revision_events
 drop constraint visa_article_revision_events_state_check,
 add constraint visa_article_revision_events_state_check check(state in('draft','review','approved','rejected','published','archived','unpublished')),
 drop constraint rad_source_event_basis_check,
 add constraint rad_source_event_basis_check check(
  (publication_basis='standard_editorial' and source_batch_id is null)
  or (publication_basis='source_faithful' and source_batch_id is not null and state in('approved','published','unpublished')));

-- Capture exact current function runtime state. The caller supplies the release
-- package hash and a reviewed scope; the function never invents a reviewer or
-- executes a restore by itself.
create or replace function private.rad_capture_function_state(
 p_package_sha256 text,p_scope text,p_function_signatures text[]
) returns bigint language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();rid bigint;state jsonb;members jsonb;
 fn record;grant_record record;deps jsonb;existing_sha text;begin
 if p_package_sha256 is null or p_package_sha256!~'^[a-f0-9]{64}$'
 or p_scope not in('reviewed_forward','manual_review')
 or p_function_signatures is null or cardinality(p_function_signatures)=0
 or cardinality(p_function_signatures)<>(select count(distinct x) from unnest(p_function_signatures)x)
 then raise exception 'function_state_scope_required' using errcode='PT422';end if;
 members:='[]'::jsonb;
 for fn in select p.oid,p.proname,n.nspname schema_name,pg_get_userbyid(p.proowner) owner_name,
  l.lanname language_name,p.prosecdef security_definer,p.provolatile volatile_code,
  coalesce(p.proconfig,'{}'::text[]) config,p.proacl acl_items,pg_get_functiondef(p.oid) definition,
  p.oid::regprocedure::text identity
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
  where p.oid::regprocedure::text=any(p_function_signatures) order by identity loop
  members:=members||jsonb_build_array(jsonb_build_object(
   'identity',fn.identity,'definition',fn.definition,'owner_name',fn.owner_name,'language_name',fn.language_name,
   'security_definer',fn.security_definer,'volatile_code',fn.volatile_code,'config',fn.config,
   -- Preserve the exact pg_proc ACL, including PUBLIC/default ACL semantics.
   -- information_schema.routine_privileges can conflate overloaded functions.
   'grants',coalesce(to_jsonb(fn.acl_items),'null'::jsonb),
   'dependencies',coalesce((select jsonb_agg(distinct dep order by dep) from (
    select pg_describe_object(d.classid,d.objid,d.objsubid) dep
    from pg_depend d where d.refclassid='pg_proc'::regclass and d.refobjid=fn.oid
      and d.classid in('pg_rewrite'::regclass,'pg_trigger'::regclass)
      and d.deptype in('n','a')
   )d),'[]'::jsonb),
   'definition_sha256',encode(extensions.digest(fn.definition,'sha256'),'hex')));
 end loop;
 if (select count(*)from jsonb_array_elements(members))<>cardinality(p_function_signatures)
  then raise exception 'function_state_member_missing' using errcode='PT404';end if;
 state:=jsonb_build_object('schema_version',1,'scope',p_scope,'package_sha256',p_package_sha256,'members',members,'captured_at',now(),'actor_id',actor);
 insert into private.rad_function_state_receipts(package_sha256,scope,actor_id,state,state_sha256)
 values(p_package_sha256,p_scope,actor,state,encode(extensions.digest(state::text,'sha256'),'hex'))
 on conflict(package_sha256,scope) do nothing returning id into rid;
 if rid is null then
  select r.id,r.state_sha256 into rid,existing_sha from private.rad_function_state_receipts r
   where r.package_sha256=p_package_sha256 and r.scope=p_scope;
  if existing_sha<>encode(extensions.digest(state::text,'sha256'),'hex')
   then raise exception 'function_state_receipt_conflict' using errcode='PT409';end if;
  return rid;
 end if;
 insert into private.rad_function_state_members(receipt_id,identity,definition,owner_name,language_name,
  security_definer,volatile_code,config,grants,dependencies,definition_sha256)
 select rid,m->>'identity',m->>'definition',m->>'owner_name',m->>'language_name',(m->>'security_definer')::boolean,
  m->>'volatile_code',(select array_agg(x)from jsonb_array_elements_text(m->'config')x),m->'grants',m->'dependencies',m->>'definition_sha256'
 from jsonb_array_elements(members)m;
 return rid;
end $$;
revoke all on function private.rad_capture_function_state(text,text,text[]) from public,anon,authenticated,service_role;

-- Restore the exact captured function definitions. This is a reviewed
-- post-commit inversion for function body/owner/ACL/settings only; it refuses
-- drift instead of deleting dependent objects or weakening existing triggers.
create or replace function private.rad_restore_function_state(p_source_receipt_id bigint,p_note text)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();r private.rad_function_state_receipts;m private.rad_function_state_members;
 current record;restored integer:=0;detail jsonb:='[]';begin
 if p_source_receipt_id is null or length(btrim(coalesce(p_note,'')))<20
 then raise exception 'function_restore_review_required' using errcode='PT422';end if;
 select * into r from private.rad_function_state_receipts where id=p_source_receipt_id;
 if r.id is null or encode(extensions.digest(r.state::text,'sha256'),'hex')<>r.state_sha256
 then raise exception 'function_state_receipt_not_found' using errcode='PT404';end if;
 perform pg_advisory_xact_lock(hashtextextended('function-state:'||r.id::text,0));
 for m in select * from private.rad_function_state_members where receipt_id=r.id order by identity loop
  select p.oid,pg_get_userbyid(p.proowner) owner_name,l.lanname language_name,p.prosecdef security_definer,p.provolatile volatile_code,
   coalesce(p.proconfig,'{}'::text[]) config,p.proacl acl_items,pg_get_functiondef(p.oid) definition,p.oid::regprocedure::text identity into current
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
   where p.oid::regprocedure::text=m.identity;
  if current.oid is null then raise exception 'function_state_missing_target: %',m.identity using errcode='PT409';end if;
  -- A changed owner or ACL is not safely reversible by replaying GRANTs.
  -- Refuse rather than changing privileges or silently dropping inherited grants.
  if current.owner_name is distinct from m.owner_name
   or coalesce(to_jsonb(current.acl_items),'null'::jsonb) is distinct from m.grants
   then raise exception 'function_acl_or_owner_drift: %',m.identity using errcode='PT409';end if;
  if coalesce((select jsonb_agg(distinct dep order by dep) from (
    select pg_describe_object(d.classid,d.objid,d.objsubid) dep
    from pg_depend d where d.refclassid='pg_proc'::regclass
      and d.refobjid=current.oid and d.classid in('pg_rewrite'::regclass,'pg_trigger'::regclass)
      and d.deptype in('n','a')
   ) deps),'[]'::jsonb) is distinct from m.dependencies
   then raise exception 'function_dependent_catalog_drift: %',m.identity using errcode='PT409';end if;
  if encode(extensions.digest(current.definition,'sha256'),'hex')<>m.definition_sha256 then
   execute m.definition;
  end if;
  -- The captured definition already carries SECURITY DEFINER and volatility.
  -- Altering these attributes can modify the generated definition text;
  -- verify every attribute only after restoring the original body.
  execute format('alter function %s %s',m.identity,case when m.security_definer then 'security definer' else 'security invoker' end);
  execute format('alter function %s %s',m.identity,case m.volatile_code when 'i' then 'immutable' when 's' then 'stable' else 'volatile' end);
  execute format('alter function %s reset all',m.identity);
  if cardinality(m.config)>0 then
   for current in select c from unnest(m.config)c loop
    if current.c like '%="%' then
     execute format('alter function %s set %s to %s',m.identity,
      split_part(current.c,'=',1),quote_literal(replace(substring(current.c from position('=' in current.c)+2),'"','')));
    else
     execute format('alter function %s set %s to %s',m.identity,
      split_part(current.c,'=',1),quote_literal(substring(current.c from position('=' in current.c)+1)));
    end if;
   end loop;
  end if;
  select p.oid,pg_get_userbyid(p.proowner) owner_name,l.lanname language_name,p.prosecdef security_definer,p.provolatile volatile_code,
   coalesce(p.proconfig,'{}'::text[]) config,p.proacl acl_items,pg_get_functiondef(p.oid) definition into current
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
   where p.oid::regprocedure::text=m.identity;
  if encode(extensions.digest(current.definition,'sha256'),'hex')<>m.definition_sha256
   or current.owner_name<>m.owner_name or current.language_name<>m.language_name or current.security_definer<>m.security_definer
   or current.volatile_code<>m.volatile_code or current.config is distinct from m.config
   or coalesce(to_jsonb(current.acl_items),'null'::jsonb) is distinct from m.grants
   then raise exception 'function_state_restore_mismatch: % hash=% expected=% owner=%/% lang=%/% sec=%/% vol=%/% config=%/%',
    m.identity,encode(extensions.digest(current.definition,'sha256'),'hex'),m.definition_sha256,
    current.owner_name,m.owner_name,current.language_name,m.language_name,current.security_definer,m.security_definer,
    current.volatile_code,m.volatile_code,current.config,m.config using errcode='PT409';end if;
  restored:=restored+1;
  detail:=detail||jsonb_build_object('identity',m.identity,'definition_sha256',m.definition_sha256);
 end loop;
 insert into private.rad_function_reversal_receipts(source_receipt_id,actor_id,action,note,restored_count)
 values(r.id,actor,'reviewed_function_state_restore',p_note,restored);
 return jsonb_build_object('source_receipt_id',r.id,'restored_count',restored,'members',detail,'actor_id',actor,'restored_at',now());
end $$;
revoke all on function private.rad_restore_function_state(bigint,text) from public,anon,authenticated,service_role;

-- Source-faithful reversal: only a currently published revision from the exact
-- approved batch can be unpublished, and only through an immutable unpublish
-- event. The head pointer guard checks this event before allowing NULL.
create or replace function private.rad_source_publication_pointer_guard() returns trigger
language plpgsql set search_path='' as $$begin
 if new.published_id is null then
  if tg_op='UPDATE' and old.published_id is not null then
   perform private.rad_require_admin();
   if not exists(select 1 from public.visa_article_revision_events e
    join private.rad_source_editorial_batches b on b.id=e.source_batch_id
    join public.visa_article_revisions r on r.id=e.revision_id
    where e.revision_id=old.published_id and e.state='unpublished' and e.publication_basis='source_faithful'
    and e.actor_id=auth.uid() and b.approved_by=auth.uid() and r.article_id=new.article_id and r.locale=new.locale
    and e.note like '%'||r.content_hash||'%'
    -- Only the event inserted by this same transaction authorizes reversal.
    and e.xmin::text=((pg_current_xact_id()::text::numeric % 4294967296)::bigint)::text)
   then raise exception 'explicit_source_unpublish_operation_required' using errcode='PT422';end if;
  end if;
  return new;
 end if;
 if tg_op='UPDATE' and new.published_id is not distinct from old.published_id then return new;end if;
 if exists(select 1 from public.visa_article_revision_events where revision_id=new.published_id and publication_basis='source_faithful') then
  perform private.rad_require_admin();
  if not exists(select 1 from public.visa_article_revision_events e join private.rad_source_editorial_batches b on b.id=e.source_batch_id
   join public.visa_article_revisions r on r.id=e.revision_id
   where e.revision_id=new.published_id and e.state='published' and e.publication_basis='source_faithful'
   and e.actor_id=auth.uid() and b.approved_by=auth.uid() and r.article_id=new.article_id and r.locale=new.locale
   and e.xmin::text=((pg_current_xact_id()::text::numeric % 4294967296)::bigint)::text)
  then raise exception 'explicit_source_publication_operation_required' using errcode='PT422';end if;
 end if;
 return new;
end $$;
revoke all on function private.rad_source_publication_pointer_guard() from public,anon,authenticated,service_role;

create or replace function public.unpublish_source_editorial_batch(p_batch_id uuid,p_manifest_sha256 text,p_note text)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.rad_require_admin();batch private.rad_source_editorial_batches;entry jsonb;r public.visa_article_revisions;
 event public.visa_article_revision_events;head public.visa_article_heads;receipts jsonb:='[]';n integer:=0;u bigint;existing_count integer;begin
 if p_batch_id is null or p_manifest_sha256 is null or p_manifest_sha256!~'^[a-f0-9]{64}$'
 or length(btrim(coalesce(p_note,'')))<20 then raise exception 'source_unpublish_review_required' using errcode='PT422';end if;
 select * into batch from private.rad_source_editorial_batches where id=p_batch_id;
 if batch.id is null then raise exception 'source_batch_not_found' using errcode='PT404';end if;
 if batch.approved_by<>actor or p_manifest_sha256<>batch.manifest_sha256 then raise exception 'source_batch_actor_or_hash_conflict' using errcode='PT409';end if;
 perform pg_advisory_xact_lock(hashtextextended('source-batch:'||p_batch_id::text,0));
 perform 1 from public.visa_article_heads h join public.visa_article_revisions v on v.article_id=h.article_id and v.locale=h.locale
 where v.id in(select (value->>'revision_id')::uuid from jsonb_array_elements(batch.manifest_text::jsonb)) order by h.article_id,h.locale for update of h;
 for entry in select value from jsonb_array_elements(batch.manifest_text::jsonb) order by value->>'revision_id' loop
  -- Publication changes catalog.active, while a later reversal must still bind
  -- the same revision/body/source. Validate all fields except that state flag.
  entry:=entry||jsonb_build_object('expected_catalog_active',true);
  select * into r from public.visa_article_revisions where id=private.rad_source_editorial_entry(entry);
  select * into head from public.visa_article_heads where article_id=r.article_id and locale=r.locale;
  select * into event from public.visa_article_revision_events e where e.revision_id=r.id and e.state='unpublished' and e.publication_basis='source_faithful' and e.source_batch_id=batch.id order by e.id desc limit 1;
  if event.id is not null then
   if head.published_id is not null or head.head_id is distinct from (entry->>'expected_head_id')::uuid
    then raise exception 'source_unpublish_retry_conflict' using errcode='PT409';end if;
  else
   if private.rad_article_state(r.id)<>'published' or head.published_id is distinct from r.id
    or head.head_id is distinct from (entry->>'expected_head_id')::uuid then raise exception 'source_publication_state_changed' using errcode='PT409';end if;

   if exists(select 1 from private.rad_source_publication_holds h join private.rad_production_reconciliation_journal j on j.package_sha256=h.package_sha256
    and j.operation_id=h.operation_id and j.payload_sha256=h.payload_sha256 where j.revision_id=r.id)
    then raise exception 'source_publication_hold_requires_evidence_reconciliation' using errcode='PT422';end if;
   insert into public.visa_article_revision_events(revision_id,state,actor_id,note,publication_basis,source_batch_id)
    values(r.id,'unpublished',actor,'unpublish source-faithful revision; content_hash='||r.content_hash||'; previous_published_id='||r.id::text||'; '||p_note,
     'source_faithful',batch.id) returning * into event;
   update public.visa_article_heads set published_id=null where article_id=r.article_id and locale=r.locale;
  end if;
  n:=n+1;
  receipts:=receipts||jsonb_build_array(jsonb_build_object('article_id',r.article_id,'locale',r.locale,'revision_id',r.id,
   'content_hash',r.content_hash,'unpublish_event_id',event.id,'actor_id',event.actor_id,'unpublished_at',event.created_at,'published_id',null));
 end loop;
 insert into private.rad_source_unpublish_receipts(batch_id,actor_id,operation,manifest_sha256,reversed_count)
 values(batch.id,actor,'unpublish_source_editorial_batch',p_manifest_sha256,n)
 on conflict(batch_id) do nothing returning id into u;
 if u is null then
  select u.id,u.reversed_count into u,n from private.rad_source_unpublish_receipts u where u.batch_id=batch.id;
  select count(*)into existing_count from public.visa_article_revision_events e where e.source_batch_id=batch.id and e.state='unpublished';
  if existing_count<>n then raise exception 'source_unpublish_receipt_conflict' using errcode='PT409';end if;
 end if;
 return private.rad_envelope(jsonb_build_object('batch_id',batch.id,'manifest_sha256',batch.manifest_sha256,'receipt_id',u,
  'receipts',receipts,'unpublished_count',n,'factual_verification_changed',false,'feed_publications',0));
end $$;
revoke all on function public.unpublish_source_editorial_batch(uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function public.unpublish_source_editorial_batch(uuid,text,text) to authenticated;
notify pgrst,'reload schema';
commit;
