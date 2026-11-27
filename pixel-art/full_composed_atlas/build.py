#!/usr/bin/env python3
"""Normalize generated full-character sheets into fixed-grid runtime atlases.

This pipeline crops whole frames only. It never cuts a character into body parts.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent / "source"
CLEAN = Path(__file__).resolve().parent / "clean"
GAME = ROOT / "game"
UNIT_OUT = GAME / "assets/units/full_sheets"
TILE_OUT = GAME / "assets/tiles/full_sheets"
FRAME = 128
ACTOR_ALPHA_THRESHOLD = 24
ACTOR_MIN_COMPONENT = 1800

ACTORS = {
    "player_actions": (8, 3, ["walk", "dao_attack", "spear_thrust"]),
    "allies_walk": (8, 4, ["spear", "shield", "archer", "banner"]),
    "enemies_walk": (8, 5, ["scout", "ronin", "shield", "gunner", "archer"]),
    "cavalry_walk": (8, 4, ["ming_lancer", "ming_archer", "wokou_saber", "wokou_heavy"]),
    "unit_attacks": (8, 8, [
        "ally_spear", "ally_shield", "ally_archer", "ally_banner",
        "enemy_ronin", "enemy_shield", "enemy_gunner", "enemy_archer",
    ]),
}

# Each entry maps an output row to a complete-character source row.
SOURCE_SHEETS = {
    "allies_walk": [("combined_complete_units.png", 0), ("combined_complete_units.png", 1), ("combined_complete_units.png", 2), ("combined_complete_units.png", 3)],
    "enemies_walk": [("enemies_walk.png", row) for row in range(5)],
}
SOURCE_COLUMNS = {"enemies_walk": 7}
COMBINED_ROW_BOUNDS = [
    (0, 166), (166, 320), (320, 478), (478, 638),
    (638, 800), (800, 960), (960, 1120), (1120, 1254),
]

# Attack art was generated with uneven row gaps. These bands retain each whole
# character frame without cutting boots or equipment at nominal equal-height lines.
CUSTOM_ROW_BOUNDS = {
    "unit_attacks": COMBINED_ROW_BOUNDS,
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def split_bounds(length: int, count: int, index: int) -> tuple[int, int]:
    return round(length * index / count), round(length * (index + 1) / count)


def checkerboard(size: tuple[int, int], cell_size: int = 8) -> Image.Image:
    image = Image.new("RGBA", size, (224, 224, 224, 255))
    pixels = image.load()
    for y in range(size[1]):
        for x in range(size[0]):
            if ((x // cell_size) + (y // cell_size)) % 2:
                pixels[x, y] = (176, 176, 176, 255)
    return image


def clear_transparent_rgb(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A")
    transparent = alpha.point(lambda value: 255 if value == 0 else 0)
    image.paste((0, 0, 0, 0), (0, 0), transparent)
    return image


def remove_small_components(alpha: Image.Image, minimum: int = 240) -> Image.Image:
    """Remove isolated model specks while preserving the whole connected sprite."""
    width, height = alpha.size
    source = alpha.load()
    visited = bytearray(width * height)
    result = Image.new("L", (width, height), 0)
    target = result.load()
    for y in range(height):
        for x in range(width):
            pos = y * width + x
            if visited[pos] or source[x, y] < ACTOR_ALPHA_THRESHOLD:
                continue
            stack = [(x, y)]
            visited[pos] = 1
            component: list[tuple[int, int]] = []
            while stack:
                cx, cy = stack.pop()
                component.append((cx, cy))
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    npos = ny * width + nx
                    if not visited[npos] and source[nx, ny] >= ACTOR_ALPHA_THRESHOLD:
                        visited[npos] = 1
                        stack.append((nx, ny))
            if len(component) >= minimum:
                for cx, cy in component:
                    target[cx, cy] = source[cx, cy]
    return result


def normalize_actor_sheet(key: str, columns: int, rows: int, row_names: list[str]) -> dict:
    source_rows = SOURCE_SHEETS.get(key, [(f"{key}.png", row) for row in range(rows)])
    frames: list[list[Image.Image]] = []
    row_bounds = CUSTOM_ROW_BOUNDS.get(key)
    for row in range(rows):
        source_name, source_row = source_rows[row]
        source = Image.open(SOURCE / source_name).convert("RGBA")
        source_columns = SOURCE_COLUMNS.get(key, columns)
        row_frames: list[Image.Image] = []
        for column in range(columns):
            source_column = column % source_columns
            x0, x1 = split_bounds(source.width, source_columns, source_column)
            if row_bounds:
                y0, y1 = row_bounds[row]
            elif source_name == "combined_complete_units.png":
                y0, y1 = COMBINED_ROW_BOUNDS[source_row]
            else:
                source_rows_count = ACTORS[key][1] if source_name == f"{key}.png" else 5
                y0, y1 = split_bounds(source.height, source_rows_count, source_row)
            cell = source.crop((x0, y0, x1, y1))
            alpha = remove_small_components(
                cell.getchannel("A"),
                500 if key == "cavalry_walk" else ACTOR_MIN_COMPONENT,
            )
            bounds = alpha.getbbox()
            if bounds is None:
                raise ValueError(f"Empty sprite frame: {key} row={row} column={column}")
            frame = cell.crop(bounds)
            frame.putalpha(alpha.crop(bounds))
            row_frames.append(frame)
        frames.append(row_frames)

    canvas = Image.new("RGBA", (columns * FRAME, rows * FRAME), (0, 0, 0, 0))
    placements: list[dict] = []
    for row, row_frames in enumerate(frames):
        max_width = max(frame.width for frame in row_frames)
        max_height = max(frame.height for frame in row_frames)
        scale = min((FRAME - 12) / max_width, (FRAME - 10) / max_height)
        for column, frame in enumerate(row_frames):
            size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
            normalized = frame.resize(size, Image.Resampling.LANCZOS)
            # Crisp one-pixel alpha keeps the generated silhouette intact at game scale.
            normalized.putalpha(normalized.getchannel("A"))
            normalized = clear_transparent_rgb(normalized)
            destination = (
                column * FRAME + (FRAME - size[0]) // 2,
                row * FRAME + FRAME - size[1] - 4,
            )
            canvas.alpha_composite(normalized, destination)
            placements.append({
                "row": row,
                "column": column,
                "row_name": row_names[row],
                "frame": column,
                "bbox": [destination[0], destination[1], size[0], size[1]],
                "source_bbox": list(frame.getbbox() or ()),
            })

    output_path = UNIT_OUT / f"{key}.webp"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output_path, "WEBP", lossless=True, method=6)
    preview = checkerboard(canvas.size)
    preview.alpha_composite(canvas)
    preview.save(CLEAN / f"{key}_checker.png", "PNG", optimize=True)
    source_files = sorted({SOURCE / name for name, _row in source_rows})
    return {
        "sources": [
            {"path": str(path.relative_to(ROOT)), "sha256": sha256(path)}
            for path in source_files
        ],
        "runtime": str(output_path.relative_to(GAME)),
        "runtime_sha256": sha256(output_path),
        "columns": columns,
        "rows": rows,
        "cell_size": [FRAME, FRAME],
        "row_names": row_names,
        "frames": placements,
        "source_mode": source.mode,
        "source_size": [source.width, source.height],
        "runtime_size": list(canvas.size),
        "runtime_bytes": output_path.stat().st_size,
    }


def normalize_tile(source: Image.Image, row: int, column: int, columns: int, rows: int) -> Image.Image:
    x0, x1 = split_bounds(source.width, columns, column)
    y0, y1 = split_bounds(source.height, rows, row)
    # Remove the generated atlas divider, then resample to the engine's 32px tile.
    tile = source.crop((x0 + 2, y0 + 2, x1 - 2, y1 - 2)).convert("RGB")
    return tile.resize((32, 32), Image.Resampling.LANCZOS).convert("RGBA")


def normalize_tiles() -> dict:
    source_path = SOURCE / "fort_atlas.png"
    source = Image.open(source_path).convert("RGB")
    terrain = Image.new("RGBA", (8 * 32, 5 * 32), (0, 0, 0, 0))
    architecture = Image.new("RGBA", (8 * 32, 6 * 32), (0, 0, 0, 0))
    generated: dict[str, object] = {}
    tile_index = json.loads((GAME / "data/yongchang_tiles.json").read_text(encoding="utf-8"))
    terrain_names = tile_index["atlases"]["terrain"]["tiles"]
    architecture_names = tile_index["atlases"]["architecture"]["tiles"]
    terrain_sources = {
        "wet_stone": (3, 2), "puddle": (4, 3),
        "shore_n": (4, 0), "shore_s": (4, 1),
        "shore_e": (4, 2), "shore_w": (4, 1),
        "shore_nw": (4, 0), "shore_ne": (4, 2),
        "shore_sw": (4, 1), "shore_se": (4, 2),
        "stone_road_a": (3, 2), "stone_road_b": (3, 3),
        "earth_road_a": (0, 0), "earth_road_b": (1, 0),
        "dock_vertical": (3, 6), "dock_horizontal": (3, 5),
        "driftwood": (4, 5),
    }

    # Mountain slots must use dry rock cells. The generated source places its
    # shoreline and water in row 4 columns 0-3, so those cells are never used
    # for blocked terrain even though the previous row-major crop did so.
    mountain_sources = [(4, 4), (4, 5), (4, 6), (4, 7), (3, 0), (3, 1), (3, 2), (3, 3)]
    for index, name in enumerate(terrain_names):
        row, column = divmod(index, 8)
        if name in terrain_sources:
            row, column = terrain_sources[name]
        elif name.startswith("mountain_"):
            row, column = mountain_sources[ord(name[-1]) - ord("a")]
        tile = normalize_tile(source, row, column, 8, 16)
        if name == "dock_horizontal":
            _match_tile_edges(tile, "horizontal")
        elif name == "dock_vertical":
            _match_tile_edges(tile, "vertical")
        terrain.alpha_composite(tile, ((index % 8) * 32, (index // 8) * 32))

    # Explicit source cells keep the runtime tile names aligned with what the
    # source actually depicts. A full scene is not a row-major semantic atlas.
    architecture_sources = {
        "plaster_plain": (6, 4), "plaster_window": (6, 5),
        "plaster_door": (6, 7), "plaster_damaged": (6, 0),
        "roof_ridge": (7, 2), "roof_slope": (7, 0),
        "roof_eave": (6, 4), "roof_corner": (7, 7),
        "land_gate_left": (8, 0), "land_gate_arch": (8, 1),
        "land_gate_right": (8, 2), "water_gate_left": (8, 3),
        "water_gate_arch": (8, 4), "water_gate_right": (8, 5),
        "wood_railing": (9, 4), "wood_railing_vertical": (9, 4),
        "stone_steps": (9, 7), "plaster_door_b": (6, 7),
        "red_lantern": (9, 1), "storefront": (9, 0),
        "gable_left": (7, 3), "gable_right": (7, 3),
        "roof_slope_b": (7, 1), "roof_slope_c": (7, 3),
        "roof_eave_b": (6, 5), "roof_eave_door": (6, 7),
        "hall_roof_ridge": (7, 4), "hall_roof_slope": (7, 5),
        "hall_roof_eave": (9, 3), "hall_roof_corner": (7, 6),
        "roof_verge": (7, 0), "roof_hip_left": (7, 2),
        "roof_hip_right": (7, 2), "hall_roof_verge": (7, 1),
        "hall_roof_hip_left": (7, 5), "hall_roof_hip_right": (7, 5),
        "roof_eave_shop": (9, 0), "roof_verge_b": (7, 3),
    }
    for index, name in enumerate(architecture_names):
        if name in architecture_sources:
            row, column = architecture_sources[name]
        else:
            # The first eight slots are the source wall row. The remaining
            # unmatched wall variants stay on that same coherent wall family.
            row, column = (5, index % 8) if index < 8 or name.startswith(("stone_wall", "arrow_slit", "wall_", "merlon")) else (8, index % 8)
        tile = normalize_tile(source, row, column, 8, 16)
        if name in {"roof_hip_right", "hall_roof_hip_right", "gable_right"}:
            tile = tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if name == "wood_railing":
            _match_tile_edges(tile, "horizontal")
        elif name == "wood_railing_vertical":
            tile = tile.transpose(Image.Transpose.ROTATE_90)
            _match_tile_edges(tile, "vertical")
        architecture.alpha_composite(tile, ((index % 8) * 32, (index // 8) * 32))

    # Static transparent props come from their dedicated 8x3 source atlas.
    props_source_path = SOURCE / "props.png"
    props_source = Image.open(props_source_path).convert("RGBA")
    props = Image.new("RGBA", (8 * 32, 3 * 32), (0, 0, 0, 0))
    for row in range(3):
        for column in range(8):
            x0, x1 = split_bounds(props_source.width, 8, column)
            y0, y1 = split_bounds(props_source.height, 3, row)
            cell = props_source.crop((x0, y0, x1, y1))
            alpha = remove_small_components(cell.getchannel("A"))
            bounds = alpha.getbbox()
            if bounds is None:
                continue
            cutout = cell.crop(bounds)
            cutout.putalpha(alpha.crop(bounds))
            scale = min(30 / cutout.width, 30 / cutout.height)
            size = (max(1, round(cutout.width * scale)), max(1, round(cutout.height * scale)))
            cutout = cutout.resize(size, Image.Resampling.LANCZOS)
            cutout.putalpha(cutout.getchannel("A"))
            cutout = clear_transparent_rgb(cutout)
            props.alpha_composite(cutout, (column * 32 + (32 - size[0]) // 2, row * 32 + 31 - size[1]))

    # Reorder 4-frame prop loops into a 4x4 atlas: reeds, beacon, banner, water.
    animated = Image.new("RGBA", (4 * 32, 4 * 32), (0, 0, 0, 0))
    animation_order = [(14, x) for x in range(4)] + [(14, x) for x in range(4, 8)]
    animation_order += [(15, x) for x in range(4)] + [(15, x) for x in range(4, 8)]
    for index, (row, column) in enumerate(animation_order):
        tile = normalize_tile(source, row, column, 8, 16)
        cell = tile.resize((32, 32), Image.Resampling.LANCZOS)
        animated.alpha_composite(cell, ((index % 4) * 32, (index // 4) * 32))

    for name, image in (("terrain_atlas", terrain), ("architecture_atlas", architecture), ("props_atlas", props), ("animated_props", animated)):
        png_path = TILE_OUT / f"{name}.png"
        TILE_OUT.mkdir(parents=True, exist_ok=True)
        image.save(png_path, "PNG", optimize=True)
        preview = checkerboard(image.size, 4 if image.width <= 256 else 8)
        preview.alpha_composite(image)
        preview.save(CLEAN / f"{name}_checker.png", "PNG", optimize=True)
        generated[name] = {
            "png": str(png_path.relative_to(GAME)),
            "size": list(image.size),
            "bytes": png_path.stat().st_size,
        }
    return {
        "source": str(source_path.relative_to(ROOT)),
        "source_sha256": sha256(source_path),
        "tile_size": 32,
        "atlas_source_grid": [8, 16],
        "atlases": generated,
    }


def _match_tile_edges(tile: Image.Image, axis: str) -> None:
    """Make only the opposite seam pixels identical for repeating bridge cells."""
    pixels = tile.load()
    if axis == "horizontal":
        for y in range(tile.height):
            pixels[tile.width - 1, y] = pixels[0, y]
    else:
        for x in range(tile.width):
            pixels[x, tile.height - 1] = pixels[x, 0]


def main() -> None:
    CLEAN.mkdir(parents=True, exist_ok=True)
    UNIT_OUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "source": "OpenAI ImageGen; complete full-character and map-category atlases",
        "license": "CC BY 4.0",
        "author": "xingwangzhe",
        "character_sheets": {
            key: normalize_actor_sheet(key, columns, rows, names)
            for key, (columns, rows, names) in ACTORS.items()
        },
        "tile_sheets": normalize_tiles(),
    }
    report_path = CLEAN / "manifest.json"
    report_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"built {len(ACTORS)} complete-character sheets and 4 tile atlases: {report_path}")


if __name__ == "__main__":
    main()
