"""Safety boundaries of the independent installer and cold restore controller."""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.self_host_snapshot import (
    backup,
    gpg_path,
    is_posix_gpg,
    restore,
    to_posix_drive_path,
)
from scripts.self_host_stack import MARKER, compose, migrate, prepare


class GpgPathTests(unittest.TestCase):
    """A POSIX gpg build cannot parse a Windows drive path as an argument.

    It treats `D:\\...` as relative, prepends the cwd, then fails to create its
    homedir or read the passphrase file -- which silently broke every snapshot
    on Windows until the path was rendered per build. The conversion is pure
    string logic so these assertions run on every platform rather than
    no-opping wherever the host has no drive letters.
    """

    def test_drive_path_becomes_a_posix_path(self):
        self.assertEqual(
            to_posix_drive_path(r"D:\RAD - Emigrate\_audit\key.pass"),
            "/d/RAD - Emigrate/_audit/key.pass",
        )
        self.assertEqual(to_posix_drive_path("C:/Users/x/key"), "/c/Users/x/key")

    def test_posix_path_is_left_alone(self):
        for untouched in ("/home/runner/key.pass", "/d/already/posix", "relative/key"):
            self.assertEqual(to_posix_drive_path(untouched), untouched)

    def test_posix_build_detection(self):
        self.assertTrue(is_posix_gpg("/usr/bin/gpg"))
        self.assertTrue(is_posix_gpg(r"C:\Program Files\Git\usr\bin\gpg.EXE"))
        self.assertFalse(is_posix_gpg(r"C:\Program Files\GnuPG\bin\gpg.exe"))

    def test_native_gpg_keeps_the_platform_path(self):
        target = Path("D:/RAD/key.pass")
        self.assertEqual(
            gpg_path(r"C:\Program Files\GnuPG\bin\gpg.exe", target),
            str(target.resolve()),
        )


class SelfHostStackTests(unittest.TestCase):
    def identity(self, root, project="rad-selfhost-test"):
        (root / "RAD_ISOLATED_INSTALL.json").write_text(
            json.dumps({"marker": MARKER, "project": project, "api_port": 58000}),
            encoding="utf8",
        )
        (root / "compose.rad.json").write_text(
            json.dumps({"services": {"db": {"image": "postgres@sha256:" + "a" * 64}}}),
            encoding="utf8",
        )

    def test_refuses_dev_or_cloud_project_and_overwrite(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in (
                "supabase",
                "rad_emigrate",
                "inshddthftkhcdosoqcn",
                "rad-selfhost-test;anything",
            ):
                self.identity(root, name)
                with self.assertRaises(ValueError):
                    compose(root, "up")
            self.identity(root)
            command = compose(root, "ps")
            self.assertIn("rad-selfhost-test", command)
            with self.assertRaises(ValueError):
                prepare(root, root, "rad-selfhost-test", 58000)

    def test_missing_service_foundations_refuses_before_migration_writes(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch("scripts.self_host_stack.sql") as sql,
        ):
            sql.return_value = subprocess.CompletedProcess([], 0, stdout=b"0\n")
            with self.assertRaisesRegex(ValueError, "Auth and Storage"):
                migrate(Path(tmp))
            self.assertEqual(sql.call_count, 1)
            self.assertNotIn(b"create", sql.call_args.args[1])

    def test_nonempty_schema_refuses_instead_of_reset(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            patch("scripts.self_host_stack.sql") as sql,
        ):
            sql.side_effect = [
                subprocess.CompletedProcess([], 0, stdout=b"1\n"),
                subprocess.CompletedProcess([], 0, stdout=b"5\n"),
            ]
            with self.assertRaisesRegex(ValueError, "empty RAD public schema"):
                migrate(Path(tmp))
            self.assertEqual(sql.call_count, 2)

    def test_restore_refuses_source_target_existing_containers_and_volumes(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            root, snapshot = base / "target", base / "snapshot"
            root.mkdir()
            snapshot.mkdir()
            self.identity(root)
            receipt = {
                "source": {"project": "rad-selfhost-source"},
                "postgres_image": "postgres@sha256:" + "a" * 64,
                "files": {},
            }
            (snapshot / "SNAPSHOT.json").write_text(
                json.dumps(receipt), encoding="utf8"
            )
            with patch("scripts.self_host_snapshot.run") as run:
                run.return_value.stdout = b"existing-container"
                with self.assertRaisesRegex(ValueError, "existing containers"):
                    restore(root, snapshot, base / "key", "gpg")
            with (
                patch("scripts.self_host_snapshot.run") as run,
                patch("scripts.self_host_snapshot.subprocess.run") as inspect,
            ):
                run.return_value.stdout = b""
                inspect.return_value.returncode = 0
                with self.assertRaisesRegex(ValueError, "pre-existing target volume"):
                    restore(root, snapshot, base / "key", "gpg")
                self.assertEqual(inspect.call_count, 1)

    def test_backup_refuses_key_in_snapshot_or_install(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "install"
            root.mkdir()
            self.identity(root)
            with self.assertRaisesRegex(ValueError, "independently"):
                backup(root, Path(tmp) / "snapshot", root / "key", "gpg")


if __name__ == "__main__":
    unittest.main()
