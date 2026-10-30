import gzip
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from tools.content_completion.v4_local_import import apply_plan, connection


class LocalImportBoundaryTests(unittest.TestCase):
    def native_fixture(self, root):
        runtime = root.parent / "_audit/RAD_MASTER_EXECUTION_20261029/native"
        runtime.mkdir(parents=True)
        marker = {
            "port": 64932,
            "database": "rad_master_acceptance_20261029",
            "source": str(root),
            "scope": "local_synthetic_managed_services_not_hosted_restore",
        }
        (runtime / "RAD_DISPOSABLE_LOCAL_ONLY.json").write_text(json.dumps(marker))
        return runtime, marker

    def test_owned_native_fixture_uses_fixed_loopback_target_and_cleans_pg_environment(
        self,
    ):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "checkout"
            runtime, _ = self.native_fixture(root)
            with (
                patch("tools.content_completion.v4_local_import.ROOT", root),
                patch.dict(
                    "os.environ", {"PGSERVICE": "untrusted-remote", "PGHOST": "remote"}
                ),
                patch(
                    "tools.content_completion.v4_local_import.subprocess.run",
                    return_value=Mock(returncode=0, stdout="local-probe", stderr=""),
                ) as execute,
            ):
                result = connection(runtime)("select 'local-probe';")
            self.assertEqual(result, "local-probe")
            command = execute.call_args.args[0]
            self.assertEqual(command[command.index("-h") + 1], "127.0.0.1")
            self.assertEqual(command[command.index("-p") + 1], "64932")
            self.assertEqual(
                command[command.index("-d") + 1], "rad_master_acceptance_20261029"
            )
            self.assertNotIn("PGSERVICE", execute.call_args.kwargs["env"])
            self.assertNotIn("PGHOST", execute.call_args.kwargs["env"])

    def test_changed_native_target_is_rejected_before_database(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "checkout"
            runtime, marker = self.native_fixture(root)
            marker["port"] = 5432
            (runtime / "RAD_DISPOSABLE_LOCAL_ONLY.json").write_text(json.dumps(marker))
            with patch("tools.content_completion.v4_local_import.ROOT", root):
                with self.assertRaisesRegex(
                    ValueError, "owned_native_runtime_marker_required"
                ):
                    connection(runtime)

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
