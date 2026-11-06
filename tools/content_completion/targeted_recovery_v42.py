"""Bounded first-party recovery through the existing DNS-pinned robots fetcher."""

from __future__ import annotations

import argparse
import copy
import gzip
import hashlib
import json
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import urljoin, urlsplit

from scripts.research_egress import EgressError, ProtectedFetcher, pinned_request
from tools.content_completion.full_recovery_v4 import (
    capture_from_raw,
    composition_source,
)
from tools.content_completion.source_limitations_v42 import (
    _raw_path,
    capture_disposition,
)
from tools.plan3_content.crawl import stable_id
from tools.plan3_content.dataset import read_jsonl, write_jsonl
from tools.plan3_content.parser import HOSTS


def validate_exact_scope(rows, ledger):
    expected = {(r["source_id"], r["url"]) for r in ledger}
    actual = {(r.get("source_id"), r.get("url")) for r in rows}
    if (
        len(ledger) != 421
        or len(expected) != 421
        or len(rows) != 421
        or actual != expected
        or any(r.get("disposition") != "SOURCE_UNRESOLVED" for r in ledger)
        or any(r["source_id"] != stable_id(r["url"]) for r in ledger)
    ):
        raise ValueError("exact_421_original_url_scope_required")


def verified_disposition_input(path, source_manifest_sha256, ledger_sha256):
    producer = json.loads(path.with_name("manifest.json").read_text(encoding="utf8"))
    if (
        producer.get("source_input_manifest_sha256") != source_manifest_sha256
        or producer.get("unresolved_ledger_sha256") != ledger_sha256
    ):
        raise ValueError("disposition_producer_original_scope_binding_required")
    if path.name not in producer.get("files", {}):
        raise ValueError("disposition_producer_file_hash_required")
    for name, expected in producer["files"].items():
        if hashlib.sha256((path.parent / name).read_bytes()).hexdigest() != expected:
            raise ValueError("disposition_producer_file_hash_mismatch")
    return producer


def verify_local_capture_reuse(rows, captures, complete_sources, roots):
    """Reprove each reused identity from its exact sealed original capture."""
    needed = {
        (r["source_id"], r["url"]): r
        for r in rows
        if r["disposition"] in {"RECOVERED_FULL_BODY", "REPRESENTED_DUPLICATE"}
    }
    verified = set()
    for capture in captures:
        key = (capture["source_id"], capture["url"])
        if key not in needed or key in verified:
            continue
        row = needed[key]
        if capture["capture_id"] not in row.get("original_capture_ids", []):
            continue
        asset = _raw_path(capture["raw_html_asset"], roots)
        proof = capture_disposition(
            capture, gzip.decompress(asset.read_bytes()), complete_sources
        )
        required = (
            "VERIFIED_COMPLETE_OWNED_BODY"
            if row["disposition"] == "RECOVERED_FULL_BODY"
            else "VERIFIED_EXACT_CAPTURE_ALIAS"
        )
        if proof["disposition"] == required:
            verified.add(key)
    if verified != set(needed):
        raise ValueError("verified_local_capture_receipt_required")
    return verified


def record_evidence_intake(candidates, output, receipt_sha256):
    """Record this local intake once; never guess historical HTTP acquisition."""
    path = output / "evidence-intake.json"
    if path.exists():
        receipt = json.loads(path.read_text(encoding="utf8"))
        if receipt["candidate_receipt_sha256"] != receipt_sha256:
            raise ValueError("delta_evidence_intake_input_changed")
    else:
        receipt = {
            "candidate_receipt_sha256": receipt_sha256,
            "evidence_intake_timestamp": datetime.now(UTC).isoformat(),
            "semantics": "recorded_local_evidence_intake_not_original_HTTP_fetch",
        }
        path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf8")
    result = copy.deepcopy(candidates)
    for row in result:
        if not row.get("retrieved_at") and not row.get("acquisition_timestamp"):
            row.update(
                acquisition_timestamp=None,
                acquisition_timestamp_status="not_recorded_in_original_capture",
                evidence_intake_timestamp=receipt["evidence_intake_timestamp"],
                retrieved_at=receipt["evidence_intake_timestamp"],
                retrieved_at_semantics=receipt["semantics"],
            )
    return result


