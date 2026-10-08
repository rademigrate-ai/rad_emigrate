#!/usr/bin/env python3
"""Focused failure-path coverage for Phase 2 loading evidence publication."""

from __future__ import annotations

import importlib.util
import json
import os
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

TARGETS = ("splash", "full_loading", "section_loading", "compact_loading")
EXPECTED_NAMES = {
    *(f"phase2_{target}_{surface}.png" for target in TARGETS for surface in ("desktop", "mobile")),
    *(f"phase2_{target}_orbit.mp4" for target in TARGETS),
    "phase2_section_loading_dark_desktop.png",
    "phase2_section_loading_dark_mobile.png",
    "phase2_loading_capture_report.json",
}


def _report() -> dict[str, object]:
    return {
        "source": "test",
        "baseUrl": "http://example.test",
        "targets": {
            target: {"finalVideo": f"phase2_{target}_orbit.mp4"}
            for target in TARGETS
        },
        "darkSectionContrast": {"desktop": [], "mobile": []},
    }


def _write_complete_evidence(directory: Path, prefix: bytes) -> None:
    for name in EXPECTED_NAMES - {"phase2_loading_capture_report.json"}:
        (directory / name).write_bytes(prefix + name.encode())
    (directory / "phase2_loading_capture_report.json").write_text(
        json.dumps(_report()),
        encoding="utf-8",
    )


def _snapshot(directory: Path) -> dict[str, bytes]:
    return {name: (directory / name).read_bytes() for name in EXPECTED_NAMES}


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

    async def test_incomplete_capture_manifest_preserves_prior_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "visual_qa"
            output.mkdir()
            _write_complete_evidence(output, b"prior-")
            before = _snapshot(output)

            async def incomplete_capture(staging: Path) -> dict[str, object]:
                (staging / "phase2_splash_desktop.png").write_bytes(b"partial")
                return _report()

            with self.assertRaisesRegex(RuntimeError, "manifest"):
                await capture.capture_and_publish(
                    output_dir=output,
                    capture_to_staging=incomplete_capture,
                )

            self.assertEqual(_snapshot(output), before)
            self.assertFalse(list(output.glob(".phase2_loading_capture_*")))

    async def test_publication_failure_rolls_back_the_full_prior_evidence_set(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "visual_qa"
            output.mkdir()
            _write_complete_evidence(output, b"prior-")
            before = _snapshot(output)
            staging_root: Path | None = None
            published = 0

            async def complete_capture(staging: Path) -> dict[str, object]:
                nonlocal staging_root
                staging_root = staging
                _write_complete_evidence(staging, b"candidate-")
                return _report()

            def fail_during_second_candidate_publish(source: Path, destination: Path) -> None:
                nonlocal published
                if source.parent == staging_root and destination.parent == output:
                    published += 1
                    if published == 2:
                        raise OSError("injected replacement failure")
                os.replace(source, destination)

            with self.assertRaisesRegex(OSError, "injected replacement failure"):
                await capture.capture_and_publish(
                    output_dir=output,
                    capture_to_staging=complete_capture,
                    replace_file=fail_during_second_candidate_publish,
                )

            self.assertEqual(_snapshot(output), before)
            self.assertFalse(list(output.glob(".phase2_loading_capture_*")))
            self.assertFalse(list(output.glob(".phase2_loading_backup_*")))


if __name__ == "__main__":
    unittest.main()
