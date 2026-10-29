"""Full-corpus V4 composition and additive, guarded Staging operation compiler.

This module does not connect to hosted services or publish. Historical packages
are immutable inputs. Every SQL operation preserves revision and source history.
"""

from __future__ import annotations

import argparse
import copy
import gzip
import hashlib
import json
import re
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

from tools.content_completion.phase_bundle import save_json
from tools.content_completion.prepare_delivery import ACTOR, PROJECT, literal
from tools.content_consolidation.build import category, title_key, topic_key
from tools.content_consolidation.composition import compose_library
from tools.content_consolidation.import_payload import payload
from tools.content_consolidation.regression import quote
from tools.plan3_content.dataset import read_jsonl, uid, write_jsonl
from tools.plan3_content.parser import normalize_url


def safe_web_url(value):
    if not isinstance(value, str) or re.search(r"[\s<>\x00-\x1f]", value):
        return False
    try:
        parsed = urlsplit(value)
        return (
            parsed.scheme in ("http", "https")
            and bool(parsed.hostname)
            and parsed.username is None
            and parsed.password is None
            and (parsed.port is None or 0 < parsed.port < 65536)
        )
    except ValueError:
        return False


def reference_metadata(article, source_index):
    """Preserve source references/media without granting reuse or verification."""
    links, assets = [], []
    for variant in article["source_ids"]:
        source = source_index[variant]
        for key, destination in (("body_links", links), ("source_assets", assets)):
            for original in source.get(key, []):
                if not safe_web_url(original.get("url")):
                    continue
                entry = {
                    **original,
                    "source_id": variant,
                    "source_snapshot_id": source["snapshot_id"],
                    "source_url": source["url"],
                }
                label = original.get("label", original.get("alt", ""))
                entry["label"] = label if isinstance(label, str) else ""
                for section in article["sections"]:
                    for block in section["blocks"]:
                        if (
                            entry["label"]
                            and entry["label"] in block["text"]
                            and any(
                                ref["source_id"] == variant
                                for ref in block["provenance"]
                            )
                        ):
                            entry["target_block_id"] = block["id"]
                            break
                    if entry.get("target_block_id"):
                        break
                if entry not in destination:
                    destination.append(entry)
    return links, assets


def apply_source_link_evidence(sources, evidence_rows):
    indexed = {}
    by_source = {}
    for row in evidence_rows:
        indexed.setdefault(
            (
                row["source_id"],
                row["raw_html_sha256"],
                row["canonical_url"],
                row["label"],
            ),
            [],
        ).append(row)
        by_source.setdefault((row["source_id"], row["raw_html_sha256"]), []).append(row)
    for source in sources:
        source["source_link_evidence"] = by_source.get(
            (source["source_id"], source["raw_html_sha256"]), []
        )
        result = []
        for link in source.get("body_links", []):
            try:
                canonical = normalize_url(link["url"])
            except (ValueError, UnicodeError):
                result.append(link)
                continue
            matches = indexed.get(
                (
                    source["source_id"],
                    source["raw_html_sha256"],
                    canonical,
                    link.get("label", ""),
                ),
                [],
            )
            restored = []
            for evidence in matches:
                for target in evidence.get("original_targets", []):
                    if safe_web_url(target.get("url")):
                        restored.append(
                            {
                                **link,
                                "url": target["url"],
                                "original_href": target.get("original_href"),
                                "original_canonicalized_url": link["url"],
                                "href_evidence": evidence,
                            }
                        )
            for value in restored or [link]:
                if value not in result:
                    result.append(value)
        source["body_links"] = result


class _HeadingIds(HTMLParser):
    def __init__(self, markup):
        super().__init__(convert_charrefs=True)
        self.ids = set()
        self.feed(markup)

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        for name in ("id", "name"):
            if values.get(name):
                self.ids.add(values[name])


def attach_application_targets(articles, source_index):
    """Only a destination representing the whole source is an internal link."""
    by_url = {}
    for article in articles:
        for source_id in article["source_ids"]:
            source = source_index[source_id]
            covered = {
                r["block_index"]
                for r in article["segment_ledger"]
                if r["source_id"] == source_id
            }
            if covered == set(range(len(source["blocks"]))):
                by_url.setdefault(normalize_url(source["url"]), []).append(
                    (article, source)
                )
    for article in articles:
        for link in article.get("source_links", []):
            try:
                candidates = by_url.get(normalize_url(link["url"]), [])
            except (ValueError, UnicodeError):
                continue
            if not candidates:
                continue
            target, source = min(
                candidates,
                key=lambda pair: (
                    pair[0]["content_class"] != "editorial",
                    pair[0]["article_id"],
                    pair[1]["source_id"],
                ),
            )
            link["app_article_id"], link["app_locale"] = (
                target["article_id"],
                target["locale"],
            )
            fragment = unquote(urlsplit(link["url"]).fragment)
            if not fragment:
                continue
            indices = {
                e["block_index"]
                for e in source.get("heading_structure_evidence", [])
                if e.get("confirmed") is True
                and any(
                    fragment in _HeadingIds(r["raw_heading_tag"]).ids
                    for r in e.get("raw_matches", [])
                )
            }
            blocks = {
                r["represented_block_id"]
                for r in target["segment_ledger"]
                if r["source_id"] == source["source_id"] and r["block_index"] in indices
            }
            if len(blocks) == 1:
                link["app_fragment"] = blocks.pop()


