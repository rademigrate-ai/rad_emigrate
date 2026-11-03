-- Function-state bootstrap: install and capture BEFORE the reviewed core forward.
-- Uses only the existing CMS Admin/immutability foundation. No database Restore,
-- content import, approval, publication, or inverse is performed by this migration.
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
 function_oid oid not null,
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

create table private.rad_function_reversal_authorizations(
 id bigint generated always as identity primary key,
 source_receipt_id bigint not null unique references private.rad_function_state_receipts(id),
 actor_id uuid not null references auth.users(id),
 expected_current_state_sha256 text not null check(expected_current_state_sha256~'^[a-f0-9]{64}$'),
 request_sha256 text not null check(request_sha256~'^[a-f0-9]{64}$'),
 independent_reviewer_ref text not null check(length(btrim(independent_reviewer_ref))>=5),
 approval_evidence_sha256 text not null check(approval_evidence_sha256~'^[a-f0-9]{64}$'),
 expires_at timestamptz not null,created_at timestamptz not null default now()
);
alter table private.rad_function_reversal_authorizations enable row level security;
revoke all on private.rad_function_reversal_authorizations from public,anon,authenticated,service_role;
create trigger rad_function_reversal_authorizations_immutable before update or delete
 on private.rad_function_reversal_authorizations for each row execute function private.rad_immutable();

create table if not exists private.rad_function_reversal_receipts(
 receipt_id bigint generated always as identity primary key,
 source_receipt_id bigint not null unique references private.rad_function_state_receipts(id),
 authorization_id bigint not null references private.rad_function_reversal_authorizations(id),
 actor_id uuid not null references auth.users(id),
 action text not null check(action='reviewed_function_state_restore'),
 note text not null check(length(btrim(note))>=20),
 restored_count integer not null check(restored_count>=0),
 definition_changes integer not null check(definition_changes>=0),
 request_sha256 text not null check(request_sha256~'^[a-f0-9]{64}$'),
 created_at timestamptz not null default now()
);
alter table private.rad_function_reversal_receipts enable row level security;
revoke all on private.rad_function_reversal_receipts from public,anon,authenticated,service_role;
create trigger rad_function_reversal_receipts_immutable before update or delete
 on private.rad_function_reversal_receipts for each row execute function private.rad_immutable();

-- package hash and a reviewed scope; the function never invents a reviewer or
-- executes a restore by itself.
create function private.rad_reviewed_function_signatures() returns text[]
language sql immutable set search_path='' as $$select array[
 'private.is_safe_public_https_url(text)','private.prevent_profile_role_escalation()',
 'private.rad_article_verification(uuid)','private.rad_claim_eligible(uuid)',
 'private.rad_evidence(jsonb,uuid)','private.rad_page_position(jsonb,text)','public.get_visa_article(jsonb)']::text[]$$;
revoke all on function private.rad_reviewed_function_signatures() from public,anon,authenticated,service_role;

create function private.rad_release_function_frame(p_signatures text[]) returns jsonb
language plpgsql set search_path='' as $$declare members jsonb;begin
 if p_signatures is null or
 (select array_agg(x order by x)from unnest(p_signatures)x) is distinct from
 (select array_agg(x order by x)from unnest(private.rad_reviewed_function_signatures())x)
 then raise exception 'exact_seven_function_scope_required' using errcode='PT422';end if;
 select jsonb_agg(jsonb_build_object(
  'identity',p.oid::regprocedure::text,'function_oid',p.oid,
  'definition',pg_get_functiondef(p.oid),'owner_name',pg_get_userbyid(p.proowner),
  'language_name',l.lanname,'security_definer',p.prosecdef,'volatile_code',p.provolatile,
  'config',coalesce(p.proconfig,'{}'::text[]),'grants',coalesce(to_jsonb(p.proacl),'null'::jsonb),
  'dependencies',coalesce((select jsonb_agg(v order by v::text)from(
   select distinct jsonb_build_object('class',d.classid::regclass::text,'object',d.objid,
    'subobject',d.objsubid,'type',d.deptype,'description',pg_describe_object(d.classid,d.objid,d.objsubid))v
   from pg_depend d where d.refclassid='pg_proc'::regclass and d.refobjid=p.oid)deps),'[]'::jsonb),
  'definition_sha256',encode(extensions.digest(pg_get_functiondef(p.oid),'sha256'),'hex'))
  order by p.oid::regprocedure::text)into members
 from pg_proc p join pg_language l on l.oid=p.prolang
 where p.oid::regprocedure::text=any(p_signatures)and p.prokind='f';
 if jsonb_array_length(coalesce(members,'[]'::jsonb))<>7 then
  raise exception 'function_state_member_missing' using errcode='PT404';end if;
 return members;
