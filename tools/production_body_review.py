"""Offline, exhaustive Production body/source review. Never connects or approves.

Inputs are immutable full-body read-only captures and sealed full source payloads.
Every content value is escaped in packets; captured HTML is never executed.
"""

from __future__ import annotations

import argparse
import difflib
import gzip
import hashlib
import html
import json
from collections import Counter
from pathlib import Path

if not __debug__:
    raise RuntimeError("optimized_python_forbidden_review_integrity_guards_required")


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def digest(value):
    return hashlib.sha256(
        (value if isinstance(value, str) else canonical(value)).encode()
    ).hexdigest()


def structure_digest(value):
    return hashlib.sha256(
        json.dumps(
            value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
        ).encode()
    ).hexdigest()


def file_sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read_rows(path):
    return list(iter_rows(path))


def iter_rows(path):
    with gzip.open(path, "rt", encoding="utf8") as stream:
        for line in stream:
            if line.strip():
                yield json.loads(line)


def write_rows(path, rows):
    data = "".join(canonical(row) + "\n" for row in rows).encode()
    Path(path).write_bytes(gzip.compress(data, mtime=0))


def semantic(body):
    return {
        k: v
        for k, v in body.items()
        if k not in ("expected_revision", "merge_manifest_id")
    }


def draft_body(request):
    """The importer strips the RPC request key before persisting a body."""
    return {k: v for k, v in request.items() if k != "request_key"}


def projected_blocks(body):
    return [
        {k: v for k, v in b.items() if k != "id"}
        for s in body.get("sections", [])
        for b in s["blocks"]
    ]


def classify_delta(before, after):
    """Exact values only: whitespace, list nesting and content are not normalized."""
    old, new = projected_blocks(before), projected_blocks(after)
    left, right = list(map(canonical, old)), list(map(canonical, new))
    cursor = 0
    for value in right:
        if cursor < len(left) and value == left[cursor]:
            cursor += 1
    a, b = Counter(left), Counter(right)
    unmatched = list((a - b).elements())
    added = list((b - a).elements())
    nonsection_changes = [
        k
        for k in sorted(set(semantic(before)) | set(semantic(after)))
        if k != "sections" and semantic(before).get(k) != semantic(after).get(k)
    ]
    label = (
        "EXACT_ADDITIVE_ORDER_PRESERVED"
        if cursor == len(left) and not nonsection_changes
        else "REORDER_OR_RESECTION_WITH_ADDITIONS"
        if not unmatched and not nonsection_changes
        else "CURRENT_CONTENT_OR_METADATA_NEEDS_EXPLICIT_RECONCILIATION"
    )
    return {
        "classification": label,
        "current_blocks": len(old),
        "desired_blocks": len(new),
        "exact_current_occurrences_preserved": len(old) - len(unmatched),
        "unmatched_current_occurrences": len(unmatched),
        "additional_desired_occurrences": len(added),
        "current_sequence_is_exact_subsequence": cursor == len(left),
        "changed_nonsection_fields": nonsection_changes,
        "unmatched_current_blocks": [json.loads(x) for x in unmatched],
        "additional_desired_blocks": [json.loads(x) for x in added],
    }


