-- Stage 1 P0/P1 completion: consultation confidentiality, owner-bound
-- entitlement RPCs, and database-enforced human Feed publication.
-- Additive and safe to re-run through the Supabase migration ledger.
begin;

-- Preserve a secure, auditable bootstrap path. The prior role-escalation
-- trigger also blocked service_role, which made a first Super Admin impossible
-- to provision in a clean project. Authenticated users still require an
-- existing Super Admin and must use set_user_role.
create or replace function private.prevent_profile_role_escalation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.role is distinct from old.role then
    if coalesce(auth.jwt()->>'role','') = 'service_role' then
      insert into public.admin_audit_logs(
        actor_id, action, resource_type, resource_id, safe_metadata
      ) values (
        auth.uid(), 'role_change_service', 'profile', new.id::text,
        jsonb_build_object('from',old.role,'to',new.role)
      );
    elsif not private.has_role(array['super_admin']) then
      raise exception 'role change forbidden' using errcode = '42501';
    end if;
  end if;
  return new;
end
$function$;

alter function private.prevent_profile_role_escalation() owner to postgres;
revoke all on function private.prevent_profile_role_escalation() from public, anon, authenticated;

-- Applicants may read only applicant-visible consultation columns. RLS cannot
-- hide a column, so remove the prior table-wide SELECT privilege.
revoke select, insert on table public.consultation_requests from authenticated;
grant select (
  id, user_id, topic, message, related_application_id, status,
  created_at, updated_at
) on table public.consultation_requests to authenticated;
grant insert (
  user_id, topic, message, related_application_id, status
) on table public.consultation_requests to authenticated;

create or replace function public.list_admin_consultations()
returns setof public.consultation_requests
language plpgsql
security definer
stable
set search_path = ''
as $function$
begin
  if not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select c.*
    from public.consultation_requests c
    order by c.created_at desc
    limit 100;
end
$function$;

alter function public.list_admin_consultations() owner to postgres;
revoke all on function public.list_admin_consultations() from public, anon;
grant execute on function public.list_admin_consultations() to authenticated;

create or replace function public.update_admin_consultation(
  p_consultation_id uuid,
  p_status text,
  p_admin_note text default null
) returns void
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_status not in ('submitted','in_review','contacted','closed') then
    raise exception 'invalid consultation status' using errcode = '22023';
  end if;
  if char_length(coalesce(p_admin_note,'')) > 4000 then
    raise exception 'admin note too long' using errcode = '22023';
  end if;

  update public.consultation_requests
  set status = p_status,
      admin_note = nullif(btrim(p_admin_note),''),
      updated_at = now()
  where id = p_consultation_id;
  if not found then
    raise exception 'consultation not found' using errcode = 'P0002';
  end if;

  insert into public.admin_audit_logs(
    actor_id, action, resource_type, resource_id, safe_metadata
  ) values (
    auth.uid(), 'update', 'consultation_request', p_consultation_id::text,
    jsonb_build_object('status', p_status, 'has_internal_note', nullif(btrim(p_admin_note),'') is not null)
  );
end
$function$;

alter function public.update_admin_consultation(uuid,text,text) owner to postgres;
revoke all on function public.update_admin_consultation(uuid,text,text) from public, anon;
grant execute on function public.update_admin_consultation(uuid,text,text) to authenticated;

