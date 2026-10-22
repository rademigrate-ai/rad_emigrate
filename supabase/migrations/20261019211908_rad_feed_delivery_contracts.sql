-- Reviewed R05 notification-only forward delta; no CRM/history replay.
begin;
-- Real transports remain unconfigured. This outbox can record sandbox receipts
-- only; no sandbox receipt grants a paid entitlement or proves external delivery.
alter table public.notification_preferences add column if not exists sms_enabled boolean not null default false;
alter table public.notification_preferences add column if not exists time_zone text not null default 'UTC';
create or replace function private.validate_notification_time_zone() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from pg_catalog.pg_timezone_names where name=new.time_zone) then
    raise exception 'invalid_time_zone' using errcode='22023';
  end if;
  return new;
end $$;
revoke all on function private.validate_notification_time_zone() from public,anon,authenticated;
drop trigger if exists trg_notification_time_zone on public.notification_preferences;
create trigger trg_notification_time_zone before insert or update of time_zone on public.notification_preferences
  for each row execute function private.validate_notification_time_zone();

create table if not exists public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  channel text not null check(channel in ('email','sms','push')),
  transport text not null default 'sandbox' check(transport='sandbox'),
  status text not null default 'queued' check(status in ('queued','processing','sandbox_delivered','failed','cancelled')),
  attempts integer not null default 0 check(attempts between 0 and 3),
  available_at timestamptz not null default now(),
  lease_until timestamptz,
  lease_token uuid,
  safe_error_code text check(safe_error_code in ('sandbox_transport_failed','preference_disabled','lease_expired')),
  created_at timestamptz not null default now(),
  finished_at timestamptz,
  unique(notification_id,channel)
);
create index if not exists notification_deliveries_pending_idx on public.notification_deliveries(available_at,id) where status in ('queued','processing');
create index if not exists notification_deliveries_user_idx on public.notification_deliveries(user_id);
alter table public.notification_deliveries enable row level security;
revoke all on public.notification_deliveries from public,anon,authenticated;
grant select(id,notification_id,user_id,channel,transport,status,attempts,created_at,finished_at) on public.notification_deliveries to authenticated;
grant all on public.notification_deliveries to service_role;
drop policy if exists notification_deliveries_owner on public.notification_deliveries;
create policy notification_deliveries_owner on public.notification_deliveries for select to authenticated
  using(user_id=(select auth.uid()));
drop policy if exists notification_deliveries_service on public.notification_deliveries;
create policy notification_deliveries_service on public.notification_deliveries for all to service_role using(true) with check(true);

create or replace function private.notification_channel_enabled(p_user uuid,p_channel text) returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce((select case p_channel when 'email' then email_enabled when 'sms' then sms_enabled when 'push' then push_enabled else false end
    from public.notification_preferences where user_id=p_user),false)
$$;
revoke all on function private.notification_channel_enabled(uuid,text) from public,anon,authenticated;

create or replace function private.notification_due_at(p_user uuid,p_at timestamptz) returns timestamptz
language plpgsql stable security definer set search_path='' as $$
declare p public.notification_preferences%rowtype; v_local timestamp; v_end timestamp;
begin
  select * into p from public.notification_preferences where user_id=p_user;
  if not found or p.quiet_hours_start is null or p.quiet_hours_end is null or p.quiet_hours_start=p.quiet_hours_end then return p_at; end if;
  v_local := p_at at time zone p.time_zone;
  if (p.quiet_hours_start<p.quiet_hours_end and v_local::time>=p.quiet_hours_start and v_local::time<p.quiet_hours_end)
    or (p.quiet_hours_start>p.quiet_hours_end and (v_local::time>=p.quiet_hours_start or v_local::time<p.quiet_hours_end)) then
    v_end := v_local::date + p.quiet_hours_end;
    if p.quiet_hours_start>p.quiet_hours_end and v_local::time>=p.quiet_hours_start then v_end:=v_end+interval '1 day'; end if;
    return v_end at time zone p.time_zone;
  end if;
  return p_at;
