#!/usr/bin/env python3
"""UI 素材处理：切条带 → 去白底 → tight crop → 居中缩放 → 输出 RGBA PNG。
复用 process_new_sprites.py 的抠图经验（flood fill + 抗锯齿白点清除）。"""
from pathlib import Path

from PIL import Image

ROOT = Path("/home/xingwangzhe/桌面/2026游戏赛事")
SRC = ROOT / "generated/ui_art"
OUT = ROOT / "game/assets/ui"
WHITE_TOL = 225
ICON = 64
PANEL = 512


def remove_white(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    # 边界 flood fill：把与边缘连通的近白像素清为透明
    from collections import deque

    seen = [[False] * w for _ in range(h)]
    q = deque()

    def near_white(x: int, y: int) -> bool:
        r, g, b, _ = px[x, y]
        return r >= WHITE_TOL and g >= WHITE_TOL and b >= WHITE_TOL

    for x in range(w):
        for y in (0, h - 1):
            if near_white(x, y) and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if near_white(x, y) and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    while q:
        cx, cy = q.popleft()
        px[cx, cy] = (0, 0, 0, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and near_white(nx, ny):
                seen[ny][nx] = True
                q.append((nx, ny))
    # 第二轮：清除贴透明区的抗锯齿白点
    changed = True
    rounds = 0
    while changed and rounds < 6:
        changed = False
        rounds += 1
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                near = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
                        near = True
                        break
                if near and r >= WHITE_TOL - 12 and g >= WHITE_TOL - 12 and b >= WHITE_TOL - 12:
                    px[x, y] = (0, 0, 0, 0)
                    changed = True
    # 透明像素 RGB 清零防污染
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0 and px[x, y][:3] != (0, 0, 0):
                px[x, y] = (0, 0, 0, 0)
    return im


def normalize(im: Image.Image, size: int) -> Image.Image:
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    w, h = im.size
    scale = min(size / w, size / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    im = im.resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(im, ((size - nw) // 2, (size - nh) // 2))
    return canvas


def split_strip(im: Image.Image, cells: int) -> list:
    w, h = im.size
    cw = w // cells
    return [im.crop((i * cw, 0, (i + 1) * cw, h)) for i in range(cells)]


JOBS = [
    # (源文件, 切割数, 输出名列表, 输出尺寸)
    ("icons_res/4_game_resource_icons_in_one_h_2026-11-22T08-14-37.png", 4,
     ["icon_grain", "icon_silver", "icon_ammo", "icon_beacon"], ICON),
    ("icons_build/3_game_building_icons_in_one_h_2026-11-22T08-15-00.png", 3,
     ["icon_tower", "icon_armory", "icon_signal"], ICON),
    ("icons_unit/3_game_soldier_unit_icons_in_o_2026-11-22T08-15-27.png", 3,
     ["icon_militia", "icon_archer", "icon_dragon"], ICON),
]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for rel, cells, names, size in JOBS:
        src = SRC / rel
        im = Image.open(src)
        cells_im = split_strip(im, cells)
        for name, cell in zip(names, cells_im):
            out = remove_white(cell)
            out = normalize(out, size)
            out.save(OUT / f"{name}.png")
            print(f"[OK] {name}.png")
    # 面板：整图去白底后保持矩形（供 NinePatch/StyleBoxTexture）
    panel_src = next((SRC / "panel").glob("*.png"))
    p = Image.open(panel_src)
    p = remove_white(p)
    bbox = p.getbbox()
    if bbox:
        p = p.crop(bbox)
    p = p.resize((PANEL, PANEL), Image.NEAREST)
    p.save(OUT / "panel_dark.png")
    print("[OK] panel_dark.png")


if __name__ == "__main__":
    main()
