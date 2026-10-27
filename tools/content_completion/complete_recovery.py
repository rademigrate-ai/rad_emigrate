"""Place preserved recovery articles and explicit source sections without rewriting originals.

Produces draft-only inputs for the existing CMS, never a parallel reader or a
hosted write. Selection is an evidence-bound editorial proposal, not legal approval.
"""

import argparse
import copy
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path

from tools.content_completion.recover_exclusions import recover, retain_blocks
from tools.content_consolidation.import_payload import payload
from tools.content_consolidation.mapping import LABELS
from tools.plan3_content.dataset import read_jsonl, uid, write_jsonl
from tools.plan3_content.parser import digest
from tools.plan3_content.taxonomy import COUNTRIES

# Full-source inspection: whole educational sections go to Study. Tourism
# statistics and brief cross-links do not establish tourist/study requirements.
SELECTIONS = {
    "173e387d-aa85-55f9-843f-e43d1df1af87": (
        "IT",
        7,
        34,
        "School system, foreign admission, tuition, financial evidence and documents; broad migration-route list remains in the independent article.",
    ),
    "65e2f61a-849d-51b0-95ab-ccd038db8b55": (
        "OM",
        0,
        0,
        "Country history, economy and living conditions; its study mention is a cross-link, with no substantive study requirements.",
    ),
    "d9bc1af3-4b25-5757-966c-11b14ce358d7": (
        "DE",
        11,
        22,
        "School and higher education, study durations, student work claims and admission documents; final contact promotion remains independent.",
    ),
    "c8b55fc6-892a-54d6-807c-31e4ad8d166a": (
        "AU",
        23,
        25,
        "Complete study section; visitor-origin statistics describe Australia tourism, not Visa rules for the visitor countries.",
    ),
    "99579d24-9cff-5221-a992-ff9e82385284": (
        "IS",
        16,
        19,
        "Education, international-student participation, language, university and processing fees; source inconsistencies retained for review.",
    ),
    "01029a5b-325e-5c62-96f2-5b5a48e29d17": (
        "TR",
        0,
        0,
        "Country, tourism and medical-tourism background; full body contains no application requirements establishing a main Visa contribution.",
    ),
    "b762f0bc-1505-59c5-9a1f-1095e5c20d7d": (
        "CH",
        5,
        17,
        "Education, degree conditions, language, student work, admission documents and student living-cost caution; final general promotion stays independent.",
    ),
    "febf0b77-f7f9-5405-a51e-845da7f44e82": (
        "FR",
        12,
        16,
        "Whole education section and its university list; general migration/contact paragraph stays independent.",
    ),
}


def excluded_block_reason(source, index):
    """Explicit dispositions for captured controls/placeholders, never inferred law."""
    if source.get("article_body_assessment") == "soft_404_not_an_article":
        return (
            "Server returned its captured page-not-found message, not an article body."
        )
    if source["source_id"] == "12f23160-9c27-5929-8b75-f90be4599963":
        return "Source contains only its title and an explicit page-being-updated placeholder; substantive body unavailable."
    if source["source_id"] == "4c2f5ff2-34f2-5a0d-aef4-7c6024d16aad":
        return "Captured source says no faq found; no FAQ answer is present."
    if source["source_id"] in {
        "47e3e133-da41-5ee5-8bc5-b6c8a675ba8a",
        "ede8a756-b3b9-541c-aceb-a7c6a9f45d7a",
        "caa929e1-afeb-5a21-b4c0-96313b911b84",
    }:
        return "FAQ search/security/pagination control outside all retained question/answer ranges."
    if source["taxonomy"]["page_type"] == "navigation_or_interactive_page":
        return "Archive/news discovery listing: article titles, clipped teasers and paging controls; linked article URLs are retained in discovery, never counted as full bodies."
    if source["title"] in {
        "About us",
        "درباره ما",
        "Contact us",
        "Contact Us",
        "تماس با ما",
    }:
        return "Company promotion/contact information, outside substantive Visa/country knowledge; original snapshot remains preserved."
    if (
        source["title"] == "محصولات"
        and source.get("article_body_assessment") == "thin_or_metadata_only_body"
    ):
        return "Empty products/navigation label, with no substantive article."
    return None


