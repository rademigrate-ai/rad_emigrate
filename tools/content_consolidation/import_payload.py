"""Deterministic bounded CMS projection; rich original structure stays pinned.

This module has no hosted credentials or execution. It never publishes.
"""

import copy

from tools.plan3_content.dataset import flat_items, schema_validator, split_text, uid
from tools.plan3_content.parser import digest


def payload(article, sources, registry):
    article = copy.deepcopy(article)
    blocks = []
    for section in article["sections"]:
        for rich in section["blocks"]:
            original = rich["original_structure"]
            typ = original["type"]
            # Closed v1 projection remains searchable/readable. The additive
            # reader uses revision-pinned rich structure, including tables.
            if typ in ("bullet_list", "numbered_list"):
                items = flat_items(original["items"])
                if len(items) <= 100 and all(len(x) <= 2000 for x in items):
                    values = [{"type": typ, "text": "", "items": items}]
                else:
                    values = [
                        {"type": "paragraph", "text": p, "items": []}
                        for p in split_text(original["text"])
                    ]
            else:
                values = [
                    {
                        "type": typ
                        if typ in ("heading", "paragraph", "callout")
                        else "callout",
                        "text": p,
                        "items": [],
                    }
                    for p in split_text(original["text"])
                ]
            for i, value in enumerate(values):
                blocks.append(
                    (
                        {**value, "id": uid(rich["id"] + ":v1:" + str(i))},
                        rich.get("selected_origin", rich["provenance"][0]),
                        rich["id"],
                    )
                )
    sections = []
    projection_map = []
    current = None
    for value, ref, rich_id in blocks:
        # At most 100 distinct evidence refs per section, and 200 blocks.
        if current is None or len(current["blocks"]) >= 100:
            index = len(sections)
            current = {
                "id": uid(article["article_id"] + ":projection:" + str(index)),
                "anchor": f"content-{index + 1}",
                "heading": article["title"],
                "order": index,
                "blocks": [],
                "evidence_refs": [],
            }
            sections.append(current)
            projection_map.append(
                {
                    "anchor": current["anchor"],
                    "section_id": current["id"],
                    "first_rich_block_id": rich_id,
                }
            )
        current["blocks"].append(value)
        source = sources[ref["source_id"]]
        excerpt = source["body_text"][ref["start"] : ref["end"]][:4000]
        evidence = {
            "snapshot_id": ref["snapshot_id"],
            "claim_id": None,
            "excerpt": excerpt,
            "locator": f"source-block:{ref['block_index']}:{ref['start']}:{ref['end']}",
        }
        if evidence not in current["evidence_refs"]:
            current["evidence_refs"].append(evidence)
    article["projection_map"] = projection_map
    request = {
        "article_id": article["article_id"],
        "locale": article["locale"],
        "expected_revision": 0,
        "title": article["title"],
        "summary": "",
        "sections": sections,
        "related_article_ids": [],
        "merge_manifest_id": None,
        "request_key": uid(
            "editorial-import:" + article["article_id"] + ":" + digest(article)
        ),
    }
    errors = sorted(
        schema_validator(registry, "save_visa_article_draft_request").iter_errors(
            request
        ),
        key=lambda e: str(e.path),
    )
    if errors:
        return {
            "article_id": article["article_id"],
            "status": "blocked_contract",
            "errors": [{"path": list(e.path), "message": e.message} for e in errors],
        }
    article["draft_request"] = request
    used = []
    for source_id in article["source_ids"]:
        s = sources[source_id]
        used.append(
            {
                **{
                    k: s[k]
                    for k in (
                        "source_id",
                        "snapshot_id",
                        "url",
                        "title",
                        "language",
                        "retrieved_at",
                        "body_text",
                        "body_sha256",
                        "raw_html_sha256",
                    )
                },
                "content_source_id": uid("content-source:" + s["url"]),
            }
        )
    return {
        "article_id": article["article_id"],
        "status": "technical_draft_only",
        "item": article,
        "sources": used,
    }
