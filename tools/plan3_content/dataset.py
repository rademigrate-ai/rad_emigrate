"""Deterministic canonicalization and loss-aware, unapproved CMS draft payloads."""

from __future__ import annotations

import gzip
import json
import re
import uuid
from collections import defaultdict
from difflib import SequenceMatcher
from pathlib import Path
from urllib.parse import urlsplit

from jsonschema import Draft202012Validator, FormatChecker

from .crawl import NAMESPACE, stable_id
from .parser import digest, extract, normalize_url, search_normalize
from .taxonomy import classify

FORMAT_VERSION = "rad-plan3-1"


def uid(value: str) -> str:
    return str(uuid.uuid5(NAMESPACE, value))


def read_jsonl(path: Path):
    with gzip.open(path, "rt", encoding="utf8") as f:
        return [json.loads(line) for line in f if line.strip()]


def write_jsonl(path: Path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with (
        path.open("wb") as raw,
        gzip.GzipFile(filename="", fileobj=raw, mode="wb", mtime=0) as f,
    ):
        for row in rows:
            f.write(
                (
                    json.dumps(
                        row, ensure_ascii=False, sort_keys=True, separators=(",", ":")
                    )
                    + "\n"
                ).encode("utf8")
            )


def schema_validator(registry: dict, name: str):
    return Draft202012Validator(
        {"$defs": registry["$defs"], "$ref": "#/$defs/" + name},
        format_checker=FormatChecker(),
    )


def source_records(collected, production, cache=None):
    existing = {normalize_url(s["url"]): s for s in production.get("sources", [])}
    records = []
    for fetched in sorted(collected, key=lambda x: x["url"]):
        url = normalize_url(fetched["url"])
        old = existing.get(url)
        parsed = fetched.get("extraction", {})
        if cache is not None and fetched.get("fetch_status") == "fetched":
            raw = cache / (stable_id(url) + ".html.gz")
            if raw.exists():
                html = gzip.decompress(raw.read_bytes())
                if digest_bytes(html) != fetched["raw_sha256"]:
                    raise ValueError("raw_cache_hash_mismatch")
                parsed = extract(html, fetched.get("final_url", url))
        title = parsed.get("title") or (old or {}).get("title") or ""
        body = parsed.get("body_text", "")
        body_hash = digest(body) if body else None
        source_id = (old or {}).get("id") or stable_id(url)
        taxonomy = classify(title, url)
        blocks = parsed.get("blocks", [])
        row = {
            "source_id": source_id,
            "collector_id": fetched["id"],
            "id_origin": "existing_production_document"
            if old
            else "proposed_deterministic_document",
            "url": url,
            "domain": urlsplit(url).hostname,
            "title": title,
            "language": parsed.get("language"),
            "taxonomy": taxonomy,
            "discovered_via": fetched.get("discovered_via", []),
            "fetch_status": fetched["fetch_status"],
            "http_status": fetched.get("status"),
            "resolved_url": fetched.get("final_url"),
            "redirects": fetched.get("redirects", []),
            "fetch_error": fetched.get("error"),
            "retrieved_at": fetched.get("retrieved_at"),
            "raw_html_sha256": fetched.get("raw_sha256"),
            "body_status": parsed.get("body_status", "not_extracted"),
            "source_container_text_chars": parsed.get("source_container_text_chars", 0),
            "body_text": body,
            "blocks": blocks,
            "body_sha256": body_hash,
            "normalized_body_sha256": digest(search_normalize(body)) if body else None,
            "snapshot_id": uid("snapshot:" + source_id + ":" + body_hash)
            if body_hash
            else None,
            "snapshot_id_state": "proposed_not_hosted"
            if body_hash
            else "not_available",
            "declared_canonical_url": parsed.get("canonical_url"),
            "date_evidence": parsed.get("dates", []),
            "http_last_modified": fetched.get("last_modified_header"),
            "body_links": parsed.get("body_links", []),
            "parser_selector": parsed.get("selector"),
            "parser_warnings": parsed.get("warnings", []),
            "classification_status": "inferred_requires_human_review",
            "source_confidence": "first_party_RAD_content_not_government_verification",
            "official_verification_status": "not_verified",
            "human_review_status": "not_reviewed",
            "publication_allowed": False,
            "reuse_authorization": "project_owner_Plan3_request_for_first_party_RAD_internal_draft_review",
            "reuse_review_required_before_publication": True,
            "historical_source_evidence": {
                "existing_document": old,
                "inventory_812_membership": "unknown_missing_original_inventory",
            },
        }
        soft_404 = search_normalize(title) in {
            "صفحه مورد نظر یافت نشد",
            "صفحه یافت نشد",
            "page not found",
            "404 page not found",
            "404 not found",
            "404",
        }
        row["article_body_assessment"] = (
            "soft_404_not_an_article"
            if soft_404
            else "body_unavailable"
            if not body
            else "thin_or_metadata_only_body"
            if len(body) < 300
            else "complete_substantive_source_container"
            if row["body_status"] == "complete_source_container"
            else "incomplete_or_unavailable_body"
        )
        row["complete_article_body"] = (
            row["body_status"] == "complete_source_container"
            and taxonomy["page_type"] in ("article", "news")
            and len(body) >= 300
            and not soft_404
        )
        records.append(row)
    return records


def digest_bytes(value):
    import hashlib

    return hashlib.sha256(value).hexdigest()


def registry_sha256(path):
    """Attest contract text independently of Git's Windows CRLF checkout."""
    return digest_bytes(path.read_bytes().replace(b"\r\n", b"\n"))


def canonicalize(sources, previous=None):
    """Auto-collapse exact bodies only; near matches remain separate review candidates."""
    previous = previous or {}
    buckets = defaultdict(list)
    for s in sources:
        if s["complete_article_body"]:
            t = s["taxonomy"]
            buckets[
                (
                    tuple(t["country_codes"]),
                    t["pathway"],
                    s["language"],
                    s["body_sha256"],
                )
            ].append(s)
    groups = []
    for _key, members in sorted(buckets.items(), key=lambda x: str(x[0])):
        ids = sorted(s["source_id"] for s in members)
        prior_ids = {previous[x] for x in ids if x in previous}
        # Never silently combine two previously distinct canonical identities.
        if len(prior_ids) > 1:
            by_prior = defaultdict(list)
            for s in members:
                by_prior[
                    previous.get(s["source_id"], uid("article:" + s["source_id"]))
                ].append(s)
            partitions = list(by_prior.values())
        else:
            partitions = [members]
        for part in partitions:
            part_ids = sorted(s["source_id"] for s in part)
            known = {previous[i] for i in part_ids if i in previous}
            group_id = next(iter(known)) if known else uid("article:" + part_ids[0])
            primary = min(
                part,
                key=lambda s: (
                    {"radvisa.com": 0, "digivisa.ir": 1, "radmohajer.ir": 2}[
                        s["domain"]
                    ],
                    s["url"],
                ),
            )
            groups.append(
                {
                    "canonical_id": group_id,
                    "source_ids": part_ids,
                    "source_urls": sorted(s["url"] for s in part),
                    "primary_source_id": primary["source_id"],
                    "preferred_title": primary["title"],
                    "language": primary["language"],
                    "country_codes": primary["taxonomy"]["country_codes"],
                    "country_code": primary["taxonomy"]["country_code"],
                    "pathway": primary["taxonomy"]["pathway"],
                    "topic": primary["taxonomy"]["topic"],
                    "duplicate_type": "exact_body" if len(part) > 1 else "independent",
                    "body_sha256": primary["body_sha256"],
                    "verification_status": "not_verified",
                    "completeness_status": "complete_source_body_not_editorial_approval",
                    "review_status": "not_reviewed",
                    "publication_allowed": False,
                    "conflicts": [],
                    "supporting_source_ids": sorted(
                        s["source_id"] for s in part if s is not primary
                    ),
                    "prior_canonical_collision": len(prior_ids) > 1,
                }
            )
    groups.sort(key=lambda g: g["canonical_id"])
    by_source = {s["source_id"]: s for s in sources}
    near = []
    topic_buckets = defaultdict(list)
    for g in groups:
        topic_buckets[(tuple(g["country_codes"]), g["pathway"], g["language"])].append(
            g
        )
    for candidates in topic_buckets.values():
        for i, a in enumerate(candidates):
            for b in candidates[i + 1 :]:
                title_score = SequenceMatcher(
                    None,
                    search_normalize(a["preferred_title"]),
                    search_normalize(b["preferred_title"]),
                    autojunk=False,
                ).ratio()
                if title_score < 0.87:
                    continue
                sa, sb = (
                    by_source[a["primary_source_id"]],
                    by_source[b["primary_source_id"]],
                )
                ta, tb = (
                    set(search_normalize(sa["body_text"]).split()),
                    set(search_normalize(sb["body_text"]).split()),
                )
                score = len(ta & tb) / max(1, len(ta | tb))

                def nums(value):
                    return set(re.findall(r"\d+(?:[.,/]\d+)*", search_normalize(value)))

                na, nb = nums(sa["body_text"]), nums(sb["body_text"])
                kind = (
                    "potential_numeric_or_date_conflict"
                    if na != nb and na and nb
                    else "same_topic_or_updated_version_candidate"
                )
                entry = {
                    "canonical_ids": [a["canonical_id"], b["canonical_id"]],
                    "relationship": kind,
                    "title_similarity": round(title_score, 4),
                    "token_jaccard": round(score, 4),
                    "only_left_numeric_tokens": sorted(na - nb)[:50],
                    "only_right_numeric_tokens": sorted(nb - na)[:50],
                    "resolution": "human_review_required_do_not_merge",
                    "verified_contradiction": False,
                }
                near.append(entry)
                for g in [a, b]:
                    g["conflicts"].append(
                        {
                            "other_canonical_id": b["canonical_id"]
                            if g is a
                            else a["canonical_id"],
                            "relationship": kind,
                            "verified_contradiction": False,
                        }
                    )
    return groups, near


def split_text(value, limit=11000):
    parts = []
    while len(value) > limit:
        cut = value.rfind(" ", 0, limit + 1)
        if cut < 1:
            cut = limit
        parts.append(value[:cut])
        value = value[cut:].lstrip()
    if value:
        parts.append(value)
    return parts


def flat_items(items, depth=0):
    result = []
    for item in items:
        result.append(("  " * depth) + item["text"])
        for child in item.get("children", []):
            result.extend(flat_items(child["items"], depth + 1))
    return result


def cms_payload(group, source, registry, catalog_countries=None):
    errors = []
    warnings = []
    article_id = group["canonical_id"]
    sections = []
    if not group["country_code"]:
        errors.append("country_requires_human_resolution")
    elif (
        catalog_countries is not None and group["country_code"] not in catalog_countries
    ):
        errors.append("destination_not_in_authoritative_catalog")
    if source["language"] not in ("fa", "en"):
        errors.append("language_not_supported")
    if not source["title"] or len(source["title"]) > 300:
        errors.append("title_contract_length")
    if len(source["body_text"]) < 300:
        errors.append("thin_source_body_requires_editorial_review")
    if source["taxonomy"]["page_type"] not in ("article", "news"):
        errors.append("not_article_page")
    if source["body_status"] != "complete_source_container":
        errors.append("body_not_complete")
    if source["taxonomy"]["multiple_pathways_detected"]:
        warnings.append("multiple_pathways_require_review")
    if group["conflicts"]:
        warnings.append("potential_conflict_requires_review_no_merge")
    current = None
    source_cursor = 0

    def new_section(heading):
        nonlocal current
        index = len(sections)
        sid = uid(
            article_id + ":section:" + str(index) + ":" + search_normalize(heading)
        )
        current = {
            "id": sid,
            "anchor": "section-" + str(index + 1),
            "heading": heading,
            "order": index,
            "blocks": [],
            "evidence_refs": [],
            "_start": None,
            "_end": None,
        }
        if not heading or len(heading) > 200:
            errors.append("section_heading_contract_length")
        sections.append(current)

    for position, b in enumerate(source["blocks"]):
        block_start = source["body_text"].find(b["text"], source_cursor)
        if block_start < 0:
            errors.append("source_block_locator_missing")
            block_start = source_cursor
        block_end = block_start + len(b["text"])
        source_cursor = block_end
        if current is None:
            new_section(source["title"])
        if b["type"] == "heading" and current["blocks"]:
            new_section(b["text"])
        if b["type"] in ("bullet_list", "numbered_list"):
            items = flat_items(b["items"])
            if any(i["children"] for i in b["items"]):
                warnings.append(
                    "nested_list_hierarchy_preserved_in_source_flattened_in_CMS_v1"
                )
            if any(len(t) > 2000 for t in items):
                warnings.append("long_list_rendered_as_source_text")
                blocks = [
                    {"type": "paragraph", "text": p, "items": []}
                    for p in split_text(b["text"])
                ]
            else:
                blocks = [
                    {"type": b["type"], "text": "", "items": items[i : i + 100]}
                    for i in range(0, len(items), 100)
                ]
        elif b["type"] == "table":
            warnings.append(
                "native_table_unsupported_plain_text_CMS_v1_original_table_preserved"
            )
            table = "\n".join(
                " | ".join(c["text"].replace("|", "\\|") for c in row)
                for row in b["rows"]
            )
            if b.get("caption"):
                table = b["caption"] + "\n" + table
            blocks = [
                {"type": "callout", "text": p, "items": []} for p in split_text(table)
            ]
        else:
            blocks = [
                {
                    "type": b["type"]
                    if b["type"] in ("heading", "paragraph")
                    else "paragraph",
                    "text": p,
                    "items": [],
                }
                for p in split_text(b["text"])
            ]
        for j, block in enumerate(blocks):
            if len(current["blocks"]) >= 200:
                new_section(current["heading"])
            if current["_start"] is None:
                current["_start"] = block_start
            current["_end"] = block_end
            current["blocks"].append(
                {
                    "id": uid(
                        article_id
                        + ":block:"
                        + str(position)
                        + ":"
                        + str(j)
                        + ":"
                        + digest(block)
                    ),
                    **block,
                }
            )
    for section in sections:
        start, end = section.pop("_start"), section.pop("_end")
        if start is None or end is None:
            errors.append("section_has_no_source_locator")
            continue
        section["evidence_refs"] = [
            {
                "snapshot_id": source["snapshot_id"],
                "claim_id": None,
                "excerpt": source["body_text"][start : min(end, start + 4000)],
                "locator": f"{source['parser_selector']};chars={start}:{end}",
            }
        ]
    if len(sections) > 100:
        errors.append("section_count_contract_limit")
    if not sections:
        errors.append("empty_sections")
    create = {
        "article_id": article_id,
        "kind": "related",
        "country_code": group["country_code"] or "",
        "pathway_slug": group["pathway"],
        "slug": "rad-article-" + article_id,
        "request_key": uid("create:" + article_id),
    }
    save = {
        "article_id": article_id,
        "locale": source["language"] or "",
        "expected_revision": 0,
        "title": source["title"],
        "summary": source["body_text"][:1500],
        "sections": sections,
        "related_article_ids": [],
        "merge_manifest_id": None,
        "request_key": uid("draft:" + article_id + ":" + source["body_sha256"]),
    }
    for name, payload in [
        ("create_visa_article_request", create),
        ("save_visa_article_draft_request", save),
    ]:
        errors.extend(
            name + ":" + ("/".join(str(p) for p in e.path) or "$") + ":" + e.validator
            for e in schema_validator(registry, name).iter_errors(payload)
        )
    # Numeric/date mentions stay unverified: technical validity never clears editorial gates.
    mentions = sorted(
        set(re.findall(r"\d+(?:[.,/]\d+)*", search_normalize(source["body_text"])))
    )
    if mentions:
        warnings.append("amounts_dates_require_official_verification")
    save["request_key"] = uid(
        "draft:"
        + article_id
        + ":"
        + digest({k: v for k, v in save.items() if k != "request_key"})
    )
    content_version = digest(
        {"create_visa_article": create, "save_visa_article_draft": save}
    )
    return {
        "canonical_id": article_id,
        "title": source["title"],
        "locale": source["language"],
        "country_code": group["country_code"],
        "country_codes": group["country_codes"],
        "pathway": group["pathway"],
        "category": group["topic"],
        "summary": save["summary"],
        "body_sha256": source["body_sha256"],
        "payload_sha256": content_version,
        "source_ids": group["source_ids"],
        "primary_source_id": source["source_id"],
        "source_snapshot_id": source["snapshot_id"],
        "retrieved_at": source["retrieved_at"],
        "source_urls": group["source_urls"],
        "review_status": "draft_not_reviewed",
        "approval_identity": None,
        "approved_at": None,
        "verification_status": "unverified",
        "publication_allowed": False,
        "conflicts": group["conflicts"],
        "validation": {
            "blocking_errors": sorted(set(errors)),
            "warnings": sorted(set(warnings)),
            "draft_payload_valid": not errors,
            "editorial_ready": False,
            "publication_eligible": False,
        },
        "editorial_blockers": [
            "human_review_required",
            "official_claim_verification_required",
            "reuse_and_attribution_review_required",
        ],
        "numeric_date_mentions_unverified": mentions,
        "wire": {"create_visa_article": create, "save_visa_article_draft": save},
    }


def validate_package(package_path: Path, registry_path: Path):
    package = json.loads(package_path.read_text(encoding="utf8"))
    root = package_path.parent
    if (
        package.get("publication_allowed") is not False
        or package.get("production_import_enabled") is not False
    ):
        raise ValueError("draft_only_gate")
    if package.get("approved_by") is not None or package.get("approved_at") is not None:
        raise ValueError("unsafe_package_approval")
    registry = json.loads(registry_path.read_text(encoding="utf8"))
    if (
        package.get("cms_registry_sha256")
        and registry_sha256(registry_path) != package["cms_registry_sha256"]
    ):
        raise ValueError("cms_contract_drift_requires_review")
    if "canonical_file" in package:
        canonical_path = (root / package["canonical_file"]).resolve()
        if not canonical_path.is_relative_to(root.resolve()):
            raise ValueError("canonical_path_escape")
        if (
            digest_bytes(canonical_path.read_bytes())
            != package["canonical_file_sha256"]
        ):
            raise ValueError("canonical_file_hash")
    path = (root / package["payload_file"]).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("payload_path_escape")
    if digest_bytes(path.read_bytes()) != package["payload_file_sha256"]:
        raise ValueError("payload_file_hash")
    payloads = read_jsonl(path)
    by_id = {a["canonical_id"]: a for a in payloads}
    if len(by_id) != len(payloads):
        raise ValueError("duplicate_canonical_id")
    entries = {a["canonical_id"]: a for a in package["articles"]}
    if len(entries) != len(package["articles"]):
        raise ValueError("duplicate_index_id")
    if set(entries) != set(by_id):
        raise ValueError("index_payload_mismatch")
    for aid, a in by_id.items():
        if (
            a.get("publication_allowed") is not False
            or a.get("approved_at") is not None
            or a.get("approval_identity") is not None
            or a.get("review_status") != "draft_not_reviewed"
        ):
            raise ValueError("unsafe_editorial_state")
        if set(a["wire"]) != {"create_visa_article", "save_visa_article_draft"}:
            raise ValueError("endpoint_allowlist")
        if (
            digest(a["wire"]) != a["payload_sha256"]
            or entries[aid]["payload_sha256"] != a["payload_sha256"]
        ):
            raise ValueError("payload_integrity")
        valid = True
        for name, req in [
            ("create_visa_article_request", a["wire"]["create_visa_article"]),
            ("save_visa_article_draft_request", a["wire"]["save_visa_article_draft"]),
        ]:
            if list(schema_validator(registry, name).iter_errors(req)):
                valid = False
        if a["validation"]["draft_payload_valid"] and (
            not valid or a["validation"]["blocking_errors"]
        ):
            raise ValueError("validation_flag_mismatch")
        if a["wire"]["save_visa_article_draft"]["expected_revision"] != 0:
            raise ValueError("non_destructive_initial_revision_only")
    return {
        "articles": len(payloads),
        "valid_draft_payloads": sum(
            a["validation"]["draft_payload_valid"] for a in payloads
        ),
        "publication_ready": 0,
        "production_import_enabled": False,
    }
