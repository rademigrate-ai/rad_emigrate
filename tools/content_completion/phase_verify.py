"""Offline verification of raw bytes, rich provenance and deterministic delivery."""

import argparse
import gzip
import json
import tempfile
from collections import Counter
from pathlib import Path

from tools.content_completion.phase_bundle import confined, recompose, save_json, sha
from tools.content_completion.phase_delivery import build, verify_payload
from tools.content_completion.source_evidence import PARSER_VERSION, parse_mohajer
from tools.content_consolidation.import_payload import payload
from tools.plan3_content.dataset import read_jsonl
from tools.plan3_content.parser import digest


def artifact_files(directory):
    return sorted(
        p
        for p in directory.rglob("*")
        if p.is_file()
        and not any(
            x in p.relative_to(directory).parts
            for x in (".network-cache", "verification")
        )
        and p.name not in ("final-manifest.json",)
        and not p.name.endswith((".zip", ".progress.jsonl"))
    )


def seal(directory):
    rows = [
        {
            "path": p.relative_to(directory).as_posix(),
            "bytes": p.stat().st_size,
            "sha256": sha(p.read_bytes()),
        }
        for p in artifact_files(directory)
    ]
    result = {
        "format": "rad-phases1-4-artifacts-v1",
        "files": rows,
        "file_count": len(rows),
        "bytes": sum(r["bytes"] for r in rows),
        "generation": "offline phase_bundle, phase_delivery and phase_verify; pinned evidence time 2026-10-28T09:30:43Z",
        "provenance": "source-captures + source-access-observations + reference-input-manifest",
        "exclusions": [
            "final-manifest.json self digest",
            ".network-cache transient transport cache",
            "verification runtime receipts bound to final Git SHA",
            "*.zip transport envelopes",
            "*.progress.jsonl transient duplicate network journal",
        ],
        "hosted_writes": 0,
        "publication_allowed": False,
    }
    save_json(directory / "final-manifest.json", result)
    return result


def verify(directory, reproduce=False):
    manifest = json.loads(
        (directory / "final-manifest.json").read_text(encoding="utf-8")
    )
    actual = {p.relative_to(directory).as_posix() for p in artifact_files(directory)}
    if actual != {r["path"] for r in manifest["files"]}:
        raise ValueError("manifest_file_set_changed")
    for row in manifest["files"]:
        data = confined(directory, row["path"]).read_bytes()
        if len(data) != row["bytes"] or sha(data) != row["sha256"]:
            raise ValueError("artifact_manifest_hash_mismatch:" + row["path"])
    captures = read_jsonl(directory / "source-captures.jsonl.gz")
    original_index = json.loads(
        (directory / "grok-original-file-index.json").read_text(encoding="utf-8")
    )
    if len(original_index) != 355:
        raise ValueError("original_Grok_file_index_incomplete")
    for row in original_index:
        data = confined(directory, row["asset"]).read_bytes()
        if len(data) != row["size"] or sha(data) != row["sha256"]:
            raise ValueError("original_Grok_asset_hash_mismatch")
    raw_count, block_count = 0, 0
    parsed_raw = {}
    for capture in captures:
        body = "\n\n".join(b["text"] for b in capture["blocks"])
        if (
            body != capture["body_text"]
            or (digest(body) if body else None) != capture["body_sha256"]
            or digest(capture["blocks"]) != capture["structure_sha256"]
        ):
            raise ValueError("capture_body_structure_hash_mismatch")
        if capture["raw_html_asset"]:
            raw = gzip.decompress(
                confined(directory, capture["raw_html_asset"]).read_bytes()
            )
            if sha(raw) != capture["raw_html_sha256"]:
                raise ValueError("original_raw_html_hash_mismatch")
            if reproduce and capture["parser_version"] == PARSER_VERSION:
                key = (capture["url"], capture["raw_html_sha256"])
                if key not in parsed_raw:
                    parsed_raw[key] = parse_mohajer(raw, capture["url"])
                parsed = parsed_raw[key]
                if not any(
                    a["body_text"] == body
                    and a["blocks"] == capture["blocks"]
                    and a["completeness"] == capture["completeness"]
                    for a in parsed["articles"]
                ):
                    raise ValueError(
                        "raw_to_rich_reproduction_mismatch:" + capture["capture_id"]
                    )
            raw_count += 1
        block_count += len(capture["blocks"])
    master = read_jsonl(directory / "source-master.jsonl.gz")
    if len({r["source_id"] for r in master}) != len(master) or len(
        {r["url"] for r in master}
    ) != len(master):
        raise ValueError("source_identity_collision")
    registry = json.loads(
        Path("supabase/contracts/rad_v1.json").read_text(encoding="utf-8")
    )
    prepared = directory / "prepared"
    rows = read_jsonl(prepared / "new-draft-payloads.jsonl.gz") + read_jsonl(
        prepared / "canonical-revision-payloads.jsonl.gz"
    )
    snapshots = {}
    for row in rows:
        verify_payload(row, snapshots)
        source_map = {s["source_id"]: s for s in row["sources"]}
        checked = payload(row["item"], source_map, registry)
        if checked["status"] != "technical_draft_only":
            raise ValueError("closed_CMS_contract_rejected")
        if row["item"]["content_class"] == "canonical" and any(
            "radmohajer.ir" in u for u in row["item"]["source_urls"]
        ):
            raise ValueError("mohajer_cannot_be_canonical")
    pages = json.loads(
        (prepared / "canonical-page-inventory.json").read_text(encoding="utf-8")
    )
    keys = [(tuple(p["country_codes"]), p["visa_category"], p["locale"]) for p in pages]
    if len(keys) != len(set(keys)):
        raise ValueError("multiple_canonical_pages_for_same_country_category_locale")
    reproduction = None
    if reproduce:
        # Recompile ALL additive drafts/revisions, mappings, source/exclusion/
        # duplicate ledgers and exact import/rollback SQL in a fresh directory.
        with tempfile.TemporaryDirectory(prefix="rad_phase_reproduction_") as folder:
            target = Path(folder)
            import shutil

            shutil.copytree(
                directory,
                target,
                dirs_exist_ok=True,
                ignore=shutil.ignore_patterns(
                    ".network-cache", "verification", "*.zip", "*.progress.jsonl"
                ),
            )
            tracked = {
                p.relative_to(directory).as_posix(): sha(p.read_bytes())
                for p in artifact_files(directory)
            }
            recompose(target)
            build(target)
            after = {
                p.relative_to(target).as_posix(): sha(p.read_bytes())
                for p in artifact_files(target)
            }
            different = sorted(
                k
                for k in tracked.keys() | after.keys()
                if tracked.get(k) != after.get(k)
            )
            if different:
                raise ValueError("nondeterministic_delivery:" + ",".join(different))
            reproduction = {
                "fresh_directory_files_equal": len(tracked),
                "different_files": 0,
            }
    return {
        "manifest_files_verified": len(actual),
        "source_records": len(master),
        "capture_versions": len(captures),
        "verified_raw_captures": raw_count,
        "exact_capture_blocks": block_count,
        "CMS_payloads_validated": len(rows),
        "canonical_locale_keys_unique": len(keys),
        "recovery_status": dict(Counter(r["recovery_status"] for r in master)),
        "reproduction": reproduction,
        "raw_to_rich_versions_reparsed": len(parsed_raw),
        "hosted_writes": 0,
        "publication_allowed": False,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--seal", action="store_true")
    parser.add_argument("--reproduce", action="store_true")
    args = parser.parse_args()
    if args.seal:
        seal(args.directory)
    print(json.dumps(verify(args.directory, args.reproduce)))
