#!/usr/bin/env python3
"""Crop model-generated atlas cells using manifest grid metadata.

The tool preserves source pixels and does not claim that generated backgrounds
are transparent or that inferred cells are production-ready.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("asset", help="manifest file key, for example weapons_implements.png")
    parser.add_argument("--output", type=Path, default=ROOT / "slices")
    args = parser.parse_args()

    manifest = json.loads((ROOT / "manifest.json").read_text())
    asset = next(item for item in manifest["assets"] if item["file"] == args.asset)
    source_path = ROOT / asset["file"]
    image = Image.open(source_path).convert("RGBA")
    columns, rows = asset["grid"]
    width, height = image.size
    args.output.mkdir(parents=True, exist_ok=True)
    for row in range(rows):
        for column in range(columns):
            left = round(column * width / columns)
            right = round((column + 1) * width / columns)
            top = round(row * height / rows)
            bottom = round((row + 1) * height / rows)
            image.crop((left, top, right, bottom)).save(
                args.output / f"{Path(args.asset).stem}_r{row:02d}_c{column:02d}.png"
            )
    print(f"cropped {rows * columns} cells from {args.asset}; source background retained")


if __name__ == "__main__":
    main()
