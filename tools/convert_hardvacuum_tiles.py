#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Convert Hard Vacuum (CC BY 3.0) Amiga tilesets into 32x32 RGBA PNG tiles.

Source: https://lostgardenhome.files.wordpress.com/2019/09/hardvacuum.zip
Author: Mark Ferrari (Lost Garden), CC BY 3.0
Usage: python tools/convert_hardvacuum_tiles.py
"""
import os
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/third_party/hardvacuum/Hard Vacuum/Terrain Tiles"
OUT = ROOT / "game/assets/tiles/hardvacuum"
CHROMA = (0, 138, 118)
TOL = 40
TILE = 32          # 输出尺寸（Godot 瓦片大小）
SRC_TILE = 20      # 源图集真实瓦片边长（Amiga 20x20）
SRC_STEP = 40      # 源图集瓦片步长（含 20px 透明间隔）
SRC_COLS = [(0, 20), (40, 59), (80, 99)]

# 类别 → 源图 → 输出前缀 → 调色映射（古代地质感：灰岩/土黄/青苔/暗红）
# 调色：把源图的亮度映射到国风地质色带（低→高）
CATEGORIES = {
    "ground": [
        ("Grass.bmp", "moss", [(28, 38, 30), (52, 68, 46), (86, 100, 62), (120, 128, 82)]),
        ("Sand.bmp", "sand", [(64, 52, 36), (110, 88, 56), (158, 130, 84), (198, 168, 116)]),
    ],
    "road": [
        ("Road.bmp", "road", [(48, 40, 30), (88, 72, 50), (132, 108, 72), (172, 144, 100)]),
        ("MntRoad.bmp", "road_rock", [(44, 44, 42), (80, 78, 72), (120, 116, 104), (160, 154, 138)]),
        ("SandRoad.bmp", "road_sand", [(56, 46, 32), (100, 80, 52), (148, 120, 76), (188, 156, 106)]),
    ],
    "rock": [
        ("Mountains.bmp", "cliff", [(40, 36, 32), (76, 70, 62), (116, 108, 96), (158, 148, 132)]),
        ("MntCliff.bmp", "cliff_dark", [(32, 30, 28), (64, 60, 54), (100, 92, 82), (140, 130, 116)]),
        ("Rock.bmp", "stone", [(46, 44, 40), (84, 80, 72), (124, 118, 106), (166, 158, 144)]),
    ],
    "water": [
        ("Crtr2Wtr.bmp", "water", [(20, 34, 40), (34, 58, 66), (52, 84, 92), (76, 116, 124)]),
    ],
}


def is_chroma(rgb):
    return all(abs(a - b) <= TOL for a, b in zip(rgb, CHROMA))


def remap(pixel, palette):
    r, g, b = pixel[:3]
    lum = (r * 299 + g * 587 + b * 114) // 1000
    idx = min(3, lum * 4 // 256)
    return palette[idx] + (255,)


def slice_atlas(path):
    """源图集：20x20 瓦片，步长 40px（列起点 0/40/80，行起点 1/41/...）。"""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    tiles = []
    x_starts = [x0 for x0, _ in SRC_COLS if x0 + SRC_TILE <= w]
    y = 1
    while y + SRC_TILE <= h:
        for x in x_starts:
            sub = im.crop((x, y, x + SRC_TILE, y + SRC_TILE))
            opaque = sum(1 for px in sub.get_flattened_data() if not is_chroma(px))
            if opaque < SRC_TILE * SRC_TILE * 0.15:
                continue
            out = Image.new("RGBA", (SRC_TILE, SRC_TILE), (0, 0, 0, 0))
            out.putdata([
                (0, 0, 0, 0) if is_chroma(px) else px + (255,)
                for px in sub.get_flattened_data()
            ])
            # 20x20 -> 32x32，nearest 保持像素风
            tiles.append(out.resize((TILE, TILE), Image.NEAREST))
        y += SRC_STEP
    return tiles


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    manifest = []
    for category, entries in CATEGORIES.items():
        cat_dir = OUT / category
        cat_dir.mkdir(parents=True, exist_ok=True)
        for src_name, prefix, palette in entries:
            path = SRC / src_name
            if not path.exists():
                print(f"SKIP missing: {src_name}")
                continue
            tiles = slice_atlas(path)
            for i, tile in enumerate(tiles):
                # 重新着色为古代地质色带
                colored = Image.new("RGBA", (TILE, TILE))
                colored.putdata([
                    remap(px, palette) if px[3] > 0 else (0, 0, 0, 0)
                    for px in tile.get_flattened_data()
                ])
                name = f"{prefix}_{i:02d}.png"
                colored.save(cat_dir / name)
                manifest.append((category, name, src_name))
                total += 1
            print(f"{src_name}: {len(tiles)} tiles")
    # manifest
    with open(OUT / "manifest.csv", "w", encoding="utf-8") as f:
        f.write("category,file,source\n")
        for row in manifest:
            f.write(",".join(row) + "\n")
    print(f"TOTAL {total} tiles -> {OUT}")


if __name__ == "__main__":
    main()
