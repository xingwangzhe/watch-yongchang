#!/usr/bin/env python3
"""明式箭塔贴图绘制（望楼 / 箭楼 / 龙首箭楼）。

约定（与 pixel-art/ 其它目录一致）：
  * 纯 Pillow 程序化绘制，不手改导出 PNG；
  * 画布 168x168 原生像素，1:1 进游戏，走 nearest 过滤不糊；
  * 三档共用同一骨架，逐档加砖石基座、双弩、龙首铜弩与灯阵；
  * 调色沿用《守望·永昌》的靛青 / 朱红 / 黄铜 / 灰石。

竖向分层（168px 画布）：
    屋面 + 正脊 → 檐下间隙 → 栏杆与弩机 → 平台楼板 → 塔身 → 砖石基座
各档的 y 由 _layout() 统一给出，避免屋脊压住弩机。

运行：
    python3 pixel-art/towers/build.py
输出：
    game/assets/units/towers/{watchtower,arrow_tower,dragon_tower}.png
    pixel-art/towers/preview.png
"""
from __future__ import annotations

import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "game", "assets", "units", "towers")
PREVIEW = os.path.join(ROOT, "pixel-art", "towers", "preview.png")

SIZE = 168
CX = SIZE // 2
GROUND = 164

OUTLINE = (24, 20, 26, 255)
STONE_D = (68, 68, 78, 255)
STONE_M = (98, 98, 108, 255)
STONE_L = (128, 128, 138, 255)
WOOD_D = (52, 34, 26, 255)
WOOD_M = (86, 56, 38, 255)
WOOD_L = (122, 84, 56, 255)
TILE_D = (42, 48, 64, 255)
TILE_M = (60, 68, 88, 255)
TILE_L = (86, 96, 118, 255)
BRASS_D = (120, 84, 30, 255)
BRASS_M = (184, 142, 56, 255)
BRASS_L = (230, 196, 114, 255)
RED_D = (110, 32, 28, 255)
RED_M = (168, 50, 38, 255)
RED_L = (214, 88, 58, 255)
LANTERN = (248, 190, 96, 255)
ROPE = (148, 124, 84, 255)
STRING = (232, 220, 186, 255)


def canvas():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def box(d, x0, y0, x1, y1, fill, edge=OUTLINE):
    d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=fill, outline=edge)


def poly(d, pts, fill, edge=OUTLINE):
    d.polygon(pts, fill=fill, outline=edge)


# ---------------------------------------------------------------- 分层参数
def _layout(tier: str) -> dict:
    """返回该档的竖向关键线与左右半宽。"""
    if tier == "watchtower":
        return dict(base_top=None, body_top=106, body_bot=158, half_body=32,
                    half_plat=42, roof_half=45, peak_h=30, lantern_h=11)
    if tier == "arrow_tower":
        return dict(base_top=146, body_top=98, body_bot=150, half_body=30,
                    half_plat=40, roof_half=43, peak_h=30, lantern_h=11)
    return dict(base_top=142, body_top=92, body_bot=146, half_body=30,
                half_plat=42, roof_half=45, peak_h=30, lantern_h=11)


# ---------------------------------------------------------------- 砖石基座
def stone_base(d, top, bottom, half_top, half_bot):
    poly(d, [(CX - half_bot, bottom), (CX + half_bot, bottom),
             (CX + half_top, top), (CX - half_top, top)], STONE_M)
    span = max(1, bottom - top)
    y = top + 5
    row = 0
    while y < bottom - 3:
        t = (y - top) / float(span)
        left = int(CX - half_top - t * (half_bot - half_top))
        right = int(CX + half_top + t * (half_bot - half_top))
        d.line([(left + 1, y), (right - 1, y)], fill=STONE_D)
        x = left + 5 + (0 if row % 2 == 0 else 6)
        while x < right - 3:
            d.line([(x, y), (x, min(y + 6, bottom - 2))], fill=STONE_D)
            x += 13
        row += 1
        y += 6
    # 左侧受光 / 右侧背光
    d.line([(CX - half_bot, bottom - 1), (CX - half_top, top + 1)], fill=STONE_L)
    d.line([(CX + half_bot - 1, bottom - 1), (CX + half_top - 1, top + 1)], fill=STONE_D)
    # 压顶檐石
    box(d, CX - half_top - 3, top - 5, CX + half_top + 3, top + 1, STONE_L)
    d.line([(CX - half_top - 2, top - 4), (CX + half_top + 2, top - 4)], fill=(158, 158, 168, 255))
    poly(d, [(CX - half_bot, bottom), (CX + half_bot, bottom),
             (CX + half_top, top), (CX - half_top, top)], None, OUTLINE)


