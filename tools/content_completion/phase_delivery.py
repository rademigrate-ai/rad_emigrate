"""Reconcile preserved delivery with new evidence; compile review-only transactions.

No network, credentials, database connection or publication is used here.
"""

import argparse
import json
import shutil
from collections import Counter, defaultdict
from itertools import combinations
from pathlib import Path

from tools.content_completion.country_labels import COUNTRIES
from tools.content_completion.phase_bundle import BASE, save_json
from tools.content_completion.prepare_delivery import PROJECT, prepare
from tools.plan3_content.dataset import read_jsonl, write_jsonl
from tools.plan3_content.parser import digest


def duplicates(captures):
    """Exact hashes prove equality; shared substantial blocks only suggest review."""
    complete = [
        c for c in captures if c["completeness"] == "complete_owned_article_container"
    ]
    bodies, normalized, urls, blocks = (defaultdict(set) for _ in range(4))
    block_sets = {}
    for c in complete:
        sid = c["source_id"]
        bodies[(c["language"], c["body_sha256"])].add(sid)
        normalized[(c["language"], c["normalized_body_sha256"])].add(sid)
        urls[c["url"]].add(c["body_sha256"])
        hashes = {digest(b) for b in c["blocks"] if len(b["text"]) >= 100}
        block_sets.setdefault(sid, set()).update(hashes)
        for checksum in hashes:
            blocks[checksum].add(sid)
    rows = []
    for (language, checksum), ids in sorted(bodies.items()):
        if len(ids) > 1:
            rows.append(
                {
                    "kind": "exact_body_alias",
                    "language": language,
                    "body_sha256": checksum,
                    "source_ids": sorted(ids),
                    "action": "retain_all_provenance_no_automatic_cross_article_merge",
                }
            )
    for (language, checksum), ids in sorted(normalized.items()):
        if len(ids) > 1 and not any(ids <= group for group in bodies.values()):
            rows.append(
                {
                    "kind": "normalized_body_overlap",
                    "language": language,
                    "normalized_body_sha256": checksum,
                    "source_ids": sorted(ids),
                    "action": "human_review_preserve_distinct_original_bytes",
                }
            )
    for url, hashes in sorted(urls.items()):
        if len(hashes) > 1:
            rows.append(
                {
                    "kind": "same_url_different_content",
                    "url": url,
                    "body_sha256_versions": sorted(hashes),
                    "action": "retain_all_versions_do_not_overwrite_editorial_head",
                }
            )
    shared = Counter()
    for ids in blocks.values():
        # Universally repeated boilerplate is not useful semantic evidence.
        if len(ids) <= 30:
            shared.update(combinations(sorted(ids), 2))
    for (left, right), count in sorted(shared.items()):
        denominator = min(len(block_sets[left]), len(block_sets[right]))
        if count >= 3 and denominator and count / denominator >= 0.45:
            rows.append(
                {
                    "kind": "shared_substantive_blocks_near_duplicate_candidate",
                    "source_ids": [left, right],
                    "shared_block_count": count,
                    "smaller_article_block_overlap": round(count / denominator, 6),
                    "unique_block_counts": [
                        len(block_sets[left] - block_sets[right]),
                        len(block_sets[right] - block_sets[left]),
                    ],
                    "action": "human_review_only_all_unique_sections_retained",
                }
            )
    return rows


def verify_payload(row, snapshots):
    if row.get("status") != "technical_draft_only":
        raise ValueError("blocked_payload_cannot_enter_import_plan")
    item = row["item"]
    if (
        item["published"]
        or item["publication_allowed"]
        or item["reviewer_id"] is not None
    ):
        raise ValueError("publication_or_approval_forbidden")
    for source in row["sources"]:
        if digest(source["body_text"]) != source["body_sha256"]:
            raise ValueError("payload_source_hash_mismatch")
        snapshots[source["snapshot_id"]] = source
    for section in item["sections"]:
        for block in section["blocks"]:
            if block["text"] != block["original_structure"]["text"]:
                raise ValueError("rich_content_text_loss")
            for ref in block["provenance"]:
                source = snapshots[ref["snapshot_id"]]
                if (
                    source["body_text"][ref["start"] : ref["end"]] != block["text"]
                    or digest(block["original_structure"]) != ref["structure_sha256"]
                ):
                    raise ValueError("rich_block_provenance_mismatch")


