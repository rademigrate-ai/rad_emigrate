#!/usr/bin/env python3
"""Focused failure-path coverage for Phase 2 loading evidence publication."""

from __future__ import annotations

import asyncio
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("capture_phase2_loading_motion.py")
SPEC = importlib.util.spec_from_file_location("phase2_capture", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
capture = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = capture
SPEC.loader.exec_module(capture)


class CapturePublicationTest(unittest.IsolatedAsyncioTestCase):
    async def test_failed_capture_discards_staged_artifacts_and_keeps_prior_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "visual_qa"
            output.mkdir()
            original = output / "phase2_existing_evidence.png"
            original.write_bytes(b"existing-evidence")

            async def simulated_console_failure(staging: Path) -> dict[str, object]:
                (staging / "phase2_target_desktop.png").write_bytes(b"partial")
                (staging / "phase2_target_orbit.webm").write_bytes(b"partial-video")
                raise RuntimeError("Browser console error(s) for target")

            with self.assertRaisesRegex(RuntimeError, "Browser console error"):
                await capture.capture_and_publish(
                    output_dir=output,
                    capture_to_staging=simulated_console_failure,
                )

            self.assertEqual(original.read_bytes(), b"existing-evidence")
            self.assertFalse((output / "phase2_target_desktop.png").exists())
            self.assertFalse((output / "phase2_target_orbit.webm").exists())
            self.assertFalse(list(output.glob(".phase2_loading_capture_*")))


if __name__ == "__main__":
    unittest.main()
