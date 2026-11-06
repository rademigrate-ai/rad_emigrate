"""Offline artifact integrity is separate from hosted release authorization."""

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from scripts import production_mechanical_decisions as mechanical
from scripts import production_reconciliation_package as package
from scripts import reconciliation_package_adapter as adapter
from scripts.tests import test_mechanical_release_decisions as mechanical_fixtures
from scripts.tests import test_production_reconciliation_package as fixtures


class PackageSealsTest(unittest.TestCase):
    def make_package(self, root, corrected=True):
        operation = package.make_operation(
            fixtures.ReconciliationPlanTest().fixture(), None, "NEW_KEY_DRAFT_CANDIDATE"
        )
        plan = package.seal_plan({"production_baseline": []}, [operation])
        (root / "plan.json").write_text(json.dumps(plan), encoding="utf8")
        package.write_rows(root / "operations.jsonl.gz", [operation])
        (root / "publication").mkdir()
        (root / "publication/batch-000.json").write_text("{}", encoding="utf8")
        seals = {
            p.relative_to(root).as_posix().replace("/", "\\"): package.digest(
                p.read_bytes()
            )
            for p in root.rglob("*")
            if p.is_file()
        }
        manifest = {
            "package_sha256": plan["package_sha256"],
            "operations": 1,
            "files": seals,
            "hosted_release_authorized": False,
            "approved": 0,
            "imported": 0,
            "published": 0,
        }
        name = "manifest.json" if corrected else "artifact-seals.json"
        (root / name).write_text(
            json.dumps(manifest if corrected else seals), encoding="utf8"
        )
        return plan, [operation], manifest

    def test_both_producer_formats_load_identical_verified_plan_and_operations(self):
        for corrected in (True, False):
            with (
                self.subTest(corrected=corrected),
                tempfile.TemporaryDirectory() as tmp,
            ):
                root = Path(tmp)
                plan, operations, _ = self.make_package(root, corrected)
                self.assertEqual(adapter.load_sealed_package(root), (plan, operations))

    def test_tampered_operation_or_batch_is_refused(self):
        for name in ("operations.jsonl.gz", "publication/batch-000.json"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                self.make_package(root)
                with (root / name).open("ab") as stream:
                    stream.write(b"changed")
                with self.assertRaisesRegex(ValueError, "package_artifact_tampered"):
                    adapter.load_sealed_package(root)

    def test_corrected_manifest_cannot_omit_add_or_alias_a_file(self):
        for mode in ("omit", "add", "alias", "unsealed_plan"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                _, _, manifest = self.make_package(root)
                if mode == "omit":
                    del manifest["files"]["publication\\batch-000.json"]
                elif mode == "add":
                    (root / "unexpected.sql").write_text("select 1", encoding="utf8")
                elif mode == "alias":
                    manifest["files"]["publication/batch-000.json"] = manifest["files"][
                        "publication\\batch-000.json"
                    ]
                else:
                    del manifest["files"]["plan.json"]
                (root / "manifest.json").write_text(json.dumps(manifest), "utf8")
                with self.assertRaises(ValueError):
                    adapter.load_sealed_package(root)

    def test_path_traversal_absolute_and_invalid_seals_are_refused(self):
        for name in ("../outside", "..\\outside", "/outside", "C:\\outside", "a/./b"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                _, _, manifest = self.make_package(root)
                manifest["files"][name] = "a" * 64
                (root / "manifest.json").write_text(json.dumps(manifest), "utf8")
                with self.assertRaisesRegex(ValueError, "package_artifact_path"):
                    adapter.load_sealed_package(root)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, _, manifest = self.make_package(root)
            manifest["files"]["plan.json"] = "not-a-digest"
            (root / "manifest.json").write_text(json.dumps(manifest), "utf8")
            with self.assertRaisesRegex(ValueError, "package_artifact_digest"):
                adapter.load_sealed_package(root)

    def test_manifest_and_plan_bindings_cannot_be_substituted(self):
        for mode in ("package", "count", "plan"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                plan, _, manifest = self.make_package(root)
                if mode == "package":
                    manifest["package_sha256"] = "a" * 64
                elif mode == "count":
                    manifest["operations"] = 2
                else:
                    plan["production_baseline"] = [{"changed": True}]
                    (root / "plan.json").write_text(json.dumps(plan), "utf8")
                    manifest["files"]["plan.json"] = package.digest(
                        (root / "plan.json").read_bytes()
                    )
                (root / "manifest.json").write_text(json.dumps(manifest), "utf8")
                with self.assertRaisesRegex(ValueError, "package_(manifest|plan)"):
                    adapter.load_sealed_package(root)

    def test_symlink_cannot_replace_an_artifact(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, _, manifest = self.make_package(root)
            batch = root / "publication/batch-000.json"
            target = root / "target.json"
            target.write_bytes(batch.read_bytes())
            batch.unlink()
            try:
                batch.symlink_to(target)
            except OSError:
                self.skipTest("This Windows account cannot create symlinks")
            manifest["files"]["target.json"] = package.digest(target.read_bytes())
            (root / "manifest.json").write_text(json.dumps(manifest), "utf8")
            with self.assertRaisesRegex(ValueError, "package_artifact_path"):
                adapter.load_sealed_package(root)

    def test_unlisted_symlink_alias_is_not_hidden_by_resolved_file_inventory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.make_package(root)
            try:
                (root / "unlisted.json").symlink_to(root / "plan.json")
            except OSError:
                self.skipTest("This Windows account cannot create symlinks")
            with self.assertRaisesRegex(ValueError, "package_artifact_path"):
                adapter.load_sealed_package(root)

    def test_cli_preserves_guarded_output_and_does_not_overwrite_existing_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "package"
            root.mkdir()
            plan, operations, _ = self.make_package(root)
            auth = fixtures.ReconciliationPlanTest().authorization(package, plan)
            authorization = Path(tmp) / "synthetic-local-render-only.json"
            authorization.write_text(json.dumps(auth), "utf8")
            output = Path(tmp) / "offline-not-executed.sql"
            command = [
                sys.executable,
                "-m",
                "scripts.reconciliation_package_adapter",
                "render-approved-restore",
                "--package",
                str(root),
                "--authorization",
                str(authorization),
                "--output",
                str(output),
            ]
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            expected = package.render_sql(plan, operations, auth)
            self.assertEqual(output.read_text("utf8"), expected)
            self.assertFalse(json.loads(result.stdout)["execution_performed"])
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(output.read_text("utf8"), expected)

    def test_corrected_cli_still_requires_real_production_checkpoint(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "package"
            root.mkdir()
            plan, _, _ = self.make_package(root)
            auth = fixtures.ReconciliationPlanTest().authorization(package, plan)
            auth = copy.deepcopy(auth)
            auth.update(execution_scope="approved_production")
            auth["restore_endpoint"]["server_addr"] = "198.51.100.11"
            authorization = Path(tmp) / "synthetic-unauthorized.json"
            authorization.write_text(json.dumps(auth), "utf8")
            output = Path(tmp) / "must-not-exist.sql"
            result = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "scripts.reconciliation_package_adapter",
                    "render-approved-production",
                    "--package",
                    str(root),
                    "--authorization",
                    str(authorization),
                    "--output",
                    str(output),
                ],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(
                "production_real_checkpoint_and_explicit_owner_authorization_required",
                result.stderr,
            )
            self.assertFalse(output.exists())

    def test_cli_cannot_write_sql_into_the_sealed_input_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "package"
            root.mkdir()
            plan, _, _ = self.make_package(root)
            auth = fixtures.ReconciliationPlanTest().authorization(package, plan)
            authorization = Path(tmp) / "synthetic-render-only.json"
            authorization.write_text(json.dumps(auth), "utf8")
            output = root / "unsealed-output.sql"
            result = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "scripts.reconciliation_package_adapter",
                    "render-approved-restore",
                    "--package",
                    str(root),
                    "--authorization",
                    str(authorization),
                    "--output",
                    str(output),
                ],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("package_output_must_be_external", result.stderr)
            self.assertFalse(output.exists())

    def test_mechanical_cli_uses_unchanged_renderer_and_keeps_checkpoint_guard(self):
        with tempfile.TemporaryDirectory() as tmp:
            evidence = Path(tmp) / "evidence"
            evidence.mkdir()
            plan, operations, readback = (
                mechanical_fixtures.MechanicalDecisionTest().fixture(evidence)
            )
            decisions = mechanical.prepare(plan, operations, evidence, readback)
            root = Path(tmp) / "package"
            root.mkdir()
            (root / "plan.json").write_text(json.dumps(plan), "utf8")
            package.write_rows(root / "operations.jsonl.gz", operations)
            (root / "mechanical-decisions.json").write_text(
                json.dumps(decisions), "utf8"
            )
            manifest = {
                "package_sha256": plan["package_sha256"],
                "operations": 1,
                "files": {
                    p.name: package.digest(p.read_bytes()) for p in root.iterdir()
                },
            }
            (root / "manifest.json").write_text(json.dumps(manifest), "utf8")
            auth = fixtures.ReconciliationPlanTest().authorization(package, plan)
            auth.update(
                mechanical_decisions_sha256=decisions["decision_package_sha256"],
                mechanical_adapter_sha256=package.digest(
                    Path(mechanical.__file__).read_bytes()
                ),
            )
            authorization = Path(tmp) / "synthetic-render-only.json"
            authorization.write_text(json.dumps(auth), "utf8")
            output = Path(tmp) / "not-executed.sql"
            command = [
                sys.executable,
                "-m",
                "scripts.reconciliation_package_adapter",
                "render-mechanical",
                "--package",
                str(root),
                "--decisions",
                str(root / "mechanical-decisions.json"),
                "--authorization",
                str(authorization),
                "--output",
                str(output),
            ]
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                output.read_text("utf8"),
                mechanical.render(plan, operations, decisions, auth),
            )
            output.unlink()
            auth["execution_scope"] = "approved_production"
            auth["restore_endpoint"]["server_addr"] = "198.51.100.11"
            authorization.write_text(json.dumps(auth), "utf8")
            result = subprocess.run(
                command + ["--execution-scope", "approved_production"],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(
                "production_real_checkpoint_and_explicit_owner_authorization_required",
                result.stderr,
            )
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
