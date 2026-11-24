#!/usr/bin/env python3
"""Reproducible Ming-inspired gameplay cursor for WATCH · YONGCHANG.

Original artwork by the WATCH · YONGCHANG project, licensed CC BY 4.0.
Run from the repository root:
    python3 pixel-art/watch_cursor/build.py

The exported PNG is a build artifact: edit this source instead of the PNG.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "skills" / "pixel-art-studio" / "scripts"))

from pixelstudio import Sprite  # noqa: E402


# Four-color lacquer/paper palette. The hotspot is the top ink pixel at (3, 0).
INK = "#201914"
GOLD = "#d9a84e"
VERMILION = "#b84e38"
PAPER = "#f2e2b9"

ARROW = [
    (3, 2), (20, 13), (14, 14), (17, 21), (13, 23),
    (10, 16), (5, 21),
]
PAPER_FACE = [
    (5, 5), (17, 13), (13, 14), (15, 19), (13, 20),
    (11, 15), (7, 18),
]


def build() -> Sprite:
    cursor = Sprite(24, 24, palette=[INK, GOLD, VERMILION, PAPER])
    cursor.polygon(ARROW, GOLD)
    # A two-pixel ink edge remains legible on both terrain and dark HUD panels.
    cursor.outline(INK, where="outside")
    cursor.outline(INK, where="outside")
    cursor.polygon(PAPER_FACE, PAPER)
    # One short vermilion inlay echoes Ming lacquer without adding visual noise.
    cursor.polygon([(6, 6), (8, 8), (7, 9)], VERMILION)
    return cursor


def main() -> None:
    source = Path(__file__).resolve().parent
    cursor = build()
    cursor.save_png(ROOT / "game" / "assets" / "ui" / "watch_cursor.png")
    cursor.save_png(source / "preview_8x.png", scale=8)
    cursor.preview(source / "preview_checker.png", scale=8, grid=True, labels=False)
    cursor.save_silhouette(source / "silhouette.png", scale=8)
    cursor.stats()


if __name__ == "__main__":
    main()
