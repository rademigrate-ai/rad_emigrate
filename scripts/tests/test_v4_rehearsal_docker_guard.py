"""The legacy corpus Docker transport must never select a remote engine."""

import json
import os
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.content_completion.v4_corpus_rehearsal import (
    local_command,
    local_environment,
)


class RehearsalDockerGuardTests(unittest.TestCase):
    def test_legacy_subprocess_environment_cannot_redirect_libpq(self):
        with patch.dict(
            os.environ,
            {
                "PGHOSTADDR": "203.0.113.1",
                "PGSERVICE": "remote-service",
                "PGSERVICEFILE": "private-service-file",
                "PGPASSWORD": "synthetic-unrelated-password",
                "PGOPTIONS": "arbitrary-options",
                "PATH": "local-tools",
            },
            clear=True,
        ):
            environment = local_environment()
        self.assertEqual(environment["PGHOSTADDR"], "127.0.0.1")
        self.assertEqual(environment["PATH"], "local-tools")
        self.assertEqual(
            {key for key in environment if key.upper().startswith("PG")},
            {"PGHOSTADDR", "PGCONNECT_TIMEOUT", "PGCLIENTENCODING"},
        )

    def marker(self):
        return json.dumps(
            {
                "project": "rad_full_content_v4_20261028",
                "source": str(Path.cwd()),
                "port": 64522,
            }
        )

    def test_remote_environment_overrides_are_rejected_before_marker_or_docker(self):
        for key in (
            "DOCKER_HOST",
            "DOCKER_CONTEXT",
            "DOCKER_CONFIG",
            "DOCKER_TLS_VERIFY",
            "DOCKER_CERT_PATH",
        ):
            with (
                self.subTest(key=key),
                patch.dict(os.environ, {key: "remote-override"}, clear=True),
                patch.object(Path, "read_text") as read,
                patch("subprocess.check_output") as inspect,
            ):
                with self.assertRaisesRegex(
                    ValueError, "local_default_docker_context_required"
                ):
                    local_command(
                        "postgres", "supabase_db_rad_full_content_v4_20261028"
                    )
                read.assert_not_called()
                inspect.assert_not_called()

    def test_local_default_socket_is_verified_and_forced_for_exec(self):
        for endpoint in (
            "unix:///var/run/docker.sock",
            "npipe:////./pipe/docker_engine",
            "npipe:////./pipe/dockerDesktopLinuxEngine",
        ):
            with (
                self.subTest(endpoint=endpoint),
                patch.dict(os.environ, {}, clear=True),
                patch.object(Path, "read_text", return_value=self.marker()),
                patch(
                    "subprocess.check_output", return_value=json.dumps(endpoint)
                ) as inspect,
            ):
                command = local_command(
                    "postgres", "supabase_db_rad_full_content_v4_20261028"
                )
                self.assertEqual(
                    command[:4], ["docker", "--context", "default", "exec"]
                )
                self.assertIn("default", inspect.call_args.args[0])
                self.assertIn("inspect", inspect.call_args.args[0])

    def test_remote_or_invalid_default_endpoint_fails_closed(self):
        for endpoint in (
            "tcp://remote.example.invalid:2376",
            "tcp://127.0.0.1:2375",
            "ssh://operator@remote.example.invalid",
            "https://remote.example.invalid",
            "unix://remote.example.invalid/var/run/docker.sock",
            "npipe:////remote.example.invalid/pipe/docker_engine",
            "",
        ):
            with (
                self.subTest(endpoint=endpoint),
                patch.dict(os.environ, {}, clear=True),
                patch.object(Path, "read_text", return_value=self.marker()),
                patch("subprocess.check_output", return_value=json.dumps(endpoint)),
            ):
                with self.assertRaisesRegex(
                    ValueError, "local_default_docker_endpoint_required"
                ):
                    local_command(
                        "postgres", "supabase_db_rad_full_content_v4_20261028"
                    )

        for reply in ("not-json", "null", "{}"):
            with (
                self.subTest(reply=reply),
                patch.dict(os.environ, {}, clear=True),
                patch.object(Path, "read_text", return_value=self.marker()),
                patch("subprocess.check_output", return_value=reply),
            ):
                with self.assertRaisesRegex(
                    ValueError, "local_default_docker_endpoint_required"
                ):
                    local_command(
                        "postgres", "supabase_db_rad_full_content_v4_20261028"
                    )

    def test_failed_or_malformed_context_inspection_cannot_select_docker(self):
        for failure in (
            subprocess.CalledProcessError(1, "docker"),
            subprocess.TimeoutExpired("docker", 10),
        ):
            with (
                self.subTest(failure=type(failure).__name__),
                patch.dict(os.environ, {}, clear=True),
                patch.object(Path, "read_text", return_value=self.marker()),
                patch("subprocess.check_output", side_effect=failure),
            ):
                with self.assertRaisesRegex(
                    ValueError, "local_default_docker_endpoint_required"
                ):
                    local_command(
                        "postgres", "supabase_db_rad_full_content_v4_20261028"
                    )


if __name__ == "__main__":
    unittest.main()
