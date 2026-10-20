begin;
-- A worker must use server-generated section hashes instead of attempting to
-- reproduce PostgreSQL jsonb canonicalization in JavaScript or in a model.
create function public.get_research_article_base(p_job_id uuid,p_lease_token uuid,p_article_id uuid,p_locale text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare j private.rad_research_jobs;r public.visa_article_revisions;a public.visa_articles;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'forbidden' using errcode='PT403';end if;
 if p_locale is null or p_locale not in ('fa','en') then raise exception 'invalid_locale' using errcode='PT422';end if;
 select * into j from private.rad_research_jobs where id=p_job_id and lease_token=p_lease_token and lease_until>now() and status='running' and kind='research_refresh';
 if not found then raise exception 'lease_invalid' using errcode='PT409';end if;
 select * into a from public.visa_articles where id=p_article_id;
 if not found then raise exception 'not_found' using errcode='PT404';end if;
 if not exists(select 1 from private.authority_entities authority where (j.request->'authority_ids') ? authority.id::text
 and (authority.country_code is null or authority.country_code=a.country_code)) then raise exception 'article_scope_forbidden' using errcode='PT403';end if;
 select rev.* into r from public.visa_article_heads h join public.visa_article_revisions rev on rev.id=h.head_id where h.article_id=p_article_id and h.locale=p_locale;
 if not found then raise exception 'not_found' using errcode='PT404';end if;
 return jsonb_build_object('article_id',a.id,'locale',r.locale,'revision_id',r.id,'revision',r.revision,'sections',r.body->'sections',
 'section_hashes',(select jsonb_agg(jsonb_build_object('section_id',s->'id','before_hash',encode(extensions.digest(s::text,'sha256'),'hex')) order by (s->>'order')::integer) from jsonb_array_elements(r.body->'sections') s));
end $$;
revoke all on function public.get_research_article_base(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.get_research_article_base(uuid,uuid,uuid,text) to service_role;
notify pgrst,'reload schema';
commit;