def supplement_source_metadata(sources, historical_sources, historical):
    """Repair empty metadata using pinned evidence, without altering source bodies."""
    prior_titles = {s["url"]: s["title"] for s in historical_sources if s.get("title")}
    prior_languages = {
        (s["url"], s.get("body_sha256")): s["language"]
        for s in historical_sources
        if s.get("complete_article_body")
    }
    for source in sources:
        prior_language = prior_languages.get((source["url"], source.get("body_sha256")))
        stronger_language_evidence = (
            source.get("language_evidence", {}).get(
                "basis", "preserved_original_capture_classification"
            )
            != "preserved_original_capture_classification"
        )
        if (
            prior_language
            and prior_language != source["language"]
            and stronger_language_evidence
        ):
            source["historical_language_disagreement"] = {
                "historical_language": prior_language,
                "resolution": "explicit_original_route_and_narrative_evidence_preferred_no_translation",
            }
        elif prior_language and prior_language != source["language"]:
            source["original_capture_language"] = source["language"]
            source["language"] = prior_language
            source["language_metadata_provenance"] = {
                "basis": "sealed_source_metadata_same_url_and_exact_body_hash",
                "historical_metadata_path": historical.as_posix(),
            }
        if not source.get("title", "").strip():
            title = prior_titles.get(source["url"])
            basis = "sealed_source_metadata_same_original_url"
            if not title:
                title = next(
                    (
                        b["text"]
                        for b in source["blocks"]
                        if b["type"] == "heading" and b["text"].strip()
                    ),
                    None,
                )
                basis = "verbatim_owned_source_heading"
            if not title:
                title = (
                    unquote(urlsplit(source["url"]).path)
                    .strip("/")
                    .split("/")[-1][:180]
                    or urlsplit(source["url"]).hostname
                )
                basis = "original_source_url_route_navigation_label_not_author_title"
            source["original_capture_title"] = source.get("title", "")
            source["title"] = title
            source["display_title_provenance"] = {
                "basis": basis,
                "original_url": source["url"],
                "historical_metadata_path": historical.as_posix()
                if basis.startswith("sealed")
                else None,
            }


def compose_all(recovery, output):
    sources = read_jsonl(recovery / "sources.jsonl.gz")
    supplements = read_jsonl(recovery / "version-supplements.jsonl.gz")
    historical = Path("artifacts/RAD_CONTENT_CONSOLIDATION_20261026/sources.jsonl.gz")
    historical_sources = read_jsonl(historical) if historical.exists() else []
    supplement_source_metadata(sources + supplements, historical_sources, historical)
    link_evidence = (
        recovery.parent / "recovery-source-links-v41/source-link-evidence.jsonl.gz"
    )
    if not link_evidence.exists():
        link_evidence = recovery.parent / "source-link-evidence.jsonl.gz"
    if link_evidence.exists():
        apply_source_link_evidence(sources + supplements, read_jsonl(link_evidence))
    all_sources = sources + supplements
    if len({s["source_id"] for s in all_sources}) != len(all_sources):
        raise ValueError("duplicate_source_version_identity")
    articles, mappings, relations, countries = compose_library(
        all_sources, title_key, topic_key
    )
    source_index = {s["source_id"]: s for s in all_sources}
    for article in articles:
        if article["content_class"] == "editorial":
            article["category"] = category(article["title"])
        # Owner-approved routine placement and precedence are mechanical.
        # Claims stay unverified and publication remains a separate operation.
        article["composition_review"] = "owner_v4_policy_applied_claims_unverified"
        article["source_links"], article["source_assets"] = reference_metadata(
            article, source_index
        )
        article["locale_corrections"] = [
            {
                "source_url": source["url"],
                "original_capture_language": source["original_capture_language"],
                "original_recorded_locale": source.get(
                    "historical_language_disagreement", {}
                ).get("historical_language", source["original_capture_language"]),
                "corrected_locale": source["language"],
                "body_sha256": source["body_sha256"],
                "basis": source.get(
                    "language_evidence", source.get("language_metadata_provenance")
                ),
                "translation_created": False,
            }
            for source in (source_index[sid] for sid in article["source_ids"])
            if source.get("historical_language_disagreement")
            or (
                source.get("original_capture_language")
                and source["original_capture_language"] != source["language"]
            )
        ]
    attach_application_targets(articles, source_index)
    output.mkdir(parents=True, exist_ok=True)
    for name, rows in (
        ("sources", sources),
        ("supplements", supplements),
        ("articles", articles),
        ("mappings", mappings),
        ("relations", relations),
        ("other-titles", countries),
        (
            "semantic-merge-ledger",
            [
                {"article_id": a["article_id"], "locale": a["locale"], **r}
                for a in articles
                for r in a["segment_ledger"]
            ],
        ),
    ):
        write_jsonl(output / (name + ".jsonl.gz"), rows)
    manifest = {
        "version": "RAD_FULL_CONTENT_V4",
        "composition_policy": "RAD_CONTENT_PRECEDENCE_V4.1",
        "source_pages": len(sources),
        "alternate_source_versions": len(supplements),
        "article_locales": len(articles),
        "article_identities": len({a["article_id"] for a in articles}),
        "classes": dict(Counter(a["content_class"] for a in articles)),
        "languages": dict(Counter(a["locale"] for a in articles)),
        "publication_allowed": False,
        "source_link_evidence_sha256": hashlib.sha256(
            link_evidence.read_bytes()
        ).hexdigest()
        if link_evidence.exists()
        else None,
        "files": {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(output.glob("*.jsonl.gz"))
        },
    }
    save_json(output / "manifest.json", manifest)
    return manifest