def source_review(item, payload_sources, originals, article_ids, stored_snapshots=None):
    errors = []
    checks = Counter()
    proof = []
    stored_snapshots = stored_snapshots or {}
    source_bindings = []
    supplied = {s["source_id"]: s for s in payload_sources}
    for s in payload_sources:
        variant = s.get("source_variant_id", s["source_id"])
        original = originals.get(variant)
        if original is None:
            errors.append({"code": "SOURCE_VARIANT_MISSING", "source": variant})
            continue
        for field in ("body_text", "body_sha256", "url", "title"):
            if s.get(field) != original.get(field):
                errors.append(
                    {
                        "code": "SOURCE_PAYLOAD_MISMATCH",
                        "source": variant,
                        "field": field,
                    }
                )
        captured = s.get("source_evidence", {}).get(
            "captured_raw_html_sha256", s.get("raw_html_sha256")
        )
        if captured != original.get("raw_html_sha256"):
            errors.append(
                {"code": "ORIGINAL_CAPTURE_HASH_BINDING_MISMATCH", "source": variant}
            )
        reused = s.get("raw_html_sha256") != captured
        if reused:
            stored = stored_snapshots.get(s["snapshot_id"])
            if not stored or any(
                stored.get(k) != v
                for k, v in {
                    "source_id": s["source_id"],
                    "content_hash": s["body_sha256"],
                    "raw_html_sha256": s["raw_html_sha256"],
                    "canonical_url": s["url"],
                }.items()
            ):
                errors.append(
                    {
                        "code": "PRESERVED_SNAPSHOT_RAW_HASH_NOT_BOUND_TO_BASELINE",
                        "source": variant,
                    }
                )
            checks["existing_snapshot_raw_hash_preserved_separately"] += 1
        source_bindings.append(
            {
                "source_variant_id": variant,
                "stored_source_id": s["source_id"],
                "stored_snapshot_id": s["snapshot_id"],
                "captured_raw_html_sha256": captured,
                "stored_snapshot_raw_html_sha256": s.get("raw_html_sha256"),
                "different_raw_captures_same_exact_body": reused,
                "body_sha256": s["body_sha256"],
            }
        )
        if digest(s["body_text"]) != s["body_sha256"]:
            errors.append({"code": "SOURCE_BODY_HASH_MISMATCH", "source": variant})
        checks["source_payloads"] += 1
    seen = set()
    for section_index, section in enumerate(item["sections"]):
        for block_index, block in enumerate(section["blocks"]):
            bid = block["id"]
            checks["rich_blocks"] += 1
            if bid in seen:
                errors.append({"code": "DUPLICATE_RICH_BLOCK_ID", "block": bid})
            seen.add(bid)
            structure = block["original_structure"]
            checks["type_" + structure["type"]] += 1
            refs = block.get("provenance", [])
            selected = block.get("selected_origin", refs[0] if refs else None)
            if not refs or selected not in refs:
                errors.append(
                    {"code": "SELECTED_ORIGIN_NOT_IN_PROVENANCE", "block": bid}
                )
            local = []
            for ref in refs:
                variant = ref.get("source_variant_id", ref["source_id"])
                s = originals.get(variant)
                problems = []
                if s is None:
                    problems.append("missing_original_variant")
                else:
                    index = ref["block_index"]
                    start = ref["start"]
                    end = ref["end"]
                    sb = s["blocks"][index] if 0 <= index < len(s["blocks"]) else None
                    if sb is None:
                        problems.append("source_block_index")
                    else:
                        if (
                            not (0 <= start <= end <= len(s["body_text"]))
                            or s["body_text"][start:end] != sb["text"]
                        ):
                            problems.append("exact_source_offsets")
                        if ref.get("sha256") != digest(sb["text"]):
                            problems.append("source_text_hash")
                        if ref.get("structure_sha256") != structure_digest(sb):
                            problems.append("source_structure_hash")
                        if ref == selected and sb != structure:
                            problems.append("selected_original_structure")
                    if ref.get("url") != s["url"]:
                        problems.append("source_url")
                    mapped = supplied.get(ref["source_id"])
                    if mapped is None or mapped["snapshot_id"] != ref["snapshot_id"]:
                        problems.append("stored_source_snapshot_binding")
                if problems:
                    errors.append(
                        {
                            "code": "BLOCK_PROVENANCE_MISMATCH",
                            "block": bid,
                            "source": variant,
                            "problems": problems,
                        }
                    )
                checks["provenance_refs"] += 1
                local.append(
                    {
                        "source_variant_id": variant,
                        "source_id": ref["source_id"],
                        "snapshot_id": ref["snapshot_id"],
                        "block_index": ref["block_index"],
                        "start": ref["start"],
                        "end": ref["end"],
                        "selected": ref == selected,
                        "exact_original_structure": bool(
                            s
                            and 0 <= ref["block_index"] < len(s["blocks"])
                            and s["blocks"][ref["block_index"]] == structure
                        ),
                        "problems": problems,
                    }
                )
            proof.append(
                {
                    "rich_block_id": bid,
                    "section_index": section_index,
                    "block_index": block_index,
                    "section_heading": section.get("heading"),
                    "heading_path": section.get("heading_path"),
                    "source_context_title": section.get("source_context_title"),
                    "program": section.get("program"),
                    "structure_sha256": digest(structure),
                    "provenance": local,
                }
            )
    for link in item.get("source_links", []):
        checks["links"] += 1
        if link.get("target_block_id") and link["target_block_id"] not in seen:
            errors.append({"code": "LINK_PLACEMENT_BLOCK_MISSING", "link": link})
        if link.get("app_article_id") and link["app_article_id"] not in article_ids:
            errors.append(
                {
                    "code": "LINK_RELATION_TARGET_MISSING",
                    "target": link["app_article_id"],
                }
            )
        if link.get("source_id") not in supplied:
            errors.append({"code": "LINK_SOURCE_BINDING_MISSING", "link": link})
        if not link.get("url"):
            errors.append({"code": "LINK_URL_MISSING", "link": link})
        if link.get("original_href"):
            checks["literal_href_preserved"] += 1
    for asset in item.get("source_assets", []):
        checks["assets"] += 1
        if asset.get("public_render_allowed") is not False:
            errors.append({"code": "ASSET_RENDER_NOT_DISABLED", "asset": asset})
        if asset.get("source_id") not in supplied:
            errors.append({"code": "ASSET_SOURCE_BINDING_MISSING", "asset": asset})
        if not asset.get("url"):
            errors.append({"code": "ASSET_URL_MISSING", "asset": asset})
    request = item["draft_request"]
    for field in ("article_id", "locale", "title"):
        if request.get(field) != item.get(field):
            errors.append({"code": "REQUEST_IDENTITY_TITLE_MISMATCH", "field": field})
    if (
        item.get("published")
        or item.get("publication_allowed")
        or item.get("editorial_state") != "draft"
    ):
        errors.append({"code": "NOT_DRAFT_ONLY"})
    for target in request.get("related_article_ids", []):
        if target not in article_ids:
            errors.append({"code": "RELATION_ID_MISSING", "target": target})
    return {
        "status": "PASS_EXACT_MECHANICAL_SOURCE_INTEGRITY"
        if not errors
        else "FAIL_MECHANICAL_SOURCE_INTEGRITY",
        "counts": dict(checks),
        "errors": errors,
        "placements": proof,
        "source_capture_vs_stored_snapshot_bindings": source_bindings,
        "interpretation": "Source text/structure/offset/hash and stored source/snapshot mapping only; source truth, legal accuracy, editorial placement and asset rights are unapproved.",
    }


def esc(value):
    return html.escape(str(value), quote=True)


def detail(title, value):
    return (
        "<details><summary>"
        + esc(title)
        + '</summary><pre dir="auto">'
        + esc(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2))
        + "</pre></details>"
    )


def render_rich(item):
    out = []
    for section in item["sections"]:
        out.append(
            '<section><h3 dir="auto">'
            + esc(section.get("heading", ""))
            + "</h3>"
            + detail(
                "Placement context", {k: v for k, v in section.items() if k != "blocks"}
            )
        )
        for b in section["blocks"]:
            s = b["original_structure"]
            out.append(
                "<article><p><code>"
                + esc(b["id"])
                + "</code> · "
                + esc(s["type"])
                + "</p>"
            )
            if s["type"] == "table":
                out.append("<table>")
                for row in s.get("rows", []):
                    out.append(
                        "<tr>"
                        + "".join(
                            '<td dir="auto">' + esc(c.get("text", "")) + "</td>"
                            for c in row
                        )
                        + "</tr>"
                    )
                out.append(
                    "</table>" + detail("Full table structure, spans and caption", s)
                )
            else:
                out.append('<pre dir="auto">' + esc(s.get("text", "")) + "</pre>")
            if s["type"] in ("bullet_list", "numbered_list"):
                out.append(detail("Full nested list structure", s))
            out.append(
                detail(
                    "Exact provenance and selected origin",
                    {
                        "selected_origin": b.get("selected_origin"),
                        "provenance": b.get("provenance"),
                    },
                )
            )
            out.append("</article>")
        out.append("</section>")
    return "".join(out)


STYLE = "body{font:16px system-ui;max-width:1250px;margin:32px auto;padding:0 24px;color:#162128}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f4f6f7;padding:12px}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccd6dc;padding:8px;text-align:start}article,section{border-block-end:1px solid #ccd6dc;margin-block:18px;padding-block:8px}summary{cursor:pointer;padding:8px}code{overflow-wrap:anywhere}.notice{padding:18px;background:#fff2d0}"


