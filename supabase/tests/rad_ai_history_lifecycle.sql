-- Synthetic fixture only; all data and role changes roll back.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values
 ('a1000000-0000-4000-8000-000000000001','ai-history-owner@example.invalid'),
 ('a1000000-0000-4000-8000-000000000002','ai-history-other@example.invalid');
insert into public.ai_sessions(id,user_id) values
 ('a1000000-0000-4000-8000-000000000011','a1000000-0000-4000-8000-000000000001'),
 ('a1000000-0000-4000-8000-000000000012','a1000000-0000-4000-8000-000000000002');
insert into public.ai_session_messages(session_id,user_id,role,content) values
 ('a1000000-0000-4000-8000-000000000011','a1000000-0000-4000-8000-000000000001','user','SYNTHETIC private fixture');

select set_config('request.jwt.claims','{"role":"authenticated","sub":"a1000000-0000-4000-8000-000000000002"}',true);
set local role authenticated;
do $$declare changed int;begin
 update public.ai_sessions set title='foreign' where id='a1000000-0000-4000-8000-000000000011';
 get diagnostics changed=row_count;
 if changed<>0 then raise exception 'foreign rename allowed';end if;
 delete from public.ai_sessions where id='a1000000-0000-4000-8000-000000000011';
 get diagnostics changed=row_count;
 if changed<>0 then raise exception 'foreign deletion allowed';end if;
end$$;
reset role;

select set_config('request.jwt.claims','{"role":"authenticated","sub":"a1000000-0000-4000-8000-000000000001"}',true);
set local role authenticated;
do $$begin
 update public.ai_sessions set title='SYNTHETIC persisted title' where id='a1000000-0000-4000-8000-000000000011';
 if not found then raise exception 'owner rename refused';end if;
 if not exists(select 1 from public.ai_sessions where id='a1000000-0000-4000-8000-000000000011' and title='SYNTHETIC persisted title') then raise exception 'rename not persisted';end if;
 begin
  update public.ai_sessions set title=repeat('x',121) where id='a1000000-0000-4000-8000-000000000011';
  raise exception 'oversized title accepted';
 exception when check_violation then null;end;
 begin
  update public.ai_sessions set title='   ' where id='a1000000-0000-4000-8000-000000000011';
  raise exception 'blank title accepted';
 exception when check_violation then null;end;
 delete from public.ai_sessions where id='a1000000-0000-4000-8000-000000000011';
 if not found then raise exception 'owner deletion refused';end if;
end$$;
reset role;
do $$begin
 if exists(select 1 from public.ai_session_messages where session_id='a1000000-0000-4000-8000-000000000011') then raise exception 'deleted session retained its messages';end if;
 if not exists(select 1 from public.ai_sessions where id='a1000000-0000-4000-8000-000000000012') then raise exception 'unrelated session deleted';end if;
 if has_table_privilege('anon','public.ai_sessions','DELETE') then raise exception 'anonymous delete grant';end if;
end$$;
rollback;