def append_contribution(base, independent, indices, program="general"):
    """Append source-ordered rich sections; keep every existing UUID and block intact."""
    result = copy.deepcopy(base)
    selected = set(indices)
    remap = {}
    for section in independent["sections"]:
        new = copy.deepcopy(section)
        new["blocks"] = [
            b for b in new["blocks"] if b["provenance"][0]["block_index"] in selected
        ]
        if not new["blocks"]:
            continue
        new["id"] = uid(
            "recovered-study-section:" + base["article_id"] + ":" + section["id"]
        )
        new["program"] = program
        for block in new["blocks"]:
            original_id = block["id"]
            block["id"] = uid(
                "recovered-study-block:" + base["article_id"] + ":" + original_id
            )
            remap[original_id] = block["id"]
        result["sections"].append(new)
    result["source_ids"] = sorted(set(base["source_ids"] + independent["source_ids"]))
    result["source_urls"] = sorted(
        set(base["source_urls"] + independent["source_urls"])
    )
    result["source_publishers"] = sorted(
        set(base["source_publishers"] + independent["source_publishers"])
    )
    for original in independent["segment_ledger"]:
        if original["block_index"] in selected:
            result["segment_ledger"].append(
                {
                    **original,
                    "destination_article_id": base["article_id"],
                    "represented_block_id": remap[original["represented_block_id"]],
                }
            )
    for claim in independent["claims"]:
        if claim["block_id"] in remap:
            result["claims"].append(
                {**copy.deepcopy(claim), "block_id": remap[claim["block_id"]]}
            )
    result["composition_review"] = (
        "source_bound_recovery_addition_requires_human_editorial_and_official_verification"
    )
    return result, remap


def combine_reference_maps(base, contribution, remap):
    result = copy.deepcopy(base)
    existing = {s["snapshot_id"] for s in result["sources"]}
    result["sources"].extend(
        copy.deepcopy(s)
        for s in contribution["sources"]
        if s["snapshot_id"] not in existing
    )
    for link in contribution["links"]:
        new = copy.deepcopy(link)
        if new.get("target_block_id"):
            new["target_block_id"] = remap.get(new["target_block_id"])
        if new not in result["links"]:
            result["links"].append(new)
    return result


