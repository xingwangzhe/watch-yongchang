#!/usr/bin/env python3
"""Crop the four complete ImageGen references; no repainting or pixel edits."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "full_sprite_concepts_v2.png"
OUTPUT = ROOT / "full_sprite_references"
NAMES = ("ming_infantry", "wokou_infantry", "ming_standard_bearer", "ming_cavalry")


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    width, height = image.size
    split_x, split_y = width // 2, height // 2
    bounds = (
        (0, 0, split_x, split_y),
        (split_x, 0, width, split_y),
        (0, split_y, split_x, height),
        (split_x, split_y, width, height),
    )
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, box in zip(NAMES, bounds, strict=True):
        crop = image.crop(box)
        alpha_box = crop.getchannel("A").point(
            lambda alpha: 255 if alpha >= 128 else 0
        ).getbbox()
        if alpha_box is None:
            raise ValueError(f"empty reference cell: {name}")
        crop.crop(alpha_box).save(OUTPUT / f"{name}.png", optimize=True)
        print(f"{name}: {alpha_box}")


if __name__ == "__main__":
    main()