end $$;
revoke all on function private.rad_release_function_frame(text[]) from public,anon,authenticated,service_role;

create or replace function private.rad_capture_function_state(
 p_package_sha256 text,p_scope text,p_function_signatures text[],p_expected_state_sha256 text,p_note text
) returns bigint language plpgsql security definer set search_path='' set lock_timeout='2s' as $$
declare actor uuid:=private.rad_require_admin();rid bigint;state jsonb;members jsonb;existing private.rad_function_state_receipts;
 baseline jsonb:='{
 "private.is_safe_public_https_url(text)":"a5aa08d5d750691c351335c2e2313c0e91a16ad7c3f90abbde507f9110b515ec",
 "private.prevent_profile_role_escalation()":"954cc67ddd74f23b0840d07618a8af66b19f32073e3098bc4cf9890718e4b529",
 "private.rad_article_verification(uuid)":"4c0dc1acff287d90a3af18a2c2b03ed30f961180d36596675ba580000438ab8a",
 "private.rad_claim_eligible(uuid)":"0e44eca646f7c634018206aea2b1505741dc58ebee5e16d754635950aabb23e0",
 "private.rad_evidence(jsonb,uuid)":"e7405584ffbc2d06b89c468f7ee1c57e754c84f9b0570051cc0e74f5eeb424b5",
 "private.rad_page_position(jsonb,text)":"f983903947d87c12e03f52c7183e0c07c53da10436104fe59937f3730268cc55",
 "public.get_visa_article(jsonb)":"85de52ee2fb230a1d194eb23dbfce4eff1444a45c597a9898453b6f1d5e7a196"}'::jsonb;
begin
 if p_package_sha256 is null or p_package_sha256!~'^[a-f0-9]{64}$'
 or p_scope is null or p_scope not in('reviewed_forward','manual_review')
 or p_expected_state_sha256 is null or p_expected_state_sha256!~'^[a-f0-9]{64}$'
 or length(btrim(coalesce(p_note,'')))<20 then
  raise exception 'function_state_scope_required' using errcode='PT422';end if;
 perform pg_advisory_xact_lock(hashtextextended('rad-function-state-catalog',0));
 if not(has_table_privilege(current_user,'pg_catalog.pg_proc','UPDATE')
  or has_table_privilege(current_user,'pg_catalog.pg_proc','DELETE')
  or has_table_privilege(current_user,'pg_catalog.pg_proc','TRUNCATE'))then
  raise exception 'provider_approved_catalog_lock_executor_required'using errcode='PT403';end if;
 lock table pg_catalog.pg_proc in share mode;
 members:=private.rad_release_function_frame(p_function_signatures);
 if encode(extensions.digest(members::text,'sha256'),'hex')<>p_expected_state_sha256 then
  raise exception 'function_capture_state_changed' using errcode='PT409';end if;
 select * into existing from private.rad_function_state_receipts where package_sha256=p_package_sha256 and scope=p_scope;
 if existing.id is not null then
  if existing.actor_id<>actor or existing.state->>'note' is distinct from p_note
   or existing.state->'members' is distinct from members
   or existing.state_sha256<>encode(extensions.digest(existing.state::text,'sha256'),'hex')
   or existing.state->>'package_sha256' is distinct from existing.package_sha256
   or existing.state->>'scope' is distinct from existing.scope
   or existing.state->>'actor_id' is distinct from existing.actor_id::text
   or existing.state->>'schema_version' is distinct from '2'
   or existing.state->'members' is distinct from(select jsonb_agg(to_jsonb(m)-'receipt_id'order by m.identity)
    from private.rad_function_state_members m where m.receipt_id=existing.id)then
   raise exception 'function_state_receipt_conflict' using errcode='PT409';end if;
  return existing.id;
 end if;
 if p_scope='reviewed_forward'and exists(select 1 from jsonb_array_elements(members)m
  where baseline->>(m->>'identity')is distinct from m->>'definition_sha256')then
  raise exception 'pre_forward_function_baseline_required' using errcode='PT409';end if;
 state:=jsonb_build_object('schema_version',2,'scope',p_scope,'package_sha256',p_package_sha256,
  'members',members,'captured_at',clock_timestamp(),'actor_id',actor,'note',p_note);
 insert into private.rad_function_state_receipts(package_sha256,scope,actor_id,state,state_sha256)
 values(p_package_sha256,p_scope,actor,state,encode(extensions.digest(state::text,'sha256'),'hex'))returning id into rid;
 insert into private.rad_function_state_members(receipt_id,identity,function_oid,definition,owner_name,language_name,
  security_definer,volatile_code,config,grants,dependencies,definition_sha256)
 select rid,m->>'identity',(m->>'function_oid')::oid,m->>'definition',m->>'owner_name',m->>'language_name',
  (m->>'security_definer')::boolean,m->>'volatile_code',
  coalesce((select array_agg(x order by position)from jsonb_array_elements_text(m->'config')with ordinality v(x,position)),'{}'::text[]),
  m->'grants',m->'dependencies',m->>'definition_sha256'from jsonb_array_elements(members)m;
 return rid;
