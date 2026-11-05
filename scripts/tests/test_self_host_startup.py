import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.self_host_stack import MARKER, start


class StartupTests(unittest.TestCase):
    def test_transient_unhealthy_is_polled_until_ready_without_reset(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "RAD_ISOLATED_INSTALL.json").write_text(
                json.dumps({"marker": MARKER, "project": "rad-selfhost-test"})
            )
            (root / "compose.rad.json").write_text(
                json.dumps({"services": {"db": {}, "pooler": {"profiles": ["pooler"]}}})
            )
            responses = [
                b"",
                b'{"Service":"db","State":"running","Health":"unhealthy"}',
                b'{"Service":"db","State":"running","Health":"healthy"}',
            ]
            with (
                patch("scripts.self_host_stack.run") as run,
                patch("scripts.self_host_stack.time.sleep") as sleep,
            ):
                run.side_effect = [
                    subprocess.CompletedProcess([], 0, stdout=value)
                    for value in responses
                ]
                start(root)
                sleep.assert_called_once()
                calls = [call.args[0] for call in run.call_args_list]
                self.assertTrue(
                    all("down" not in call and "rm" not in call for call in calls)
                )
                self.assertNotIn("--wait", calls[0])

    def test_deadline_reports_unready_services_without_destroying_them(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "RAD_ISOLATED_INSTALL.json").write_text(
                json.dumps({"marker": MARKER, "project": "rad-selfhost-test"})
            )
            (root / "compose.rad.json").write_text(json.dumps({"services": {"db": {}}}))
            with (
                patch("scripts.self_host_stack.run") as run,
                patch("scripts.self_host_stack.time.sleep"),
                patch(
                    "scripts.self_host_stack.time.monotonic", side_effect=[0, 0, 241]
                ),
            ):
                run.side_effect = [
                    subprocess.CompletedProcess([], 0, stdout=b""),
                    subprocess.CompletedProcess([], 0, stdout=b""),
                ]
                with self.assertRaisesRegex(RuntimeError, "db"):
                    start(root)
