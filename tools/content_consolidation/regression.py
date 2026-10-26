"""Synthetic SQL regression generator. Caller executes only on disposable DB.

All operations are rolled back. It never connects to a hosted project.
"""

import json
from pathlib import Path

from tools.plan3_content.dataset import uid
from tools.plan3_content.parser import digest

from .composition import compose
from .import_payload import payload


def quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def fixture(registry):
    body = "SYNTHETIC ONLY — condition A. No immigration advice."
    s = {
        "source_id": uid("editorial-regression-source"),
        "snapshot_id": uid("editorial-regression-snapshot"),
        "title": "Synthetic independent source",
        "url": "https://radmohajer.ir/fa/synthetic-editorial-regression",
        "domain": "radmohajer.ir",
        "language": "en",
        "retrieved_at": "2026-10-24T10:00:00Z",
        "body_text": body,
        "body_sha256": digest(body),
        "raw_html_sha256": digest("synthetic fixture"),
        "blocks": [{"type": "paragraph", "text": body}],
        "taxonomy": {
            "country_codes": ["CA"],
            "country_evidence": "source_title",
            "pathway": "general",
        },
    }
    a = compose(
        [s],
        uid("editorial-regression-article"),
        "Synthetic independent article",
        ["CA"],
    )
    item = payload(a, {s["source_id"]: s}, registry)
    assert item["status"] == "technical_draft_only", item
    return item


def sql(registry):
    p = fixture(registry)
    actor, batch = uid("editorial-regression-admin"), uid("editorial-regression-batch")
    a = p["article_id"]
    args = f"{quote(batch)}::uuid,{quote('a' * 64)},{quote(actor)}::uuid,{quote(json.dumps(p['item'], ensure_ascii=False))}::jsonb,{quote(json.dumps(p['sources'], ensure_ascii=False))}::jsonb"
    return f"""begin;
set local statement_timeout='60s';
select set_config('request.jwt.claims','{{"role":"service_role"}}',true);
insert into auth.users(id,email) values('{actor}','editorial-native@example.invalid');
insert into public.profiles(id,role) values('{actor}','admin') on conflict(id) do update set role='admin';
create temporary table editorial_test_receipts(value jsonb);
-- Disabled import gate, including for service role.
select set_config('request.jwt.claims','{{"role":"service_role"}}',true);
do $$begin
 begin perform public.import_editorial_draft({args});raise exception 'FAIL import enabled by default';
 exception when sqlstate 'PT403' then null;end;
end$$;
insert into private.rad_editorial_import_target values('epolbumcfbohtmgvomki',true) on conflict(project_ref) do update set enabled=true;
insert into editorial_test_receipts select public.import_editorial_draft({args});
do $$declare first jsonb;second jsonb;begin
 select value into first from editorial_test_receipts;
 second:=public.import_editorial_draft({args});
 if first<>second then raise exception 'FAIL idempotent receipt';end if;
 if (select count(*) from private.rad_editorial_import_journal where article_id='{a}')<>1 then raise exception 'FAIL duplicate import';end if;
end$$;
-- EXECUTE rights and private table isolation are checked independently of JWT.
do $$begin
 if has_function_privilege('anon','public.import_editorial_draft(uuid,text,uuid,jsonb,jsonb)','execute')
 or has_function_privilege('authenticated','public.import_editorial_draft(uuid,text,uuid,jsonb,jsonb)','execute')
 or has_table_privilege('authenticated','private.rad_editorial_rich_revisions','select') then raise exception 'FAIL private ACL';end if;
end$$;
set local role anon;
select set_config('request.jwt.claims','{{"role":"anon"}}',true);
do $$begin
 begin perform public.get_editorial_article('{a}','en',false);raise exception 'FAIL draft leaked';exception when sqlstate 'PT404' then null;end;
 begin perform public.get_editorial_article('{a}','en',true);raise exception 'FAIL anon preview';exception when sqlstate 'PT403' then null;end;
 if jsonb_array_length(public.list_editorial_articles('en')->'data'->'items')<>0 then raise exception 'FAIL unpublished list leak';end if;
end$$;
reset role;
select set_config('request.jwt.claims','{{"role":"authenticated","sub":"{actor}"}}',true);
do $$declare r uuid;begin
 if public.get_editorial_article('{a}','en',true)->'data'->'rich_sections' is null then raise exception 'FAIL rich preview';end if;
 begin perform public.get_editorial_article('{a}','fa',true);raise exception 'FAIL translation invented';exception when sqlstate 'PT404' then null;end;
 select revision_id into r from private.rad_editorial_import_journal where article_id='{a}';
 begin perform public.clear_editorial_revision(r,'Synthetic cannot clear unverified source');raise exception 'FAIL unverified clearance';exception when sqlstate 'PT422' then null;end;
 begin insert into public.visa_article_revision_events(revision_id,state,actor_id) values(r,'approved','{actor}');
 raise exception 'FAIL unverified approval';exception when sqlstate 'PT422' then null;end;
end$$;
select set_config('request.jwt.claims','{{"role":"service_role"}}',true);
do $$declare r jsonb;begin
 r:=public.rollback_editorial_import('{batch}');
 if (r->>'detached_unmodified_drafts')::integer<>1 then raise exception 'FAIL rollback detach';end if;
 r:=public.rollback_editorial_import('{batch}');
 if (r->>'detached_unmodified_drafts')::integer<>0 then raise exception 'FAIL rollback retry';end if;
 begin perform public.import_editorial_draft({args});raise exception 'FAIL rolled back batch replay';exception when sqlstate 'PT409' then null;end;
 if not exists(select 1 from public.source_snapshots where id='{p["sources"][0]["snapshot_id"]}') then raise exception 'FAIL evidence deleted';end if;
end$$;
select 'PASS editorial: disabled default, draft-only, idempotency, ACL, preview, missing translation, clearance, approval guard, rollback and immutable evidence';
rollback;
"""


if __name__ == "__main__":
    import argparse

    p = argparse.ArgumentParser()
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    registry = json.loads(
        Path("supabase/contracts/rad_v1.json").read_text(encoding="utf8")
    )
    args.output.write_text(sql(registry), encoding="utf8")