# ---------------------------------------------------------------- 塔身
def timber_body(d, top, bottom, half):
    box(d, CX - half, top, CX + half, bottom, WOOD_M)
    # 室内暗部
    box(d, CX - half + 7, top + 7, CX + half - 7, bottom - 1, (36, 24, 20, 255), None)
    # 四角立柱
    for sx in (-1, 1):
        x0 = CX + sx * half - (8 if sx > 0 else 0)
        box(d, x0, top, x0 + 8, bottom, WOOD_M)
        d.line([(x0 + 1, top + 1), (x0 + 1, bottom - 1)], fill=WOOD_L)
    # X 形斜撑
    d.line([(CX - half + 8, bottom - 5), (CX + half - 8, top + 10)], fill=WOOD_L, width=4)
    d.line([(CX + half - 8, bottom - 5), (CX - half + 8, top + 10)], fill=WOOD_L, width=4)
    # 上下横梁
    box(d, CX - half, top, CX + half, top + 6, WOOD_M)
    d.line([(CX - half + 1, top + 1), (CX + half - 1, top + 1)], fill=WOOD_L)
    box(d, CX - half, bottom - 6, CX + half, bottom, WOOD_D)
    box(d, CX - half, top, CX + half, bottom, None, OUTLINE)


# ---------------------------------------------------------------- 平台与栏杆
def platform(d, floor_y, half):
    """楼板 + 左右两段矮栏板，正面敞开留给弩机。"""
    box(d, CX - half - 2, floor_y, CX + half + 2, floor_y + 7, WOOD_D)
    d.line([(CX - half - 1, floor_y + 1), (CX + half + 1, floor_y + 1)], fill=WOOD_L)
    # 挑檐下的斗拱齿
    x = CX - half + 4
    while x < CX + half - 4:
        box(d, x, floor_y + 5, x + 5, floor_y + 10, WOOD_M, None)
        x += 11
    for sx in (-1, 1):
        a = CX + sx * half
        b = CX + sx * (half - 13)
        x0, x1 = min(a, b), max(a, b)
        box(d, x0, floor_y - 25, x1, floor_y - 6, WOOD_M)
        x = x0 + 2
        while x < x1 - 1:
            d.line([(x, floor_y - 24), (x, floor_y - 7)], fill=WOOD_D)
            x += 4
        box(d, x0 - 1, floor_y - 29, x1 + 1, floor_y - 25, WOOD_M)
        d.line([(x0, floor_y - 28), (x1, floor_y - 28)], fill=WOOD_L)


# ---------------------------------------------------------------- 弩机
def crossbow(d, cx, base_y, arm=13, twin=False):
    for off in ([-16, 14] if twin else [0]):
        bx = cx + off
        poly(d, [(bx - arm, base_y - 13), (bx - 3, base_y - 9),
                 (bx - 3, base_y - 4), (bx - arm, base_y - 8)], BRASS_D)
        poly(d, [(bx + arm, base_y - 13), (bx + 3, base_y - 9),
                 (bx + 3, base_y - 4), (bx + arm, base_y - 8)], BRASS_D)
        d.line([(bx - arm, base_y - 11), (bx, base_y - 7), (bx + arm, base_y - 11)], fill=STRING)
        box(d, bx - 4, base_y - 12, bx + 4, base_y - 1, WOOD_M)
        d.line([(bx - 1, base_y - 12), (bx - 1, base_y - 1)], fill=WOOD_L)
        d.line([(bx, base_y - 17), (bx, base_y - 3)], fill=BRASS_L)
        d.point((bx, base_y - 17), fill=(255, 248, 214, 255))


