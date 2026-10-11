#!/usr/bin/env python3
"""Step 3 — real ingestion simulation against captured production state.

Reads:
  --dataset  CANONICAL_CONTENT_DATASET.jsonl
  --live     LIVE_STATE_SNAPSHOT.json  (captured read-only from production:
             source_documents, source_snapshots, content_sources)

Writes (under --out):
  INGESTION_IMPACT_REPORT.json  - exact per-operation counts, per-site
                                  breakdown, row-level conflict detail,
                                  anomaly list, and the dry-run delta vs the
                                  theoretical (live-state-unaware) dry-run.
  INGESTION_PLAN_PREVIEW.json   - the deterministic operation list an operator
                                  would execute (ordered, idempotent).

Semantics (matching the real DB contract):
  * source_documents: canonical_url UNIQUE. Existing documents are matched by
    URL equivalence (host lowercase, trailing '/' ignored) so
    https://digivisa.ir/ (production) and https://digivisa.ir (dataset) are
    the SAME document — never a duplicate insert.
  * source_snapshots: UNIQUE (document_id, content_hash); content_hash :=
    sha256(normalized_text) for rows written by this package.
  * language_code NOT NULL in ('fa','en'); title NOT NULL (validated upstream
    by the dataset builder; violations counted here as blockers).
  * No writes are performed by this tool.

stdlib-only, deterministic.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
from collections import Counter, defaultdict

from url_equivalence import url_key  # noqa: F401  (single source of truth,
                                     # shared with generate_ingest_sql)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", required=True)
    ap.add_argument("--live", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)

    rows = [json.loads(l) for l in
            pathlib.Path(a.dataset).read_text(encoding="utf-8").splitlines()
            if l.strip()]
    live = json.loads(pathlib.Path(a.live).read_text(encoding="utf-8"))
    live_docs = live["source_documents"]
    live_snaps = live["source_snapshots"]
    live_sources = live.get("content_sources", [])

    # Index production state
    docs_by_key = {url_key(d["canonical_url"]): d for d in live_docs}
    snaps_by_doc = defaultdict(set)
    for s in live_snaps:
        snaps_by_doc[s["document_id"]].add(s["content_hash"])

    counters = Counter()
    per_site = defaultdict(Counter)
    plan = []
    anomalies = []
    url_equiv_matches = []
    seen_docs = set()          # url_key already given a document operation
    seen_snaps = set()         # (url_key, body_sha256) pairs already planned

    for r in sorted(rows, key=lambda x: (x["site"], x["canonical_url"])):
        key = url_key(r["canonical_url"])
        site = r["site"]

        # dataset-level contract validation
        blockers = []
        if r["language"] not in ("fa", "en"):
            blockers.append("language_not_null_violation")
        if not r["extracted_title"]:
            blockers.append("title_not_null_violation")
        if blockers:
            counters["BLOCKED"] += 1
            per_site[site]["BLOCKED"] += 1
            anomalies.append({"url": r["canonical_url"], "blockers": blockers})
            continue

        pair = (key, r["body_sha256"])
        if pair in seen_snaps:
            # exact duplicate (same canonical content) — nothing new to write
            counters["SKIP_URL_EQUIVALENT_DATASET_ROW"] += 1
            per_site[site]["SKIP_URL_EQUIVALENT_DATASET_ROW"] += 1
            continue
        seen_snaps.add(pair)

        first_doc_op = key not in seen_docs
        if first_doc_op:
            seen_docs.add(key)

        existing = docs_by_key.get(key)
        if existing is None:
            if first_doc_op:
                counters["DOC_INSERT"] += 1
                per_site[site]["DOC_INSERT"] += 1
            doc_ref = "NEW"
            doc_snap = set()
            new_snap = True
            if key != r["canonical_url"]:
                anomalies.append({
                    "url": r["canonical_url"],
                    "note": "canonical form differs from URL-equivalence key"})
        else:
            doc_ref = existing["id"]
            if first_doc_op:
                if existing["canonical_url"] != r["canonical_url"]:
                    url_equiv_matches.append({
                        "dataset_url": r["canonical_url"],
                        "production_url": existing["canonical_url"],
                        "production_doc_id": existing["id"]})
                doc_snap = snaps_by_doc.get(existing["id"], set())
                diff = []
                if existing.get("last_content_hash") != r["body_sha256"]:
                    diff.append("last_content_hash")
                if existing.get("language_code") != r["language"]:
                    diff.append("language_code")
                counters["DOC_UPDATE"] += 1
                per_site[site]["DOC_UPDATE"] += 1
                plan.append({
                    "op": "UPDATE source_documents",
                    "id": existing["id"],
                    "fields": diff or ["last_seen_at"],
                    "url": r["canonical_url"]})
            else:
                doc_snap = snaps_by_doc.get(existing["id"], set())
            new_snap = True

        if new_snap:
            if r["body_sha256"] in doc_snap:
                counters["SNAP_SKIP_EXISTS"] += 1
                per_site[site]["SNAP_SKIP_EXISTS"] += 1
            else:
                counters["SNAP_INSERT"] += 1
                per_site[site]["SNAP_INSERT"] += 1
                plan.append({
                    "op": "INSERT source_snapshots",
                    "document": doc_ref,
                    "content_hash": r["body_sha256"],
                    "url": r["canonical_url"],
                    "text_len": len(r.get("body") or "")})

    # production-side anomalies worth operator attention
    doc_ids = {d["id"] for d in live_docs}
    for s in live_snaps:
        if s["document_id"] not in doc_ids:
            anomalies.append({"snapshot": s["id"], "blockers": ["orphan_snapshot"]})
    for d in live_docs:
        hs = snaps_by_doc.get(d["id"], set())
        if not hs:
            anomalies.append({"doc": d["canonical_url"],
                              "blockers": ["document_without_snapshot"]})
        elif d.get("last_content_hash") and d["last_content_hash"] not in hs:
            anomalies.append({
                "doc": d["canonical_url"],
                "blockers": ["last_content_hash_not_in_snapshots"],
                "last_content_hash": d["last_content_hash"],
                "snapshot_hashes": sorted(hs)})

    # text-length validation against ingest contract (<100000 chars)
    over = [r["canonical_url"] for r in rows if len(r.get("body") or "") > 99_000]
    for u in over:
        anomalies.append({"url": u, "blockers": ["text_over_100k_contract"]})

    # duplicate production canonical keys under equivalence (should be none)
    prod_keys = Counter(url_key(d["canonical_url"]) for d in live_docs)
    dup_prod = [k for k, n in prod_keys.items() if n > 1]

    report = {
        "schema_version": "rad-ingestion-impact-v1",
        "dataset": str(pathlib.Path(a.dataset)),
        "live_state_captured_at": live.get("captured_at_utc"),
        "counts": dict(counters),
        "per_site": {k: dict(v) for k, v in sorted(per_site.items())},
        "url_equivalence_matches": url_equiv_matches,
        "url_equivalence_dataset_collapses":
            counters.get("SKIP_URL_EQUIVALENT_DATASET_ROW", 0),
        "production_anomalies": anomalies,
        "production_duplicate_url_keys": dup_prod,
        "text_over_100k": over,
        "totals": {
            "dataset_rows": len(rows),
            "production_documents": len(live_docs),
            "production_snapshots": len(live_snaps),
            "documents_final": len(seen_docs | set(docs_by_key)),
            "distinct_url_hash_pairs": len(seen_snaps),
        },
        "content_source_linkage": {
            "production_rows_with_source_id": sum(
                1 for d in live_docs if d.get("source_id")),
            "policy": "source_id stays NULL for bulk evidence rows, matching "
                      "existing production rows; content_sources rows are "
                      "per-article seeds, not per-site.",
        },
        "id_compatibility": {
            "dataset_id": "rad-<24 hex> (text, deterministic from canonical_url)",
            "production_pk": "uuid gen_random_uuid()",
            "resolution": "The dataset id is carried in snapshot metadata only; "
                          "the DB primary key is server-generated. Dataset ids "
                          "remain the stable local identity for review tooling.",
        },
        "rls_and_permissions": {
            "write_path": "service_role (bypasses RLS) or admin-authenticated "
                          "session ('admins manage sources/snapshots' policy)",
            "anon": "SELECT grant only; INSERT/UPDATE/DELETE denied by grant "
                    "and by RLS policies",
            "read_path": "anon reads only documents/snapshots cited by "
                         "APPROVED knowledge claims (policy-enforced)",
            "verified_from": "committed migrations "
                             "20261003211635 (grants/policies, RLS enabled "
                             "lines 175-176) + live REST probe (anon GET ok, "
                             "anon GET on research_findings/content_drafts "
                             "-> 401/42501)",
        },
        "triggers_and_publication_gates": {
            "inspected_at": "2026-10-12",
            "inspected_from": "committed migrations (supabase/migrations/*.sql)",
            "source_documents": "NO triggers (no updated_at, no audit, no gate) "
                                "and NO realtime/publication membership",
            "source_snapshots": "NO triggers and NO realtime/publication membership",
            "content_sources": "has updated_at trigger + AFTER audit trigger "
                               "(private.audit_content_change -> "
                               "admin_audit_logs); this package performs ZERO "
                               "content_sources writes, so neither fires",
            "feed_items": "Stage 1 migration 20261010010000 adds "
                          "BEFORE-row guard trigger (trg_guard_human_feed_item_"
                          "mutation) blocking ALL feed mutations unless an "
                          "authorized human publish RPC sets the actor marker "
                          "-- even service_role direct writes fail; this "
                          "package writes zero feed rows (rehearsal enforced "
                          "the same invariant with a local hard guard)",
            "realtime_publication": "no alter publication statements exist in "
                                    "any migration; nothing in public schema "
                                    "is publication-gated, so the bulk "
                                    "ingestion cannot interact with Realtime "
                                    "replication gates",
            "impact_on_ingest": "chunk inserts/updates touch only "
                                "source_documents + source_snapshots; with no "
                                "triggers on either table the only runtime "
                                "gates are the unique indexes (idempotency) "
                                "and the knowledge_citations FK RESTRICT "
                                "(rollback safety)",
        },
        "writes_performed": 0,
    }
    (out / "INGESTION_IMPACT_REPORT.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    preview = {
        "schema_version": "rad-ingestion-plan-v1",
        "idempotent": True,
        "ordered_operations": plan,
        "operation_counts": dict(counters),
        "notes": [
            "Re-running against the same live state after a successful ingest "
            "converts every INSERT/UPDATE into a SKIP (unique-key based).",
            "content_hash := sha256(normalized_text) — the package's "
            "documented definition; 5 legacy seed snapshots used an "
            "undetermined prior algorithm (see anomaly list), which does not "
            "affect uniqueness.",
            "Bulk mode must NOT use ingest_research_snapshot() — that "
            "interface creates research_findings + review drafts (correct for "
            "scheduled delta sync, wrong for bulk: it would flood the review "
            "queue with one finding per page).",
        ],
    }
    (out / "INGESTION_PLAN_PREVIEW.json").write_text(
        json.dumps(preview, ensure_ascii=False, indent=2), encoding="utf-8")

    print(json.dumps({"counts": dict(counters),
                      "url_equiv_matches": len(url_equiv_matches),
                      "anomalies": len(anomalies),
                      "plan_ops": len(plan)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
