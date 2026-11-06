import gzip
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from tools.content_completion.v4_transport import build


class TransportBoundaries(unittest.TestCase):
    def fixture(self, root, sql="begin;\nselect 'متن فارسی';\ncommit;\n"):
        raw = sql.encode("utf-8")
        (root / "operation-0000.sql.gz").write_bytes(gzip.compress(raw))
        plan = {
            "project": "epolbumcfbohtmgvomki",
            "publication_allowed": False,
            "manifest_sha256": "a" * 64,
            "batch_id": "reviewed-fixture",
            "operations": [
                {
                    "file": "operation-0000.sql.gz",
                    "sha256": hashlib.sha256(raw).hexdigest(),
                }
            ],
        }
        (root / "import-plan.json").write_text(json.dumps(plan), encoding="utf-8")
        return plan

    def test_modified_reviewed_operation_never_reaches_compressor(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.fixture(root)
            (root / "operation-0000.sql.gz").write_bytes(
                gzip.compress(b"begin;select 2;commit;")
            )
            with patch(
                "tools.content_completion.v4_transport.subprocess.run"
            ) as compressor:
                with self.assertRaisesRegex(ValueError, "hash_changed"):
                    build(root, Path("gpg"))
                compressor.assert_not_called()

    def test_production_target_never_reaches_compressor(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            plan = self.fixture(root)
            plan["project"] = "inshddthftkhcdosoqcn"
            (root / "import-plan.json").write_text(json.dumps(plan), encoding="utf-8")
            with patch(
                "tools.content_completion.v4_transport.subprocess.run"
            ) as compressor:
                with self.assertRaisesRegex(ValueError, "staging_drafts_only"):
                    build(root, Path("gpg"))
                compressor.assert_not_called()

    def test_unbounded_batch_rejected(self):
        with self.assertRaisesRegex(ValueError, "batch_size"):
            build(Path("unused"), Path("gpg"), 100)

    def test_transport_binds_full_unicode_text_hash_before_execute(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.fixture(root)
            with patch(
                "tools.content_completion.v4_transport.subprocess.run",
                return_value=SimpleNamespace(stdout=b"PUBLIC COMPRESSED FIXTURE"),
            ) as compressor:
                manifest = build(root, Path("gpg"))
            self.assertEqual(manifest["operation_count"], 1)
            self.assertIn("متن فارسی", compressor.call_args.kwargs["input"].decode())
            transport = json.loads(
                (root / "transport/batch-0000.json").read_text("utf-8")
            )
            self.assertLess(
                transport["query"].index("v4_transport_hash_mismatch"),
                transport["query"].index("execute content"),
            )
            self.assertIn(transport["decompressed_sha256"], transport["query"])


if __name__ == "__main__":
    unittest.main()
