"""Loss-accounted continuous bodies with immutable source segment identities."""

import copy
from collections import defaultdict

from tools.plan3_content.dataset import uid
from tools.plan3_content.parser import digest, search_normalize, text
from tools.plan3_content.taxonomy import COUNTRIES

from .mapping import LABELS, relevant_segments, source_mapping


def compose(members, identity, title, countries, route=None, selections=None):
    domains = {s["domain"] for s in members}
    if "radmohajer.ir" in domains and len(domains) > 1:
        raise ValueError("supplementary_source_must_remain_standalone")
    sections, groups, seen, omissions, claims, ledger = [], {}, {}, [], [], []
    numeric = defaultdict(lambda: defaultdict(set))
    for source in sorted(members, key=lambda s: (s["domain"], s["url"])):
        mapping = source_mapping(source)
        program = mapping["program"] if route else "independent"
        selected = (
            set(selections[source["source_id"]])
            if selections
            else set(range(len(source["blocks"])))
        )
        heading, offset, active = title, 0, None
        for index, block in enumerate(source["blocks"]):
            value = block["text"]
            start = source["body_text"].find(value, offset)
            if start < 0:
                raise ValueError("unbound_source_block")
            offset = start + len(value)
            ref = {
                "source_id": source["source_id"],
                "snapshot_id": source["snapshot_id"],
                "url": source["url"],
                "block_index": index,
                "start": start,
                "end": offset,
                "sha256": digest(value),
                "structure_sha256": digest(block),
            }
            if index not in selected:
                continue
            if block["type"] == "heading":
                heading, active = value, None
            group_key = (program, text(heading))
            if group_key not in groups:
                active = {
                    "id": uid(identity + ":section:" + digest(group_key)),
                    "heading": heading,
                    "program": program,
                    "blocks": [],
                }
                groups[group_key] = active
                sections.append(active)
            else:
                active = groups[group_key]
            # Structural equality is required: identical flattened table/list
            # text does not prove equivalent structure or legal scope.
            fingerprint = (program, digest(block))
            if fingerprint in seen:
                target = seen[fingerprint]
                target["provenance"].append(ref)
                row = {
                    "reason": "exact_structure_and_text_repetition",
                    "provenance": ref,
                    "represented_block_id": target["id"],
                }
                omissions.append(row)
                ledger.append(
                    {
                        **ref,
                        "destination_article_id": identity,
                        "status": "exact_duplicate_represented",
                        "represented_block_id": target["id"],
                    }
                )
                continue
            item = {
                "id": uid(
                    identity + ":block:" + source["source_id"] + ":" + str(index)
                ),
                "type": block["type"],
                "text": value,
                "original_structure": copy.deepcopy(block),
                "provenance": [ref],
            }
            active["blocks"].append(item)
            seen[fingerprint] = item
            ledger.append(
                {
                    **ref,
                    "destination_article_id": identity,
                    "status": "preserved",
                    "represented_block_id": item["id"],
                }
            )
            if block["type"] != "heading":
                numbers = __import__("re").findall(
                    r"\d+(?:[.,]\d+)?", search_normalize(value)
                )
                promise = bool(__import__("re").search(r"تضمین|قطعی|100\s*%", value))
                claims.append(
                    {
                        "block_id": item["id"],
                        "verification_status": "not_verified",
                        "official_references": [],
                        "verified_at": None,
                        "review_reason": "unsupported_outcome_promise_preserved_for_review"
                        if promise
                        else "source_claim_requires_official_and_human_review",
                        "provenance": ref,
                    }
                )
                numeric[group_key][source["source_id"]].update(numbers)
    # Remove heading-only groups only if all their blocks were represented
    # elsewhere. No source heading or trailing heading is silently discarded.
    sections = [s for s in sections if s["blocks"]]
    conflicts = [
        {
            "type": "numeric_disagreement_candidate_not_adjudicated",
            "program": key[0],
            "heading": key[1],
            "source_values": {k: sorted(v) for k, v in values.items()},
            "resolution": "official_verification_and_human_review_required",
        }
        for key, values in numeric.items()
        if len(values) > 1 and len({tuple(sorted(v)) for v in values.values()}) > 1
    ]
    return {
        "article_id": identity,
        "title": title,
        "locale": members[0]["language"],
        "country_codes": countries,
        "pathway": route or "general",
        "visa_category": route,
        "category": "migration" if route else "general-guide",
        "content_class": "canonical" if route else "editorial",
        "source_ids": sorted(s["source_id"] for s in members),
        "source_urls": sorted(s["url"] for s in members),
        "source_publishers": sorted(domains),
        "sections": sections,
        "omissions": omissions,
        "claims": claims,
        "conflicts": conflicts,
        "segment_ledger": ledger,
        "editorial_state": "draft",
        "verification_state": "unverified",
        "reviewer_id": None,
        "published": False,
        "publication_allowed": False,
        "composition_review": "country_category_program_proposal_requires_human_review"
        if route
        else "independent_editorial_review_required",
        "english_translation": "original_english_source_only"
        if members[0]["language"] == "en"
        else "not_available",
    }


