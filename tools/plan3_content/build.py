"""Build the reviewable content library from captured evidence, without network or DB writes."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path

from .dataset import (
    COMPRESSION,
    FORMAT_VERSION,
    canonicalize,
    cms_payload,
    digest_bytes,
    read_jsonl,
    registry_sha256,
    source_records,
    updated_identities,
    validate_package,
    write_jsonl,
)
from .parser import digest
from .quality import assess_references, assess_source
from .taxonomy import COUNTRIES, PATHWAYS, VERSION


def write_json(path, value):
    path.write_text(
        json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf8",
        newline="\n",
    )


def write_csv(path, rows, fields):
    with path.open("w", encoding="utf8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    k: json.dumps(v, ensure_ascii=False, separators=(",", ":"))
                    if isinstance(v, (list, dict))
                    else v
                    for k, v in row.items()
                    if k in fields
                }
            )


def build(
    collected,
    production,
    structured,
    discovery,
    output,
    registry_path,
    cache=None,
    schema_gate=None,
):
    output.mkdir(parents=True, exist_ok=True)
    data_dir = output / "data"
    data_dir.mkdir(exist_ok=True)
    registry = json.loads(registry_path.read_text(encoding="utf8"))
    previous_path = data_dir / "canonical_identity_registry.json"
    previous = (
        json.loads(previous_path.read_text(encoding="utf8"))
        if previous_path.exists()
        else {}
    )
    sources = source_records(collected, production, cache)
    for s in sources:
        s["quality"] = assess_source(s)
    assess_references(sources)
    # A compact parsed capture makes offline rebuilds possible without copying
    # raw HTML or every site's repeated navigation links into Git.
    capture = []
    for s in sources:
        capture.append(
            {
                **(
                    {"fetch_history": s["fetch_history"]}
                    if s.get("fetch_history")
                    else {}
                ),
                "id": s["collector_id"],
                "url": s["url"],
                "discovered_via": s["discovered_via"],
                "fetch_status": s["fetch_status"],
                "status": s["http_status"],
                "final_url": s["resolved_url"],
                "redirects": s["redirects"],
                "error": s["fetch_error"],
                "retrieved_at": s["retrieved_at"],
                "raw_sha256": s["raw_html_sha256"],
                "last_modified_header": s["http_last_modified"],
                "extraction": {
                    "title": s["title"],
                    "language": s["language"],
                    "body_text": s["body_text"],
                    "blocks": s["blocks"],
                    "body_status": s["body_status"],
                    "source_container_text_chars": s["source_container_text_chars"],
                    "canonical_url": s["declared_canonical_url"],
                    "dates": s["date_evidence"],
                    "body_links": s["body_links"],
                    "selector": s["parser_selector"],
                    "warnings": s["parser_warnings"],
                },
            }
        )
    write_jsonl(data_dir / "capture.jsonl.gz", capture)
    groups, relationships = canonicalize(sources, previous)
    by_source = {s["source_id"]: s for s in sources}
    countries = {d["code"] for d in production["destinations"]}
    drafts = [
        cms_payload(g, by_source[g["primary_source_id"]], registry, countries)
        for g in groups
    ]
    for a in drafts:
        q = by_source[a["primary_source_id"]]["quality"]
        a["validation"]["blocking_errors"] = sorted(
            set(a["validation"]["blocking_errors"] + q["blocking_errors"])
        )
        a["validation"]["warnings"] = sorted(
            set(a["validation"]["warnings"] + q["warnings"])
        )
        a["validation"]["draft_payload_valid"] = not a["validation"]["blocking_errors"]
    by_group = {g["canonical_id"]: g for g in groups}
    by_draft = {a["canonical_id"]: a for a in drafts}
    membership = {sid: g["canonical_id"] for g in groups for sid in g["source_ids"]}
    for s in sources:
        s["canonical_group"] = membership.get(s["source_id"])
    canonical = []
    for g in groups:
        s = by_source[g["primary_source_id"]]
        canonical.append(
            {
                **g,
                "body_text": s["body_text"],
                "structured_blocks": s["blocks"],
                "retrieved_at": s["retrieved_at"],
                "source_body_completeness": s["body_status"],
                "source_manifests": [
                    {
                        "source_id": by_source[i]["source_id"],
                        "url": by_source[i]["url"],
                        "snapshot_id": by_source[i]["snapshot_id"],
                        "body_sha256": by_source[i]["body_sha256"],
                        "retrieved_at": by_source[i]["retrieved_at"],
                    }
                    for i in g["source_ids"]
                ],
                "content_version_hash": by_draft[g["canonical_id"]]["payload_sha256"],
                "parent_content_version": None,
                "change_diff_inputs": {
                    "block_hashes": [digest(b) for b in s["blocks"]],
                    "original_text_retained": True,
                },
            }
        )
    write_jsonl(data_dir / "sources.jsonl.gz", sources)
    write_jsonl(data_dir / "canonical_articles.jsonl.gz", canonical)
    write_jsonl(data_dir / "cms_drafts.jsonl.gz", drafts)
    write_json(
        previous_path,
        updated_identities(previous, groups),
    )
    write_json(data_dir / "duplicate_relationships.json", relationships)
    write_json(data_dir / "production_content_baseline.json", production)
    write_json(data_dir / "production_structured_baseline.json", structured)
    write_json(data_dir / "production_canonical_schema_gate.json", schema_gate)
    write_json(data_dir / "discovery.json", discovery)
    write_json(
        data_dir / "taxonomy.json",
        {
            "version": VERSION,
            "country_aliases": COUNTRIES,
            "pathways": PATHWAYS,
            "classification_is_inference": True,
            "human_review_required": True,
        },
    )
    package = {
        "format_version": FORMAT_VERSION,
        "publication_allowed": False,
        "production_import_enabled": False,
        "human_approval_required": True,
        "destination_catalog_country_codes": sorted(countries),
        "approved_by": None,
        "approved_at": None,
        "cms_registry_sha256": registry_sha256(registry_path),
        "cms_registry_hash_format": "UTF-8_text_with_LF_line_endings",
        "payload_file": "data/cms_drafts.jsonl.gz",
        "payload_file_sha256": digest_bytes(
            (data_dir / "cms_drafts.jsonl.gz").read_bytes()
        ),
        "source_file": "data/sources.jsonl.gz",
        "source_file_sha256": digest_bytes(
            (data_dir / "sources.jsonl.gz").read_bytes()
        ),
        "canonical_file": "data/canonical_articles.jsonl.gz",
        "canonical_file_sha256": digest_bytes(
            (data_dir / "canonical_articles.jsonl.gz").read_bytes()
        ),
        "identity_registry_file": "data/canonical_identity_registry.json",
        "identity_registry_sha256": digest_bytes(previous_path.read_bytes()),
        "source_snapshot_ids_are_proposed_until_resolved": True,
        "import_policy": "initial_drafts_only_expected_revision_0_no_approval_no_publication",
        "articles": [
            {
                k: a[k]
                for k in [
                    "canonical_id",
                    "title",
                    "locale",
                    "country_code",
                    "country_codes",
                    "pathway",
                    "category",
                    "summary",
                    "body_sha256",
                    "payload_sha256",
                    "source_ids",
                    "primary_source_id",
                    "source_snapshot_id",
                    "retrieved_at",
                    "source_urls",
                    "review_status",
                    "verification_status",
                    "publication_allowed",
                    "validation",
                ]
            }
            for a in drafts
        ],
    }
    write_json(output / "10_CMS_DRAFT_IMPORT_PACKAGE.json", package)
    validation = validate_package(
        output / "10_CMS_DRAFT_IMPORT_PACKAGE.json", registry_path
    )
    inventory = []
    for s in sources:
        a = by_draft.get(s.get("canonical_group"), {})
        tax = s["taxonomy"]
        g = by_group.get(s.get("canonical_group"), {})
        inventory.append(
            {
                "source_id": s["source_id"],
                "url": s["url"],
                "domain": s["domain"],
                "page_title": s["title"],
                "type": tax["page_type"],
                "language": s["language"],
                "country": tax["country_codes"],
                "pathway": tax["pathway"],
                "topic": tax["topic"],
                "source_availability": "retrieved"
                if s["fetch_status"] == "fetched"
                else s["fetch_status"],
                "fetch_status": s["fetch_status"],
                "http_status": s["http_status"],
                "content_body_status": s["body_status"],
                "article_body_assessment": s["article_body_assessment"],
                "body_completeness": "full_source_container"
                if s["complete_article_body"]
                else "not_complete_article_body",
                "publication_date_evidence": [
                    x for x in s["date_evidence"] if "publish" in x["field"].lower()
                ],
                "modification_date_evidence": [
                    x for x in s["date_evidence"] if "modif" in x["field"].lower()
                ],
                "retrieval_timestamp": s["retrieved_at"],
                "source_confidence": s["source_confidence"],
                "canonical_group": s["canonical_group"],
                "duplicate_relationship": g.get("duplicate_type"),
                "conflict_status": "potential_conflict_review"
                if g.get("conflicts")
                else "not_established",
                "import_readiness": "structurally_valid_draft_pending_backend_and_human_review"
                if a.get("validation", {}).get("draft_payload_valid")
                else "blocked_or_not_article",
                "publication_allowed": False,
                "body_chars": len(s["body_text"]),
                "source_id_origin": s["id_origin"],
            }
        )
    fields = list(inventory[0]) if inventory else ["source_id", "url", "fetch_status"]
    write_csv(output / "01_SOURCE_DISCOVERY_INVENTORY.csv", inventory, fields)
    historical = [
        {
            "record_type": "historical_report",
            "historical_report": "812 source entries /10 incomplete canonical /0 ready",
            "historical_count": 812,
            "historical_source_id": None,
            "current_source_id": None,
            "url": None,
            "reconciliation_status": "missing_original_inventory_count_and_membership_not_verifiable",
            "evidence": "Named artifact folders absent from refreshed main, inspected branches/history and local workspace; owner confirms historical references only.",
        }
    ]
    historical.extend(
        {
            "record_type": "reconstructed_current_source",
            "historical_report": "812 source report",
            "historical_count": None,
            "historical_source_id": (
                s["historical_source_evidence"]["existing_document"] or {}
            ).get("id"),
            "current_source_id": s["source_id"],
            "url": s["url"],
            "reconciliation_status": "existing_production_id_preserved_membership_unknown"
            if s["id_origin"] == "existing_production_document"
            else "reconstructed_812_membership_unknown",
            "evidence": "actual_current_source_discovery_not_a_recovered_historical_row",
        }
        for s in sources
    )
    write_csv(
        output / "02_812_SOURCE_RECONCILIATION.csv", historical, list(historical[0])
    )
    write_csv(
        output / "03_SOURCE_FETCH_RESULTS.csv",
        [
            {
                "source_id": s["source_id"],
                "url": s["url"],
                "status": s["fetch_status"],
                "http_status": s["http_status"],
                "resolved_url": s["resolved_url"],
                "redirects": s["redirects"],
                "error": s["fetch_error"],
                "retrieved_at": s["retrieved_at"],
                "raw_html_sha256": s["raw_html_sha256"],
            }
            for s in sources
        ],
        [
            "source_id",
            "url",
            "status",
            "http_status",
            "resolved_url",
            "redirects",
            "error",
            "retrieved_at",
            "raw_html_sha256",
        ],
    )
    write_csv(
        output / "04_ARTICLE_BODY_COMPLETENESS.csv",
        [
            {
                "source_id": s["source_id"],
                "url": s["url"],
                "type": s["taxonomy"]["page_type"],
                "title": s["title"],
                "body_status": s["body_status"],
                "article_body_assessment": s["article_body_assessment"],
                "complete_article_body": s["complete_article_body"],
                "characters": len(s["body_text"]),
                "blocks": len(s["blocks"]),
                "tables": sum(b["type"] == "table" for b in s["blocks"]),
                "headings": sum(b["type"] == "heading" for b in s["blocks"]),
                "parser_selector": s["parser_selector"],
                "errors": s["quality"]["blocking_errors"],
                "warnings": s["quality"]["warnings"],
                "data_file": "data/sources.jsonl.gz",
                "record_key": s["source_id"],
            }
            for s in sources
        ],
        [
            "source_id",
            "url",
            "type",
            "title",
            "body_status",
            "article_body_assessment",
            "complete_article_body",
            "characters",
            "blocks",
            "tables",
            "headings",
            "parser_selector",
            "errors",
            "warnings",
            "data_file",
            "record_key",
        ],
    )
    write_csv(
        output / "05_CANONICAL_GROUPS.csv",
        groups,
        [
            "canonical_id",
            "preferred_title",
            "language",
            "country_code",
            "country_codes",
            "pathway",
            "topic",
            "source_ids",
            "source_urls",
            "primary_source_id",
            "supporting_source_ids",
            "duplicate_type",
            "conflicts",
            "verification_status",
            "completeness_status",
            "review_status",
            "publication_allowed",
        ],
    )
    counts = defaultdict(
        lambda: {"source_bodies": 0, "canonical_drafts": 0, "contract_valid_drafts": 0}
    )
    for s in sources:
        if s["complete_article_body"]:
            for country in s["taxonomy"]["country_codes"]:
                counts[(country, s["taxonomy"]["pathway"])]["source_bodies"] += 1
    for g in groups:
        for country in g["country_codes"]:
            counts[(country, g["pathway"])]["canonical_drafts"] += 1
            counts[(country, g["pathway"])]["contract_valid_drafts"] += int(
                by_draft[g["canonical_id"]]["validation"]["draft_payload_valid"]
            )
    coverage = []
    observed = countries | {c for g in groups for c in g["country_codes"]}
    for country in sorted(observed):
        for pathway in PATHWAYS:
            values = counts[(country, pathway)]
            coverage.append(
                {
                    "country_code": country,
                    "pathway": pathway,
                    "in_production_destination_catalog": country in countries,
                    **values,
                    "verified_legal_claims": 0,
                    "human_approved_articles": 0,
                    "published_canonical_articles": 0,
                    "gap": "no_source_body"
                    if not values["source_bodies"]
                    else "official_verification_and_human_review_required",
                }
            )
    write_csv(output / "07_COUNTRY_PATHWAY_COVERAGE.csv", coverage, list(coverage[0]))
    destinations = {d["id"]: d for d in production["destinations"]}
    categories = {c["id"]: c for c in production["categories"]}
    structured_rows = []
    for p in production["programs"]:
        d = destinations[p["destination_id"]]
        cat = categories[p["category_id"]]
        locs = {
            localization["locale"]: localization
            for localization in p.get("localizations") or []
        }
        structured_rows.append(
            {
                "program_id": p["id"],
                "program_slug": p["slug"],
                "country": d["code"],
                "pathway": cat["slug"],
                "status": p["status"],
                "fa_title_present": bool(locs.get("fa", {}).get("title")),
                "en_title_present": bool(locs.get("en", {}).get("title")),
                "fa_description_chars": len(
                    locs.get("fa", {}).get("description") or ""
                ),
                "en_description_chars": len(
                    locs.get("en", {}).get("description") or ""
                ),
                "requirements_rows": p["requirements"],
                "steps_rows": p["steps"],
                "fees_text_present": bool(p["fees"]),
                "processing_time_text_present": bool(p["processing_time"]),
                "primary_source_id": p["primary_source_id"],
                "regulatory_verification": "not_established_by_seed_or_presence",
                "source_reference_file": "data/production_structured_baseline.json",
                "source_bodies_for_pair": counts[(d["code"], cat["slug"])][
                    "source_bodies"
                ],
                "factual_gaps": "eligibility/documents/fees/processing/steps require current competent official evidence",
            }
        )
    write_csv(
        output / "08_VISA_STRUCTURED_DATA_COMPLETENESS.csv",
        structured_rows,
        list(structured_rows[0]) if structured_rows else ["program_id"],
    )
    evidence = {
        "format_version": FORMAT_VERSION,
        "claim_verification_is_not_automated": True,
        "verified_claim_count": 0,
        "source_record_file": "data/sources.jsonl.gz",
        "canonical_record_file": "data/canonical_articles.jsonl.gz",
        "sources": [
            {
                "source_id": s["source_id"],
                "url": s["url"],
                "snapshot_id": s["snapshot_id"],
                "snapshot_state": s["snapshot_id_state"],
                "raw_html_sha256": s["raw_html_sha256"],
                "body_sha256": s["body_sha256"],
                "retrieved_at": s["retrieved_at"],
                "date_evidence": s["date_evidence"],
                "source_class": s["domain"].split(".")[0],
                "body_reference_links": s["body_links"],
                "official_verification_status": "not_verified",
                "publication_allowed": False,
            }
            for s in sources
            if s["body_text"]
        ],
        "government_reference_policy": "External reference URLs are candidates, not proof of competence, freshness or verified claims. No third-party full bodies are copied.",
    }
    write_json(output / "09_CITATION_AND_EVIDENCE_MANIFEST.json", evidence)
    queue = []
    for a in drafts:
        queue.append(
            {
                "canonical_id": a["canonical_id"],
                "title": a["title"],
                "language": a["locale"],
                "country": a["country_code"],
                "pathway": a["pathway"],
                "priority": "high"
                if a["conflicts"] or a["validation"]["blocking_errors"]
                else "normal",
                "draft_payload_valid": a["validation"]["draft_payload_valid"],
                "blocking_errors": a["validation"]["blocking_errors"],
                "warnings": a["validation"]["warnings"],
                "editorial_blockers": a["editorial_blockers"],
                "review_status": a["review_status"],
                "assigned_reviewer": None,
                "approved_at": None,
                "publication_allowed": False,
                "source_urls": a["source_urls"],
            }
        )
    write_csv(
        output / "17_EDITORIAL_REVIEW_QUEUE.csv",
        queue,
        list(queue[0]) if queue else ["canonical_id"],
    )
    metrics = {
        "format_version": FORMAT_VERSION,
        "client_task_date": "2026-10-24",
        "compression": COMPRESSION,
        "discovered_urls": len(sources),
        "fetch_states": dict(Counter(s["fetch_status"] for s in sources)),
        "successfully_retrieved_pages": sum(
            s["fetch_status"] == "fetched" for s in sources
        ),
        "complete_article_bodies": sum(s["complete_article_body"] for s in sources),
        "body_status_counts": dict(Counter(s["body_status"] for s in sources)),
        "article_body_assessments": dict(
            Counter(s["article_body_assessment"] for s in sources)
        ),
        "canonical_drafts": len(groups),
        "structurally_valid_draft_payloads": validation["valid_draft_payloads"],
        "exact_duplicate_groups": sum(len(g["source_ids"]) > 1 for g in groups),
        "near_or_conflict_candidates": len(relationships),
        "existing_source_ids_preserved": sum(
            s["id_origin"] == "existing_production_document" for s in sources
        ),
        "verified_claims": 0,
        "human_approved_articles": 0,
        "publication_ready_articles": 0,
        "published_articles_by_this_task": 0,
        "historical_812_count_verified": False,
        "historical_10_canonical_count_verified": False,
        "production_baseline_counts": production["counts"],
        "production_canonical_cms_tables_present": all(
            schema_gate["canonical_tables"].values()
        )
        if schema_gate
        else None,
        "capture_file": "data/capture.jsonl.gz",
        "capture_sha256": digest_bytes((data_dir / "capture.jsonl.gz").read_bytes()),
        "pipeline_file_sha256": {
            p.relative_to(Path(__file__).resolve().parents[2]).as_posix(): digest_bytes(
                p.read_bytes()
            )
            for p in sorted(Path(__file__).parent.glob("*.py"))
        },
        "source_counts_by_domain": dict(Counter(s["domain"] for s in sources)),
        "validation": validation,
    }
    write_json(output / "PLAN3_MANIFEST.json", metrics)
    from .reports import write_reports

    write_reports(output, metrics, relationships, drafts)
    seal(output)
    return metrics


def seal(output):
    files = sorted(
        (p for p in output.rglob("*") if p.is_file() and p.name != "CHECKSUMS.sha256"),
        key=lambda path: path.relative_to(output).as_posix(),
    )
    (output / "CHECKSUMS.sha256").write_text(
        "".join(
            hashlib.sha256(p.read_bytes()).hexdigest()
            + "  "
            + p.relative_to(output).as_posix()
            + "\n"
            for p in files
        ),
        encoding="utf8",
        newline="\n",
    )


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--collected", type=Path, required=True)
    p.add_argument("--production-metadata", type=Path, required=True)
    p.add_argument("--structured-metadata", type=Path, required=True)
    p.add_argument("--discovery", type=Path, required=True)
    p.add_argument("--cache", type=Path)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument(
        "--registry", type=Path, default=Path("supabase/contracts/rad_v1.json")
    )
    p.add_argument("--schema-gate", type=Path, required=True)
    a = p.parse_args()
    result = build(
        read_jsonl(a.collected),
        json.loads(a.production_metadata.read_text(encoding="utf8")),
        json.loads(a.structured_metadata.read_text(encoding="utf8")),
        json.loads(a.discovery.read_text(encoding="utf8")),
        a.output,
        a.registry,
        a.cache,
        json.loads(a.schema_gate.read_text(encoding="utf8")),
    )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