def canonicalize(row, source_index, hosted_sources):
    """Preserve variant IDs locally, pin DB provenance to document + snapshot."""
    item = copy.deepcopy(row)
    docs = {s["canonical_url"]: s["source_id"] for s in hosted_sources}
    snapshots = {
        (s["source_id"], s["content_hash"]): s["snapshot_id"]
        for s in hosted_sources
        if s["snapshot_id"]
    }
    stored_raw = {
        s["snapshot_id"]: s.get("raw_html_sha256")
        for s in hosted_sources
        if s["snapshot_id"]
    }
    remap = {}
    for variant in row["source_ids"]:
        source = source_index[variant]
        origin = docs.get(
            source["url"], source.get("origin_source_id", source["source_id"])
        )
        snap = snapshots.get((origin, source["body_sha256"]), source["snapshot_id"])
        remap[variant] = (origin, snap)
    registry = json.loads(Path("supabase/contracts/rad_v1.json").read_text("utf-8"))
    projected = payload(item, source_index, registry)
    if projected["status"] != "technical_draft_only":
        return projected
    item = projected["item"]
    item["source_capture_variants"] = [
        {
            "source_id": variant,
            "source_snapshot_id": source_index[variant]["snapshot_id"],
            "source_url": source_index[variant]["url"],
            "body_sha256": source_index[variant]["body_sha256"],
            "raw_html_sha256": source_index[variant].get("raw_html_sha256"),
            "raw_html_asset": source_index[variant].get("raw_html_asset"),
            "capture_id": source_index[variant].get("capture_id"),
        }
        for variant in row["source_ids"]
    ]
    snapshot_remap = {}
    for variant, (_, snapshot) in remap.items():
        old = source_index[variant]["snapshot_id"]
        if old in snapshot_remap and snapshot_remap[old] != snapshot:
            raise ValueError("ambiguous_snapshot_canonicalization")
        snapshot_remap[old] = snapshot
    visited = set()

    def walk(value):
        if isinstance(value, (dict, list)):
            if id(value) in visited:
                return
            visited.add(id(value))
        if isinstance(value, dict):
            mapped_reference = False
            if "source_id" in value and value["source_id"] in remap:
                variant = value["source_id"]
                value["source_variant_id"] = variant
                value["source_id"] = remap[variant][0]
                if "snapshot_id" in value:
                    value["snapshot_id"] = remap[variant][1]
                    mapped_reference = True
            # Projection evidence does not carry a source_id.
            if "snapshot_id" in value and not mapped_reference:
                value["snapshot_id"] = snapshot_remap.get(
                    value["snapshot_id"], value["snapshot_id"]
                )
            if "source_snapshot_id" in value:
                value["source_snapshot_id"] = snapshot_remap.get(
                    value["source_snapshot_id"], value["source_snapshot_id"]
                )
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)

    walk(item)
    item["source_ids"] = sorted({v[0] for v in remap.values()})
    item["source_snapshot_ids"] = sorted({v[1] for v in remap.values()})
    used = {}
    for source in projected["sources"]:
        variant = source["source_id"]
        original = source_index[variant]
        source["source_variant_id"] = variant
        source["source_id"], source["snapshot_id"] = remap[variant]
        acquisition = original.get("acquisition_timestamp")
        if (
            not acquisition
            and original.get("retrieved_at_semantics")
            != "recorded_local_evidence_intake_not_original_HTTP_fetch"
            and not str(original.get("acquisition_timestamp_status", "")).startswith(
                "not_recorded"
            )
        ):
            acquisition = original.get("retrieved_at")
        source["source_evidence"] = {
            "original_acquisition_time_unconfirmed": not bool(acquisition),
            "original_http_status": original.get("http_status"),
            "original_acquisition_timestamp": acquisition,
            "evidence_intake_timestamp": original.get("evidence_intake_timestamp"),
            "stored_fetched_at_semantics": original.get(
                "retrieved_at_semantics", "recorded_HTTP_fetch_timestamp"
            ),
            "raw_html_asset": original.get("raw_html_asset"),
            "origin_capture_id": original.get("capture_id"),
            "captured_raw_html_sha256": source["raw_html_sha256"],
        }
        if source["snapshot_id"] in stored_raw:
            source["raw_html_sha256"] = stored_raw[source["snapshot_id"]]
            if not source["raw_html_sha256"]:
                raise ValueError(
                    "existing_snapshot_raw_hash_missing_reference_map_unprovable"
                )
        if not source["retrieved_at"]:
            source["retrieved_at"] = original.get("evidence_intake_timestamp")
        if not source["retrieved_at"]:
            raise ValueError("missing_recorded_acquisition_or_evidence_intake_time")
        used[source["snapshot_id"]] = source
    projected["item"] = item
    projected["sources"] = sorted(used.values(), key=lambda s: s["snapshot_id"])
    projected["reference_map"] = {
        "capture_status": "complete",
        "sources": [
            {k: s[k] for k in ("snapshot_id", "body_sha256", "raw_html_sha256")}
            for s in projected["sources"]
        ],
        "links": [
            {
                "url": entry["url"],
                "label": entry.get("label", ""),
                "source_snapshot_id": entry["source_snapshot_id"],
                "target_block_id": entry.get("target_block_id"),
                "kind": entry.get("kind", "reference"),
                "source_url": entry["source_url"],
                "original_url": entry.get("original_url", entry["url"]),
                **{
                    key: entry[key]
                    for key in ("app_article_id", "app_locale", "app_fragment")
                    if key in entry
                },
            }
            for entry in item.get("source_links", []) + item.get("source_assets", [])
        ],
    }
    return projected


def source_sql(sources, manifest):
    return f"""for s in select value from jsonb_array_elements({literal(sources)}) loop
if s->>'body_sha256' is distinct from encode(extensions.digest(s->>'body_text','sha256'),'hex') or s->>'url'!~'^https://(digivisa[.]ir|radvisa[.]com|radmohajer[.]ir)/' then raise exception 'v4_source_integrity';end if;
doc:=(s->>'source_id')::uuid;snap:=(s->>'snapshot_id')::uuid;cs:=(s->>'content_source_id')::uuid;
if exists(select 1 from public.source_documents where (canonical_url=s->>'url' and id<>doc) or (id=doc and canonical_url<>s->>'url')) then raise exception 'v4_source_identity_conflict';end if;
if exists(select 1 from public.source_snapshots where (id=snap and (document_id<>doc or content_hash<>s->>'body_sha256' or normalized_text<>s->>'body_text')) or (document_id=doc and content_hash=s->>'body_sha256' and id<>snap)) then raise exception 'v4_snapshot_conflict';end if;
insert into public.content_sources(id,publisher,source_type,title,url,language_code,retrieved_at,content_hash) select cs,'RAD first-party editorial source, not legal verification','rad_official',s->>'title',s->>'url',s->>'language',(s->>'retrieved_at')::timestamptz,s->>'body_sha256' where not exists(select 1 from public.content_sources where url=s->>'url');
select id into cs from public.content_sources where url=s->>'url' order by created_at,id limit 1;
insert into public.source_documents(id,canonical_url,source_id,source_authority,title,language_code,jurisdiction,last_content_hash) values(doc,s->>'url',cs,'rad_official',s->>'title',s->>'language','',s->>'body_sha256') on conflict(id) do nothing;
insert into public.source_snapshots(id,document_id,content_hash,normalized_text,http_status,fetched_at,metadata) values(snap,doc,s->>'body_sha256',s->>'body_text',(s->'source_evidence'->>'original_http_status')::integer,(s->>'retrieved_at')::timestamptz,jsonb_build_object('raw_html_sha256',s->>'raw_html_sha256','source_evidence',s->'source_evidence','v4_manifest',{quote(manifest)},'factual_verification','not_verified')) on conflict(id) do nothing;
perform private.rad_classify_snapshot(snap);end loop;"""


