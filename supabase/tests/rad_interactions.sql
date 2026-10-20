begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values
 ('a4000000-0000-4000-8000-000000000001','synthetic-moderator@example.invalid'),
 ('a4000000-0000-4000-8000-000000000002','synthetic-commenter@example.invalid'),
 ('a4000000-0000-4000-8000-000000000003','synthetic-observer@example.invalid');
update public.profiles set role='admin' where id='a4000000-0000-4000-8000-000000000001';
create temporary table interaction_ids(kind text primary key,id uuid);
grant all on interaction_ids to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a4000000-0000-4000-8000-000000000001"}',true);
do $$ declare d jsonb;r jsonb;begin
 d:=public.save_feed_draft(jsonb_build_object('item_id',null,'expected_revision',0,'locale','en','title','Synthetic comments fixture','summary','No immigration advice.',
 'body',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'type','paragraph','text','Synthetic interaction body.','items','[]'::jsonb)),
 'category','announcement','article_id',null,'expires_at',null,'request_key',gen_random_uuid()))->'data';
 r:=jsonb_build_object('revision_id',d->'revision_id','content_hash',d->'content_hash','expected_revision',d->'revision','decision','approve','note','','request_key',gen_random_uuid());
 perform public.review_feed_draft(r);
 perform public.publish_feed_revision((r-'expected_revision'-'decision'-'note')||jsonb_build_object('request_key',gen_random_uuid()));
 insert into pg_temp.interaction_ids values('feed',(d->>'item_id')::uuid);
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a4000000-0000-4000-8000-000000000002"}',true);
do $$ declare r jsonb;request jsonb;feed uuid:=(select id from pg_temp.interaction_ids where kind='feed');begin
 request:=jsonb_build_object('feed_id',feed,'parent_id',null,'body','Synthetic comment, plain text only.','request_key',gen_random_uuid());
 r:=public.create_feed_comment(request);
 if r<>public.create_feed_comment(request) or r->'data'->>'state'<>'pending' then raise exception 'comment replay/state';end if;
 insert into pg_temp.interaction_ids values('comment',(r->'data'->>'id')::uuid);
 begin perform public.moderate_feed_comment(jsonb_build_object('comment_id',r->'data'->'id','expected_revision',1,'state','visible','note','forged moderator','request_key',gen_random_uuid()));raise exception 'moderator escalation';exception when sqlstate 'PT403' then null;end;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a4000000-0000-4000-8000-000000000003"}',true);
do $$ declare r jsonb;begin
 r:=public.list_feed_comments(jsonb_build_object('feed_id',(select id from pg_temp.interaction_ids where kind='feed'),'cursor',null,'limit',20));
 if jsonb_array_length(r->'data'->'items')<>0 then raise exception 'pending comment leak';end if;
 begin perform public.delete_feed_comment(jsonb_build_object('comment_id',(select id from pg_temp.interaction_ids where kind='comment'),'expected_revision',1,'request_key',gen_random_uuid()));raise exception 'cross-user comment deletion';exception when sqlstate 'PT404' then null;end;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a4000000-0000-4000-8000-000000000001"}',true);
select public.moderate_feed_comment(jsonb_build_object('comment_id',(select id from interaction_ids where kind='comment'),'expected_revision',1,'state','visible','note','Synthetic moderator decision','request_key',gen_random_uuid()));
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a4000000-0000-4000-8000-000000000003"}',true);
do $$ declare r jsonb;request jsonb;cursor text;first_id text;begin
 request:=jsonb_build_object('feed_id',(select id from pg_temp.interaction_ids where kind='feed'),'cursor',null,'limit',1);
 r:=public.list_feed_comments(request);
 if jsonb_array_length(r->'data'->'items')<>1 or (r->'data'->'items'->0->>'is_owner')::boolean then raise exception 'visible comment projection';end if;
 perform public.create_feed_comment(jsonb_build_object('feed_id',(select id from pg_temp.interaction_ids where kind='feed'),'parent_id',(select id from pg_temp.interaction_ids where kind='comment'),'body','Synthetic reply.','request_key',gen_random_uuid()));
 r:=public.list_feed_comments(request);cursor:=r->'page'->>'next_cursor';first_id:=r->'data'->'items'->0->>'id';
 if cursor is null then raise exception 'missing comment cursor';end if;
 r:=public.list_feed_comments(request||jsonb_build_object('cursor',cursor));
 if jsonb_array_length(r->'data'->'items')<>1 or r->'data'->'items'->0->>'id'=first_id then raise exception 'reply ownership/pagination';end if;
 begin perform public.list_feed_comments(request||jsonb_build_object('cursor',cursor,'limit',2));raise exception 'cursor filter tamper';exception when sqlstate 'PT409' then null;end;
 perform set_config('request.jwt.claims','{"role":"authenticated","sub":"a4000000-0000-4000-8000-000000000002"}',true);
 begin perform public.list_feed_comments(request||jsonb_build_object('cursor',cursor));raise exception 'cross-user cursor replay';exception when sqlstate 'PT409' then null;end;
 perform public.delete_feed_comment(jsonb_build_object('comment_id',(select id from pg_temp.interaction_ids where kind='comment'),'expected_revision',2,'request_key',gen_random_uuid()));
end $$;
reset role;
do $$ declare x jsonb;begin
 if private.rad_search_normalize('كِتاب ي ۱۲۳ ١٢٣')<> 'کتاب ی 123 123' then raise exception 'Persian normalization';end if;
 x:=private.rad_snippet('😀 alpha bravo','alpha');
 if x->'match_ranges'<> '[{"start":3,"end":8}]'::jsonb then raise exception 'UTF16 range: %',x;end if;
 x:=private.rad_snippet('Synthetic searchable immigration marker.','immigraton');
 if jsonb_array_length(x->'match_ranges')<>1 then raise exception 'typo snippet';end if;
end $$;
rollback;
