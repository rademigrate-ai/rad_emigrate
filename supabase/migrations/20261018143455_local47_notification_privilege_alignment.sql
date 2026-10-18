-- Forward-only least-privilege alignment, tested only in disposable local stacks.
begin;
-- Trigger invocation does not need clients to call trigger routines directly.
-- has_role is the sole private helper intentionally used by client RLS policies.
revoke execute on all functions in schema private from public,anon,authenticated;
grant execute on all functions in schema private to service_role;
grant execute on function private.has_role(text[]) to anon,authenticated;
alter default privileges for role postgres in schema private revoke execute on functions from public;
alter default privileges for role postgres in schema public revoke execute on functions from public;

create or replace function public.create_user_notification(
  p_user_id uuid,p_type text,p_title text,p_body text,p_action_path text default null,p_source_id uuid default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_type text:=coalesce(nullif(btrim(p_type),''),'system');
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' and not private.has_role(array['admin','super_admin']) then
    raise exception 'forbidden' using errcode='42501';
  end if;
  if p_user_id is null or nullif(btrim(p_title),'') is null or nullif(btrim(p_body),'') is null
    or char_length(p_title)>200 or char_length(p_body)>4000 or v_type not in ('feed','application','document','system')
    or (p_action_path is not null and (p_action_path not like '/%' or p_action_path like '//%'
      or position(chr(92) in p_action_path)>0 or p_action_path ~ '[[:cntrl:]]' or char_length(p_action_path)>1000)) then
    raise exception 'invalid_notification' using errcode='22023';
  end if;
  insert into public.notifications(user_id,type,title,body,action_path,source_id)
    values(p_user_id,v_type,btrim(p_title),p_body,p_action_path,p_source_id) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.create_user_notification(uuid,text,text,text,text,uuid) from public,anon;
grant execute on function public.create_user_notification(uuid,text,text,text,text,uuid) to authenticated,service_role;
notify pgrst,'reload schema';
commit;