def prepare_delta(candidates_path, baseline, output, runtime=None):
    """Compose only proved new identities; never replace a partial existing body.

    Optional execution is limited by the existing exact owned-native marker.
    Every operation and retry is enclosed in a transaction that rolls back.
    """
    from tools.content_completion.full_audit_v4 import audit
    from tools.content_completion.full_pipeline_v4 import (
        compile_operations,
        compose_all,
    )
    from tools.content_completion.v4_corpus_rehearsal import HEAD_QUERY, SOURCE_QUERY
    from tools.content_completion.v4_local_import import connection

    candidates = read_jsonl(candidates_path)
    if not candidates:
        raise ValueError("proved_recovered_candidates_required")
    if len({r["source_id"] for r in candidates}) != len(candidates):
        raise ValueError("multiple_versions_require_complete_source_reconciliation")
    output.mkdir(parents=True, exist_ok=True)
    candidates = record_evidence_intake(
        candidates, output, hashlib.sha256(candidates_path.read_bytes()).hexdigest()
    )
    source_input = output / "source-input"
    source_input.mkdir(exist_ok=True)
    write_jsonl(source_input / "sources.jsonl.gz", candidates)
    write_jsonl(source_input / "version-supplements.jsonl.gz", [])
    seal = {
        "version": "rad-v4.2-additive-recovered-identity-delta",
        "publication_allowed": False,
        "candidate_receipt_sha256": hashlib.sha256(
            candidates_path.read_bytes()
        ).hexdigest(),
        "files": {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in source_input.glob("*.jsonl.gz")
        },
    }
    (source_input / "source-input-manifest.json").write_text(
        json.dumps(seal, sort_keys=True, indent=2) + "\n"
    )
    first, repeated = output / "composition", output / "composition-repeat"
    manifest = compose_all(source_input, first)
    repeated_manifest = compose_all(source_input, repeated)
    if manifest != repeated_manifest:
        raise ValueError("delta_composition_not_deterministic")
    articles = read_jsonl(first / "articles.jsonl.gz")
    old_ids = {r["article_id"] for r in read_jsonl(baseline / "articles.jsonl.gz")}
    collisions = sorted({r["article_id"] for r in articles} & old_ids)
    if collisions:
        raise ValueError(
            "delta_existing_canonical_identity_requires_complete_contributors:"
            + ",".join(collisions)
        )
    proof = audit(candidates, articles)
    (output / "independent-audit.json").write_text(
        json.dumps(proof, ensure_ascii=False, indent=2) + "\n"
    )
    receipt = {
        "scope": "new_original_source_identities_only_existing_heads_unchanged",
        "sources": len(candidates),
        "source_blocks": sum(len(r["blocks"]) for r in candidates),
        "article_locales": len(articles),
        "deterministic_rebuild": True,
        "baseline_manifest_sha256": hashlib.sha256(
            (baseline / "manifest.json").read_bytes()
        ).hexdigest(),
        "manifest_sha256": hashlib.sha256(
            (first / "manifest.json").read_bytes()
        ).hexdigest(),
        "status": "PREPARED_NOT_TARGET_BOUND",
        "hosted_writes": 0,
        "publication_allowed": False,
    }
    if runtime is not None:
        sql = connection(runtime)
        heads = json.loads(sql("begin read only;\n" + HEAD_QUERY + "\nrollback;"))
        source_rows = json.loads(
            sql("begin read only;\n" + SOURCE_QUERY + "\nrollback;")
        )
        current_ids = {r["article_id"] for r in heads}
        if {r["article_id"] for r in articles} & current_ids:
            raise ValueError(
                "delta_existing_native_head_requires_complete_contributors"
            )
        (output / "all-native-heads-before.json").write_text(
            json.dumps(heads, sort_keys=True, indent=2) + "\n"
        )
        # This compiler is explicitly restricted to proved-new article IDs.
        # Its legacy-named input accurately contains zero existing heads in that
        # scope; complete current heads are preserved above for review/rollback.
        (output / "staging-heads-before.json").write_text("[]\n")
        (output / "staging-sources-before.json").write_text(
            json.dumps(source_rows, sort_keys=True, indent=2) + "\n"
        )
        compiled = output / "import"
        compile_operations(first, output, compiled)
        plan = json.loads((compiled / "import-plan.json").read_text())
        if plan["blocked"] or any(
            r["operation"] != "new_draft" for r in plan["operations"]
        ):
            raise ValueError("delta_requires_unblocked_new_drafts_only")
        script = output / "native-delta-retry-rollback.sql"
        parts = [
            "begin;\ncreate temp table delta_heads_before as select article_id,locale,head_id,published_id from public.visa_article_heads where head_id is not null or published_id is not null;\ncreate temp table delta_catalog_before as select article_id,to_jsonb(c) original from private.rad_editorial_catalog c;\n"
        ]
        for _ in range(2):
            for operation in plan["operations"]:
                raw = gzip.decompress((compiled / operation["file"]).read_bytes())
                if hashlib.sha256(raw).hexdigest() != operation["sha256"]:
                    raise ValueError("delta_operation_checksum_mismatch")
                body = raw.decode()
                if not body.endswith("commit;\n"):
                    raise ValueError("delta_transaction_shape")
                parts.append(body.split("begin;\n", 1)[1].removesuffix("commit;\n"))
        rollback = (compiled / "rollback.sql").read_text()
        parts.append(rollback.split("begin;\n", 1)[1].removesuffix("commit;\n"))
        parts.append("""do $$begin
if exists(select 1 from delta_heads_before b left join public.visa_article_heads h on h.article_id=b.article_id and h.locale=b.locale where h.head_id is distinct from b.head_id or h.published_id is distinct from b.published_id) then raise exception 'delta_original_head_changed';end if;
if exists(select 1 from delta_catalog_before b left join private.rad_editorial_catalog c on c.article_id=b.article_id where to_jsonb(c) is distinct from b.original) then raise exception 'delta_original_catalog_changed';end if;
if exists(select 1 from public.visa_article_heads h where h.head_id is not null and not exists(select 1 from delta_heads_before b where b.article_id=h.article_id and b.locale=h.locale)) then raise exception 'delta_active_new_head_after_rollback';end if;
if exists(select 1 from private.rad_editorial_import_target where enabled) then raise exception 'delta_import_gate_left_enabled';end if;
end $$;
rollback;
select 'PASS_DELTA_RETRY_ROLLBACK';
""")
        script.write_text("".join(parts), encoding="utf8")
        response = sql(script, timeout=180)
        (output / "native-rehearsal.log").write_text(response + "\n")
        if "PASS_DELTA_RETRY_ROLLBACK" not in response:
            raise ValueError("delta_rehearsal_receipt_missing")
        after = json.loads(sql("begin read only;\n" + HEAD_QUERY + "\nrollback;"))
        if after != heads:
            raise ValueError("delta_enclosing_rollback_changed_heads")
        receipt.update(
            status="VERIFIED_PASS_NATIVE_ONLY",
            operations=len(plan["operations"]),
            every_operation_exactly_retried=True,
            generated_rollback_restored_heads_and_catalogs=True,
            enclosing_transaction_rolled_back=True,
            all_native_heads_before_sha256=hashlib.sha256(
                (output / "all-native-heads-before.json").read_bytes()
            ).hexdigest(),
            native_runtime=str(runtime),
            native_plan_is_not_hosted_package=True,
        )
    (output / "delta-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    return receipt


def recover(
    rows, complete_sources, output, *, fetch=None, verified_local_capture_keys=()
):
    for row in rows:
        if (
            row["disposition"] in {"RECOVERED_FULL_BODY", "REPRESENTED_DUPLICATE"}
            and (row.get("source_id"), row["url"]) not in verified_local_capture_keys
        ):
            raise ValueError("verified_local_capture_receipt_required")
    output.mkdir(parents=True, exist_ok=True)
    hosts = HOSTS | {"www." + h for h in HOSTS}
    if fetch is None:
        requests = []

        def recorded_request(url, *, max_bytes):
            entry = {
                "url": url,
                "observed_at": datetime.now(UTC).isoformat(),
                "maximum_bytes": max_bytes,
            }
            try:
                status, headers, body = pinned_request(url, max_bytes=max_bytes)
                entry.update(
                    status=status,
                    headers=headers,
                    raw_sha256=hashlib.sha256(body).hexdigest(),
                    bytes=len(body),
                )
                if urlsplit(url).path == "/robots.txt":
                    policy_asset = output / (entry["raw_sha256"] + ".robots.txt.gz")
                    policy_asset.write_bytes(gzip.compress(body, mtime=0))
                    entry["policy_asset"] = policy_asset.resolve().as_posix()
                return status, headers, body
            except EgressError as error:
                entry["safe_error"] = str(error)
                raise
            finally:
                requests.append(entry)
                write_jsonl(output / "https-request-observations.jsonl.gz", requests)

        fetch = ProtectedFetcher(
            hosts, request=recorded_request, minimum_interval=3
        ).fetch
    failures, circuit, results = {}, {}, []
    for row in rows:
        result = {**row, "candidate": None}
        url, host = row["url"], urlsplit(row["url"]).hostname
        if row["disposition"] in {"RECOVERED_FULL_BODY", "REPRESENTED_DUPLICATE"}:
            result["network"] = {"status": "REUSED_VERIFIED_LOCAL_CAPTURE"}
            results.append(result)
            continue
        if host in circuit:
            result["network"] = {
                "status": "HOST_CIRCUIT_OPEN",
                "safe_error": circuit[host],
            }
            results.append(result)
            continue
        observed = datetime.now(UTC).isoformat()
        current, redirects = url, []
        try:
            for hop in range(4):
                parsed = urlsplit(current)
                if (
                    parsed.scheme != "https"
                    or parsed.hostname not in hosts
                    or parsed.username
                    or parsed.password
                    or parsed.port not in (None, 443)
                    or parsed.fragment
                ):
                    raise EgressError("unsafe_source_redirect")
                status, headers, raw = fetch(current)
                if 300 <= status < 400:
                    location = headers.get("location")
                    if not location or hop == 3:
                        raise EgressError("redirect_limit")
                    destination = urljoin(current, location)
                    target = urlsplit(destination)
                    if target.scheme != "https" or target.hostname not in {
                        host,
                        "www." + host,
                        host.removeprefix("www."),
                    }:
                        raise EgressError("unsafe_source_redirect")
                    redirects.append(
                        {"from": current, "to": destination, "status": status}
                    )
                    current = destination
                    continue
                break
            failures[host] = 0
            result["network"] = {
                "status": "FETCHED",
                "http_status": status,
                "observed_at": observed,
                "final_url": current,
                "redirects": redirects,
                "raw_bytes": len(raw),
                "raw_sha256": hashlib.sha256(raw).hexdigest(),
            }
            if status in {401, 403, 429, 503}:
                circuit[host] = "http_" + str(status)
            if status == 200:
                asset = output / (hashlib.sha256(raw).hexdigest() + ".html.gz")
                asset.write_bytes(gzip.compress(raw, mtime=0))
                metadata = {
                    "final_url": current,
                    "content_type": headers.get("content-type", ""),
                    "status": status,
                    "retrieved_at": observed,
                    "method": "dns_pinned_https_robots_permitted_targeted_recovery",
                }
                assessments = []
                for capture in capture_from_raw(
                    raw, url, metadata, asset.resolve().as_posix()
                ):
                    assessment = capture_disposition(capture, raw, complete_sources)
                    candidate = assessment.pop("candidate", None)
                    assessments.append(assessment)
                    if candidate:
                        result["candidate"] = composition_source(candidate)
                        result["disposition"] = "RECOVERED_FULL_BODY"
                result["live_capture_assessments"] = assessments
            if status in {404, 410}:
                result["current_live_verification"] = "SOURCE_UNAVAILABLE_HTTP_" + str(
                    status
                )
        except (EgressError, ValueError, UnicodeError) as error:
            code = (
                str(error)
                if isinstance(error, EgressError)
                else "capture_requires_review"
            )
            failures[host] = failures.get(host, 0) + 1
            if code.startswith("robots_") or failures[host] >= 3:
                circuit[host] = code
            result["network"] = {
                "status": "REFUSED_OR_UNAVAILABLE",
                "safe_error": code,
                "observed_at": observed,
                "redirects": redirects,
            }
        results.append(result)
        write_jsonl(
            output / "live-dispositions.progress.jsonl.gz",
            [{k: v for k, v in r.items() if k != "candidate"} for r in results],
        )
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dispositions", type=Path, required=True)
    parser.add_argument("--source-input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--unresolved-ledger", type=Path)
    parser.add_argument(
        "--live",
        action="store_true",
        help="explicit bounded public fetch authorization; no paid APIs",
    )
    args = parser.parse_args()
    if not args.live:
        parser.error("--live is required; offline source proof is a separate command")
    rows = read_jsonl(args.dispositions)
    ledger = (
        args.unresolved_ledger
        or args.source_input.parent
        / "recovery-ready-sources/unresolved-sources.jsonl.gz"
    )
    validate_exact_scope(rows, read_jsonl(ledger))
    source_manifest = args.source_input / "source-input-manifest.json"
    manifest_bytes = source_manifest.read_bytes()
    seal = json.loads(manifest_bytes)
    for name, expected in seal["files"].items():
        if (
            hashlib.sha256((args.source_input / name).read_bytes()).hexdigest()
            != expected
        ):
            raise ValueError("input_seal_mismatch:" + name)
    ledger_summary = json.loads(
        ledger.with_name("summary.json").read_text(encoding="utf8")
    )
    if (
        ledger_summary.get("authoritative_source_manifest_sha256")
        != hashlib.sha256(manifest_bytes).hexdigest()
    ):
        raise ValueError("unresolved_ledger_source_seal_binding_required")
    verified_disposition_input(
        args.dispositions,
        hashlib.sha256(manifest_bytes).hexdigest(),
        hashlib.sha256(ledger.read_bytes()).hexdigest(),
    )
    complete_sources = read_jsonl(args.source_input / "sources.jsonl.gz")
    reused = verify_local_capture_reuse(
        rows,
        read_jsonl(args.source_input / "capture-versions.jsonl.gz"),
        complete_sources,
        [args.source_input.resolve().parents[2]],
    )
    results = recover(
        rows, complete_sources, args.output, verified_local_capture_keys=reused
    )
    candidates = [r.pop("candidate") for r in results if r.get("candidate")]
    for row in results:
        row.pop("candidate", None)
    write_jsonl(args.output / "url-dispositions.jsonl.gz", results)
    write_jsonl(args.output / "recovered-sources.jsonl.gz", candidates)
    summary = {
        "rows": len(results),
        "dispositions": dict(Counter(r["disposition"] for r in results)),
        "network": dict(Counter(r["network"]["status"] for r in results)),
        "new_recovered_sources": len(candidates),
        "paid_calls": 0,
        "publication_allowed": False,
        "hosted_writes": 0,
        "irrecoverable_claims": 0,
        "input_dispositions_sha256": hashlib.sha256(
            args.dispositions.read_bytes()
        ).hexdigest(),
        "unresolved_ledger_sha256": hashlib.sha256(ledger.read_bytes()).hexdigest(),
        "source_input_manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
        "input_producer_manifest_sha256": hashlib.sha256(
            args.dispositions.with_name("manifest.json").read_bytes()
        ).hexdigest(),
        "reused_original_captures_independently_reproved": len(reused),
        "files": {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(args.output.glob("*.gz"))
        },
    }
    (args.output / "manifest.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
