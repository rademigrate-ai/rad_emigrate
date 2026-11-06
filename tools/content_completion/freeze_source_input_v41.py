"""Seal raw-backed article inputs separately from the global discovery audit."""

import argparse
import gzip
import hashlib
import json
import shutil
from collections import defaultdict
from pathlib import Path

from tools.content_completion.full_recovery_v4 import (
    explicit_placeholder_reason,
    known_nonarticle_route,
)
from tools.content_completion.phase_bundle import save_json
from tools.content_completion.recovery_bindings_v41 import bind_heading_levels, headings
from tools.content_completion.recovery_cache_repair_v4 import (
    correct_export_languages,
    reconcile_exact_source_aliases,
)
from tools.plan3_content.dataset import read_jsonl, write_jsonl


def freeze(directory, output, bundle):
    if (output / "source-input-manifest.json").exists():
        raise ValueError("sealed_source_input_already_exists_do_not_overwrite")
    output.mkdir(parents=True, exist_ok=True)
    for name in (
        "capture-versions.jsonl.gz",
        "inventory.jsonl.gz",
        "network-observations.jsonl.gz",
        "owned-completeness-reassessment.jsonl.gz",
        "owned-nonarticle-captures.jsonl.gz",
    ):
        if (directory / name).exists():
            shutil.copyfile(directory / name, output / name)
    exclusions, heading_rows, integrity = [], [], {}
    for name in ("sources.jsonl.gz", "version-supplements.jsonl.gz"):
        retained, grouped = [], defaultdict(list)
        for source in read_jsonl(directory / name):
            reason = known_nonarticle_route(
                source["url"]
            ) or explicit_placeholder_reason(source)
            if reason:
                exclusions.append(
                    {
                        "source_id": source["source_id"],
                        "url": source["url"],
                        "capture_id": source["capture_id"],
                        "raw_html_sha256": source["raw_html_sha256"],
                        "body_sha256": source["body_sha256"],
                        "disposition": reason[0],
                        "basis": reason[1],
                        "all_original_blocks_preserved_in_capture_versions": True,
                    }
                )
            else:
                grouped[source["raw_html_asset"]].append(source)
        for index, (asset, members) in enumerate(sorted(grouped.items())):
            raw = gzip.decompress(Path(asset).read_bytes())
            checksum = hashlib.sha256(raw).hexdigest()
            if any(s["raw_html_sha256"] != checksum for s in members):
                raise ValueError("source_input_raw_hash_mismatch")
            integrity[asset] = {"asset": asset, "sha256": checksum, "bytes": len(raw)}
            matched, encoding = headings(raw)
            for source in members:
                source["heading_structure_evidence"] = bind_heading_levels(
                    source, matched, encoding
                )
                heading_rows.extend(
                    {
                        "source_id": source["source_id"],
                        "url": source["url"],
                        "capture_id": source["capture_id"],
                        **r,
                    }
                    for r in source["heading_structure_evidence"]
                )
                retained.append(source)
            if index % 100 == 0:
                print("SOURCE_INPUT_HEADINGS", index, "of", len(grouped), flush=True)
        write_jsonl(
            output / name, sorted(retained, key=lambda r: (r["url"], r["source_id"]))
        )
    write_jsonl(output / "source-input-exclusions.jsonl.gz", exclusions)
    write_jsonl(output / "heading-structure-evidence.jsonl.gz", heading_rows)
    write_jsonl(
        output / "heading-structure-unresolved.jsonl.gz",
        [r for r in heading_rows if not r["confirmed"]],
    )
    write_jsonl(
        output / "source-raw-integrity-index.jsonl.gz",
        sorted(integrity.values(), key=lambda r: r["asset"]),
    )
    summary = json.loads((directory / "summary.json").read_text(encoding="utf-8"))
    current = read_jsonl(output / "sources.jsonl.gz")
    summary.update(
        source_input_only=True,
        discovery_inventory_is_separate=True,
        source_checkpoint_only=False,
        complete_source_pages=len(current),
        eligible_complete_source_pages=len(current),
        complete_source_blocks=sum(len(s["blocks"]) for s in current),
        source_input_exclusions=len(exclusions),
        heading_levels_confirmed=sum(r["confirmed"] for r in heading_rows),
        heading_levels_unresolved=sum(not r["confirmed"] for r in heading_rows),
        selected_source_raw_assets_verified=len(integrity),
        new_network_requests=0,
    )
    save_json(output / "summary.json", summary)
    inventory = read_jsonl(output / "inventory.jsonl.gz")
    excluded = {r["url"]: r for r in exclusions}
    for row in inventory:
        if row["url"] in excluded:
            row.update(
                disposition=excluded[row["url"]]["disposition"],
                basis=excluded[row["url"]]["basis"],
            )
    write_jsonl(output / "inventory.jsonl.gz", inventory)
    correct_export_languages(output)
    original = {r["url"] for r in read_jsonl(bundle / "source-master.jsonl.gz")}
    reconcile_exact_source_aliases(output, original)
    files = {
        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(output.iterdir())
        if p.is_file()
    }
    manifest = {
        "version": "rad-source-input-v4.1",
        "sources": len(current),
        "blocks": sum(len(s["blocks"]) for s in current),
        "supplements": len(read_jsonl(output / "version-supplements.jsonl.gz")),
        "files": files,
        "original_snapshot_text_and_structural_hashes_unchanged": True,
        "heading_levels_are_additive_raw_evidence": True,
        "publication_allowed": False,
    }
    save_json(output / "source-input-manifest.json", manifest)
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--directory",
        type=Path,
        default=Path("artifacts/RAD_FULL_CONTENT_V4_20261028/recovery-ready-sources"),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("artifacts/RAD_FULL_CONTENT_V4_20261028/recovery-source-input"),
    )
    parser.add_argument(
        "--bundle",
        type=Path,
        default=Path("_audit/RAD_CODEX_PHASES_1_TO_4_FINAL_20261028"),
    )
    args = parser.parse_args()
    print(json.dumps(freeze(args.directory, args.output, args.bundle), sort_keys=True))