def html_doc(title, body):
    return (
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; img-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'\"><meta name=\"viewport\" content=\"width=device-width\"><title>"
        + esc(title)
        + "</title><style>"
        + STYLE
        + "</style></head><body>"
        + body
        + "</body></html>"
    )


def make_packet(case, before, payload, source_proof):
    item = payload["item"]
    after = item["draft_request"]
    old = before["body"] if before else {}
    delta = "\n".join(
        difflib.unified_diff(
            json.dumps(
                semantic(old), ensure_ascii=False, sort_keys=True, indent=2
            ).splitlines(),
            json.dumps(
                semantic(draft_body(after)),
                ensure_ascii=False,
                sort_keys=True,
                indent=2,
            ).splitlines(),
            fromfile="CURRENT_PRODUCTION",
            tofile="DESIRED_SEALED_DRAFT",
            n=5,
        )
    )
    body = (
        '<a href="../index.html">All cases</a><h1 dir="auto">'
        + esc(item["title"])
        + "</h1><p>"
        + esc(case["case_id"])
        + " · "
        + esc(case["case_sha256"])
        + '</p><p class="notice">Mechanical evidence only. No legal, editorial, publication or hosted execution approval. Existing Production heads, revisions and actors remain preserved.</p>'
    )
    body += detail("Case verdict, operation and exact pending choices", case)
    body += (
        '<h2>Complete before / after difference</h2><pre dir="auto">'
        + esc(delta or "No current head; complete candidate below.")
        + "</pre>"
    )
    body += detail(
        "Complete current Production body and stored sections", before
    ) + detail("Complete desired draft request", after)
    body += (
        "<h2>Full desired rich content in exact section/block order</h2>"
        + render_rich(item)
    )
    body += detail(
        "Complete link records, literal hrefs, labels and placements",
        item.get("source_links", []),
    ) + detail(
        "Complete asset records and rights restrictions", item.get("source_assets", [])
    )
    body += detail("Per-block exact source and placement proofs", source_proof)
    body += detail(
        "Full composition metadata, title, relationships and provenance",
        {k: v for k, v in item.items() if k not in ("sections", "draft_request")},
    )
    body += "<h2>Full sealed source context</h2>"
    for source in payload["sources"]:
        body += detail("Source " + source["source_id"] + " · " + source["url"], source)
    return html_doc(item["title"], body)


def verify_capture_files(workspace):
    """Recheck original raw bytes and literal anchor evidence, using local files only.

    This independent supplement binds all 657 case hashes after packet generation.
    No captured markup is evaluated and no remote resources are requested.
    """
    workspace = Path(workspace).resolve()
    review = (
        workspace
        / "_audit/RAD_MASTER_CONVERGENCE_20261031/db_forward_review/body-review"
    )
    cases = read_rows(review / "review-cases.jsonl.gz")
    used = {}
    links = {}
    assets = {}
    for c in cases:
        p = json.loads(
            gzip.decompress(
                (
                    review / "payloads" / f"{c['article_id']}-{c['locale']}.json.gz"
                ).read_bytes()
            )
        )
        for s in p["sources"]:
            variant = s.get("source_variant_id", s["source_id"])
            used.setdefault(variant, []).append(c["case_id"])
        for link in p["item"].get("source_links", []):
            variant = link.get("source_variant_id", link.get("source_id"))
            links.setdefault(variant, []).append(link)
        for asset in p["item"].get("source_assets", []):
            variant = asset.get("source_variant_id", asset.get("source_id"))
            assets.setdefault(variant, []).append(asset)
    compdirs = [
        workspace / "_audit/RAD_MASTER_EXECUTION_20261029/content/composition-safe",
        workspace
        / "_audit/RAD_MASTER_CONVERGENCE_20261031/content-recovery/additive-two-source-delta/composition",
    ]
    rows = []
    for folder in compdirs:
        for s in iter_rows(folder / "sources.jsonl.gz"):
            sid = s["source_id"]
            if sid not in used:
                continue
            issues = []
            asset = s.get("raw_html_asset")
            raw = None
            path = None
            if asset:
                original = Path(asset)
                candidates = (
                    [original]
                    if original.is_absolute()
                    else [
                        workspace / "rad_full_content_v4" / asset,
                        workspace / "rad_master_completion_20261029" / asset,
                        workspace / asset,
                    ]
                )
                # Recovery assets can retain the former Windows workspace prefix.
                text = str(asset).replace("\\", "/")
                marker = "/RAD - Emigrate/"
                if marker in text:
                    candidates.append(workspace / text.split(marker, 1)[1])
                if "/Desktop/RAD - Emigrate/" in text:
                    candidates.append(
                        workspace / text.split("/Desktop/RAD - Emigrate/", 1)[1]
                    )
                path = next((x for x in candidates if x.exists()), None)
            if path is None:
                issues.append("ORIGINAL_RAW_ASSET_NOT_FOUND")
            else:
                raw = path.read_bytes()
                if path.suffix == ".gz":
                    raw = gzip.decompress(raw)
                if hashlib.sha256(raw).hexdigest() != s["raw_html_sha256"]:
                    issues.append("ORIGINAL_RAW_BYTES_HASH_MISMATCH")
            if digest(s["body_text"]) != s["body_sha256"]:
                issues.append("ORIGINAL_NORMALIZED_BODY_HASH_MISMATCH")
            checked = 0
            unconfirmed = 0
            decoded = raw.decode("utf8", errors="replace") if raw is not None else ""
            for link in links.get(sid, []):
                evidence = link.get("href_evidence", {})
                if (
                    evidence.get("raw_html_sha256")
                    and evidence["raw_html_sha256"] != s["raw_html_sha256"]
                ):
                    issues.append("LINK_RAW_CAPTURE_HASH_MISMATCH")
                matches = evidence.get("raw_matches", [])
                if not matches:
                    unconfirmed += 1
                for match in matches:
                    anchor = match.get("raw_anchor_tag")
                    if anchor and digest(anchor) != match.get("raw_anchor_sha256"):
                        issues.append("RAW_ANCHOR_HASH_MISMATCH")
                    if anchor and raw is not None and anchor not in decoded:
                        # A non-UTF8 source records the decoder used for its character offsets.
                        encoding = match.get("decoded_encoding", "utf8")
                        try:
                            present = anchor in raw.decode(encoding)
                        except (LookupError, UnicodeDecodeError):
                            present = False
                        if not present:
                            issues.append("RAW_ANCHOR_NOT_IN_ORIGINAL_CAPTURE")
                    if anchor:
                        checked += 1
            rows.append(
                {
                    "source_variant_id": sid,
                    "case_ids": sorted(set(used[sid])),
                    "url": s["url"],
                    "capture_id": s.get("capture_id"),
                    "raw_asset": str(path) if path else asset,
                    "raw_html_sha256": s["raw_html_sha256"],
                    "body_sha256": s["body_sha256"],
                    "raw_bytes_verified": raw is not None
                    and hashlib.sha256(raw).hexdigest() == s["raw_html_sha256"],
                    "literal_raw_anchors_verified": checked,
                    "link_records_without_raw_anchor_proof": unconfirmed,
                    "asset_records_preserved_rights_pending": len(assets.get(sid, [])),
                    "issues": sorted(set(issues)),
                    "status": "PASS_EXACT_CAPTURE_BYTES_AND_RECORDED_EVIDENCE"
                    if not issues
                    else "FAIL_CAPTURE_EVIDENCE",
                }
            )
    present = {r["source_variant_id"] for r in rows}
    missing = set(used) - present
    result = {
        "status": "PASS_ALL_USED_ORIGINAL_CAPTURE_SEALS"
        if not missing and all(not r["issues"] for r in rows)
        else "REVIEW_CAPTURE_EVIDENCE_FAILURES",
        "cases": len(cases),
        "case_index_sha256": file_sha(review / "review-cases.jsonl.gz"),
        "source_variants": len(rows),
        "missing_variants": sorted(missing),
        "raw_bytes_verified": sum(r["raw_bytes_verified"] for r in rows),
        "literal_raw_anchors_verified": sum(
            r["literal_raw_anchors_verified"] for r in rows
        ),
        "link_records_without_raw_anchor_proof": sum(
            r["link_records_without_raw_anchor_proof"] for r in rows
        ),
        "rows": rows,
        "network_requests": 0,
        "hosted_writes": 0,
        "source_truth_or_asset_rights_approved": False,
    }
    (review / "source-capture-integrity.json").write_text(
        json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf8",
    )
    print(json.dumps({k: v for k, v in result.items() if k != "rows"}, indent=2))
    return result


