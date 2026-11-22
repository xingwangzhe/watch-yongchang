#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Process AI-generated 4-frame sprite strips into individual RGBA frames.

- Input: 1024x256 RGB strips with 4 frames side by side on white background
- Output: individual 64x64 (units) / 96x96 (buildings) RGBA PNG frames
- Chroma: remove near-white background, flood-fill from edges only
Usage: python tools/process_new_sprites.py
"""
from pathlib import Path
from PIL import Image
import numpy as np
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "generated/new_art"
OUT = ROOT / "game/assets"

# (source dir, output subdir, category, size)
JOBS = [
    ("longdeng_run/Frame_A_B_C_D__4_frame_horizon_2026-11-22T07-19-52.png", "units/xiangyong/run", "unit", 64),
    ("gongshou_run2/Frame_A_B_C_D__4_frame_horizon_2026-11-22T07-21-17.png", "units/gongshou/run", "unit", 64),
    ("longdeng_run2/Frame_A_B_C_D__4_frame_horizon_2026-11-22T07-20-51.png", "units/longdeng/run", "unit", 64),
    ("jianta_attack/Frame_A_B_C_D__4_frame_horizon_2026-11-22T07-22-00.png", "buildings/jianta/attack", "building", 96),
    ("junxiefang_produce/Frame_A_B_C_D__4_frame_horizon_2026-11-22T07-22-31.png", "buildings/junxiefang/produce", "building", 96),
    ("fenghuotai_activate/Frame_A_B_C_D__4_frame_horizon_2026-11-22T07-22-57.png", "buildings/fenghuotai/activate", "building", 96),
]

FRAMES = 4
WHITE_TOL = 225  # 提高阈值以清除抗锯齿白边


def split_strip(im):
    """Split 1024x256 strip into 4 equal cells (256x256 each)."""
    w, h = im.size
    cw = w // FRAMES
    return [im.crop((i * cw, 0, (i + 1) * cw, h)) for i in range(FRAMES)]


def remove_white(cell):
    """Remove near-white bg: use flood fill from edges on light-pixel mask."""
    arr = np.array(cell.convert("RGBA")).copy()
    rgb = arr[:, :, :3]
    # light background candidates
    light = (rgb.min(axis=2) >= WHITE_TOL)
    # flood from image borders through light pixels
    seeds = np.zeros(light.shape, bool)
    seeds[0, :] = light[0, :]
    seeds[-1, :] = light[-1, :]
    seeds[:, 0] = light[:, 0]
    seeds[:, -1] = light[:, -1]
    lab, n = ndi.label(seeds | light, structure=ndi.generate_binary_structure(2, 1))
    border_labels = set(np.unique(np.concatenate([
        lab[0, :], lab[-1, :], lab[:, 0], lab[:, -1]
    ]))) - {0}
    bg = np.isin(lab, list(border_labels))
    arr[bg, 3] = 0

    # 第二轮：清除紧贴透明区的孤立亮像素（抗锯齿白点）
    alpha = arr[:, :, 3]
    near_transparent = ndi.binary_dilation(alpha == 0, structure=ndi.generate_binary_structure(2, 1))
    edge_light = near_transparent & (alpha > 0) & (rgb.min(axis=2) >= WHITE_TOL - 15)
    arr[edge_light, 3] = 0
    return Image.fromarray(arr, "RGBA")


def tight_crop(im, pad=2):
    ys, xs = np.where(np.array(im)[:, :, 3] > 8)
    if len(xs) == 0:
        return im
    x0, x1 = max(0, xs.min() - pad), min(im.width, xs.max() + pad + 1)
    y0, y1 = max(0, ys.min() - pad), min(im.height, ys.max() + pad + 1)
    return im.crop((x0, y0, x1, y1))


def normalize(im, size):
    """Crop tight then fit into size x size preserving aspect, centered."""
    im = tight_crop(im)
    ratio = min(size / im.width, size / im.height)
    nw, nh = int(im.width * ratio), int(im.height * ratio)
    im = im.resize((nw, nh), Image.NEAREST)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(im, ((size - nw) // 2, (size - nh) // 2))
    return out


def main():
    for rel, out_rel, cat, size in JOBS:
        src = SRC / rel
        if not src.exists():
            print("SKIP missing", rel)
            continue
        strip = Image.open(src).convert("RGBA")
        cells = split_strip(strip)
        out_dir = OUT / out_rel
        out_dir.mkdir(parents=True, exist_ok=True)
        for i, cell in enumerate(cells, 1):
            cleaned = remove_white(cell)
            final = normalize(cleaned, size)
            final.save(out_dir / f"frame_{i:02d}.png")
        print(f"{rel} -> {out_rel}: {len(cells)} frames @ {size}px")

    # Generate static.png from first frame for each entity
    for rel, out_rel, cat, size in JOBS:
        first = OUT / out_rel / "frame_01.png"
        if first.exists():
            parent = first.parent.parent
            Image.open(first).save(parent / "static.png")


if __name__ == "__main__":
    main()