end $$;
revoke all on function private.rad_capture_function_state(text,text,text[],text,text)from public,anon,authenticated,service_role;

create or replace function private.rad_restore_function_state(
 p_source_receipt_id bigint,p_expected_current_state_sha256 text,p_note text
)returns jsonb language plpgsql security definer set search_path='' set lock_timeout='2s' as $$
declare actor uuid:=private.rad_require_admin();r private.rad_function_state_receipts;
 approval private.rad_function_reversal_authorizations;prior private.rad_function_reversal_receipts;
 source_members jsonb;members jsonb;frame jsonb;m jsonb;request_sha text;changes integer:=0;rid bigint;done_at timestamptz;
begin
 if p_source_receipt_id is null or p_expected_current_state_sha256 is null
 or p_expected_current_state_sha256!~'^[a-f0-9]{64}$'or length(btrim(coalesce(p_note,'')))<20 then
  raise exception 'function_restore_review_required' using errcode='PT422';end if;
 perform pg_advisory_xact_lock(hashtextextended('rad-function-state-catalog',0));
 if not(has_table_privilege(current_user,'pg_catalog.pg_proc','UPDATE')
  or has_table_privilege(current_user,'pg_catalog.pg_proc','DELETE')
  or has_table_privilege(current_user,'pg_catalog.pg_proc','TRUNCATE'))then
  raise exception 'provider_approved_catalog_lock_executor_required'using errcode='PT403';end if;
 lock table pg_catalog.pg_proc in share mode;
 select * into r from private.rad_function_state_receipts where id=p_source_receipt_id;
 if r.id is null or encode(extensions.digest(r.state::text,'sha256'),'hex')<>r.state_sha256 then
  raise exception 'function_state_receipt_not_found' using errcode='PT404';end if;
 if r.actor_id<>actor then raise exception 'function_state_actor_conflict' using errcode='PT403';end if;
 if r.state->>'package_sha256' is distinct from r.package_sha256
 or r.state->>'scope' is distinct from r.scope
 or r.state->>'actor_id' is distinct from r.actor_id::text
 or r.state->>'schema_version' is distinct from '2'then
  raise exception 'function_state_root_integrity_failed' using errcode='PT409';end if;
 select jsonb_agg(to_jsonb(member)-'receipt_id'order by member.identity)into source_members
 from private.rad_function_state_members member where member.receipt_id=r.id;
 if source_members is distinct from r.state->'members'or jsonb_array_length(source_members)<>7
 or exists(select 1 from jsonb_array_elements(source_members)captured
  where encode(extensions.digest(captured->>'definition','sha256'),'hex')<>captured->>'definition_sha256')then
  raise exception 'function_state_member_integrity_failed' using errcode='PT409';end if;
 request_sha:=encode(extensions.digest(jsonb_build_object('source_receipt_id',r.id,'actor_id',actor,
  'expected_current_state_sha256',p_expected_current_state_sha256,'note',p_note)::text,'sha256'),'hex');
 select * into approval from private.rad_function_reversal_authorizations where source_receipt_id=r.id;
 if approval.id is null or approval.actor_id<>actor or approval.expires_at<=clock_timestamp()
 or approval.expected_current_state_sha256<>p_expected_current_state_sha256 or approval.request_sha256<>request_sha then
  raise exception 'independent_function_reversal_authorization_required' using errcode='PT403';end if;
 members:=private.rad_release_function_frame(private.rad_reviewed_function_signatures());
 select * into prior from private.rad_function_reversal_receipts where source_receipt_id=r.id;
 if prior.receipt_id is not null then
  if prior.actor_id<>actor or prior.request_sha256<>request_sha or prior.authorization_id<>approval.id
   or members is distinct from source_members then raise exception 'function_restore_retry_conflict' using errcode='PT409';end if;
  rid:=prior.receipt_id;changes:=prior.definition_changes;done_at:=prior.created_at;
 else
  if encode(extensions.digest(members::text,'sha256'),'hex')<>p_expected_current_state_sha256 then
   raise exception 'function_current_state_changed' using errcode='PT409';end if;
  -- Refuse every owner/ACL/OID/dependent change before executing any definition.
  for m in select value from jsonb_array_elements(source_members)loop
   select value into frame from jsonb_array_elements(members)where value->>'identity'=m->>'identity';
   if frame->'function_oid'is distinct from m->'function_oid'then
    raise exception 'function_identity_oid_drift' using errcode='PT409';end if;
   if frame->'owner_name'is distinct from m->'owner_name'or frame->'grants'is distinct from m->'grants'then
    raise exception 'function_acl_or_owner_drift' using errcode='PT409';end if;
   if frame->'dependencies'is distinct from m->'dependencies'then
    raise exception 'function_dependent_catalog_drift' using errcode='PT409';end if;
  end loop;
  for m in select value from jsonb_array_elements(source_members)loop
   select value into frame from jsonb_array_elements(members)where value->>'identity'=m->>'identity';
   if frame->>'definition_sha256'<>m->>'definition_sha256'then
    -- pg_get_functiondef preserves language, volatility, security mode and all
    -- SET clauses, including quoted/multiple GUC values. Do not reparse them.
    execute m->>'definition';changes:=changes+1;
   end if;
  end loop;
  if private.rad_release_function_frame(private.rad_reviewed_function_signatures())is distinct from source_members then
   raise exception 'function_state_restore_mismatch' using errcode='PT409';end if;
  insert into private.rad_function_reversal_receipts(source_receipt_id,authorization_id,actor_id,action,note,
   restored_count,definition_changes,request_sha256)values(r.id,approval.id,actor,'reviewed_function_state_restore',p_note,7,changes,request_sha)
   returning receipt_id,created_at into rid,done_at;
 end if;
 return jsonb_build_object('source_receipt_id',r.id,'reversal_receipt_id',rid,'restored_count',7,
  'definition_changes',changes,'actor_id',actor,'restored_at',done_at,'state_sha256',encode(extensions.digest(source_members::text,'sha256'),'hex'));
