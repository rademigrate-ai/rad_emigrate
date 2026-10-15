-- Align Storage RLS with the client's intentional upsert behavior and move
-- consultation creation behind a serialized, owner-bound abuse-control RPC.
-- This migration is additive repository work only; it is not applied by this
-- implementation task.
begin;

-- Supabase Storage upsert requires SELECT + INSERT + UPDATE. Keep UPDATE as
-- narrow as the existing read/upload/delete policies: the private documents
-- bucket and the authenticated user's first path segment only.
drop policy if exists "documents storage update own" on storage.objects;
create policy "documents storage update own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create index if not exists consultation_requests_user_created_idx
  on public.consultation_requests (user_id, created_at desc);

-- Direct INSERT allowed an authenticated caller to create an unbounded number
-- of requests. All user submissions now pass through the RPC below. Service
-- workflows retain their existing table grant and Admin updates retain their
-- separate role-checked RPC.
revoke insert on table public.consultation_requests from authenticated;
revoke insert (
  user_id, topic, message, related_application_id, status
) on table public.consultation_requests from authenticated;

create or replace function public.submit_consultation_request(
  p_topic text,
  p_message text,
  p_related_application_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_topic text := nullif(btrim(p_topic), '');
  v_message text := nullif(btrim(p_message), '');
  v_request_id uuid;
  v_hour_count integer;
  v_day_count integer;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if v_topic is null or char_length(v_topic) not between 3 and 200 then
    raise exception 'invalid_consultation_topic' using errcode = '22023';
  end if;
  if v_message is null or char_length(v_message) not between 10 and 5000 then
    raise exception 'invalid_consultation_message' using errcode = '22023';
  end if;
  if p_related_application_id is not null and not exists (
    select 1
    from public.applications a
    where a.id = p_related_application_id
      and a.user_id = v_user_id
  ) then
    raise exception 'related_application_forbidden' using errcode = '42501';
  end if;

  -- Serialize a user's submissions so concurrent requests cannot overshoot.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('consultation:' || v_user_id::text, 0)
  );

  select
    count(*) filter (where c.created_at >= now() - interval '1 hour')::integer,
    count(*) filter (where c.created_at >= now() - interval '1 day')::integer
  into v_hour_count, v_day_count
  from public.consultation_requests c
  where c.user_id = v_user_id
    and c.created_at >= now() - interval '1 day';

  if v_hour_count >= 3 or v_day_count >= 10 then
    raise exception 'consultation_rate_limited' using errcode = 'P0001';
  end if;

  insert into public.consultation_requests (
    user_id, topic, message, related_application_id, status
  ) values (
    v_user_id, v_topic, v_message, p_related_application_id, 'submitted'
  )
  returning id into v_request_id;

  return v_request_id;
end
$function$;

alter function public.submit_consultation_request(text,text,uuid)
  owner to postgres;
revoke all on function public.submit_consultation_request(text,text,uuid)
  from public, anon, service_role;
grant execute on function public.submit_consultation_request(text,text,uuid)
  to authenticated;

comment on function public.submit_consultation_request(text,text,uuid) is
  'Owner-bound consultation intake with validation and per-user 3/hour, 10/day limits.';

commit;