end $$;
revoke all on function private.notification_due_at(uuid,timestamptz) from public,anon,authenticated;

create or replace function public.queue_notification_delivery(p_notification_id uuid,p_channel text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare n public.notifications%rowtype; v_id uuid;
begin
  if p_channel is null or p_channel not in ('email','sms','push') then raise exception 'invalid_channel' using errcode='22023'; end if;
  select * into n from public.notifications where id=p_notification_id;
  if not found then raise exception 'notification_not_found' using errcode='P0002'; end if;
  if coalesce(auth.jwt()->>'role','')<>'service_role' and auth.uid() is distinct from n.user_id
    and not private.has_role(array['admin','super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
  if not private.notification_channel_enabled(n.user_id,p_channel) then return jsonb_build_object('queued',false,'reason','preference_disabled'); end if;
  insert into public.notification_deliveries(notification_id,user_id,channel,available_at)
    values(n.id,n.user_id,p_channel,private.notification_due_at(n.user_id,now()))
    on conflict(notification_id,channel) do nothing returning id into v_id;
  if v_id is null then select id into v_id from public.notification_deliveries where notification_id=n.id and channel=p_channel; end if;
  return jsonb_build_object('queued',true,'delivery_id',v_id,'transport','sandbox');
end $$;
revoke all on function public.queue_notification_delivery(uuid,text) from public,anon;
grant execute on function public.queue_notification_delivery(uuid,text) to authenticated,service_role;

create or replace function public.claim_sandbox_notification() returns setof public.notification_deliveries
language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
  update public.notification_deliveries d set status='cancelled',safe_error_code='preference_disabled',finished_at=now(),lease_token=null,lease_until=null
    where d.status in ('queued','processing') and not private.notification_channel_enabled(d.user_id,d.channel);
  update public.notification_deliveries d set available_at=private.notification_due_at(d.user_id,now())
    where d.status='queued' and d.available_at<=now() and private.notification_due_at(d.user_id,now())>now();
  update public.notification_deliveries set status='failed',safe_error_code='lease_expired',finished_at=now(),lease_token=null,lease_until=null
    where status='processing' and lease_until<=now() and attempts>=3;
  select d.id into v_id from public.notification_deliveries d where d.attempts<3 and d.available_at<=now()
    and (d.status='queued' or (d.status='processing' and d.lease_until<=now()))
    and private.notification_due_at(d.user_id,now())<=now()
    order by d.available_at,d.id for update skip locked limit 1;
  return query update public.notification_deliveries set status='processing',attempts=attempts+1,
    lease_until=now()+interval '60 seconds',lease_token=gen_random_uuid()
    where id=v_id returning *;
end $$;
revoke all on function public.claim_sandbox_notification() from public,anon,authenticated;
grant execute on function public.claim_sandbox_notification() to service_role;

create or replace function public.finish_sandbox_notification(p_delivery_id uuid,p_lease_token uuid,p_success boolean) returns boolean
language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='42501'; end if;
  if p_success is null then raise exception 'result_required' using errcode='22023'; end if;
  update public.notification_deliveries d set status='cancelled',safe_error_code='preference_disabled',finished_at=now(),lease_token=null,lease_until=null
    where d.id=p_delivery_id and d.lease_token=p_lease_token and d.status='processing' and d.lease_until>now()
    and not private.notification_channel_enabled(d.user_id,d.channel);
  if found then return false; end if;
  update public.notification_deliveries set
    status=case when p_success then 'sandbox_delivered' when attempts<3 then 'queued' else 'failed' end,
    safe_error_code=case when p_success then null else 'sandbox_transport_failed' end,
    available_at=case when p_success then available_at else now()+attempts*interval '1 minute' end,
    finished_at=case when p_success or attempts>=3 then now() else null end,
    lease_token=null,lease_until=null
  where id=p_delivery_id and lease_token=p_lease_token and status='processing' and lease_until>now();
  return found;
end $$;
revoke all on function public.finish_sandbox_notification(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.finish_sandbox_notification(uuid,uuid,boolean) to service_role;


-- RAD v1 Feed and notification contracts follow.
alter table public.notification_preferences
 add column if not exists revision integer not null default 1,
 add column if not exists currency_alerts boolean not null default false,
 add column if not exists followed_country_codes text[] not null default '{}',
 add column if not exists followed_pathway_slugs text[] not null default '{}';
alter table public.notifications add column if not exists target jsonb;
alter table public.notifications add column if not exists event_id uuid not null default gen_random_uuid();
create unique index if not exists rad_notification_event_owner_once on public.notifications(event_id,user_id,type);
alter table public.feed_items add column if not exists linked_article_id uuid references public.visa_articles(id);
alter table public.feed_items add column if not exists publication_event_id uuid;
create index if not exists feed_linked_article_idx on public.feed_items(linked_article_id);
revoke insert,update,delete on public.notification_preferences,public.saved_feed_items,public.feed_item_reads from anon,authenticated;
revoke update on public.notifications from authenticated;
grant update(read_at) on public.notifications to authenticated;
create table public.rad_feed_revisions(
 id uuid primary key default gen_random_uuid(),item_id uuid not null references public.feed_items(id),locale text not null check(locale in ('fa','en')),
 revision integer not null,body jsonb not null,content_hash text not null,
 created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),unique(item_id,locale,revision)
);
create table public.rad_feed_heads(item_id uuid not null references public.feed_items(id),locale text not null,head_id uuid references public.rad_feed_revisions(id),published_id uuid references public.rad_feed_revisions(id),primary key(item_id,locale));
create table public.rad_feed_events(
 id uuid primary key default gen_random_uuid(),sequence bigint generated always as identity,
 revision_id uuid not null references public.rad_feed_revisions(id),state text not null check(state in ('draft','approved','rejected','published')),
 actor_id uuid not null references auth.users(id),note text not null default '',created_at timestamptz not null default now()
);
create index rad_feed_event_revision_idx on public.rad_feed_events(revision_id,sequence desc);
create unique index rad_feed_publish_once on public.rad_feed_events(revision_id) where state='published';
alter table public.rad_feed_revisions enable row level security;
alter table public.rad_feed_heads enable row level security;
alter table public.rad_feed_events enable row level security;
revoke all on public.rad_feed_revisions,public.rad_feed_heads,public.rad_feed_events from public,anon,authenticated,service_role;
create trigger rad_feed_revision_immutable before update or delete on public.rad_feed_revisions for each row execute function private.rad_immutable();
create trigger rad_feed_event_immutable before update or delete on public.rad_feed_events for each row execute function private.rad_immutable();

create function private.rad_feed_state(revision_id uuid) returns text language sql stable set search_path='' as $$
 select state from public.rad_feed_events e where e.revision_id=$1 order by sequence desc limit 1;
$$;
create function private.rad_feed_revision_json(r public.rad_feed_revisions) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('item_id',r.item_id,'revision_id',r.id,'revision',r.revision,'content_hash',r.content_hash,
 'editorial_state',private.rad_feed_state(r.id),'updated_at',to_char(r.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'));
$$;
create function private.rad_feed_mutate(operation text,body jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare prior jsonb;result jsonb;r public.rad_feed_revisions;h public.rad_feed_heads;ev public.rad_feed_events;item uuid;new_state text;
begin
 perform private.rad_require_admin();prior:=private.rad_begin_mutation(operation,body);if prior is not null then return prior; end if;
 if operation='save_feed_draft' then
  item:=coalesce((body->>'item_id')::uuid,gen_random_uuid());
  perform set_config('rad.human_publish_actor',auth.uid()::text,true);
  if body->>'item_id' is null then
   if (body->>'expected_revision')::integer<>0 then raise exception 'revision_conflict' using errcode='PT409'; end if;
   insert into public.feed_items(id,slug,category,status,created_by) values(item,'feed-'||item,body->>'category','draft',auth.uid());
  elsif not exists(select 1 from public.feed_items where id=item) then raise exception 'not_found' using errcode='PT404'; end if;
  insert into public.rad_feed_heads(item_id,locale) values(item,body->>'locale') on conflict do nothing;
  select * into h from public.rad_feed_heads where item_id=item and locale=body->>'locale' for update;
  select * into r from public.rad_feed_revisions where id=h.head_id;
  if coalesce(r.revision,0)<>(body->>'expected_revision')::integer then raise exception 'revision_conflict' using errcode='PT409'; end if;
  if body->>'article_id' is not null and not exists(select 1 from public.visa_article_heads where article_id=(body->>'article_id')::uuid and published_id is not null) then raise exception 'article_unavailable' using errcode='PT422'; end if;
  insert into public.rad_feed_revisions(item_id,locale,revision,body,content_hash,created_by)
  values(item,body->>'locale',coalesce(r.revision,0)+1,body-'request_key',encode(extensions.digest((body-'request_key'-'expected_revision')::text,'sha256'),'hex'),auth.uid()) returning * into r;
  insert into public.rad_feed_events(revision_id,state,actor_id) values(r.id,'draft',auth.uid());
  update public.rad_feed_heads set head_id=r.id where item_id=item and locale=r.locale;
  result:=private.rad_envelope(private.rad_feed_revision_json(r),r.locale);
 else
  select * into r from public.rad_feed_revisions where id=(body->>'revision_id')::uuid;
  if not found then raise exception 'not_found' using errcode='PT404'; end if;
  select * into h from public.rad_feed_heads where item_id=r.item_id and locale=r.locale for update;
  if h.head_id<>r.id or r.content_hash<>body->>'content_hash' or (body ? 'expected_revision' and r.revision<>(body->>'expected_revision')::integer) then raise exception 'revision_conflict' using errcode='PT409'; end if;
  if operation='review_feed_draft' then
   if private.rad_feed_state(r.id)<>'draft' then raise exception 'invalid_transition' using errcode='PT409'; end if;
   new_state:=case body->>'decision' when 'approve' then 'approved' else 'rejected' end;
   if new_state='rejected' and nullif(btrim(body->>'note'),'') is null then raise exception 'rejection_note_required' using errcode='PT422'; end if;
   insert into public.rad_feed_events(revision_id,state,actor_id,note) values(r.id,new_state,auth.uid(),body->>'note');
   result:=private.rad_envelope(private.rad_feed_revision_json(r),r.locale);
  else
   if private.rad_feed_state(r.id) not in ('approved','published') then raise exception 'approval_required' using errcode='PT409'; end if;
   select * into ev from public.rad_feed_events where revision_id=r.id and state='published';
   if not found then
    perform set_config('rad.human_publish_actor',auth.uid()::text,true);
    insert into public.feed_item_localizations(feed_item_id,locale,title,summary,body)
    values(r.item_id,r.locale,r.body->>'title',r.body->>'summary',private.rad_blocks_text(r.body->'body'))
    on conflict(feed_item_id,locale) do update set title=excluded.title,summary=excluded.summary,body=excluded.body;
    insert into public.rad_feed_events(revision_id,state,actor_id) values(r.id,'published',auth.uid()) returning * into ev;
    update public.feed_items set category=r.body->>'category',linked_article_id=(r.body->>'article_id')::uuid,expires_at=(r.body->>'expires_at')::timestamptz,
    status='published',published_at=now(),reviewed_by=auth.uid(),publication_event_id=ev.id where id=r.item_id;
    update public.rad_feed_heads set published_id=r.id where item_id=r.item_id and locale=r.locale;
   end if;
   result:=private.rad_envelope(jsonb_build_object('resource_id',r.item_id,'revision_id',r.id,'revision',r.revision,'event_id',ev.id,
    'published_at',to_char(ev.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'target',jsonb_build_object('kind','feed_item','id',r.item_id,'section_id',null)),r.locale);
  end if;
 end if;
 return private.rad_finish_mutation(operation,body,result);
end $$;

create function private.rad_feed_json(item uuid,locale text) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',f.id,'slug',f.slug,'revision',coalesce(r.revision,1),'locale',$2,'title',l.title,'summary',l.summary,
  'body',coalesce(r.body->'body',jsonb_build_array(jsonb_build_object('id',f.id,'type','paragraph','text',l.body,'items','[]'::jsonb))),
  'category',f.category,'article_id',f.linked_article_id,'published_at',to_char(f.published_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'expires_at',case when f.expires_at is null then null else to_char(f.expires_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') end,
  'saved',exists(select 1 from public.saved_feed_items where user_id=auth.uid() and feed_item_id=f.id),
  'read_at',(select to_char(read_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') from public.feed_item_reads where user_id=auth.uid() and feed_item_id=f.id),
  'target',jsonb_build_object('kind','feed_item','id',f.id,'section_id',null))
 from public.feed_items f join public.feed_item_localizations l on l.feed_item_id=f.id and l.locale=$2
 left join public.rad_feed_heads h on h.item_id=f.id and h.locale=$2 left join public.rad_feed_revisions r on r.id=h.published_id
 where f.id=$1 and f.status='published' and f.published_at<=now() and (f.expires_at is null or f.expires_at>now());
$$;
create function public.get_feed_item(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform private.rad_assert_request('get_feed_item',p_request);result:=private.rad_feed_json((p_request->>'item_id')::uuid,p_request->>'locale');
 if result is null then raise exception 'not_found' using errcode='PT404'; end if;
 return private.rad_envelope(result,p_request->>'locale');
end $$;
create function public.resolve_legacy_feed_slug(p_slug text,p_locale text) returns jsonb language plpgsql security definer set search_path='' as $$
declare id uuid;
begin
 if p_slug !~ '^[a-z0-9-]{1,160}$' or p_locale not in ('fa','en') then raise exception 'invalid_request' using errcode='PT422'; end if;
 select feed_items.id into id from public.feed_items where slug=p_slug;
 return public.get_feed_item(jsonb_build_object('item_id',id,'locale',p_locale));
end $$;
create function public.list_feed(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;off integer;lim integer:=(p_request->>'limit')::integer;version text;total integer;
begin
 perform private.rad_assert_request('list_feed',p_request);
 if (p_request->>'saved_only')::boolean then perform private.rad_require_owner(); end if;
 select coalesce(max(updated_at)::text,'empty') into version from public.feed_items;
 off:=coalesce((private.rad_page_position(p_request,version)->>'offset')::integer,0);
 with visible as (select f.* from public.feed_items f where private.rad_feed_json(f.id,p_request->>'locale') is not null
 and (p_request->>'category' is null or f.category=p_request->>'category') and (not (p_request->>'saved_only')::boolean or exists(select 1 from public.saved_feed_items where user_id=auth.uid() and feed_item_id=f.id))),
 page as(select * from visible order by published_at desc,id desc offset off limit lim)
 select (select count(*) from visible),coalesce(jsonb_agg(private.rad_feed_json(p.id,p_request->>'locale') order by p.published_at desc,p.id desc),'[]') into total,result from page p;
 return private.rad_envelope(jsonb_build_object('items',result),p_request->>'locale',private.rad_page(p_request,version,jsonb_build_object('offset',off+lim),total>off+lim));
end $$;

create or replace function private.notify_feed_publication() returns trigger language plpgsql security definer set search_path='' as $$
declare n uuid; pref public.notification_preferences; channel text; country text;pathway text;
begin
 if new.status<>'published' or new.published_at is null or (tg_op='UPDATE' and old.status=new.status and old.published_at is not distinct from new.published_at) then return new; end if;
 select country_code,pathway_slug into country,pathway from public.visa_articles where id=new.linked_article_id;
 for pref in select * from public.notification_preferences where feed_updates
  and (cardinality(followed_country_codes)=0 or country=any(followed_country_codes))
  and (cardinality(followed_pathway_slugs)=0 or pathway=any(followed_pathway_slugs)) loop
  insert into public.notifications(user_id,type,title,body,action_path,source_id,target,event_id)
  select pref.user_id,'feed',coalesce(l.title,new.slug),coalesce(l.summary,'New RAD content'),'/feed/'||new.id,new.id,
   jsonb_build_object('kind','feed_item','id',new.id,'section_id',null),coalesce(new.publication_event_id,gen_random_uuid())
  from (select 1) singleton left join public.feed_item_localizations l on l.feed_item_id=new.id and l.locale=pref.locale returning id into n;
  foreach channel in array array['email','sms','push'] loop
   perform public.queue_notification_delivery(n,channel);
  end loop;
 end loop;
 return new;
end $$;

create function private.rad_ack(applied boolean default true) returns jsonb language sql volatile set search_path='' as $$
 select jsonb_build_object('applied',applied,'updated_at',to_char(now() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'));
$$;
create function private.rad_feed_interact(operation text,body jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare owner uuid:=private.rad_require_owner();prior jsonb;
begin
 prior:=private.rad_begin_mutation(operation,body);if prior is not null then return prior; end if;
 if not exists(select 1 from public.feed_items where id=(body->>'item_id')::uuid and status='published' and published_at<=now() and (expires_at is null or expires_at>now())) then raise exception 'not_found' using errcode='PT404'; end if;
 if operation='set_feed_saved' then
  if (body->>'saved')::boolean then insert into public.saved_feed_items(user_id,feed_item_id) values(owner,(body->>'item_id')::uuid) on conflict do nothing;
  else delete from public.saved_feed_items where user_id=owner and feed_item_id=(body->>'item_id')::uuid; end if;
 else
  insert into public.feed_item_reads(user_id,feed_item_id) values(owner,(body->>'item_id')::uuid) on conflict do nothing;
 end if;
 return private.rad_finish_mutation(operation,body,private.rad_envelope(private.rad_ack()));
end $$;

create function private.rad_preferences_json(p public.notification_preferences) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('revision',p.revision,'feed_updates',p.feed_updates,'application_updates',p.application_updates,'document_updates',p.document_updates,
 'currency_alerts',p.currency_alerts,'email_enabled',p.email_enabled,'push_enabled',p.push_enabled,'sms_enabled',p.sms_enabled,
 'locale',p.locale,'time_zone',p.time_zone,'quiet_start',left(p.quiet_hours_start::text,5),'quiet_end',left(p.quiet_hours_end::text,5),
 'followed_country_codes',to_jsonb(p.followed_country_codes),'followed_pathway_slugs',to_jsonb(p.followed_pathway_slugs),'updated_at',to_char(p.updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'));
$$;
create function public.get_notification_preferences(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare owner uuid:=private.rad_require_owner();p public.notification_preferences;
begin
 perform private.rad_assert_request('get_notification_preferences',p_request);
 select * into p from public.notification_preferences where user_id=owner;
 if not found then
  return private.rad_envelope(jsonb_build_object('revision',0,'feed_updates',true,'application_updates',true,'document_updates',true,'currency_alerts',false,
  'email_enabled',false,'push_enabled',false,'sms_enabled',false,'locale','fa','time_zone','UTC','quiet_start',null,'quiet_end',null,
  'followed_country_codes','[]'::jsonb,'followed_pathway_slugs','[]'::jsonb,'updated_at',to_char(now() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
 end if;
 return private.rad_envelope(private.rad_preferences_json(p),p.locale);
end $$;
create function public.save_notification_preferences(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare owner uuid:=private.rad_require_owner();prior jsonb;p public.notification_preferences;v jsonb:=p_request->'preferences';expected integer;
begin
 prior:=private.rad_begin_mutation('save_notification_preferences',p_request);if prior is not null then return prior; end if;
 perform pg_advisory_xact_lock(hashtextextended('notification-prefs:'||owner::text,0));
 select * into p from public.notification_preferences where user_id=owner for update;
 expected:=case when found then p.revision else 0 end;
 if expected<>(p_request->>'expected_revision')::integer then raise exception 'revision_conflict' using errcode='PT409'; end if;
 if not exists(select 1 from pg_timezone_names where name=v->>'time_zone')
  or (v->>'quiet_start' is null)<>(v->>'quiet_end' is null)
  or (v->>'quiet_start' is not null and (v->>'quiet_start' !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or v->>'quiet_end' !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$')) then raise exception 'invalid_notification_preferences' using errcode='PT422'; end if;
 insert into public.notification_preferences(user_id,revision,feed_updates,application_updates,document_updates,currency_alerts,email_enabled,push_enabled,sms_enabled,locale,time_zone,quiet_hours_start,quiet_hours_end,followed_country_codes,followed_pathway_slugs)
 values(owner,expected+1,(v->>'feed_updates')::boolean,(v->>'application_updates')::boolean,(v->>'document_updates')::boolean,(v->>'currency_alerts')::boolean,
  (v->>'email_enabled')::boolean,(v->>'push_enabled')::boolean,(v->>'sms_enabled')::boolean,v->>'locale',v->>'time_zone',(v->>'quiet_start')::time,(v->>'quiet_end')::time,
  array(select jsonb_array_elements_text(v->'followed_country_codes')),array(select jsonb_array_elements_text(v->'followed_pathway_slugs')))
 on conflict(user_id) do update set revision=excluded.revision,feed_updates=excluded.feed_updates,application_updates=excluded.application_updates,document_updates=excluded.document_updates,
  currency_alerts=excluded.currency_alerts,email_enabled=excluded.email_enabled,push_enabled=excluded.push_enabled,sms_enabled=excluded.sms_enabled,locale=excluded.locale,
  time_zone=excluded.time_zone,quiet_hours_start=excluded.quiet_hours_start,quiet_hours_end=excluded.quiet_hours_end,followed_country_codes=excluded.followed_country_codes,followed_pathway_slugs=excluded.followed_pathway_slugs,updated_at=now()
 returning * into p;
 return private.rad_finish_mutation('save_notification_preferences',p_request,private.rad_envelope(private.rad_preferences_json(p),p.locale));
end $$;

create function private.rad_notification_target(n public.notifications) returns jsonb language sql stable set search_path='' as $$
 select coalesce(n.target,case
 when n.type='feed' and n.source_id is not null then jsonb_build_object('kind','feed_item','id',n.source_id,'section_id',null)
 when n.type='application' and n.source_id is not null then jsonb_build_object('kind','case','id',n.source_id,'section_id',null)
 else jsonb_build_object('kind','profile','id',n.user_id,'section_id',null) end);
$$;
create function private.rad_notification_visible(n public.notifications) returns boolean language plpgsql stable security definer set search_path='' as $$
declare target jsonb:=private.rad_notification_target(n);
begin
 if n.user_id is distinct from auth.uid() then return false; end if;
 if target->>'kind'='feed_item' then return exists(select 1 from public.feed_items where id=(target->>'id')::uuid and status='published' and published_at<=now() and (expires_at is null or expires_at>now())); end if;
 if target->>'kind'='visa_article' then return exists(select 1 from public.visa_article_heads where article_id=(target->>'id')::uuid and published_id is not null); end if;
 if target->>'kind'='case' then return exists(select 1 from public.applications where id=(target->>'id')::uuid and user_id=auth.uid()); end if;
 if target->>'kind'='currency_alert' then return exists(select 1 from public.currency_alerts where id=(target->>'id')::uuid and user_id=auth.uid()); end if;
 return target->>'kind'='profile' and target->>'id'=auth.uid()::text;
end $$;
create function private.rad_notification_json(n public.notifications) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',n.id,'event_id',n.event_id,'type',n.type,'title',left(n.title,300),'body',left(n.body,4000),
 'target',private.rad_notification_target(n),'created_at',to_char(n.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
 'read_at',case when n.read_at is null then null else to_char(n.read_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') end,
 'delivery_state',coalesce((select case status when 'sandbox_delivered' then 'sandbox_receipt' else status end from public.notification_deliveries where notification_id=n.id order by created_at desc,id desc limit 1),'in_app'));
$$;
create function public.list_notifications(p_request jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare owner uuid:=private.rad_require_owner();result jsonb;off integer;lim integer:=(p_request->>'limit')::integer;version text;total integer;unread integer;
begin
 perform private.rad_assert_request('list_notifications',p_request);
 select coalesce(max(created_at)::text,'empty') into version from public.notifications where user_id=owner;
 off:=coalesce((private.rad_page_position(p_request,version)->>'offset')::integer,0);
 select count(*) into unread from public.notifications n where user_id=owner and read_at is null and private.rad_notification_visible(n);
 with visible as(select * from public.notifications n where user_id=owner and private.rad_notification_visible(n)
 and (not (p_request->>'unread_only')::boolean or read_at is null) and (p_request->>'type' is null or type=p_request->>'type')),
 page as(select * from visible order by created_at desc,id desc offset off limit lim)
 select (select count(*) from visible),coalesce(jsonb_agg(private.rad_notification_json(p) order by p.created_at desc,p.id desc),'[]') into total,result from page p;
 return private.rad_envelope(jsonb_build_object('items',result,'unread_count',unread),null,private.rad_page(p_request,version,jsonb_build_object('offset',off+lim),total>off+lim));
end $$;
create function private.rad_notification_mutate(operation text,body jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare owner uuid:=private.rad_require_owner();prior jsonb;
begin
 prior:=private.rad_begin_mutation(operation,body);if prior is not null then return prior; end if;
 if operation='mark_notification_read' then
  if not exists(select 1 from public.notifications where user_id=owner and id=(body->>'notification_id')::uuid) then raise exception 'not_found' using errcode='PT404'; end if;
  update public.notifications set read_at=coalesce(read_at,now()) where user_id=owner and id=(body->>'notification_id')::uuid;
 else
  update public.notifications set read_at=now() where user_id=owner and read_at is null and created_at<=least((body->>'before')::timestamptz,now());
 end if;
 return private.rad_finish_mutation(operation,body,private.rad_envelope(private.rad_ack()));
end $$;
CREATE FUNCTION public.save_feed_draft(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_feed_mutate('save_feed_draft',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.save_feed_draft(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.save_feed_draft(jsonb) TO authenticated;
CREATE FUNCTION public.review_feed_draft(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_feed_mutate('review_feed_draft',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.review_feed_draft(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.review_feed_draft(jsonb) TO authenticated;
CREATE FUNCTION public.publish_feed_revision(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_feed_mutate('publish_feed_revision',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.publish_feed_revision(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.publish_feed_revision(jsonb) TO authenticated;
CREATE FUNCTION public.set_feed_saved(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_feed_interact('set_feed_saved',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.set_feed_saved(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.set_feed_saved(jsonb) TO authenticated;
CREATE FUNCTION public.mark_feed_read(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_feed_interact('mark_feed_read',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.mark_feed_read(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.mark_feed_read(jsonb) TO authenticated;
CREATE FUNCTION public.mark_notification_read(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_notification_mutate('mark_notification_read',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.mark_notification_read(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(jsonb) TO authenticated;
CREATE FUNCTION public.mark_all_notifications_read(p_request jsonb) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $rpc$ SELECT private.rad_notification_mutate('mark_all_notifications_read',p_request); $rpc$;
REVOKE ALL ON FUNCTION public.mark_all_notifications_read(jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read(jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.get_feed_item(jsonb) FROM PUBLIC; GRANT EXECUTE ON FUNCTION public.get_feed_item(jsonb) TO anon,authenticated;
REVOKE ALL ON FUNCTION public.list_feed(jsonb) FROM PUBLIC; GRANT EXECUTE ON FUNCTION public.list_feed(jsonb) TO anon,authenticated;
REVOKE ALL ON FUNCTION public.get_notification_preferences(jsonb) FROM PUBLIC,anon,service_role; GRANT EXECUTE ON FUNCTION public.get_notification_preferences(jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.save_notification_preferences(jsonb) FROM PUBLIC,anon,service_role; GRANT EXECUTE ON FUNCTION public.save_notification_preferences(jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.list_notifications(jsonb) FROM PUBLIC,anon,service_role; GRANT EXECUTE ON FUNCTION public.list_notifications(jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.resolve_legacy_feed_slug(text,text) FROM PUBLIC; GRANT EXECUTE ON FUNCTION public.resolve_legacy_feed_slug(text,text) TO anon,authenticated;
commit;