def verify_review_outputs(workspace):
    """Check every packet, decision binding and immutable evidence seal offline."""
    workspace = Path(workspace).resolve()
    out = (
        workspace
        / "_audit/RAD_MASTER_CONVERGENCE_20261031/db_forward_review/body-review"
    )
    receipt = json.loads((out / "receipt.json").read_text("utf8"))
    cases = read_rows(out / "review-cases.jsonl.gz")
    decisions = json.loads((out / "decisions-template.json").read_text("utf8"))[
        "decisions"
    ]
    assert len(cases) == len(decisions) == 657
    assert len({(c["article_id"], c["locale"]) for c in cases}) == 657
    for name, expected in receipt["outputs"].items():
        assert file_sha(out / name) == expected, "review_output_changed"
    for name, expected in receipt["packets"].items():
        assert file_sha(out / name) == expected, "packet_changed"
        text = (out / name).read_text("utf8")
        for tag in ("script", "iframe", "img", "object", "embed", "form"):
            assert "<" + tag not in text.lower(), "active_content_in_packet"
        assert "default-src 'none'" in text and "Full sealed source context" in text
    for c, d in zip(cases, decisions, strict=True):
        payload_path = out / "payloads" / f"{c['article_id']}-{c['locale']}.json.gz"
        payload = json.loads(gzip.decompress(payload_path.read_bytes()))
        assert (
            digest({"item": payload["item"], "sources": payload["sources"]})
            == c["payload_sha256"]
        ), "cached_full_payload_changed"
        assert (
            digest(payload["item"]["draft_request"]) == c["desired_request_sha256"]
        ), "desired_request_changed"
        assert (
            digest({k: v for k, v in c.items() if k != "case_sha256"})
            == c["case_sha256"]
        ), "case_hash_changed"
        assert all(
            d[k] == c[k]
            for k in (
                "case_id",
                "article_id",
                "locale",
                "case_sha256",
                "payload_sha256",
                "desired_article_sha256",
                "current_head",
                "current_body_md5",
            )
        )
        assert all(
            d[k] is None
            for k in ("decision", "reviewer_id", "review_receipt_sha256", "note")
        ), "human_choice_filled"
    for name, expected in receipt["inputs"].items():
        assert file_sha(name) == expected, "sealed_input_changed"
    by_key = {(c["article_id"], c["locale"]): c for c in cases}
    identity_fields = (
        "article_id",
        "locale",
        "title",
        "content_class",
        "country_codes",
        "category",
        "pathway",
        "visa_category",
        "editorial_state",
        "verification_state",
        "published",
        "publication_allowed",
    )
    identity_checked = 0
    for name in receipt["inputs"]:
        if (
            not name.endswith("composition-safe\\articles.jsonl.gz")
            and not name.replace("\\", "/").endswith("composition/articles.jsonl.gz")
            and not name.replace("\\", "/").endswith(
                "composition-safe/articles.jsonl.gz"
            )
        ):
            continue
        for original in iter_rows(name):
            key = (original["article_id"], original["locale"])
            if key not in by_key:
                continue
            payload = json.loads(
                gzip.decompress(
                    (out / "payloads" / f"{key[0]}-{key[1]}.json.gz").read_bytes()
                )
            )
            assert digest(original) == by_key[key]["desired_article_sha256"]
            assert all(
                payload["item"].get(k) == original.get(k) for k in identity_fields
            ), "original_title_identity_or_destination_metadata_changed"
            identity_checked += 1
    assert identity_checked == 657
    captures = json.loads((out / "source-capture-integrity.json").read_text("utf8"))
    assert captures["case_index_sha256"] == file_sha(out / "review-cases.jsonl.gz")
    gaps = json.loads((out / "link-anchor-gap-crosswalk.json").read_text("utf8"))
    gap_choices = json.loads(
        (out / "link-anchor-gap-decisions.template.json").read_text("utf8")
    )["decisions"]
    assert gaps["case_index_sha256"] == file_sha(out / "review-cases.jsonl.gz")
    assert gaps["existing_link_review_cases"] == 215
    assert gaps["unconfirmed_link_occurrences"] == 109
    assert gaps["unique_capture_link_gap_identities"] == len(gaps["cases"])
    assert sum(len(c["affected_body_occurrences"]) for c in gaps["cases"]) == 109
    assert len({c["gap_case_id"] for c in gaps["cases"]}) == len(gaps["cases"])
    for c in gaps["cases"]:
        assert c["human_decision"] is None
        assert (
            digest({k: v for k, v in c.items() if k != "gap_case_sha256"})
            == c["gap_case_sha256"]
        )
    for choice in gap_choices:
        assert all(
            choice[k] is None
            for k in ("decision", "reviewer_id", "review_receipt_sha256")
        )
        assert any(
            choice["gap_case_id"] == c["gap_case_id"]
            and choice["gap_case_sha256"] == c["gap_case_sha256"]
            and not c["exact_existing_review_cases"]
            for c in gaps["cases"]
        )
    assert len(gap_choices) == gaps["additional_unique_link_evidence_cases"]
    result = {
        "status": "PASS_ALL657_PACKETS_CASE_BINDINGS_INPUT_SEALS_AND_BLANK_CHOICES",
        "packets_verified": 657,
        "current_body_captures_bound": 251,
        "new_candidates_bound": 406,
        "human_approvals_filled": 0,
        "generator_sha256": file_sha(__file__),
        "test_sha256": file_sha(
            workspace
            / "rad_master_completion_20261029/scripts/tests/test_production_body_review.py"
        ),
        "case_index_sha256": file_sha(out / "review-cases.jsonl.gz"),
        "review_receipt_sha256": file_sha(out / "receipt.json"),
        "source_capture_integrity_sha256": file_sha(
            out / "source-capture-integrity.json"
        ),
        "hosted_mutations": 0,
        "source_capture_status": captures["status"],
        "source_link_raw_anchor_gaps": captures[
            "link_records_without_raw_anchor_proof"
        ],
        "additional_unique_link_evidence_choices": len(gap_choices),
        "supplement_sha256": {
            name: file_sha(out / name)
            for name in (
                "link-anchor-gap-crosswalk.json",
                "link-anchor-gap-decisions.template.json",
                "LINK_ANCHOR_GAPS.html",
                "specific-content-choices.json",
                "REVIEW_GUIDE.html",
            )
        },
    }
    (out / "verification.json").write_text(
        json.dumps(result, sort_keys=True, indent=2) + "\n", encoding="utf8"
    )
    print(json.dumps(result, indent=2))
    return result


