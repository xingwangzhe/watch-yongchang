#!/usr/bin/env python3
"""Build QA-only ground attack composites from separate body/clothing cells.

This script never adds weapons, shields, or other gear. Outputs are reference
contacts for visual review and are not formal runtime sprites.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
SLICES = ROOT / "slices_v3"
DEFAULT_OUTPUT = Path("/tmp/yongchang-ground-attack-qa")
CELL = 128
ROWS = 5
COLUMNS = 6
FACTIONS = {
    "ming": "ming_ground_attack_clothing_overlay_v1_source.png",
    "wokou": "wokou_ground_attack_clothing_overlay_v1_source.png",
}
BODY_SOURCE = "ground_attack_bodies_v3_source.png"
KEY_RGB = (0, 255, 0)
KEY_TOLERANCE = 210


def slice_sheet(source_name: str, prefix: str, output: Path) -> list[Image.Image]:
    """Slice a 6x5 green-key source atlas into registered 128px cells."""
    source_path = ROOT / source_name
    if not source_path.is_file():
        raise FileNotFoundError(f"missing ImageGen source sheet: {source_path}")
    with Image.open(source_path) as source_file:
        source = source_file.convert("RGBA")
    cells: list[Image.Image] = []
    output.mkdir(parents=True, exist_ok=True)
    for row in range(ROWS):
        for column in range(COLUMNS):
            bounds = (
                round(column * source.width / COLUMNS),
                round(row * source.height / ROWS),
                round((column + 1) * source.width / COLUMNS),
                round((row + 1) * source.height / ROWS),
            )
            image = source.crop(bounds)
            pixels = image.load()
            kr, kg, kb = KEY_RGB
            for y in range(image.height):
                for x in range(image.width):
                    red, green, blue, _alpha = pixels[x, y]
                    distance_sq = (red - kr) ** 2 + (green - kg) ** 2 + (blue - kb) ** 2
                    pixels[x, y] = (red, green, blue, 0 if distance_sq <= KEY_TOLERANCE ** 2 else 255)
            image = image.resize((CELL, CELL), Image.Resampling.NEAREST)
            if image.size != (CELL, CELL):
                raise ValueError(f"{source_name} produced {image.size}, expected {(CELL, CELL)}")
            image.save(output / f"{prefix}_r{row:02d}_c{column:02d}.png")
            cells.append(image)
    return cells


def composite(body: Image.Image, clothing: Image.Image) -> Image.Image:
    """Keep both generated layers in their shared 128px action-pose canvas."""
    result = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    result.alpha_composite(body)
    result.alpha_composite(clothing)
    return result


def changed_fraction(first: Image.Image, second: Image.Image) -> float:
    a = first.get_flattened_data()
    b = second.get_flattened_data()
    changed = sum(
        1 for p, q in zip(a, b)
        if max(abs(p[channel] - q[channel]) for channel in range(4)) > 12
    )
    return round(changed / (CELL * CELL), 5)


def contact_sheet(faction: str, frames: list[Image.Image], target: Path) -> None:
    gap, label_height = 12, 24
    sheet_width = COLUMNS * CELL + (COLUMNS + 1) * gap
    sheet_height = ROWS * (CELL + label_height) + (ROWS + 1) * gap
    sheet = Image.new("RGBA", (sheet_width, sheet_height), (28, 33, 39, 255))
    draw = ImageDraw.Draw(sheet)
    for row in range(ROWS):
        y = gap + row * (CELL + label_height + gap)
        draw.text((gap, y + CELL + 4), f"{faction} action row {row}", fill=(240, 230, 207, 255))
        for column in range(COLUMNS):
            x = gap + column * (CELL + gap)
            # Checkerboard only belongs to the QA presentation background.
            for cy in range(0, CELL, 16):
                for cx in range(0, CELL, 16):
                    tone = (61, 67, 75, 255) if (cx // 16 + cy // 16) % 2 == 0 else (43, 48, 55, 255)
                    draw.rectangle((x + cx, y + cy, x + cx + 15, y + cy + 15), fill=tone)
            sheet.alpha_composite(frames[row * COLUMNS + column], (x, y))
    sheet.save(target)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    body_cells = slice_sheet(BODY_SOURCE, "body", args.output / "slices" / "body")
    report: dict[str, object] = {
        "purpose": "QA only; no weapons, shields, or runtime assets are produced",
        "grid": {"columns": COLUMNS, "rows": ROWS, "cell": [CELL, CELL]},
        "action_rows": [
            {"row": row, "semantic_label": "unmapped pose family; do not assign runtime action yet"}
            for row in range(ROWS)
        ],
        "factions": {},
    }
    for faction, prefix in FACTIONS.items():
        clothing = slice_sheet(prefix, "clothing", args.output / "slices" / faction)
        frames = [composite(body, garment) for body, garment in zip(body_cells, clothing)]
        output = args.output / f"{faction}_ground_attack_contact.png"
        contact_sheet(faction, frames, output)
        rows = []
        for row in range(ROWS):
            row_frames = frames[row * COLUMNS:(row + 1) * COLUMNS]
            boxes = [image.getchannel("A").getbbox() for image in row_frames]
            deltas = [changed_fraction(row_frames[index - 1], row_frames[index]) for index in range(1, COLUMNS)]
            rows.append({"row": row, "frame_alpha_bounds": boxes, "adjacent_changed_fraction": deltas})
        report["factions"][faction] = {
            "clothing_source": prefix,
            "clothing_slices": str(args.output / "slices" / faction),
            "contact_sheet": str(output),
            "frame_count": len(frames),
            "rows": rows,
        }
    source_hashes = {}
    for name in (BODY_SOURCE, *FACTIONS.values()):
        source_hashes[name] = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
    report["source_sha256"] = source_hashes
    report_path = args.output / "ground_attack_qa_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote QA contacts and frame report to {args.output}")


if __name__ == "__main__":
    main()
