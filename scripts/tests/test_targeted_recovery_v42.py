import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from scripts.research_egress import EgressError
from tools.content_completion.targeted_recovery_v42 import recover
from tools.plan3_content.crawl import stable_id


class TargetedRecoveryTests(unittest.TestCase):
    def test_recovered_flag_without_verified_original_capture_fails_closed(self):
        def fetch(_url):
            self.fail("unproved reuse must fail before any network access")

        with (
            tempfile.TemporaryDirectory() as temp,
            self.assertRaisesRegex(
                ValueError, "verified_local_capture_receipt_required"
            ),
        ):
            recover(
                [
                    {
                        "source_id": "original",
                        "url": "https://radvisa.com/guide",
                        "disposition": "RECOVERED_FULL_BODY",
                    }
                ],
                [],
                Path(temp),
                fetch=fetch,
            )

    def test_producer_manifest_binds_dispositions_and_original_scope(self):
        from tools.content_completion.targeted_recovery_v42 import (
            verified_disposition_input,
        )

        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            path = directory / "url-dispositions.jsonl.gz"
            path.write_bytes(b"original producer evidence")
            manifest = {
                "files": {path.name: hashlib.sha256(path.read_bytes()).hexdigest()},
                "source_input_manifest_sha256": "source-seal",
                "unresolved_ledger_sha256": "ledger-seal",
            }
            (directory / "manifest.json").write_text(json.dumps(manifest))
            verified_disposition_input(path, "source-seal", "ledger-seal")
            path.write_bytes(b"substituted disposition flags")
            with self.assertRaisesRegex(
                ValueError, "disposition_producer_file_hash_mismatch"
            ):
                verified_disposition_input(path, "source-seal", "ledger-seal")

    def test_local_intake_is_explicit_reused_and_never_an_invented_http_date(self):
        from tools.content_completion.targeted_recovery_v42 import (
            record_evidence_intake,
        )

        original = [{"source_id": "s", "body_text": "Original", "retrieved_at": None}]
        with tempfile.TemporaryDirectory() as temp:
            first = record_evidence_intake(original, Path(temp), "a" * 64)
            second = record_evidence_intake(original, Path(temp), "a" * 64)
            self.assertEqual(first, second)
            self.assertIsNone(original[0]["retrieved_at"])
            self.assertIsNone(first[0]["acquisition_timestamp"])
            self.assertEqual(first[0]["body_text"], "Original")
            self.assertEqual(
                first[0]["retrieved_at"], first[0]["evidence_intake_timestamp"]
            )
            self.assertEqual(
                first[0]["retrieved_at_semantics"],
                "recorded_local_evidence_intake_not_original_HTTP_fetch",
            )
            with self.assertRaisesRegex(
                ValueError, "delta_evidence_intake_input_changed"
            ):
                record_evidence_intake(original, Path(temp), "b" * 64)

    def test_exact_421_scope_rejects_duplicate_or_substituted_original_url(self):
        from tools.content_completion.targeted_recovery_v42 import validate_exact_scope

        ledger = [
            {
                "url": f"https://radvisa.com/article/{n}",
                "source_id": stable_id(f"https://radvisa.com/article/{n}"),
                "disposition": "SOURCE_UNRESOLVED",
            }
            for n in range(421)
        ]
        rows = [{**row, "disposition": "SOURCE_UNAVAILABLE"} for row in ledger]
        validate_exact_scope(rows, ledger)
        with self.assertRaisesRegex(
            ValueError, "exact_421_original_url_scope_required"
        ):
            validate_exact_scope([rows[0], *rows[1:-1], rows[0]], ledger)
        wrong = [{**row} for row in rows]
        wrong[-1]["url"] = "https://radvisa.com/article/substituted"
        wrong[-1]["source_id"] = stable_id(wrong[-1]["url"])
        with self.assertRaisesRegex(
            ValueError, "exact_421_original_url_scope_required"
        ):
            validate_exact_scope(wrong, ledger)

    def test_robots_failure_circuits_host_and_does_not_invent_unrecoverable(self):
        calls = []

        def fetch(url):
            calls.append(url)
            raise EgressError("robots_unavailable")

        rows = [
            {
                "url": f"https://radvisa.com/article/{n}",
                "disposition": "SOURCE_UNAVAILABLE",
            }
            for n in range(5)
        ]
        with tempfile.TemporaryDirectory() as temp:
            result = recover(rows, [], Path(temp), fetch=fetch)
        self.assertEqual(len(calls), 1)
        self.assertEqual(result[0]["network"]["safe_error"], "robots_unavailable")
        self.assertEqual(result[-1]["network"]["status"], "HOST_CIRCUIT_OPEN")
        self.assertTrue(all(r["disposition"] == "SOURCE_UNAVAILABLE" for r in result))

    def test_cross_publisher_or_http_redirect_is_not_followed(self):
        for location in ["https://example.org/secret", "http://radvisa.com/guide"]:
            calls = []

            def fetch(url, calls=calls, location=location):
                calls.append(url)
                return 302, {"location": location}, b""

            with tempfile.TemporaryDirectory() as temp:
                result = recover(
                    [
                        {
                            "url": "https://radvisa.com/guide",
                            "disposition": "SOURCE_UNAVAILABLE",
                        }
                    ],
                    [],
                    Path(temp),
                    fetch=fetch,
                )
            self.assertEqual(len(calls), 1)
            self.assertEqual(
                result[0]["network"]["safe_error"], "unsafe_source_redirect"
            )

    def test_complete_heading_only_capture_is_preserved_as_unverified_candidate(self):
        raw = b'<h1>Guide</h1><div itemprop="articleBody"><h2>Required documents</h2><h2>Original authored explanation.</h2></div>'

        def fetch(_url):
            return 200, {"content-type": "text/html; charset=utf-8"}, raw

        with tempfile.TemporaryDirectory() as temp:
            result = recover(
                [
                    {
                        "url": "https://radvisa.com/guide",
                        "disposition": "SOURCE_UNAVAILABLE",
                    }
                ],
                [],
                Path(temp),
                fetch=fetch,
            )
            self.assertEqual(result[0]["disposition"], "RECOVERED_FULL_BODY")
            self.assertFalse(result[0]["candidate"]["publication_allowed"])
            self.assertTrue(Path(result[0]["candidate"]["raw_html_asset"]).is_file())

    def test_already_recovered_original_is_not_unnecessarily_refetched(self):
        def fetch(_url):
            self.fail("already recovered evidence must be reused")

        with tempfile.TemporaryDirectory() as temp:
            result = recover(
                [
                    {
                        "source_id": "original",
                        "url": "https://radvisa.com/guide",
                        "disposition": "RECOVERED_FULL_BODY",
                    }
                ],
                [],
                Path(temp),
                fetch=fetch,
                verified_local_capture_keys={("original", "https://radvisa.com/guide")},
            )
        self.assertEqual(
            result[0]["network"]["status"], "REUSED_VERIFIED_LOCAL_CAPTURE"
        )


if __name__ == "__main__":
    unittest.main()
