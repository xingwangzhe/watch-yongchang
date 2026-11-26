#!/usr/bin/env python3
"""Bake all legal enemy walk strips into one deterministic runtime atlas."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
CATALOG = GAME / "data/enemy_variants.json"
OUT = GAME / "assets/units/forge/enemy_variant_atlas.png"
MANIFEST = GAME / "data/enemy_variant_atlas.json"
PREVIEW = Path(__file__).with_name("enemy_variant_atlas_preview.png")
CELL = 128
FRAMES = 8
COLUMNS = 36
ROWS = 32


def main() -> None:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    strips = [
        variant
        for enemy_id in sorted(catalog["variants"])
        for variant in sorted(catalog["variants"][enemy_id], key=lambda item: item["draw_id"])
    ]
    if len(strips) != 144:
        raise ValueError(f"expected 144 enemy variants, got {len(strips)}")

    atlas = Image.new("RGBA", (COLUMNS * CELL, ROWS * CELL), (0, 0, 0, 0))
    entries: dict[str, dict[str, int | str]] = {}
    for variant_index, variant in enumerate(strips):
        source_path = GAME / variant["texture"].removeprefix("res://")
        source_path = source_path.with_suffix(".png")
        strip = Image.open(source_path).convert("RGBA")
        if strip.size != (CELL * FRAMES, CELL):
            raise ValueError(f"{source_path}: expected {(CELL * FRAMES, CELL)}, got {strip.size}")
        first_cell = variant_index * FRAMES
        for frame in range(FRAMES):
            cell = first_cell + frame
            x = cell % COLUMNS * CELL
            y = cell // COLUMNS * CELL
            atlas.paste(strip.crop((frame * CELL, 0, (frame + 1) * CELL, CELL)), (x, y))
        entries[variant["draw_id"]] = {
            "first_cell": first_cell,
            "frames": FRAMES,
            "fps": int(variant.get("fps", 10)),
        }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT, optimize=True)
    manifest = {
        "version": 1,
        "texture": "res://assets/units/forge/enemy_variant_atlas.webp",
        "source": "pixel-art/character_forge/bake_enemy_variant_atlas.py",
        "cell_size": CELL,
        "columns": COLUMNS,
        "rows": ROWS,
        "atlas_size": [COLUMNS * CELL, ROWS * CELL],
        "frames": FRAMES,
        "variant_count": len(entries),
        "variants": entries,
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    preview = atlas.resize((COLUMNS * 32, ROWS * 32), Image.Resampling.NEAREST)
    draw = ImageDraw.Draw(preview)
    for index in range(len(strips)):
        cell = index * FRAMES
        x = cell % COLUMNS
        y = cell // COLUMNS
        draw.rectangle((x * 32, y * 32, min(COLUMNS * 32 - 1, (x + FRAMES) * 32 - 1), y * 32 + 31), outline=(212, 170, 89, 255))
    preview.save(PREVIEW, optimize=True)
    print(f"variants={len(entries)} frames={len(entries) * FRAMES} atlas={atlas.size} output={OUT}")


if __name__ == "__main__":
    main()
