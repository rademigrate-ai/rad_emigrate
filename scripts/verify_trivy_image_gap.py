#!/usr/bin/env python3
"""Verify independent local Trivy scans for three images absent from Scout SARIF.

This is digest-bound evidence, NOT a claim that vulnerable packages are safe.
No scans are skipped or waived; a missing/stale artifact refuses a receipt.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

GAP = {
    "darthsim/imgproxy:v3.31.4": "imgproxy_trivy.json",
    "supabase/realtime:v2.143.3": "realtime_trivy.json",
    "supabase/storage-api:v1.81.0": "storage-api_trivy.json",
}


def verify_missing_images(lock_bytes: bytes, reports_dir: Path) -> dict:
    lock = json.loads(lock_bytes)
    details = []
    for image, name in GAP.items():
        reference = lock.get(image, {}).get("digest")
        if not isinstance(reference, str) or "@sha256:" not in reference:
            raise ValueError("missing approved immutable digest: " + image)
        path = reports_dir / name
        if not path.is_file() or path.is_symlink():
            raise ValueError("missing independent scan: " + name)
        raw = path.read_bytes()
        record = json.loads(raw)
        if record.get("SchemaVersion") != 2:
            raise ValueError("unexpected Trivy schema: " + name)
        if record.get("ArtifactName") != reference:
            raise ValueError("Trivy scan is not for locked digest: " + name)
        try:
            created = datetime.fromisoformat(record["CreatedAt"].replace("Z", "+00:00"))
        except (KeyError, ValueError, TypeError) as exc:
            raise ValueError("missing valid scan timestamp: " + name) from exc
        if created.tzinfo is None:
            raise ValueError("timestamp missing time zone: " + name)
        sections = record.get("Results")
        if not isinstance(sections, list):
            raise ValueError("Trivy scan results must be a list: " + name)
        counts = {"CRITICAL": 0, "HIGH": 0}
        fix_hints = {"CRITICAL": 0, "HIGH": 0}
        vulnerabilities = []
        for section in sections:
            for vuln in section.get("Vulnerabilities") or []:
                severity = vuln.get("Severity")
                if severity not in counts:
                    raise ValueError("unexpected vulnerability severity: " + name)
                if not vuln.get("VulnerabilityID") or not vuln.get("PkgName"):
                    raise ValueError("incomplete vulnerability evidence: " + name)
                counts[severity] += 1
                if vuln.get("FixedVersion"):
                    fix_hints[severity] += 1
                vulnerabilities.append(
                    {
                        "id": vuln["VulnerabilityID"],
                        "severity": severity,
                        "package": vuln["PkgName"],
                        "installed_version": vuln.get("InstalledVersion"),
                        "fixed_version_hint": vuln.get("FixedVersion"),
                        "reachability": "NOT_ASSESSED",
                        "compatible_image_fix_verified": False,
                        "security_acceptance": "NOT_GRANTED",
                    }
                )
        details.append(
            {
                "image": image,
                "locked_digest": reference,
                "scan": name,
                "scan_sha256": hashlib.sha256(raw).hexdigest(),
                "scanner": "Trivy 0.76.1",
                "timestamp": record["CreatedAt"],
                "high": counts["HIGH"],
                "critical": counts["CRITICAL"],
                "fix_version_hints": fix_hints,
                "advisories": vulnerabilities,
                "state": "SCANNED_NO_SECURITY_ACCEPTANCE",
            }
        )
    return {
        "verdict": "NO_GO_UNREMEDIATED_FINDINGS",
        "image_lock_sha256": hashlib.sha256(lock_bytes).hexdigest(),
        "scanner_coverage_gap_closed": sorted(GAP),
        "original_docker_scout_reports_remain_missing": True,
        "reachability_verified": False,
        "images": details,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reports-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = verify_missing_images(
        (ROOT / "deploy/self-hosted/images.lock.json").read_bytes(),
        args.reports_dir,
    )
    out = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        if args.output.exists():
            raise FileExistsError("do not overwrite an existing security receipt")
        args.output.write_text(out, encoding="utf8")
    else:
        sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
