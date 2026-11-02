"""Activation is offline, bounded, separated from discovery and fails closed."""

import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from scripts import research_activation_package as activation


class ResearchActivationPackageTest(unittest.TestCase):
    def test_cli_seals_actual_sql_file_bytes_on_windows_and_unix(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repo"
            (root / "supabase").mkdir(parents=True)
            (root / "scripts").mkdir()
            (root / "supabase/config.toml").write_text("fixture", "utf8")
            (root / "scripts/research_egress.py").write_text("fixture", "utf8")
            output = Path(directory) / "output"
            result = subprocess.run(
                [
                    sys.executable,
                    "-B",
                    "-m",
                    "scripts.research_activation_package",
                    "--repo",
                    str(root),
                    "--output",
                    str(output),
                ],
                cwd=Path(__file__).resolve().parents[2],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            package = json.loads((output / "activation-package.json").read_text("utf8"))
            for name, field in [
                ("SCHEDULER_REVIEW_ONLY.sql", "scheduler_review_sha256"),
                ("STOP_REVIEW_ONLY.sql", "stop_review_sha256"),
            ]:
                with self.subTest(name=name):
                    self.assertEqual(
                        hashlib.sha256((output / name).read_bytes()).hexdigest(),
                        package[field],
                    )

    def test_runtime_symlink_cannot_escape_source_binding(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target.ts"
            target.write_text("fixture", "utf8")
            alias = root / "runtime.ts"
            try:
                alias.symlink_to(target)
            except OSError:
                self.skipTest("local platform does not permit synthetic symlinks")
            with self.assertRaisesRegex(ValueError, "owned_regular_source"):
                activation.build_package(
                    root, [alias], "*/15 * * * *", "rad_official_purpose"
                )

    def test_actual_relative_runtime_contract_dependency_is_sealed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shared = root / "supabase/functions/_shared"
            shared.mkdir(parents=True)
            (shared / "rad_contract.ts").write_text(
                "import schema from '../../contracts/rad_v1.json';", "utf8"
            )
            contracts = root / "supabase/contracts"
            contracts.mkdir()
            dependency = contracts / "rad_v1.json"
            dependency.write_text('{"required":["job_id"]}', "utf8")
            (root / "supabase/config.toml").write_text("synthetic config", "utf8")
            (root / "scripts").mkdir()
            gateway = root / "scripts/research_egress.py"
            gateway.write_text("synthetic pinned gateway", "utf8")
            sources = activation.collect_sources(root)
            package = activation.build_package(
                root, sources, "*/15 * * * *", "rad_official_purpose"
            )
            self.assertIn("supabase/contracts/rad_v1.json", package["source_sha256"])
            self.assertIn("scripts/research_egress.py", package["source_sha256"])
            dependency.write_text("{}", "utf8")
            with self.assertRaisesRegex(ValueError, "source_changed"):
                activation.verify_sources(root, package)

    def test_disabled_package_seals_runtime_and_never_exports_secret_values(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runtime = root / "runtime.ts"
            runtime.write_text("synthetic runtime", encoding="utf8")
            result = activation.build_package(
                root, [runtime], "*/15 * * * *", "rad_official_purpose"
            )
            self.assertFalse(result["flags"]["RAD_OFFICIAL_SOURCE_WORKER_ENABLED"])
            self.assertFalse(result["flags"]["RAD_OFFICIAL_SOURCE_DISCOVERY_ENABLED"])
            self.assertEqual(result["hosted_operations_executed"], 0)
            self.assertIn("runtime.ts", result["source_sha256"])
            self.assertEqual(result["activation_state"], "REVIEW_ONLY")
            runtime.write_text("changed", encoding="utf8")
            with self.assertRaisesRegex(ValueError, "source_changed"):
                activation.verify_sources(root, result)

    def test_scheduler_is_review_only_and_does_not_replace_legacy_jobs(self):
        sql = activation.scheduler_sql("*/15 * * * *", "rad_official_purpose")
        self.assertLess(sql.index("RAISE EXCEPTION"), sql.index("cron.schedule"))
        self.assertIn("?dispatch=1", sql)
        self.assertIn("x-rad-official-source-token", sql)
        self.assertNotIn("rad-daily-research-worker", sql)
        self.assertNotIn("cron.unschedule", sql)
        self.assertNotIn("Bearer", sql)

    def test_manifest_cannot_drop_sources_or_tamper_its_own_seal(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "runtime.ts"
            source.write_text("fixture", "utf8")
            package = activation.build_package(
                root, [source], "*/15 * * * *", "rad_official_purpose"
            )
            package["source_sha256"] = {}
            with self.assertRaisesRegex(ValueError, "package_integrity"):
                activation.verify_sources(root, package)

    def test_sql_injection_unbounded_cadence_and_literal_token_refused(self):
        for schedule, reference in [
            ("* * * * *", "rad_official_purpose"),
            ("*/15 * * * *';--", "rad_official_purpose"),
            ("*/15 * * * *", "secret'; drop table x;--"),
        ]:
            with (
                self.subTest(schedule=schedule, reference=reference),
                self.assertRaises(ValueError),
            ):
                activation.scheduler_sql(schedule, reference)


if __name__ == "__main__":
    unittest.main()
