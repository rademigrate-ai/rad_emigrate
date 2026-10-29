"""Generate the exact review-only Staging transaction; no hosted connection."""

import argparse
import gzip
import hashlib
import json
from pathlib import Path

from tools.content_completion.country_labels import COUNTRIES
from tools.content_consolidation.regression import quote
from tools.plan3_content.dataset import read_jsonl, uid

PROJECT = "epolbumcfbohtmgvomki"
ACTOR = "0166163b-582b-4d2e-82dc-f9942c2f80b5"


def literal(value):
    return (
        quote(json.dumps(value, ensure_ascii=False, separators=(",", ":"))) + "::jsonb"
    )


def prepare(directory, output, project):
    if project != PROJECT:
        raise ValueError("staging_only")
    new = read_jsonl(directory / "new-draft-payloads.jsonl.gz")
    changes = read_jsonl(directory / "canonical-revision-payloads.jsonl.gz")
    retirements = read_jsonl(directory / "source-reading-retirements.jsonl.gz")
    originals = {
        (r["article_id"], r["locale"]): r
        for r in read_jsonl(
            Path("artifacts/RAD_CONTENT_CONSOLIDATION_20261026/articles.jsonl.gz")
        )
    }
    maps = {
        (m["article_id"], m["locale"]): m
        for m in read_jsonl(directory / "reference-maps.jsonl.gz")
    }
    sources = read_jsonl(directory / "source-intake.jsonl.gz")
    files = {
        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(directory.glob("*.json*"))
    }
    manifest = hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()
    batch = uid("rad-content-continuation:" + manifest)
    country_pages = json.loads(
        (directory / "canonical-page-inventory.json").read_text(encoding="utf-8")
    )
    countries = sorted(
        {c for r in country_pages for c in r["country_codes"]}
        | {c for r in new for c in r["item"]["country_codes"]}
    )
    lines = [
        "-- REVIEW ONLY. Execute only after exact Owner authorization and verified hosted backup/restore.",
        "-- Staging epolbumcfbohtmgvomki only; draft/unverified; no migrations or publication.",
        "begin;",
        "set local lock_timeout='5s';",
        "set local statement_timeout='120s';",
        "set local standard_conforming_strings=on;",
        "select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);",
        "do $$begin if not exists(select 1 from private.rad_editorial_import_target where project_ref='epolbumcfbohtmgvomki' and not enabled) then raise exception 'staging_gate_changed';end if;end$$;",
        "create temporary table recovery_publication_before on commit drop as select article_id,locale,published_id from public.visa_article_heads;",
        "update private.rad_editorial_import_target set enabled=true where project_ref='epolbumcfbohtmgvomki';",
        "do $recovery$ declare s jsonb;cs uuid;doc uuid;snap uuid;v public.visa_article_revisions;rid uuid;composition jsonb;request jsonb;prior_catalog jsonb;prior_identity jsonb;begin",
    ]
    # The existing import RPC creates sources for new articles. Direct canonical
    # contributions also need original snapshots, under identical strict checks.
    lines += [
        "for s in select value from jsonb_array_elements("
        + literal(sources)
        + ") loop",
        "if s->>'body_sha256' is distinct from encode(extensions.digest(s->>'body_text','sha256'),'hex') or s->>'url'!~'^https://(radvisa[.]com|digivisa[.]ir|radmohajer[.]ir)/' then raise exception 'source_integrity';end if;",
        "cs:=(s->>'content_source_id')::uuid;doc:=(s->>'source_id')::uuid;snap:=(s->>'snapshot_id')::uuid;",
        "if exists(select 1 from public.source_documents where (canonical_url=s->>'url' and id<>doc) or (id=doc and canonical_url<>s->>'url')) then raise exception 'source_identity_conflict';end if;",
        "if exists(select 1 from public.source_snapshots where (id=snap and (document_id<>doc or content_hash<>s->>'body_sha256' or normalized_text<>s->>'body_text')) or (document_id=doc and content_hash=s->>'body_sha256' and id<>snap)) then raise exception 'snapshot_identity_conflict';end if;",
        "insert into public.content_sources(id,publisher,source_type,title,url,language_code,retrieved_at,content_hash) select cs,'RAD first-party editorial source, not legal verification','rad_official',s->>'title',s->>'url',s->>'language',(s->>'retrieved_at')::timestamptz,s->>'body_sha256' where not exists(select 1 from public.content_sources where url=s->>'url');",
        "select id into cs from public.content_sources where url=s->>'url' order by created_at,id limit 1;",
        "insert into public.source_documents(id,canonical_url,source_id,source_authority,title,language_code,jurisdiction,last_content_hash) values(doc,s->>'url',cs,'rad_official',s->>'title',s->>'language','',s->>'body_sha256') on conflict(id) do nothing;",
        "insert into public.source_snapshots(id,document_id,content_hash,normalized_text,http_status,fetched_at,metadata) values(snap,doc,s->>'body_sha256',s->>'body_text',200,(s->>'retrieved_at')::timestamptz,jsonb_build_object('raw_html_sha256',s->>'raw_html_sha256','recovery_manifest',"
        + quote(manifest)
        + ",'factual_verification','not_verified')) on conflict(id) do nothing;",
        "perform private.rad_classify_snapshot(snap);end loop;",
    ]
    for country in countries:
        identity = uid("rad-recovered-country:" + country)
        fa, en = COUNTRIES[country][0], COUNTRIES[country][-1]
        slug = "source-" + country.lower()
        lines.append(
            f"insert into public.destinations(id,code,slug,status) select '{identity}','{country}','{slug}','draft' where not exists(select 1 from public.destinations where code='{country}');"
        )
        for locale, name in (("fa", fa), ("en", en)):
            lines.append(
                f"insert into public.destination_localizations(destination_id,locale,name,summary) select id,'{locale}',{quote(name)},'' from public.destinations where code='{country}' on conflict(destination_id,locale) do nothing;"
            )
    for row in new:
        lines.append(
            f"perform public.import_editorial_draft('{batch}','{manifest}','{ACTOR}',{literal(row['item'])},{literal(row['sources'])});"
        )
        capture = maps[(row["article_id"], row["item"]["locale"])]
        lines.append(
            f"perform public.attach_editorial_reference_map('{row['article_id']}','{capture['locale']}',1,'{manifest}',{literal(capture['map'])});"
        )
    for row in changes:
        item = row["item"]
        a, locale = row["article_id"], item["locale"]
        # Lock first; an unchanged original import may be revised. A full exact
        # retry is recognized only by our marker AND exact target rich sections.
        reclassification = "catalog_reclassification" in row
        country_association = (
            reclassification
            and row["catalog_reclassification"].get("kind")
            == "body_evidenced_country_association"
        )
        prior_identity_statement = (
            "prior_identity:=null;"
            if country_association
            else f"select to_jsonb(x) into prior_identity from public.visa_articles x where x.id='{a}';if prior_identity->>'kind'<>'main' or prior_identity->>'pathway_slug'<>'study' then raise exception 'classification_identity_changed';end if;"
        )
        prior_statement = (
            f"select to_jsonb(c) into strict prior_catalog from private.rad_editorial_catalog c where c.article_id='{a}' for update;if prior_catalog->'composition' is distinct from {literal(row['catalog_reclassification']['expected_composition'])} or prior_catalog->>'active'<>'true' or prior_catalog->'country_codes' is distinct from {literal(originals[(a, locale)]['country_codes'])} or prior_catalog->>'content_class'<>{quote(originals[(a, locale)]['content_class'])} or prior_catalog->>'category'<>{quote(originals[(a, locale)]['category'])} or not ({retirement_head_guard(a, locale, originals[(a, locale)]['sections'])}) then raise exception 'classification_catalog_changed';end if;"
            + prior_identity_statement
            if reclassification
            else "prior_catalog:=null;prior_identity:=null;"
        )
        lines += [
            f"perform pg_advisory_xact_lock(hashtextextended('rad-editorial:{a}',0));",
            f"select r.* into strict v from public.visa_article_revisions r join public.visa_article_heads h on h.head_id=r.id where h.article_id='{a}' and h.locale='{locale}' for update of h;",
            "select r.composition into composition from private.rad_editorial_rich_revisions r where r.revision_id=v.id;",
            f"if composition->'content_recovery'->>'manifest'={quote(manifest)} and composition->'sections'={literal(item['sections'])} then null;else",
            f"if v.revision<>1 or private.rad_article_state(v.id)<>'draft' or private.rad_article_verification(v.id)<>'unverified' or not exists(select 1 from private.rad_editorial_import_journal where article_id='{a}' and locale='{locale}' and revision_id=v.id and rolled_back_at is null) or composition->'sections' is distinct from {literal(originals[(a, locale)]['sections'])} then raise exception 'existing_head_requires_manual_reconciliation';end if;",
            f"request:={literal(item['draft_request'])}||jsonb_build_object('expected_revision',v.revision,'request_key','{uid('recovery-revision:' + manifest + ':' + a + ':' + locale)}');",
            f'perform set_config(\'request.jwt.claims\',\'{{"role":"service_role","sub":"{ACTOR}"}}\',true);',
            prior_statement,
            f"if prior_catalog is not null then prior_catalog:=prior_catalog||jsonb_build_object('recovery_prior_country_titles',coalesce((select jsonb_agg(country_code) from private.rad_editorial_country_titles where article_id='{a}'),'[]'::jsonb));end if;",
            "rid:=private.rad_save_article(request);",
            f"composition:={literal({k: v for k, v in item.items() if k != 'draft_request'})}||jsonb_build_object('content_recovery',jsonb_build_object('manifest','{manifest}','parent_revision_id',v.id,'parent_catalog',prior_catalog,'parent_identity',prior_identity));",
            "insert into private.rad_editorial_rich_revisions(revision_id,composition) values(rid,composition) on conflict(revision_id) do update set composition=excluded.composition where private.rad_editorial_rich_revisions.composition->'sections'=excluded.composition->'sections';",
            f"perform public.attach_editorial_reference_map('{a}','{locale}',v.revision+1,'{manifest}',{literal(maps[(a, locale)]['map'])});",
            "end if;",
        ]
        if country_association:
            lines += [
                f"update private.rad_editorial_catalog c set country_codes=array[{','.join(quote(c) for c in item['country_codes'])}]::text[],composition=r.composition from public.visa_article_heads h join private.rad_editorial_rich_revisions r on r.revision_id=h.head_id where c.article_id='{a}' and h.article_id=c.article_id and h.locale='{locale}' and r.composition->'content_recovery'->>'manifest'='{manifest}' and c.content_class='editorial' and c.composition=r.composition->'content_recovery'->'parent_catalog'->'composition';",
            ]
            for country in item["country_codes"]:
                lines.append(
                    f"insert into private.rad_editorial_country_titles(country_code,article_id) values('{country}','{a}') on conflict do nothing;"
                )
        elif reclassification:
            lines += [
                f"update private.rad_editorial_catalog c set content_class='editorial',category='education',composition=r.composition from public.visa_article_heads h join private.rad_editorial_rich_revisions r on r.revision_id=h.head_id where c.article_id='{a}' and h.article_id=c.article_id and h.locale='{locale}' and r.composition->'content_recovery'->>'manifest'='{manifest}' and c.content_class='canonical' and c.composition=r.composition->'content_recovery'->'parent_catalog'->'composition';",
                f"update public.visa_articles set kind='related',pathway_slug='topic-{a.replace('-', '')}' where id='{a}' and kind='main' and pathway_slug='study';",
                f"insert into private.rad_editorial_country_titles(country_code,article_id) values('IR','{a}') on conflict do nothing;",
            ]
        if reclassification:
            lines.append(
                f"if not exists(select 1 from private.rad_editorial_catalog c join public.visa_article_heads h on h.article_id=c.article_id join private.rad_editorial_rich_revisions r on r.revision_id=h.head_id where c.article_id='{a}' and h.locale='{locale}' and c.active and c.composition=r.composition and c.content_class={quote(item['content_class'])} and c.category={quote(item['category'])} and to_jsonb(c.country_codes)={literal(item['country_codes'])}) then raise exception 'classification_target_catalog_changed';end if;"
            )
    # Hide a historical duplicate only after its full original blocks have been
    # placed in canonical bodies. Refuse any changed catalog, revision or review.
    # The original immutable rich revision, source snapshots and relations remain.
    for row in retirements:
        a, locale = row["article_id"], row["locale"]
        untouched = retirement_head_guard(a, locale, row["expected_sections"])
        expected = row["expected_composition"]
        lines += [
            f"perform pg_advisory_xact_lock(hashtextextended('rad-editorial:{a}',0));",
            f"perform 1 from public.visa_article_heads where article_id='{a}' and locale='{locale}' for update;",
            f"select to_jsonb(c) into strict prior_catalog from private.rad_editorial_catalog c where c.article_id='{a}' for update;",
            f"if not ({untouched}) then raise exception 'duplicate_reader_changed_or_reviewed';end if;",
            f"if prior_catalog->'composition'->'content_recovery_retirement'->>'manifest'='{manifest}' and prior_catalog->>'active'='false' and (prior_catalog->'composition')-'content_recovery_retirement'={literal(expected)} then null;else",
            f"if prior_catalog->>'active'<>'true' or prior_catalog->>'content_class'<>'editorial' or prior_catalog->'composition' is distinct from {literal(expected)} or prior_catalog->'country_codes' is distinct from {literal(expected['country_codes'])} or prior_catalog->>'category'<>{quote(expected['category'])} then raise exception 'duplicate_reader_catalog_changed';end if;",
            f"update private.rad_editorial_catalog c set active=false,composition=c.composition||jsonb_build_object('content_recovery_retirement',jsonb_build_object('manifest','{manifest}','replacement_article_ids',{literal(row['replacement_article_ids'])},'reason',{quote(row['reason'])})) where c.article_id='{a}';",
            "end if;",
        ]
    # New country links stay proposed. Only new parent/related pairs are added,
    # so existing human link decisions and their original justifications survive.
    for row in new + changes:
        item = row["item"]
        if item["content_class"] != "editorial" or not item["country_codes"]:
            continue
        lines.append(
            "perform public.propose_editorial_relations(coalesce((select jsonb_agg(jsonb_build_object('parent_id',p.article_id,'related_id',"
            + quote(item["article_id"])
            + ",'country_overlap',to_jsonb(p.country_codes),'rank',0,'relevance_basis','explicit_recovered_source_country_proposal','recovery_manifest',"
            + quote(manifest)
            + ",'state','proposed','reviewer_id',null)) from private.rad_editorial_catalog p where p.active and p.content_class='canonical' and p.country_codes && array["
            + ",".join(quote(c) for c in item["country_codes"])
            + "]::text[] and not exists(select 1 from private.rad_editorial_relations r where r.parent_id=p.article_id and r.related_id="
            + quote(item["article_id"])
            + "::uuid)),'[]'::jsonb));"
        )
    for row in new:
        item = row["item"]
        if item["content_class"] != "canonical":
            continue
        lines.append(
            "perform public.propose_editorial_relations(coalesce((select jsonb_agg(jsonb_build_object('parent_id',"
            + quote(item["article_id"])
            + ",'related_id',c.article_id,'country_overlap',to_jsonb(c.country_codes),'rank',0,'relevance_basis','existing_independent_country_article_for_new_category','recovery_manifest',"
            + quote(manifest)
            + ",'state','proposed','reviewer_id',null)) from private.rad_editorial_catalog c where c.active and c.content_class='editorial' and c.country_codes && array["
            + ",".join(quote(c) for c in item["country_codes"])
            + "]::text[] and not exists(select 1 from private.rad_editorial_relations r where r.parent_id="
            + quote(item["article_id"])
            + "::uuid and r.related_id=c.article_id)),'[]'::jsonb));"
        )
    for row in new + changes:
        a, locale = row["article_id"], row["item"]["locale"]
        lines += [
            f'perform set_config(\'request.jwt.claims\',\'{{"role":"authenticated","sub":"{ACTOR}"}}\',true);',
            f"if public.get_editorial_article('{a}','{locale}',true)->'data'->'rich_sections' is distinct from {literal(row['item']['sections'])} then raise exception 'admin_reader_body_mismatch';end if;",
            f"begin perform public.get_editorial_article('{a}','{locale}',false);raise exception 'draft_leaked';exception when sqlstate 'PT404' then null;end;",
        ]
    lines += [
        "end $recovery$;",
        "do $$begin if exists(select 1 from recovery_publication_before b join public.visa_article_heads h using(article_id,locale) where b.published_id is distinct from h.published_id) then raise exception 'publication_pointer_changed';end if;end$$;",
        "update private.rad_editorial_import_target set enabled=false where project_ref='epolbumcfbohtmgvomki';",
        "commit;",
    ]
    sql = "\n".join(lines) + "\n"
    if sql.count("$recovery$") != 2:
        raise ValueError("source_contains_sql_delimiter")
    output.mkdir(parents=True, exist_ok=True)
    (output / "PROPOSED_IMPORT_REVIEW_ONLY.sql.gz").write_bytes(
        gzip.compress(sql.encode(), mtime=0)
    )
    rollback = [
        "-- REVIEW ONLY. Staging only; immutable revisions and snapshots remain preserved.",
        "begin;",
        "set local lock_timeout='5s';",
        "select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);",
        "do $$begin if not exists(select 1 from private.rad_editorial_import_target where project_ref='epolbumcfbohtmgvomki' and not enabled) then raise exception 'staging_gate_changed';end if;end$$;",
        "update private.rad_editorial_import_target set enabled=true where project_ref='epolbumcfbohtmgvomki';",
        "create temporary table recovery_rollback_eligible(article_id uuid,locale text,head_id uuid,parent_id uuid,prior_catalog jsonb,prior_identity jsonb) on commit drop;",
    ]
    for row in changes:
        a, locale = row["article_id"], row["item"]["locale"]
        guard = (
            " and exists(select 1 from private.rad_editorial_catalog c where c.article_id=h.article_id and c.active and c.composition=r.composition and c.content_class="
            + quote(row["item"]["content_class"])
            + " and c.category="
            + quote(row["item"]["category"])
            + " and to_jsonb(c.country_codes)="
            + literal(row["item"]["country_codes"])
            + ")"
            + " and "
            + unreviewed_links_guard(a)
            if "catalog_reclassification" in row
            else ""
        )
        rollback.append(
            "select pg_advisory_xact_lock(hashtextextended('rad-editorial:"
            + a
            + "',0));"
        )
        rollback.append(
            "insert into recovery_rollback_eligible select h.article_id,h.locale,h.head_id,(r.composition->'content_recovery'->>'parent_revision_id')::uuid,nullif(r.composition->'content_recovery'->'parent_catalog','null'),nullif(r.composition->'content_recovery'->'parent_identity','null') from public.visa_article_heads h join private.rad_editorial_rich_revisions r on r.revision_id=h.head_id join public.visa_article_revisions v on v.id=r.revision_id where h.article_id="
            + quote(a)
            + "::uuid and h.locale="
            + quote(locale)
            + " and v.revision=2 and v.title="
            + quote(row["item"]["title"])
            + " and r.composition->'content_recovery'->>'manifest'="
            + quote(manifest)
            + " and r.composition->'sections'="
            + literal(row["item"]["sections"])
            + " and private.rad_article_state(v.id)='draft' and private.rad_article_verification(v.id)='unverified' and not exists(select 1 from public.visa_article_heads where published_id=v.id) and not exists(select 1 from private.rad_editorial_clearances where revision_id=v.id)"
            + guard
            + " for update of h;"
        )
    rollback += [
        "delete from private.rad_editorial_relations r using recovery_rollback_eligible e where r.related_id=e.article_id and r.justification->>'recovery_manifest'="
        + quote(manifest)
        + " and r.state='proposed' and r.rank=0 and r.revision=1 and r.reviewed_by is null and r.reviewed_at is null;",
        "delete from private.rad_editorial_country_titles t using recovery_rollback_eligible e where t.article_id=e.article_id and e.prior_catalog is not null and not (coalesce(e.prior_catalog->'recovery_prior_country_titles','[]'::jsonb)?t.country_code) and t.country_code=any((select c.country_codes from private.rad_editorial_catalog c where c.article_id=e.article_id)::text[]) and t.state='proposed' and t.rank=0 and t.revision=1 and t.reviewed_by is null and t.reviewed_at is null;",
        "update private.rad_editorial_catalog c set content_class=e.prior_catalog->>'content_class',category=e.prior_catalog->>'category',country_codes=array(select jsonb_array_elements_text(e.prior_catalog->'country_codes')),composition=e.prior_catalog->'composition' from recovery_rollback_eligible e where c.article_id=e.article_id and e.prior_catalog is not null;",
        "update public.visa_articles a set kind=e.prior_identity->>'kind',pathway_slug=e.prior_identity->>'pathway_slug' from recovery_rollback_eligible e where a.id=e.article_id and e.prior_identity is not null;",
        "update public.visa_article_heads h set head_id=e.parent_id from recovery_rollback_eligible e where h.article_id=e.article_id and h.locale=e.locale and h.head_id=e.head_id;",
    ]
    for row in retirements:
        a, locale = row["article_id"], row["locale"]
        rollback += [
            f"select pg_advisory_xact_lock(hashtextextended('rad-editorial:{a}',0));",
            f"update private.rad_editorial_catalog c set active=true,composition=c.composition-'content_recovery_retirement' where c.article_id='{a}' and not c.active and c.content_class='editorial' and c.composition->'content_recovery_retirement'->>'manifest'='{manifest}' and c.composition-'content_recovery_retirement'={literal(row['expected_composition'])} and ({retirement_head_guard(a, locale, row['expected_sections'])});",
        ]
    rollback += [
        "select public.rollback_editorial_import('" + batch + "');",
        "update private.rad_editorial_import_target set enabled=false where project_ref='epolbumcfbohtmgvomki';",
        "commit;",
    ]
    rollback_sql = "\n".join(rollback) + "\n"
    (output / "PROPOSED_ROLLBACK_REVIEW_ONLY.sql.gz").write_bytes(
        gzip.compress(rollback_sql.encode(), mtime=0)
    )
    source_values = ",".join(
        "("
        + ",".join(
            quote(s[k]) for k in ("source_id", "url", "snapshot_id", "body_sha256")
        )
        + ")"
        for s in sources
    )
    expected_heads = [(r["article_id"], r["item"]["locale"]) for r in changes] + [
        (r["article_id"], r["locale"]) for r in retirements
    ]
    head_values = ",".join(
        "(" + quote(a) + "," + quote(locale) + ")" for a, locale in expected_heads
    )
    new_ids = ",".join(quote(r["article_id"]) + "::uuid" for r in new)
    preflight = (
        "-- SELECT ONLY. Readiness evidence; does not create a backup or authorize writes.\n"
        + "with expected_sources(id,url,snapshot_id,hash) as(values "
        + source_values
        + "),expected_heads(id,locale) as(values "
        + head_values
        + ")\n"
        + "select jsonb_build_object('project','epolbumcfbohtmgvomki','observed_at',now(),'server_version',current_setting('server_version'),'planned_new_article_locales',"
        + str(len(new))
        + ",'planned_existing_heads',"
        + str(len(expected_heads))
        + ",'existing_new_article_ids',(select count(*) from public.visa_articles where id in("
        + new_ids
        + ")),"
        + "'source_identity_conflicts',(select count(*) from expected_sources e join public.source_documents d on d.canonical_url=e.url or d.id=e.id::uuid where d.id<>e.id::uuid or d.canonical_url<>e.url),'snapshot_conflicts',(select count(*) from expected_sources e join public.source_snapshots s on s.id=e.snapshot_id::uuid or (s.document_id=e.id::uuid and s.content_hash=e.hash) where s.id<>e.snapshot_id::uuid or s.document_id<>e.id::uuid or s.content_hash<>e.hash),"
        + "'changed_or_missing_existing_heads',(select count(*) from expected_heads e left join public.visa_article_heads h on h.article_id=e.id::uuid and h.locale=e.locale left join public.visa_article_revisions rv on rv.id=h.head_id left join private.rad_editorial_catalog c on c.article_id=h.article_id where rv.id is null or rv.revision<>1 or not coalesce(c.active,false) or h.published_id is not null or private.rad_article_state(rv.id)<>'draft' or private.rad_article_verification(rv.id)<>'unverified' or exists(select 1 from private.rad_editorial_clearances where revision_id=rv.id)),'missing_destination_codes',(select jsonb_agg(code order by code) from unnest(array["
        + ",".join(quote(c) for c in countries)
        + "]::text[])code where not exists(select 1 from public.destinations d where d.code=code.code)),"
        + "'rich_revisions',(select count(*) from private.rad_editorial_rich_revisions),'reference_maps',(select count(*) from private.rad_editorial_reference_maps where active),'import_gate',(select jsonb_agg(to_jsonb(t)) from private.rad_editorial_import_target t),'imported_published',(select count(*) from public.visa_article_heads h join private.rad_editorial_catalog c on c.article_id=h.article_id where h.published_id is not null));\n"
    )
    (output / "READ_ONLY_PREFLIGHT.sql").write_text(
        preflight, encoding="utf-8", newline="\n"
    )
    plan = {
        "project": project,
        "actor_id": ACTOR,
        "batch_id": batch,
        "manifest_sha256": manifest,
        "input_files": files,
        "sql_sha256": hashlib.sha256(sql.encode()).hexdigest(),
        "rollback_sql_sha256": hashlib.sha256(rollback_sql.encode()).hexdigest(),
        "read_only_preflight_sha256": hashlib.sha256(preflight.encode()).hexdigest(),
        "new_article_locales": len(new),
        "existing_draft_revisions": len(changes),
        "canonical_revisions": sum(
            r["item"]["content_class"] == "canonical" for r in changes
        ),
        "catalog_reclassifications": sum(
            "catalog_reclassification" in r for r in changes
        ),
        "duplicate_source_readers_hidden": len(retirements),
        "source_snapshots": len(sources),
        "reference_maps": len(maps),
        "country_codes_considered": countries,
        "country_insert_policy": "missing_only_draft_with_source_supported_names",
        "import_gate": "enabled_only_inside_one_transaction_and_disabled_before_commit",
        "publication_allowed": False,
        "hosted_executed": False,
        "requires": [
            "verified hosted backup and isolated restore",
            "explicit exact-operation Owner authorization",
            "fresh matching Staging preflight",
        ],
    }
    (output / "import-plan.json").write_text(
        json.dumps(plan, indent=2) + "\n", encoding="utf-8", newline="\n"
    )
    return plan


