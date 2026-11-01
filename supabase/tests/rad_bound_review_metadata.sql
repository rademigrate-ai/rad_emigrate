-- Private review metadata cannot become a lookup oracle for a normal user.
-- Synthetic local/CI identity only, always rolled back.
begin;
insert into auth.users(id,email) values('8b000000-0000-4000-8000-000000000001','metadata-security-user@example.invalid');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"8b000000-0000-4000-8000-000000000001"}',true);
set local role authenticated;
do $$begin
 begin
  perform public.get_research_review_context_v2('8b000000-0000-4000-8000-000000000099');
  raise exception 'FAIL ordinary user accessed private review context';
 exception when sqlstate 'PT403' then null;end;
end $$;
reset role;
set local role anon;
do $$begin
 begin
  perform public.get_research_review_context_v2('8b000000-0000-4000-8000-000000000099');
  raise exception 'FAIL anonymous review context';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
set local role service_role;
do $$begin
 begin
  perform public.get_research_review_context_v2('8b000000-0000-4000-8000-000000000099');
  raise exception 'FAIL service worker review context';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
