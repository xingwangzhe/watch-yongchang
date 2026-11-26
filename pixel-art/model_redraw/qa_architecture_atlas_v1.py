#!/usr/bin/env python3
"""Slice and audit generated architecture art; never draws or edits art pixels."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[1]
SOURCE = ROOT / "architecture_atlas_model_v1_source.png"
OUTPUT = Path("/tmp/yongchang-architecture-qa")
ATLAS = PROJECT / "game" / "data" / "yongchang_tiles.json"
PREVIOUS_ATLAS = PROJECT / "game" / "assets" / "tiles" / "yongchang" / "architecture_atlas.png"
COLS = 8
ROWS = 6
TILE = 32
ALPHA_THRESHOLD = 128
SEAM_TILES = (
    "stone_wall_a",
    "stone_wall_moss",
    "wall_water_base",
    "roof_slope",
    "roof_slope_b",
    "hall_roof_slope",
)


def harden_alpha(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    image.putalpha(image.getchannel("A").point(
        lambda alpha: 255 if alpha >= ALPHA_THRESHOLD else 0
    ))
    return image


def edge_mismatch(a: Image.Image, b: Image.Image) -> dict[str, float | int]:
    pa = list(a.convert("RGBA").getdata())
    pb = list(b.convert("RGBA").getdata())
    deltas = [max(abs(x - y) for x, y in zip(ca, cb)) for ca, cb in zip(pa, pb)]
    return {
        "pixels": len(deltas),
        "mismatch_pixels_gt_32": sum(delta > 32 for delta in deltas),
        "mean_channel_max_delta": round(sum(deltas) / max(1, len(deltas)), 2),
    }


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGBA")
    if source.width % COLS or source.height % ROWS:
        raise ValueError(f"source {source.size} is not divisible by {COLS}x{ROWS}")
    cell_w, cell_h = source.width // COLS, source.height // ROWS
    if cell_w != cell_h:
        raise ValueError(f"source cells are not square: {cell_w}x{cell_h}")

    tile_index = json.loads(ATLAS.read_text(encoding="utf-8"))
    architecture = tile_index["atlases"]["architecture"]
    tile_names = architecture["tiles"]
    if len(tile_names) != COLS * ROWS:
        raise ValueError(f"expected {COLS * ROWS} tile names, got {len(tile_names)}")

    result = Image.new("RGBA", (COLS * TILE, ROWS * TILE), (0, 0, 0, 0))
    frames: dict[str, Image.Image] = {}
    cell_reports = []
    for index, name in enumerate(tile_names):
        row, col = divmod(index, COLS)
        crop = source.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
        clean = harden_alpha(crop)
        bbox = clean.getchannel("A").getbbox()
        normalized = clean.resize((TILE, TILE), Image.Resampling.NEAREST)
        result.alpha_composite(normalized, (col * TILE, row * TILE))
        frames[name] = normalized
        cell_reports.append({
            "index": index,
            "name": name,
            "row": row,
            "column": col,
            "source_cell": [cell_w, cell_h],
            "alpha_bbox_at_threshold": list(bbox) if bbox else None,
            "touches_cell_edge": bool(bbox and (
                bbox[0] == 0 or bbox[1] == 0 or bbox[2] == cell_w or bbox[3] == cell_h
            )),
            "empty": bbox is None,
        })

    # Keep the existing vertical bridge railing because gameplay art tests require its
    # north/south coverage to join exactly. This is atlas assembly, not pixel drawing.
    previous_atlas = Image.open(PREVIOUS_ATLAS).convert("RGBA")
    preserved_tiles = {"wood_railing_vertical"}
    for index, name in enumerate(tile_names):
        if name not in preserved_tiles:
            continue
        row, col = divmod(index, COLS)
        original = previous_atlas.crop(
            (col * TILE, row * TILE, (col + 1) * TILE, (row + 1) * TILE)
        )
        result.paste(original, (col * TILE, row * TILE))
        frames[name] = original

    resource_path = str(architecture["path"])
    if not resource_path.startswith("res://"):
        raise ValueError(f"architecture atlas must use res:// path, got {resource_path}")
    atlas_path = PROJECT / "game" / resource_path.removeprefix("res://")
    atlas_path.parent.mkdir(parents=True, exist_ok=True)
    result.save(atlas_path, optimize=True)
    preview = result.resize((COLS * 128, ROWS * 128), Image.Resampling.NEAREST)
    preview.save(OUTPUT / "architecture_atlas_contact.png", optimize=True)

    repeats = Image.new("RGBA", (TILE * 3 * 3, TILE * 3 * 2), (16, 20, 26, 255))
    seam_reports = []
    for i, name in enumerate(SEAM_TILES):
        tile = frames[name]
        left, right = tile.crop((0, 0, 1, TILE)), tile.crop((TILE - 1, 0, TILE, TILE))
        top, bottom = tile.crop((0, 0, TILE, 1)), tile.crop((0, TILE - 1, TILE, TILE))
        seam_reports.append({
            "name": name,
            "horizontal": edge_mismatch(right, left),
            "vertical": edge_mismatch(bottom, top),
        })
        x0, y0 = (i % 3) * TILE * 3, (i // 3) * TILE * 3
        for y in range(3):
            for x in range(3):
                repeats.alpha_composite(tile, (x0 + x * TILE, y0 + y * TILE))
    repeats.resize((repeats.width * 4, repeats.height * 4), Image.Resampling.NEAREST).save(
        OUTPUT / "architecture_3x3_seam_contact.png", optimize=True
    )

    report = {
        "source": str(SOURCE.relative_to(PROJECT)),
        "source_size": list(source.size),
        "grid": [COLS, ROWS],
        "source_cell_size": [cell_w, cell_h],
        "derived_tile_size": [TILE, TILE],
        "alpha_threshold": ALPHA_THRESHOLD,
        "atlas": str(atlas_path),
        "tile_count": len(cell_reports),
        "empty_tiles": [item["name"] for item in cell_reports if item["empty"]],
        "cells_touching_edges": [item["name"] for item in cell_reports if item["touches_cell_edge"]],
        "seam_tests": seam_reports,
        "preserved_from_previous_atlas": sorted(preserved_tiles),
        "runtime_integrated": atlas_path.is_file(),
        "cells": cell_reports,
    }
    (OUTPUT / "architecture_atlas_model_v1_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({
        "atlas": str(atlas_path),
        "contact": str(OUTPUT / "architecture_atlas_contact.png"),
        "repeat_contact": str(OUTPUT / "architecture_3x3_seam_contact.png"),
        "report": str(OUTPUT / "architecture_atlas_model_v1_report.json"),
        "source_cell": [cell_w, cell_h],
        "tiles": len(cell_reports),
        "empty": report["empty_tiles"],
        "edge_touching": report["cells_touching_edges"],
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
