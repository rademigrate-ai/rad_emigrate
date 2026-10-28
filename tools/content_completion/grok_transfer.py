"""Verify the newly delivered ORIGINAL Grok bytes and add provenance, not imports."""

import argparse
import json
import zipfile
from collections import Counter
from itertools import zip_longest
from pathlib import Path

from tools.content_completion.phase_bundle import (
    BASE,
    CORPUS,
    Bundle,
    confined,
    recompose,
    save_json,
    sha,
)
from tools.content_completion.source_evidence import parse_mohajer
from tools.plan3_content.dataset import read_jsonl, write_jsonl

EXPECTED_ZIP_SHA = "8d4ae958a231596e7a844cf669a5ab23acd6fc3d51fe4606001a4082ae0ca1f2"
PREFIX = "RAD_CONTENT_GAP_RECOVERY_20261027/"


def asset(directory, relative, data):
    name = Path("assets/grok") / (sha(data)[:20] + Path(relative).suffix)
    path = directory / name
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_bytes() != data:
        raise ValueError("original_asset_short_hash_collision")
    path.write_bytes(data)
    return name.as_posix()


def ingest(directory, originals, archive, handoff, evidence_time):
    if sha(archive.read_bytes()) != EXPECTED_ZIP_SHA:
        raise ValueError("original_transfer_ZIP_hash_mismatch")
    with zipfile.ZipFile(archive) as zipped:
        manifest_raw = zipped.read(PREFIX + "__GROK_TRANSFER_SHA256.json")
        manifest = json.loads(manifest_raw)
        files = manifest["files"]
        if (
            manifest["schema"] != "rad-grok-transfer-sha256-v1"
            or len(files) != 355
            or manifest["source_file_count"] != 355
        ):
            raise ValueError("original_transfer_manifest_count_or_schema")
        if len(zipped.namelist()) != len(set(zipped.namelist())):
            raise ValueError("duplicate_original_ZIP_member")
        if set(zipped.namelist()) != {PREFIX + row["path"] for row in files} | {
            PREFIX + "__GROK_TRANSFER_SHA256.json"
        }:
            raise ValueError("original_ZIP_file_set_mismatch")
        if {
            p.relative_to(originals).as_posix()
            for p in originals.rglob("*")
            if p.is_file()
        } != {row["path"] for row in files}:
            raise ValueError("installed_original_file_set_mismatch")
        index = []
        for record in sorted(files, key=lambda r: r["path"]):
            raw = confined(originals, record["path"]).read_bytes()
            if (
                sha(raw) != record["sha256"]
                or len(raw) != record["size"]
                or raw != zipped.read(PREFIX + record["path"])
            ):
                raise ValueError(
                    "original_installed_ZIP_SHA_mismatch:" + record["path"]
                )
            index.append({**record, "asset": asset(directory, record["path"], raw)})
    save_json(directory / "grok-original-file-index.json", index)
    (directory / "grok-original-transfer-manifest.json").write_bytes(manifest_raw)
    (
        directory
        / "reference-evidence/GROK_355_TRANSFER_AND_CROSS_AGENT_HANDOFF_20261028.md"
    ).write_bytes(handoff.read_bytes())
    bundle = Bundle(
        directory, read_jsonl(CORPUS / "sources.jsonl.gz"), "2026-10-28T09:30:43Z"
    )
    bundle.master = {
        r["url"]: r for r in read_jsonl(directory / "source-master.jsonl.gz")
    }
    bundle.captures = {
        c["capture_id"]: c for c in read_jsonl(directory / "source-captures.jsonl.gz")
    }
    # Evidence arrived later than the initial intake. Record its actual operation
    # time in the transfer receipt, not as the unknown original HTTP fetch time.
    primary = json.loads(
        (originals / "04_digivisa_radvisa_146_manifest.json").read_text(
            encoding="utf-8"
        )
    )
    source_intake = {
        s["source_id"]: s for s in read_jsonl(BASE / "prepared/source-intake.jsonl.gz")
    }
    primary_proof = []
    for record in primary:
        raw = confined(originals, record["recovered_text_file"]).read_bytes()
        body = raw.decode("utf-8")
        source = source_intake[record["source_id"]]
        if (
            sha(raw) != record["recovered_text_sha256"]
            or body != source["body_text"]
            or len(body) != record["body_len"]
            or source["body_sha256"] != record["body_sha256"]
        ):
            raise ValueError("original_primary_export_not_exact_existing_intake")
        primary_proof.append(
            {
                "source_id": source["source_id"],
                "snapshot_id": source["snapshot_id"],
                "body_sha256": source["body_sha256"],
                "original_export_asset": next(
                    r["asset"]
                    for r in index
                    if r["path"] == record["recovered_text_file"]
                ),
                "disposition": "exact_physical_export_of_existing_intake_no_import",
            }
        )
    mohajer = json.loads(
        (originals / "03_mohajer_100_recovery_manifest.json").read_text(
            encoding="utf-8"
        )
    )
    frontier = {
        r["source_id"]
        for r in json.loads(
            (BASE / "inaccessible-source-list.json").read_text(encoding="utf-8")
        )
        if r["old_disposition"] == "body_ready_for_unreviewed_composition"
    }
    if (
        len(mohajer) != 100
        or {r["source_id"] for r in mohajer} != frontier
        or len(primary) != 146
    ):
        raise ValueError("original_Grok_source_identity_sets_mismatch")
    raw_files = list((originals / "recovered_bodies_radmohajer").glob("*.html"))
    parsed_proof, pair_diffs = [], []
    verification = json.loads(
        (
            directory
            / "reference-evidence/RAD_CROSS_AGENT_HASH_QA_20261028/LOCAL_REFETCH_PARTIAL_VERIFICATION.json"
        ).read_text(encoding="utf-8-sig")
    )
    refetch = {r["source_id"]: r for r in verification["verified_files"]}
    for record in mohajer:
        text_raw = confined(originals, record["recovered_text_file"]).read_bytes()
        text_body = text_raw.decode("utf-8")
        if (
            sha(text_raw) != record["recovered_text_sha256"]
            or len(text_body) != record["text_len"]
        ):
            raise ValueError("original_Mohajer_TXT_hash_or_length_mismatch")
        matching = [
            p
            for p in raw_files
            if p.name.startswith("mohajer_" + record["source_id"][:13] + "_")
        ]
        if len(matching) != 1:
            raise ValueError("original_Mohajer_raw_identity_ambiguous")
        raw = matching[0].read_bytes()
        parsed = parse_mohajer(raw, record["url"])
        row = bundle.source(record["url"])
        if row["source_id"] != record["source_id"]:
            raise ValueError("original_Mohajer_source_id_URL_conflict")
        prior_hashes = {
            bundle.captures[c]["body_sha256"]
            for c in row["capture_ids"]
            if bundle.captures[c]["acquisition_method"]
            != "grok_original_transfer_verified"
        }
        capture_ids = []
        for article in parsed["articles"]:
            capture = bundle.capture(
                {
                    "url": record["url"],
                    "language": "fa",
                    "http_status": record["http_status"],
                },
                article,
                "grok_original_transfer_verified",
                raw,
                original_manifest=record,
                original_txt_asset=next(
                    r["asset"]
                    for r in index
                    if r["path"] == record["recovered_text_file"]
                ),
                original_txt_sha256=sha(text_raw),
                txt_is_whole_page_not_article_only=True,
                verified_transfer_evidence_time=evidence_time,
                reported_status_source="original_Grok_manifest_not_new_HTTP_request",
            )
            capture["evidence_intake_timestamp"] = evidence_time
            capture_ids.append(capture["capture_id"])
        parsed_proof.append(
            {
                "source_id": record["source_id"],
                "url": record["url"],
                "capture_ids": capture_ids,
                "whole_page_TXT_sha256": sha(text_raw),
                "raw_sha256": sha(raw),
                "owned_article_completeness": [
                    a["completeness"] for a in parsed["articles"]
                ],
                "owned_body_matches_preserved_version": bool(capture_ids)
                and all(
                    c["body_sha256"] in prior_hashes
                    and c["completeness"] == "complete_owned_article_container"
                    for c in [bundle.captures[i] for i in capture_ids]
                ),
                "original_Grok_transfer_proven": True,
            }
        )
        if record["source_id"] in refetch:
            comparison = refetch[record["source_id"]]
            refetch_asset = next(
                c["evidence"]["original_txt_asset"]
                for c in bundle.captures.values()
                if c["source_id"] == record["source_id"]
                and c["acquisition_method"]
                == "new_windows_live_refetch_not_grok_original"
            )
            later_raw = (directory / refetch_asset).read_bytes()
            later = (
                later_raw.decode("utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
            )
            original = text_body.replace("\r\n", "\n").replace("\r", "\n")
            counts = Counter()
            for old, new in zip_longest(
                original.splitlines(), later.splitlines(), fillvalue=""
            ):
                if old == new:
                    continue
                numeric = all(not v.strip() or v.strip().isdigit() for v in (old, new))
                counter = all("بازدید" in v for v in (old, new))
                counts[
                    "numeric_only"
                    if numeric
                    else "visitor_counter"
                    if counter
                    else "other_textual_difference_requires_review"
                ] += 1
            pair_diffs.append(
                {
                    "source_id": record["source_id"],
                    "original_txt_sha256": sha(text_raw),
                    "refetch_raw_sha256": comparison["text_on_disk_sha256"],
                    "raw_bytes_equal": text_raw == later_raw,
                    "normalized_character_counts": [len(original), len(later)],
                    "different_line_pairs": sum(counts.values()),
                    "line_difference_classes": dict(counts),
                    "editorial_equivalence_not_automatically_inferred": True,
                }
            )
    write_jsonl(directory / "source-captures.jsonl.gz", list(bundle.captures.values()))
    write_jsonl(
        directory / "source-master.jsonl.gz",
        sorted(bundle.master.values(), key=lambda r: r["url"]),
    )
    summary_path = directory / "source-integrity-summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    summary.update(
        original_grok_package_transferred=True,
        original_grok_files_verified=355,
        original_grok_mohajer_captures=len(mohajer),
        original_grok_primary_exact_existing_exports=len(primary_proof),
        capture_versions=len(bundle.captures),
    )
    save_json(summary_path, summary)
    save_json(
        directory / "grok-original-source-reconciliation.json",
        {
            "zip_sha256": EXPECTED_ZIP_SHA,
            "files_verified": len(index),
            "bytes_verified": sum(r["size"] for r in index),
            "evidence_verified_at": evidence_time,
            "source_HTTP_capture_time_inferred": False,
            "primary_146": primary_proof,
            "mohajer_100": parsed_proof,
            "refetch_33_differences": pair_diffs,
            "new_import_operations_for_transfer": 0,
            "hosted_writes": 0,
        },
    )
    recompose(directory)
    return {
        "files_verified": 355,
        "primary_exact_intake": len(primary_proof),
        "mohajer_bodies_matching_preserved_versions": sum(
            r["owned_body_matches_preserved_version"] for r in parsed_proof
        ),
        "refetch_line_differences": sum(r["different_line_pairs"] for r in pair_diffs),
        "other_textual_difference_lines": sum(
            r["line_difference_classes"].get(
                "other_textual_difference_requires_review", 0
            )
            for r in pair_diffs
        ),
        "new_import_operations": 0,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--originals", type=Path, required=True)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--handoff", type=Path, required=True)
    parser.add_argument(
        "--evidence-verified-at",
        required=True,
        help="Actual UTC time of original transfer verification; pin for reproduction, never original HTTP acquisition time",
    )
    args = parser.parse_args()
    print(
        json.dumps(
            ingest(
                args.directory,
                args.originals,
                args.archive,
                args.handoff,
                args.evidence_verified_at,
            )
        )
    )
