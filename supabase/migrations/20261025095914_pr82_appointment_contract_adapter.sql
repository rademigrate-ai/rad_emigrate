-- PR82 remediation; never hosted-applied by this change.
-- Wire contract: supabase/contracts/appointments_v1.json.
-- Preserve the Plan2 request RPCs while exposing the existing Flutter receipt
-- vocabulary. A preferred time remains a request, never an available slot.
begin;
alter table public.interview_requests
 add column title text not null default '' check(char_length(title)<=300),
 add column cancellation_reason text check(char_length(cancellation_reason)<=2000);

create function private.rad_appointment_json(r public.interview_requests)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',r.id,'user_id',r.user_id,'kind','radSession',
  'title',case when r.title='' then 'RAD interview request' else r.title end,
  'notes',r.notes,'cancellation_reason',r.cancellation_reason,
  'start_utc',r.preferred_start_utc,'end_utc',r.preferred_end_utc,
  'time_zone',r.time_zone,'status',case r.status when 'submitted' then 'requested'
   when 'pending_confirmation' then 'inReview' else r.status end,
  'created_at',r.created_at,'updated_at',r.updated_at);
$$;
revoke all on function private.rad_appointment_json(public.interview_requests) from public,anon,authenticated,service_role;

create function public.list_rad_appointments() returns setof jsonb
language sql stable security definer set search_path='' as $$
 select private.rad_appointment_json(r) from public.interview_requests r
 where r.user_id=auth.uid() and coalesce(auth.jwt()->>'role','')='authenticated' order by r.created_at desc,r.id;
$$;

create function public.submit_rad_appointment(p_title text,p_start_utc timestamptz,
 p_end_utc timestamptz,p_time_zone text,p_notes text,p_idempotency_key uuid)
returns setof jsonb language plpgsql security definer set search_path='' as $$
declare r public.interview_requests; actor uuid:=auth.uid();
begin
 if actor is null or coalesce(auth.jwt()->>'role','')<>'authenticated' then
  raise exception 'authentication_required' using errcode='42501';end if;
 if p_title is null or char_length(btrim(p_title)) not between 1 and 300
  or p_notes is null or char_length(p_notes)>4000 or p_start_utc is null
  or not isfinite(p_start_utc)
  or (p_end_utc is not null and (not isfinite(p_end_utc) or p_end_utc<=p_start_utc)) or p_idempotency_key is null then
  raise exception 'invalid_request' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||':'||p_idempotency_key::text,0));
 select * into r from public.interview_requests
 where user_id=actor and idempotency_key=p_idempotency_key::text;
 if found then
  if r.title is distinct from btrim(p_title) or r.notes is distinct from p_notes
   or r.preferred_start_utc is distinct from p_start_utc
   or r.preferred_end_utc is distinct from p_end_utc
   or r.time_zone is distinct from nullif(btrim(coalesce(p_time_zone,'')),'') then
   raise exception 'idempotency_conflict' using errcode='PT409';end if;
 else
  select * into r from public.submit_interview_request(p_notes,p_start_utc,
   p_end_utc,p_time_zone,'en',p_idempotency_key::text);
  update public.interview_requests set title=btrim(p_title) where id=r.id returning * into r;
 end if;
 return next private.rad_appointment_json(r);
end $$;

create function public.reschedule_rad_appointment(p_appointment_id uuid,
 p_start_utc timestamptz,p_end_utc timestamptz,p_time_zone text,p_notes text)
returns setof jsonb language plpgsql security definer set search_path='' as $$
declare r public.interview_requests;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'role','')<>'authenticated' then
  raise exception 'authentication_required' using errcode='42501';end if;
 if p_notes is null or char_length(p_notes)>4000 or p_start_utc is null
  or not isfinite(p_start_utc)
  or (p_end_utc is not null and (not isfinite(p_end_utc) or p_end_utc<=p_start_utc)) then
  raise exception 'invalid_request' using errcode='22023';end if;
 select * into r from public.reschedule_interview_request(p_appointment_id,
  p_start_utc,p_end_utc,p_time_zone);
 update public.interview_requests set notes=p_notes where id=r.id and user_id=auth.uid() returning * into r;
 return next private.rad_appointment_json(r);
end $$;

create function public.cancel_rad_appointment(p_appointment_id uuid,p_reason text)
returns setof jsonb language plpgsql security definer set search_path='' as $$
declare r public.interview_requests;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'role','')<>'authenticated' then
  raise exception 'authentication_required' using errcode='42501';end if;
 if p_reason is null or char_length(btrim(p_reason)) not between 1 and 2000 then
  raise exception 'invalid_request' using errcode='22023';end if;
 select * into r from public.cancel_interview_request(p_appointment_id);
 update public.interview_requests set cancellation_reason=btrim(p_reason)
 where id=r.id and user_id=auth.uid() returning * into r;
 return next private.rad_appointment_json(r);
end $$;

revoke all on function public.list_rad_appointments(),
 public.submit_rad_appointment(text,timestamptz,timestamptz,text,text,uuid),
 public.reschedule_rad_appointment(uuid,timestamptz,timestamptz,text,text),
 public.cancel_rad_appointment(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.list_rad_appointments(),
 public.submit_rad_appointment(text,timestamptz,timestamptz,text,text,uuid),
 public.reschedule_rad_appointment(uuid,timestamptz,timestamptz,text,text),
 public.cancel_rad_appointment(uuid,text) to authenticated;
commit;