end $$;
revoke all on function private.rad_restore_function_state(bigint,text,text)from public,anon,authenticated,service_role;

create function public.get_release_function_state(p_package_sha256 text)returns jsonb
language plpgsql security definer set search_path=''as $$declare actor uuid:=private.rad_require_admin();frame jsonb;begin
 if p_package_sha256 is distinct from '4beb6ba711c5b0243d69be29b32a76c13f5ebcc47ce131e7ca406bcd67e6c282'then
  raise exception 'reviewed_release_package_required'using errcode='PT422';end if;
 frame:=private.rad_release_function_frame(private.rad_reviewed_function_signatures());
 return jsonb_build_object('package_sha256',p_package_sha256,'actor_id',actor,
  'catalog_lock_executor_available',has_table_privilege(current_user,'pg_catalog.pg_proc','UPDATE')
   or has_table_privilege(current_user,'pg_catalog.pg_proc','DELETE')
   or has_table_privilege(current_user,'pg_catalog.pg_proc','TRUNCATE'),
  'state_sha256',encode(extensions.digest(frame::text,'sha256'),'hex'),
  'members',(select jsonb_agg(m-'definition'order by m->>'identity')from jsonb_array_elements(frame)m));
end $$;
create function public.capture_release_function_state(p_package_sha256 text,p_expected_state_sha256 text,p_note text)returns jsonb
language plpgsql security definer set search_path=''as $$declare actor uuid:=private.rad_require_admin();rid bigint;begin
 if p_package_sha256 is distinct from '4beb6ba711c5b0243d69be29b32a76c13f5ebcc47ce131e7ca406bcd67e6c282'then
  raise exception 'reviewed_release_package_required'using errcode='PT422';end if;
 rid:=private.rad_capture_function_state(p_package_sha256,'reviewed_forward',private.rad_reviewed_function_signatures(),p_expected_state_sha256,p_note);
 return jsonb_build_object('receipt_id',rid,'actor_id',actor,'state_sha256',p_expected_state_sha256);
end $$;
create function public.reverse_release_function_state(p_source_receipt_id bigint,p_expected_current_state_sha256 text,p_note text)returns jsonb
language plpgsql security definer set search_path=''as $$begin
 perform private.rad_require_admin();
 return private.rad_restore_function_state(p_source_receipt_id,p_expected_current_state_sha256,p_note);
end $$;
revoke all on function public.get_release_function_state(text),public.capture_release_function_state(text,text,text),
 public.reverse_release_function_state(bigint,text,text)from public,anon,authenticated,service_role;
grant execute on function public.get_release_function_state(text),public.capture_release_function_state(text,text,text),
 public.reverse_release_function_state(bigint,text,text)to authenticated;

notify pgrst,'reload schema';
commit;
