"""No-go evidence triage must reject stale or incomplete image scan records."""

import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile

from scripts.triage_image_security import parse_triage


class ImageSecurityTriageTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.archive = Path(self.tmp.name) / "sample.zip"
        self.lock = json.dumps(
            {
                f"example/image-{index}:v1": {
                    "digest": f"example/image-{index}@sha256:{index:064x}"
                }
                for index in range(12)
            }
        ).encode()
        self.sarif = json.dumps(
            {
                "runs": [
                    {
                        "tool": {
                            "driver": {
                                "rules": [
                                    {
                                        "id": "CVE-SYNTHETIC",
                                        "properties": {
                                            "cvssV3_severity": "CRITICAL",
                                            "fixed_version": "2.0",
                                        },
                                    }
                                ]
                            }
                        },
                        "results": [{"ruleId": "CVE-SYNTHETIC"}],
                    }
                ]
            }
        ).encode()
        with ZipFile(self.archive, "w") as zipped:
            zipped.writestr("scan.sarif.json", self.sarif)
        self.review = {
            "image_lock_sha256": hashlib.sha256(self.lock).hexdigest(),
            "reports": [
                {
                    "report": "scan.sarif.json",
                    "sha256": hashlib.sha256(self.sarif).hexdigest(),
                    "package_advisory_matches": 1,
                    "severity": {"HIGH": 0, "CRITICAL": 1},
                    "status": "REPORT_AVAILABLE",
                }
            ],
            "total_package_advisory_matches": 1,
            "unique_advisories_across_reports": 1,
            "missing_reports": ["not-scanned"],
        }

    def triage(self):
        return parse_triage(
            image_lock=self.lock,
            review=json.dumps(self.review).encode(),
            evidence_zip=self.archive,
        )

    def test_real_evidence_is_counted_without_relabeling_no_go(self):
        result = self.triage()
        self.assertIn("NO_GO", result["verdict"])
        self.assertEqual(result["total_package_advisory_matches"], 1)
        self.assertEqual(result["reports"][0]["fix_version_advertised"]["CRITICAL"], 1)
        self.assertEqual(result["missing_image_scans"], ["not-scanned"])
        self.assertEqual(result["reports"][0]["reachability"], "NOT_ASSESSED")

    def test_changed_lock_is_rejected(self):
        self.review["image_lock_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "another image lock"):
            self.triage()

    def test_tampered_scan_bytes_are_rejected(self):
        self.review["reports"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "changed security evidence"):
            self.triage()

    def test_missing_scan_is_rejected(self):
        self.review["reports"][0]["report"] = "absent.sarif.json"
        with self.assertRaisesRegex(ValueError, "missing security evidence"):
            self.triage()

    def test_mismatched_total_is_rejected(self):
        self.review["total_package_advisory_matches"] = 2
        with self.assertRaisesRegex(ValueError, "aggregate advisory evidence"):
            self.triage()


if __name__ == "__main__":
    unittest.main()