def do_sql(body, declarations=""):
    number = 0
    while f"$rad_v4_{number}$" in body:
        number += 1
    delimiter = f"$rad_v4_{number}$"
    return f"do {delimiter} declare {declarations} begin\n{body}\nend {delimiter};"


def transaction(body):
    return (
        """-- Staging draft content only. No publication or historical migration replay.
begin;
set local lock_timeout='5s';set local statement_timeout='120s';
set local standard_conforming_strings=on;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
"""
        + do_sql(
            """if not exists(select 1 from private.rad_editorial_import_target where project_ref='epolbumcfbohtmgvomki' and not enabled) then raise exception 'v4_wrong_target_or_gate_changed';end if;
update private.rad_editorial_import_target set enabled=true where project_ref='epolbumcfbohtmgvomki';
"""
            + body
            + "\nupdate private.rad_editorial_import_target set enabled=false where project_ref='epolbumcfbohtmgvomki';",
            "s jsonb;cs uuid;doc uuid;snap uuid;rid uuid;v public.visa_article_revisions;c jsonb;req jsonb;pc jsonb;pa jsonb;pt jsonb;ph jsonb;",
        )
        + "\ncommit;\n"
    )


def capture_parent_sql(article):
    return f"""
perform pg_advisory_xact_lock(hashtextextended('rad-editorial:{article}',0));
select to_jsonb(x) into pc from private.rad_editorial_catalog x where article_id='{article}' for update;
select to_jsonb(x) into pa from public.visa_articles x where id='{article}';
select coalesce(jsonb_agg(to_jsonb(x) order by country_code),'[]'::jsonb) into pt from private.rad_editorial_country_titles x where article_id='{article}';
select coalesce(jsonb_agg(jsonb_build_object('locale',locale,'head_id',head_id,'published_id',published_id) order by locale),'[]'::jsonb) into ph from public.visa_article_heads where article_id='{article}' and (head_id is not null or published_id is not null);
"""


def catalog_preflight_sql(article, prior, original_heads, manifest):
    baseline = "false"
    if prior:
        baseline = f"encode(extensions.digest(pc::text,'sha256'),'hex')={quote(prior['catalog_hash'])} and pa={literal(prior['identity'])} and pt={literal(prior['country_titles'])} and ph={literal(original_heads)}"
    parent_hash = (
        f"and pc->'composition'->'content_full_v4'->>'parent_catalog_hash'={quote(prior['catalog_hash'])}"
        if prior
        else ""
    )
    return f"""
if exists(select 1 from public.visa_article_heads where article_id='{article}' and published_id is not null) then raise exception 'v4_shared_publication_protected';end if;
if pc is not null and not coalesce(({baseline}) or (pc->'composition'->'content_full_v4'->>'manifest'={quote(manifest)} {parent_hash}
and pc-'composition'=pc->'composition'->'content_full_v4'->'applied_catalog_metadata'
and pa=pc->'composition'->'content_full_v4'->'applied_identity'
and pt=pc->'composition'->'content_full_v4'->'applied_country_titles'
and ph=pc->'composition'->'content_full_v4'->'applied_heads'),false) then raise exception 'v4_catalog_or_shared_locale_changed';end if;
"""


def catalog_refresh_sql(item):
    article = item["article_id"]
    countries = literal(item["country_codes"])
    editorial = item["content_class"] == "editorial"
    kind = "related" if editorial else "main"
    pathway = (
        "topic-" + article.replace("-", "") if editorial else item["visa_category"]
    )
    return f"""
if exists(select 1 from private.rad_editorial_country_titles where article_id='{article}' and state<>'proposed' and (not country_code=any(array(select jsonb_array_elements_text({countries}))) or not {str(editorial).lower()})) then raise exception 'v4_reviewed_country_mapping_requires_reconciliation';end if;
update public.visa_articles set kind={quote(kind)},country_code=case when jsonb_array_length({countries})=1 then {countries}->>0 else null end,pathway_slug={quote(pathway)} where id='{article}';
update private.rad_editorial_catalog set content_class={quote(item["content_class"])},category={quote(item["category"])},country_codes=array(select jsonb_array_elements_text({countries})),active=true,
composition=(select composition from private.rad_editorial_rich_revisions where revision_id=rid),
source_snapshot_ids=array(select distinct (ref->>'snapshot_id')::uuid from public.visa_article_heads h join private.rad_editorial_rich_revisions rr on rr.revision_id=h.head_id cross join lateral jsonb_array_elements(rr.composition->'sections')sec cross join lateral jsonb_array_elements(sec->'blocks')b cross join lateral jsonb_array_elements(b->'provenance')ref where h.article_id='{article}' order by 1),
source_publishers=array(select distinct o.publisher from public.visa_article_heads h join private.rad_editorial_rich_revisions rr on rr.revision_id=h.head_id cross join lateral jsonb_array_elements(rr.composition->'sections')sec cross join lateral jsonb_array_elements(sec->'blocks')b cross join lateral jsonb_array_elements(b->'provenance')ref join private.visa_source_origins o on o.snapshot_id=(ref->>'snapshot_id')::uuid where h.article_id='{article}' order by 1)
where article_id='{article}' and active;
if not found then raise exception 'v4_catalog_inactive_or_missing';end if;
delete from private.rad_editorial_country_titles where article_id='{article}' and (not country_code=any(array(select jsonb_array_elements_text({countries}))) or not {str(editorial).lower()});
insert into private.rad_editorial_country_titles(country_code,article_id) select value,'{article}' from jsonb_array_elements_text({countries}) where {str(editorial).lower()} on conflict do nothing;
update private.rad_editorial_rich_revisions set composition=jsonb_set(composition,'{{content_full_v4}}',composition->'content_full_v4'||jsonb_build_object('applied_catalog_metadata',(select to_jsonb(x)-'composition' from private.rad_editorial_catalog x where article_id='{article}'),'applied_identity',(select to_jsonb(x) from public.visa_articles x where id='{article}'),'applied_country_titles',(select coalesce(jsonb_agg(to_jsonb(x) order by country_code),'[]'::jsonb) from private.rad_editorial_country_titles x where article_id='{article}'),'applied_heads',(select coalesce(jsonb_agg(jsonb_build_object('locale',locale,'head_id',head_id,'published_id',published_id) order by locale),'[]'::jsonb) from public.visa_article_heads where article_id='{article}' and (head_id is not null or published_id is not null)))) where revision_id=rid;
update private.rad_editorial_catalog set composition=(select composition from private.rad_editorial_rich_revisions where revision_id=rid) where article_id='{article}';
"""