def dragon_ballista(d, cx, base_y):
    # 支架
    box(d, cx - 18, base_y - 3, cx + 18, base_y + 3, BRASS_D)
    for sx in (-1, 1):
        poly(d, [(cx + sx * 26, base_y - 15), (cx + sx * 5, base_y - 10),
                 (cx + sx * 5, base_y - 3), (cx + sx * 26, base_y - 7)], BRASS_M)
    d.line([(cx - 26, base_y - 13), (cx, base_y - 7), (cx + 26, base_y - 13)], fill=STRING)
    # 龙首
    poly(d, [(cx - 9, base_y - 7), (cx + 9, base_y - 7), (cx + 11, base_y - 15),
             (cx + 3, base_y - 20), (cx - 6, base_y - 19), (cx - 11, base_y - 12)], BRASS_M)
    box(d, cx + 3, base_y - 16, cx + 7, base_y - 13, RED_L)
    d.line([(cx - 4, base_y - 19), (cx - 10, base_y - 24)], fill=BRASS_L, width=2)
    d.line([(cx + 4, base_y - 19), (cx + 10, base_y - 24)], fill=BRASS_L, width=2)
    d.line([(cx - 8, base_y - 10), (cx - 16, base_y - 8)], fill=BRASS_L)
    d.line([(cx + 8, base_y - 10), (cx + 16, base_y - 8)], fill=BRASS_L)
    d.line([(cx, base_y - 24), (cx, base_y - 28)], fill=BRASS_L)


# ---------------------------------------------------------------- 屋顶
def roof(d, eave_y, half, trim=BRASS_M, peak_h=30):
    peak_y = eave_y - peak_h
    inset = 12
    top_l, top_r = CX - half + inset, CX + half - inset
    bot_l, bot_r = CX - half, CX + half
    ridges = 9
    for i in range(ridges):
        t0, t1 = i / float(ridges), (i + 1) / float(ridges)
        xt0, xt1 = top_l + (top_r - top_l) * t0, top_l + (top_r - top_l) * t1
        xb0, xb1 = bot_l + (bot_r - bot_l) * t0, bot_l + (bot_r - bot_l) * t1
        col = TILE_L if i < 3 else (TILE_M if i < 7 else TILE_D)
        poly(d, [(xt0, peak_y), (xt1, peak_y), (xb1, eave_y), (xb0, eave_y)], col, None)
        d.line([(xt1, peak_y), (xb1, eave_y)], fill=TILE_D)
    poly(d, [(bot_l, eave_y), (top_l, peak_y), (top_r, peak_y), (bot_r, eave_y)], None, OUTLINE)
    # 起翘檐角
    for sx in (-1, 1):
        x0 = CX + sx * half
        poly(d, [(x0, eave_y - 3), (x0 + sx * 13, eave_y - 12),
                 (x0 + sx * 12, eave_y - 2), (x0, eave_y + 2)], trim)
    # 檐口板
    box(d, CX - half, eave_y - 1, CX + half, eave_y + 4, trim)
    d.line([(CX - half + 1, eave_y + 1), (CX + half - 1, eave_y + 1)], fill=BRASS_D)
    # 正脊
    box(d, CX - half + inset, peak_y - 5, CX + half - inset, peak_y + 1, trim)
    d.line([(CX - half + inset + 1, peak_y - 4), (CX + half - inset - 1, peak_y - 4)], fill=BRASS_L)
    # 鸱吻
    for sx in (-1, 1):
        x = CX + sx * (half - inset)
        poly(d, [(x, peak_y - 3), (x + sx * 6, peak_y - 13),
                 (x + sx * 9, peak_y - 4), (x + sx * 3, peak_y - 1)], trim)
    return peak_y


# ---------------------------------------------------------------- 小件
def hanging_lantern(d, x, eave_y, h=11):
    """挂在屋檐外沿的灯笼，不压栏杆。"""
    d.line([(x, eave_y + 2), (x, eave_y + 6)], fill=ROPE)
    y = eave_y + 6
    box(d, x - 4, y, x + 5, y + h, RED_M)
    d.rectangle([x - 3, y + 2, x + 3, y + h - 3], fill=RED_L)
    box(d, x - 4, y + h - 3, x + 5, y + h, RED_D)
    d.line([(x, y + 3), (x, y + h - 4)], fill=LANTERN)
    d.line([(x, y + h), (x, y + h + 3)], fill=LANTERN)


def tally_flag(d, x, top_y, bottom_y, color=RED_M):
    """高杆战旗：杆自楼身起，挑过屋面。"""
    box(d, x, top_y, x + 3, bottom_y, WOOD_D)
    d.line([(x + 1, top_y), (x + 1, bottom_y - 1)], fill=WOOD_L)
    poly(d, [(x + 3, top_y + 3), (x + 27, top_y + 10),
             (x + 19, top_y + 17), (x + 27, top_y + 24), (x + 3, top_y + 23)], color)
    d.line([(x + 6, top_y + 9), (x + 19, top_y + 13)], fill=BRASS_L)
    d.line([(x + 6, top_y + 17), (x + 15, top_y + 19)], fill=BRASS_L)
    poly(d, [(x - 2, top_y - 4), (x + 6, top_y - 4), (x + 2, top_y + 2)], BRASS_M)


