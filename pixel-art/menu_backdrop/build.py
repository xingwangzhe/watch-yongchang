#!/usr/bin/env python3
"""《守望·永昌》主菜单夜景 — pixel-art-studio build script.

Master canvas: 640x360. Game export: 1280x720 (2x nearest-neighbour).
All pixels are authored here; exported PNGs are build products.
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "skills" / "pixel-art-studio" / "scripts"))

from pixelstudio import Sprite  # noqa: E402


W, H = 640, 360
OUTPUT = ROOT / "game" / "assets" / "ui" / "menu_backdrop.png"
CLOUD_OUTPUT = ROOT / "game" / "assets" / "ui" / "menu_clouds.png"
WAVE_OUTPUT = ROOT / "game" / "assets" / "ui" / "menu_waves.png"
BOAT_OUTPUT = ROOT / "game" / "assets" / "ui" / "menu_boat.png"
FIRE_OUTPUT = ROOT / "game" / "assets" / "ui" / "menu_beacon.png"
PREVIEW = ROOT / "docs" / "screenshots" / "ui_2026-11-23" / "menu_backdrop_v2.png"
MASTER = Path(__file__).resolve().parent / "menu_backdrop_1x.png"
SWATCH = Path(__file__).resolve().parent / "palette.png"
CLOUD_MASTER = Path(__file__).resolve().parent / "menu_clouds_1x.png"
WAVE_MASTER = Path(__file__).resolve().parent / "menu_waves_1x.png"
BOAT_MASTER = Path(__file__).resolve().parent / "menu_boat_1x.png"
FIRE_MASTER = Path(__file__).resolve().parent / "menu_beacon_1x.png"

# 32-colour scene palette: cool ink and stone, with restrained lantern warmth.
PAL = [
    "#03070d",  # 0  sky black
    "#07151d",  # 1  sky deep
    "#0b222b",  # 2  sky blue-green
    "#10313a",  # 3  sky teal
    "#17464b",  # 4  horizon teal
    "#0b1f24",  # 5  far mountain
    "#14343a",  # 6  middle mountain
    "#071418",  # 7  near ink
    "#061a21",  # 8  sea deep
    "#0b2b34",  # 9  sea middle
    "#103e46",  # 10 sea light
    "#1d5659",  # 11 wave crest
    "#101b1d",  # 12 wall shadow
    "#1a2a2c",  # 13 wall base
    "#29403e",  # 14 wall mid
    "#405a50",  # 15 wall light
    "#596d5b",  # 16 stone highlight
    "#0a1012",  # 17 roof black
    "#192324",  # 18 roof body
    "#2b392f",  # 19 roof mid
    "#4a4d39",  # 20 roof edge
    "#4b2a1e",  # 21 wood dark
    "#7b442b",  # 22 wood
    "#b06a3d",  # 23 wood light
    "#c08d43",  # 24 old gold
    "#e9b75b",  # 25 gold light
    "#d97d36",  # 26 lantern
    "#ffc76e",  # 27 lantern core
    "#71281f",  # 28 vermilion dark
    "#a9432f",  # 29 vermilion light
    "#f2e4bf",  # 30 moon and stars
    "#608b84",  # 31 mist
]

s = Sprite(W, H, palette=PAL)
rng = random.Random(1558)


def reset_canvas(width: int = W, height: int = H, seed: int = 1558) -> Sprite:
    global s, rng
    rng = random.Random(seed)
    s = Sprite(width, height, palette=PAL)
    return s


def rect(x0: int, y0: int, x1: int, y1: int, color: int) -> None:
    s.rect(x0, y0, x1, y1, color)


def line(x0: int, y0: int, x1: int, y1: int, color: int) -> None:
    s.line(x0, y0, x1, y1, color)


def poly(points: list[tuple[int, int]], color: int) -> None:
    s.polygon(points, color)


def ridge(base_y: int, amplitude: int, step: int, seed: int) -> list[tuple[int, int]]:
    local = random.Random(seed)
    pts: list[tuple[int, int]] = []
    for x in range(-16, W + 16 + step, step):
        wave = (
            math.sin(x * 0.020 + seed) * amplitude * 0.32
            + math.sin(x * 0.047 + seed * 0.7) * amplitude * 0.18
        )
        pts.append((x, int(base_y + wave + local.randrange(-amplitude, amplitude + 1) * 0.45)))
    pts += [(W + 20, H + 8), (-20, H + 8)]
    return pts


def small_tree(x: int, y: int, height: int, color: int = 7) -> None:
    line(x, y, x, y - height, color)
    levels = max(2, height // 4)
    for level in range(levels):
        yy = y - 2 - level * 3
        span = max(1, height // 3 - level)
        line(x - span, yy, x + span, yy, color)


def cloud_wisp(x: int, y: int, length: int, color: int, highlight: int = 4) -> None:
    for row in range(3):
        yy = y + row + (1 if row == 1 else 0)
        xx = x + row * 5
        ll = max(8, length - row * 12 + rng.randrange(-8, 9))
        rect(xx, yy, xx + ll, yy, color)
    for _ in range(max(2, length // 22)):
        hx = x + rng.randrange(0, length)
        rect(hx, y - 1, hx + rng.randrange(2, 9), y - 1, highlight)


def cloud_bank(x: int, y: int, width: int, height: int, light_bias: bool = False) -> None:
    """Layered pixel cloud bank; stays clear of tile edges for seamless scrolling."""
    rows = max(3, height // 2)
    for row in range(rows):
        inset = int(row * width * 0.055)
        yy = y + height - row * 2
        x0 = x + inset
        x1 = x + width - inset
        if x1 <= x0:
            continue
        color = 3 if row < 2 else 4
        rect(x0, yy, x1, yy, color)
        if rng.random() < 0.55:
            rect(x0 + rng.randrange(0, max(1, x1 - x0)), yy - 1,
                 x0 + rng.randrange(0, max(1, x1 - x0)), yy - 1, 5)
    # Moonlit crest and ragged underside.
    for _ in range(max(4, width // 18)):
        cx = x + rng.randrange(width // 6, max(width // 6 + 1, width * 5 // 6))
        cy = y + (0 if not light_bias else 1)
        rect(cx, cy, cx + rng.randrange(2, 9), cy, 31)
    for _ in range(max(3, width // 25)):
        cx = x + rng.randrange(width // 8, max(width // 8 + 1, width * 7 // 8))
        rect(cx, y + height + rng.randrange(0, 2), cx + rng.randrange(2, 8),
             y + height + rng.randrange(0, 2), 3)


def draw_sky() -> None:
    s.gradient_dither(0, 0, W - 1, H - 1, [0, 1, 2, 3, 4], axis="v", pattern="bayer8")

    for _ in range(150):
        x = rng.randrange(2, W - 2)
        y = rng.randrange(4, 166)
        if y > 120 and rng.random() < 0.55:
            continue
        color = 30 if rng.random() < 0.72 else 16
        rect(x, y, x, y, color)
        if rng.random() < 0.10:
            rect(x - 1, y, x + 1, y, color)
            rect(x, y - 1, x, y + 1, color)

    for cx, cy in ((235, 42), (378, 31), (512, 78), (68, 96), (450, 120)):
        for _ in range(8):
            x = cx + rng.randrange(-11, 12)
            y = cy + rng.randrange(-7, 8)
            rect(x, y, x, y, 4 if rng.random() < 0.5 else 30)

    # Sparse halo dust avoids a hard bullseye while keeping every pixel opaque.
    cx, cy = 309, 66
    for y in range(cy - 49, cy + 50):
        for x in range(cx - 49, cx + 50):
            dist = math.hypot(x - cx, y - cy)
            if 27.0 < dist <= 49.0:
                falloff = max(0.0, 1.0 - (dist - 27.0) / 22.0) ** 1.7
                noise = ((x * 73856093) ^ (y * 19349663) ^ 0x5A17) & 0xFFFF
                if noise / 65535.0 < falloff * 0.46:
                    color = 25 if dist < 33.0 and noise % 5 < 3 else 4 if dist < 41.0 else 3
                    s.px(x, y, color)
    s.circle(cx, cy, 28, 25, fill=True)
    s.circle(cx, cy, 26, 30, fill=True)
    for dx, dy, rr in ((-9, -7, 3), (7, 5, 2), (3, 14, 2), (-13, 11, 1), (13, -11, 1)):
        s.circle(cx + dx, cy + dy, rr, 25, fill=True)
    line(cx - 25, cy + 20, cx + 19, cy + 20, 25)
    rect(cx - 35, cy + 5, cx - 11, cy + 6, 4)
    rect(cx + 10, cy + 11, cx + 36, cy + 12, 4)
    rect(cx - 22, cy + 30, cx + 16, cy + 31, 4)


def draw_cloud_layer() -> None:
    for x, y, width, height in (
        (32, 18, 126, 10),
        (212, 34, 156, 12),
        (470, 18, 118, 9),
        (94, 74, 172, 12),
        (356, 70, 138, 10),
        (520, 98, 100, 8),
        (48, 118, 184, 13),
        (278, 112, 146, 10),
        (446, 138, 158, 12),
        (126, 154, 128, 9),
    ):
        cloud_bank(x, y, width, height, light_bias=y < 80)

    for x, y, length, color, highlight in (
        (292, 42, 124, 4, 31),
        (206, 72, 188, 3, 31),
        (34, 96, 174, 5, 4),
        (386, 103, 204, 4, 31),
        (148, 137, 278, 6, 4),
        (8, 151, 204, 5, 4),
        (458, 154, 168, 6, 4),
        (88, 20, 138, 3, 31),
        (520, 62, 104, 4, 5),
        (332, 164, 152, 5, 4),
    ):
        cloud_wisp(x, y, length, color, highlight)

    # Thin wisps keep the band from looking like two repeated cloud rows.
    for _ in range(24):
        x = rng.randrange(6, W - 54)
        y = rng.randrange(22, 176)
        rect(x, y, x + rng.randrange(8, 46), y, 5 if rng.random() < 0.65 else 6)


def draw_mountains() -> None:
    far = ridge(152, 24, 13, 21)
    poly(far, 6)
    line_points = far[:-2]
    for i in range(len(line_points) - 1):
        line(line_points[i][0], line_points[i][1], line_points[i + 1][0], line_points[i + 1][1], 5)

    mid = ridge(177, 19, 11, 34)
    poly(mid, 5)
    for i in range(len(mid) - 3):
        x, y = mid[i]
        line(x, y, mid[i + 1][0], mid[i + 1][1], 7)

    near = ridge(206, 14, 9, 57)
    poly(near, 7)
    for i in range(len(near) - 3):
        x, y = near[i]
        line(x, y, near[i + 1][0], near[i + 1][1], 0)

    for x in range(4, W, 7):
        local_rng = random.Random(1000 + x)
        y = 190 + int(8 * math.sin(x * 0.035)) + local_rng.randrange(-7, 8)
        if local_rng.random() < 0.48:
            small_tree(x, y, local_rng.randrange(3, 9), 7 if x < 380 else 0)

    px, py = 435, 132
    rect(px - 1, py, px + 1, py + 15, 0)
    for tier in range(3):
        ty = py - tier * 4
        poly([(px - 8 + tier * 2, ty), (px, ty - 4), (px + 8 - tier * 2, ty)], 0)
    rect(px, py - 19, px, py - 15, 0)

    for y, x0 in ((157, 18), (170, 286), (195, 74), (211, 386)):
        for _ in range(14):
            xx = x0 + rng.randrange(-30, 100)
            yy = y + rng.randrange(-3, 4)
            rect(xx, yy, xx + rng.randrange(14, 54), yy, 31)
        s.dither(max(0, x0 - 20), y - 2, min(W - 1, x0 + 110), y + 2, "keep", 5, mix=0.24, pattern="bayer8")


def draw_boat(x: int, y: int, scale: int = 1) -> None:
    hull = [
        (x - 12 * scale, y),
        (x - 8 * scale, y + 3 * scale),
        (x + 9 * scale, y + 3 * scale),
        (x + 13 * scale, y),
        (x + 7 * scale, y + 1 * scale),
        (x - 7 * scale, y + 1 * scale),
    ]
    poly(hull, 7)
    line(x - 7 * scale, y + 2 * scale, x + 8 * scale, y + 2 * scale, 14)
    line(x, y, x, y - 12 * scale, 7)
    poly([(x + 1, y - 12 * scale), (x + 10 * scale, y - 4 * scale), (x + 1, y - 3 * scale)], 18)
    rect(x - 1, y - 7 * scale, x + 1, y - 5 * scale, 26)
    rect(x, y - 7 * scale, x, y - 6 * scale, 27)
    for ring, color in ((5, 4), (3, 26), (1, 27)):
        rect(x - ring, y - 6 * scale - ring, x + ring, y - 6 * scale - ring, color)


def draw_sea() -> None:
    s.gradient_dither(0, 184, W - 1, 306, [8, 9, 10], axis="v", pattern="bayer8")

    for x, y in ((42, 198), (146, 191), (486, 190), (592, 196)):
        rect(x, y, x + 1, y + 1, 27)
        rect(x - 1, y + 1, x + 2, y + 1, 4)


def draw_wave_layer() -> None:
    wave_h = 120
    for _ in range(118):
        x = rng.randrange(0, W - 16)
        y = rng.randrange(4, wave_h - 5)
        length = rng.randrange(2, min(24, W - x - 2))
        color = 11 if rng.random() < 0.20 else 9
        rect(x, y, x + length, y, color)
        if length > 7 and rng.random() < 0.40:
            rect(x + 2, y + 1, x + length - 3, y + 1, 10)
        if rng.random() < 0.12:
            rect(x + length // 2, y - 1, x + length // 2, y - 1, 4)


def draw_boat_sprite() -> None:
    draw_boat(24, 34, 1)


def chinese_roof(x: int, y: int, width: int, roof_h: int, body_h: int, lit: bool = False) -> None:
    body_top = y + 2
    body_bottom = y + 2 + body_h
    rect(x + 8, body_top, x + width - 8, body_bottom, 18)
    for bx in range(x + 12, x + width - 8, 22):
        rect(bx, body_top, bx + 2, body_bottom, 21)
    if lit:
        for wx in range(x + 20, x + width - 14, 26):
            rect(wx, body_top + 5, wx + 6, body_top + 12, 26)
            rect(wx + 1, body_top + 6, wx + 5, body_top + 10, 27)

    ridge_y = y - roof_h
    pts = [
        (x - 7, y + 1), (x + 2, y - roof_h // 3),
        (x + width // 5, ridge_y), (x + width * 4 // 5, ridge_y),
        (x + width - 2, y - roof_h // 3), (x + width + 8, y + 1),
        (x + width + 1, y + 4), (x + width // 2, y),
        (x - 1, y + 4),
    ]
    poly(pts, 18)
    line(x + width // 5, ridge_y, x + width * 4 // 5, ridge_y, 20)
    line(x + 3, y - 1, x + width - 2, y - 1, 19)
    line(x - 6, y + 1, x - 10, y - 2, 20)
    line(x + width + 7, y + 1, x + width + 11, y - 2, 20)
    for tx in range(x + 9, x + width - 4, 7):
        fx = (tx - (x + width // 5)) / max(1, width * 3 // 5)
        ty = int(ridge_y + (y - 1 - ridge_y) * max(0.0, min(1.0, abs(fx))))
        line(tx, ty, tx + rng.randrange(-1, 2), y - 2, 17)
    for ox in (x + width // 5, x + width * 4 // 5):
        rect(ox - 1, ridge_y - 2, ox + 1, ridge_y, 20)


def draw_skyline() -> None:
    chinese_roof(138, 246, 92, 21, 24, lit=True)
    chinese_roof(205, 236, 70, 17, 22, lit=False)
    chinese_roof(275, 246, 82, 18, 21, lit=True)
    chinese_roof(416, 249, 94, 19, 22, lit=False)
    chinese_roof(505, 240, 74, 17, 20, lit=True)


def draw_gatehouse() -> None:
    poly([(22, 280), (27, 238), (111, 238), (116, 280)], 12)
    rect(31, 245, 106, 279, 13)
    for y in range(250, 279, 7):
        line(33, y, 104, y, 7)
        for x in range(35 + (4 if (y // 7) % 2 else 0), 104, 17):
            line(x, y, x, y + 6, 12)
    poly([(49, 280), (49, 259), (55, 252), (75, 252), (81, 259), (81, 280)], 21)
    poly([(53, 280), (53, 261), (58, 256), (72, 256), (77, 261), (77, 280)], 26)
    rect(58, 266, 72, 279, 27)
    line(57, 279, 73, 279, 25)
    line(63, 262, 63, 279, 21)
    line(68, 262, 68, 279, 21)

    rect(32, 203, 105, 238, 21)
    rect(37, 207, 100, 230, 18)
    for x in range(39, 101, 15):
        rect(x, 207, x + 2, 238, 21)
    for x in range(45, 100, 24):
        rect(x, 214, x + 9, 225, 26)
        rect(x + 1, 215, x + 8, 223, 27)
        line(x + 4, 215, x + 4, 223, 21)
    line(29, 229, 108, 229, 22)
    for x in range(33, 108, 8):
        line(x, 229, x, 238, 21)

    chinese_roof(23, 205, 92, 18, 12, lit=False)
    line(30, 201, 108, 201, 20)
    for x in range(34, 108, 9):
        rect(x, 198, x, 201, 21)

    poly([(35, 208), (61, 209), (59, 229), (49, 225), (41, 231), (35, 228)], 28)
    line(41, 211, 58, 212, 29)
    rect(46, 215, 51, 220, 24)


def draw_beacon_tower() -> None:
    poly([(574, 280), (580, 222), (636, 222), (639, 280)], 12)
    for y in range(229, 280, 7):
        line(580, y, 638, y, 7)
        for x in range(583 + (3 if (y // 7) % 2 else 0), 638, 14):
            line(x, y, x, y + 6, 13)
    rect(590, 244, 627, 279, 13)
    for x in (596, 613, 629):
        rect(x, 252, x + 5, 260, 21)
        rect(x + 1, 253, x + 4, 258, 26)

    rect(568, 210, 639, 224, 21)
    rect(574, 214, 637, 222, 22)
    for x in range(576, 638, 9):
        rect(x, 210, x + 1, 224, 21)
    line(565, 210, 639, 210, 20)

    rect(584, 187, 633, 211, 18)
    rect(590, 192, 627, 208, 21)
    for x in range(593, 627, 8):
        rect(x, 194, x + 3, 206, 26)
        rect(x + 1, 195, x + 2, 202, 27)
    chinese_roof(578, 188, 62, 15, 7, lit=False)

    rect(603, 169, 615, 174, 22)
    rect(605, 171, 613, 173, 21)

    line(631, 186, 631, 153, 21)
    poly([(632, 154), (639, 157), (636, 163), (632, 161)], 28)
    rect(633, 156, 635, 157, 29)


def draw_wall() -> None:
    rect(0, 268, W - 1, H - 1, 12)
    rect(0, 274, W - 1, H - 1, 13)
    rect(0, 272, W - 1, 275, 15)
    rect(0, 276, W - 1, 277, 7)

    for x in range(-8, W + 12, 28):
        rect(x, 258, x + 19, 274, 12)
        rect(x + 1, 258, x + 18, 259, 15)
        rect(x + 17, 258, x + 19, 274, 7)
        rect(x + 5, 264, x + 8, 265, 14)

    for row, y in enumerate(range(281, H, 7)):
        line(0, y, W - 1, y, 7)
        offset = 0 if row % 2 == 0 else 9
        for x in range(-offset, W, 18):
            line(x, y, x, min(H - 1, y + 6), 12)
            if rng.random() < 0.20:
                rect(x + rng.randrange(2, 12), y + 2, x + rng.randrange(12, 18), y + 2, 14)
            if rng.random() < 0.08:
                line(x + 4, y + 2, x + 5, y + 5, 7)

    for x in (126, 248, 382, 502):
        rect(x, 265, x + 8, 271, 21)
        rect(x + 2, 262, x + 6, 265, 26)
        rect(x + 3, 261, x + 5, 262, 27)
        rect(x + 1, 267, x + 7, 267, 22)
        line(x - 1, 269, x + 9, 269, 21)

    for x, banner_w in ((166, 17), (438, 14), (558, 12)):
        line(x, 254, x, 276, 21)
        poly([(x + 1, 255), (x + banner_w, 257), (x + banner_w - 3, 267), (x + 1, 265)], 28)
        rect(x + 5, 259, x + 7, 261, 24)

    for x in (110, 232, 362, 528):
        rect(x, 273, x + 7, 277, 7)
        s.circle(x + 8, 275, 3, 7, fill=True)
        line(x + 3, 278, x - 1, 281, 7)

    line(313, 289, 318, 294, 7)
    line(318, 294, 316, 300, 7)
    line(318, 294, 323, 298, 7)
    rect(321, 289, 323, 290, 14)
    line(282, 309, 311, 309, 14)


def draw_foreground() -> None:
    for y, x0, length in ((276, 0, 210), (286, 326, 220), (303, 160, 240), (316, 0, 150)):
        for _ in range(26):
            x = x0 + rng.randrange(-30, length)
            yy = y + rng.randrange(-2, 3)
            rect(x, yy, x + rng.randrange(8, 35), yy, 31)
        s.dither(max(0, x0 - 20), y - 3, min(W - 1, x0 + length), y + 3, "keep", 13, mix=0.24, pattern="bayer8")

    poly([(-8, 360), (-8, 326), (17, 313), (48, 321), (73, 343), (79, 360)], 12)
    poly([(0, 360), (0, 329), (19, 320), (42, 326), (61, 346), (65, 360)], 13)
    poly([(570, 360), (572, 329), (592, 316), (624, 322), (646, 342), (650, 360)], 12)
    poly([(588, 360), (590, 336), (607, 324), (629, 329), (646, 348), (650, 360)], 13)
    for _ in range(16):
        x = rng.choice((rng.randrange(4, 70), rng.randrange(580, 638)))
        y = rng.randrange(326, 353)
        rect(x, y, x + rng.randrange(1, 8), y, 14 if rng.random() < 0.5 else 7)

    for base_x in [rng.randrange(0, 85) for _ in range(40)] + [rng.randrange(555, 640) for _ in range(40)]:
        base_y = 358 + rng.randrange(-2, 4)
        height = rng.randrange(10, 48)
        lean = rng.randrange(-12, 13)
        line(base_x, base_y, base_x + lean // 2, base_y - height // 2, 7)
        line(base_x + lean // 2, base_y - height // 2, base_x + lean, base_y - height, 7)
        if rng.random() < 0.28:
            rect(base_x + lean, base_y - height - 2, base_x + lean, base_y - height, 21)

    for tx, top in ((13, 247), (619, 244)):
        line(tx, 356, tx + (3 if tx < 100 else -3), top, 7)
        for y in range(top + 8, 344, 10):
            direction = 1 if tx < 100 else -1
            span = rng.randrange(9, 27)
            line(tx, y, tx + direction * span, y - rng.randrange(2, 9), 7)
            for _ in range(3):
                bx = tx + direction * rng.randrange(4, span + 1)
                by = y - rng.randrange(2, 9)
                line(bx, by, bx + direction * rng.randrange(2, 6), by - rng.randrange(2, 6), 7)

    for y in range(334, H):
        density = 0.12 + (y - 334) / 26 * 0.45
        s.dither(0, y, W - 1, y, "keep", 0, mix=density, pattern="bayer4")
    for x in range(0, 34):
        s.dither(x, 0, x, H - 1, "keep", 0, mix=0.25 * (1 - x / 34), pattern="bayer4")
    for x in range(W - 34, W):
        s.dither(x, 0, x, H - 1, "keep", 0, mix=0.22 * ((x - (W - 34)) / 34), pattern="bayer4")


def draw_beacon_frames() -> None:
    for frame in range(6):
        if frame:
            s.add_frame(copy=False, duration=100)
        rng = random.Random(8100 + frame)

        for puff in range(18):
            phase = (puff / 18.0 + frame / 6.0 + 0.04) % 1.0
            x = 24 + int(math.sin(puff * 1.9 + frame * 0.9 + phase * 5.0) * (3.0 + phase * 4.0) + phase * 6.0)
            y = 29 - int(phase * 27.0)
            size = 1 + int(phase * 2.0)
            color = 5 if puff % 3 else 31
            rect(x - size, y, x + size, y, color)
            if size > 1:
                rect(x, y - 1, x + size - 1, y - 1, color)

        flick = (-2, 1, 0, -1, 2, 0)[frame]
        poly([
            (18, 45), (20, 40), (21, 36 + flick), (24, 29 - flick),
            (26, 34), (29, 31 + flick), (30, 39), (32, 45),
            (28, 43), (26, 47), (22, 43),
        ], 26)
        poly([
            (21, 45), (22, 40), (24, 35 + flick), (26, 39),
            (28, 36), (29, 43), (27, 45), (24, 46),
        ], 28)
        poly([(23, 45), (24, 39 - flick), (27, 42), (28, 45), (25, 47)], 27)
        rect(24, 34 - flick, 25, 37 - flick, 30)
        if frame in (1, 4):
            rect(17, 38, 18, 38, 25)
        if frame in (0, 3):
            rect(31, 35, 32, 35, 25)


def build() -> None:
    reset_canvas(W, H, 1558)
    draw_sky()
    draw_mountains()
    draw_sea()
    draw_skyline()
    draw_gatehouse()
    draw_beacon_tower()
    draw_wall()
    draw_foreground()

    s.save_png(str(MASTER), scale=1)
    s.save_png(str(OUTPUT), scale=2)
    s.save_png(str(PREVIEW), scale=2)
    s.save_swatch(str(SWATCH))
    s.stats()

    reset_canvas(W, 180, 2201)
    draw_cloud_layer()
    s.save_png(str(CLOUD_MASTER), scale=1)
    s.save_png(str(CLOUD_OUTPUT), scale=2)

    reset_canvas(W, 120, 3203)
    draw_wave_layer()
    s.save_png(str(WAVE_MASTER), scale=1)
    s.save_png(str(WAVE_OUTPUT), scale=2)

    reset_canvas(48, 48, 4105)
    draw_boat_sprite()
    s.save_png(str(BOAT_MASTER), scale=1)
    s.save_png(str(BOAT_OUTPUT), scale=2)

    reset_canvas(48, 48, 5107)
    draw_beacon_frames()
    s.tag("burn", 1, 6, "forward")
    s.save_spritesheet(str(FIRE_MASTER), layout="horizontal", scale=1, json_path=None)
    s.save_spritesheet(str(FIRE_OUTPUT), layout="horizontal", scale=2, json_path=None)
    s.stats()


if __name__ == "__main__":
    build()