def build(corpus, recovery, output, raw_caches=()):
    output.mkdir(parents=True, exist_ok=True)
    sources = {s["source_id"]: s for s in read_jsonl(corpus / "sources.jsonl.gz")}
    originals = read_jsonl(corpus / "articles.jsonl.gz")
    articles = {(a["article_id"], a["locale"]): a for a in originals}
    drafts = read_jsonl(recovery / "geographic-drafts.jsonl.gz")
    maps = {
        (r["article_id"], r["locale"]): r
        for r in read_jsonl(recovery / "article-reference-maps.jsonl.gz")
    }
    references = {
        (r["article_id"], r["locale"]): r
        for r in read_jsonl(
            Path("artifacts/RAD_CONTENT_REFERENCE_CAPTURE_20261026")
            / "article_reference_maps.jsonl.gz"
        )
    }
    registry = json.loads(
        Path("supabase/contracts/rad_v1.json").read_text(encoding="utf-8")
    )
    if raw_caches:
        extra_drafts, extra_maps = recover(sources, raw_caches)
        drafts.extend(extra_drafts)
        maps.update({(r["article_id"], r["locale"]): r for r in extra_maps})
    decisions, revisions, prepared_maps, new_payloads = [], [], [], []
    baseline_articles = copy.deepcopy(articles)
    verification_file = output.parent / "staging-comparison.json"
    verified_baselines = set()
    if verification_file.exists():
        verification = json.loads(verification_file.read_text(encoding="utf-8"))
        verified_baselines = {
            (r["article_id"], r["locale"])
            for r in verification["rows"]
            if r["import_matches_corpus"] and r["head_matches_corpus"]
        }
        if verified_baselines != set(baseline_articles):
            raise ValueError("staging_baseline_not_identical")
    changed, source_intake = set(), {}
    for draft in drafts:
        sid = draft["source_ids"][0]
        source = sources[sid]
        if digest(source["body_text"]) != source["body_sha256"]:
            raise ValueError("source_body_hash_mismatch")
        placement = draft.get("recovery_placement")
        if placement is None:
            if len(draft["country_codes"]) != 1:
                raise ValueError("unresolved_country:" + sid)
            placement = {
                "independent_indices": list(range(len(source["blocks"]))),
                "contributions": [],
                "rationale": "Full source-bound geographic article remains independent; human review pending.",
            }
            if sid in SELECTIONS:
                country, start, end, reason = SELECTIONS[sid]
                if draft["country_codes"] != [country]:
                    raise ValueError("classification_country_mismatch")
                placement["rationale"] = reason
                if end:
                    placement["contributions"] = [
                        {
                            "country": country,
                            "visa_category": "study",
                            "indices": list(range(start, end)),
                        }
                    ]
        decision = {
            "source_id": sid,
            "source_url": source["url"],
            "source_body_sha256": source["body_sha256"],
            "source_structure_sha256": digest(source["blocks"]),
            "independent_article_id": draft["article_id"]
            if placement["independent_indices"] is not None
            else None,
            "independent_indices": placement["independent_indices"],
            "country_codes": draft["country_codes"],
            "main_contributions": [],
            "classification_status": "source_bound_proposal_human_review_pending",
            "rationale": placement["rationale"],
        }
        source_payload = payload(draft, sources, registry)
        if source_payload["status"] != "technical_draft_only":
            raise ValueError("source_contract_rejected:" + sid)
        for item in source_payload["sources"]:
            source_intake[item["source_id"]] = item
        for contribution in placement["contributions"]:
            country, route, indices = (
                contribution["country"],
                contribution["visa_category"],
                contribution["indices"],
            )
            identity = uid(f"rad-country-category-v3:{country}:{route}")
            key = (identity, draft["locale"])
            if key not in articles:
                # New card uses the same canonical identity rule and CMS contract.
                template = copy.deepcopy(
                    next(a for a in originals if a["content_class"] == "canonical")
                )
                template.update(
                    article_id=identity,
                    locale=draft["locale"],
                    country_codes=[country],
                    visa_category=route,
                    pathway=route,
                    title=f"{LABELS[route][0 if draft['locale'] == 'fa' else 1]} — {COUNTRIES[country][0 if draft['locale'] == 'fa' else -1]}",
                )
                for field in (
                    "sections",
                    "source_ids",
                    "source_urls",
                    "source_publishers",
                    "omissions",
                    "claims",
                    "conflicts",
                    "segment_ledger",
                ):
                    template[field] = []
                articles[key] = template
                references[key] = {
                    "map": {
                        "capture_status": "complete",
                        "sources": [],
                        "links": [],
                        "media_reuse": "not_authorized",
                        "legal_verification": "not_inferred_from_links",
                    }
                }
            enriched, remap = append_contribution(
                articles[key], draft, indices, contribution.get("program", "general")
            )
            if sid == "9a312140-6273-5aaf-afe4-ab1ed4f901f9" and route == "family":
                enriched["conflicts"].append(
                    {
                        "type": "source_internal_parent_eligibility_disagreement",
                        "source_id": sid,
                        "source_block_indices": [1, 8],
                        "original_passages": [
                            source["blocks"][i]["text"] for i in (1, 8)
                        ],
                        "resolution": "human_and_official_source_verification_required",
                    }
                )
            if sid == "99579d24-9cff-5221-a992-ff9e82385284":
                enriched["conflicts"].append(
                    {
                        "type": "source_internal_university_count_disagreement",
                        "source_id": sid,
                        "source_block_indices": [18],
                        "original_passages": [source["blocks"][18]["text"]],
                        "resolution": "human_and_official_source_verification_required",
                    }
                )
            articles[key] = enriched
            changed.add(key)
            references[key]["map"] = combine_reference_maps(
                references[key]["map"],
                maps[(draft["article_id"], draft["locale"])]["map"],
                remap,
            )
            decision["main_contributions"].append(
                {
                    "article_id": identity,
                    "visa_category": route,
                    "country_code": country,
                    "block_indices": indices,
                    "block_structure_sha256": [
                        digest(source["blocks"][i]) for i in indices
                    ],
                }
            )
        if placement["independent_indices"] is not None:
            independent = retain_blocks(draft, placement["independent_indices"])
            prepared = payload(independent, sources, registry)
            if prepared["status"] != "technical_draft_only":
                raise ValueError("independent_contract_rejected:" + sid)
            new_payloads.append(prepared)
            prepared_maps.append(maps[(draft["article_id"], draft["locale"])])
            articles[(draft["article_id"], draft["locale"])] = independent
        decisions.append(decision)
    # Returning medical students are education/repatriation information, not
    # an incoming Iran Visa route. Keep the existing identity/body/history.
    repatriation_key = ("b396ad72-bfd0-5ac5-b26f-38bfd114a5ed", "fa")
    repatriation = copy.deepcopy(articles[repatriation_key])
    repatriation.update(
        content_class="editorial",
        visa_category=None,
        pathway="general",
        category="education",
        composition_review="Iran_returning_medical_student_transfer_not_an_incoming_Visa_route",
    )
    articles[repatriation_key] = repatriation
    changed.add(repatriation_key)
    for key in sorted(changed):
        prepared = payload(articles[key], sources, registry)
        if prepared["status"] != "technical_draft_only":
            raise ValueError("canonical_contract_rejected:" + key[0])
        if key in baseline_articles:
            prepared["base_sections_sha256"] = digest(
                baseline_articles[key]["sections"]
            )
            if key == repatriation_key:
                prepared["catalog_reclassification"] = {
                    "from_content_class": "canonical",
                    "to_content_class": "editorial",
                    "reason": "Source explicitly concerns medical student transfer from foreign universities back to Iran, not an Iran Visa application.",
                }
            revisions.append(prepared)
        else:
            new_payloads.append(prepared)
        prepared_maps.append(
            {
                "article_id": key[0],
                "locale": key[1],
                "expected_revision": 2 if key in baseline_articles else 1,
                "map": references[key]["map"],
            }
        )
    write_jsonl(output / "source-intake.jsonl.gz", list(source_intake.values()))
    destinations = defaultdict(list)
    for article in articles.values():
        for section in article["sections"]:
            for block in section["blocks"]:
                for ref in block["provenance"]:
                    original = sources[ref["source_id"]]["blocks"][ref["block_index"]]
                    if (
                        digest(original) != ref["structure_sha256"]
                        or digest(original["text"]) != ref["sha256"]
                    ):
                        raise ValueError("unbound_destination_block")
                    destinations[(ref["source_id"], ref["block_index"])].append(
                        {
                            "article_id": article["article_id"],
                            "locale": article["locale"],
                            "content_class": article["content_class"],
                            "country_codes": article["country_codes"],
                            "visa_category": article["visa_category"],
                            "block_id": block["id"],
                            "destination_structure_sha256": digest(
                                block["original_structure"]
                            ),
                            "staging_status": "pending_authorized_import"
                            if (
                                (article["article_id"], article["locale"])
                                not in baseline_articles
                                or any(
                                    r["article_id"] == article["article_id"]
                                    for r in revisions
                                )
                            )
                            else (
                                "baseline_sections_match_staging_20261027"
                                if (article["article_id"], article["locale"])
                                in verified_baselines
                                else "staging_not_verified"
                            ),
                            "admin_rendered": False,
                        }
                    )
    ledger = []
    for source in sources.values():
        offset = 0
        for index, block in enumerate(source["blocks"]):
            start = source["body_text"].find(block["text"], offset)
            if start < 0:
                raise ValueError("source_block_offset_mismatch")
            offset = start + len(block["text"])
            targets = destinations[(source["source_id"], index)]
            exclusion = excluded_block_reason(source, index) if not targets else None
            ledger.append(
                {
                    "source_domain": source["domain"],
                    "source_url": source["url"],
                    "canonical_url": source.get("declared_canonical_url"),
                    "source_id": source["source_id"],
                    "source_block_index": index,
                    "source_body_sha256": source["body_sha256"],
                    "source_block_sha256": digest(block),
                    "source_structure": block,
                    "start": start,
                    "end": offset,
                    "destinations": targets,
                    "inclusion_status": "represented"
                    if targets
                    else (
                        "excluded_with_evidence"
                        if exclusion
                        else "unresolved_source_classification"
                    ),
                    "exception": None
                    if targets
                    else exclusion or source["consolidation_disposition"],
                }
            )
    write_jsonl(output / "new-draft-payloads.jsonl.gz", new_payloads)
    write_jsonl(output / "canonical-revision-payloads.jsonl.gz", revisions)
    write_jsonl(output / "reference-maps.jsonl.gz", prepared_maps)
    write_jsonl(output / "source-section-ledger.jsonl.gz", ledger)
    (output / "classification-decisions.json").write_text(
        json.dumps(decisions, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    inventory = [
        {
            "article_id": a["article_id"],
            "locale": a["locale"],
            "title": a["title"],
            "content_class": a["content_class"],
            "country_codes": a["country_codes"],
            "visa_category": a["visa_category"],
            "source_ids": a["source_ids"],
            "section_count": len(a["sections"]),
            "block_count": sum(len(s["blocks"]) for s in a["sections"]),
            "published": False,
        }
        for a in articles.values()
    ]
    for name, rows in (
        (
            "canonical-page-inventory",
            [a for a in inventory if a["content_class"] == "canonical"],
        ),
        (
            "other-titles-inventory",
            [a for a in inventory if a["content_class"] == "editorial"],
        ),
    ):
        (output / (name + ".json")).write_text(
            json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    with (output / "source-url-inventory.csv").open(
        "w", encoding="utf-8-sig", newline=""
    ) as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=[
                "source_id",
                "domain",
                "url",
                "title",
                "language",
                "fetch_status",
                "body_status",
                "body_sha256",
                "consolidation_disposition",
            ],
        )
        writer.writeheader()
        writer.writerows(
            {key: s.get(key) for key in writer.fieldnames} for s in sources.values()
        )
    summary = {
        "original_sources": len(sources),
        "recovered_source_articles": len(drafts),
        "new_independent_articles": sum(
            r["item"]["content_class"] == "editorial" for r in new_payloads
        ),
        "new_canonical_pages": sum(
            r["item"]["content_class"] == "canonical" for r in new_payloads
        ),
        "verified_baseline_article_locales": len(verified_baselines),
        "original_article_locales": len(originals),
        "new_full_article_drafts": len(new_payloads),
        "recovered_original_blocks": sum(
            len(sources[d["source_ids"][0]]["blocks"]) for d in drafts
        ),
        "recovered_unique_source_blocks_represented": sum(
            bool(destinations[(d["source_ids"][0], i)])
            for d in drafts
            for i in range(len(sources[d["source_ids"][0]]["blocks"]))
        ),
        "canonical_pages_enriched": sum(
            r["item"]["content_class"] == "canonical" for r in revisions
        ),
        "existing_drafts_reclassified": sum(
            "catalog_reclassification" in r for r in revisions
        ),
        "added_main_source_blocks": sum(
            len(c["block_indices"]) for d in decisions for c in d["main_contributions"]
        ),
        "reference_maps": len(prepared_maps),
        "recovered_classifications_unresolved": 0,
        "captured_source_blocks": len(ledger),
        "source_block_dispositions": dict(
            Counter(r["inclusion_status"] for r in ledger)
        ),
        "hosted_mutations": 0,
        "publication_allowed": False,
        "verdict": "NO_GO_PENDING_COVERAGE_AND_HOSTED_SAFETY_AUTHORIZATION",
    }
    (output / "summary.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8"
    )
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--recovery", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--raw-cache", type=Path, action="append", default=[])
    args = parser.parse_args()
    print(json.dumps(build(args.corpus, args.recovery, args.output, args.raw_cache)))
