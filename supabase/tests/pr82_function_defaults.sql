-- Actual CREATE probes, rolled back; explicit application RPC grants are separate.
begin;
create function public.pr82_default_execute_probe() returns boolean language sql as $$select true$$;
create function private.pr82_default_execute_probe() returns boolean language sql as $$select true$$;
do $$declare schema_name text;actor text;
begin
 foreach schema_name in array array['public','private'] loop
  foreach actor in array array['anon','authenticated'] loop
   if has_function_privilege(actor,format('%I.pr82_default_execute_probe()',schema_name),'EXECUTE') then
    raise exception 'new % function unexpectedly executable by %',schema_name,actor;
   end if;
  end loop;
 end loop;
end $$;
select 'PASS: newly created public/private functions deny client execution by default' as result;
rollback;
