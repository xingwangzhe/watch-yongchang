#!/usr/bin/env python3
"""Slice and audit image-model atlases without inventing or repainting pixels.

The source image must have a real transparent background for alpha cleanup to
be meaningful. This tool intentionally does not infer or remove checkerboards.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parent


def parse_size(value: str) -> tuple[int, int]:
    try:
        width, height = (int(part) for part in value.lower().split("x", 1))
    except (ValueError, TypeError) as error:
        raise argparse.ArgumentTypeError("size must be WIDTHxHEIGHT") from error
    if width < 1 or height < 1:
        raise argparse.ArgumentTypeError("size dimensions must be positive")
    return width, height


def cell_bounds(width: int, height: int, columns: int, rows: int, x: int, y: int) -> tuple[int, int, int, int]:
    return (
        round(x * width / columns),
        round(y * height / rows),
        round((x + 1) * width / columns),
        round((y + 1) * height / rows),
    )


def hard_alpha(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    rgba.putalpha(alpha)
    return rgba


def chroma_alpha(image: Image.Image, key: tuple[int, int, int], tolerance: int) -> Image.Image:
    """Remove an explicitly requested flat chroma key, never infer a background."""
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    kr, kg, kb = key
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, _a = pixels[x, y]
            distance = (r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2
            if distance <= tolerance * tolerance:
                pixels[x, y] = (r, g, b, 0)
            else:
                pixels[x, y] = (r, g, b, 255)
    return rgba


def fit_content(image: Image.Image, size: tuple[int, int], padding: int = 5, align_bottom: bool = True) -> Image.Image:
    """Fit visible generated content into a transparent frame without repainting."""
    bbox = image.getchannel("A").getbbox()
    result = Image.new("RGBA", size, (0, 0, 0, 0))
    if bbox is None:
        return result
    content = image.crop(bbox)
    max_w, max_h = max(1, size[0] - padding * 2), max(1, size[1] - padding * 2)
    scale = min(max_w / content.width, max_h / content.height)
    fitted = content.resize((max(1, round(content.width * scale)), max(1, round(content.height * scale))), Image.Resampling.NEAREST)
    x = (size[0] - fitted.width) // 2
    y = size[1] - padding - fitted.height if align_bottom else (size[1] - fitted.height) // 2
    result.alpha_composite(fitted, (x, y))
    return result


def bbox_or_none(image: Image.Image) -> list[int] | None:
    bbox = image.getchannel("A").getbbox()
    return list(bbox) if bbox else None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("asset", help="asset filename recorded in manifest.json")
    parser.add_argument("--output", type=Path, default=ROOT / "slices")
    parser.add_argument("--grid", type=parse_size, metavar="COLSxROWS", help="override manifest grid")
    parser.add_argument("--cell-size", type=parse_size, metavar="WIDTHxHEIGHT", help="nearest-neighbor output size")
    parser.add_argument("--alpha-threshold", type=int, metavar="0-255", help="hard-threshold existing alpha")
    parser.add_argument("--chroma-key", metavar="#RRGGBB", help="explicit flat key color to remove from generated RGB art")
    parser.add_argument("--key-tolerance", type=int, default=48, help="RGB distance tolerance for --chroma-key (default: 48)")
    parser.add_argument("--fit-content", action="store_true", help="crop visible content, preserve aspect ratio, and fit in output cell")
    parser.add_argument("--contact", type=Path, help="write a nearest-neighbor contact sheet")
    parser.add_argument("--report", type=Path, help="write cell/frame metrics as JSON")
    parser.add_argument("--frame-rows", action="store_true", help="measure adjacent-frame pixel difference per row")
    args = parser.parse_args()

    manifest = json.loads((ROOT / "manifest.json").read_text())
    entry = next((item for item in manifest["assets"] if item["file"] == args.asset), None)
    if entry is None:
        parser.error(f"{args.asset!r} is not listed in {ROOT / 'manifest.json'}")
    source = ROOT / entry["file"]
    if not source.exists():
        parser.error(f"source file is missing: {source}")
    image = Image.open(source).convert("RGBA")
    columns, rows = args.grid or tuple(entry["grid"])
    width, height = image.size
    args.output.mkdir(parents=True, exist_ok=True)
    output_size = args.cell_size
    cells: list[Image.Image] = []
    records: list[dict[str, object]] = []

    for row in range(rows):
        row_cells: list[Image.Image] = []
        for column in range(columns):
            bounds = cell_bounds(width, height, columns, rows, column, row)
            cell = image.crop(bounds)
            if args.chroma_key:
                try:
                    raw = args.chroma_key.lstrip("#")
                    key = tuple(int(raw[index:index + 2], 16) for index in (0, 2, 4))
                    if len(raw) != 6:
                        raise ValueError
                except ValueError:
                    parser.error("--chroma-key must be #RRGGBB")
                if not 0 <= args.key_tolerance <= 441:
                    parser.error("--key-tolerance must be between 0 and 441")
                cell = chroma_alpha(cell, key, args.key_tolerance)
            if args.alpha_threshold is not None:
                if not 0 <= args.alpha_threshold <= 255:
                    parser.error("--alpha-threshold must be between 0 and 255")
                cell = hard_alpha(cell, args.alpha_threshold)
            if output_size:
                cell = fit_content(cell, output_size) if args.fit_content else cell.resize(output_size, Image.Resampling.NEAREST)
            cell.save(args.output / f"{Path(args.asset).stem}_r{row:02d}_c{column:02d}.png")
            cells.append(cell)
            row_cells.append(cell)
            records.append({
                "row": row,
                "column": column,
                "source_bounds": list(bounds),
                "size": list(cell.size),
                "alpha_bbox": bbox_or_none(cell),
                "alpha_coverage": round(sum(cell.getchannel("A").get_flattened_data()) / (255 * cell.width * cell.height), 5),
            })
        if args.frame_rows:
            for column in range(1, columns):
                previous = row_cells[column - 1].convert("RGBA")
                current = row_cells[column].convert("RGBA")
                diff = ImageChops.difference(previous, current)
                changed = sum(1 for pixel in diff.get_flattened_data() if max(pixel) > 12)
                records[(row * columns) + column]["changed_fraction_from_previous"] = round(
                    changed / (previous.width * previous.height), 5
                )

    if args.contact:
        sample_w, sample_h = cells[0].size
        gap, label_h = 4, 18
        sheet = Image.new("RGBA", (columns * (sample_w + gap) + gap, rows * (sample_h + label_h + gap) + gap), (36, 42, 50, 255))
        draw = ImageDraw.Draw(sheet)
        for index, cell in enumerate(cells):
            row, column = divmod(index, columns)
            x, y = gap + column * (sample_w + gap), gap + row * (sample_h + label_h + gap)
            checker = Image.new("RGBA", cell.size, (0, 0, 0, 0))
            checker_draw = ImageDraw.Draw(checker)
            size = max(4, min(cell.size) // 8)
            for cy in range(0, cell.height, size):
                for cx in range(0, cell.width, size):
                    if (cx // size + cy // size) % 2 == 0:
                        checker_draw.rectangle((cx, cy, cx + size - 1, cy + size - 1), fill=(74, 79, 88, 255))
            sheet.alpha_composite(checker, (x, y))
            sheet.alpha_composite(cell, (x, y))
            draw.text((x, y + sample_h + 2), f"r{row:02d} c{column:02d}", fill=(235, 235, 235, 255))
        args.contact.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(args.contact)

    report = {
        "source": str(source),
        "source_size": [width, height],
        "grid": [columns, rows],
        "source_background": entry.get("background", "unspecified"),
        "alpha_threshold": args.alpha_threshold,
        "chroma_key": args.chroma_key,
        "key_tolerance": args.key_tolerance if args.chroma_key else None,
        "fit_content": args.fit_content,
        "output_size": list(output_size) if output_size else None,
        "frame_rows": args.frame_rows,
        "cells": records,
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(f"sliced {len(cells)} cells from {args.asset} ({columns}x{rows}); see per-cell alpha and motion metrics")


if __name__ == "__main__":
    main()