def restore_catalog_sql(article):
    return f"""
if c->'content_full_v4'->'parent_catalog' is not null and c->'content_full_v4'->'parent_catalog'<>'null'::jsonb then
update private.rad_editorial_catalog set content_class=c->'content_full_v4'->'parent_catalog'->>'content_class',category=c->'content_full_v4'->'parent_catalog'->>'category',country_codes=array(select jsonb_array_elements_text(c->'content_full_v4'->'parent_catalog'->'country_codes')),source_publishers=array(select jsonb_array_elements_text(c->'content_full_v4'->'parent_catalog'->'source_publishers')),source_snapshot_ids=array(select jsonb_array_elements_text(c->'content_full_v4'->'parent_catalog'->'source_snapshot_ids'))::uuid[],composition=c->'content_full_v4'->'parent_catalog'->'composition',active=(c->'content_full_v4'->'parent_catalog'->>'active')::boolean where article_id='{article}';
delete from private.rad_editorial_country_titles where article_id='{article}';
insert into private.rad_editorial_country_titles select (jsonb_populate_record(null::private.rad_editorial_country_titles,value)).* from jsonb_array_elements(c->'content_full_v4'->'parent_country_titles');
update public.visa_articles set kind=c->'content_full_v4'->'parent_identity'->>'kind',country_code=c->'content_full_v4'->'parent_identity'->>'country_code',pathway_slug=c->'content_full_v4'->'parent_identity'->>'pathway_slug',slug=c->'content_full_v4'->'parent_identity'->>'slug' where id='{article}';
else
update private.rad_editorial_catalog set active=false where article_id='{article}' and not exists(select 1 from public.visa_article_heads where article_id='{article}' and (head_id is not null or published_id is not null));
end if;
"""


def rollback_operation_sql(item, prior, manifest, batch):
    article, locale = item["article_id"], item["locale"]
    revision = prior["revision"] + 1 if prior else 1
    target_body = {
        k: value for k, value in item["draft_request"].items() if k != "request_key"
    }
    target_body["expected_revision"] = prior["revision"] if prior else 0
    guard = f"""
v.revision={revision} and v.body={literal(target_body)}
and v.content_hash=encode(extensions.digest(({literal(target_body)}-'expected_revision')::text,'sha256'),'hex')
and c->'content_full_v4'->>'manifest'={quote(manifest)} and c->'sections'={literal(item["sections"])}
and private.rad_article_state(v.id)='draft' and private.rad_article_verification(v.id)='unverified'
and not exists(select 1 from private.rad_editorial_clearances where revision_id=v.id)
and not exists(select 1 from public.visa_article_heads where article_id='{article}' and locale='{locale}' and published_id is not null)
and exists(select 1 from private.rad_editorial_catalog where article_id='{article}' and composition=c)
and (select to_jsonb(x)-'composition' from private.rad_editorial_catalog x where article_id='{article}')=c->'content_full_v4'->'applied_catalog_metadata'
and (select to_jsonb(x) from public.visa_articles x where id='{article}')=c->'content_full_v4'->'applied_identity'
and (select coalesce(jsonb_agg(to_jsonb(x) order by country_code),'[]'::jsonb) from private.rad_editorial_country_titles x where article_id='{article}')=c->'content_full_v4'->'applied_country_titles'
and (select coalesce(jsonb_agg(jsonb_build_object('locale',locale,'head_id',head_id,'published_id',published_id) order by locale),'[]'::jsonb) from public.visa_article_heads where article_id='{article}' and (head_id is not null or published_id is not null))=c->'content_full_v4'->'applied_heads'
"""
    body = f"""
perform pg_advisory_xact_lock(hashtextextended('rad-editorial:{article}',0));
select r.* into v from public.visa_article_heads h join public.visa_article_revisions r on r.id=h.head_id where h.article_id='{article}' and h.locale='{locale}' for update of h;
select composition into c from private.rad_editorial_rich_revisions where revision_id=v.id;
if {guard} then
update public.visa_article_heads set head_id={quote(prior["head_id"]) + "::uuid" if prior else "null"} where article_id='{article}' and locale='{locale}';
"""
    if not prior:
        body += f"update private.rad_editorial_import_journal set rolled_back_at=now() where article_id='{article}' and locale='{locale}' and batch_id='{batch}' and revision_id=v.id and rolled_back_at is null;\n"
    body += restore_catalog_sql(article) + "\nend if;"
    return do_sql(body, "v public.visa_article_revisions;c jsonb;")


