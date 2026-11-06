"""Offline package builder unit tests; no remote services or real secrets."""

import subprocess
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from scripts.build_self_host_bundle import build_bundle, git


def run(repo, *args):
    subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True)


class BuildSelfHostBundleTest(unittest.TestCase):
    def test_packages_only_tracked_rad_sources_and_no_env_secrets(self):
        with TemporaryDirectory() as folder:
            base = Path(folder)
            source, upstream, output = base / "app", base / "upstream", base / "bundle"
            source.mkdir()
            upstream.mkdir()
            for repo in (source, upstream):
                run(repo, "init", "-q")
                run(repo, "config", "user.email", "fixture@example.test")
                run(repo, "config", "user.name", "Fixture")
            (source / "pubspec.yaml").write_text("name: rad_emigrate\n")
            (source / "supabase/functions/research-sync").mkdir(parents=True)
            (source / "supabase/functions/research-sync/index.ts").write_text(
                "export default {};\n"
            )
            (source / "supabase/functions/tests").mkdir()
            (source / "supabase/functions/tests/do_not_ship.ts").write_text("fixture")
            (source / "supabase/migrations").mkdir()
            (source / "supabase/migrations/20261104000000_fixture.sql").write_text(
                "select 1;"
            )
            (source / "supabase/functions/research-sync/.env").write_text(
                "NON_PUBLIC_SECRET=not_real_fixture"
            )
            run(
                source,
                "add",
                "pubspec.yaml",
                "supabase/functions",
                "supabase/migrations",
            )
            run(source, "commit", "-qm", "fixture app")

            (upstream / "docker").mkdir()
            (upstream / "docker/docker-compose.yml").write_text(
                "services:\n  db:\n    image: postgres:17\n"
            )
            (upstream / "docker/.env.example").write_text("VAR=replace_me\n")
            (upstream / "docker/.env").write_text("VAR=do_not_ship\n")
            run(upstream, "add", "docker/docker-compose.yml", "docker/.env.example")
            run(upstream, "commit", "-qm", "fixture docker")

            manifest = build_bundle(
                source,
                upstream,
                output,
                expected_upstream_sha=git(upstream, "rev-parse", "HEAD"),
            )
            self.assertEqual(manifest["migration_count"], 1)
            self.assertEqual(manifest["edge_function_names"], ["research-sync"])
            self.assertTrue(
                (output / "volumes/functions/research-sync/index.ts").is_file()
            )
            self.assertTrue(
                (output / "rad_migrations/20261104000000_fixture.sql").is_file()
            )
            self.assertTrue((output / ".env.example").is_file())
            self.assertFalse((output / ".env").exists())
            self.assertFalse((output / "volumes/functions/research-sync/.env").exists())
            self.assertFalse((output / "volumes/functions/tests").exists())
            self.assertIn("NOT_MIGRATION_OR_RELEASE_ACCEPTANCE", manifest["status"])
            with self.assertRaises(FileExistsError):
                build_bundle(
                    source,
                    upstream,
                    output,
                    expected_upstream_sha=git(upstream, "rev-parse", "HEAD"),
                )

    def test_rejects_unverified_upstream_release(self):
        with TemporaryDirectory() as folder:
            base = Path(folder)
            (base / "app").mkdir()
            (base / "app/pubspec.yaml").write_text("name: rad")
            (base / "upstream/docker").mkdir(parents=True)
            (base / "upstream/docker/docker-compose.yml").write_text("services: {}")
            run(base / "upstream", "init", "-q")
            with self.assertRaises(ValueError):
                build_bundle(base / "app", base / "upstream", base / "bundle")


if __name__ == "__main__":
    unittest.main()