def retirement_head_guard(article_id, locale, sections):
    """Only the untouched imported draft may be hidden or reactivated."""
    return (
        f"exists(select 1 from public.visa_article_heads h join public.visa_article_revisions rv on rv.id=h.head_id join private.rad_editorial_rich_revisions r on r.revision_id=rv.id join private.rad_editorial_import_journal j on j.revision_id=rv.id and j.article_id=h.article_id and j.locale=h.locale where h.article_id='{article_id}' and h.locale='{locale}' and rv.revision=1 and j.rolled_back_at is null and h.published_id is null and private.rad_article_state(rv.id)='draft' and private.rad_article_verification(rv.id)='unverified' and r.composition->'sections'={literal(sections)} and not exists(select 1 from private.rad_editorial_clearances where revision_id=rv.id))"
        + " and "
        + unreviewed_links_guard(article_id)
    )


def unreviewed_links_guard(article_id):
    return (
        f"not exists(select 1 from private.rad_editorial_relations where (parent_id='{article_id}' or related_id='{article_id}') and (state<>'proposed' or revision<>1 or reviewed_by is not null or reviewed_at is not null))"
        f" and not exists(select 1 from private.rad_editorial_country_titles where article_id='{article_id}' and (state<>'proposed' or revision<>1 or reviewed_by is not null or reviewed_at is not null))"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--project", required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.directory, args.output, args.project)))
