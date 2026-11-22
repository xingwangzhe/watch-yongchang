#!/usr/bin/env python3
"""合成「地形过渡图块」（Hard Vacuum 具名图块的派生资产）。

问题：Hard Vacuum 原始包只有单一地貌的纹理变体，没有地貌之间的过渡块。
直接相邻摆放会形成硬边与台阶感（草原亮度 ~50，沙地 ~120，差 70 灰阶）。

做法：对每一对有序地貌 (A → B)，按 4 邻接位（N/E/S/W 共 16 种组合）合成一张
32×32 过渡块：以 A 为底，把 B 从「存在 B 邻居」的那几条边向内做渐变覆盖，
渐变边界带噪声抖动（模拟自然咬合），并对渐变带做 Bayer 抖动以保持像素风。

输出：
  game/assets/tiles/hardvacuum/transitions/<A>_to_<B>_<mask>.png   （mask 0..15）
  game/assets/tiles/hardvacuum/transitions/INDEX.json              （索引 + 生成参数）

mask 位定义：bit0=N, bit1=E, bit2=S, bit3=W（1 表示该方向邻居是 B）。

用法：
  python3 tools/make_transition_tiles.py            # 生成
  python3 tools/make_transition_tiles.py --preview   # 生成并输出联系表到 /tmp
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
from typing import Dict, List, Tuple

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "game", "assets", "tiles", "hardvacuum")
OUT_DIR = os.path.join(ROOT, "transitions")

TILE = 32
RAMP = 11          # 渐变带宽度（像素）
JITTER = 2         # 边界抖动幅度（像素）
BAYER = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]

# 参与过渡的地貌 → 代表性底图（同一地貌内部再用变体轮换）
CATEGORIES: Dict[str, str] = {
    "moss": "ground",
    "sand": "ground",
    "water": "water",
}

# 只合成实际会相邻的地貌对（无序），生成时双向各一套
PAIRS: List[Tuple[str, str]] = [
    ("moss", "sand"),
    ("moss", "water"),
    ("sand", "water"),
]

VARIANT_COUNT = {"moss": 13, "sand": 13, "water": 14}


def _load(cat: str, variant: int) -> Image.Image:
    sub = CATEGORIES[cat]
    path = os.path.join(ROOT, sub, f"{cat}_{variant:02d}.png")
    if not os.path.exists(path):
        path = os.path.join(ROOT, sub, f"{cat}_00.png")
    return Image.open(path).convert("RGBA")


def _alpha_mask(mask_bits: int, rng: random.Random) -> List[List[float]]:
    """按 4 邻接位生成 0..1 的覆盖强度图（1 = 完全被 B 覆盖）。"""
    # 每个方向一条「距离该边的距离」
    ramp = [[0.0] * TILE for _ in range(TILE)]
    noise = [[rng.uniform(-JITTER, JITTER) for _ in range(TILE)] for _ in range(TILE)]
    for y in range(TILE):
        for x in range(TILE):
            best = 0.0
            if mask_bits & 1:   # N：来自顶部
                best = max(best, 1.0 - (y + noise[y][x]) / RAMP)
            if mask_bits & 2:   # E：来自右侧
                best = max(best, 1.0 - ((TILE - 1 - x) + noise[y][x]) / RAMP)
            if mask_bits & 4:   # S：来自底部
                best = max(best, 1.0 - ((TILE - 1 - y) + noise[y][x]) / RAMP)
            if mask_bits & 8:   # W：来自左侧
                best = max(best, 1.0 - (x + noise[y][x]) / RAMP)
            ramp[y][x] = smoothstep(clamp01(best))
    return ramp


def clamp01(v: float) -> float:
    return 0.0 if v < 0.0 else (1.0 if v > 1.0 else v)


def smoothstep(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)


def _blend(a: Image.Image, b: Image.Image, mask_bits: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    alpha = _alpha_mask(mask_bits, rng)
    pa, pb = a.load(), b.load()
    out = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    po = out.load()
    for y in range(TILE):
        for x in range(TILE):
            t = alpha[y][x]
            # Bayer 抖动：像素风里比连续插值更像手绘过渡
            thr = (BAYER[y % 4][x % 4] + 0.5) / 16.0
            t = 1.0 if t > thr else 0.0 if t < thr - 0.45 else t
            ca, cb = pa[x, y], pb[x, y]
            po[x, y] = (
                int(round(ca[0] * (1 - t) + cb[0] * t)),
                int(round(ca[1] * (1 - t) + cb[1] * t)),
                int(round(ca[2] * (1 - t) + cb[2] * t)),
                255,
            )
    return out


def build() -> Dict[str, object]:
    os.makedirs(OUT_DIR, exist_ok=True)
    index: Dict[str, object] = {
        "tile_size": TILE,
        "ramp_px": RAMP,
        "jitter_px": JITTER,
        "mask_bits": {"N": 1, "E": 2, "S": 4, "W": 8},
        "pairs": {},
        "source": "派生自 Hard Vacuum (Mark Ferrari / Lost Garden) CC BY 3.0，本项目合成过渡块",
    }
    made = 0
    for ca, cb in PAIRS:
        for src, dst in ((ca, cb), (cb, ca)):
            key = f"{src}_to_{dst}"
            index["pairs"][key] = {}
            for mask_bits in range(16):
                # 底图变体在同一地貌内轮换，避免 16 张过渡块完全同底
                va = mask_bits % VARIANT_COUNT[src]
                vb = (mask_bits * 3 + 1) % VARIANT_COUNT[dst]
                img = _blend(_load(src, va), _load(dst, vb), mask_bits,
                             seed=hash((key, mask_bits)) & 0xFFFF)
                name = f"{key}_{mask_bits:02d}.png"
                img.save(os.path.join(OUT_DIR, name))
                index["pairs"][key][str(mask_bits)] = name
                made += 1
    with open(os.path.join(OUT_DIR, "INDEX.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)
    return {"made": made, "index": index}


def preview() -> str:
    """把三类地貌各拼一个 6×6 小场景，检查过渡是否自然。"""
    scenes = [("moss", "sand"), ("moss", "water"), ("sand", "water")]
    cell = TILE * 6
    canvas = Image.new("RGB", (cell * len(scenes) + 16 * (len(scenes) + 1), cell + 32),
                       (24, 26, 30))
    for si, (a, b) in enumerate(scenes):
        # 左半 A、右半 B 的竖直分界 + 上方一小块 B 咬合
        grid: List[List[int]] = []
        for y in range(6):
            row = []
            for x in range(6):
                row.append(1 if x >= 3 else 0)
            grid.append(row)
        grid[1][2] = 1
        grid[4][2] = 1
        patch = Image.new("RGBA", (cell, cell))
        for y in range(6):
            for x in range(6):
                own = grid[y][x]
                bits = 0
                nb = [(0, -1, 1), (1, 0, 2), (0, 1, 4), (-1, 0, 8)]
                for dx, dy, bit in nb:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < 6 and 0 <= ny < 6 and grid[ny][nx] != own:
                        bits |= bit
                if bits == 0:
                    tile = _load(a if own == 0 else b, (x * 3 + y) % 13)
                else:
                    src, dst = (a, b) if own == 0 else (b, a)
                    f = os.path.join(OUT_DIR, f"{src}_to_{dst}_{bits:02d}.png")
                    if not os.path.exists(f):
                        continue
                    tile = Image.open(f).convert("RGBA")
                patch.paste(tile, (x * TILE, y * TILE))
        canvas.paste(patch, (16 + si * (cell + 16), 16))
    out = "/tmp/transition_preview.png"
    canvas.save(out)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args()
    info = build()
    print(f"[OK] 合成过渡图块 {info['made']} 张 → {OUT_DIR}")
    if args.preview:
        print("[OK] 联系表 →", preview())


if __name__ == "__main__":
    main()