def build(directory):
    prepared = directory / "prepared"
    prepared.mkdir(parents=True, exist_ok=True)
    # Keep original payload bytes until an explicitly additive file is compiled.
    for path in sorted((BASE / "prepared").iterdir()):
        if path.is_file():
            shutil.copyfile(path, prepared / path.name)
    captures = read_jsonl(directory / "source-captures.jsonl.gz")
    master = read_jsonl(directory / "source-master.jsonl.gz")
    extra = read_jsonl(directory / "other-titles-draft-payloads.jsonl.gz")
    old_new = read_jsonl(prepared / "new-draft-payloads.jsonl.gz")
    snapshots = {}
    for row in old_new + extra:
        verify_payload(row, snapshots)
    combined = old_new + extra
    identities = [(r["article_id"], r["item"]["locale"]) for r in combined]
    if len(identities) != len(set(identities)):
        raise ValueError("duplicate_article_locale_in_combined_import")
    write_jsonl(prepared / "new-draft-payloads.jsonl.gz", combined)
    maps = read_jsonl(prepared / "reference-maps.jsonl.gz") + read_jsonl(
        directory / "other-titles-reference-maps.jsonl.gz"
    )
    write_jsonl(prepared / "reference-maps.jsonl.gz", maps)
    prior_summary = json.loads((prepared / "summary.json").read_text(encoding="utf-8"))
    save_json(
        prepared / "summary.json",
        {
            **prior_summary,
            "new_full_article_drafts": len(combined),
            "new_independent_articles": prior_summary["new_independent_articles"]
            + len(extra),
            "reference_maps": len(maps),
            "additional_independent_phase1_4": len(extra),
            "scope": "combined preserved proposal plus phases1-4; captured_source_blocks below refers to original sealed corpus only",
        },
    )
    intake = {
        s["snapshot_id"]: s for s in read_jsonl(prepared / "source-intake.jsonl.gz")
    }
    for row in extra:
        for s in row["sources"]:
            prior = intake.get(s["snapshot_id"])
            if prior and any(
                prior[k] != s[k]
                for k in ("source_id", "body_text", "body_sha256", "url")
            ):
                raise ValueError("conflicting_snapshot_in_intake")
            intake.setdefault(s["snapshot_id"], s)
    write_jsonl(
        prepared / "source-intake.jsonl.gz",
        sorted(intake.values(), key=lambda s: s["snapshot_id"]),
    )
    existing_other = json.loads(
        (prepared / "other-titles-inventory.json").read_text(encoding="utf-8")
    )
    extra_inventory = [
        {
            **{
                k: row["item"][k]
                for k in (
                    "article_id",
                    "locale",
                    "title",
                    "country_codes",
                    "source_ids",
                )
            },
            "state": "draft",
            "human_review_required": True,
        }
        for row in extra
    ]
    save_json(
        prepared / "other-titles-inventory.json", existing_other + extra_inventory
    )
    ledger = read_jsonl(prepared / "source-section-ledger.jsonl.gz")
    exclusions = []
    for row in ledger:
        if row["inclusion_status"] != "excluded_with_evidence":
            continue
        reason = row["exception"]
        is_listing = reason.startswith("Archive/news")
        exclusions.append(
            {
                **row,
                "reassessment": "partial_listing_evidence_preserved_not_discarded_as_non_substantive"
                if is_listing
                else "explicit_nonarticle_or_out_of_scope_evidence_preserved",
                "editorial_approval": False,
                "full_original_block_retained": True,
                "requires_review": is_listing,
                "review_method": "original_block_hash_and_recorded_exclusion_reason_checked; full extracted block retained for independent inspection",
                "next_action": "follow source-access/master records for corresponding full articles; do not count teaser as complete"
                if is_listing
                else "retain immutable evidence; editor may reconsider scope",
            }
        )
    write_jsonl(directory / "reviewed-exclusions.jsonl.gz", exclusions)
    # Every captured block has its original text, exact hashes and a location or hold.
    mappings = {
        m["capture_id"]: m
        for m in read_jsonl(directory / "supplementary-destination-map.jsonl.gz")
    }
    new_ledger = []
    for capture in captures:
        for index, block in enumerate(capture["blocks"]):
            target = mappings.get(capture["capture_id"])
            new_ledger.append(
                {
                    "capture_id": capture["capture_id"],
                    "source_id": capture["source_id"],
                    "source_url": capture["url"],
                    "block_index": index,
                    "body_sha256": capture["body_sha256"],
                    "block_sha256": digest(block["text"]),
                    "structure_sha256": digest(block),
                    "original_structure": block,
                    "destination": target
                    or {
                        "disposition": "preserved_primary_source_section_ledger_or_human_version_review"
                        if capture["completeness"] == "complete_owned_article_container"
                        else "nonarticle_partial_or_incomplete_evidence_hold"
                    },
                    "human_review_required": True,
                }
            )
    write_jsonl(directory / "capture-block-ledger.jsonl.gz", new_ledger)
    duplicate_rows = duplicates(captures)
    write_jsonl(directory / "duplicate-conflict-ledger.jsonl.gz", duplicate_rows)
    source_rows = {r["source_id"]: r for r in master}
    frontier = json.loads(
        (
            directory
            / "reference-evidence/RAD_CROSS_AGENT_HASH_QA_20261028/GROK100_LOCAL_RECONCILIATION.json"
        ).read_text(encoding="utf-8-sig")
    )
    # Different independent report versions use a named rows/reconciliation list.
    frontier_rows = (
        frontier
        if isinstance(frontier, list)
        else next(v for v in frontier.values() if isinstance(v, list) and len(v) == 100)
    )
    frontier_proof = []
    for r in frontier_rows:
        sid = r.get("source_id") or r.get("codex_source_id")
        source = source_rows[sid]
        versions = [
            c
            for c in captures
            if c["source_id"] == sid
            and c["completeness"] == "complete_owned_article_container"
            and c["raw_html_asset"]
        ]
        frontier_proof.append(
            {
                "source_id": sid,
                "url": source["url"],
                "full_historical_body_and_verified_raw": bool(versions),
                "capture_ids": [c["capture_id"] for c in versions],
                "raw_sha256": sorted({c["raw_html_sha256"] for c in versions}),
                "body_sha256": sorted({c["body_sha256"] for c in versions}),
                "original_grok_transfer_proven": any(
                    c["acquisition_method"] == "grok_original_transfer_verified"
                    for c in versions
                ),
            }
        )
    save_json(directory / "frontier100-original-cache-proof.json", frontier_proof)
    primary_proof = []
    for s in read_jsonl(BASE / "prepared/source-intake.jsonl.gz"):
        versions = [
            c
            for c in captures
            if c["source_id"] == s["source_id"]
            and c["body_sha256"] == s["body_sha256"]
            and c["raw_html_sha256"] == s["raw_html_sha256"]
            and c["raw_html_asset"]
        ]
        if not versions:
            raise ValueError(
                "primary_intake_missing_matching_raw_body:" + s["source_id"]
            )
        primary_proof.append(
            {
                "source_id": s["source_id"],
                "snapshot_id": s["snapshot_id"],
                "body_sha256": s["body_sha256"],
                "raw_sha256": s["raw_html_sha256"],
                "capture_ids": [c["capture_id"] for c in versions],
            }
        )
    save_json(directory / "primary146-integrity-proof.json", primary_proof)
    blockers = []
    for row in master:
        if row["recovery_status"] != "full_body_and_verified_raw" and not row[
            "recovery_status"
        ].startswith("excluded_"):
            blockers.append(
                {
                    **{
                        k: row.get(k)
                        for k in (
                            "source_id",
                            "url",
                            "recovery_status",
                            "original_classification",
                            "last_known_http_status",
                            "last_known_fetch_error",
                            "content_completeness",
                            "capture_ids",
                        )
                    },
                    "blocker": "no_verified_complete_owned_article_body; retained raw may be listing, placeholder, error or inaccessible source",
                    "next_action": row["follow_up"],
                    "publication_allowed": False,
                }
            )
    write_jsonl(directory / "unresolved-source-register.jsonl.gz", blockers)
    review = read_jsonl(directory / "human-review-queue.jsonl.gz")
    review += [
        {
            "reason": r["kind"],
            "evidence": r,
            "state": "human_review_required",
            "publication_allowed": False,
        }
        for r in duplicate_rows
        if r["kind"] != "exact_body_alias"
    ]
    review += [
        {
            "reason": "previous_listing_exclusions_retain_substantive_partial_evidence",
            "source_id": sid,
            "block_indices": [
                r["source_block_index"] for r in exclusions if r["source_id"] == sid
            ],
            "state": "human_review_required",
            "publication_allowed": False,
        }
        for sid in sorted({r["source_id"] for r in exclusions if r["requires_review"]})
    ]
    write_jsonl(directory / "complete-human-review-queue.jsonl.gz", review)
    plan = prepare(prepared, directory / "import-review", PROJECT)
    canonical = json.loads(
        (prepared / "canonical-page-inventory.json").read_text(encoding="utf-8")
    )
    previous_preflight = json.loads(
        (BASE / "expanded-hosted-preflight.json").read_text(encoding="utf-8")
    )
    prior_missing = set(previous_preflight["missing_destination_codes"])
    proposed = []
    for code in plan["country_codes_considered"]:
        candidates = [
            r for r in existing_other + extra_inventory if code in r["country_codes"]
        ]
        pages = [r for r in canonical if code in r["country_codes"]]
        proposed.append(
            {
                "country_code": code,
                "names": {"fa": COUNTRIES[code][0], "en": COUNTRIES[code][-1]},
                "prior_missing_29_register": code in prior_missing,
                "historical_catalog_observed_at": previous_preflight["observed_at"],
                "current_hosted_presence_not_rechecked": True,
                "canonical_visa_categories": sorted(
                    {r["visa_category"] for r in pages}
                ),
                "canonical_article_ids": sorted({r["article_id"] for r in pages}),
                "independent_article_locales": len(candidates),
                "independent_article_ids": sorted(
                    {r["article_id"] for r in candidates}
                ),
                "source_ids": sorted(
                    {sid for r in pages + candidates for sid in r["source_ids"]}
                ),
                "insert_policy": "missing_only_draft; no invented program or automatic public tile",
                "editorial_status": "human_review_required",
                "publication_allowed": False,
            }
        )
    save_json(directory / "destination-proposals.json", proposed)
    summary = {
        "new_draft_payloads": len(combined),
        "additional_independent_drafts": len(extra),
        "canonical_pages": len(
            json.loads(
                (prepared / "canonical-page-inventory.json").read_text(encoding="utf-8")
            )
        ),
        "other_titles_locales_including_existing": len(existing_other) + len(extra),
        "source_snapshots_in_combined_intake": len(intake),
        "previous_excluded_blocks_reconciled": len(exclusions),
        "partial_listing_blocks_preserved_for_review": sum(
            r["requires_review"] for r in exclusions
        ),
        "all_capture_blocks_preserved": len(new_ledger),
        "captured_body_characters_including_versions": sum(
            len(c["body_text"]) for c in captures
        ),
        "duplicate_conflict_counts": dict(Counter(r["kind"] for r in duplicate_rows)),
        "frontier100_verified_full_body_raw": sum(
            r["full_historical_body_and_verified_raw"] for r in frontier_proof
        ),
        "primary_intake_verified_raw_body": len(primary_proof),
        "unresolved_source_records": len(blockers),
        "human_review_items": len(review),
        "import_plan": plan,
        "hosted_writes": 0,
        "publication_allowed": False,
        "coverage_verdict": "REVIEW_AND_SOURCE_GAPS_REMAIN; no claim of complete live three-site coverage",
    }
    save_json(directory / "delivery-integrity-summary.json", summary)
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.directory)))
