"""Bind the final inventory and portable raw dependencies to the sealed inputs."""

import argparse
import gzip
import hashlib
import json
import shutil
from collections import Counter
from pathlib import Path

from tools.content_completion.phase_bundle import save_json
from tools.content_completion.recovery_cache_repair_v4 import (
    reconcile_exact_source_aliases,
)
from tools.plan3_content.dataset import read_jsonl, write_jsonl


def synchronize(source_input, inventory_directory, bundle, output):
    seal_path = source_input / "source-input-manifest.json"
    seal_hash = hashlib.sha256(seal_path.read_bytes()).hexdigest()
    seal = json.loads(seal_path.read_text(encoding="utf-8"))
    for name, checksum in seal["files"].items():
        if hashlib.sha256((source_input / name).read_bytes()).hexdigest() != checksum:
            raise ValueError("sealed_source_file_changed:" + name)
    for name in (
        "sources.jsonl.gz",
        "version-supplements.jsonl.gz",
        "language-corrections.jsonl.gz",
        "heading-structure-evidence.jsonl.gz",
        "heading-structure-unresolved.jsonl.gz",
        "source-input-exclusions.jsonl.gz",
    ):
        shutil.copyfile(source_input / name, inventory_directory / name)
    exclusions = {
        r["url"]: r
        for r in read_jsonl(source_input / "source-input-exclusions.jsonl.gz")
    }
    rows = read_jsonl(inventory_directory / "inventory.jsonl.gz")
    for row in rows:
        if row["url"] in exclusions:
            row.update(
                disposition=exclusions[row["url"]]["disposition"],
                basis=exclusions[row["url"]]["basis"],
            )
            row.pop("exact_alias_evidence", None)
            row.pop("represented_source_url", None)
            row.pop("represented_source_id", None)
    write_jsonl(inventory_directory / "inventory.jsonl.gz", rows)
    original_urls = {r["url"] for r in read_jsonl(bundle / "source-master.jsonl.gz")}
    reconcile_exact_source_aliases(inventory_directory, original_urls)
    summary_path = inventory_directory / "summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    source_summary = json.loads(
        (source_input / "summary.json").read_text(encoding="utf-8")
    )
    for field in (
        "complete_source_pages",
        "eligible_complete_source_pages",
        "complete_source_blocks",
        "full_owned_body_count",
        "original_capture_languages",
        "source_languages",
        "source_language_metadata_corrections",
        "selected_source_raw_assets_verified",
        "heading_levels_confirmed",
        "heading_levels_unresolved",
        "source_input_exclusions",
    ):
        if field in source_summary:
            summary[field] = source_summary[field]
    summary["authoritative_source_input"] = source_input.as_posix()
    summary["authoritative_source_manifest_sha256"] = seal_hash
    sources = read_jsonl(source_input / "sources.jsonl.gz")
    alias_ids = {
        r["source_id"]
        for r in read_jsonl(inventory_directory / "exact-source-aliases.jsonl.gz")
    }
    summary["unique_source_group_languages"] = dict(
        sorted(
            Counter(
                s["language"] for s in sources if s["source_id"] not in alias_ids
            ).items()
        )
    )
    save_json(summary_path, summary)
    raw_index = read_jsonl(inventory_directory / "raw-integrity-index.jsonl.gz")
    dependencies, errors = [], []
    root = Path.cwd().resolve()
    for entry in raw_index:
        relative = Path(entry["asset"])
        path = relative.resolve()
        if relative.is_absolute() or not path.is_relative_to(root):
            raise ValueError("nonportable_raw_asset_reference")
        compressed = path.read_bytes()
        if hashlib.sha256(gzip.decompress(compressed)).hexdigest() != entry["sha256"]:
            raise ValueError("delivery_raw_checksum_mismatch")
        dependencies.append(
            {
                "path": relative.as_posix(),
                "compressed_sha256": hashlib.sha256(compressed).hexdigest(),
                "raw_html_sha256": entry["sha256"],
                "compressed_bytes": len(compressed),
            }
        )
        if "recovery/network/" in relative.as_posix():
            metadata = path.with_suffix(".json")
            if not metadata.exists():
                errors.append(
                    {"path": relative.as_posix(), "error": "missing_HTTP_metadata"}
                )
            else:
                dependencies.append(
                    {
                        "path": metadata.relative_to(root).as_posix(),
                        "sha256": hashlib.sha256(metadata.read_bytes()).hexdigest(),
                        "role": "HTTP_response_metadata",
                    }
                )
    if hashlib.sha256(seal_path.read_bytes()).hexdigest() != seal_hash:
        raise ValueError("source_manifest_changed_during_delivery_index")
    output.mkdir(parents=True, exist_ok=True)
    write_jsonl(
        output / "portable-dependencies.jsonl.gz",
        sorted(dependencies, key=lambda r: r["path"]),
    )
    result = {
        "version": "rad-recovery-delivery-v4.1",
        "source_input": source_input.as_posix(),
        "source_manifest_sha256": seal_hash,
        "source_input_modified": False,
        "raw_assets_verified": len(raw_index),
        "portable_dependencies": len(dependencies),
        "metadata_errors": errors,
        "authoritative_source_package": source_input.as_posix(),
        "final_inventory_package": inventory_directory.as_posix(),
        "required_raw_patterns": [
            "artifacts/RAD_FULL_CONTENT_V4_20261028/recovery/network/*.html.gz",
            "artifacts/RAD_FULL_CONTENT_V4_20261028/recovery/network/*.html.json",
            "_audit/RAD_CODEX_PHASES_1_TO_4_FINAL_20261028/assets/raw/*.html.gz",
        ],
        "intermediate_recovery_bodies_are_not_dependencies": True,
        "new_network_requests": 0,
    }
    save_json(output / "manifest.json", result)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-input",
        type=Path,
        default=Path("artifacts/RAD_FULL_CONTENT_V4_20261028/recovery-source-input"),
    )
    parser.add_argument(
        "--inventory",
        type=Path,
        default=Path("artifacts/RAD_FULL_CONTENT_V4_20261028/recovery-ready-sources"),
    )
    parser.add_argument(
        "--bundle",
        type=Path,
        default=Path("_audit/RAD_CODEX_PHASES_1_TO_4_FINAL_20261028"),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("artifacts/RAD_FULL_CONTENT_V4_20261028/recovery-delivery-v41"),
    )
    args = parser.parse_args()
    print(
        json.dumps(
            synchronize(args.source_input, args.inventory, args.bundle, args.output),
            sort_keys=True,
        )
    )
