"""Build a portable, offline, source-faithful phases 1–4 handoff.

All inputs are read-only. Raw hashes are verified before assets or drafts are
accepted. Existing source versions, journals and editorial work are not changed.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from urllib.parse import urlsplit

from tools.content_completion.recover_geography import make_draft
from tools.content_completion.source_evidence import (
    country_evidence,
    original_url,
    parse_mohajer,
)
from tools.content_consolidation.import_payload import payload
from tools.plan3_content.crawl import stable_id
from tools.plan3_content.dataset import read_jsonl, uid, write_jsonl
from tools.plan3_content.parser import digest, search_normalize

BASE = Path("_audit/RAD_CONTENT_COMPLETION_20261027")
CORPUS = Path("artifacts/RAD_CONTENT_CONSOLIDATION_20261026")
REFERENCES = [
    "RAD_FINALIZATION_ROADMAP_20261028.md",
    "RAD_FULL_FEATURE_ACCEPTANCE_MATRIX_20261028.md",
    "RAD_SQLQA_20261028/SQL_QA_HANDOFF.md",
    "RAD_CROSS_AGENT_HASH_QA_20261028/RAD_TRANSFER_RECOVERY_UPDATE_20261028.md",
    "RAD_CROSS_AGENT_HASH_QA_20261028/GROK100_LOCAL_RECONCILIATION.json",
    "RAD_CROSS_AGENT_HASH_QA_20261028/LOCAL_REFETCH_PARTIAL_VERIFICATION.json",
    "RAD_CROSS_AGENT_HASH_QA_20261028/REFETCH_REMAINING_URLS.json",
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def confined(root, relative):
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("input_path_escapes_reference_root")
    return path


class Bundle:
    def __init__(self, output, sources, received_at):
        self.output = output
        self.received_at = received_at
        self.sources = {s["source_id"]: s for s in sources}
        self.by_url = {original_url(s["url"]): s["source_id"] for s in sources}
        self.captures = {}
        self.observations = []
        self.listing_excerpts = []
        self.integrity = []
        self.master = {
            original_url(s["url"]): {
                "source_id": s["source_id"],
                "url": original_url(s["url"]),
                "publisher": s["domain"],
                "capture_ids": [],
                "original_classification": s["consolidation_disposition"],
                "last_known_http_status": s.get("http_status"),
                "last_known_fetch_error": s.get("fetch_error"),
                "editorial_status": "human_review_required",
                "historical_source_ids": [s["source_id"]],
            }
            for s in sources
        }

    def source(self, url):
        url = original_url(url)
        if url not in self.master:
            sid = stable_id(url)
            self.by_url[url] = sid
            self.master[url] = {
                "source_id": sid,
                "url": url,
                "publisher": urlsplit(url).hostname,
                "capture_ids": [],
                "original_classification": None,
                "editorial_status": "human_review_required",
                "historical_source_ids": [],
            }
        return self.master[url]

    def raw_asset(self, raw):
        checksum = sha(raw)
        # Short physical names avoid Windows MAX_PATH; the complete digest and
        # a collision check remain authoritative, never the short name alone.
        relative = Path("assets/raw") / (checksum[:20] + ".html.gz")
        target = self.output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            if gzip.decompress(target.read_bytes()) != raw:
                raise ValueError("short_asset_name_collision")
        else:
            stream = io.BytesIO()
            with gzip.GzipFile(
                filename="", fileobj=stream, mode="wb", mtime=0, compresslevel=9
            ) as zipped:
                zipped.write(raw)
            target.write_bytes(stream.getvalue())
        return {
            "raw_html_sha256": checksum,
            "raw_html_asset": relative.as_posix(),
            "raw_html_bytes": len(raw),
        }

    def capture(self, source, parsed, method, raw=None, **evidence):
        row = self.source(source["url"])
        body = parsed.get("body_text", "")
        blocks = parsed.get("blocks", [])
        if "\n\n".join(b["text"] for b in blocks) != body:
            raise ValueError("body_and_block_sequence_disagree")
        body_hash = digest(body) if body else None
        if parsed.get("body_sha256") not in (None, body_hash):
            raise ValueError("body_digest_disagrees")
        asset = (
            self.raw_asset(raw)
            if raw is not None
            else {
                "raw_html_sha256": source.get("raw_html_sha256"),
                "raw_html_asset": None,
            }
        )
        identity = uid(
            "phase-capture:"
            + row["source_id"]
            + ":"
            + str(body_hash)
            + ":"
            + str(asset["raw_html_sha256"])
            + ":"
            + method
        )
        item = {
            "capture_id": identity,
            "source_id": row["source_id"],
            "url": row["url"],
            "title": parsed.get("title") or source.get("title") or "",
            "language": source.get("language") or parsed.get("language") or "fa",
            "snapshot_id": uid("snapshot:" + row["source_id"] + ":" + body_hash)
            if body_hash
            else None,
            "body_text": body,
            "blocks": blocks,
            "body_sha256": body_hash,
            "normalized_body_sha256": digest(search_normalize(body)) if body else None,
            "structure_sha256": digest(blocks),
            "completeness": parsed.get("completeness", "unknown"),
            "acquisition_method": method,
            "acquisition_timestamp": source.get("retrieved_at"),
            "evidence_intake_timestamp": self.received_at,
            "acquisition_timestamp_status": "recorded"
            if source.get("retrieved_at")
            else "not_recorded_do_not_infer_from_publication_date",
            "http_status": source.get("http_status"),
            "resolved_url": source.get("resolved_url"),
            "parser_version": parsed.get("parser_version", "sealed_h1_owned_body_v2"),
            "links": parsed.get("original_links", source.get("body_links", [])),
            "assets": parsed.get("assets", source.get("source_assets", [])),
            "warnings": parsed.get("warnings", []),
            **asset,
            "evidence": evidence,
        }
        self.captures[identity] = item
        if identity not in row["capture_ids"]:
            row["capture_ids"].append(identity)
        return item


def reference_map(source, draft, captures):
    links = []
    for capture in captures:
        for link in capture["links"]:
            label = link.get("label", "")
            target = next(
                (
                    b["id"]
                    for s in draft["sections"]
                    for b in s["blocks"]
                    if label and label in b["text"]
                ),
                None,
            )
            row = {
                "source_snapshot_id": capture["snapshot_id"],
                "source_url": capture["url"],
                "original_href": link.get("original_href") or link["url"],
                "url": link["url"],
                "label": label,
                "target_block_id": target,
                "verification_state": "not_verified",
            }
            if row not in links:
                links.append(row)
    return {
        "article_id": draft["article_id"],
        "locale": draft["locale"],
        "expected_revision": 1,
        "map": {
            "capture_status": "complete",
            "sources": [
                {k: c[k] for k in ("snapshot_id", "body_sha256", "raw_html_sha256")}
                for c in captures
            ],
            "links": links,
            "media_reuse": "not_authorized",
            "legal_verification": "not_inferred_from_links",
        },
    }


def prepare_independent(bundle, registry):
    existing = json.loads(
        (BASE / "prepared/other-titles-inventory.json").read_text(encoding="utf-8")
    )
    existing_by_source = defaultdict(list)
    for row in existing:
        for sid in row["source_ids"]:
            existing_by_source[sid].append(row["article_id"])
    existing_body = defaultdict(list)
    for sid, ids in existing_by_source.items():
        source = bundle.sources.get(sid)
        if source and source.get("body_sha256"):
            existing_body[(source["language"], source["body_sha256"])].extend(ids)
    mappings, queue, candidates = [], [], []
    for row in bundle.master.values():
        captures = [bundle.captures[c] for c in row["capture_ids"]]
        full = [
            c
            for c in captures
            if c["completeness"] == "complete_owned_article_container"
            and c["raw_html_asset"]
        ]
        if row["publisher"] != "radmohajer.ir":
            continue
        # Organization/contact pages have an owned body too. Ownership alone
        # does not turn them into independent country knowledge articles.
        if (
            urlsplit(row["url"])
            .path.rstrip("/")
            .lower()
            .endswith(("/about-us", "/contact-us"))
        ):
            for capture in full:
                mappings.append(
                    {
                        "capture_id": capture["capture_id"],
                        "source_id": row["source_id"],
                        "disposition": "legitimately_excluded_company_contact_or_promotion_original_preserved",
                    }
                )
            continue
        versions = {c["body_sha256"] for c in full}
        for capture in full:
            sid = capture["source_id"]
            prior = bundle.sources.get(sid)
            old_ids = existing_by_source.get(sid, [])
            if old_ids and prior and prior["body_sha256"] == capture["body_sha256"]:
                mappings.append(
                    {
                        "capture_id": capture["capture_id"],
                        "source_id": sid,
                        "article_ids": old_ids,
                        "disposition": "existing_full_independent_article_unchanged",
                    }
                )
            elif old_ids or len(versions) > 1:
                queue.append(
                    {
                        "capture_id": capture["capture_id"],
                        "source_id": sid,
                        "reason": "same_url_different_body_requires_version_review",
                        "existing_article_ids": old_ids,
                        "raw_html_asset": capture["raw_html_asset"],
                        "body_sha256": capture["body_sha256"],
                        "state": "human_review_required",
                    }
                )
                mappings.append(
                    {
                        "capture_id": capture["capture_id"],
                        "source_id": sid,
                        "disposition": "full_source_version_review_candidate",
                    }
                )
            elif (capture["language"], capture["body_sha256"]) in existing_body:
                mappings.append(
                    {
                        "capture_id": capture["capture_id"],
                        "source_id": sid,
                        "article_ids": sorted(
                            set(
                                existing_body[
                                    (capture["language"], capture["body_sha256"])
                                ]
                            )
                        ),
                        "disposition": "exact_body_alias_provenance_review_no_duplicate_import",
                    }
                )
                queue.append(
                    {
                        "capture_id": capture["capture_id"],
                        "source_id": sid,
                        "reason": "attach_alias_provenance_only_after_editorial_review",
                        "state": "human_review_required",
                    }
                )
            else:
                candidates.append(capture)
    groups = defaultdict(list)
    for capture in candidates:
        groups[
            (capture["language"], capture["body_sha256"], capture["structure_sha256"])
        ].append(capture)
    prepared, maps = [], []
    for group in sorted(
        groups.values(), key=lambda values: min(c["source_id"] for c in values)
    ):
        # Repeated captures of the identical source need one snapshot, not a
        # duplicate import or duplicate provenance entry.
        unique = {}
        for capture in sorted(
            group,
            key=lambda c: (c["source_id"], c["acquisition_method"], c["capture_id"]),
        ):
            unique.setdefault(capture["source_id"], capture)
        captures = list(unique.values())
        first = captures[0]
        country = country_evidence(first["title"], first["url"], first["body_text"])
        source = {
            **first,
            "domain": "radmohajer.ir",
            "taxonomy": {"country_codes": country["country_codes"]},
            "retrieved_at": first["acquisition_timestamp"]
            or first["evidence_intake_timestamp"],
        }
        if len(source["title"]) > 300:
            queue.append(
                {
                    "capture_id": first["capture_id"],
                    "reason": "original_title_exceeds_closed_CMS_contract_requires_review",
                    "state": "human_review_required",
                }
            )
            continue
        draft = make_draft(source)
        for other in captures[1:]:
            mirror = make_draft(
                {
                    **other,
                    "domain": "radmohajer.ir",
                    "taxonomy": {"country_codes": country["country_codes"]},
                }
            )
            for original_section, mirror_section in zip(
                draft["sections"], mirror["sections"], strict=True
            ):
                for original, mirrored in zip(
                    original_section["blocks"], mirror_section["blocks"], strict=True
                ):
                    original["provenance"].extend(mirrored["provenance"])
            draft["source_ids"].append(other["source_id"])
            draft["source_urls"].append(other["url"])
        draft["source_recovery"] = {
            "capture_ids": [c["capture_id"] for c in group],
            "country_evidence": country,
            "historical_claims_require_official_verification": True,
            "mohajer_remains_independent": True,
        }
        source_map = {
            c["source_id"]: {
                **c,
                "domain": "radmohajer.ir",
                "language": draft["locale"],
                "retrieved_at": c["acquisition_timestamp"]
                or c["evidence_intake_timestamp"],
                "raw_html_sha256": c["raw_html_sha256"],
            }
            for c in captures
        }
        # The real local evidence-intake time satisfies the storage contract;
        # it is explicitly NOT represented as the original HTTP capture time.
        missing_times = [c for c in captures if not c["acquisition_timestamp"]]
        data = payload(draft, source_map, registry)
        data["import_readiness"] = (
            "technical_draft_only"
            if data["status"] == "technical_draft_only"
            else "blocked_contract"
        )
        for source_item in data.get("sources", []):
            c = source_map[source_item["source_id"]]
            source_item["source_evidence"] = {
                "original_http_capture_time": c["acquisition_timestamp"],
                "local_evidence_intake_time": c["evidence_intake_timestamp"],
                "retrieved_at_semantics": "recorded_original_capture"
                if c["acquisition_timestamp"]
                else "local_preserved_cache_intake_not_original_HTTP_fetch",
                "original_http_status": c["http_status"],
                "capture_method": c["acquisition_method"],
                "original_evidence": c["evidence"],
                "factual_verification": "not_verified",
                "original_acquisition_time_unconfirmed": not bool(
                    c["acquisition_timestamp"]
                ),
            }
        prepared.append(data)
        maps.append(reference_map(source, draft, captures))
        for capture in group:
            mappings.append(
                {
                    "capture_id": capture["capture_id"],
                    "source_id": capture["source_id"],
                    "article_ids": [draft["article_id"]],
                    "disposition": "independent_other_titles_draft",
                    "import_readiness": data["import_readiness"],
                }
            )
        queue.append(
            {
                "article_id": draft["article_id"],
                "source_ids": draft["source_ids"],
                "country_codes": draft["country_codes"],
                "reason": "all recovered Mohajer articles remain independent; verify historic legal claims, country scope, completeness and media rights before any approval",
                "country_evidence": country,
                "acquisition_timestamp_missing": bool(missing_times),
                "state": "human_review_required",
                "publication_allowed": False,
            }
        )
    return prepared, maps, mappings, queue


def recompose(directory):
    """Portable replay from immutable capture evidence, with no external paths."""
    bundle = Bundle(
        directory, read_jsonl(CORPUS / "sources.jsonl.gz"), "2026-10-28T09:30:43Z"
    )
    bundle.master = {
        r["url"]: r for r in read_jsonl(directory / "source-master.jsonl.gz")
    }
    bundle.captures = {
        c["capture_id"]: c for c in read_jsonl(directory / "source-captures.jsonl.gz")
    }
    registry = json.loads(
        Path("supabase/contracts/rad_v1.json").read_text(encoding="utf-8")
    )
    drafts, maps, mappings, review = prepare_independent(bundle, registry)
    for filename, rows in (
        ("other-titles-draft-payloads.jsonl.gz", drafts),
        ("other-titles-reference-maps.jsonl.gz", maps),
        ("supplementary-destination-map.jsonl.gz", mappings),
        ("human-review-queue.jsonl.gz", review),
    ):
        write_jsonl(directory / filename, rows)
    by_source = defaultdict(list)
    for row in mappings:
        by_source[row["source_id"]].append(row)
    for row in bundle.master.values():
        if row["source_id"] in by_source:
            row["destinations"] = by_source[row["source_id"]]
        classify_exclusion(row)
    write_jsonl(
        directory / "source-master.jsonl.gz",
        sorted(bundle.master.values(), key=lambda r: r["url"]),
    )
    summary_path = directory / "source-integrity-summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    summary["new_independent_draft_candidates"] = len(drafts)
    summary["source_recovery_status"] = dict(
        Counter(r["recovery_status"] for r in bundle.master.values())
    )
    summary["new_draft_import_readiness"] = dict(
        Counter(d["import_readiness"] for d in drafts)
    )
    summary["contract_rejected_candidates"] = sum(
        d["status"] != "technical_draft_only" for d in drafts
    )
    save_json(summary_path, summary)


def classify_exclusion(row):
    if (row.get("original_classification") or "").endswith("_excluded") and row[
        "recovery_status"
    ] != "full_body_and_verified_raw":
        row["recovery_status"] = (
            "excluded_noneditorial_query_stateful_or_legacy_template_route"
        )
        row["content_completeness"] = "not_an_established_substantive_article"
        row["destinations"] = [
            {
                "disposition": "legitimately_excluded_noneditorial_route",
                "rule": row["original_classification"],
            }
        ]
        row["follow_up"] = (
            "retain exact exclusion evidence; do not crawl stateful/noneditorial routes or count them as missing articles"
        )


def add_observations(bundle, observations, cache, method):
    """Preserve dated attempts and verified raw captures without overwriting history."""
    selected = {
        (s["source_id"], s["body_sha256"])
        for s in read_jsonl(BASE / "prepared/source-intake.jsonl.gz")
    }
    for record in observations:
        row = bundle.source(record["url"])
        observation = {k: v for k, v in record.items() if k != "extraction"}
        observation["source_id"] = row["source_id"]
        observation["evidence_origin"] = method
        bundle.observations.append(observation)
        row["last_known_http_status"] = record.get("status")
        row["last_known_fetch_error"] = record.get("error")
        if record.get("fetch_status") != "fetched":
            continue
        path = confined(
            cache, record.get("raw_cache_file") or record["id"] + ".html.gz"
        )
        raw = gzip.decompress(path.read_bytes())
        if sha(raw) != record["raw_sha256"]:
            raise ValueError("observation_raw_hash_mismatch")
        if row["publisher"] == "radmohajer.ir":
            parsed_page = parse_mohajer(raw, row["url"])
            versions = parsed_page["articles"] or [
                {
                    "title": parsed_page["title"],
                    "body_text": "",
                    "blocks": [],
                    "completeness": parsed_page["page_kind"],
                }
            ]
        else:
            parsed = dict(record.get("extraction") or {})
            prior = bundle.sources.get(row["source_id"], {})
            known_full = (
                row["source_id"],
                digest(parsed.get("body_text", "")),
            ) in selected
            known_full |= bool(
                prior.get("body_text")
                and prior.get("consolidation_disposition")
                == "body_ready_for_unreviewed_composition"
                and prior["body_text"] == parsed.get("body_text")
            )
            parsed["completeness"] = (
                "complete_owned_article_container"
                if known_full
                else "frozen_nonarticle_or_incomplete_requires_review"
            )
            versions = [parsed]
        for parsed in versions:
            bundle.capture(
                {
                    "url": row["url"],
                    "language": parsed.get("language") or "fa",
                    "retrieved_at": record.get("retrieved_at"),
                    "http_status": record.get("status"),
                    "resolved_url": record.get("final_url"),
                },
                parsed,
                method,
                raw,
                original_observation=observation,
            )


def build(
    reference_root,
    antigravity_root,
    intake,
    caches,
    output,
    received_at,
    network_observations=None,
    network_cache=None,
):
    if (
        not received_at.endswith("Z")
        or datetime.fromisoformat(received_at.replace("Z", "+00:00"))
        .utcoffset()
        .total_seconds()
        != 0
    ):
        raise ValueError("actual_UTC_evidence_intake_time_required")
    output.mkdir(parents=True, exist_ok=True)
    sources = read_jsonl(CORPUS / "sources.jsonl.gz")
    bundle = Bundle(output, sources, received_at)
    input_manifest = []
    for name in REFERENCES:
        path = reference_root / "_audit" / name
        if path.is_file():
            data = path.read_bytes()
            relative = Path("reference-evidence") / name
            target = output / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            input_manifest.append(
                {"reference": name, "sha256": sha(data), "asset": relative.as_posix()}
            )
        else:
            input_manifest.append({"reference": name, "status": "missing"})
    # Preserve all frozen bodies, even those whose current HTTP observations fail.
    for source in sources:
        raw = None
        for cache in caches:
            path = confined(cache, source["collector_id"] + ".html.gz")
            if path.is_file():
                candidate = gzip.decompress(path.read_bytes())
                if sha(candidate) == source.get("raw_html_sha256"):
                    raw = candidate
                    break
        if source.get("body_text") or raw is not None:
            parsed = {
                **source,
                "completeness": "complete_owned_article_container"
                if source["consolidation_disposition"]
                == "body_ready_for_unreviewed_composition"
                else "frozen_nonarticle_or_incomplete_requires_review",
            }
            bundle.capture(
                source,
                parsed,
                "preserved_frozen_original",
                raw,
                original_body_status=source["body_status"],
                raw_hash_verified=raw is not None,
            )
    recovered_path = (
        antigravity_root / "_scratch/recovered_radmohajer_articles.jsonl.gz"
    )
    records = read_jsonl(recovered_path)
    for record in records:
        path = confined(antigravity_root, record["html_cache_path"])
        raw = gzip.decompress(path.read_bytes())
        if sha(raw) != record["raw_sha256"]:
            raise ValueError("antigravity_raw_hash_mismatch:" + record["url"])
        parsed = parse_mohajer(raw, record["url"])
        row = bundle.source(record["url"])
        row["last_known_page_kind"] = parsed["page_kind"]
        row["antigravity_extraction"] = {
            "reported_blocks": record["blocks_count"],
            "reported_body_chars": record["body_text_len"],
            "raw_sha256_verified": True,
            "source_type": record["source_type"],
        }
        # A local cache timestamp is not proof of when a live/archived page was fetched.
        for article in parsed["articles"]:
            bundle.capture(
                {"url": record["url"], "language": "fa"},
                article,
                "antigravity_" + record["source_type"].lower(),
                raw,
                reported_body_sha256=digest(record["body_text"]),
                declared_canonical_url=parsed["declared_canonical_url"],
                publication_dates=parsed["dates"],
            )
        if not parsed["articles"]:
            bundle.capture(
                {"url": record["url"], "language": "fa"},
                {
                    "title": parsed["title"],
                    "body_text": "",
                    "blocks": [],
                    "completeness": parsed["page_kind"],
                },
                "antigravity_" + record["source_type"].lower(),
                raw,
            )
        for excerpt in parsed["listing_excerpts"]:
            child = bundle.source(excerpt["url"])
            evidence = {
                **excerpt,
                "source_id": child["source_id"],
                "observed_on": row["url"],
                "raw_html_sha256": sha(raw),
                "raw_html_asset": bundle.raw_asset(raw)["raw_html_asset"],
                "disposition": "partial_excerpt_requires_full_source_or_editorial_review",
            }
            bundle.listing_excerpts.append(evidence)
    qa = reference_root / "_audit/RAD_CROSS_AGENT_HASH_QA_20261028"
    verification = json.loads(
        (qa / "LOCAL_REFETCH_PARTIAL_VERIFICATION.json").read_text(encoding="utf-8-sig")
    )
    for record in verification["verified_files"]:
        raw = confined(
            intake / "recovered_bodies_radmohajer", record["html_file"]
        ).read_bytes()
        original_text = confined(
            intake / "recovered_bodies_radmohajer", record["text_file"]
        ).read_bytes()
        normalized = (
            original_text.decode("utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
        )
        if (
            sha(raw) != record["html_sha256"]
            or sha(original_text) != record["text_on_disk_sha256"]
            or sha(normalized.encode("utf-8")) != record["text_normalized_sha256"]
        ):
            raise ValueError("fresh_refetch_pair_hash_mismatch")
        text_asset = Path("assets/original-text") / (sha(original_text)[:20] + ".txt")
        target = output / text_asset
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(original_text)
        parsed = parse_mohajer(raw, record["source_url"])
        for article in parsed["articles"]:
            bundle.capture(
                {"url": record["source_url"], "language": "fa"},
                article,
                "new_windows_live_refetch_not_grok_original",
                raw,
                file_modified_utc=record["file_modified_utc"],
                original_txt_asset=text_asset.as_posix(),
                original_txt_sha256=record["text_on_disk_sha256"],
                txt_lf_sha256=record["text_normalized_sha256"],
                txt_is_whole_page_not_article_only=True,
            )
    add_observations(
        bundle,
        read_jsonl(BASE / "source-resume/capture.jsonl.gz"),
        BASE / "source-resume/cache",
        "preserved_20261027_source_resume",
    )
    if network_observations:
        if not network_cache:
            raise ValueError("network_cache_required")
        add_observations(
            bundle,
            read_jsonl(network_observations),
            network_cache,
            "targeted_public_GET_20261028",
        )
    registry = json.loads(
        Path("supabase/contracts/rad_v1.json").read_text(encoding="utf-8")
    )
    drafts, maps, mappings, review = prepare_independent(bundle, registry)
    by_capture = {m["capture_id"]: m for m in mappings}
    for row in bundle.master.values():
        caps = [bundle.captures[c] for c in row["capture_ids"]]
        full = [
            c for c in caps if c["completeness"] == "complete_owned_article_container"
        ]
        raw = any(c["raw_html_asset"] for c in caps)
        row["recovery_status"] = (
            "full_body_and_verified_raw"
            if full and raw
            else (
                "full_body_only_raw_missing"
                if full
                else (
                    "raw_without_complete_article"
                    if raw
                    else "unavailable_or_unfetched"
                )
            )
        )
        row["body_versions"] = sorted({c["body_sha256"] for c in full})
        row["same_url_different_content"] = len(row["body_versions"]) > 1
        row["destinations"] = [
            by_capture[c] for c in row["capture_ids"] if c in by_capture
        ]
        row["source_family"] = (
            "independent_mohajer"
            if row["publisher"] == "radmohajer.ir"
            else "primary_rad_visa"
        )
        row["follow_up"] = (
            "human editorial and current factual verification"
            if full
            else "inspect retained raw/partial evidence or obtain an authorized complete source capture; never bypass access controls"
        )
        row["content_completeness"] = (
            "full_owned_body"
            if full
            else (
                "partial_listing_excerpt_only"
                if any(
                    e["source_id"] == row["source_id"] for e in bundle.listing_excerpts
                )
                else "no_complete_substantive_body"
            )
        )
        row["duplication_status"] = (
            "same_url_different_content_review"
            if row["same_url_different_content"]
            else "see_duplicate_ledger"
        )
        if not row["destinations"]:
            row["destinations"] = [
                {
                    "disposition": "prior_primary_mapping_see_source_section_ledger"
                    if row["publisher"] != "radmohajer.ir" and full
                    else "human_review_full_source"
                    if full
                    else "nonarticle_or_unresolved_evidence_see_blocker_register"
                }
            ]
        classify_exclusion(row)
    output_files = {
        "source-captures.jsonl.gz": list(bundle.captures.values()),
        "source-master.jsonl.gz": sorted(
            bundle.master.values(), key=lambda r: r["url"]
        ),
        "listing-excerpts.jsonl.gz": bundle.listing_excerpts,
        "other-titles-draft-payloads.jsonl.gz": drafts,
        "other-titles-reference-maps.jsonl.gz": maps,
        "supplementary-destination-map.jsonl.gz": mappings,
        "human-review-queue.jsonl.gz": review,
        "source-access-observations.jsonl.gz": bundle.observations,
    }
    for filename, rows in output_files.items():
        write_jsonl(output / filename, rows)
    save_json(output / "reference-input-manifest.json", input_manifest)
    summary = {
        "frozen_source_records": len(sources),
        "master_sources": len(bundle.master),
        "capture_versions": len(bundle.captures),
        "antigravity_raw_records_verified": len(records),
        "new_live_refetch_pairs_verified": len(verification["verified_files"]),
        "listing_excerpts_preserved": len(bundle.listing_excerpts),
        "new_independent_draft_candidates": len(drafts),
        "contract_rejected_candidates": sum(
            d["status"] != "technical_draft_only" for d in drafts
        ),
        "source_recovery_status": dict(
            Counter(r["recovery_status"] for r in bundle.master.values())
        ),
        "new_draft_import_readiness": dict(
            Counter(d["import_readiness"] for d in drafts)
        ),
        "original_grok_package_transferred": False,
        "offline_builder_network_requests": 0,
        "targeted_network_observations": str(network_observations)
        if network_observations
        else None,
        "hosted_writes": 0,
        "publication_allowed": False,
    }
    save_json(output / "source-integrity-summary.json", summary)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-root", type=Path, required=True)
    parser.add_argument("--antigravity-root", type=Path, required=True)
    parser.add_argument("--intake", type=Path, required=True)
    parser.add_argument("--cache", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--network-observations", type=Path)
    parser.add_argument("--network-cache", type=Path)
    parser.add_argument(
        "--evidence-received-at",
        required=True,
        help="Actual UTC time this local evidence intake began; pin the same value for reproduction.",
    )
    args = parser.parse_args()
    print(
        json.dumps(
            build(
                args.reference_root,
                args.antigravity_root,
                args.intake,
                args.cache,
                args.output,
                args.evidence_received_at,
                args.network_observations,
                args.network_cache,
            )
        )
    )


if __name__ == "__main__":
    main()
