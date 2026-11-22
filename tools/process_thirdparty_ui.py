#!/usr/bin/env python3
"""第三方 UI 装饰素材转换流水线。

来源（均可在 OpenGameArt 页面核查许可）：
- golden-ui by buch (CC0)：裁切琥珀金像素面板 → panel_gold.png（九宫格用）
- Free UI Asset Pack 1 by ctatz (CC0)：白色通用符号染色为金色 → icon_*.png

输出至 game/assets/ui/（成品），原始素材归档 generated/ui_thirdparty/raw/，
TASL 登记见 generated/ui_thirdparty/LICENSES.md。

用法：python3 tools/process_thirdparty_ui.py
依赖：Pillow
"""

from pathlib import Path
from PIL import Image

import zipfile
import io

PROJ = Path(__file__).resolve().parent.parent
RAW = PROJ / "generated" / "ui_thirdparty" / "raw"
OUT = PROJ / "game" / "assets" / "ui"

# 与代码 C_GOLD 一致的金色（RGB 0-255）
GOLD = (222, 184, 89, 255)

# golden-ui 精灵图中干净面板的裁切框（九宫格边框约 8px）
PANEL_CROP = (176, 183, 275, 215)

# ctatz 符号 -> 成品图标名
SYMBOLS = {
    "SYMB_PLAY.png": "icon_play.png",
    "SYMB_SETTINGS.png": "icon_settings.png",
    "SYMB_INFO.png": "icon_info.png",
    "SYMB_X.png": "icon_close.png",
    "SYMB_PAUSE.png": "icon_pause.png",
    "SYMB_VOLUME.png": "icon_volume.png",
    "SYMB_MUTE.png": "icon_mute.png",
    "SYMB_CHECK.png": "icon_check.png",
    "SYMB_AWARD.png": "icon_award.png",
}

ICON_BOX = 64  # 成品图标统一装进 64×64 画布


def tint_gold(im: Image.Image) -> Image.Image:
    """把白色符号染成金色：按亮度映射到 GOLD，保留 alpha（含软阴影）。"""
    src = im.convert("RGBA")
    out = Image.new("RGBA", src.size)
    px_s = src.load()
    px_o = out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px_s[x, y]
            if a == 0:
                continue
            lum = (r + g + b) / 765.0  # 白=1，灰=阴影
            px_o[x, y] = (
                int(GOLD[0] * lum),
                int(GOLD[1] * lum),
                int(GOLD[2] * lum),
                a,
            )
    return out


def fit_canvas(im: Image.Image, box: int) -> Image.Image:
    """保持比例缩放进 box×box 透明画布（居中）。"""
    im = im.copy()
    im.thumbnail((box, box), Image.LANCZOS)
    canvas = Image.new("RGBA", (box, box), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((box - im.width) // 2, (box - im.height) // 2))
    return canvas


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    # 1) golden-ui 面板（原生分辨率保留，供 StyleBoxTexture 九宫格）
    sheet = Image.open(RAW / "golden-ui_ui-split_buch_CC0.png").convert("RGBA")
    panel = sheet.crop(PANEL_CROP)
    panel.save(OUT / "panel_gold.png")
    print(f"[OK] panel_gold.png {panel.size}")

    # 2) ctatz 符号染色
    zpath = RAW / "free-ui-asset-pack-1_ctatz_CC0.zip"
    with zipfile.ZipFile(zpath) as z:
        for src_name, dst_name in SYMBOLS.items():
            data = z.read(f"Symbols & Text/{src_name}")
            sym = Image.open(io.BytesIO(data))
            icon = fit_canvas(tint_gold(sym), ICON_BOX)
            icon.save(OUT / dst_name)
            print(f"[OK] {dst_name} <- {src_name}")

    print("[DONE] UI 装饰素材输出至", OUT)


if __name__ == "__main__":
    main()
