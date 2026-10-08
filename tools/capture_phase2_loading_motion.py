#!/usr/bin/env python3
"""Capture Phase 2 RAD Earth-and-bird Flutter loading evidence.

The visual-QA build must already be served locally. The `splash` route mounts
an actual SplashPage held pending by a QA-only bootstrap override; all loading
routes use the production shared widgets with synthetic state only. This script
never enters credentials, triggers app actions, or accesses customer data.
"""

from __future__ import annotations

import asyncio
import json
import os
import shutil
import subprocess
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Awaitable, Callable

from playwright.async_api import ConsoleMessage, Page, async_playwright

OUT = Path("docs/visual_qa")
BASE_URL = os.environ.get("RAD_PHASE2_CAPTURE_URL", "http://127.0.0.1:8087")
CAPTURE_SECONDS = 14
SETTLE_MS = 3200
DESKTOP = {"width": 1280, "height": 800}
MOBILE = {"width": 390, "height": 844}


@dataclass(frozen=True)
class CaptureTarget:
    slug: str
    screen: str


TARGETS = (
    CaptureTarget("splash", "splash"),
    CaptureTarget("full_loading", "loading-full"),
    CaptureTarget("section_loading", "loading-section"),
    CaptureTarget("compact_loading", "loading-compact"),
)


def url_for(screen: str) -> str:
    return f"{BASE_URL}/?screen={screen}&capture=1"


def duration_seconds(path: Path) -> float:
    output = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=nk=1:nw=1",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return float(output.stdout.strip())


def video_metadata(path: Path) -> dict[str, object]:
    output = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "stream=codec_name,width,height,r_frame_rate",
            "-show_entries",
            "format=duration",
            "-of",
            "json",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(output.stdout)


def transcode_exact_orbit(raw: Path, final: Path) -> tuple[float, float]:
    raw_duration = duration_seconds(raw)
    trim_start = max(0.0, raw_duration - CAPTURE_SECONDS)
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(raw),
            "-ss",
            f"{trim_start:.3f}",
            "-t",
            str(CAPTURE_SECONDS),
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-movflags",
            "+faststart",
            str(final),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return raw_duration, trim_start


def attach_console_capture(page: Page, messages: list[dict[str, str]]) -> None:
    def record(message: ConsoleMessage) -> None:
        messages.append({"type": message.type, "text": message.text})

    page.on("console", record)


def raise_for_console_errors(label: str, messages: list[dict[str, str]]) -> None:
    errors = [message["text"] for message in messages if message["type"] == "error"]
    if errors:
        joined = "\n".join(f"- {message}" for message in errors)
        raise RuntimeError(f"Browser console error(s) for {label}:\n{joined}")


async def capture_target(
    playwright,
    target: CaptureTarget,
    output_dir: Path,
) -> dict[str, object]:
    console: list[dict[str, str]] = []
    recording_dir = output_dir / f"phase2_{target.slug}_recording_tmp"
    raw_video = output_dir / f"phase2_{target.slug}_orbit.webm"
    final_video = output_dir / f"phase2_{target.slug}_orbit.mp4"

    shutil.rmtree(recording_dir, ignore_errors=True)
    recording_dir.mkdir(parents=True, exist_ok=True)
    raw_video.unlink(missing_ok=True)
    final_video.unlink(missing_ok=True)

    browser = await playwright.chromium.launch(
        executable_path="/usr/bin/chromium",
        headless=True,
        args=["--no-sandbox"],
    )
    try:
        desktop_context = await browser.new_context(
            viewport=DESKTOP,
            device_scale_factor=1,
            record_video_dir=str(recording_dir),
            record_video_size=DESKTOP,
        )
        desktop = await desktop_context.new_page()
        attach_console_capture(desktop, console)
        await desktop.goto(url_for(target.screen), wait_until="networkidle", timeout=60000)
        await desktop.wait_for_timeout(SETTLE_MS)
        await desktop.screenshot(
            path=str(output_dir / f"phase2_{target.slug}_desktop.png")
        )

        video = desktop.video
        assert video is not None
        started = time.monotonic()
        await desktop.wait_for_timeout(CAPTURE_SECONDS * 1000)
        capture_seconds = time.monotonic() - started
        await desktop.close()
        await desktop_context.close()
        await video.save_as(str(raw_video))

        mobile_context = await browser.new_context(
            viewport=MOBILE,
            device_scale_factor=1,
        )
        mobile = await mobile_context.new_page()
        attach_console_capture(mobile, console)
        await mobile.goto(url_for(target.screen), wait_until="networkidle", timeout=60000)
        await mobile.wait_for_timeout(SETTLE_MS)
        await mobile.screenshot(
            path=str(output_dir / f"phase2_{target.slug}_mobile.png")
        )
        await mobile_context.close()
    finally:
        await browser.close()

    raise_for_console_errors(target.slug, console)
    raw_duration, trim_start = transcode_exact_orbit(raw_video, final_video)
    raw_video.unlink(missing_ok=True)
    shutil.rmtree(recording_dir, ignore_errors=True)
    final_duration = duration_seconds(final_video)
    if not 12 <= final_duration <= 15:
        raise RuntimeError(f"Unexpected final duration for {target.slug}: {final_duration}")

    return {
        "route": target.screen,
        "url": url_for(target.screen),
        "desktopViewport": "1280x800",
        "mobileViewport": "390x844",
        "requestedCaptureSeconds": CAPTURE_SECONDS,
        "captureSeconds": capture_seconds,
        "rawRecordingSeconds": raw_duration,
        "trimStartSeconds": trim_start,
        "finalVideo": final_video.name,
        "finalVideoMetadata": video_metadata(final_video),
        "console": console,
    }


