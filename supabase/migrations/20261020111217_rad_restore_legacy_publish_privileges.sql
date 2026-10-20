-- Restore the reviewed human-only legacy publication effect after G-002's
-- later replacement. Localization is present before the publish event fires.
begin;
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
  if auth.uid() is null or coalesce(auth.jwt()->>'role','')<>'authenticated' or not private.has_role(array['admin','super_admin']) then
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
    v_slug, v_category, 'draft', v_draft.primary_source_id,
    v_draft.source_url, now(), auth.uid(), auth.uid()
  ) returning id into v_feed_id;

  insert into public.feed_item_localizations(
    feed_item_id, locale, title, summary, body
  ) values (
    v_feed_id, v_draft.language_code, v_draft.title,
    left(v_draft.body,500), v_draft.body
  );

  update public.feed_items set status='published' where id=v_feed_id;

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
revoke all on function public.publish_content_draft(uuid,text,text) from public,anon,service_role;
grant execute on function public.publish_content_draft(uuid,text,text) to authenticated;
-- Per-schema default revokes cannot subtract PostgreSQL's global PUBLIC grant.
-- Explicitly revoke existing private helpers and secure future routines globally.
revoke execute on all functions in schema private from public,anon,authenticated;
grant execute on function private.has_role(text[]) to anon,authenticated;
alter default privileges for role postgres revoke execute on functions from public;
create or replace function private.safe_operational_code(value text)
returns text language sql immutable returns null on null input set search_path='' as $$
 select case when value in ('ok','unspecified','provider_timeout','provider_unavailable','provider_unauthorized',
  'provider_rate_limited','provider_request_failed','provider_malformed_response','provider_refused','provider_response_too_large',
  'provider_model_unavailable','provider_unreachable','unsafe_base_url','unsafe_redirect','database_unavailable',
  'storage_unavailable','source_fetch_failed','source_timeout','source_too_large','source_empty','lease_expired',
  'quota_check_failed','routing_unavailable','no_eligible_model','processing_unavailable','synthetic_failure')
  or value ~ '^(source_http|database)_[45][0-9]{2}$' then value else 'unspecified' end;
$$;
revoke all on function private.safe_operational_code(text) from public,anon,authenticated;
grant execute on function private.safe_operational_code(text) to service_role;

-- Known typed metrics only. Unknown keys are omitted, so PII cannot survive in
-- either an unexpected key name or nested values. No free-form payload storage.
create or replace function private.redact_safe_metadata(value jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare k text; v jsonb; result jsonb:='{}'; accepted boolean; removed integer:=0; n numeric; s text;
begin
 if value is null then return '{}'; end if;
 if jsonb_typeof(value)<>'object' or octet_length(value::text)>16384 then
  return '{"payload_rejected":true,"redacted_fields":1}'::jsonb; end if;
 if (select count(*) from jsonb_object_keys(value))>64 then
  return '{"payload_rejected":true,"redacted_fields":1}'::jsonb; end if;
 for k,v in select key,val from jsonb_each(value) e(key,val) loop
  accepted:=false;
  if k in ('attempt','attempt_count','max_attempts','duration_ms','latency_ms','source_count','changed_count','failed_count',
   'retry_count','consecutive_failure_count','schema_version','redacted_fields') and jsonb_typeof(v)='number' then
   n:=(v#>>'{}')::numeric;
   accepted:=n>=0 and n=trunc(n) and n<=case when k in ('duration_ms','latency_ms') then 600000 else 2147483647 end;
  elsif k in ('retryable','sandbox','payload_rejected') and jsonb_typeof(v)='boolean' then accepted:=true;
  elsif jsonb_typeof(v)='string' then
   s:=v#>>'{}';
   if k='status' then accepted:=s in ('healthy','degraded','offline','unknown','queued','running','succeeded','failed','cancelled',
    'review_required','sandbox_delivered','retry_scheduled','investigating','identified','monitoring','resolved');
   elsif k in ('safe_error_code','error_code') then
    accepted:=private.safe_operational_code(s)=s;
   elsif k in ('mode','transport') then accepted:=s in ('sandbox','local','disabled','test');
   elsif k='channel' then accepted:=s in ('email','sms','push');
   elsif k='operation' then accepted:=s in ('claim','dispatch','complete','retry','request','health_check','ingest','review','publish','release_validation');
   elsif k='component_slug' then accepted:=s in ('database','auth','storage','research','ai','document_intelligence','notifications','payments');
   end if;
  end if;
  if accepted then result:=result||jsonb_build_object(k,v); else removed:=removed+1; end if;
 end loop;
 if removed>0 then result:=result||jsonb_build_object('redacted_fields',
  least(2147483647::bigint,removed::bigint+coalesce((result->>'redacted_fields')::bigint,0))); end if;
 return result;
end $$;
revoke all on function private.redact_safe_metadata(jsonb) from public,anon,authenticated;
grant execute on function private.redact_safe_metadata(jsonb) to service_role;

create or replace function private.sanitize_operational_event()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 new.safe_metadata:=private.redact_safe_metadata(new.safe_metadata);
 if new.user_id_hash is not null and new.user_id_hash !~ '^[a-f0-9]{64}$' then new.user_id_hash:=null; end if;
 if new.event_type not in ('ai.request_failed','ai.request_succeeded','research.job_failed','research.job_succeeded',
  'document.processing_failed','document.processing_completed','notification.dispatch_failed','notification.sandbox_delivered',
  'payment.sandbox_event','component.health_alert','component.health_recovered','incident.transition','release.local_check','event.unspecified')
  then new.event_type:='event.unspecified'; end if;
 if not exists(select 1 from public.system_components where slug=new.component_slug) then new.component_slug:='unknown'; end if;
 return new;
end $$;
revoke all on function private.sanitize_operational_event() from public,anon,authenticated;
grant execute on function private.sanitize_operational_event() to service_role;
drop trigger sanitize_operational_events on public.operational_events;
create trigger sanitize_operational_events before insert or update on public.operational_events
 for each row execute function private.sanitize_operational_event();


revoke execute on all functions in schema private from public,anon,authenticated;
grant execute on function private.has_role(text[]) to anon,authenticated;
notify pgrst,'reload schema';
commit;