def matching_link_cases(link, variant, cases, exact_capture=True):
    result = []
    for case in cases:
        proof = case["evidence"]["original_proof"]
        source = (
            case["source_id"] == link.get("source_variant_id", link["source_id"])
            or case["source_url"] == link["source_url"]
        )
        capture = (
            variant["capture_id"] in case["capture_ids"]
            and proof.get("raw_html_sha256") == variant["raw_html_sha256"]
        )
        targets = proof.get("original_targets", []) + case.get("alternatives", [])
        same_link = proof.get("label") == link.get("label") and (
            proof.get("canonical_url") == link["url"]
            or bool(link.get("original_href"))
            and any(t.get("original_href") == link["original_href"] for t in targets)
        )
        if source and same_link and (capture or not exact_capture):
            result.append(
                {"case_id": case["case_id"], "case_sha256": case["case_sha256"]}
            )
    return result


def write_link_gap_crosswalk(workspace):
    workspace = Path(workspace).resolve()
    out = (
        workspace
        / "_audit/RAD_MASTER_CONVERGENCE_20261031/db_forward_review/body-review"
    )
    existing_path = (
        out.parents[1] / "content-recovery/decision-packages/review-packet.json"
    )
    existing = json.loads(existing_path.read_text("utf8"))
    known = [c for c in existing["cases"] if c["category"] == "link"]
    assert len(known) == 215, "expected_existing_link_review_cases"
    bodycases = read_rows(out / "review-cases.jsonl.gz")
    groups = {}
    occurrences = 0
    for bodycase in bodycases:
        p = json.loads(
            gzip.decompress(
                (
                    out
                    / "payloads"
                    / f"{bodycase['article_id']}-{bodycase['locale']}.json.gz"
                ).read_bytes()
            )
        )
        variants = {
            s.get("source_variant_id", s["source_id"]): s
            for s in p["item"]["source_capture_variants"]
        }
        for index, link in enumerate(p["item"].get("source_links", [])):
            if link.get("href_evidence", {}).get("raw_matches"):
                continue
            occurrences += 1
            sid = link.get("source_variant_id", link["source_id"])
            variant = variants[sid]
            identity = {
                "source_variant_id": sid,
                "capture_id": variant["capture_id"],
                "raw_html_sha256": variant["raw_html_sha256"],
                "source_url": link["source_url"],
                "label": link.get("label"),
                "original_href": link.get("original_href"),
                "url": link["url"],
            }
            key = digest(identity)
            group = groups.setdefault(
                key,
                {
                    "gap_case_id": "raw-anchor-gap:" + key[:24],
                    **identity,
                    "original_raw_asset": variant.get("raw_html_asset"),
                    "exact_existing_review_cases": matching_link_cases(
                        link, variant, known
                    ),
                    "related_different_capture_cases_context_only": matching_link_cases(
                        link, variant, known, False
                    ),
                    "affected_body_occurrences": [],
                    "human_decision": None,
                    "publication_approval": False,
                    "choices": [
                        "retain_original_link_unresolved",
                        "defer_link_evidence_review",
                        "provide_exact_source_capture_raw_anchor_evidence",
                    ],
                    "required_evidence": "Exact original capture bytes/hash, literal anchor span and original href/label; another capture or normalized target is context only.",
                },
            )
            group["affected_body_occurrences"].append(
                {
                    "body_case_id": bodycase["case_id"],
                    "body_case_sha256": bodycase["case_sha256"],
                    "article_id": bodycase["article_id"],
                    "locale": bodycase["locale"],
                    "packet": bodycase["packet"],
                    "link_record_index": index,
                    "source_id": link["source_id"],
                    "source_snapshot_id": link["source_snapshot_id"],
                    "target_block_id": link.get("target_block_id"),
                    "complete_original_link_record": link,
                }
            )
    rows = []
    decisions = []
    for _, group in sorted(groups.items()):
        exactids = {x["case_id"] for x in group["exact_existing_review_cases"]}
        group["related_different_capture_cases_context_only"] = [
            r
            for r in group["related_different_capture_cases_context_only"]
            if r["case_id"] not in exactids
        ]
        group["disposition"] = (
            "REFERENCE_EXISTING_HASH_BOUND_HUMAN_CASE_NO_DUPLICATE_CHOICE"
            if exactids
            else "ADDITIONAL_HASH_BOUND_LINK_EVIDENCE_CHOICE_REQUIRED"
        )
        group["gap_case_sha256"] = digest(group)
        rows.append(group)
        if not exactids:
            decisions.append(
                {
                    "gap_case_id": group["gap_case_id"],
                    "gap_case_sha256": group["gap_case_sha256"],
                    "decision": None,
                    "reviewer_id": None,
                    "review_receipt_sha256": None,
                }
            )
    result = {
        "status": "COMPLETE_EXACT_CAPTURE_LINK_GAP_CROSSWALK_NO_APPROVALS",
        "case_index_sha256": file_sha(out / "review-cases.jsonl.gz"),
        "existing_link_review_packet_sha256": file_sha(existing_path),
        "existing_link_review_cases": 215,
        "unconfirmed_link_occurrences": occurrences,
        "unique_capture_link_gap_identities": len(rows),
        "exact_existing_case_mapped_identities": sum(
            bool(r["exact_existing_review_cases"]) for r in rows
        ),
        "additional_unique_link_evidence_cases": len(decisions),
        "additional_occurrences": sum(
            len(r["affected_body_occurrences"])
            for r in rows
            if not r["exact_existing_review_cases"]
        ),
        "same_link_other_capture_context_only_identities": sum(
            bool(r["related_different_capture_cases_context_only"]) for r in rows
        ),
        "deduplication": "Identity includes exact source variant, original capture ID and raw hash, literal href, label and preserved target. Existing215 are referenced only for exact capture identity; different captures never merge decisions.",
        "human_choices_filled": 0,
        "cases": rows,
    }
    assert occurrences == 109
    (out / "link-anchor-gap-crosswalk.json").write_text(
        json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf8",
    )
    (out / "link-anchor-gap-decisions.template.json").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "existing215_unchanged": True,
                "decisions": decisions,
            },
            ensure_ascii=False,
            sort_keys=True,
            indent=2,
        )
        + "\n",
        encoding="utf8",
    )
    body = (
        '<a href="REVIEW_GUIDE.html">Review guide</a><h1>Raw-anchor evidence gap crosswalk</h1><p class="notice">These are additional source-evidence decisions, never legal/editorial approval. Existing 215 link cases remain unchanged. Different captures are context only; no cross-capture equivalence is inferred.</p>'
        + detail(
            "Exact coverage and no-double-count totals",
            {k: v for k, v in result.items() if k != "cases"},
        )
    )
    for row in rows:
        body += (
            "<h2>"
            + esc(row["gap_case_id"])
            + "</h2>"
            + "".join(
                '<p><a href="'
                + esc(x["packet"])
                + '">'
                + esc(x["body_case_id"])
                + " · full body/source context</a></p>"
                for x in row["affected_body_occurrences"]
            )
            + detail(
                "Exact capture, href, source, affected body cases, choices and case hash",
                row,
            )
        )
    (out / "LINK_ANCHOR_GAPS.html").write_text(
        html_doc("109 raw-anchor evidence gaps", body), encoding="utf8"
    )
    print(
        json.dumps(
            {k: v for k, v in result.items() if k not in ("cases", "deduplication")},
            indent=2,
        )
    )
    return result


