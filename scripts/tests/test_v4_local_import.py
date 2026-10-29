import gzip
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from tools.content_completion.v4_local_import import apply_plan, connection


class LocalImportBoundaryTests(unittest.TestCase):
    def test_different_runtime_is_rejected_before_any_database_call(self):
        with self.assertRaisesRegex(ValueError, "owned_v4_runtime_path_required"):
            connection(Path("not_the_owned_fixture"))

    def fixture(self, root):
        raw = b"begin;\nselect 1;\ncommit;\n"
        (root / "operation.sql.gz").write_bytes(gzip.compress(raw))
        plan = {
            "project": "epolbumcfbohtmgvomki",
            "publication_allowed": False,
            "blocked": [],
            "operations": [
                {"file": "operation.sql.gz", "sha256": hashlib.sha256(raw).hexdigest()}
            ],
        }
        (root / "import-plan.json").write_text(json.dumps(plan))
        return plan

    def test_a_tampered_operation_never_reaches_database(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.fixture(root)
            (root / "operation.sql.gz").write_bytes(gzip.compress(b"changed"))
            sql = Mock()
            (root / "_scratch").mkdir()
            with (
                patch(
                    "tools.content_completion.v4_local_import.connection",
                    return_value=sql,
                ),
                patch("tools.content_completion.v4_local_import.ROOT", root),
                self.assertRaisesRegex(ValueError, "hash_changed"),
            ):
                apply_plan(root, root)
            sql.assert_not_called()

    def test_partial_batch_failure_retains_only_committed_receipts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            plan = self.fixture(root)
            plan["operations"] *= 2
            (root / "import-plan.json").write_text(json.dumps(plan))
            (root / "_scratch").mkdir()
            failure = RuntimeError("second operation failed")
            failure.local_stdout = "V4_APPLIED:0\n"
            with (
                patch(
                    "tools.content_completion.v4_local_import.connection",
                    return_value=Mock(side_effect=failure),
                ),
                patch("tools.content_completion.v4_local_import.ROOT", root),
                self.assertRaisesRegex(RuntimeError, "second operation"),
            ):
                apply_plan(root, root)
            receipts = json.loads((root / "local-execution.json").read_text())
            self.assertEqual(len(receipts), 1)
            self.assertEqual(
                receipts[0]["environment"], "local:rad_full_content_v4_20261028"
            )


if __name__ == "__main__":
    unittest.main()
