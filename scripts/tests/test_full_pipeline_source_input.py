"""Sealed V4.1 input must supersede the incomplete acquisition checkpoint."""

import contextlib
import hashlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.tests.test_content_consolidation import source
from tools.content_completion.full_pipeline_v4 import compose_all, main
from tools.plan3_content.dataset import read_jsonl, write_jsonl


class SealedInputTests(unittest.TestCase):
    def package(self, directory, identity):
        directory.mkdir(parents=True)
        row = source(identity, "تحصیل کانادا")
        write_jsonl(directory / "sources.jsonl.gz", [row])
        write_jsonl(directory / "version-supplements.jsonl.gz", [])
        manifest = {
            "version": "rad-source-input-v4.1",
            "files": {
                p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                for p in directory.glob("*.jsonl.gz")
            },
        }
        (directory / "source-input-manifest.json").write_text(json.dumps(manifest))
        return row

    def test_cli_prefers_sealed_input_over_stale_recovery(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sealed = self.package(root / "recovery-source-input", "sealed")
            self.package(root / "recovery", "stale")
            with patch("sys.argv", ["pipeline", "compose", "--root", str(root)]):
                with contextlib.redirect_stdout(io.StringIO()):
                    main()
            actual = read_jsonl(root / "composition/sources.jsonl.gz")
            self.assertEqual([r["source_id"] for r in actual], [sealed["source_id"]])
            manifest = json.loads((root / "composition/manifest.json").read_text())
            self.assertEqual(
                manifest["source_input_manifest_sha256"],
                hashlib.sha256(
                    (
                        root / "recovery-source-input/source-input-manifest.json"
                    ).read_bytes()
                ).hexdigest(),
            )

    def test_explicit_source_and_output_leave_inputs_untouched(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            directory = root / "sealed"
            self.package(directory, "selected")
            before = {p.name: p.read_bytes() for p in directory.iterdir()}
            with patch(
                "sys.argv",
                [
                    "pipeline",
                    "compose",
                    "--source-input",
                    str(directory),
                    "--output",
                    str(root / "receipts"),
                ],
            ):
                with contextlib.redirect_stdout(io.StringIO()):
                    main()
            self.assertEqual(len(read_jsonl(root / "receipts/articles.jsonl.gz")), 1)
            self.assertEqual(
                {p.name: p.read_bytes() for p in directory.iterdir()}, before
            )

    def test_changed_sealed_source_is_rejected_before_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.package(root / "sealed", "original")
            write_jsonl(
                root / "sealed/sources.jsonl.gz", [source("changed", "تحصیل کانادا")]
            )
            with self.assertRaisesRegex(ValueError, "sealed_source_checksum_mismatch"):
                compose_all(root / "sealed", root / "output")
            self.assertFalse((root / "output").exists())


if __name__ == "__main__":
    unittest.main()
