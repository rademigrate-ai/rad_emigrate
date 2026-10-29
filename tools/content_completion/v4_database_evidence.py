"""Prepare independent read-only reconciliation of canonical payloads with DB/UI.

No import/compiler implementation is reused. PostgreSQL jsonb wire ordering is
reproduced only for hashing; the SQL also verifies the original text ranges of
every stored provenance reference against immutable snapshots. No network calls
or writes to a database are made by this module.
"""

import argparse
import gzip
import hashlib
import json
from pathlib import Path

ACTOR = "0166163b-582b-4d2e-82dc-f9942c2f80b5"


def jsonb_text(value):
    if isinstance(value, dict):
        if any(not isinstance(key, str) for key in value):
            raise ValueError("json_object_keys_must_be_strings")
        keys = sorted(
            value, key=lambda key: (len(key.encode("utf-8")), key.encode("utf-8"))
        )
        return (
            "{"
            + ", ".join(
                json.dumps(key, ensure_ascii=False) + ": " + jsonb_text(value[key])
                for key in keys
            )
            + "}"
        )
    if isinstance(value, list):
        return "[" + ", ".join(jsonb_text(item) for item in value) + "]"
    if value is None or isinstance(value, (str, bool, int)):
        return json.dumps(value, ensure_ascii=False, allow_nan=False)
    # Avoid guessing PostgreSQL numeric normalization for binary floats.
    raise ValueError("unsupported_jsonb_hash_value:" + type(value).__name__)


def digest(value, postgres=False):
    text = (
        jsonb_text(value)
        if postgres
        else json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
    )
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def restore_variant_references(value, source_index):
    """Undo only documented storage-ID remapping, preserving all other fields."""
    if isinstance(value, list):
        return [restore_variant_references(item, source_index) for item in value]
    if not isinstance(value, dict):
        return value
    result = {
        key: restore_variant_references(item, source_index)
        for key, item in value.items()
        if key != "source_variant_id"
    }
    if "source_variant_id" in value:
        variant = value["source_variant_id"]
        if variant not in source_index:
            raise ValueError("payload_references_unknown_source_variant")
        result["source_id"] = variant
        for field in ("snapshot_id", "source_snapshot_id"):
            if field in result:
                result[field] = source_index[variant]["snapshot_id"]
    return result