def retirement_candidates(articles, heads, ready_ids):
    """Prove every prior original segment is represented before hiding a reader."""
    frozen = Path("artifacts/RAD_CONTENT_CONSOLIDATION_20261026/articles.jsonl.gz")
    if not frozen.exists():
        return [], []
    old_articles = read_jsonl(frozen)
    target_signatures, locale_corrections = {}, {}
    for article in articles:
        identity = (article["article_id"], article["locale"])
        if identity in ready_ids:
            target_signatures[identity] = {
                (r["url"], r["structure_sha256"]) for r in article["segment_ledger"]
            }
            locale_corrections[identity] = {
                (
                    r["source_url"],
                    r.get("original_recorded_locale", r["original_capture_language"]),
                )
                for r in article.get("locale_corrections", [])
                if r["corrected_locale"] == article["locale"]
                and r.get("translation_created") is False
            }
    current_ids = {article["article_id"] for article in articles}
    grouped, blocked = {}, []
    for old in old_articles:
        identity = (old["article_id"], old["locale"])
        prior = heads.get(identity)
        if (
            not prior
            or old["article_id"] in current_ids
            or not prior.get("catalog_active")
        ):
            continue
        if (
            not prior.get("batch_id")
            or prior["published_id"]
            or prior["revision"] != 1
            or not prior.get("catalog_hash")
        ):
            blocked.append(
                {
                    "article_id": identity[0],
                    "locale": identity[1],
                    "reason": "retirement_protected_existing_head",
                }
            )
            continue
        needed = {(r["url"], r["structure_sha256"]) for r in old["segment_ledger"]}
        candidates = {
            key: {
                signature
                for signature in signatures
                if key[1] == identity[1]
                or (signature[0], identity[1]) in locale_corrections[key]
            }
            for key, signatures in target_signatures.items()
            if signatures & needed
        }
        missing = needed - set().union(set(), *candidates.values())
        if missing:
            blocked.append(
                {
                    "article_id": identity[0],
                    "locale": identity[1],
                    "reason": "prior_source_segments_not_proven_represented",
                    "missing_unique_signatures": len(missing),
                }
            )
            continue
        remaining, targets = set(needed), []
        while remaining:
            best = min(
                candidates, key=lambda key: (-len(candidates[key] & remaining), key)
            )
            targets.append(best)
            remaining -= candidates[best]
        grouped.setdefault(identity[0], []).append(
            {
                "locale": identity[1],
                "prior": prior,
                "replacement_article_ids": sorted({key[0] for key in targets}),
                "replacement_destinations": [
                    {"article_id": key[0], "locale": key[1]}
                    for key in sorted(set(targets))
                ],
                "source_segment_proof": [
                    {"url": url, "structure_sha256": value}
                    for url, value in sorted(needed)
                ],
            }
        )
    plans = []
    for article, locales in grouped.items():
        existing_locales = {
            locale
            for aid, locale in heads
            if aid == article and heads[(aid, locale)].get("head_id")
        }
        if existing_locales != {row["locale"] for row in locales}:
            blocked.append(
                {
                    "article_id": article,
                    "reason": "retirement_cannot_hide_unrepresented_locale",
                }
            )
        else:
            plans.append({"article_id": article, "locales": locales})
    return sorted(plans, key=lambda r: r["article_id"]), blocked


def retirement_sql(plan, manifest):
    article = plan["article_id"]
    body = capture_parent_sql(article)
    for row in plan["locales"]:
        prior, locale = row["prior"], row["locale"]
        body += f"""
if not exists(select 1 from public.visa_article_heads h join public.visa_article_revisions rv on rv.id=h.head_id join private.rad_editorial_rich_revisions rr on rr.revision_id=rv.id where h.article_id='{article}' and h.locale='{locale}' and h.head_id='{prior["head_id"]}' and rv.content_hash={quote(prior["content_hash"])} and h.published_id is null and private.rad_article_state(rv.id)='draft' and private.rad_article_verification(rv.id)='unverified' and not exists(select 1 from private.rad_editorial_clearances where revision_id=rv.id) and encode(extensions.digest((rr.composition->'sections')::text,'sha256'),'hex')={quote(prior["rich_sections_hash"])}) then raise exception 'v4_retirement_head_changed';end if;
if exists(select 1 from jsonb_array_elements({literal(row["source_segment_proof"])})proof where not exists(select 1 from public.visa_article_heads h join private.rad_editorial_catalog cat on cat.article_id=h.article_id and cat.active join private.rad_editorial_rich_revisions rr on rr.revision_id=h.head_id cross join lateral jsonb_array_elements(rr.composition->'sections')sec cross join lateral jsonb_array_elements(sec->'blocks')b cross join lateral jsonb_array_elements(b->'provenance')ref where exists(select 1 from jsonb_array_elements({literal(row["replacement_destinations"])})dest where h.article_id=(dest->>'article_id')::uuid and h.locale=dest->>'locale') and rr.composition->'content_full_v4'->>'manifest'={quote(manifest)} and ref->>'url'=proof->>'url' and ref->>'structure_sha256'=proof->>'structure_sha256')) then raise exception 'v4_retirement_source_coverage_not_live';end if;
"""
    prior_hash = plan["locales"][0]["prior"]["catalog_hash"]
    body += f"""
if pc->'composition'->'content_full_v4_retirement'->>'manifest'={quote(manifest)} and not (pc->>'active')::boolean then null;else
if encode(extensions.digest(pc::text,'sha256'),'hex')<>{quote(prior_hash)} then raise exception 'v4_retirement_catalog_changed';end if;
update private.rad_editorial_catalog set active=false,composition=composition||jsonb_build_object('content_full_v4_retirement',jsonb_build_object('manifest',{quote(manifest)},'parent_catalog',pc,'parent_identity',pa,'parent_country_titles',pt,'parent_heads',ph,'coverage',{literal(plan["locales"])})) where article_id='{article}';
end if;
"""
    restore = f"""
perform pg_advisory_xact_lock(hashtextextended('rad-editorial:{article}',0));
select composition into c from private.rad_editorial_catalog where article_id='{article}' and not active for update;
if c->'content_full_v4_retirement'->>'manifest'={quote(manifest)} and (select coalesce(jsonb_agg(jsonb_build_object('locale',locale,'head_id',head_id,'published_id',published_id) order by locale),'[]'::jsonb) from public.visa_article_heads where article_id='{article}' and (head_id is not null or published_id is not null))=c->'content_full_v4_retirement'->'parent_heads' and (select to_jsonb(x) from public.visa_articles x where id='{article}')=c->'content_full_v4_retirement'->'parent_identity' and (select coalesce(jsonb_agg(to_jsonb(x) order by country_code),'[]'::jsonb) from private.rad_editorial_country_titles x where article_id='{article}')=c->'content_full_v4_retirement'->'parent_country_titles' then
c:=jsonb_build_object('content_full_v4',c->'content_full_v4_retirement');
{restore_catalog_sql(article)}
end if;
"""
    return body, do_sql(restore, "c jsonb;")


