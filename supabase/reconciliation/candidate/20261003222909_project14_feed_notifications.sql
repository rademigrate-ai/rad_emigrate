
create table public.feed_items (
 id uuid primary key default gen_random_uuid(),
 slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
 category text not null check (category in ('update','guide','deadline','event','success_story','announcement')),
 status text not null default 'draft' check (status in ('draft','review','published','archived')),
 primary_source_id uuid references public.content_sources(id) on delete set null,
 source_url text check (source_url is null or source_url like 'https://%'),
 hero_image_url text check (hero_image_url is null or hero_image_url like 'https://%'),
 effective_date date,
 published_at timestamptz,
 expires_at timestamptz,
 created_by uuid references auth.users(id) on delete set null,
 reviewed_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.feed_item_localizations (
 feed_item_id uuid not null references public.feed_items(id) on delete cascade,
 locale text not null check (locale in ('fa','en')),
 title text not null,
 summary text not null,
 body text not null,
 primary key(feed_item_id,locale)
);
create table public.saved_feed_items (
 user_id uuid not null references auth.users(id) on delete cascade,
 feed_item_id uuid not null references public.feed_items(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(user_id,feed_item_id)
);
create table public.feed_item_reads (
 user_id uuid not null references auth.users(id) on delete cascade,
 feed_item_id uuid not null references public.feed_items(id) on delete cascade,
 read_at timestamptz not null default now(),
 primary key(user_id,feed_item_id)
);
create table public.notification_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade,
 feed_updates boolean not null default true,
 application_updates boolean not null default true,
 document_updates boolean not null default true,
 email_enabled boolean not null default false,
 push_enabled boolean not null default false,
 locale text not null default 'fa' check (locale in ('fa','en')),
 quiet_hours_start time,
 quiet_hours_end time,
 updated_at timestamptz not null default now()
);
create table public.notifications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 type text not null check (type in ('feed','application','document','system')),
 title text not null,
 body text not null,
 action_path text,
 source_id uuid,
 read_at timestamptz,
 created_at timestamptz not null default now()
);
create table public.push_subscriptions (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 endpoint text not null,
 p256dh text not null,
 auth_secret text not null,
 user_agent text,
 last_used_at timestamptz,
 created_at timestamptz not null default now(),
 unique(user_id,endpoint)
);

create index feed_items_public_idx on public.feed_items(status,published_at desc);
create index feed_items_source_idx on public.feed_items(primary_source_id);
create index feed_items_creator_idx on public.feed_items(created_by);
create index feed_items_reviewer_idx on public.feed_items(reviewed_by);
create index saved_feed_items_item_idx on public.saved_feed_items(feed_item_id);
create index feed_item_reads_item_idx on public.feed_item_reads(feed_item_id);
create index notifications_user_unread_idx on public.notifications(user_id,read_at,created_at desc);
create index push_subscriptions_user_idx on public.push_subscriptions(user_id);

alter table public.feed_items enable row level security;
alter table public.feed_item_localizations enable row level security;
alter table public.saved_feed_items enable row level security;
alter table public.feed_item_reads enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notifications enable row level security;
alter table public.push_subscriptions enable row level security;

revoke all on table public.feed_items,public.feed_item_localizations,public.saved_feed_items,
 public.feed_item_reads,public.notification_preferences,public.notifications,public.push_subscriptions from anon,authenticated;
grant select on public.feed_items,public.feed_item_localizations to anon,authenticated;
grant select,insert,delete on public.saved_feed_items,public.feed_item_reads to authenticated;
grant select,insert,update on public.notification_preferences to authenticated;
grant select,update on public.notifications to authenticated;
grant select,insert,update,delete on public.push_subscriptions to authenticated;
grant select,insert,update,delete on public.feed_items,public.feed_item_localizations to authenticated;
grant all privileges on public.feed_items,public.feed_item_localizations,public.saved_feed_items,
 public.feed_item_reads,public.notification_preferences,public.notifications,public.push_subscriptions to service_role;

create policy "published feed public read" on public.feed_items for select to anon,authenticated
 using((status='published' and published_at<=now() and (expires_at is null or expires_at>now()))
  or (select private.has_role(array['admin','super_admin'])));
create policy "published feed localizations public read" on public.feed_item_localizations for select to anon,authenticated
 using(exists(select 1 from public.feed_items f where f.id=feed_item_id and
  ((f.status='published' and f.published_at<=now() and (f.expires_at is null or f.expires_at>now()))
   or (select private.has_role(array['admin','super_admin'])))));
create policy "admins manage feed" on public.feed_items for all to authenticated
 using((select private.has_role(array['admin','super_admin']))) with check((select private.has_role(array['admin','super_admin'])));
create policy "admins manage feed localizations" on public.feed_item_localizations for all to authenticated
 using((select private.has_role(array['admin','super_admin']))) with check((select private.has_role(array['admin','super_admin'])));
create policy "users manage saved feed" on public.saved_feed_items for all to authenticated
 using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy "users manage read feed" on public.feed_item_reads for all to authenticated
 using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy "users manage notification preferences" on public.notification_preferences for all to authenticated
 using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy "users read own notifications" on public.notifications for select to authenticated using(user_id=(select auth.uid()));
create policy "users mark own notifications" on public.notifications for update to authenticated
 using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy "users manage push subscriptions" on public.push_subscriptions for all to authenticated
 using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy "service writes notifications" on public.notifications for all to service_role using(true) with check(true);

create or replace function private.notify_feed_publication()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='published' and new.published_at is not null and
    (old.status is distinct from new.status or old.published_at is distinct from new.published_at) then
  insert into public.notifications(user_id,type,title,body,action_path,source_id)
  select p.user_id,'feed',coalesce(l.title,new.slug),coalesce(l.summary,'New RAD content is available.'),
    '/feed/'||new.slug,new.id
  from public.notification_preferences p
  left join public.feed_item_localizations l on l.feed_item_id=new.id and l.locale=p.locale
  where p.feed_updates;
 end if;
 return new;
end $$;
alter function private.notify_feed_publication() owner to postgres;
revoke all on function private.notify_feed_publication() from public,anon,authenticated;
create trigger feed_publication_notifications after insert or update of status,published_at on public.feed_items
 for each row execute function private.notify_feed_publication();



