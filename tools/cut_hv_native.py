#!/usr/bin/env python3
"""Hard Vacuum 原生图块切割（20px 网格，×2 输出 40px）。

为什么必须这样做
---------------
Hard Vacuum（Mark Ferrari, CC BY 3.0）的地形图集是 **20×20** 的瓦片网格。
历史实现按 32px 窗口去切 20px 图集，每块都跨了瓦片边界，于是同一块图里混着
相邻两格的碎片——渲染出来就是"一把碎石"，既不可平铺也认不出结构（城墙尤其明显）。
本脚本严格按 20px 网格切分，再用 nearest 整数 2 倍放大到 40px，像素保持完整对齐。

切分规则
--------
- 输入：assets/third_party/hardvacuum/Hard Vacuum/Terrain Tiles/*.bmp
- 色键：RGB(0,138,118) teal → 全透明（Hard Vacuum 约定）
- 全透明格（图集中的空槽）不输出
- 部分透明的格（边缘过渡块）照常输出，manifest 里标 `partial=1`
- 命名：`<语义>_<行*列数+列>_<列>_<行>.png`，语义来自 SHEETS 映射
- 同时输出 manifest.csv（file, semantic, col, row, source, partial）

用法
----
    python3 tools/cut_hv_native.py            # 切割 + 生成联系表
    python3 tools/cut_hv_native.py --no-sheet # 只切割
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "assets/third_party/hardvacuum/Hard Vacuum/Terrain Tiles"
OUT_DIR = ROOT / "game/assets/tiles/hardvacuum/native"
SHEET_DIR = ROOT / "docs/screenshots/hv_native"

TS = 20      # 原生瓦片边长
SCALE = 2    # 整数倍放大 → 40px，像素严格对齐
OUT_TS = TS * SCALE
TRANS = (0, 138, 118)

# 语义 → 源 BMP（同名多个源会自动加后缀区分）
SHEETS: dict[str, list[str]] = {
    "moss": ["Grass", "Grass2"],
    "sand": ["Sand"],
    "road": ["Road", "RoadJnt"],
    "road_rock": ["MntRoad", "StneRoad"],
    "road_sand": ["SandRoad"],
    "water": ["Water2", "WatrFlow"],
    "cliff": ["GrasClif"],          # 草地→崖壁过渡：含真正的垂直墙面
    "cliff_dark": ["MntCliff", "StnCliff"],
    "stone": ["Stone"],             # 砌石：含清晰砖缝的墙面
    "mountain": ["Mountains"],
    "tree": ["Trees", "TreeGrs"],
}


def load_keyed(path: Path) -> Image.Image:
    """读 BMP，转 RGBA，teal 色键置透明。"""
    im = Image.open(path).convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            if (r, g, b) == TRANS:
                px[x, y] = (0, 0, 0, 0)
    return im


def cut_sheet(src_name: str, semantic: str, out_dir: Path, rows: list[dict]) -> int:
    path = SRC_DIR / f"{src_name}.bmp"
    if not path.exists():
        print(f"  ! 缺少 {path.name}")
        return 0
    im = load_keyed(path)
    cols_n = im.width // TS
    rows_n = im.height // TS
    count = 0
    for r in range(rows_n):
        for c in range(cols_n):
            tile = im.crop((c * TS, r * TS, (c + 1) * TS, (r + 1) * TS))
            alpha = tile.getchannel("A")
            if alpha.getextrema()[1] == 0:
                continue  # 空槽
            partial = 1 if alpha.getextrema()[0] < 255 else 0
            big = tile.resize((OUT_TS, OUT_TS), Image.NEAREST)
            idx = r * cols_n + c
            # 文件名必须含源表名：同一语义常来自多张图集（如 moss <- Grass + Grass2），
            # 它们的 (col,row) 会重叠，只用语义+坐标会把后来的块覆盖掉前面的。
            src_slug = src_name.lower().replace("-", "_")
            fname = f"{semantic}_{src_slug}_{idx:03d}_c{c}_r{r}.png"
            big.save(out_dir / fname)
            rows.append({
                "file": fname,
                "semantic": semantic,
                "source": f"{src_name}.bmp",
                "col": c,
                "row": r,
                "grid_index": idx,
                "partial": partial,
            })
            count += 1
    return count


def make_sheet(semantic: str, items: list[dict], out_path: Path, cols: int = 9) -> None:
    if not items:
        return
    cell = OUT_TS * 3
    pad = 10
    n = len(items)
    rws = (n + cols - 1) // cols
    W = cols * (cell + pad) + pad
    H = rws * (cell + pad + 16) + pad
    cv = Image.new("RGB", (W, H), (22, 24, 28))
    d = ImageDraw.Draw(cv)
    for i, it in enumerate(items):
        r, c = divmod(i, cols)
        x = pad + c * (cell + pad)
        y = pad + r * (cell + pad + 16)
        for yy in range(0, cell, 12):
            for xx in range(0, cell, 12):
                bg = (56, 60, 68) if ((xx // 12 + yy // 12) % 2 == 0) else (40, 44, 50)
                d.rectangle([x + xx, y + yy, x + xx + 11, y + yy + 11], fill=bg)
        tile = Image.open(OUT_DIR / it["file"])
        tile = tile.resize((cell, cell), Image.NEAREST)
        cv.paste(tile, (x, y), tile)
        d.text((x + 1, y + cell + 2), f"{it['col']},{it['row']}", fill=(255, 210, 120))
    cv.save(out_path)
    print(f"  联系表 {out_path.relative_to(ROOT)} ({n} 块)")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-sheet", action="store_true")
    args = ap.parse_args()

    if not SRC_DIR.exists():
        raise SystemExit(f"找不到原始素材目录：{SRC_DIR}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    stale = list(OUT_DIR.glob("*.png"))
    for f in stale:
        f.unlink()
    if stale:
        print(f"清掉旧图块 {len(stale)} 个（命名规则已变更）")
    stale = list(OUT_DIR.glob("*.png"))
    for f in stale:
        f.unlink()
    if stale:
        print(f"清掉旧图块 {len(stale)} 个（命名规则已变更）")
    SHEET_DIR.mkdir(parents=True, exist_ok=True)

    rows: list[dict] = []
    by_sem: dict[str, list[dict]] = {}
    print(f"源：{SRC_DIR}")
    print(f"目标：{OUT_DIR}  ({TS}px ×{SCALE} = {OUT_TS}px)")
    for semantic, srcs in SHEETS.items():
        for src in srcs:
            n = cut_sheet(src, semantic, OUT_DIR, rows)
            print(f"  {semantic:12s} <- {src:12s} {n} 块")
    for row in rows:
        by_sem.setdefault(row["semantic"], []).append(row)

    with (OUT_DIR / "manifest.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"manifest.csv {len(rows)} 条")

    if not args.no_sheet:
        for semantic, items in by_sem.items():
            make_sheet(semantic, items, SHEET_DIR / f"{semantic}.png")


if __name__ == "__main__":
    main()