-- SECURITY DEFINER quota functions must not accept an arbitrary target user or
-- caller-selected role from an authenticated client.
create or replace function public.get_ai_daily_quota_status(
  p_user_id uuid,
  p_role text default 'user'
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_role text;
  v_limit integer;
  v_token_limit integer;
  v_used integer;
  v_tokens integer;
  v_is_service boolean := coalesce(auth.jwt()->>'role','') = 'service_role';
  v_day timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
begin
  if p_user_id is null then
    raise exception 'user_required' using errcode = '22023';
  end if;
  if not v_is_service and auth.uid() is distinct from p_user_id then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if v_is_service then
    v_role := coalesce(nullif(p_role,''), 'user');
  else
    select coalesce(p.role,'user') into v_role
    from public.profiles p where p.id = p_user_id;
    v_role := coalesce(v_role, 'user');
  end if;

  select l.daily_requests, l.daily_output_tokens
  into v_limit, v_token_limit
  from public.ai_usage_limits l
  where l.role = v_role
  limit 1;
  if v_limit is null then
    v_limit := 50;
    v_token_limit := 100000;
  end if;

  select count(*)::integer, coalesce(sum(r.output_tokens),0)::integer
  into v_used, v_tokens
  from public.ai_requests r
  where r.user_id = p_user_id and r.created_at >= v_day;

  return jsonb_build_object(
    'allowed', (v_used < v_limit and v_tokens < v_token_limit),
    'count', v_used,
    'limit', v_limit,
    'tokens_used', v_tokens,
    'token_limit', v_token_limit,
    'error', case when v_used >= v_limit or v_tokens >= v_token_limit
      then 'daily_limit_reached' else null end
  );
end
$function$;

alter function public.get_ai_daily_quota_status(uuid,text) owner to postgres;
revoke all on function public.get_ai_daily_quota_status(uuid,text) from public, anon;
grant execute on function public.get_ai_daily_quota_status(uuid,text) to authenticated, service_role;

create or replace function public.get_ai_access_decision(
  p_user_id uuid default null,
  p_guest_key_hash text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_role text := 'anonymous';
  v_ent jsonb;
  v_quota jsonb;
  v_paid_active boolean := false;
  v_plan text := 'base';
  v_is_service boolean := coalesce(auth.jwt()->>'role','') = 'service_role';
begin
  if p_user_id is not null then
    if not v_is_service and auth.uid() is distinct from p_user_id then
      raise exception 'forbidden' using errcode = '42501';
    end if;
    select coalesce(p.role,'user') into v_role
    from public.profiles p where p.id = p_user_id;
    v_role := coalesce(v_role, 'user');

    select jsonb_build_object(
      'id', e.id, 'plan_code', e.plan_code, 'status', e.status,
      'starts_at', e.starts_at, 'ends_at', e.ends_at, 'source', e.source
    ) into v_ent
    from public.ai_entitlements e
    where e.user_id = p_user_id
      and e.status = 'active'
      and (e.starts_at is null or e.starts_at <= now())
      and (e.ends_at is null or e.ends_at > now())
    order by e.created_at desc
    limit 1;

    v_paid_active := v_ent is not null;
    if v_paid_active then v_plan := coalesce(v_ent->>'plan_code','base'); end if;
    v_quota := public.get_ai_daily_quota_status(p_user_id, v_role);
    return jsonb_build_object(
      'identity','authenticated', 'user_id',p_user_id, 'role',v_role,
      'plan',v_plan, 'paid_entitlement_active',v_paid_active,
      'payment_available',false, 'entitlement',v_ent, 'quota',v_quota,
      'capability_chat',true,
      'reason',case when (v_quota->>'allowed')::boolean is false
        then coalesce(v_quota->>'error','daily_limit_reached') else 'allowed' end
    );
  end if;

  -- Anonymous decisions are made only by the trusted Edge layer after it has
  -- hashed the opaque guest identity. Clients cannot execute this branch.
  if v_is_service and p_guest_key_hash is not null
     and length(p_guest_key_hash) between 32 and 128 then
    return jsonb_build_object(
      'identity','anonymous', 'role','anonymous', 'plan','guest',
      'paid_entitlement_active',false, 'payment_available',false,
      'guest_limit',5, 'capability_chat',true, 'reason','guest_path'
    );
  end if;

  return jsonb_build_object(
    'identity','none', 'payment_available',false,
    'capability_chat',false, 'reason','authentication_required'
  );
end
$function$;

alter function public.get_ai_access_decision(uuid,text) owner to postgres;
revoke all on function public.get_ai_access_decision(uuid,text) from public, anon;
grant execute on function public.get_ai_access_decision(uuid,text) to authenticated, service_role;

-- OCR provider destinations use the same public-HTTPS database allowlist as AI
-- providers. Existing unsafe configuration is disabled and cleared without
-- exposing its Vault secret.
update public.document_processor_config
set enabled = false, endpoint_url = null, updated_at = now()
where endpoint_url is not null
  and not private.is_safe_public_https_url(endpoint_url);

alter table public.document_processor_config
  drop constraint if exists document_processor_config_public_endpoint_check;
alter table public.document_processor_config
  add constraint document_processor_config_public_endpoint_check
  check (endpoint_url is null or private.is_safe_public_https_url(endpoint_url))
  not valid;
alter table public.document_processor_config
  validate constraint document_processor_config_public_endpoint_check;

-- All draft mutations go through role-checking, audited RPCs. This prevents an
-- Admin client from setting approved/published directly through PostgREST.
revoke insert, update, delete on table public.content_drafts from authenticated;

-- Feed tables are read-only to API roles. The publishing SECURITY DEFINER RPC
-- is the sole human path. Even service_role direct writes are stopped by the
-- trigger unless the RPC sets the transaction-local human actor marker.
revoke insert, update, delete on table public.feed_items, public.feed_item_localizations
from authenticated;

create or replace function private.guard_human_feed_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor text := current_setting('rad.human_publish_actor', true);
begin
  if v_actor is null
     or auth.uid() is null
     or v_actor <> auth.uid()::text
     or not private.has_role(array['admin','super_admin']) then
    raise exception 'feed mutation requires explicit authorized human publication'
      using errcode = '42501';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end
$function$;

alter function private.guard_human_feed_mutation() owner to postgres;
revoke all on function private.guard_human_feed_mutation() from public, anon, authenticated;

drop trigger if exists trg_guard_human_feed_item_mutation on public.feed_items;
create trigger trg_guard_human_feed_item_mutation
before insert or update or delete on public.feed_items
for each row execute function private.guard_human_feed_mutation();

drop trigger if exists trg_guard_human_feed_localization_mutation on public.feed_item_localizations;
create trigger trg_guard_human_feed_localization_mutation
before insert or update or delete on public.feed_item_localizations
for each row execute function private.guard_human_feed_mutation();

create or replace function public.publish_content_draft(
  p_draft_id uuid,
  p_category text default 'update',
  p_slug text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_draft public.content_drafts%rowtype;
  v_feed_id uuid;
  v_slug text;
  v_category text;
begin
  if not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_draft from public.content_drafts where id = p_draft_id for update;
  if not found then raise exception 'draft not found' using errcode = 'P0002'; end if;
  if v_draft.status = 'published' and v_draft.feed_item_id is not null then
    return v_draft.feed_item_id;
  end if;
  if v_draft.status <> 'approved' then
    raise exception 'draft requires explicit approval before publication'
      using errcode = '22023';
  end if;

  v_category := coalesce(nullif(btrim(p_category),''),v_draft.category,'update');
  if v_category not in ('update','guide','deadline','event','success_story','announcement') then
    raise exception 'invalid category' using errcode = '22023';
  end if;
  v_slug := coalesce(
    nullif(lower(regexp_replace(btrim(coalesce(p_slug,'')),'[^a-z0-9]+','-','g')),''),
    lower(regexp_replace(left(v_draft.title,48),'[^a-zA-Z0-9]+','-','g'))
      || '-' || substr(v_draft.id::text,1,8)
  );
  v_slug := trim(both '-' from v_slug);
  if v_slug !~ '^[a-z0-9-]+$' then
    v_slug := 'rad-update-' || substr(v_draft.id::text,1,12);
  end if;
  if exists(select 1 from public.feed_items where slug = v_slug) then
    v_slug := v_slug || '-' || substr(gen_random_uuid()::text,1,8);
  end if;

  perform set_config('rad.human_publish_actor',auth.uid()::text,true);
  insert into public.feed_items(
    slug, category, status, primary_source_id, source_url,
    published_at, created_by, reviewed_by
  ) values (
    v_slug, v_category, 'published', v_draft.primary_source_id,
    v_draft.source_url, now(), auth.uid(), auth.uid()
  ) returning id into v_feed_id;

  insert into public.feed_item_localizations(
    feed_item_id, locale, title, summary, body
  ) values (
    v_feed_id, v_draft.language_code, v_draft.title,
    left(v_draft.body,500), v_draft.body
  );

  update public.content_drafts
  set status = 'published', feed_item_id = v_feed_id,
      category = v_category, reviewed_by = auth.uid(), updated_at = now()
  where id = p_draft_id;

  insert into public.admin_audit_logs(
    actor_id, action, resource_type, resource_id, safe_metadata
  ) values (
    auth.uid(),'publish','content_draft',p_draft_id::text,
    jsonb_build_object('feed_item_id',v_feed_id,'slug',v_slug,'category',v_category)
  );
  return v_feed_id;
end
$function$;

alter function public.publish_content_draft(uuid,text,text) owner to postgres;
revoke all on function public.publish_content_draft(uuid,text,text) from public, anon, service_role;
grant execute on function public.publish_content_draft(uuid,text,text) to authenticated;

comment on function public.publish_content_draft(uuid,text,text) is
  'Explicit human Admin publication only. Draft must first be approved; direct Feed writes are trigger-blocked.';

commit;
