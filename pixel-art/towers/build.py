#!/usr/bin/env python3
"""Slice and export ImageGen arrow-tower sprites without drawing pixels."""
from __future__ import annotations

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "pixel-art/model_redraw/slices_v3/arrow_towers_v1"
OUT = ROOT / "game/assets/units/towers"
PREVIEW = ROOT / "pixel-art/towers/preview.png"
SIZE = (168, 168)
TOWERS = {
    "watchtower": "arrow_towers_v1_source_r00_c00.png",
    "arrow_tower": "arrow_towers_v1_source_r00_c01.png",
    "dragon_tower": "arrow_towers_v1_source_r00_c02.png",
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sprites: list[Image.Image] = []
    for name, filename in TOWERS.items():
        image = Image.open(SOURCE / filename).convert("RGBA")
        image.thumbnail(SIZE, Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        canvas.alpha_composite(image, ((SIZE[0] - image.width) // 2,
                                       SIZE[1] - image.height))
        canvas.save(OUT / f"{name}.png")
        sprites.append(canvas)
        print(f"sliced {filename} -> game/assets/units/towers/{name}.png")
    pad = 10
    sheet = Image.new("RGBA", (SIZE[0] * len(sprites) + pad * (len(sprites) + 1),
                                SIZE[1] + pad * 2), (20, 24, 30, 255))
    for index, sprite in enumerate(sprites):
        sheet.alpha_composite(sprite, (pad + index * (SIZE[0] + pad), pad))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.Resampling.NEAREST).save(PREVIEW)
    print(f"wrote {PREVIEW}")


if __name__ == "__main__":
    main()