async def capture_section_dark_contrast(
    playwright,
    output_dir: Path,
) -> dict[str, list[dict[str, str]]]:
    browser = await playwright.chromium.launch(
        executable_path="/usr/bin/chromium",
        headless=True,
        args=["--no-sandbox"],
    )
    reports: dict[str, list[dict[str, str]]] = {}
    try:
        for suffix, viewport in (("desktop", DESKTOP), ("mobile", MOBILE)):
            page = await browser.new_page(viewport=viewport, device_scale_factor=1)
            console: list[dict[str, str]] = []
            attach_console_capture(page, console)
            await page.goto(
                url_for("loading-section-dark"),
                wait_until="networkidle",
                timeout=60000,
            )
            await page.wait_for_timeout(SETTLE_MS)
            await page.screenshot(
                path=str(output_dir / f"phase2_section_loading_dark_{suffix}.png")
            )
            await page.close()
            raise_for_console_errors(f"section-loading-dark-{suffix}", console)
            reports[suffix] = console
    finally:
        await browser.close()
    return reports


CaptureToStaging = Callable[[Path], Awaitable[dict[str, object]]]
ReplaceFile = Callable[[Path, Path], None]


def expected_evidence_names() -> set[str]:
    names = {
        "phase2_loading_capture_report.json",
        "phase2_section_loading_dark_desktop.png",
        "phase2_section_loading_dark_mobile.png",
    }
    for target in TARGETS:
        names.update(
            {
                f"phase2_{target.slug}_desktop.png",
                f"phase2_{target.slug}_mobile.png",
                f"phase2_{target.slug}_orbit.mp4",
            }
        )
    return names


def validate_staged_evidence(
    staging: Path,
    report: dict[str, object],
) -> list[Path]:
    expected = expected_evidence_names()
    entries = list(staging.iterdir())
    unexpected_directories = [entry.name for entry in entries if entry.is_dir()]
    artifact_names = {entry.name for entry in entries if entry.is_file()}
    missing = sorted(expected - artifact_names)
    unexpected = sorted(artifact_names - expected)
    if missing or unexpected or unexpected_directories:
        raise RuntimeError(
            "Phase 2 evidence manifest mismatch: "
            f"missing={missing}, unexpected={unexpected}, "
            f"directories={sorted(unexpected_directories)}"
        )

    targets = report.get("targets")
    if not isinstance(targets, dict) or set(targets) != {
        target.slug for target in TARGETS
    }:
        raise RuntimeError("Phase 2 report target manifest mismatch")
    for target in TARGETS:
        target_report = targets.get(target.slug)
        if not isinstance(target_report, dict) or target_report.get(
            "finalVideo"
        ) != f"phase2_{target.slug}_orbit.mp4":
            raise RuntimeError(f"Phase 2 report video manifest mismatch for {target.slug}")

    dark_section = report.get("darkSectionContrast")
    if not isinstance(dark_section, dict) or set(dark_section) != {
        "desktop",
        "mobile",
    }:
        raise RuntimeError("Phase 2 dark-section report manifest mismatch")

    return sorted(staging / name for name in expected)


def publish_evidence_set(
    *,
    output_dir: Path,
    artifacts: list[Path],
    replace_file: ReplaceFile,
) -> None:
    """Replaces evidence as one rollback-safe set after staging validation."""
    with tempfile.TemporaryDirectory(
        prefix=".phase2_loading_backup_",
        dir=output_dir,
    ) as temporary:
        backup = Path(temporary)
        prior_artifacts: list[tuple[Path, Path]] = []
        published: list[Path] = []
        try:
            for artifact in artifacts:
                destination = output_dir / artifact.name
                if destination.exists():
                    archived = backup / artifact.name
                    replace_file(destination, archived)
                    prior_artifacts.append((destination, archived))

            for artifact in artifacts:
                destination = output_dir / artifact.name
                replace_file(artifact, destination)
                published.append(destination)
        except Exception:
            for destination in published:
                destination.unlink(missing_ok=True)
            for destination, archived in reversed(prior_artifacts):
                if archived.exists():
                    os.replace(archived, destination)
            raise


async def capture_and_publish(
    *,
    output_dir: Path,
    capture_to_staging: CaptureToStaging,
    replace_file: ReplaceFile = os.replace,
) -> None:
    """Validates and transactionally publishes one complete evidence generation."""
    output_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=".phase2_loading_capture_",
        dir=output_dir,
    ) as temporary:
        staging = Path(temporary)
        report = await capture_to_staging(staging)
        (staging / "phase2_loading_capture_report.json").write_text(
            json.dumps(report, indent=2) + "\n",
            encoding="utf-8",
        )
        artifacts = validate_staged_evidence(staging, report)
        publish_evidence_set(
            output_dir=output_dir,
            artifacts=artifacts,
            replace_file=replace_file,
        )


async def main() -> None:
    async def capture_to_staging(staging: Path) -> dict[str, object]:
        reports: dict[str, object] = {}
        async with async_playwright() as playwright:
            for target in TARGETS:
                reports[target.slug] = await capture_target(
                    playwright,
                    target,
                    staging,
                )
            dark_section_reports = await capture_section_dark_contrast(
                playwright,
                staging,
            )
        return {
            "source": "Flutter visual-QA entrypoint with actual shared loading widgets",
            "baseUrl": BASE_URL,
            "targets": reports,
            "darkSectionContrast": dark_section_reports,
        }

    await capture_and_publish(
        output_dir=OUT,
        capture_to_staging=capture_to_staging,
    )


if __name__ == "__main__":
    asyncio.run(main())
