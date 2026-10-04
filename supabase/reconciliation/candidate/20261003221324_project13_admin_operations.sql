
create table public.admin_case_notes (
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.applications(id) on delete cascade,
 author_id uuid not null references auth.users(id) on delete cascade,
 body text not null check (char_length(body) between 1 and 5000),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.admin_tasks (
 id uuid primary key default gen_random_uuid(),
 application_id uuid references public.applications(id) on delete cascade,
 title text not null check (char_length(title) between 1 and 200),
 status text not null default 'open' check (status in ('open','in_progress','blocked','done','cancelled')),
 priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
 assigned_to uuid references auth.users(id) on delete set null,
 created_by uuid not null references auth.users(id) on delete cascade,
 due_at timestamptz,
 completed_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.application_status_history (
 id bigint generated always as identity primary key,
 application_id uuid not null references public.applications(id) on delete cascade,
 from_status text,
 to_status text not null,
 changed_by uuid references auth.users(id) on delete set null,
 changed_at timestamptz not null default now()
);
create table public.admin_saved_views (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null check (char_length(name) between 1 and 100),
 resource text not null check (resource in ('applications','documents','research','ai','document_jobs')),
 filters jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 unique(owner_id,name,resource)
);

create index admin_case_notes_application_idx on public.admin_case_notes(application_id,created_at desc);
create index admin_case_notes_author_idx on public.admin_case_notes(author_id);
create index admin_tasks_status_due_idx on public.admin_tasks(status,due_at);
create index admin_tasks_application_idx on public.admin_tasks(application_id);
create index admin_tasks_assignee_idx on public.admin_tasks(assigned_to,status);
create index admin_tasks_creator_idx on public.admin_tasks(created_by);
create index application_status_history_application_idx on public.application_status_history(application_id,changed_at desc);

alter table public.admin_case_notes enable row level security;
alter table public.admin_tasks enable row level security;
alter table public.application_status_history enable row level security;
alter table public.admin_saved_views enable row level security;
grant select,insert,update,delete on public.admin_case_notes,public.admin_tasks,public.admin_saved_views to authenticated;
grant select on public.application_status_history to authenticated;
grant all privileges on public.admin_case_notes,public.admin_tasks,public.application_status_history,public.admin_saved_views to service_role;
grant usage,select on sequence public.application_status_history_id_seq to authenticated,service_role;

create policy "admins manage case notes" on public.admin_case_notes for all to authenticated
 using((select private.has_role(array['admin','super_admin']))) with check((select private.has_role(array['admin','super_admin'])) and author_id=(select auth.uid()));
create policy "admins manage tasks" on public.admin_tasks for all to authenticated
 using((select private.has_role(array['admin','super_admin']))) with check((select private.has_role(array['admin','super_admin'])));
create policy "admins read status history" on public.application_status_history for select to authenticated
 using((select private.has_role(array['admin','super_admin'])));
create policy "admins manage own saved views" on public.admin_saved_views for all to authenticated
 using(owner_id=(select auth.uid()) and (select private.has_role(array['admin','super_admin'])))
 with check(owner_id=(select auth.uid()) and (select private.has_role(array['admin','super_admin'])));
create policy "admins read applications" on public.applications for select to authenticated using((select private.has_role(array['admin','super_admin'])));
create policy "admins update applications" on public.applications for update to authenticated
 using((select private.has_role(array['admin','super_admin']))) with check((select private.has_role(array['admin','super_admin'])));
create policy "admins read documents" on public.documents for select to authenticated using((select private.has_role(array['admin','super_admin'])));
create policy "admins update documents" on public.documents for update to authenticated
 using((select private.has_role(array['admin','super_admin']))) with check((select private.has_role(array['admin','super_admin'])));

create or replace function private.record_application_status_change()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.status is distinct from new.status then
  insert into public.application_status_history(application_id,from_status,to_status,changed_by)
  values(new.id,old.status,new.status,auth.uid());
  insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,safe_metadata)
  values(auth.uid(),'status_change','application',new.id::text,jsonb_build_object('from',old.status,'to',new.status));
 end if;
 return new;
end $$;
alter function private.record_application_status_change() owner to postgres;
revoke all on function private.record_application_status_change() from public,anon,authenticated;
create trigger applications_status_history after update of status on public.applications
 for each row execute function private.record_application_status_change();

create or replace function public.set_user_role(p_user_id uuid,p_role text)
returns void language plpgsql security definer set search_path='' as $$
declare old_role text;
begin
 if not private.has_role(array['super_admin']) then raise exception 'forbidden' using errcode='42501'; end if;
 if p_role not in ('user','admin','super_admin') then raise exception 'invalid role' using errcode='22023'; end if;
 select role into old_role from public.profiles where id=p_user_id for update;
 if old_role is null then raise exception 'profile not found' using errcode='P0002'; end if;
 update public.profiles set role=p_role,updated_at=now() where id=p_user_id;
 insert into public.admin_audit_logs(actor_id,action,resource_type,resource_id,safe_metadata)
 values(auth.uid(),'role_change','profile',p_user_id::text,jsonb_build_object('from',old_role,'to',p_role));
end $$;
alter function public.set_user_role(uuid,text) owner to postgres;
revoke all on function public.set_user_role(uuid,text) from public,anon;
grant execute on function public.set_user_role(uuid,text) to authenticated;



