"""Rollback-only V4 import/retry/rollback/edit-preservation tests on an owned clone.

No hosted connection is supported. Every test opens an explicit transaction and
rolls it back, including inserted synthetic sources. Original clone rows survive.
"""

import argparse
import copy
import gzip
import hashlib
import json
import subprocess
import tempfile
from datetime import UTC, datetime
from pathlib import Path

from tools.content_completion.full_pipeline_v4 import (
    ACTOR,
    canonicalize,
    compile_operations,
    reference_metadata,
)
from tools.content_completion.phase_bundle import save_json
from tools.content_consolidation.composition import compose
from tools.content_consolidation.regression import quote
from tools.plan3_content.dataset import read_jsonl, uid, write_jsonl
from tools.plan3_content.parser import digest


def run(
    database="rad_content_v4_20261028",
    psql=r"C:\Program Files\PostgreSQL\17\bin\psql.exe",
):
    if not database.startswith("rad_content_v4_"):
        raise ValueError("owned_v4_clone_database_required")
    command = [
        psql,
        "-h",
        "127.0.0.1",
        "-p",
        "64139",
        "-U",
        "postgres",
        "-d",
        database,
        "-w",
        "-q",
        "-A",
        "-t",
        "-v",
        "ON_ERROR_STOP=1",
    ]

    def sql(value):
        result = subprocess.run(
            command,
            check=False,
            input=value,
            text=True,
            encoding="utf-8",
            capture_output=True,
        )
        if result.returncode:
            raise ValueError("local_SQL_regression_failed:" + result.stderr[-5000:])
        return result.stdout.strip()

    heads = json.loads(
        sql("""select jsonb_agg(x) from (select h.article_id,h.locale,h.head_id,h.published_id,v.revision,v.content_hash,
encode(extensions.digest((rr.composition->'sections')::text,'sha256'),'hex') rich_sections_hash,j.batch_id,c.active catalog_active,
c.content_class,c.country_codes,encode(extensions.digest(to_jsonb(c)::text,'sha256'),'hex') catalog_hash,to_jsonb(a) identity,
(select coalesce(jsonb_agg(to_jsonb(ct) order by country_code),'[]') from private.rad_editorial_country_titles ct where ct.article_id=a.id) country_titles
from public.visa_article_heads h join public.visa_article_revisions v on v.id=h.head_id join private.rad_editorial_catalog c on c.article_id=h.article_id
join public.visa_articles a on a.id=h.article_id join private.rad_editorial_rich_revisions rr on rr.revision_id=v.id
join private.rad_editorial_import_journal j on j.article_id=h.article_id and j.locale=h.locale
where h.published_id is null and v.revision=1 and c.active and private.rad_article_state(v.id)='draft'
order by length(v.body::text),h.article_id limit 30)x;""")
    )
    existing_sources = json.loads(
        sql("""select jsonb_agg(x) from(select d.id source_id,d.canonical_url,s.id snapshot_id,s.content_hash,s.metadata->>'raw_html_sha256' raw_html_sha256
from public.source_documents d left join public.source_snapshots s on s.document_id=d.id)x;""")
    )
    corpus = Path("artifacts/RAD_CONTENT_CONSOLIDATION_20261026")
    originals = {
        (a["article_id"], a["locale"]): a
        for a in read_jsonl(corpus / "articles.jsonl.gz")
    }
    original_sources = {
        s["source_id"]: s for s in read_jsonl(corpus / "sources.jsonl.gz")
    }
    prior = next(h for h in heads if (h["article_id"], h["locale"]) in originals)
    old = originals[(prior["article_id"], prior["locale"])]
    counts_before = sql(
        "select jsonb_build_array((select count(*) from public.visa_article_revisions),(select count(*) from public.source_snapshots),(select count(*) from public.visa_article_heads where published_id is not null));"
    )
    checks = []

    with tempfile.TemporaryDirectory(prefix="rad_v4_sql_regression_") as temp:
        root = Path(temp)
        for mode in ("new", "existing"):
            members = (
                [copy.deepcopy(original_sources[s]) for s in old["source_ids"]]
                if mode == "existing"
                else []
            )
            domain = members[0]["domain"] if members else "digivisa.ir"
            body = "SYNTHETIC ONLY: additional local regression statement."
            synthetic = {
                "source_id": uid("v4-sql-regression:" + mode),
                "snapshot_id": uid("v4-sql-regression-snapshot:" + mode),
                "url": f"https://{domain}/article/v4-local-sql-regression-{mode}",
                "domain": domain,
                "title": old["title"] if members else "SYNTHETIC local regression",
                "language": old["locale"],
                "blocks": [{"type": "paragraph", "text": body}],
                "body_text": body,
                "body_sha256": digest(body),
                "raw_html_sha256": digest("synthetic raw " + mode),
                "retrieved_at": datetime.now(UTC).isoformat(),
                "http_status": 200,
                "taxonomy": copy.deepcopy(members[0]["taxonomy"])
                if members
                else {
                    "country_codes": ["CA"],
                    "country_evidence": "synthetic_fixture",
                    "pathway": "general",
                },
                "complete_article_body": True,
                "consolidation_disposition": "body_ready_for_unreviewed_composition",
            }
            members.append(synthetic)
            article = compose(
                members,
                old["article_id"]
                if mode == "existing"
                else uid("v4-sql-regression-article"),
                old["title"] if mode == "existing" else synthetic["title"],
                old["country_codes"] if mode == "existing" else ["CA"],
                old["visa_category"] if mode == "existing" else None,
            )
            article["category"] = (
                old["category"] if mode == "existing" else "general-guide"
            )
            index = {s["source_id"]: s for s in members}
            article["source_links"], article["source_assets"] = reference_metadata(
                article, index
            )
            folder = root / mode
            composition = folder / "composition"
            composition.mkdir(parents=True)
            for name, values in (
                ("sources", members),
                ("supplements", []),
                ("articles", [article]),
            ):
                write_jsonl(composition / (name + ".jsonl.gz"), values)
            save_json(
                composition / "manifest.json",
                {
                    "files": {
                        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                        for p in composition.glob("*.jsonl.gz")
                    }
                },
            )
            save_json(
                folder / "staging-heads-before.json",
                [prior] if mode == "existing" else [],
            )
            save_json(folder / "staging-sources-before.json", existing_sources)
            compile_operations(composition, folder, folder / "import")
            plan = json.loads((folder / "import/import-plan.json").read_text("utf-8"))
            if plan["blocked"] or len(plan["operations"]) != 1:
                raise ValueError("local_regression_plan_not_one_safe_operation")
            operation = gzip.decompress(
                (folder / "import" / plan["operations"][0]["file"]).read_bytes()
            ).decode("utf-8")
            operation = operation.replace("begin;\n", "", 1).removesuffix("commit;\n")
            rollback = (
                (folder / "import/rollback.sql")
                .read_text("utf-8")
                .replace("begin;\n", "", 1)
                .removesuffix("commit;\n")
            )
            aid, locale = article["article_id"], article["locale"]
            expected_head = prior["head_id"] if mode == "existing" else None
            restored = f"head_id is not distinct from {quote(expected_head) + '::uuid' if expected_head else 'null'}"
            assertion = f"do $$begin if not exists(select 1 from public.visa_article_heads where article_id='{aid}' and locale='{locale}' and {restored}) then raise exception 'regression_rollback_did_not_restore_expected_head';end if;end $$;"
            sql(
                "begin;\n"
                + operation
                + operation
                + rollback
                + assertion
                + "\nrollback;"
            )
            checks.append(mode + "_import_retry_and_rollback")
            item = canonicalize(article, index, existing_sources)["item"]
            request = copy.deepcopy(item["draft_request"])
            request["expected_revision"] = 2 if mode == "existing" else 1
            request["title"] = "SYNTHETIC human follow-up revision"
            request["request_key"] = uid("synthetic-human-followup:" + mode)
            human_edit = f'select set_config(\'request.jwt.claims\',\'{{"role":"service_role","sub":"{ACTOR}"}}\',true);select private.rad_save_article({quote(json.dumps(request, ensure_ascii=False))}::jsonb);'
            assertion = f"do $$begin if not exists(select 1 from public.visa_article_heads h join public.visa_article_revisions r on r.id=h.head_id where h.article_id='{aid}' and h.locale='{locale}' and r.title='SYNTHETIC human follow-up revision') then raise exception 'regression_rollback_overwrote_human_revision';end if;end $$;"
            sql(
                "begin;\n"
                + operation
                + human_edit
                + rollback
                + assertion
                + "\nrollback;"
            )
            checks.append(mode + "_rollback_preserves_later_human_revision")
    counts_after = sql(
        "select jsonb_build_array((select count(*) from public.visa_article_revisions),(select count(*) from public.source_snapshots),(select count(*) from public.visa_article_heads where published_id is not null));"
    )
    if counts_before != counts_after:
        raise ValueError("rollback_only_regression_changed_clone_inventory")
    return {
        "status": "PASS",
        "database": database,
        "checks": checks,
        "all_transactions_rolled_back": True,
        "source_revision_publication_counts_unchanged": True,
        "hosted_writes": 0,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", default="rad_content_v4_20261028")
    args = parser.parse_args()
    print(json.dumps(run(args.database)))