def compile_operations(directory, root, output):
    from tools.content_completion.full_audit_v4 import audit

    sources = read_jsonl(directory / "sources.jsonl.gz") + read_jsonl(
        directory / "supplements.jsonl.gz"
    )
    articles = read_jsonl(directory / "articles.jsonl.gz")
    verification = audit(sources, articles)
    save_json(directory / "independent-audit.json", verification)
    heads = {
        (r["article_id"], r["locale"]): r
        for r in json.loads((root / "staging-heads-before.json").read_text("utf-8"))
    }
    existing_sources = json.loads(
        (root / "staging-sources-before.json").read_text("utf-8")
    )
    source_index = {s["source_id"]: s for s in sources}
    rows = [canonicalize(a, source_index, existing_sources) for a in articles]
    blocked = [r for r in rows if r["status"] != "technical_draft_only"]
    ready = [r for r in rows if r["status"] == "technical_draft_only"]
    output.mkdir(parents=True, exist_ok=True)
    write_jsonl(output / "payloads.jsonl.gz", ready)
    save_json(output / "blocked.json", blocked)
    manifest = hashlib.sha256((directory / "manifest.json").read_bytes()).hexdigest()
    batch = uid("RAD_FULL_CONTENT_V4:" + manifest)
    operations, rollbacks = [], []
    for number, row in enumerate(ready):
        item = row["item"]
        article, locale = item["article_id"], item["locale"]
        prior = heads.get((article, locale))
        shared_heads = sorted(
            (h for (aid, _), h in heads.items() if aid == article),
            key=lambda h: h["locale"],
        )
        shared_prior = prior or (shared_heads[0] if shared_heads else None)
        if (
            not prior
            and shared_prior
            and (not shared_prior.get("batch_id") or shared_prior.get("published_id"))
        ):
            blocked.append(
                {
                    "article_id": article,
                    "locale": locale,
                    "reason": "protected_existing_identity_cannot_gain_imported_locale",
                }
            )
            continue
        body = source_sql(row["sources"], manifest) + capture_parent_sql(article)
        body += catalog_preflight_sql(
            article,
            shared_prior,
            [
                {key: h[key] for key in ("locale", "head_id", "published_id")}
                for h in shared_heads
            ],
            manifest,
        )
        saved = {k: val for k, val in item.items() if k != "draft_request"}
        marker = {
            "manifest": manifest,
            "batch_id": batch,
            "parent_head": prior,
            "parent_catalog_hash": shared_prior.get("catalog_hash")
            if shared_prior
            else None,
        }
        saved["content_full_v4"] = marker
        base_saved = {k: value for k, value in saved.items() if k != "content_full_v4"}
        marker_sql = (
            literal(marker)
            + "||jsonb_build_object('parent_catalog',pc,'parent_identity',pa,'parent_country_titles',pt,'parent_heads',ph)"
        )
        saved_sql = (
            literal(saved)
            + "||jsonb_build_object('content_full_v4',"
            + marker_sql
            + ")"
        )
        if prior:
            if not prior["batch_id"] or prior["published_id"] or prior["revision"] != 1:
                blocked.append(
                    {
                        "article_id": article,
                        "locale": locale,
                        "reason": "human_or_published_head_requires_reconciliation",
                    }
                )
                continue
            if not prior.get("catalog_hash"):
                raise ValueError("exact_catalog_preflight_hash_required")
            body += f"""
select r.* into strict v from public.visa_article_heads h join public.visa_article_revisions r on r.id=h.head_id where h.article_id='{article}' and h.locale='{locale}' for update of h;
select composition into c from private.rad_editorial_rich_revisions where revision_id=v.id;
if private.rad_article_state(v.id)<>'draft' or private.rad_article_verification(v.id)<>'unverified' or exists(select 1 from private.rad_editorial_clearances where revision_id=v.id) or exists(select 1 from public.visa_article_heads where article_id='{article}' and locale='{locale}' and published_id is not null) then raise exception 'v4_existing_head_changed';end if;
if c->'content_full_v4'->>'manifest'={quote(manifest)} and c-'content_full_v4'={literal(base_saved)} and v.revision={prior["revision"] + 1} and v.body={literal(item["draft_request"])}-'request_key'||jsonb_build_object('expected_revision',{prior["revision"]}) then rid:=v.id;else
if v.id<>'{prior["head_id"]}'::uuid or v.content_hash<>{quote(prior["content_hash"])} or encode(extensions.digest((c->'sections')::text,'sha256'),'hex')<>{quote(prior["rich_sections_hash"])} then raise exception 'v4_existing_head_changed';end if;
if encode(extensions.digest(pc::text,'sha256'),'hex')<>{quote(prior["catalog_hash"])} and not coalesce(pc->'composition'->'content_full_v4'->>'manifest'={quote(manifest)} and pc->'composition'->'content_full_v4'->>'parent_catalog_hash'={quote(prior["catalog_hash"])},false) then raise exception 'v4_catalog_changed';end if;
req:={literal(item["draft_request"])}||jsonb_build_object('expected_revision',v.revision,'request_key','{uid(batch + article + locale)}');
perform private.rad_assert_request('save_visa_article_draft',req);
perform set_config('request.jwt.claims','{{"role":"service_role","sub":"{ACTOR}"}}',true);
rid:=private.rad_save_article(req);
insert into private.rad_editorial_rich_revisions(revision_id,composition) values(rid,{saved_sql}) on conflict(revision_id) do update set composition=excluded.composition where private.rad_editorial_rich_revisions.composition=c;
{catalog_refresh_sql(item)}
end if;
"""
        else:
            body += f"""
if not exists(select 1 from private.rad_editorial_import_journal where article_id='{article}' and locale='{locale}' and batch_id='{batch}' and rolled_back_at is null) then
perform public.import_editorial_draft('{batch}','{manifest}','{ACTOR}',{saved_sql}||jsonb_build_object('draft_request',{literal(item["draft_request"])}),{literal(row["sources"])});
end if;
select r.* into strict v from public.visa_article_heads h join public.visa_article_revisions r on r.id=h.head_id where h.article_id='{article}' and h.locale='{locale}' for update of h;
rid:=v.id;
select composition into c from private.rad_editorial_rich_revisions where revision_id=rid;
if v.revision<>1 or private.rad_article_state(v.id)<>'draft' or private.rad_article_verification(v.id)<>'unverified' or exists(select 1 from private.rad_editorial_clearances where revision_id=v.id) or c->'content_full_v4'->>'manifest' is distinct from {quote(manifest)} or c-'content_full_v4' is distinct from {literal(base_saved)} or v.body is distinct from {literal(item["draft_request"])}-'request_key' or exists(select 1 from public.visa_article_heads where article_id='{article}' and locale='{locale}' and published_id is not null) then raise exception 'v4_new_import_head_changed';end if;
if c->'content_full_v4'->'applied_heads' is null then
{catalog_refresh_sql(item)}
end if;
"""
        rollback = rollback_operation_sql(item, prior, manifest, batch)
        body += f"""
perform public.attach_editorial_reference_map('{article}','{locale}',{prior["revision"] + 1 if prior else 1},'{manifest}',{literal(row["reference_map"])});
perform set_config('request.jwt.claims','{{"role":"authenticated","sub":"{ACTOR}"}}',true);
if public.get_editorial_article('{article}','{locale}',true)->'data'->'rich_sections' is distinct from {literal(item["sections"])} then raise exception 'v4_complete_reader_roundtrip_failed';end if;
perform set_config('request.jwt.claims','{{"role":"service_role"}}',true);
"""
        filename = f"operation-{number:04d}.sql.gz"
        raw = transaction(body).encode("utf-8")
        with gzip.GzipFile(
            filename="", fileobj=(output / filename).open("wb"), mode="wb", mtime=0
        ) as stream:
            stream.write(raw)
        operations.append(
            {
                "file": filename,
                "sha256": hashlib.sha256(raw).hexdigest(),
                "article_id": article,
                "locale": locale,
                "operation": "guarded_revision" if prior else "new_draft",
                "sql_bytes": len(raw),
            }
        )
        if rollback:
            rollbacks.append(rollback)
    ready_ids = {(r["article_id"], r["locale"]) for r in operations}
    retirements, retirement_blockers = retirement_candidates(articles, heads, ready_ids)
    blocked.extend(retirement_blockers)
    save_json(output / "retirement-coverage-proofs.json", retirements)

    def emit_finalization(body, kind, article_id=None):
        filename = f"operation-{len(ready) + sum(r['operation'] not in ('new_draft', 'guarded_revision') for r in operations):04d}.sql.gz"
        raw = transaction(body).encode("utf-8")
        with (
            (output / filename).open("wb") as handle,
            gzip.GzipFile(filename="", fileobj=handle, mode="wb", mtime=0) as stream,
        ):
            stream.write(raw)
        operations.append(
            {
                "file": filename,
                "sha256": hashlib.sha256(raw).hexdigest(),
                "article_id": article_id,
                "locale": None,
                "operation": kind,
                "sql_bytes": len(raw),
            }
        )

    for retirement in retirements:
        forward, backward = retirement_sql(retirement, manifest)
        emit_finalization(
            forward, "represented_reader_retirement", retirement["article_id"]
        )
        rollbacks.append(backward)
    relation_path = directory / "relations.jsonl.gz"
    if relation_path.exists():
        ready_articles = {identity[0] for identity in ready_ids}
        unique_relations = {
            (r["parent_id"], r["related_id"]): r
            for r in read_jsonl(relation_path)
            if r["parent_id"] in ready_articles and r["related_id"] in ready_articles
        }
        relations = [
            {**value, "v4_manifest": manifest}
            for _, value in sorted(unique_relations.items())
        ]
        for offset in range(0, len(relations), 250):
            chunk = relations[offset : offset + 250]
            body = f"""
select coalesce(jsonb_agg(value),'[]'::jsonb) into req from jsonb_array_elements({literal(chunk)}) where not exists(select 1 from private.rad_editorial_relations where parent_id=(value->>'parent_id')::uuid and related_id=(value->>'related_id')::uuid);
if jsonb_array_length(req)>0 then perform public.propose_editorial_relations(req);end if;
"""
            emit_finalization(body, "context_relation_proposals")
        rollbacks.append(
            f"delete from private.rad_editorial_relations where justification->>'v4_manifest'={quote(manifest)} and state='proposed' and revision=1 and reviewed_by is null;"
        )
    rollback = (
        "begin;\nselect set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);\nupdate private.rad_editorial_import_target set enabled=true where project_ref='epolbumcfbohtmgvomki';\n"
        + "\n".join(reversed(rollbacks))
        + f"\nupdate private.rad_editorial_import_batches set rolled_back_at=now() where id='{batch}' and not exists(select 1 from private.rad_editorial_import_journal where batch_id='{batch}' and rolled_back_at is null);\nupdate private.rad_editorial_import_target set enabled=false where project_ref='epolbumcfbohtmgvomki';\ncommit;\n"
    )
    (output / "rollback.sql").write_text(rollback, encoding="utf-8")
    save_json(output / "blocked.json", blocked)
    result = {
        "project": PROJECT,
        "actor_id": ACTOR,
        "manifest_sha256": manifest,
        "batch_id": batch,
        "operations": operations,
        "blocked": len(blocked),
        "counts": dict(Counter(r["operation"] for r in operations)),
        "publication_allowed": False,
        "hosted_executed": False,
    }
    save_json(output / "import-plan.json", result)
    return {k: v for k, v in result.items() if k != "operations"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("compose", "compile"))
    parser.add_argument(
        "--root", type=Path, default=Path("artifacts/RAD_FULL_CONTENT_V4_20261028")
    )
    args = parser.parse_args()
    result = (
        compose_all(args.root / "recovery", args.root / "composition")
        if args.mode == "compose"
        else compile_operations(
            args.root / "composition", args.root, args.root / "import"
        )
    )
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
