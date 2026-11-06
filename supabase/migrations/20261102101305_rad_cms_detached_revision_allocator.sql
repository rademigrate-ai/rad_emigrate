-- A detached unverified revision must not block the next ordinary Admin save.
-- Keep optimistic concurrency on the locked current head; allocate the next
-- number across all revisions for this article/locale, including detached ones.
-- No head, content, actor, publication pointer, ownership or ACL is changed here.
do $rad_detached_allocator$
declare
  target oid := to_regprocedure('private.rad_save_article(jsonb)');
  original_source text;
  definition text;
  properties_before jsonb;
  properties_after jsonb;
  needle constant text := 'coalesce(r.revision,0)+1';
  replacement constant text := '(select coalesce(max(previous.revision),0)+1 from public.visa_article_revisions previous where previous.article_id=h.article_id and previous.locale=h.locale)';
begin
  if target is null then
    raise exception 'DETACHED_ALLOCATOR_REQUIRED_HELPER_MISSING';
  end if;
  select p.prosrc, to_jsonb(p)-'prosrc'
    into original_source, properties_before
    from pg_proc p where p.oid=target;
  if md5(original_source)='7143698d1557b881d2502913bee837ca' then
    return;
  end if;
  if md5(original_source)<>'9d3394feffb9380ca4df7934296c82f8'
     or length(original_source)-length(replace(original_source,needle,''))<>length(needle) then
    raise exception 'DETACHED_ALLOCATOR_BASELINE_BODY_MISMATCH';
  end if;
  definition := pg_get_functiondef(target);
  if length(definition)-length(replace(definition,needle,''))<>length(needle) then
    raise exception 'DETACHED_ALLOCATOR_DEFINITION_MISMATCH';
  end if;
  execute replace(definition,needle,replacement);
  select to_jsonb(p)-'prosrc' into properties_after from pg_proc p where p.oid=target;
  if properties_after is distinct from properties_before
     or (select md5(p.prosrc) from pg_proc p where p.oid=target)<>'7143698d1557b881d2502913bee837ca' then
    raise exception 'DETACHED_ALLOCATOR_RESULT_OR_PRIVILEGE_MISMATCH';
  end if;
end $rad_detached_allocator$;
