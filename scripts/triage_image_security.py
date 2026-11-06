#!/usr/bin/env python3
"""Verify digest-bound Docker Scout SARIF evidence; never imply release clearance.

Usage: python scripts/triage_image_security.py --evidence-zip PATH
Print JSON only; no service changes, scanning exceptions or whitelist.
This is a triage of package matches, not a reachability/exploitability verdict.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def parse_triage(*, image_lock: bytes, review: bytes, evidence_zip: Path) -> dict:
    metadata = json.loads(review)
    lock = json.loads(image_lock)
    if metadata["image_lock_sha256"] != _sha256(image_lock):
        raise ValueError("security review belongs to another image lock")
    if len(lock) != 12 or len({v["digest"] for v in lock.values()}) != 12:
        raise ValueError("unexpected or duplicate image lock")
    summaries = []
    matched = 0
    unique_ids = set()
    with ZipFile(evidence_zip) as evidence:
        names = set(evidence.namelist())
        for entry in metadata["reports"]:
            name = entry["report"]
            if name not in names:
                raise ValueError("missing security evidence: " + name)
            raw = evidence.read(name)
            if _sha256(raw) != entry["sha256"]:
                raise ValueError("changed security evidence: " + name)
            runs = json.loads(raw)["runs"]
            rules = {
                rule["id"]: rule
                for run in runs
                for rule in run["tool"]["driver"].get("rules", [])
            }
            findings = [result for run in runs for result in run.get("results", [])]
            if len(findings) != entry["package_advisory_matches"]:
                raise ValueError("advisory count mismatch: " + name)
            severity = {"CRITICAL": 0, "HIGH": 0}
            fixed = {"CRITICAL": 0, "HIGH": 0}
            individual = []
            for finding in findings:
                key = finding["ruleId"]
                rule = rules.get(key)
                if rule is None:
                    raise ValueError("finding without matching rule: " + key)
                props = rule.get("properties", {})
                rank = props.get("cvssV3_severity")
                if rank not in severity:
                    raise ValueError("unexpected severity: " + str(rank))
                severity[rank] += 1
                version = props.get("fixed_version", "not fixed")
                if version and version != "not fixed":
                    fixed[rank] += 1
                unique_ids.add(key)
                individual.append(
                    {
                        "advisory_id": key,
                        "severity": rank,
                        "affected_package_urls": props.get("purls", []),
                        "affected_version_range": props.get("affected_version"),
                        "upstream_fixed_version_hint": version,
                        "reachability": "NOT_ASSESSED",
                        "compatible_image_fix_verified": False,
                        "security_acceptance": "NOT_GRANTED",
                    }
                )
            if severity != entry["severity"]:
                raise ValueError("severity mismatch: " + name)
            matched += len(findings)
            summaries.append(
                {
                    "report": name,
                    "severity": severity,
                    "fix_version_advertised": fixed,
                    "advisory_matches": len(findings),
                    "status": entry["status"],
                    "reachability": "NOT_ASSESSED",
                    "advisories": sorted(
                        individual,
                        key=lambda item: (
                            item["severity"] != "CRITICAL",
                            item["advisory_id"],
                            str(item["affected_package_urls"]),
                        ),
                    ),
                }
            )
    if (
        matched != metadata["total_package_advisory_matches"]
        or len(unique_ids) != metadata["unique_advisories_across_reports"]
    ):
        raise ValueError("aggregate advisory evidence differs from review")
    missing = metadata["missing_reports"]
    if not isinstance(missing, list):
        raise ValueError("missing reports must be an explicit list")
    return {
        "verdict": "NO_GO_INCOMPLETE_SCAN_AND_REACHABILITY_REVIEW",
        "image_lock_sha256": _sha256(image_lock),
        "evidence_zip_sha256": _sha256(evidence_zip.read_bytes()),
        "total_package_advisory_matches": matched,
        "unique_advisories": len(unique_ids),
        "missing_image_scans": missing,
        "reports": summaries,
        "note": (
            "A fixed-version hint is not proof of a compatible patched image. "
            "Reachability and upgrades need independently verified evidence."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence-zip", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = parse_triage(
        image_lock=(ROOT / "deploy/self-hosted/images.lock.json").read_bytes(),
        review=(ROOT / "deploy/self-hosted/image-security-review.json").read_bytes(),
        evidence_zip=args.evidence_zip,
    )
    text = json.dumps(result, sort_keys=True, indent=2) + "\n"
    if args.output:
        if args.output.exists():
            raise FileExistsError("refusing to overwrite a previous audit receipt")
        args.output.write_text(text, encoding="utf8")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
