#!/usr/bin/env python3
"""Extract the original RAD bird mark from the official owner-supplied logo.

The official logo contains a bird body, a detached wing, and separate RAD
letterforms. This script keeps the two largest red connected components (the
body and wing), removes the letterforms, and writes a transparent solid-red
bird asset for small, high-quality loading motion.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/rad_official_logo.png"
TARGET = ROOT / "assets/branding/rad_bird_silhouette.png"
RAD_RED = (232, 12, 25, 255)
ALPHA_THRESHOLD = 24


def is_rad_red(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha > ALPHA_THRESHOLD and red > 90 and red > green * 1.5 and red > blue * 1.5


def connected_components(image: Image.Image) -> list[list[tuple[int, int]]]:
    width, height = image.size
    pixels = image.load()
    active = {
        (x, y)
        for y in range(height)
        for x in range(width)
        if is_rad_red(pixels[x, y])
    }
    components: list[list[tuple[int, int]]] = []

    while active:
        seed = active.pop()
        component = [seed]
        queue: deque[tuple[int, int]] = deque([seed])
        while queue:
            x, y = queue.popleft()
            for neighbor in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if neighbor in active:
                    active.remove(neighbor)
                    component.append(neighbor)
                    queue.append(neighbor)
        components.append(component)

    return sorted(components, key=len, reverse=True)


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    components = connected_components(source)
    if len(components) < 2:
        raise RuntimeError("The official logo did not expose separate RAD bird components.")

    bird_pixels = {pixel for component in components[:2] for pixel in component}
    min_x = min(x for x, _ in bird_pixels)
    min_y = min(y for _, y in bird_pixels)
    max_x = max(x for x, _ in bird_pixels)
    max_y = max(y for _, y in bird_pixels)
    padding = 10
    crop_width = max_x - min_x + 1 + padding * 2
    crop_height = max_y - min_y + 1 + padding * 2

    result = Image.new("RGBA", (crop_width, crop_height), (0, 0, 0, 0))
    result_pixels = result.load()
    for x, y in bird_pixels:
        result_pixels[x - min_x + padding, y - min_y + padding] = RAD_RED

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    result.save(TARGET, "PNG", optimize=True)
    print(f"Wrote {TARGET.relative_to(ROOT)} ({result.width}x{result.height})")


if __name__ == "__main__":
    main()