def write_review_guide(workspace):
    workspace = Path(workspace).resolve()
    out = (
        workspace
        / "_audit/RAD_MASTER_CONVERGENCE_20261031/db_forward_review/body-review"
    )
    cases = read_rows(out / "review-cases.jsonl.gz")
    receipt = json.loads((out / "receipt.json").read_text("utf8"))
    captures = json.loads((out / "source-capture-integrity.json").read_text("utf8"))
    exceptions = []
    for c in cases:
        if (
            c["delta"]["classification"]
            != "CURRENT_CONTENT_OR_METADATA_NEEDS_EXPLICIT_RECONCILIATION"
        ):
            continue
        p = json.loads(
            gzip.decompress(
                (
                    out / "payloads" / f"{c['article_id']}-{c['locale']}.json.gz"
                ).read_bytes()
            )
        )
        exact = {canonical(b) for b in projected_blocks(p["item"]["draft_request"])}
        rich = [
            b["original_structure"] for s in p["item"]["sections"] for b in s["blocks"]
        ]
        rows = []
        for b in c["delta"]["unmatched_current_blocks"]:
            reason = (
                "DUPLICATE_OCCURRENCE_EXACT_BLOCK_STILL_PRESENT"
                if canonical(b) in exact
                else "EXACT_CURRENT_TEXT_RETAINED_INSIDE_DESIRED_RICH_STRUCTURE"
                if any(b["text"] and b["text"] in n.get("text", "") for n in rich)
                else "EXACT_CURRENT_TEXT_REQUIRES_RECONCILIATION"
            )
            rows.append(
                {
                    "current_block_sha256": digest(b),
                    "current_block": b,
                    "finding": reason,
                }
            )
        exceptions.append(
            {
                "case_id": c["case_id"],
                "case_sha256": c["case_sha256"],
                "article_id": c["article_id"],
                "locale": c["locale"],
                "packet": c["packet"],
                "title": c["title"],
                "current_head": c["current_head"],
                "current_body_md5": c["current_body_md5"],
                "findings": dict(Counter(r["finding"] for r in rows)),
                "unmatched_current_occurrences": rows,
                "pending_choice": "Keep current draft, or separately review a detached candidate that reconciles each listed old occurrence; no current head advancement or deletion authorized.",
            }
        )
    (out / "specific-content-choices.json").write_text(
        json.dumps(
            {
                "case_index_sha256": file_sha(out / "review-cases.jsonl.gz"),
                "cases": exceptions,
                "human_choices_filled": 0,
            },
            ensure_ascii=False,
            sort_keys=True,
            indent=2,
        )
        + "\n",
        encoding="utf8",
    )
    body = '<h1>Complete independent body review</h1><p><a href="index.html">Open all 657 complete packets</a></p><p class="notice">All 251 existing Production body differences and all 406 new candidates were examined mechanically against full sealed content. No legal, editorial, publication or execution approval is recorded. All human decisions remain blank.</p>'
    body += "<h2>Exact existing-content findings</h2><p>207 preserve every current block in exact order and add content. 42 retain all exact current block occurrences with reordering or different sections plus additions. Two need the focused choices below. Existing heads, old revisions and operational actors remain preserved for every case.</p>"
    for c in exceptions:
        body += (
            '<h3><a href="'
            + esc(c["packet"])
            + '" dir="auto">'
            + esc(c["case_id"] + " · " + c["title"])
            + "</a></h3>"
            + detail(
                "Specific old occurrences, retained-text findings and pending choice", c
            )
        )
    body += (
        "<h2>Source capture proof and remaining evidence limitations</h2><p>All "
        + str(captures["raw_bytes_verified"])
        + " used original capture byte seals were rechecked. "
        + str(captures["literal_raw_anchors_verified"])
        + " recorded literal raw-anchor occurrences match their original captures. "
        + str(captures["link_records_without_raw_anchor_proof"])
        + " link-record occurrences lack raw-anchor evidence; these remain unresolved. 2,148 asset records preserve their source references, with rights and public rendering unapproved.</p>"
    )
    body += '<p><a href="source-capture-integrity.json">Complete per-source capture proof</a> · <a href="LINK_ANCHOR_GAPS.html">109 raw-anchor gaps and exact existing-case crosswalk</a> · <a href="specific-content-choices.json">Machine-readable focused content choices</a> · <a href="decisions-template.json">Blank hash-bound decisions</a> · <a href="verification.json">Artifact verification</a></p>'
    body += detail("Mechanical counts", receipt["source_checks"])
    (out / "REVIEW_GUIDE.html").write_text(
        html_doc("Independent body review guide", body), encoding="utf8"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--workspace", type=Path, default=Path(__file__).resolve().parents[2]
    )
    args = parser.parse_args()
    workspace = args.workspace.resolve()
    review = workspace / "_audit/RAD_MASTER_CONVERGENCE_20261031/db_forward_review"
    out = review / "body-review"
    packets = out / "cases"
    packets.mkdir(exist_ok=True)
    payload_dir = out / "payloads"
    payload_dir.mkdir(exist_ok=True)
    execution = workspace / "_audit/RAD_MASTER_EXECUTION_20261029/content"
    recovery = review.parent / "content-recovery"
    dispositions = read_rows(
        review / "production-desired-reconciled-dispositions.jsonl.gz"
    )
    desired = {(r["article_id"], r["locale"]): r for r in dispositions}
    differing = {
        k
        for k, v in desired.items()
        if v["body_comparison"] == "DISTINCT_CANONICAL_SECTIONS"
    }
    new = {
        k
        for k, v in desired.items()
        if v["operation_class"] == "NEW_KEY_DRAFT_CANDIDATE"
    }
    selected = differing | new
    dirs = [
        (execution / "composition-safe", execution / "native-rehearsal/import"),
        (
            recovery / "additive-two-source-delta/composition",
            recovery / "additive-two-source-delta/import",
        ),
    ]
    originals = {}
    composition = {}
    payloads = {}
    inputs = {}
    baseline_sources = execution / "native-rehearsal/staging-sources-before.json"
    stored_snapshots = {
        s["snapshot_id"]: s
        for s in json.loads(baseline_sources.read_text("utf8"))
        if s.get("snapshot_id")
    }
    inputs[str(baseline_sources)] = file_sha(baseline_sources)
    for comp, imp in dirs:
        manifest = json.loads((comp / "manifest.json").read_text("utf8"))
        for name in ("articles.jsonl.gz", "sources.jsonl.gz"):
            path = comp / name
            assert file_sha(path) == manifest["files"][name], (
                "sealed_composition_changed"
            )
            inputs[str(path)] = file_sha(path)
        originals.update(
            {s["source_id"]: s for s in iter_rows(comp / "sources.jsonl.gz")}
        )
        composition.update(
            {
                (a["article_id"], a["locale"]): a
                for a in iter_rows(comp / "articles.jsonl.gz")
                if (a["article_id"], a["locale"]) in selected
            }
        )
        for p in iter_rows(imp / "payloads.jsonl.gz"):
            key = (p["item"]["article_id"], p["item"]["locale"])
            if key not in selected:
                continue
            path = payload_dir / (key[0] + "-" + key[1] + ".json.gz")
            data = canonical(p).encode()
            if not path.exists() or gzip.decompress(path.read_bytes()) != data:
                path.write_bytes(gzip.compress(data, compresslevel=1, mtime=0))
            payloads[key] = path
        inputs[str(imp / "payloads.jsonl.gz")] = file_sha(imp / "payloads.jsonl.gz")
    current = {}
    captures = []
    for path in sorted(out.glob("production-full-body-*.json")):
        capture = json.loads(path.read_text("utf8"))
        inputs[str(path)] = file_sha(path)
        captures.append(capture["observed_at"])
        for r in capture["rows"]:
            key = (r["article_id"], r["locale"])
            assert key not in current, "duplicate_current_key"
            current[key] = r
    assert len(differing) == 251 and len(new) == 406 and set(current) == differing
    assert set(composition) == set(payloads) == selected and len(desired) == 1100
    article_ids = {k[0] for k in desired}
    cases = []
    decisions = []
    counts = Counter()
    integrity = Counter()
    files = {}
    for index, key in enumerate(sorted(differing | new)):
        d = desired[key]
        p = json.loads(gzip.decompress(payloads[key].read_bytes()))
        item = p["item"]
        before = current.get(key)
        assert digest(composition[key]) == d["desired_article_sha256"], (
            "desired_composition_digest_binding"
        )
        # Prepared payload may add storage mappings/projection fields. Every original rich
        # structure, section placement and block ordering must still be identical.
        source_sections = composition[key]["sections"]
        prepared_sections = item["sections"]
        assert len(source_sections) == len(prepared_sections), "section_count"
        for a, b in zip(source_sections, prepared_sections, strict=True):
            assert {k: v for k, v in a.items() if k != "blocks"} == {
                k: v for k, v in b.items() if k != "blocks"
            }, "placement_changed"
            assert [r["original_structure"] for r in a["blocks"]] == [
                r["original_structure"] for r in b["blocks"]
            ], "original_structure_changed"
        if before:
            assert (
                before["head_id"] == d["current_head"]
                and before["body_md5"] == d["comparisons"]["body_md5"]["current"]
            ), "current_capture_drift"
            assert (
                before["body_semantic_md5"]
                == d["comparisons"]["body_semantic_md5"]["current"]
            ), "semantic_capture_drift"
            assert before["published_id"] is None
        proof = source_review(
            item, p["sources"], originals, article_ids, stored_snapshots
        )
        delta = (
            classify_delta(before["body"], draft_body(item["draft_request"]))
            if before
            else {
                "classification": "NEW_KEY_FULL_SOURCE_COMPOSITION",
                "current_blocks": 0,
                "desired_blocks": len(projected_blocks(item["draft_request"])),
            }
        )
        case = {
            "case_id": f"RAD-BODY-{index + 1:04d}",
            "article_id": key[0],
            "locale": key[1],
            "title": item["title"],
            "kind": "differing_existing" if before else "new_candidate",
            "desired_article_sha256": d["desired_article_sha256"],
            "payload_sha256": digest({"item": item, "sources": p["sources"]}),
            "current_head": before["head_id"] if before else None,
            "current_body_md5": before["body_md5"] if before else None,
            "current_body_sha256": digest(before["body"]) if before else None,
            "desired_request_sha256": digest(item["draft_request"]),
            "source_review_status": proof["status"],
            "source_review_counts": proof["counts"],
            "source_review_errors": proof["errors"],
            "delta": delta,
            "operation": "CREATE_DETACHED_IMMUTABLE_DRAFT_PRESERVE_CURRENT_HEAD_REVISION_ACTOR"
            if before
            else "CREATE_INITIAL_UNPUBLISHED_DRAFT_ONLY_IF_KEY_STILL_ABSENT",
            "human_choice": "Review exact full diff and source placements, then choose create_detached_draft or keep_current; head advancement is separately unapproved."
            if before
            else "Review full candidate, title, source context and destination placement before draft execution; publication separately unapproved.",
            "authorship_inference": "No absence of human edits inferred from archive equality or source overlap.",
            "execution_allowed": False,
            "publication_allowed": False,
            "editorial_approved": False,
            "legal_approved": False,
            "packet": f"cases/{key[0]}-{key[1]}.html",
        }
        case["case_sha256"] = digest(case)
        cases.append(case)
        counts[delta["classification"]] += 1
        integrity[proof["status"]] += 1
        path = out / case["packet"]
        path.write_text(make_packet(case, before, p, proof), encoding="utf8")
        files[case["packet"]] = file_sha(path)
        decisions.append(
            {
                "case_id": case["case_id"],
                "article_id": key[0],
                "locale": key[1],
                "case_sha256": case["case_sha256"],
                "payload_sha256": case["payload_sha256"],
                "desired_article_sha256": case["desired_article_sha256"],
                "current_head": case["current_head"],
                "current_body_md5": case["current_body_md5"],
                "decision": None,
                "reviewer_id": None,
                "review_receipt_sha256": None,
                "note": None,
            }
        )
        if (index + 1) % 100 == 0:
            print(
                json.dumps({"reviewed": index + 1, "integrity": dict(integrity)}),
                flush=True,
            )
    write_rows(out / "review-cases.jsonl.gz", cases)
    (out / "decisions-template.json").write_text(
        json.dumps(
            {"schema_version": 1, "decisions": decisions}, ensure_ascii=False, indent=2
        )
        + "\n",
        encoding="utf8",
    )
    rows = "".join(
        "<tr><td>"
        + esc(c["case_id"])
        + '</td><td><a href="'
        + esc(c["packet"])
        + '" dir="auto">'
        + esc(c["title"])
        + "</a></td><td>"
        + esc(c["kind"])
        + "</td><td>"
        + esc(c["delta"]["classification"])
        + "</td><td>"
        + esc(c["source_review_status"])
        + "</td></tr>"
        for c in cases
    )
    (out / "index.html").write_text(
        html_doc(
            "All 657 independent body/source cases",
            '<h1>657 complete body and source review cases</h1><p class="notice">251 current Production differences and 406 new candidates. Every packet includes complete content and source context. Mechanical integrity does not approve facts, law, editorial placement, assets, execution or publication. All human decisions are blank.</p><pre>'
            + esc(
                json.dumps(
                    {
                        "delta_classes": dict(counts),
                        "source_integrity": dict(integrity),
                    },
                    indent=2,
                )
            )
            + "</pre><table><tr><th>Case</th><th>Title and complete packet</th><th>Kind</th><th>Delta</th><th>Integrity</th></tr>"
            + rows
            + "</table>",
        ),
        encoding="utf8",
    )
    receipt = {
        "status": "COMPLETE_ALL657_MECHANICAL_REVIEW_HUMAN_APPROVAL_PENDING",
        "cases": 657,
        "differing_existing": 251,
        "new_candidates": 406,
        "current_capture_rows": len(current),
        "all_current_heads_and_body_md5_bound": True,
        "capture_observation_window": [min(captures), max(captures)],
        "delta_classes": dict(counts),
        "source_integrity": dict(integrity),
        "source_checks": dict(
            sum((Counter(c["source_review_counts"]) for c in cases), Counter())
        ),
        "human_decisions_filled": 0,
        "hosted_mutations": 0,
        "legal_approval": False,
        "editorial_approval": False,
        "execution_allowed": False,
        "publication_allowed": False,
        "normalization": "Body comparison excludes ONLY expected_revision and merge_manifest_id. Draft RPC request_key is outside the persisted body contract and removed when deriving desired body. Per-row original full bodies retained. Block comparisons ignore only generated block IDs and retain exact text/type/items.",
        "all745_current_actor_and_revision_preservation": "Existing archive proof remains separate; no actor substitution, head advance or retirement proposed.",
        "limitations": [
            "Machine proof cannot establish factual/legal correctness or original authorship.",
            "251 current values captured in separate bounded read-only transactions; fresh atomic guard required before execution.",
            "Source link and asset remote availability and rights not checked.",
            "Rich projection absent in Production remains independent schema/import execution gate.",
            "No public content rendering or browser acceptance performed.",
        ],
        "inputs": inputs,
        "outputs": {
            name: file_sha(out / name)
            for name in (
                "review-cases.jsonl.gz",
                "decisions-template.json",
                "index.html",
            )
        },
        "packets": files,
    }
    (out / "receipt.json").write_text(
        json.dumps(receipt, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf8",
    )
    print(
        json.dumps(
            {
                k: receipt[k]
                for k in (
                    "status",
                    "cases",
                    "delta_classes",
                    "source_integrity",
                    "source_checks",
                )
            },
            indent=2,
        )
    )
    verify_capture_files(workspace)
    write_link_gap_crosswalk(workspace)
    write_review_guide(workspace)
    verify_review_outputs(workspace)


if __name__ == "__main__":
    main()