def prepare(payloads, output, batch_size=40, composition=None):
    if not 1 <= batch_size <= 100:
        raise ValueError("bounded_reconciliation_batch_required")
    with gzip.open(payloads, "rt", encoding="utf-8") as stream:
        rows = [json.loads(line) for line in stream if line.strip()]
    keys = [(row["article_id"], row["item"]["locale"]) for row in rows]
    if not rows or len(keys) != len(set(keys)):
        raise ValueError("nonempty_unique_destinations_required")
    bridge = {}
    if composition:

        def read(name):
            with gzip.open(
                composition / (name + ".jsonl.gz"), "rt", encoding="utf-8"
            ) as stream:
                return [json.loads(line) for line in stream if line.strip()]

        original_articles = read("articles")
        original_sources = read("sources") + read("supplements")
        articles = {
            (row["article_id"], row["locale"]): row for row in original_articles
        }
        source_index = {row["source_id"]: row for row in original_sources}
        if set(keys) != set(articles) or len(articles) != len(original_articles):
            raise ValueError("composition_payload_destination_mismatch")
        for row in rows:
            item = row["item"]
            article = articles[(row["article_id"], item["locale"])]
            for field in (
                "article_id",
                "locale",
                "title",
                "content_class",
                "country_codes",
                "category",
            ):
                if item.get(field) != article.get(field):
                    raise ValueError(
                        "composition_payload_placement_mismatch:"
                        + row["article_id"]
                        + ":"
                        + field
                    )
            for field in ("sections", "source_assets", "source_links"):
                actual = restore_variant_references(item.get(field, []), source_index)
                if actual != article.get(field, []):
                    raise ValueError(
                        "composition_payload_content_mismatch:"
                        + row["article_id"]
                        + ":"
                        + field
                    )
            for source in row.get("sources", []):
                variant = source.get("source_variant_id", source["source_id"])
                if variant not in source_index or any(source.get(field) != source_index[variant].get(field) for field in ("url", "body_sha256", "body_text")):
                    raise ValueError("composition_payload_source_body_mismatch")
            bridge[(row["article_id"], item["locale"])] = True
    output.mkdir(parents=True, exist_ok=True)
    expected = []
    for row in rows:
        item = row["item"]
        body = {
            "rich_sections": item["sections"],
            "source_assets": item.get("source_assets", []),
            "source_links": item.get("source_links", []),
        }
        expected.append(
            {
                "article_id": row["article_id"],
                "locale": item["locale"],
                "expected_rich_sections_sha256": digest(item["sections"]),
                "expected_body_sha256": digest(body),
                "postgres_body_sha256": digest(body, postgres=True),
                "composition_payload_match": bridge.get(
                    (row["article_id"], item["locale"]), False
                ),
                "postgres_placement_sha256": digest(
                    {
                        key: item.get(key)
                        for key in (
                            "title",
                            "content_class",
                            "country_codes",
                            "category",
                        )
                    },
                    postgres=True,
                ),
            }
        )
    manifest = []
    for start in range(0, len(expected), batch_size):
        batch = expected[start : start + batch_size]
        source_expectations = {}
        for payload_row in rows[start:start + batch_size]:
            for source in payload_row.get("sources", []):
                source_expectations[source["snapshot_id"]] = source
        # IDs/locales are validated before interpolation, never publisher text.
        import uuid

        for row in batch:
            uuid.UUID(row["article_id"])
            if row["locale"] not in ("fa", "en"):
                raise ValueError("unsupported_locale")
        values = ",\n".join(
            f"('{row['article_id']}'::uuid,'{row['locale']}','{row['postgres_body_sha256']}','{row['postgres_placement_sha256']}')"
            for row in batch
        )
        snapshot_values = []
        for source in source_expectations.values():
            uuid.UUID(source["snapshot_id"])
            uuid.UUID(source["source_id"])
            if hashlib.sha256(source["body_text"].encode("utf-8")).hexdigest() != source["body_sha256"]:
                raise ValueError("expected_source_body_hash_mismatch")
            url = source["url"].replace("'", "''")
            snapshot_values.append(f"('{source['snapshot_id']}'::uuid,'{source['source_id']}'::uuid,'{url}','{source['body_sha256']}')")
        snapshots = ",\n".join(snapshot_values) or "(null::uuid,null::uuid,null::text,null::text)"
        sql = f"""begin;
set local statement_timeout='120s';
select set_config('request.jwt.claims','{{"role":"authenticated","sub":"{ACTOR}"}}',true);
with expected(article_id,locale,body_hash,placement_hash) as(values {values}), expected_snapshots(snapshot_id,source_id,url,body_hash) as(values {snapshots}), actual as(
select e.*,h.head_id,r.id revision_id,rr.composition,public.get_editorial_article(e.article_id,e.locale,true)->'data' reader
from expected e left join public.visa_article_heads h on h.article_id=e.article_id and h.locale=e.locale
left join public.visa_article_revisions r on r.id=h.head_id
left join private.rad_editorial_rich_revisions rr on rr.revision_id=r.id), receipts as(
select article_id,locale,revision_id,
revision_id is not null revision_exists,
coalesce(encode(extensions.digest(jsonb_build_object('rich_sections',composition->'sections','source_assets',coalesce(composition->'source_assets','[]'::jsonb),'source_links',coalesce(composition->'source_links','[]'::jsonb))::text,'sha256'),'hex')=body_hash,false) rich_sections_match,
coalesce(reader->>'revision_id'=revision_id::text and encode(extensions.digest(jsonb_build_object('rich_sections',reader->'rich_sections','source_assets',reader->'source_assets','source_links',reader->'source_links')::text,'sha256'),'hex')=body_hash,false) reader_sections_match,
coalesce(jsonb_array_length(composition->'sections')>0 and not exists(
 select 1 from expected_snapshots es left join public.source_snapshots ss on ss.id=es.snapshot_id left join public.source_documents d on d.id=ss.document_id
 where ss.id is null or ss.document_id is distinct from es.source_id or d.canonical_url is distinct from es.url or ss.content_hash is distinct from es.body_hash or encode(extensions.digest(ss.normalized_text,'sha256'),'hex') is distinct from es.body_hash
) and not exists(
 select 1 from jsonb_array_elements(composition->'sections')s cross join lateral jsonb_array_elements(s->'blocks')b cross join lateral jsonb_array_elements(b->'provenance')p
 left join public.source_snapshots ss on ss.id=(p->>'snapshot_id')::uuid
 left join public.source_documents d on d.id=ss.document_id
 where ss.id is null or not exists(select 1 from expected_snapshots es where es.snapshot_id=ss.id) or d.id is distinct from (p->>'source_id')::uuid or d.canonical_url is distinct from p->>'url'
 or (p->>'start')::integer<0 or (p->>'end')::integer>(char_length(ss.normalized_text))
 or (p->>'end')::integer<(p->>'start')::integer
 or encode(extensions.digest(substring(ss.normalized_text from (p->>'start')::integer+1 for (p->>'end')::integer-(p->>'start')::integer),'sha256'),'hex') is distinct from p->>'sha256'
),false) source_references_valid,
body_hash expected_postgres_body_sha256
 ,coalesce(encode(extensions.digest(jsonb_build_object('title',reader->'title','content_class',reader->'content_class','country_codes',reader->'country_codes','category',reader->'category')::text,'sha256'),'hex')=placement_hash,false) placement_matches
from actual)
select coalesce(jsonb_agg(to_jsonb(receipts) order by article_id,locale),'[]'::jsonb) from receipts;
rollback;
"""
        path = output / f"database-query-{start // batch_size:04d}.sql"
        path.write_text(sql, encoding="utf-8")
        manifest.append(
            {
                "file": path.name,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "destinations": len(batch),
            }
        )
    (output / "expected-ui-heads.json").write_text(
        json.dumps(expected, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    result = {
        "payload_sha256": hashlib.sha256(payloads.read_bytes()).hexdigest(),
        "destinations": len(expected),
        "queries": manifest,
        "database_mutations": 0,
        "independent_composition_payload_bridge": bool(composition),
    }
    (output / "manifest.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8"
    )
    return result


def collect_local(output):
    # Import only the exact-fixture connection guard, never the importer or
    # composition algorithms as evidence of preservation.
    from tools.content_completion.v4_local_import import ROOT, connection

    sql = connection(ROOT / "_scratch/v4-runtime")
    manifest = json.loads((output / "manifest.json").read_text("utf-8"))
    receipts = []
    for query in manifest["queries"]:
        path = output / query["file"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != query["sha256"]:
            raise ValueError("reconciliation_query_changed")
        result = sql(path.read_text("utf-8"), timeout=180)
        arrays = []
        for line in result.splitlines():
            try:
                value = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(value, list):
                arrays.append(value)
        if len(arrays) != 1 or len(arrays[0]) != query["destinations"]:
            raise ValueError("complete_database_query_receipts_required")
        receipts.extend(arrays[0])
    for row in receipts:
        row["environment"] = "local:rad_full_content_v4_20261028"
    by_key = {(row["article_id"], row["locale"]): row for row in receipts}
    expected = json.loads((output / "expected-ui-heads.json").read_text("utf-8"))
    for row in expected:
        row["revision_id"] = by_key[(row["article_id"], row["locale"])]["revision_id"]
        by_key[(row["article_id"], row["locale"])]["composition_payload_match"] = row[
            "composition_payload_match"
        ]
    with gzip.open(
        output / "database-receipts.jsonl.gz", "wt", encoding="utf-8"
    ) as stream:
        for row in receipts:
            stream.write(json.dumps(row, ensure_ascii=False) + "\n")
    (output / "expected-ui-heads.json").write_text(
        json.dumps(expected, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    flags = (
        "revision_exists",
        "rich_sections_match",
        "reader_sections_match",
        "source_references_valid",
        "placement_matches",
    )
    if manifest["independent_composition_payload_bridge"]:
        flags += ("composition_payload_match",)
    failed = [
        {
            "article_id": row["article_id"],
            "locale": row["locale"],
            "failed_checks": [key for key in flags if row.get(key) is not True],
        }
        for row in receipts
        if not all(row.get(key) is True for key in flags)
    ]
    summary = {
        "status": "FAIL" if failed else "PASS",
        "scope": "marked_local_V4_fixture_only",
        "destinations": len(receipts),
        "failed": failed,
        "hosted_operations": 0,
    }
    (output / "database-reconciliation.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    if failed:
        raise ValueError(
            "independent_database_reconciliation_failed:" + str(len(failed))
        )
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--payloads", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--collect-local", action="store_true")
    parser.add_argument("--composition", type=Path)
    args = parser.parse_args()
    print(json.dumps(prepare(args.payloads, args.output, composition=args.composition)))
    if args.collect_local:
        print(json.dumps(collect_local(args.output)))
