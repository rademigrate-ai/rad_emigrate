"""Loss-accounted continuous bodies with immutable source segment identities."""

import copy
from collections import defaultdict

from tools.content_completion.country_labels import COUNTRIES
from tools.plan3_content.dataset import uid
from tools.plan3_content.parser import digest, search_normalize, text

from .mapping import LABELS, relevant_segments, source_mapping
from .precedence_v4 import (
    VERSION,
    candidate_key,
    classify_passage,
    equivalence,
    initial_heading,
    preferred_publisher,
    scope_key,
    semantic_signature,
    title_context,
)


def source_heading_level(block, evidence):
    original = block.get("level")
    if type(original) is int and 1 <= original <= 6:
        return original
    raw = (
        evidence.get("level")
        if evidence and evidence.get("confirmed") is True
        else None
    )
    return raw if type(raw) is int and 1 <= raw <= 6 else None


def compose(members, identity, title, countries, route=None, selections=None):
    domains = {s["domain"] for s in members}
    if "radmohajer.ir" in domains and len(domains) > 1:
        raise ValueError("supplementary_source_must_remain_standalone")
    sections, groups, seen, omissions, claims, ledger = [], {}, {}, [], [], []
    numeric = defaultdict(lambda: defaultdict(set))
    variants = defaultdict(set)
    source_variants = {(s["source_id"], s["snapshot_id"]): s for s in members}
    heading_evidence = {
        key: {
            row["block_index"]: row for row in s.get("heading_structure_evidence", [])
        }
        for key, s in source_variants.items()
    }
    for member in members:
        variants[member["source_id"]].add(member["snapshot_id"])
    for source in sorted(
        members,
        key=lambda s: (
            s["domain"],
            s["url"],
            s.get("retrieved_at") or "",
            s["snapshot_id"],
        ),
    ):
        mapping = source_mapping(source)
        program = mapping["program"] if route else "independent"
        selected = (
            set(
                selections.get(
                    (source["source_id"], source["snapshot_id"]),
                    selections.get(source["source_id"], []),
                )
            )
            if selections
            else set(range(len(source["blocks"])))
        )
        heading, offset, active = initial_heading(source, title), 0, None
        heading_stack, heading_path = [], ()
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
                "publisher": source["domain"],
                "source_title": source["title"],
                "block_index": index,
                "start": start,
                "end": offset,
                "sha256": digest(value),
                "structure_sha256": digest(block),
            }
            if block["type"] == "heading":
                heading, active = value, None
                evidence = heading_evidence[
                    (source["source_id"], source["snapshot_id"])
                ].get(index)
                level = source_heading_level(block, evidence)
                if level is None:
                    heading_stack = [
                        (
                            None,
                            value,
                            (source["source_id"], source["snapshot_id"], index),
                        )
                    ]
                else:
                    if level == 1:
                        heading_stack = []
                    while (
                        heading_stack
                        and heading_stack[-1][0] is not None
                        and heading_stack[-1][0] >= level
                    ):
                        heading_stack.pop()
                    heading_stack.append((level, value, None))
                heading_path = tuple(
                    (level, semantic_signature(label)[0], uncertain)
                    for level, label, uncertain in heading_stack
                )
            # Unselected headings still define the scope of later selected
            # descendants. Dropping that context can merge distinct sources.
            if index not in selected:
                continue
            context_title = (
                source["title"]
                if title_context(source)[0] == "specific_source_title"
                and source["title"] != title
                else None
            )
            displayed_heading = (
                f"{context_title} — {heading}"
                if context_title and context_title != heading
                else heading
            )
            group_key = (program, text(heading), title_context(source), heading_path)
            if group_key not in groups:
                active = {
                    "id": uid(identity + ":section:" + digest(group_key)),
                    "heading": displayed_heading,
                    "source_context_title": context_title,
                    "heading_path": [
                        {"level": level, "text": label, "uncertain_scope": uncertain}
                        for level, label, uncertain in heading_stack
                    ],
                    "program": program,
                    "blocks": [],
                }
                groups[group_key] = active
                sections.append(active)
            else:
                active = groups[group_key]
            # Structural equality is required: identical flattened table/list
            # text does not prove equivalent structure or legal scope.
            fingerprint = (
                scope_key(source, heading, program),
                heading_path,
                candidate_key(block),
            )
            matches = [
                (item, equivalence(item["original_structure"], block))
                for item in seen.get(fingerprint, [])
            ]
            match = next(((item, why) for item, why in matches if why), None)
            if match:
                target, evidence = match
                preferred = preferred_publisher(value)
                selected_ref = target["selected_origin"]
                if (
                    source["domain"] == preferred
                    and selected_ref["publisher"] != preferred
                ):
                    target.update(
                        text=value,
                        original_structure=copy.deepcopy(block),
                        selected_origin=ref,
                        passage_classification=classify_passage(value),
                        preferred_publisher=preferred,
                    )
                    # A prior retained spelling can become represented by the
                    # preferred equivalent. Keep its immutable original hashes.
                    for previous in ledger:
                        if previous["represented_block_id"] == target["id"]:
                            previous["status"] = (
                                evidence["kind"] + "_duplicate_represented"
                            )
                            previous["equivalence_evidence"] = evidence
                target["provenance"].append(ref)
                row = {
                    "reason": evidence["rule"],
                    "provenance": ref,
                    "represented_block_id": target["id"],
                    "equivalence_evidence": evidence,
                }
                omissions.append(row)
                ledger.append(
                    {
                        **ref,
                        "destination_article_id": identity,
                        "status": "preserved"
                        if target["selected_origin"] == ref
                        else evidence["kind"] + "_duplicate_represented",
                        "represented_block_id": target["id"],
                        "equivalence_evidence": evidence,
                    }
                )
                continue
            item = {
                "id": uid(
                    identity
                    + ":block:"
                    + source["source_id"]
                    + ":"
                    + str(index)
                    + (
                        ":" + source["snapshot_id"]
                        if len(variants[source["source_id"]]) > 1
                        else ""
                    )
                ),
                "type": block["type"],
                "text": value,
                "original_structure": copy.deepcopy(block),
                "provenance": [ref],
                "selected_origin": ref,
                "passage_classification": classify_passage(value),
                "preferred_publisher": preferred_publisher(value),
                "composition_policy": VERSION,
            }
            active["blocks"].append(item)
            seen.setdefault(fingerprint, []).append(item)
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
    retained = {b["id"]: b for s in sections for b in s["blocks"]}
    for item in retained.values():
        ref = item["selected_origin"]
        evidence = heading_evidence[(ref["source_id"], ref["snapshot_id"])].get(
            ref["block_index"]
        )
        if item["type"] == "heading":
            level = source_heading_level(item["original_structure"], evidence)
            if level is not None:
                item["heading_level"] = level
            if evidence:
                item["heading_structure_evidence"] = copy.deepcopy(evidence)
        item["source_role"] = (
            "supplemental"
            if item["preferred_publisher"] in domains
            and item["selected_origin"]["publisher"] != item["preferred_publisher"]
            else "primary"
        )
        item["source_roles"] = [
            {
                "source_id": ref["source_id"],
                "block_index": ref["block_index"],
                "role": "primary"
                if ref == item["selected_origin"]
                else "represented_equivalent",
            }
            for ref in item["provenance"]
        ]
    # The decision ledger names the actual final retained spelling and origin,
    # including when a later clinical RADVisa passage superseded DigiVisa.
    for row in ledger:
        target = retained[row["represented_block_id"]]
        row["selected_origin"] = target["selected_origin"]
        row["retained_structure_sha256"] = digest(target["original_structure"])
        row["composition_policy"] = VERSION
        selected_ref = target["selected_origin"]
        if all(
            row[key] == selected_ref[key]
            for key in ("source_id", "snapshot_id", "block_index")
        ):
            row["status"] = "preserved"
            row.pop("equivalence_evidence", None)
        else:
            original = source_variants[(row["source_id"], row["snapshot_id"])][
                "blocks"
            ][row["block_index"]]
            evidence = equivalence(original, target["original_structure"])
            if evidence is None:
                raise ValueError("final_equivalent_cannot_be_revalidated")
            row["equivalence_evidence"] = evidence
            row["status"] = evidence["kind"] + "_duplicate_represented"
    for claim in claims:
        claim["provenance"] = retained[claim["block_id"]]["selected_origin"]
    omissions = [
        {
            "reason": row["equivalence_evidence"]["rule"],
            "provenance": {
                key: row[key]
                for key in (
                    "source_id",
                    "snapshot_id",
                    "url",
                    "publisher",
                    "source_title",
                    "block_index",
                    "start",
                    "end",
                    "sha256",
                    "structure_sha256",
                )
            },
            "represented_block_id": row["represented_block_id"],
            "equivalence_evidence": row["equivalence_evidence"],
            "selected_origin": row["selected_origin"],
        }
        for row in ledger
        if row["status"] != "preserved"
    ]
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
        "source_ids": sorted({s["source_id"] for s in members}),
        "source_urls": sorted({s["url"] for s in members}),
        "source_snapshot_ids": sorted({s["snapshot_id"] for s in members}),
        "source_publishers": sorted(domains),
        "sections": sections,
        "omissions": omissions,
        "claims": claims,
        "conflicts": conflicts,
        "segment_ledger": ledger,
        "composition_policy": VERSION,
        "editorial_state": "draft",
        "verification_state": "unverified",
        "reviewer_id": None,
        "published": False,
        "publication_allowed": False,
        "composition_review": "owner_approved_merge_policy_publication_separate",
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
                "snapshot_id": source["snapshot_id"],
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
                (
                    namespace,
                    None if namespace == "supplementary" else topic_key(source),
                    (source["language"], source["url"])
                    if namespace == "supplementary"
                    else None,
                )
            ].append(source)
    # Same-origin versions share one reader. Exact copied bodies at alternate
    # Mohajer URLs also share that reader, retaining all original identities.
    # This avoids assigning the same historical topic/body UUID to two readers.
    roots, copies = {}, {}

    def root(key):
        while key in roots:
            key = roots[key]
        return key

    for key, members in list(independent.items()):
        if key[0] != "supplementary":
            continue
        for member in members:
            signature = (topic_key(member), digest(member["body_text"]))
            if signature in copies:
                left, right = root(key), root(copies[signature])
                if left != right:
                    first, second = sorted((left, right), key=str)
                    roots[second] = first
            else:
                copies[signature] = key
    regrouped = defaultdict(list)
    for key, members in independent.items():
        regrouped[root(key)].extend(members)
    independent = regrouped
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
                {
                    (s["source_id"], s["snapshot_id"]): indices
                    for s, indices in contributions
                },
            )
        )
    for (namespace, key, _), members in sorted(
        independent.items(), key=lambda item: str(item[0])
    ):
        first = min(
            members,
            key=lambda s: (
                s["domain"] != "digivisa.ir",
                s["url"],
                s.get("retrieved_at") or "",
                s["snapshot_id"],
            ),
        )
        key = topic_key(first) if namespace == "supplementary" else key
        body_hash = digest(first["body_text"])
        identity = uid(
            "rad-independent-v3:" + namespace + ":" + digest((key, body_hash))
        )
        article = compose(
            members,
            identity,
            first["title"],
            sorted(
                {c for member in members for c in member["taxonomy"]["country_codes"]}
            ),
        )
        article["source_prior_article_ids"] = sorted(
            {
                uid(
                    "rad-independent-v3:"
                    + namespace
                    + ":"
                    + digest((topic_key(s), digest(s["body_text"])))
                )
                for s in members
            }
        )
        articles.append(article)
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
                        "relevance_basis": "owner_approved_country_context_association_claims_unverified",
                        "rank": 0,
                        "state": "proposed",
                        "reviewer_id": None,
                    }
                )
    return articles, mappings, relations, countries