def arrow_bundle(d, x, y):
    for i in range(5):
        d.line([(x + i * 3, y), (x + i * 3 + 3, y - 15)], fill=WOOD_L)
        d.point((x + i * 3 + 3, y - 15), fill=BRASS_L)
    box(d, x - 3, y - 6, x + 17, y - 1, ROPE)


def shadow(d, y, half):
    d.ellipse([CX - half, y - 6, CX + half, y + 6], fill=(0, 0, 0, 62))


# ---------------------------------------------------------------- 三档
def build_watchtower():
    L = _layout("watchtower")
    img, d = canvas()
    shadow(d, 157, 42)
    timber_body(d, L["body_top"], L["body_bot"], L["half_body"])
    platform(d, L["body_top"], L["half_plat"])
    crossbow(d, CX, L["body_top"] - 6, arm=12)
    eave = L["body_top"] - 30
    roof(d, eave, L["roof_half"], BRASS_M, L["peak_h"])
    hanging_lantern(d, CX - L["roof_half"] + 4, eave, L["lantern_h"])
    hanging_lantern(d, CX + L["roof_half"] - 4, eave, L["lantern_h"])
    tally_flag(d, CX - L["half_body"] - 12, eave - 34, L["body_bot"] - 10)
    arrow_bundle(d, CX + 24, 158)
    return img


def build_arrow_tower():
    L = _layout("arrow_tower")
    img, d = canvas()
    shadow(d, 161, 48)
    stone_base(d, L["base_top"], GROUND, L["half_body"] + 8, L["half_body"] + 14)
    timber_body(d, L["body_top"], L["body_bot"], L["half_body"])
    platform(d, L["body_top"], L["half_plat"])
    crossbow(d, CX, L["body_top"] - 6, arm=13, twin=True)
    eave = L["body_top"] - 30
    roof(d, eave, L["roof_half"], BRASS_M, L["peak_h"])
    hanging_lantern(d, CX - L["roof_half"] + 4, eave, L["lantern_h"])
    hanging_lantern(d, CX + L["roof_half"] - 4, eave, L["lantern_h"])
    tally_flag(d, CX - L["half_body"] - 12, eave - 34, L["body_bot"] - 10)
    arrow_bundle(d, CX + 24, 160)
    return img


def build_dragon_tower():
    L = _layout("dragon_tower")
    img, d = canvas()
    shadow(d, 161, 52)
    stone_base(d, L["base_top"], GROUND, L["half_body"] + 9, L["half_body"] + 16)
    timber_body(d, L["body_top"], L["body_bot"], L["half_body"])
    platform(d, L["body_top"], L["half_plat"])
    dragon_ballista(d, CX, L["body_top"] - 4)
    eave = L["body_top"] - 32
    roof(d, eave, L["roof_half"], BRASS_L, L["peak_h"])
    hanging_lantern(d, CX - L["roof_half"] + 4, eave, L["lantern_h"] + 1)
    hanging_lantern(d, CX + L["roof_half"] - 4, eave, L["lantern_h"] + 1)
    tally_flag(d, CX - L["half_body"] - 12, eave - 34, L["body_bot"] - 10, RED_M)
    # 金饰钉
    for x in range(CX - 28, CX + 30, 11):
        d.point((x, L["body_top"] + 12), fill=BRASS_L)
        d.point((x, L["body_top"] + 13), fill=BRASS_D)
    arrow_bundle(d, CX + 24, 160)
    return img


BUILDS = {
    "watchtower": build_watchtower,
    "arrow_tower": build_arrow_tower,
    "dragon_tower": build_dragon_tower,
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    images = {}
    for name, fn in BUILDS.items():
        img = fn()
        path = os.path.join(OUT_DIR, f"{name}.png")
        img.save(path)
        images[name] = img
        print(f"wrote {path}  {img.size[0]}x{img.size[1]}  bbox={img.getbbox()}")

    pad = 10
    sheet = Image.new("RGBA", (SIZE * 3 + pad * 4, SIZE + pad * 2), (20, 24, 30, 255))
    for i, img in enumerate(images.values()):
        sheet.alpha_composite(img, (pad + i * (SIZE + pad), pad))
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    sheet.save(PREVIEW)
    print(f"wrote {PREVIEW}")


if __name__ == "__main__":
    main()
