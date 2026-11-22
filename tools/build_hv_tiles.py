#!/usr/bin/env python3
"""Hard Vacuum Tiled 标准图块集构建。

来源链：Hard Vacuum (Mark Ferrari / Lost Garden, CC BY 3.0)
       → RWX (jame581 开源仓库, MIT) 按 Tiled 标准切好的 20×20 图块 png
       → 本脚本归档入 game/assets/tiles/hv/bitmaps/ 并生成 .tsx。

tsx 文件为 Tiled 图块集标准格式（tilewidth=20, trans=008a76 同 RWX），
Godot 侧由 tile_map_builder.gd 程序化构建等价的 TileSetAtlasSource。

用法：python3 tools/build_hv_tiles.py
依赖：Pillow（仅用于联系表）
"""

from pathlib import Path
from PIL import Image

PROJ = Path(__file__).resolve().parent.parent
BITMAPS = PROJ / "game" / "assets" / "tiles" / "hv" / "bitmaps"
OUT_TSX = PROJ / "game" / "assets" / "tiles" / "hv"

# 每个图块集：文件名 -> (Tiled 名称, 说明)
SETS = {
    "shortgrass": ("Short Grass", "短草底面"),
    "longgrass": ("Long Grass", "长草/树（tile16=树）"),
    "dirt": ("Dirt", "土路"),
    "stone": ("Stone", "岩石/山地"),
    "water": ("Water", "水面"),
    "decoration": ("Decoration", "树/石装饰"),
    "dirt2longgrass_flat": ("Dirt Long Grass - Flat", "土路→长草 过渡"),
    "stone2longgrass_flat": ("Stone Long Grass - Flat", "岩石→长草 过渡"),
    "longgrass2shallowwater_flat": ("Long Grass Shallow Water - Flat", "长草→浅水 过渡"),
    "longgrass2stone_flat": ("Long Grass Stone - Flat", "长草→岩石 过渡"),
    "longgrass2mountain_flat": ("Long Grass Mountain - Flat", "长草→山 过渡"),
}


def write_tsx(name: str, png: Path, im: Image.Image, columns: int, rows: int) -> None:
    tile_count = columns * rows
    tsx = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<tileset name="{name}" tilewidth="20" tileheight="20" '
        f'tilecount="{tile_count}" columns="{columns}">\n'
        f' <image source="bitmaps/{png.name}" trans="008a76" '
        f'width="{im.width}" height="{im.height}"/>\n'
        "</tileset>\n"
    )
    out = OUT_TSX / f"{name}.tsx"
    out.write_text(tsx, encoding="utf-8")
    print(f"[TSX] {out.name} ({columns}x{rows} tiles)")


def contact_sheet() -> None:
    pngs = sorted(BITMAPS.glob("*.png"))
    cell_w = 160
    pad = 6
    rows_img = []
    max_h = 0
    for p in pngs:
        im = Image.open(p).convert("RGBA")
        scale = max(1, cell_w // max(im.width, 1))
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        rows_img.append((p.name, im))
        max_h = max(max_h, im.height)
    total_w = cell_w * len(rows_img) + pad * (len(rows_img) + 1)
    total_h = max_h + 2 * pad + 22
    sheet = Image.new("RGBA", (total_w, total_h), (38, 44, 48, 255))
    from PIL import ImageDraw

    d = ImageDraw.Draw(sheet)
    x = pad
    for name, im in rows_img:
        sheet.alpha_composite(im, (x, pad))
        d.text((x, max_h + pad + 2), name.replace(".png", ""), fill=(220, 210, 180, 255))
        x += cell_w + pad
    out = Path("/tmp/hv_tiles_contact.png")
    sheet.save(out)
    print(f"[SHEET] {out}")


def main() -> None:
    for stem, (name, _desc) in SETS.items():
        png = BITMAPS / f"{stem}.png"
        if not png.exists():
            print(f"[SKIP] 缺 {stem}.png")
            continue
        im = Image.open(png)
        cols, rows = im.width // 20, im.height // 20
        if im.width % 20 or im.height % 20:
            print(f"[WARN] {stem} 尺寸 {im.size} 非 20 倍数")
            continue
        write_tsx(name, png, im, cols, rows)
    contact_sheet()
    print("[DONE]")


if __name__ == "__main__":
    main()
