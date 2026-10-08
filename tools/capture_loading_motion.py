#!/usr/bin/env python3
"""Capture the real RAD loader from the isolated Flutter visual-QA app."""

from __future__ import annotations

import asyncio
from pathlib import Path

from playwright.async_api import async_playwright

OUT = Path("docs/visual_qa")
FRAMES = OUT / "loading_motion_frames"
URL = "http://127.0.0.1:8084/?screen=loading&capture=1"


async def capture() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    FRAMES.mkdir(parents=True, exist_ok=True)
    for frame in FRAMES.glob("frame_*.png"):
        frame.unlink()

    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            executable_path="/usr/bin/chromium",
            headless=True,
            args=["--no-sandbox"],
        )
        desktop = await browser.new_page(
            viewport={"width": 1280, "height": 800}, device_scale_factor=1
        )
        await desktop.goto(URL, wait_until="networkidle", timeout=60000)
        await desktop.wait_for_timeout(1200)
        await desktop.screenshot(path=str(OUT / "loading_motion_desktop.png"))

        for index in range(24):
            await desktop.screenshot(path=str(FRAMES / f"frame_{index:03d}.png"))
            await desktop.wait_for_timeout(125)
        await desktop.close()

        mobile = await browser.new_page(
            viewport={"width": 390, "height": 844}, device_scale_factor=1
        )
        await mobile.goto(URL, wait_until="networkidle", timeout=60000)
        await mobile.wait_for_timeout(900)
        await mobile.screenshot(path=str(OUT / "loading_motion_mobile.png"))
        await mobile.close()
        await browser.close()


if __name__ == "__main__":
    asyncio.run(capture())
