#!/usr/bin/env python3
"""Capture the real production Login Earth-and-bird scene with Chromium.

The production Flutter web build must already be served locally. This script
never enters credentials, triggers auth actions, or captures customer data.
"""

from __future__ import annotations

import asyncio
import json
import os
import shutil
import subprocess
import time
from pathlib import Path

from playwright.async_api import ConsoleMessage, Page, async_playwright

OUT = Path("docs/visual_qa")
RECORDING_DIR = OUT / "login_earth_bird_recording_tmp"
RAW_VIDEO = OUT / "login_earth_bird_orbit.webm"
FINAL_VIDEO = OUT / "login_earth_bird_orbit.mp4"
FINAL_GIF = OUT / "login_earth_bird_orbit.gif"
URL = os.environ.get("RAD_CAPTURE_URL", "http://127.0.0.1:8086/#/login")
ORBIT_CAPTURE_SECONDS = 14
FOREGROUND_SETTLE_MS = 4200


def attach_console_capture(page: Page, messages: list[dict[str, str]]) -> None:
    def record(message: ConsoleMessage) -> None:
        messages.append({"type": message.type, "text": message.text})

    page.on("console", record)


def media_duration_seconds(path: Path) -> float:
    result = subprocess.run(
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
    return float(result.stdout.strip())


def render_final_orbit(capture_seconds: float) -> tuple[float, float]:
    raw_duration = media_duration_seconds(RAW_VIDEO)
    trim_start = max(0.0, raw_duration - capture_seconds)
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(RAW_VIDEO),
            "-ss",
            f"{trim_start:.3f}",
            "-t",
            f"{capture_seconds:.3f}",
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-movflags",
            "+faststart",
            str(FINAL_VIDEO),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(FINAL_VIDEO),
            "-vf",
            (
                "fps=10,scale=720:-2:flags=lanczos,"
                "split[s0][s1];[s0]palettegen=max_colors=128[p];"
                "[s1][p]paletteuse=dither=bayer"
            ),
            "-loop",
            "0",
            str(FINAL_GIF),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return raw_duration, trim_start


async def capture() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.rmtree(RECORDING_DIR, ignore_errors=True)
    RECORDING_DIR.mkdir(parents=True, exist_ok=True)
    RAW_VIDEO.unlink(missing_ok=True)

    console_messages: list[dict[str, str]] = []
    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            executable_path="/usr/bin/chromium",
            headless=True,
            args=["--no-sandbox"],
        )

        desktop_context = await browser.new_context(
            viewport={"width": 1280, "height": 800},
            device_scale_factor=1,
            record_video_dir=str(RECORDING_DIR),
            record_video_size={"width": 1280, "height": 800},
        )
        desktop = await desktop_context.new_page()
        attach_console_capture(desktop, console_messages)
        await desktop.goto(URL, wait_until="networkidle", timeout=60000)
        await desktop.wait_for_timeout(FOREGROUND_SETTLE_MS)
        await desktop.screenshot(path=str(OUT / "login_earth_bird_desktop.png"))

        video = desktop.video
        assert video is not None
        capture_started = time.monotonic()
        await desktop.wait_for_timeout(ORBIT_CAPTURE_SECONDS * 1000)
        capture_seconds = time.monotonic() - capture_started
        await desktop.close()
        await desktop_context.close()
        await video.save_as(str(RAW_VIDEO))

        mobile_context = await browser.new_context(
            viewport={"width": 390, "height": 844},
            device_scale_factor=1,
        )
        mobile = await mobile_context.new_page()
        attach_console_capture(mobile, console_messages)
        await mobile.goto(URL, wait_until="networkidle", timeout=60000)
        await mobile.wait_for_timeout(FOREGROUND_SETTLE_MS)
        await mobile.screenshot(path=str(OUT / "login_earth_bird_mobile.png"))
        await mobile_context.close()
        await browser.close()

    raw_duration, trim_start = render_final_orbit(capture_seconds)
    RAW_VIDEO.unlink(missing_ok=True)
    shutil.rmtree(RECORDING_DIR, ignore_errors=True)

    report = {
        "source": "production Flutter web entrypoint",
        "url": URL,
        "desktopViewport": "1280x800",
        "mobileViewport": "390x844",
        "captureSeconds": capture_seconds,
        "rawRecordingSeconds": raw_duration,
        "trimStartSeconds": trim_start,
        "console": console_messages,
    }
    (OUT / "login_earth_bird_capture_report.json").write_text(
        json.dumps(report, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    asyncio.run(capture())