def compose_library(sources, title_key, topic_key):
    main, independent, mappings = defaultdict(list), defaultdict(list), []
    for source in sources:
        if (
            source.get("consolidation_disposition")
            != "body_ready_for_unreviewed_composition"
        ):
            continue
        mapping = source_mapping(source)
        indices = relevant_segments(source, mapping)
        mappings.append(
            {
                "source_id": source["source_id"],
                "url": source["url"],
                **mapping,
                "selected_main_block_indices": indices,
            }
        )
        if indices:
            key = (
                source["language"],
                mapping["country_codes"][0],
                mapping["visa_category"],
            )
            main[key].append((source, indices))
        if mapping["independent"]:
            # Radmohajer never merges with primary material. Multi-country
            # associations share ONE independent article identity.
            namespace = (
                "supplementary"
                if source["domain"] == "radmohajer.ir"
                else "primary-independent"
            )
            independent[
                (namespace, topic_key(source), digest(source["body_text"]))
            ].append(source)
    articles = []
    for (locale, country, route), contributions in sorted(main.items()):
        name = COUNTRIES[country][0] if locale == "fa" else COUNTRIES[country][-1]
        title = f"{LABELS[route][0 if locale == 'fa' else 1]} — {name}"
        identity = uid(f"rad-country-category-v3:{country}:{route}")
        articles.append(
            compose(
                [s for s, _ in contributions],
                identity,
                title,
                [country],
                route,
                {s["source_id"]: indices for s, indices in contributions},
            )
        )
    for (namespace, key, body_hash), members in sorted(
        independent.items(), key=lambda item: str(item[0])
    ):
        first = sorted(members, key=lambda s: s["url"])[0]
        identity = uid(
            "rad-independent-v3:" + namespace + ":" + digest((key, body_hash))
        )
        articles.append(
            compose(
                members, identity, first["title"], first["taxonomy"]["country_codes"]
            )
        )
    relations, countries = [], []
    for a in articles:
        if a["content_class"] != "editorial":
            continue
        for country in a["country_codes"]:
            countries.append(
                {
                    "country_code": country,
                    "article_id": a["article_id"],
                    "locale": a["locale"],
                    "state": "proposed",
                    "basis": "explicit_source_title_or_url_country",
                    "reviewer_id": None,
                }
            )
        for parent in articles:
            if (
                parent["content_class"] == "canonical"
                and parent["locale"] == a["locale"]
                and set(parent["country_codes"]) & set(a["country_codes"])
            ):
                relations.append(
                    {
                        "parent_id": parent["article_id"],
                        "related_id": a["article_id"],
                        "country_overlap": sorted(
                            set(parent["country_codes"]) & set(a["country_codes"])
                        ),
                        "relevance_basis": "country_level_supplementary_proposal_requires_human_review",
                        "rank": 0,
                        "state": "proposed",
                        "reviewer_id": None,
                    }
                )
    return articles, mappings, relations, countries
