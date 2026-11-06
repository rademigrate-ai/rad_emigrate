"""Offline, case-specific decisions bound to immutable original-source evidence.

No fetch, SQL, publication, source rewrite, hierarchy guess or encoding repair.
Raw publisher HTML is data and is emitted only escaped under a restrictive CSP.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import html
import json
from collections import Counter, defaultdict
from pathlib import Path, PureWindowsPath

from tools.content_completion.source_limitations_v42 import _owned, _span_for
from tools.plan3_content.crawl import stable_id
from tools.plan3_content.parser import digest, text

ORIGINAL_SEAL = "a7f13fa7087820e64add7b446adf2fadaff734badcd676bb560fa6a3a7f197f7"
ORIGINAL_LEDGER = "3ec14396366690e47d0711fc0e9e4d2f8f5f3a497e9fda0aeed1c9869e2a5a22"
ORIGINAL_PROOF_SEAL = "dbefb25199f3de89d9da45eabd878623e4376ca767635a93337ffab78f4d858e"
ORIGINAL_COMPOSITION = (
    "ea3f5a51a38505bdf27bb2c523dbd8fcb90be7984d7ffcc45f14b911b92ed6a2"
)
EXPECTED_COUNTS = {"source": 64, "heading": 103, "link": 215, "encoding": 1}
CSP = (
    "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"
)
STYLE = """body{font:16px/1.6 system-ui,sans-serif;max-width:1100px;margin:32px auto;padding:0 20px;color:#17232e;background:#f8fafb}
a{color:#005c87}pre{white-space:pre-wrap;overflow-wrap:anywhere;direction:auto;background:white;padding:16px;border:1px solid #ccd5dd}
code{overflow-wrap:anywhere}article{border-top:2px solid #aab9c5;padding:24px 0}summary{cursor:pointer}li{margin:8px 0}
.small{font-size:13px}table{border-collapse:collapse}td,th{border:1px solid #ccd5dd;padding:8px;text-align:left}"""


def canonical(value):
    return json.dumps(
        value, ensure_ascii=True, sort_keys=True, separators=(",", ":")
    ).encode()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def case_hash(case):
    return hashlib.sha256(
        canonical({k: v for k, v in case.items() if k != "case_sha256"})
    ).hexdigest()


def packet_hash(packet):
    return hashlib.sha256(
        canonical({k: v for k, v in packet.items() if k != "packet_sha256"})
    ).hexdigest()


def rows(path):
    return [
        json.loads(line)
        for line in gzip.decompress(path.read_bytes()).decode("utf8").splitlines()
        if line
    ]


def link_case_identity(proof, ordinal):
    # Original link ledgers contain repeated identical proof rows. Preserve each
    # original row identity; never invent a one-to-one raw anchor assignment.
    return proof["capture_id"] + ":" + str(ordinal) + ":" + digest(proof)[:20]


def guard_output_directory(output, protected):
    destination = output.resolve()
    if any(destination.is_relative_to(original.resolve()) for original in protected):
        raise ValueError("review_output_must_not_overlap_sealed_originals")


def resolve_asset(original, roots):
    """Resolve moved runtime files without editing their sealed legacy paths."""
    direct = Path(original)
    if direct.is_file():
        return direct
    historical = PureWindowsPath(original)
    tails = []
    if not historical.is_absolute():
        tails.append(Path(*historical.parts))
    for anchor in ["RAD - Emigrate", "rad_full_content_v4"]:
        if anchor in historical.parts:
            tails.append(Path(*historical.parts[historical.parts.index(anchor) + 1 :]))
    for root in roots:
        for tail in tails:
            candidate = root / tail
            if (
                candidate.resolve().is_relative_to(root.resolve())
                and candidate.is_file()
            ):
                return candidate
    raise FileNotFoundError("sealed_raw_asset_unavailable:" + original)


def safe_text(value):
    return str(value).encode("utf8", errors="backslashreplace").decode("utf8")


def pre(value):
    content = (
        json.dumps(value, ensure_ascii=False, indent=2)
        if not isinstance(value, str)
        else value
    )
    return "<pre>" + html.escape(safe_text(content)) + "</pre>"


def page(title, body):
    return (
        '<!doctype html><html lang="en"><meta charset="utf-8">'
        '<meta http-equiv="Content-Security-Policy" content="'
        + html.escape(CSP, quote=True)
        + '">'
        "<title>"
        + html.escape(title)
        + "</title><style>"
        + STYLE
        + "</style><body><h1>"
        + html.escape(title)
        + "</h1>"
        + body
        + "</body></html>"
    )


def raw_evidence_html(raw):
    return page(
        "Untrusted original HTML — escaped evidence",
        "<p>Publisher markup is displayed as inert text. Invalid UTF-8 bytes use visible backslash escapes; "
        "this is evidence display, never an encoding repair.</p>"
        + pre("Raw SHA256: " + hashlib.sha256(raw).hexdigest())
        + pre(raw.decode("utf8", errors="surrogateescape")),
    )


def encoding_roundtrip(raw, expected_hash, codec):
    if hashlib.sha256(raw).hexdigest() != expected_hash:
        raise ValueError("raw_checksum_mismatch")
    try:
        decoded = raw.decode(codec, errors="strict")
        recovered = decoded.encode(codec, errors="strict")
    except (UnicodeError, LookupError) as exc:
        raise ValueError("strict_encoding_roundtrip_failed") from exc
    if recovered != raw:
        raise ValueError("encoding_roundtrip_bytes_differ")
    return {
        "codec": codec,
        "raw_html_sha256": expected_hash,
        "decoded_text_sha256": digest(decoded),
        "roundtrip_equal": True,
        "semantic_encoding_verified": False,
        "repair_proposed": False,
    }


def affected_block_index(articles):
    index = defaultdict(list)
    for article in articles:
        for section in article.get("sections", []):
            for block in section.get("blocks", []):
                for provenance in block.get("provenance", []):
                    key = (provenance["source_id"], provenance["block_index"])
                    row = {
                        "article_id": article["article_id"],
                        "locale": article["locale"],
                        "section_id": section.get("id", section.get("anchor")),
                        "block_id": block["id"],
                    }
                    if row not in index[key]:
                        index[key].append(row)
    return dict(index)


def decision_template(packet):
    return {
        "packet_sha256": packet["packet_sha256"],
        "publication_allowed": False,
        "decisions": [
            {
                "case_id": case["case_id"],
                "case_sha256": case["case_sha256"],
                "choice": None,
            }
            for case in packet["cases"]
        ],
    }


def owner_batches(cases):
    """Group identical decision menus, never replace the individual case hashes."""
    groups = defaultdict(list)
    for case in cases:
        proof = case.get("evidence", {}).get("original_proof", {})
        reason = sorted(case.get("ambiguity", {}).get("captured_assessment_counts", {}))
        key = (
            case["category"],
            proof.get("disposition", ""),
            tuple(reason),
            tuple(c["id"] for c in case["choices"]),
        )
        groups[key].append(case)
    result = []
    for key, members in sorted(groups.items()):
        group = {
            "batch_id": key[0] + ":" + digest(key)[:16],
            "category": key[0],
            "evidence_class": key[1],
            "source_assessment_classes": list(key[2]),
            "case_refs": [
                {"case_id": c["case_id"], "case_sha256": c["case_sha256"]}
                for c in members
            ],
            "choices": [
                {"id": c["id"], "label": c.get("label", c["id"])}
                for c in members[0]["choices"]
            ],
            "scope": "Same menu only: inspect linked individual evidence/effects. A selected batch choice applies separately to every listed hash-bound case; no editorial/publication approval.",
        }
        group["batch_sha256"] = digest(group)
        result.append(group)
    return result


def batch_template(packet):
    return {
        "packet_sha256": packet["packet_sha256"],
        "publication_allowed": False,
        "batches": [
            {
                "batch_id": g["batch_id"],
                "batch_sha256": g["batch_sha256"],
                "choice": None,
            }
            for g in packet["owner_batches"]
        ],
    }


def expand_batches(packet, selection):
    if set(selection) != {"packet_sha256", "publication_allowed", "batches"}:
        raise ValueError("batch_selection_fields_invalid")
    if (
        selection["packet_sha256"] != packet["packet_sha256"]
        or selection["publication_allowed"] is not False
    ):
        raise ValueError("stale_batch_or_publication_forbidden")
    expected = owner_batches(packet["cases"])
    if expected != packet.get("owner_batches"):
        raise ValueError("batch_case_hash_binding_invalid")
    groups = {g["batch_id"]: g for g in expected}
    seen, decisions = set(), []
    for entry in selection["batches"]:
        if not isinstance(entry, dict) or set(entry) != {
            "batch_id",
            "batch_sha256",
            "choice",
        }:
            raise ValueError("batch_entry_fields_invalid")
        identity = entry["batch_id"]
        if identity in seen or identity not in groups:
            raise ValueError("duplicate_or_unknown_batch")
        seen.add(identity)
        group = groups[identity]
        if entry["batch_sha256"] != group["batch_sha256"]:
            raise ValueError("stale_batch_hash")
        selected_choice = entry["choice"]
        if selected_choice is not None and selected_choice not in [
            c["id"] for c in group["choices"]
        ]:
            raise ValueError("illegal_batch_choice")
        decisions.extend(
            {**ref, "choice": selected_choice} for ref in group["case_refs"]
        )
    return {
        "packet_sha256": packet["packet_sha256"],
        "publication_allowed": False,
        "decisions": decisions,
    }


def validate_decisions(packet, batch):
    if packet.get("publication_allowed") is not False or packet_hash(
        packet
    ) != packet.get("packet_sha256"):
        raise ValueError("packet_hash_or_publication_invalid")
    if set(batch) != {"packet_sha256", "publication_allowed", "decisions"}:
        raise ValueError("decision_batch_fields_invalid")
    if (
        batch.get("publication_allowed") is not False
        or batch["packet_sha256"] != packet["packet_sha256"]
    ):
        raise ValueError("stale_packet_or_publication_forbidden")
    for original, expected in packet["inputs"].items():
        path = Path(original)
        if not path.is_file() or sha(path) != expected:
            raise ValueError("stale_original_input:" + original)
    cases = {}
    for case in packet["cases"]:
        if case_hash(case) != case.get("case_sha256") or case["case_id"] in cases:
            raise ValueError("case_hash_or_duplicate_invalid")
        cases[case["case_id"]] = case
        if any(
            item.get("effect", {}).get("publication_allowed") is not False
            for item in case["choices"]
        ):
            raise ValueError("nested_publication_forbidden")
    seen, accepted = set(), []
    if not isinstance(batch["decisions"], list):
        raise TypeError("decisions_list_required")
    for decision in batch["decisions"]:
        if not isinstance(decision, dict) or set(decision) != {
            "case_id",
            "case_sha256",
            "choice",
        }:
            raise ValueError("decision_fields_invalid")
        identity = decision["case_id"]
        if identity in seen or identity not in cases:
            raise ValueError("duplicate_or_unknown_case")
        seen.add(identity)
        case = cases[identity]
        if decision["case_sha256"] != case["case_sha256"]:
            raise ValueError("stale_case_hash")
        choice = decision["choice"]
        if choice is None:
            continue
        if not isinstance(choice, str):
            raise TypeError("finite_choice_string_required")
        choices = {item["id"]: item for item in case["choices"]}
        if choice not in choices:
            raise ValueError("illegal_choice")
        accepted.append(
            {
                "case_id": identity,
                "case_sha256": case["case_sha256"],
                "source_url": case["source_url"],
                "capture_ids": case["capture_ids"],
                "choice": choice,
                "effect": choices[choice]["effect"],
                "original_evidence_preserved": True,
            }
        )
    return {
        "status": "OFFLINE_DECISION_PLAN_ONLY",
        "packet_sha256": packet["packet_sha256"],
        "publication_allowed": False,
        "hosted_writes": 0,
        "source_rewrites": 0,
        "decisions": accepted,
        "remaining_undecided": len(cases) - len(accepted),
        "factual_editorial_approval_inferred": False,
    }


def choice(identity, caption, action, **effect):
    return {
        "id": identity,
        "label": caption,
        "effect": {
            "action": action,
            **effect,
            "preserve_original_reference": True,
            "source_bytes_changed": False,
            "publication_allowed": False,
            "execution_scope": "offline_plan_only",
        },
    }


def verify_seal(directory, filename, expected=None):
    manifest_path = directory / filename
    if expected is not None and sha(manifest_path) != expected:
        raise ValueError("original_manifest_binding_required")
    manifest = json.loads(manifest_path.read_text(encoding="utf8"))
    for name, checksum in manifest["files"].items():
        candidate = directory / name
        if (
            candidate.resolve().parent != directory.resolve()
            or sha(candidate) != checksum
        ):
            raise ValueError("sealed_file_hash_mismatch:" + name)
    return manifest


def decision_schema(packet):
    alternatives = []
    for case in packet["cases"]:
        alternatives.append(
            {
                "type": "object",
                "additionalProperties": False,
                "required": ["case_id", "case_sha256", "choice"],
                "properties": {
                    "case_id": {"const": case["case_id"]},
                    "case_sha256": {"const": case["case_sha256"]},
                    "choice": {"enum": [None] + [c["id"] for c in case["choices"]]},
                },
            }
        )
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "type": "object",
        "additionalProperties": False,
        "required": ["packet_sha256", "publication_allowed", "decisions"],
        "properties": {
            "packet_sha256": {"const": packet["packet_sha256"]},
            "publication_allowed": {"const": False},
            "decisions": {"type": "array", "items": {"oneOf": alternatives}},
        },
        "$comment": "Runtime validator additionally rejects duplicate IDs and changed original input hashes. Null is undecided, never approval.",
    }


def build_packet(
    source_input, proofs, composition, unresolved_ledger, asset_roots, output
):
    guard_output_directory(
        output, [source_input, proofs, composition, unresolved_ledger.parent]
    )
    source_seal = verify_seal(source_input, "source-input-manifest.json", ORIGINAL_SEAL)
    proof_seal = verify_seal(proofs, "manifest.json", ORIGINAL_PROOF_SEAL)
    composition_seal = verify_seal(composition, "manifest.json", ORIGINAL_COMPOSITION)
    if (
        proof_seal["source_input_manifest_sha256"] != ORIGINAL_SEAL
        or proof_seal["unresolved_ledger_sha256"] != ORIGINAL_LEDGER
        or sha(unresolved_ledger) != ORIGINAL_LEDGER
        or composition_seal["source_input_manifest_sha256"] != ORIGINAL_SEAL
    ):
        raise ValueError("original_scope_binding_required")
    ledger = rows(unresolved_ledger)
    url_proofs = rows(proofs / "url-dispositions.jsonl.gz")
    if (
        len(ledger) != 421
        or len(url_proofs) != 421
        or len({r["source_id"] for r in ledger}) != 421
        or {(r["source_id"], r["url"]) for r in ledger}
        != {(r["source_id"], r["url"]) for r in url_proofs}
        or any(r["source_id"] != stable_id(r["url"]) for r in ledger)
    ):
        raise ValueError("exact_original_421_scope_required")
    sources = rows(source_input / "sources.jsonl.gz")
    captures = rows(source_input / "capture-versions.jsonl.gz")
    by_capture = {r["capture_id"]: r for r in captures}
    selected = {r["capture_id"]: r for r in sources}
    articles = rows(composition / "articles.jsonl.gz")
    affected = affected_block_index(articles)
    output.mkdir(parents=True, exist_ok=True)
    evidence_dir = output / "evidence"
    evidence_dir.mkdir(exist_ok=True)
    inputs = {}
    inputs[str(Path(__file__).resolve())] = sha(Path(__file__).resolve())
    for directory, name, seal in [
        (source_input, "source-input-manifest.json", source_seal),
        (proofs, "manifest.json", proof_seal),
        (composition, "manifest.json", composition_seal),
    ]:
        for path in [directory / name] + [directory / item for item in seal["files"]]:
            inputs[str(path.resolve())] = sha(path)
    inputs[str(unresolved_ledger.resolve())] = sha(unresolved_ledger)
    raw_cache, contexts = {}, {}

    def context(capture):
        identity = capture["capture_id"] + "-" + digest(capture)[:12]
        if identity in contexts:
            return contexts[identity]
        raw_path = resolve_asset(capture["raw_html_asset"], asset_roots)
        inputs[str(raw_path.resolve())] = sha(raw_path)
        checksum = capture["raw_html_sha256"]
        if checksum not in raw_cache:
            raw = gzip.decompress(raw_path.read_bytes())
            if hashlib.sha256(raw).hexdigest() != checksum:
                raise ValueError("raw_checksum_mismatch")
            (evidence_dir / (checksum + ".html")).write_text(
                raw_evidence_html(raw), encoding="utf8"
            )
            raw_cache[checksum] = raw
        if (
            capture.get("body_sha256") is not None
            and digest(capture.get("body_text", "")) != capture["body_sha256"]
        ):
            raise ValueError("body_checksum_mismatch")
        if (
            capture.get("structure_sha256") is not None
            and digest(capture.get("blocks", [])) != capture["structure_sha256"]
        ):
            raise ValueError("structure_checksum_mismatch")
        body_file = "evidence/" + identity + ".html"
        (output / body_file).write_text(
            page(
                "Complete original capture " + capture["capture_id"],
                "<p>Immutable original capture, not an approved article.</p>"
                + pre(capture),
            ),
            encoding="utf8",
        )
        result = {
            "capture_id": capture["capture_id"],
            "source_id": capture["source_id"],
            "url": capture["url"],
            "resolved_url": capture.get("resolved_url"),
            "title": capture.get("title"),
            "language": capture.get("language"),
            "raw_html_sha256": checksum,
            "raw_original_asset": str(raw_path.resolve()),
            "raw_display_html": "evidence/" + checksum + ".html",
            "full_capture_html": body_file,
            "body_sha256": capture.get("body_sha256"),
            "structure_sha256": capture.get("structure_sha256"),
            "http_status": capture.get("http_status"),
            "completeness": capture.get("completeness"),
            "block_count": len(capture.get("blocks", [])),
        }
        contexts[identity] = result
        return result

    def affected_rows(source_id, indices=None):
        collected = []
        for (sid, index), destinations in affected.items():
            if sid != source_id or (indices is not None and index not in indices):
                continue
            for dest in destinations:
                row = {**dest, "source_block_index": index}
                if row not in collected:
                    collected.append(row)
        return collected

    def base(category, identity, source_id, url, capture_rows, proof):
        references = [context(c) for c in capture_rows]
        for ref in references:
            if (
                proof.get("raw_html_sha256")
                and proof["raw_html_sha256"] != ref["raw_html_sha256"]
            ):
                raise ValueError("case_capture_raw_binding_mismatch")
        return {
            "case_id": category + ":" + identity,
            "category": category,
            "source_id": source_id,
            "source_url": url,
            "capture_ids": [c["capture_id"] for c in capture_rows],
            "evidence": {"original_proof": proof, "captures": references},
            "publication_allowed": False,
            "human_decision": None,
            "recommendation": None,
            "original_reference_preserved": True,
        }

    cases = []
    for proof in url_proofs:
        if proof["disposition"] != "REQUIRES_HUMAN_CLASSIFICATION":
            continue
        capture_rows = [by_capture[cid] for cid in proof["original_capture_ids"]]
        case = base(
            "source",
            proof["source_id"],
            proof["source_id"],
            proof["url"],
            capture_rows,
            proof,
        )
        assessments = Counter(a["disposition"] for a in proof["capture_assessments"])
        case["ambiguity"] = {
            "captured_assessment_counts": dict(assessments),
            "reason": "Captured content is an error page, lacks a complete owned body, is a placeholder/title-only page or is thin. Neither URL shape nor title proves a missing article's content or permanent absence.",
            "capture_block_positions": {
                c["capture_id"]: list(range(len(c.get("blocks", []))))
                for c in capture_rows
            },
        }
        case["affected_destinations"] = affected_rows(proof["source_id"])
        case["destination_mapping_basis"] = (
            "Exact source provenance only; empty means no baseline imported block, never an invented article ID."
        )
        case["choices"] = [
            choice(
                "keep_original_unclassified",
                "Keep this original URL unresolved",
                "retain_original_unresolved_no_import",
            ),
            choice(
                "request_better_copy",
                "Request an original publisher copy for this URL",
                "queue_exact_original_url_copy_request_no_network",
                requested_url=proof["url"],
                required="Raw bytes + acquisition identity + complete owned body; separate hash-checked intake",
            ),
        ]
        if set(assessments) == {"EXPLICIT_ERROR_PAGE_NOT_RECOVERED_ARTICLE"}:
            case["choices"].append(
                choice(
                    "record_error_capture",
                    "Record captured error page while keeping the original URL unresolved",
                    "classify_only_captured_error_not_original_article",
                    capture_ids=case["capture_ids"],
                )
            )
            case["recommendation"] = {
                "choice": "record_error_capture",
                "mechanical_basis": "Every captured assessment independently identifies an explicit error page. This classifies only these captures; it proves no article absence or irrecoverability.",
            }
        elif set(assessments) == {"PLACEHOLDER_OR_TITLE_ONLY_REQUIRES_REVIEW"}:
            case["choices"].append(
                choice(
                    "record_placeholder_capture",
                    "Classify these captures as placeholder/title-only; keep URL unresolved",
                    "classify_current_capture_placeholder_only",
                    capture_ids=case["capture_ids"],
                )
            )
        if set(assessments) == {
            "THIN_NONHEADING_BODY_REQUIRES_HUMAN_CLASSIFICATION"
        } and all(
            a.get("complete_body_identity_verified")
            for a in proof["capture_assessments"]
        ):
            case["choices"].append(
                choice(
                    "retain_thin_body_candidate",
                    "Treat the displayed exact thin body as a draft-intake candidate",
                    "queue_exact_immutable_thin_body_for_separate_draft_intake",
                    capture_body_hashes=[c.get("body_sha256") for c in capture_rows],
                )
            )
        cases.append(case)

    for proof in rows(proofs / "heading-dispositions.jsonl.gz"):
        if proof["disposition"] not in {
            "HEADING_OCCURRENCE_REQUIRES_REVIEW",
            "BODY_IDENTITY_REQUIRES_REVIEW",
        }:
            continue
        capture = selected[proof["capture_id"]]
        case = base(
            "heading",
            proof["capture_id"] + ":" + str(proof["block_index"]),
            proof["source_id"],
            proof["url"],
            [capture],
            proof,
        )
        index = proof["block_index"]
        block = capture["blocks"][index]
        if digest(block["text"]) != proof["text_sha256"]:
            raise ValueError("heading_block_hash_mismatch")
        document, encoding, body, owned_span, spans = _owned(
            raw_cache[capture["raw_html_sha256"]]
        )
        matches = []
        if body is not None:
            # Include the full document title candidates as alternatives, explicitly
            # distinguishing outside-container hits from owned article occurrences.
            from bs4 import BeautifulSoup

            soup = BeautifulSoup(document, "html.parser")
            for tag in soup.find_all(
                ["h1", "h2", "h3", "h4", "h5", "h6", "p", "b", "strong"]
            ):
                if text(tag.get_text(" ", strip=True)) != block["text"]:
                    continue
                span = _span_for(tag, spans)
                if span:
                    matches.append(
                        {
                            "tag": tag.name,
                            "decoded_character_start": span["start"],
                            "decoded_character_end": span["end"],
                            "inside_owned_container": bool(
                                owned_span
                                and owned_span["start"]
                                <= span["start"]
                                < span["end"]
                                <= owned_span["end"]
                            ),
                            "raw_markup": document[span["start"] : span["end"]],
                            "raw_markup_sha256": digest(
                                document[span["start"] : span["end"]]
                            ),
                        }
                    )
        case["block_positions"] = {
            "index": index,
            "text_sha256": proof["text_sha256"],
            "stored_block": block,
            "previous": capture["blocks"][max(0, index - 2) : index],
            "following": capture["blocks"][index + 1 : index + 3],
        }
        case["evidence"]["literal_raw_occurrences"] = matches
        case["evidence"]["owned_body_span"] = (
            {k: owned_span[k] for k in ["start", "end"]} if owned_span else None
        )
        case["evidence"]["decoded_encoding"] = encoding
        case["ambiguity"] = {
            "reason": "Complete body identity could not be reproduced."
            if proof["disposition"] == "BODY_IDENTITY_REQUIRES_REVIEW"
            else "Stored heading occurrence count/order does not match the owned raw heading candidates. Title/outside-container and emphasis occurrences are shown without assigning a numeric hierarchy.",
            "matching_document_occurrences": len(matches),
            "numeric_level_inferred": False,
        }
        case["affected_destinations"] = affected_rows(proof["source_id"], {index})
        case["choices"] = [
            choice(
                "keep_existing_unresolved",
                "Preserve current block and unresolved review flag",
                "preserve_exact_block_and_open_review",
                source_block_index=index,
            ),
            choice(
                "request_better_copy",
                "Request an unambiguous original copy",
                "queue_exact_original_url_copy_request_no_network",
                requested_url=proof["url"],
            ),
        ]
        if proof["complete_body_identity_verified"]:
            case["choices"].append(
                choice(
                    "retain_unlevelled",
                    "Keep this text as a heading without a numeric level",
                    "propose_heading_level_null_preserve_text_and_provenance",
                    source_block_index=index,
                    text_sha256=proof["text_sha256"],
                    level=None,
                    affected_block_ids=[
                        r["block_id"] for r in case["affected_destinations"]
                    ],
                )
            )
        cases.append(case)

    for ordinal, proof in enumerate(rows(proofs / "link-dispositions.jsonl.gz")):
        if proof["disposition"] != "OWNED_LINK_TARGET_REQUIRES_REVIEW":
            continue
        capture = selected[proof["capture_id"]]
        identity = link_case_identity(proof, ordinal)
        case = base(
            "link", identity, proof["source_id"], proof["url"], [capture], proof
        )
        case["original_proof_row_index"] = ordinal
        case["proof_row_identity_basis"] = (
            "Pinned original link ledger row; identical repeated proof rows remain distinct without an invented raw-anchor assignment."
        )
        document, _, _, owned_span, _ = _owned(raw_cache[capture["raw_html_sha256"]])
        for match in proof["raw_matches"]:
            fragment = document[
                match["decoded_character_start"] : match["decoded_character_end"]
            ]
            if (
                fragment != match["raw_anchor_tag"]
                or digest(fragment) != match["raw_anchor_sha256"]
            ):
                raise ValueError("link_raw_span_mismatch")
        indices = [
            i
            for i, b in enumerate(capture["blocks"])
            if proof["label"]
            and proof["label"] in text(json.dumps(b, ensure_ascii=False))
        ]
        case["block_positions"] = {
            "candidate_source_block_indices": indices,
            "basis": "Label substring in exact original block; occurrence-to-block binding is not proven.",
            "raw_occurrence_positions": [
                {
                    "start": m["decoded_character_start"],
                    "end": m["decoded_character_end"],
                }
                for m in proof["raw_matches"]
            ],
        }
        case["affected_destinations"] = affected_rows(proof["source_id"])
        case["affected_destination_scope"] = (
            "All blocks from this exact source are listed conservatively; link occurrence-to-block binding remains unproven."
        )
        case["alternatives"] = proof["original_targets"]
        case["ambiguity"] = {
            "reason": "Multiple distinct original href/target spellings survive normalization, or no owned occurrence was uniquely verified. A shared canonical URL does not authorize discarding or aliasing the originals.",
            "canonical_url": proof["canonical_url"],
            "label": proof["label"],
            "owned_raw_anchor_count": len(proof["raw_matches"]),
            "distinct_original_target_count": len(proof["original_targets"]),
            "alias_inferred": False,
        }
        case["choices"] = [
            choice(
                "preserve_originals_unresolved",
                "Keep every original href and unresolved mapping",
                "preserve_all_original_hrefs_no_alias",
                original_targets=proof["original_targets"],
                canonical_url=proof["canonical_url"],
            ),
            choice(
                "request_better_copy",
                "Request source clarification for this link label",
                "queue_link_clarification_no_network",
                source_url=proof["url"],
                label=proof["label"],
                canonical_url=proof["canonical_url"],
            ),
        ]
        if proof["raw_matches"] and proof["original_targets"]:
            case["choices"].append(
                choice(
                    "retain_distinct_occurrences",
                    "Retain each captured href occurrence as a distinct original reference",
                    "propose_distinct_occurrence_references_no_alias_or_target_rewrite",
                    original_targets=proof["original_targets"],
                    raw_occurrences=proof["raw_matches"],
                    affected_article_locales=sorted(
                        {
                            (r["article_id"], r["locale"])
                            for r in case["affected_destinations"]
                        }
                    ),
                )
            )
            case["recommendation"] = {
                "choice": "retain_distinct_occurrences",
                "mechanical_basis": "The hash-checked owned raw spans explicitly retain the listed distinct hrefs. Preserve each rather than infer equivalence; no target availability, alias or factual endorsement is inferred.",
            }
        cases.append(case)

    for proof in rows(proofs / "encoding-dispositions.jsonl.gz"):
        matching = [
            c for c in captures if c.get("raw_html_sha256") == proof["raw_html_sha256"]
        ]
        if not matching:
            raise ValueError("encoding_capture_identity_required")
        capture = matching[0]
        case = base(
            "encoding",
            proof["raw_html_sha256"],
            capture["source_id"],
            capture["url"],
            matching,
            proof,
        )
        raw = raw_cache[proof["raw_html_sha256"]]
        document = raw.decode("utf8", errors="surrogateescape")
        if document.encode("utf8", errors="surrogateescape") != raw:
            raise ValueError("surrogateescape_roundtrip_failed")
        positions = proof["owned_body_defect_positions"]
        case["evidence"]["byte_defects"] = [
            {
                "decoded_character_position": pos,
                "raw_byte_position": len(
                    document[:pos].encode("utf8", errors="surrogateescape")
                ),
                "byte_hex": document[pos]
                .encode("utf8", errors="surrogateescape")
                .hex(),
                "surrounding_original_text": document[max(0, pos - 100) : pos + 101],
            }
            for pos in positions
        ]
        span = proof["owned_body_span"]
        owned_bytes = document[span["start"] : span["end"]].encode(
            "utf8", errors="surrogateescape"
        )
        case["evidence"]["owned_body_bytes_sha256"] = hashlib.sha256(
            owned_bytes
        ).hexdigest()
        case["evidence"]["byte_preservation_roundtrip_equal"] = True
        case["evidence"]["repair_proposed"] = False
        case["block_positions"] = {
            "all_capture_block_indices": list(range(len(capture.get("blocks", [])))),
            "exact_defect_to_parsed_block_mapping": "UNPROVEN_RAW_BYTE_POSITIONS_PROVIDED",
        }
        case["affected_destinations"] = affected_rows(capture["source_id"])
        case["ambiguity"] = {
            "reason": "Invalid UTF-8 bytes lie inside the owned body. Raw bytes and byte positions are exact; the intended characters/codec are not proven. A reversible codec alone cannot establish intended publisher text.",
            "encoding_inferred": False,
            "original_bytes_changed": False,
        }
        case["choices"] = [
            choice(
                "preserve_bytes_exception",
                "Preserve exact bytes and keep encoding exception open",
                "retain_owned_body_bytes_and_open_encoding_exception",
                raw_html_sha256=proof["raw_html_sha256"],
                owned_body_bytes_sha256=case["evidence"]["owned_body_bytes_sha256"],
            ),
            choice(
                "request_publisher_copy",
                "Request publisher-confirmed original encoding or a clean original copy",
                "queue_publisher_copy_request_no_network",
                source_url=capture["url"],
                raw_html_sha256=proof["raw_html_sha256"],
                repair_requirements="Separate proposal requires original raw SHA256, strict decoder/encoder byte roundtrip and primary proof of intended characters; no repair is selected here.",
            ),
        ]
        cases.append(case)
    cases.sort(key=lambda c: c["case_id"])
    counts = dict(Counter(c["category"] for c in cases))
    if counts != EXPECTED_COUNTS or len({c["case_id"] for c in cases}) != 383:
        raise ValueError("complete_383_case_scope_required:" + str(counts))
    for case in cases:
        if not case["capture_ids"] or not case["choices"]:
            raise ValueError("case_evidence_or_choices_missing")
        case["case_sha256"] = case_hash(case)
    packet = {
        "version": "RAD_REVIEW_PACKETS_V4.3",
        "source_base_commit": "81f11ce176d9645ae0503e360e22ef6a414c355b",
        "source_input_manifest_sha256": ORIGINAL_SEAL,
        "original_unresolved_ledger_sha256": ORIGINAL_LEDGER,
        "publication_allowed": False,
        "hosted_writes": 0,
        "network_calls": 0,
        "editorial_approval_inferred": False,
        "inputs": inputs,
        "counts": counts,
        "cases": cases,
    }
    packet["packet_sha256"] = packet_hash(packet)
    packet["owner_batches"] = owner_batches(cases)
    packet["packet_sha256"] = packet_hash(packet)
    (output / "review-packet.json").write_text(
        json.dumps(packet, ensure_ascii=True, indent=2) + "\n", encoding="utf8"
    )
    (output / "decisions-template.json").write_text(
        json.dumps(decision_template(packet), indent=2) + "\n", encoding="utf8"
    )
    (output / "owner-batches-template.json").write_text(
        json.dumps(batch_template(packet), indent=2) + "\n", encoding="utf8"
    )
    (output / "decisions.schema.json").write_text(
        json.dumps(decision_schema(packet), indent=2) + "\n", encoding="utf8"
    )
    index_body = (
        "<p>383 original-evidence cases. Choose only after reading each case and its full original capture. "
        "No option is preselected. Recommendations describe mechanical preservation only.</p>"
        "<p>Edit <a href='decisions-template.json'>the blank JSON decision template</a>; "
        "the offline validator produces an action plan and never modifies source or publishes.</p>"
        "<p>Packet SHA256 <code>" + packet["packet_sha256"] + "</code></p>"
        "<ul>"
        + "".join(
            "<li><a href='#"
            + category
            + "'>"
            + category
            + " — "
            + str(count)
            + "</a></li>"
            for category, count in sorted(counts.items())
        )
        + "</ul>"
    )
    index_body += "<h2>Minimal owner decision batches</h2><p>Read individual cases before choosing a batch. Blank means undecided. Split any batch by using individual case choices instead; the validator rejects duplicates.</p><p><a href='owner-batches-template.json'>Blank batch decision template</a></p>"
    for group in packet["owner_batches"]:
        index_body += (
            "<details><summary>"
            + html.escape(group["batch_id"])
            + " — "
            + str(len(group["case_refs"]))
            + " cases</summary>"
            + pre({k: v for k, v in group.items() if k != "case_refs"})
            + "<ul>"
        )
        for ref in group["case_refs"]:
            filename = (
                "case-"
                + hashlib.sha256(ref["case_id"].encode()).hexdigest()[:24]
                + ".html"
            )
            index_body += (
                "<li><a href='"
                + filename
                + "'>"
                + html.escape(ref["case_id"])
                + "</a> <code>"
                + ref["case_sha256"]
                + "</code></li>"
            )
        index_body += "</ul></details>"
    for category in sorted(counts):
        index_body += "<h2 id='" + category + "'>" + category + "</h2><ol>"
        for case in [c for c in cases if c["category"] == category]:
            filename = (
                "case-"
                + hashlib.sha256(case["case_id"].encode()).hexdigest()[:24]
                + ".html"
            )
            body_html = (
                "<p><a href='index.html'>All cases</a></p><p>Case SHA256 <code>"
                + case["case_sha256"]
                + "</code></p>"
            )
            body_html += "<h2>Original source</h2>" + pre(case["source_url"])
            body_html += "<h2>Complete original context</h2><ul>"
            for ref in case["evidence"]["captures"]:
                body_html += (
                    "<li>"
                    + html.escape(ref["capture_id"])
                    + ": <a href='"
                    + ref["full_capture_html"]
                    + "'>full original body and blocks</a> · "
                    "<a href='"
                    + ref["raw_display_html"]
                    + "'>full escaped original HTML</a></li>"
                )
            body_html += "</ul><h2>Evidence, alternatives and exact effects</h2>" + pre(
                case
            )
            (output / filename).write_text(
                page(case["case_id"], body_html), encoding="utf8"
            )
            index_body += (
                "<li><a href='"
                + filename
                + "'>"
                + html.escape(case["case_id"])
                + "</a> "
                + html.escape(case["source_url"])
                + "</li>"
            )
        index_body += "</ol>"
    (output / "index.html").write_text(
        page("RAD original-source owner decision packet", index_body), encoding="utf8"
    )
    # Verify all inputs again: the packet cannot silently span a source rewrite.
    for filename, checksum in inputs.items():
        if sha(Path(filename)) != checksum:
            raise ValueError("input_changed_during_packet_generation")
    blank_plan = validate_decisions(packet, decision_template(packet))
    receipt = {
        "status": "PASS_ALL_383_EVIDENCE_CASES_PREPARED_NO_DECISIONS_MADE",
        "packet_sha256": packet["packet_sha256"],
        "counts": counts,
        "cases": len(cases),
        "unique_raw_files": len(raw_cache),
        "capture_contexts": len(contexts),
        "minimal_owner_batches": len(packet["owner_batches"]),
        "raw_hashes_verified": True,
        "original_seal_unchanged": True,
        "blank_template_undecided": blank_plan["remaining_undecided"],
        "case_hashes_verified": True,
        "publication_allowed": False,
        "hosted_writes": 0,
        "network_calls": 0,
        "source_rewrites": 0,
        "files": {
            str(p.relative_to(output)).replace("\\", "/"): sha(p)
            for p in sorted(output.rglob("*"))
            if p.is_file() and p.name != "manifest.json"
        },
    }
    (output / "manifest.json").write_text(
        json.dumps(receipt, indent=2) + "\n", encoding="utf8"
    )
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("build")
    for name in [
        "source-input",
        "proofs",
        "composition",
        "unresolved-ledger",
        "output",
    ]:
        build.add_argument("--" + name, type=Path, required=True)
    build.add_argument("--asset-root", type=Path, action="append", required=True)
    apply = sub.add_parser("apply-offline")
    apply.add_argument("--packet", type=Path, required=True)
    apply.add_argument("--decisions", type=Path, required=True)
    apply.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "build":
        receipt = build_packet(
            args.source_input,
            args.proofs,
            args.composition,
            args.unresolved_ledger,
            args.asset_root,
            args.output,
        )
        print(json.dumps({k: v for k, v in receipt.items() if k != "files"}, indent=2))
    else:
        packet = json.loads(args.packet.read_text(encoding="utf8"))
        batch = json.loads(args.decisions.read_text(encoding="utf8"))
        if "batches" in batch:
            batch = expand_batches(packet, batch)
        plan = validate_decisions(packet, batch)
        protected = {Path(p).resolve() for p in packet["inputs"]}
        protected.update([args.packet.resolve(), args.decisions.resolve()])
        if args.output.resolve() in protected or args.output.exists():
            raise ValueError("new_offline_output_path_required")
        args.output.write_text(
            json.dumps(plan, ensure_ascii=True, indent=2) + "\n", encoding="utf8"
        )
        print(
            json.dumps(
                {
                    "status": plan["status"],
                    "decisions": len(plan["decisions"]),
                    "remaining_undecided": plan["remaining_undecided"],
                    "publication_allowed": False,
                }
            )
        )


if __name__ == "__main__":
    main()
