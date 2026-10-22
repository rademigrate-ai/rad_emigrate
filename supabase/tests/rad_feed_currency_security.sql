begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email) values
 ('a1000000-0000-4000-8000-000000000001','rad-feed-admin@example.invalid'),
 ('a1000000-0000-4000-8000-000000000002','rad-feed-user@example.invalid'),
 ('a1000000-0000-4000-8000-000000000003','rad-feed-other@example.invalid');
update public.profiles set role='admin' where id='a1000000-0000-4000-8000-000000000001';
select public.record_fx_observation(jsonb_build_object('provider','frankfurter','base','USD','quote','EUR','rate','0.5','observation_date',current_date,'source_url','https://api.frankfurter.dev/v2/rate/usd/eur'));

set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a1000000-0000-4000-8000-000000000002"}',true);
do $$ declare p jsonb;r jsonb;a jsonb; begin
 p:='{"expected_revision":0,"preferences":{"feed_updates":true,"application_updates":true,"document_updates":true,"currency_alerts":true,"email_enabled":false,"push_enabled":false,"sms_enabled":false,"locale":"en","time_zone":"Asia/Tehran","quiet_start":"23:00","quiet_end":"07:00","followed_country_codes":[],"followed_pathway_slugs":[]},"request_key":"c1000000-0000-4000-8000-000000000001"}';
 r:=public.save_notification_preferences(p);
 if (r->'data'->>'revision')::integer<>1 then raise exception 'preferences initial revision'; end if;
 begin perform public.save_notification_preferences(p||'{"request_key":"c1000000-0000-4000-8000-000000000002"}');raise exception 'stale prefs accepted';exception when sqlstate 'PT409' then null; end;
 r:=public.convert_currency('{"base":"USD","quote":"EUR","amount":"5.01","input_unit":"currency","output_unit":"currency","decimal_places":2,"allow_stale":false}');
 if (r->'data'->>'output_amount')::numeric<>2.50 then raise exception 'half even failed: %',r; end if;
 r:=public.get_fx_history(jsonb_build_object('base','USD','quote','EUR','date_from',(current_date-2)::text,'date_to',current_date::text,'cursor',null,'limit',20));
 if r->'data'->>'provider'<>'frankfurter' or jsonb_array_length(r->'data'->'missing_dates')<>2 then raise exception 'history provenance/gaps';end if;
 r:=public.convert_currency('{"base":"IRR","quote":"IRR","amount":"123","input_unit":"toman","output_unit":"currency","decimal_places":0,"allow_stale":false}');
 if r->'data'->>'output_amount'<>'1230' or r->'data'->'observation'<>'null'::jsonb or r->'data'->>'conversion_kind'<>'identity' then raise exception 'toman identity provenance';end if;
 a:=public.create_currency_alert('{"base":"USD","quote":"EUR","direction":"above","threshold":"0.6","cooldown_seconds":3600,"request_key":"c1000000-0000-4000-8000-000000000003"}');
 if a->'data'->>'rate_basis'<>'provider_reference' then raise exception 'alert basis'; end if;
 begin perform public.record_fx_observation('{}');raise exception 'client rate write admitted';exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a1000000-0000-4000-8000-000000000001"}',true);
do $$ declare r jsonb;request jsonb;draft jsonb;item uuid; begin
 request:='{"item_id":null,"expected_revision":0,"locale":"en","title":"Synthetic Feed","summary":"Synthetic review test","body":[{"id":"e1000000-0000-4000-8000-000000000001","type":"paragraph","text":"Synthetic full Feed body.","items":[]}],"category":"announcement","article_id":null,"expires_at":null,"request_key":"c1000000-0000-4000-8000-000000000004"}';
 draft:=public.save_feed_draft(request)->'data';item:=(draft->>'item_id')::uuid;
 begin perform public.get_feed_item(jsonb_build_object('item_id',item,'locale','en'));raise exception 'draft Feed leaked';exception when sqlstate 'PT404' then null;end;
 request:=jsonb_build_object('revision_id',draft->'revision_id','expected_revision',draft->'revision','decision','approve','content_hash',draft->'content_hash','note','','request_key','c1000000-0000-4000-8000-000000000005');
 perform public.review_feed_draft(request);
 r:=public.publish_feed_revision((request-'expected_revision'-'decision'-'note')||'{"request_key":"c1000000-0000-4000-8000-000000000006"}');
 r:=public.get_feed_item(jsonb_build_object('item_id',item,'locale','en'));
 if r->'data'->'body'->0->>'text'<>'Synthetic full Feed body.' then raise exception 'full body missing'; end if;
 r:=public.list_feed('{"locale":"en","category":null,"saved_only":false,"cursor":null,"limit":20}');
 if jsonb_array_length(r->'data'->'items')<>1 then raise exception 'Feed list mismatch'; end if;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"a1000000-0000-4000-8000-000000000002"}',true);
do $$ declare r jsonb;n uuid; begin
 r:=public.list_notifications('{"unread_only":true,"type":null,"cursor":null,"limit":20}');
 if (r->'data'->>'unread_count')::integer<>1 then raise exception 'notification count: %',r; end if;
 if r->'data'->'items'->0->'target'->>'kind'<>'feed_item' then raise exception 'typed Feed target missing'; end if;
 n:=(r->'data'->'items'->0->>'id')::uuid;
 perform public.mark_notification_read(jsonb_build_object('notification_id',n,'request_key','c1000000-0000-4000-8000-000000000007'));
 perform set_config('request.jwt.claims','{"role":"authenticated","sub":"a1000000-0000-4000-8000-000000000003"}',true);
 begin perform public.mark_notification_read(jsonb_build_object('notification_id',n,'request_key','c1000000-0000-4000-8000-000000000008'));raise exception 'cross user read admitted';exception when sqlstate 'PT404' then null;end;
 r:=public.list_notifications('{"unread_only":false,"type":null,"cursor":null,"limit":20}');
 if jsonb_array_length(r->'data'->'items')<>0 then raise exception 'cross user notification leak'; end if;
end $$;
reset role;
rollback;
