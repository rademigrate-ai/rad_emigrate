"""Independent scanner evidence must match the immutable image lock exactly."""

import json
import tempfile
import unittest
from pathlib import Path

from scripts.verify_trivy_image_gap import GAP, verify_missing_images


class TrivyGapTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.directory = Path(tmp.name)
        self.lock = {
            image: {"digest": image.split(":")[0] + "@sha256:" + f"{i:064x}"}
            for i, image in enumerate(GAP, start=1)
        }
        for image, name in GAP.items():
            self._write(
                name,
                {
                    "SchemaVersion": 2,
                    "ArtifactName": self.lock[image]["digest"],
                    "CreatedAt": "2026-11-05T23:50:19+03:30",
                    "Results": [
                        {
                            "Vulnerabilities": [
                                {
                                    "VulnerabilityID": "CVE-SYNTHETIC",
                                    "Severity": "HIGH",
                                    "PkgName": "test-lib",
                                    "InstalledVersion": "1",
                                    "FixedVersion": "2",
                                }
                            ]
                        }
                    ],
                },
            )

    def _write(self, file, contents):
        (self.directory / file).write_text(json.dumps(contents), encoding="utf8")

    def _read(self, file):
        return json.loads((self.directory / file).read_text(encoding="utf8"))

    def verify(self):
        return verify_missing_images(json.dumps(self.lock).encode(), self.directory)

    def test_accepted_reports_never_claim_reachability_or_safe_release(self):
        result = self.verify()
        self.assertIn("NO_GO", result["verdict"])
        self.assertEqual(len(result["images"]), 3)
        self.assertEqual(sum(x["high"] for x in result["images"]), 3)
        self.assertFalse(result["reachability_verified"])
        for entry in result["images"]:
            self.assertEqual(entry["advisories"][0]["reachability"], "NOT_ASSESSED")
            self.assertFalse(entry["advisories"][0]["compatible_image_fix_verified"])
            self.assertEqual(
                entry["advisories"][0]["security_acceptance"], "NOT_GRANTED"
            )

    def test_image_digest_mismatch_fails_closed(self):
        first = next(iter(GAP.values()))
        record = self._read(first)
        record["ArtifactName"] = "evil@sha256:" + "0" * 64
        self._write(first, record)
        with self.assertRaisesRegex(ValueError, "not for locked digest"):
            self.verify()

    def test_missing_or_incomplete_evidence_fails_closed(self):
        first = next(iter(GAP.values()))
        (self.directory / first).unlink()
        with self.assertRaisesRegex(ValueError, "missing independent scan"):
            self.verify()

    def test_unknown_severity_is_not_silently_filtered(self):
        first = next(iter(GAP.values()))
        record = self._read(first)
        record["Results"][0]["Vulnerabilities"][0]["Severity"] = "UNKNOWN"
        self._write(first, record)
        with self.assertRaisesRegex(ValueError, "unexpected vulnerability severity"):
            self.verify()

    def test_empty_scan_result_is_a_valid_zero_finding_report(self):
        first = next(iter(GAP.values()))
        record = self._read(first)
        record.pop("Results")
        self._write(first, record)
        summary = self.verify()
        self.assertEqual(
            next(x for x in summary["images"] if x["scan"] == first)["critical"], 0
        )

    def test_invalid_created_at_rejected(self):
        first = next(iter(GAP.values()))
        record = self._read(first)
        record["CreatedAt"] = "not-a-date"
        self._write(first, record)
        with self.assertRaisesRegex(ValueError, "valid scan timestamp"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
