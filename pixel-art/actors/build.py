#!/usr/bin/env python3
"""128x128 animated Ming / wokou actors for WATCH · YONGCHANG.

Artwork is drawn pixel by pixel with skills/pixel-art-studio/scripts/pixelstudio.py.
The skeleton uses explicit shoulder, elbow, hip, knee, and ankle landmarks; walk and
attack frames are rebuilt per pose instead of stretching one chibi drawing.

Run from the project root:
    python3 pixel-art/actors/build.py
"""

from __future__ import annotations

import math
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "skills" / "pixel-art-studio" / "scripts"))

from pixelstudio import Sprite  # noqa: E402


CELL = 128
COLS = 16
ROWS = 16
FRAME_COUNT = 16
IDLE_FRAMES = (0, 1)
WALK_FRAMES = tuple(range(2, 10))
ATTACK_FRAMES = tuple(range(10, 16))
HEAD_Y = 25.0

INK = "#07090b"
SKIN = "#c9986c"
SKIN_D = "#8a5c40"
SKIN_L = "#e1b486"
SKIN_LL = "#f0cf9e"
HAIR = "#2a201b"
HAIR_D = "#15110f"
HAIR_L = "#4a3828"
CLOTH = "#85745a"
CLOTH_D = "#493d2e"
CLOTH_L = "#b6a17f"
BLACK = "#17191a"
BLACK_L = "#33383a"
RED = "#8d3028"
RED_D = "#521b1a"
RED_L = "#c6533e"
GOLD = "#b9853f"
GOLD_L = "#edbc62"
IRON = "#687572"
IRON_D = "#333e3d"
IRON_L = "#a5b1aa"
IRON_LL = "#d2dbcf"
BLUE = "#2f4c5d"
BLUE_D = "#1d2e39"
BLUE_L = "#4e7585"
GREEN = "#3d5a3c"
GREEN_D = "#233323"
GREEN_L = "#6f8d53"
LEATHER = "#5b3a24"
LEATHER_D = "#352116"
LEATHER_L = "#8b5b35"
WOOD = "#4e3527"
WHITE = "#ddd5c3"
PURPLE = "#4c3050"
PURPLE_D = "#2a1930"
PURPLE_L = "#805578"
BONE = "#c7bfa6"
FIRE = "#ff9b38"
FIRE_L = "#ffd36a"

PAL = [
    INK, SKIN, SKIN_D, SKIN_L, SKIN_LL, HAIR, HAIR_D, HAIR_L,
    CLOTH, CLOTH_D, CLOTH_L, BLACK, BLACK_L, RED, RED_D, RED_L,
    GOLD, GOLD_L, IRON, IRON_D, IRON_L, IRON_LL, BLUE, BLUE_D,
    BLUE_L, GREEN, GREEN_D, GREEN_L, LEATHER, LEATHER_D, LEATHER_L,
    WHITE, PURPLE, PURPLE_D, PURPLE_L, BONE, FIRE, FIRE_L,
]


class Canvas(Sprite):
    """Sprite with tuple-friendly rectangles for readable anatomy helpers."""

    def rect(self, *args: object) -> None:
        if len(args) == 3 and isinstance(args[0], tuple) and isinstance(args[1], tuple):
            x0, y0 = args[0]
            x1, y1 = args[1]
            super().rect(int(x0), int(y0), int(x1), int(y1), args[2])
            return
        super().rect(*args)


SPECS = {
    "scout": {
        "hat": "headband", "weapon": "knife", "shield": False, "banner": False,
        "cloth": LEATHER, "cloth_d": CLOTH_D, "armor": None, "bulk": 0,
        "beard": False, "cloth_l": LEATHER_L,
    },
    "ronin": {
        "hat": "ronin", "weapon": "sword", "shield": False, "banner": False,
        "cloth": CLOTH, "cloth_d": CLOTH_D, "armor": None, "bulk": 0,
        "beard": True, "cloth_l": CLOTH_L,
    },
    "gun": {
        "hat": "kasa", "weapon": "gun", "shield": False, "banner": False,
        "cloth": IRON_D, "cloth_d": BLACK, "armor": IRON_D, "bulk": 0,
        "beard": False, "cloth_l": IRON,
    },
    "shield": {
        "hat": "kasa", "weapon": "sword", "shield": True, "banner": False,
        "cloth": LEATHER, "cloth_d": CLOTH_D, "armor": IRON_D, "bulk": 1,
        "beard": False, "cloth_l": LEATHER_L,
    },
    "archer": {
        "hat": "headband", "weapon": "bow", "shield": False, "banner": False,
        "cloth": GREEN, "cloth_d": GREEN_D, "armor": None, "bulk": 0,
        "beard": False, "cloth_l": GREEN_L,
    },
    "banner": {
        "hat": "kasa", "weapon": "sword", "shield": False, "banner": True,
        "cloth": RED, "cloth_d": RED_D, "armor": IRON_D, "bulk": 0,
        "beard": True, "cloth_l": RED_L,
    },
    "pirate": {
        "hat": "bandana", "weapon": "sword", "shield": False, "banner": False,
        "cloth": BLUE, "cloth_d": BLUE_D, "armor": None, "bulk": 1,
        "beard": True, "cloth_l": BLUE_L,
    },
    "ninja": {
        "hat": "hood", "weapon": "knife", "shield": False, "banner": False,
        "cloth": BLACK, "cloth_d": BLACK_L, "armor": None, "bulk": 0,
        "beard": False, "cloth_l": BLACK_L,
    },
    "general": {
        "hat": "helmet", "weapon": "sword", "shield": False, "banner": False,
        "cloth": RED, "cloth_d": RED_D, "armor": IRON, "bulk": 1,
        "beard": True, "cloth_l": RED_L,
    },
    "daimyo": {
        "hat": "great_helmet", "weapon": "fan", "shield": False, "banner": False,
        "cloth": PURPLE, "cloth_d": PURPLE_D, "armor": GOLD, "bulk": 2,
        "beard": True, "cloth_l": PURPLE_L,
    },
    "ashigaru": {
        "hat": "kasa", "weapon": "spear", "shield": False, "banner": False,
        "cloth": CLOTH_D, "cloth_d": BLACK, "armor": IRON_D, "bulk": 0,
        "beard": False, "cloth_l": CLOTH,
    },
    "teppo_captain": {
        "hat": "helmet", "weapon": "gun", "shield": False, "banner": True,
        "cloth": LEATHER, "cloth_d": CLOTH_D, "armor": IRON, "bulk": 1,
        "beard": True, "cloth_l": LEATHER_L,
    },
    "sohei": {
        "hat": "monk", "weapon": "naginata", "shield": False, "banner": False,
        "cloth": CLOTH, "cloth_d": CLOTH_D, "armor": None, "bulk": 1,
        "beard": False, "cloth_l": CLOTH_L,
    },
    "oni": {
        "hat": "oni", "weapon": "dual", "shield": False, "banner": False,
        "cloth": RED, "cloth_d": BLACK, "armor": IRON_D, "bulk": 2,
        "beard": False, "cloth_l": RED_L,
    },
    "water_ghost": {
        "hat": "none", "weapon": "trident", "shield": False, "banner": False,
        "cloth": BLUE, "cloth_d": BLUE_L, "armor": None, "bulk": 0,
        "beard": True, "cloth_l": BLUE_L,
    },
    "bombardier": {
        "hat": "bandana", "weapon": "bomb", "shield": False, "banner": False,
        "cloth": CLOTH_D, "cloth_d": BLACK, "armor": LEATHER, "bulk": 1,
        "beard": False, "cloth_l": CLOTH,
    },
}


def add(a: tuple[float, float], b: tuple[float, float]) -> tuple[float, float]:
    return a[0] + b[0], a[1] + b[1]


def sub(a: tuple[float, float], b: tuple[float, float]) -> tuple[float, float]:
    return a[0] - b[0], a[1] - b[1]


def mul(a: tuple[float, float], k: float) -> tuple[float, float]:
    return a[0] * k, a[1] * k


def length(a: tuple[float, float]) -> float:
    return math.hypot(a[0], a[1])


def unit(a: tuple[float, float]) -> tuple[float, float]:
    n = length(a)
    return (1.0, 0.0) if n < 0.001 else a[0] / n, a[1] / n


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def pt(p: tuple[float, float]) -> tuple[int, int]:
    return int(round(p[0])), int(round(p[1]))


def solve_ik(
    root: tuple[float, float],
    target: tuple[float, float],
    upper: float,
    lower: float,
    bend: int,
) -> tuple[float, float]:
    delta = sub(target, root)
    dist = max(1.0, min(upper + lower - 0.5, length(delta)))
    direction = unit(delta)
    base = math.atan2(direction[1], direction[0])
    cosine = (upper * upper + dist * dist - lower * lower) / (2.0 * upper * dist)
    angle = math.acos(max(-1.0, min(1.0, cosine)))
    joint_angle = base + bend * angle
    return add(root, (math.cos(joint_angle) * upper, math.sin(joint_angle) * upper))


def polygon(s: Sprite, points: list[tuple[float, float]], color: str) -> None:
    s.polygon([pt(p) for p in points], color)


def torso_polygon(
    shoulder_x: float,
    shoulder_y: float,
    waist_y: float,
    bulk: int,
) -> list[tuple[float, float]]:
    return [
        (shoulder_x - 16 - bulk, shoulder_y + 1),
        (shoulder_x + 17 + bulk, shoulder_y),
        (shoulder_x + 12 + bulk // 2, shoulder_y + 11),
        (shoulder_x + 11, waist_y),
        (shoulder_x - 11, waist_y),
        (shoulder_x - 13 - bulk // 2, shoulder_y + 12),
    ]


def draw_segment(
    s: Sprite,
    a: tuple[float, float],
    b: tuple[float, float],
    w0: float,
    w1: float,
    base: str,
    dark: str,
    light: str,
) -> None:
    direction = sub(b, a)
    n = unit((-direction[1], direction[0]))
    outer = [
        add(a, mul(n, w0 / 2.0)),
        add(b, mul(n, w1 / 2.0)),
        add(b, mul(n, -w1 / 2.0)),
        add(a, mul(n, -w0 / 2.0)),
    ]
    polygon(s, outer, dark)
    inner0 = max(1.0, w0 - 2.0)
    inner1 = max(1.0, w1 - 2.0)
    inner = [
        add(a, mul(n, inner0 / 2.0)),
        add(b, mul(n, inner1 / 2.0)),
        add(b, mul(n, -inner1 / 2.0)),
        add(a, mul(n, -inner0 / 2.0)),
    ]
    polygon(s, inner, base)
    hl_n = n if n[0] + n[1] <= 0 else mul(n, -1.0)
    s.line(
        *pt(add(a, mul(hl_n, max(0.0, inner0 / 2.0 - 0.6)))),
        *pt(add(b, mul(hl_n, max(0.0, inner1 / 2.0 - 0.6)))),
        light,
    )


def draw_joint(
    s: Sprite,
    p: tuple[float, float],
    radius: int,
    base: str,
    dark: str,
    light: str,
) -> None:
    s.circle(*pt(p), radius, dark, fill=True)
    s.circle(*pt(p), max(1, radius - 1), base, fill=True)
    s.px(*pt(add(p, (-max(1, radius - 2), -1))), light)


def draw_foot(
    s: Sprite,
    ankle: tuple[float, float],
    base: str,
    dark: str,
    light: str,
    hero: bool = False,
) -> None:
    x, y = pt(ankle)
    if hero:
        polygon(
            s,
            [(x - 5, y - 2), (x + 6, y - 2), (x + 11, y + 1),
             (x + 10, y + 5), (x - 6, y + 5)],
            dark,
        )
        polygon(
            s,
            [(x - 4, y - 1), (x + 6, y - 1), (x + 9, y + 2),
             (x + 9, y + 4), (x - 5, y + 4)],
            base,
        )
        s.line(x - 4, y + 1, x + 7, y + 1, light)
        s.line(x - 5, y + 4, x + 9, y + 4, dark)
    else:
        polygon(
            s,
            [(x - 4, y - 1), (x + 6, y - 1), (x + 10, y + 2),
             (x + 8, y + 4), (x - 5, y + 4)],
            dark,
        )
        polygon(
            s,
            [(x - 3, y), (x + 5, y), (x + 8, y + 2),
             (x + 7, y + 3), (x - 4, y + 3)],
            base,
        )
        s.line(x - 3, y, x + 6, y, light)


def draw_leg(
    s: Sprite,
    hip: tuple[float, float],
    ankle: tuple[float, float],
    spec: dict,
    far: bool,
    hero: bool = False,
    bend: int = -1,
) -> None:
    knee = solve_ik(hip, ankle, 24.0, 25.0, bend)
    if hero:
        upper, lower = IRON_D, IRON
        upper_d, lower_d = INK, IRON_D
        upper_l, lower_l = IRON_L, IRON_L
        boot, boot_d, boot_l = IRON_D, INK, IRON_L
    else:
        upper = str(spec["cloth_d"]) if far else str(spec["cloth"])
        upper_d = INK
        upper_l = str(spec["cloth_l"])
        lower = str(spec["cloth_d"]) if far else str(spec["cloth"])
        lower_d = INK
        lower_l = str(spec["cloth_l"])
        if spec["armor"] is not None:
            lower = IRON_D if far else IRON
            lower_d = INK
            lower_l = IRON_L
        boot, boot_d, boot_l = LEATHER_D, INK, LEATHER_L
    hx, hy = pt(hip)
    s.circle(hx, hy, 5, upper_d, fill=True)
    s.circle(hx, hy, 4, upper, fill=True)
    s.px(hx - 1, hy - 2, upper_l)
    draw_segment(s, hip, knee, 12.0 if hero else 10.0, 9.0, upper, upper_d, upper_l)
    draw_segment(s, knee, ankle, 9.0, 7.0, lower, lower_d, lower_l)
    draw_joint(s, knee, 5 if hero else 4, lower, lower_d, lower_l)
    s.line(hx - 4, hy - 1, hx + 4, hy - 1, upper_d)
    s.line(hx - 3, hy, hx + 3, hy, upper_l)
    kx, ky = pt(knee)
    if hero or spec["armor"] is not None:
        plate = IRON if hero else str(spec["armor"])
        polygon(
            s,
            [(kx - 5, ky - 3), (kx + 5, ky - 3),
             (kx + 4, ky + 4), (kx - 4, ky + 4)],
            plate,
        )
        s.line(kx - 3, ky - 2, kx + 3, ky - 2, IRON_L)
        s.px(kx - 1, ky + 1, GOLD_L)
        s.px(kx + 2, ky + 1, GOLD_L)
    else:
        s.line(kx - 4, ky, kx + 4, ky, upper_d)
        s.line(kx - 3, ky - 1, kx + 3, ky - 1, upper_l)
    ax, ay = pt(ankle)
    s.circle(ax, ay, 3, lower_d, fill=True)
    s.circle(ax, ay, 2, lower, fill=True)
    s.line(ax - 4, ay - 1, ax + 4, ay - 1, lower_d)
    s.line(ax - 3, ay - 2, ax + 3, ay - 2, lower_l)
    draw_foot(s, ankle, boot, boot_d, boot_l, hero=hero)


def draw_arm(
    s: Sprite,
    shoulder: tuple[float, float],
    hand: tuple[float, float],
    spec: dict,
    far: bool,
    hero: bool = False,
    bend: int = 1,
) -> None:
    elbow = solve_ik(shoulder, hand, 18.0, 18.0, bend)
    if hero:
        sleeve, sleeve_d, sleeve_l = IRON_D, INK, IRON_L
        skin = SKIN_D if far else SKIN
    else:
        sleeve = str(spec["cloth_d"]) if far else str(spec["cloth"])
        sleeve_d = INK
        sleeve_l = str(spec["cloth_l"])
        skin = SKIN_D if far else SKIN
    armored = hero or spec["armor"] is not None
    if armored:
        forearm = IRON_D if far else IRON
        forearm_d = INK
        forearm_l = IRON_L
    else:
        forearm, forearm_d, forearm_l = skin, SKIN_D, SKIN_L
    sx, sy = pt(shoulder)
    s.circle(sx, sy, 5, sleeve_d, fill=True)
    s.circle(sx, sy, 4, sleeve, fill=True)
    s.px(sx - 1, sy - 2, sleeve_l)
    draw_segment(s, shoulder, elbow, 10.0, 8.0, sleeve, sleeve_d, sleeve_l)
    draw_segment(s, elbow, hand, 7.0, 5.0, forearm, forearm_d, forearm_l)
    draw_joint(s, elbow, 4, skin, SKIN_D, SKIN_L)
    s.line(sx - 4, sy, sx + 4, sy, sleeve_d)
    s.line(sx - 3, sy + 1, sx + 3, sy + 1, sleeve_l)
    ex, ey = pt(elbow)
    s.line(ex - 3, ey, ex + 3, ey, SKIN_D)
    s.line(ex - 2, ey - 1, ex + 2, ey - 1, SKIN_L)
    forearm_dir = unit(sub(hand, elbow))
    cuff_center = add(hand, mul(forearm_dir, -2.5))
    cuff_n = (-forearm_dir[1], forearm_dir[0])
    s.line(
        *pt(add(cuff_center, mul(cuff_n, -3.5))),
        *pt(add(cuff_center, mul(cuff_n, 3.5))),
        forearm_d,
    )
    s.line(
        *pt(add(cuff_center, mul(cuff_n, -2.5))),
        *pt(add(cuff_center, mul(cuff_n, 2.5))),
        forearm_l,
    )
    s.circle(*pt(hand), 3, SKIN_D, fill=True)
    s.circle(*pt(hand), 2, skin, fill=True)
    s.px(*pt(add(hand, (-1, -1))), SKIN_L)


def draw_neck(
    s: Sprite,
    hx: float,
    hy: float,
    shoulder_y: float,
    spec: dict,
    hero: bool,
) -> None:
    collar_top = shoulder_y - 4
    polygon(
        s,
        [(hx - 4, hy + 5), (hx + 5, hy + 5),
         (hx + 6, shoulder_y + 1), (hx - 5, shoulder_y + 1)],
        SKIN_D,
    )
    polygon(
        s,
        [(hx - 3, hy + 6), (hx + 4, hy + 6),
         (hx + 4, shoulder_y - 1), (hx - 4, shoulder_y - 1)],
        SKIN,
    )
    s.line(*pt((hx - 3, hy + 7)), *pt((hx + 4, hy + 7)), SKIN_L)
    armored = hero or spec["armor"] is not None
    collar_d = IRON_D if armored else str(spec["cloth_d"])
    collar = IRON if armored else str(spec["cloth"])
    collar_l = GOLD_L if armored else str(spec["cloth_l"])
    polygon(
        s,
        [(hx - 9, collar_top), (hx + 9, collar_top),
         (hx + 7, shoulder_y + 3), (hx - 7, shoulder_y + 3)],
        collar_d,
    )
    polygon(
        s,
        [(hx - 8, collar_top + 1), (hx + 8, collar_top + 1),
         (hx + 6, shoulder_y + 2), (hx - 6, shoulder_y + 2)],
        collar,
    )
    if armored:
        s.line(*pt((hx - 7, collar_top + 2)), *pt((hx + 7, collar_top + 2)), collar_l)
        s.line(*pt((hx - 5, collar_top + 4)), *pt((hx + 5, collar_top + 4)), collar_d)
    else:
        polygon(
            s,
            [(hx - 2, collar_top + 1), (hx + 2, collar_top + 1),
             (hx + 1, shoulder_y), (hx - 1, shoulder_y)],
            SKIN_D,
        )
        s.line(*pt((hx - 6, collar_top + 1)), *pt((hx - 1, shoulder_y + 2)), collar_l)
        s.line(*pt((hx + 6, collar_top + 1)), *pt((hx + 1, shoulder_y + 2)), collar_l)


def draw_cape(
    s: Sprite,
    upper_x: float,
    bob: int,
    phase: float,
    hero: bool = False,
) -> None:
    sway = math.sin(phase) * 3.0
    if hero:
        top_y = 40 + bob
        points = [
            (upper_x - 14, top_y), (upper_x + 19, top_y),
            (upper_x + 30 + sway, 92), (upper_x + 21 + sway, 88),
            (upper_x + 15, 98), (upper_x + 6 + sway, 89),
            (upper_x - 4, 96), (upper_x - 17 + sway, 87),
        ]
        polygon(s, points, RED_D)
        inner = [
            (upper_x - 12, top_y + 2), (upper_x + 16, top_y + 2),
            (upper_x + 26 + sway, 89), (upper_x + 18 + sway, 85),
            (upper_x + 12, 94), (upper_x + 4 + sway, 86),
            (upper_x - 3, 92), (upper_x - 14 + sway, 84),
        ]
        polygon(s, inner, RED)
        s.line(*pt((upper_x - 2, top_y + 10)), *pt((upper_x - 11 + sway, 82)), RED_L)
        s.line(*pt((upper_x + 12, top_y + 12)), *pt((upper_x + 14 + sway, 88)), RED_L)


def draw_banner(
    s: Sprite,
    upper_x: float,
    bob: int,
    phase: float,
    cloth: str,
    cloth_l: str,
) -> None:
    wave = math.sin(phase * 1.3) * 3.0
    pole_x = upper_x - 26
    s.rect(pt((pole_x, 20 + bob)), pt((pole_x + 2, 92)), LEATHER_D)
    s.line(pole_x + 1, 23 + bob, pole_x + 1, 88, LEATHER_L)
    polygon(
        s,
        [(pole_x + 2, 21 + bob), (pole_x + 31 + wave, 25 + bob),
         (pole_x + 29 + wave, 53 + bob), (pole_x + 20, 57 + bob),
         (pole_x + 12, 53 + bob), (pole_x + 2, 56 + bob)],
        RED_D,
    )
    polygon(
        s,
        [(pole_x + 4, 24 + bob), (pole_x + 28 + wave, 28 + bob),
         (pole_x + 26 + wave, 49 + bob), (pole_x + 18, 52 + bob),
         (pole_x + 11, 49 + bob), (pole_x + 4, 51 + bob)],
        cloth,
    )
    s.line(pole_x + 5, 27 + bob, pole_x + 27 + wave, 31 + bob, cloth_l)
    for y in (34, 42):
        s.rect(
            pt((pole_x + 7, y + bob)),
            pt((pole_x + 24 + int(wave), y + bob + 1)),
            GOLD,
        )
    s.rect(pt((pole_x + 14, 29 + bob)), pt((pole_x + 19, 44 + bob)), GOLD)
    s.rect(pt((pole_x + 16, 31 + bob)), pt((pole_x + 17, 42 + bob)), cloth)


def draw_pelvis(
    s: Sprite,
    sx: float,
    upper_x: float,
    waist_y: float,
    hip_y: float,
    spec: dict,
    hero: bool,
) -> None:
    cloth = RED if hero else str(spec["cloth"])
    cloth_d = RED_D if hero else str(spec["cloth_d"])
    cloth_l = RED_L if hero else str(spec["cloth_l"])
    skirt = [
        (upper_x - 11, waist_y - 1),
        (upper_x + 11, waist_y - 1),
        (sx + 15, hip_y + 5),
        (sx + 8, hip_y + 8),
        (sx, hip_y + 5),
        (sx - 8, hip_y + 8),
        (sx - 15, hip_y + 5),
    ]
    polygon(s, skirt, cloth_d)
    inner = [
        (upper_x - 9, waist_y + 1),
        (upper_x + 9, waist_y + 1),
        (sx + 12, hip_y + 4),
        (sx + 6, hip_y + 6),
        (sx, hip_y + 3),
        (sx - 6, hip_y + 6),
        (sx - 12, hip_y + 4),
    ]
    polygon(s, inner, cloth)
    s.line(*pt((sx - 2, waist_y + 3)), *pt((sx - 6, hip_y + 6)), cloth_d)
    s.line(*pt((sx + 3, waist_y + 3)), *pt((sx + 7, hip_y + 6)), cloth_l)
    if hero:
        s.line(*pt((sx, waist_y + 2)), *pt((sx, hip_y + 4)), RED_L)
        s.px(*pt((sx, hip_y + 4)), GOLD_L)
    if spec["armor"] is not None or hero:
        s.line(*pt((sx - 11, hip_y + 2)), *pt((sx + 11, hip_y + 2)), IRON_D)
        s.px(*pt((sx - 9, hip_y + 2)), GOLD)
        s.px(*pt((sx + 9, hip_y + 2)), GOLD)


def draw_torso(
    s: Sprite,
    sx: float,
    upper_x: float,
    shoulder_y: float,
    waist_y: float,
    bob: int,
    spec: dict,
    hero: bool = False,
) -> None:
    bulk = int(spec["bulk"])
    cloth = RED if hero else str(spec["cloth"])
    cloth_d = RED_D if hero else str(spec["cloth_d"])
    cloth_l = RED_L if hero else str(spec["cloth_l"])
    torso = torso_polygon(upper_x, shoulder_y, waist_y, bulk)
    polygon(s, torso, cloth_d)
    inner = [
        (upper_x - 14 - bulk, shoulder_y + 2),
        (upper_x + 15 + bulk, shoulder_y + 1),
        (upper_x + 10 + bulk // 2, shoulder_y + 12),
        (upper_x + 9, waist_y - 1),
        (upper_x - 9, waist_y - 1),
        (upper_x - 11 - bulk // 2, shoulder_y + 12),
    ]
    polygon(s, inner, cloth)

    if hero or spec["armor"] is not None:
        armor = IRON if hero else str(spec["armor"])
        armor_d = IRON_D if hero else IRON_D
        armor_l = IRON_L if hero else GOLD_L
        plate = [
            (upper_x - 13 - bulk, shoulder_y + 3),
            (upper_x + 14 + bulk, shoulder_y + 2),
            (upper_x + 9, waist_y - 3),
            (upper_x - 9, waist_y - 3),
        ]
        polygon(s, plate, armor_d)
        plate_inner = [
            (upper_x - 12 - bulk, shoulder_y + 4),
            (upper_x + 13 + bulk, shoulder_y + 3),
            (upper_x + 8, waist_y - 4),
            (upper_x - 8, waist_y - 4),
        ]
        polygon(s, plate_inner, armor)
        for y in range(int(shoulder_y) + 7, int(waist_y) - 3, 4):
            s.line(
                *pt((upper_x - 10 - bulk // 2, y)),
                *pt((upper_x + 11 + bulk // 2, y)),
                armor_d,
            )
            s.line(
                *pt((upper_x - 9 - bulk // 2, y + 1)),
                *pt((upper_x + 10 + bulk // 2, y + 1)),
                armor_l,
            )
            s.px(*pt((upper_x - 7, y + 1)), GOLD_L)
            s.px(*pt((upper_x + 8, y + 1)), GOLD_L)
    else:
        s.line(
            *pt((upper_x - 8, shoulder_y + 5)),
            *pt((upper_x + 5, waist_y - 3)),
            cloth_l,
        )
        s.line(
            *pt((upper_x + 8, shoulder_y + 5)),
            *pt((upper_x - 1, waist_y - 3)),
            cloth_d,
        )

    if hero:
        tabard = [
            (upper_x - 5, shoulder_y + 4), (upper_x + 6, shoulder_y + 4),
            (upper_x + 6, waist_y + 10), (upper_x, waist_y + 15),
            (upper_x - 6, waist_y + 10),
        ]
        polygon(s, tabard, RED_D)
        polygon(s, [add(p, (0, 1)) for p in tabard[0:3]] + [(upper_x, waist_y + 13),
                                                              (upper_x - 5, waist_y + 9)],
                RED)
        for y in (shoulder_y + 9, shoulder_y + 16, waist_y - 1):
            s.px(*pt((upper_x, y)), GOLD_L)

    belt_y = waist_y + 1
    s.rect(pt((upper_x - 12, belt_y)), pt((upper_x + 12, belt_y + 4)), LEATHER_D)
    s.rect(pt((upper_x - 11, belt_y + 1)), pt((upper_x + 11, belt_y + 2)), GOLD)
    s.px(*pt((upper_x, belt_y + 2)), GOLD_L)

    shoulder_pad = IRON if hero or spec["armor"] is not None else cloth_d
    shoulder_edge = GOLD if hero or spec["armor"] is not None else cloth_l
    polygon(
        s,
        [(upper_x - 20 - bulk, shoulder_y + 1), (upper_x - 10, shoulder_y - 3),
         (upper_x - 6, shoulder_y + 8), (upper_x - 17 - bulk, shoulder_y + 9)],
        shoulder_pad,
    )
    polygon(
        s,
        [(upper_x + 9, shoulder_y - 3), (upper_x + 20 + bulk, shoulder_y + 1),
         (upper_x + 17 + bulk, shoulder_y + 9), (upper_x + 7, shoulder_y + 8)],
        shoulder_pad,
    )
    s.line(*pt((upper_x - 19 - bulk, shoulder_y + 2)), *pt((upper_x - 9, shoulder_y - 1)),
           shoulder_edge)
    s.line(*pt((upper_x + 9, shoulder_y - 1)), *pt((upper_x + 19 + bulk, shoulder_y + 2)),
           shoulder_edge)


def draw_head(
    s: Sprite,
    hx: float,
    hy: float,
    spec: dict,
    hero: bool = False,
) -> None:
    hx_i, hy_i = pt((hx, hy))
    s.rect((hx_i - 4, hy_i + 7), (hx_i + 4, hy_i + 12), SKIN_D)
    s.ellipse(hx_i - 9, hy_i - 10, hx_i + 8, hy_i + 10, HAIR_D, fill=True)
    s.ellipse(hx_i - 8, hy_i - 9, hx_i + 8, hy_i + 9, HAIR, fill=True)
    s.ellipse(hx_i - 7, hy_i - 8, hx_i + 8, hy_i + 8, SKIN_D, fill=True)
    s.ellipse(hx_i - 6, hy_i - 8, hx_i + 7, hy_i + 7, SKIN, fill=True)
    s.ellipse(hx_i - 5, hy_i - 7, hx_i + 5, hy_i + 5, SKIN_L, fill=True)
    s.px(hx_i + 8, hy_i - 1, SKIN)
    s.px(hx_i + 9, hy_i, SKIN_D)
    s.px(hx_i + 8, hy_i + 1, SKIN_D)
    s.rect((hx_i - 8, hy_i - 5), (hx_i - 6, hy_i + 3), HAIR)
    s.rect((hx_i - 8, hy_i + 4), (hx_i - 6, hy_i + 9), HAIR_D)
    s.rect((hx_i - 2, hy_i - 1), (hx_i, hy_i), INK)
    s.rect((hx_i + 4, hy_i - 1), (hx_i + 6, hy_i), INK)
    s.px(hx_i - 2, hy_i - 1, WHITE)
    s.px(hx_i + 4, hy_i - 1, WHITE)
    s.line(hx_i - 3, hy_i - 3, hx_i, hy_i - 4, HAIR_D)
    s.line(hx_i + 4, hy_i - 4, hx_i + 7, hy_i - 3, HAIR_D)
    s.rect((hx_i + 7, hy_i + 3), (hx_i + 9, hy_i + 4), SKIN_D)
    s.line(hx_i + 3, hy_i + 4, hx_i + 7, hy_i + 4, SKIN_D)
    if spec["beard"] or hero:
        s.polygon(
            [(hx_i + 1, hy_i + 4), (hx_i + 8, hy_i + 4),
             (hx_i + 7, hy_i + 11), (hx_i + 4, hy_i + 8)],
            HAIR,
        )
        s.line(hx_i + 2, hy_i + 5, hx_i + 7, hy_i + 5, HAIR_D)
    if spec["beard"]:
        s.rect((hx_i, hy_i + 3), (hx_i + 6, hy_i + 4), HAIR_D)

    kind = spec["hat"]
    if hero:
        kind = "ming_helmet"
    if kind == "headband":
        s.rect((hx_i - 9, hy_i - 5), (hx_i + 9, hy_i - 3), spec["cloth_d"])
        s.rect((hx_i - 8, hy_i - 5), (hx_i + 8, hy_i - 4), spec["cloth"])
        s.line(hx_i + 7, hy_i - 4, hx_i + 13, hy_i, spec["cloth"])
        s.px(hx_i + 14, hy_i + 1, spec["cloth_l"])
    elif kind == "ronin":
        polygon(
            s,
            [(hx_i - 17, hy_i - 4), (hx_i + 17, hy_i - 4),
             (hx_i + 12, hy_i - 11), (hx_i - 11, hy_i - 11)],
            CLOTH_D,
        )
        polygon(
            s,
            [(hx_i - 15, hy_i - 6), (hx_i + 15, hy_i - 6),
             (hx_i + 11, hy_i - 10), (hx_i - 10, hy_i - 10)],
            CLOTH_L,
        )
        s.rect((hx_i - 1, hy_i - 13), (hx_i + 2, hy_i - 8), CLOTH)
        for x in (-9, -3, 3, 9):
            s.line(hx_i + x, hy_i - 6, hx_i, hy_i - 11, CLOTH_D)
    elif kind == "kasa":
        polygon(
            s,
            [(hx_i - 20, hy_i - 4), (hx_i + 20, hy_i - 4), (hx_i, hy_i - 16)],
            CLOTH_D,
        )
        polygon(
            s,
            [(hx_i - 17, hy_i - 5), (hx_i + 17, hy_i - 5), (hx_i, hy_i - 14)],
            CLOTH,
        )
        for x in (-11, -5, 5, 11):
            s.line(hx_i + x, hy_i - 5, hx_i, hy_i - 12, CLOTH_D)
        s.rect((hx_i - 2, hy_i - 17), (hx_i + 2, hy_i - 12), CLOTH_L)
    elif kind in {"helmet", "great_helmet"}:
        s.ellipse(hx_i - 11, hy_i - 14, hx_i + 11, hy_i - 4, IRON_D, fill=True)
        s.ellipse(hx_i - 10, hy_i - 13, hx_i + 10, hy_i - 5, IRON, fill=True)
        s.ellipse(hx_i - 8, hy_i - 12, hx_i + 6, hy_i - 8, IRON_L, fill=True)
        s.rect((hx_i - 11, hy_i - 5), (hx_i + 11, hy_i - 3), IRON_D)
        s.line(hx_i - 10, hy_i - 4, hx_i + 10, hy_i - 4, IRON_L)
        s.rect((hx_i - 12, hy_i - 3), (hx_i - 7, hy_i + 7), IRON_D)
        s.rect((hx_i + 7, hy_i - 3), (hx_i + 12, hy_i + 7), IRON_D)
        s.line(hx_i - 11, hy_i - 2, hx_i - 8, hy_i + 6, IRON_L)
        s.line(hx_i + 11, hy_i - 2, hx_i + 8, hy_i + 6, IRON_L)
        s.rect((hx_i - 2, hy_i - 19), (hx_i + 2, hy_i - 13), GOLD)
        s.rect((hx_i - 1, hy_i - 21), (hx_i + 1, hy_i - 17), GOLD_L)
        if kind == "great_helmet":
            polygon(
                s,
                [(hx_i - 5, hy_i - 13), (hx_i - 18, hy_i - 22),
                 (hx_i - 3, hy_i - 8)],
                GOLD,
            )
            polygon(
                s,
                [(hx_i + 5, hy_i - 13), (hx_i + 18, hy_i - 22),
                 (hx_i + 3, hy_i - 8)],
                GOLD,
            )
    elif kind == "ming_helmet":
        s.ellipse(hx_i - 11, hy_i - 15, hx_i + 11, hy_i - 4, IRON_D, fill=True)
        s.ellipse(hx_i - 10, hy_i - 14, hx_i + 10, hy_i - 5, IRON, fill=True)
        s.ellipse(hx_i - 8, hy_i - 13, hx_i + 6, hy_i - 8, IRON_L, fill=True)
        s.rect((hx_i - 12, hy_i - 5), (hx_i + 12, hy_i - 3), IRON_D)
        s.rect((hx_i - 11, hy_i - 4), (hx_i + 11, hy_i - 3), GOLD)
        s.rect((hx_i - 2, hy_i - 21), (hx_i + 2, hy_i - 14), GOLD)
        polygon(
            s,
            [(hx_i - 1, hy_i - 23), (hx_i + 1, hy_i - 23),
             (hx_i + 5, hy_i - 18), (hx_i, hy_i - 16),
             (hx_i - 5, hy_i - 18)],
            RED,
        )
        polygon(
            s,
            [(hx_i, hy_i - 22), (hx_i + 2, hy_i - 18),
             (hx_i, hy_i - 17), (hx_i - 2, hy_i - 18)],
            RED_L,
        )
        s.line(hx_i - 11, hy_i - 3, hx_i - 6, hy_i + 8, IRON_D)
        s.line(hx_i + 11, hy_i - 3, hx_i + 6, hy_i + 8, IRON_D)
    elif kind == "hood":
        s.ellipse(hx_i - 11, hy_i - 10, hx_i + 11, hy_i + 11, BLACK, fill=True)
        s.rect((hx_i - 7, hy_i - 1), (hx_i + 9, hy_i + 2), WHITE)
        s.rect((hx_i - 3, hy_i), (hx_i, hy_i + 1), INK)
        s.rect((hx_i + 5, hy_i), (hx_i + 8, hy_i + 1), INK)
        s.rect((hx_i - 10, hy_i + 8), (hx_i + 10, hy_i + 11), BLACK_L)
        s.rect((hx_i + 8, hy_i + 10), (hx_i + 11, hy_i + 19), RED)
    elif kind == "oni":
        s.ellipse(hx_i - 11, hy_i - 7, hx_i + 11, hy_i + 12, RED_D, fill=True)
        s.ellipse(hx_i - 9, hy_i - 6, hx_i + 10, hy_i + 11, RED, fill=True)
        s.rect((hx_i - 8, hy_i - 2), (hx_i + 9, hy_i + 1), WHITE)
        s.rect((hx_i - 4, hy_i - 1), (hx_i - 1, hy_i + 1), INK)
        s.rect((hx_i + 4, hy_i - 1), (hx_i + 8, hy_i + 1), INK)
        s.rect((hx_i - 2, hy_i + 6), (hx_i + 7, hy_i + 8), INK)
        for x in (-1, 2, 5):
            s.px(hx_i + x, hy_i + 6, WHITE)
        polygon(
            s,
            [(hx_i - 7, hy_i - 6), (hx_i - 17, hy_i - 17),
             (hx_i - 3, hy_i - 7)],
            GOLD,
        )
        polygon(
            s,
            [(hx_i + 7, hy_i - 6), (hx_i + 17, hy_i - 17),
             (hx_i + 3, hy_i - 7)],
            GOLD,
        )
    elif kind == "monk":
        s.rect((hx_i - 10, hy_i - 10), (hx_i + 10, hy_i + 1), CLOTH_D)
        s.rect((hx_i - 9, hy_i - 9), (hx_i + 9, hy_i - 3), CLOTH)
        s.line(hx_i - 12, hy_i - 4, hx_i + 12, hy_i - 4, CLOTH_L)
        s.rect((hx_i - 7, hy_i + 7), (hx_i + 7, hy_i + 10), CLOTH_D)
    elif kind == "bandana":
        s.rect((hx_i - 10, hy_i - 6), (hx_i + 10, hy_i - 3), RED_D)
        s.rect((hx_i - 9, hy_i - 6), (hx_i + 9, hy_i - 4), RED)
        s.line(hx_i + 9, hy_i - 4, hx_i + 15, hy_i - 8, RED)
        s.px(hx_i + 16, hy_i - 9, RED_L)


def draw_shield(
    s: Sprite,
    hand: tuple[float, float],
    phase: float,
) -> None:
    cx, cy = pt(hand)
    r = 17
    s.circle(cx, cy, r, LEATHER_D, fill=True)
    s.circle(cx, cy, r - 1, LEATHER, fill=True)
    s.circle(cx - 1, cy - 1, r - 4, LEATHER_L, fill=True)
    s.circle(cx, cy, 6, IRON_D, fill=True)
    s.circle(cx, cy, 4, IRON, fill=True)
    s.px(cx - 1, cy - 2, IRON_LL)
    for dx, dy in ((-11, -6), (9, -9), (-10, 9), (10, 8)):
        s.px(cx + dx, cy + dy, GOLD)
    for i in range(5):
        x = cx - 13 + i * 6
        y = cy + int(math.sin(phase + i) * 2)
        s.line(x, cy - 12, x + 2, cy + 12, LEATHER_D)


def draw_sword(
    s: Sprite,
    hand: tuple[float, float],
    angle: float,
    blade_length: float,
    kind: str = "sword",
) -> None:
    d = (math.cos(angle), math.sin(angle))
    n = (-d[1], d[0])
    h = hand
    if kind == "knife":
        blade_length = min(blade_length, 23)
        guard = 5
    elif kind == "dual":
        blade_length = min(blade_length, 30)
        guard = 5
    else:
        guard = 7
    base = add(h, mul(d, 2))
    tip = add(h, mul(d, blade_length))
    s.line(*pt(add(h, mul(d, -6))), *pt(h), LEATHER_D)
    s.line(*pt(add(h, mul(d, -5))), *pt(add(h, mul(d, -1))), LEATHER_L)
    s.line(*pt(add(h, mul(n, -guard))), *pt(add(h, mul(n, guard))), GOLD)
    s.line(*pt(add(h, mul(n, -guard + 1))), *pt(add(h, mul(n, guard - 1))), GOLD_L)
    blade = [
        add(base, mul(n, -1.5)), add(tip, mul(n, -0.5)),
        add(tip, mul(n, 0.5)), add(base, mul(n, 1.5)),
    ]
    polygon(s, blade, IRON_D)
    s.line(*pt(add(base, mul(n, -0.5))), *pt(add(tip, mul(n, 0))), IRON_L)
    s.line(*pt(add(base, mul(n, 0.5))), *pt(add(tip, mul(n, 0.5))), IRON)
    s.px(*pt(tip), WHITE)
    s.px(*pt(add(h, mul(d, -7))), GOLD)


def draw_polearm(
    s: Sprite,
    hand: tuple[float, float],
    angle: float,
    kind: str,
) -> None:
    d = (math.cos(angle), math.sin(angle))
    n = (-d[1], d[0])
    if kind == "spear":
        back, shaft, blade_len = 18, 37, 8
    elif kind == "naginata":
        back, shaft, blade_len = 20, 30, 15
    else:
        back, shaft, blade_len = 16, 34, 10
    start = add(hand, mul(d, -back))
    end = add(hand, mul(d, shaft))
    s.line(*pt(start), *pt(end), LEATHER_D)
    s.line(*pt(add(start, (1, 0))), *pt(add(end, (1, 0))), WOOD)
    s.line(*pt(add(start, n)), *pt(add(end, n)), LEATHER_L)
    if kind == "spear":
        polygon(
            s,
            [add(end, mul(n, -4)), add(end, mul(d, blade_len)),
             add(end, mul(n, 4))],
            IRON_L,
        )
        s.line(*pt(add(end, mul(d, 1))), *pt(add(end, mul(d, blade_len - 2))), IRON_LL)
        s.rect(pt(add(end, mul(n, -1))), pt(add(end, mul(n, 1))), GOLD)
    elif kind == "naginata":
        curve = [
            add(end, mul(n, -2)), add(add(end, mul(d, 7)), mul(n, -5)),
            add(add(end, mul(d, 14)), mul(n, -1)),
            add(add(end, mul(d, 9)), mul(n, 4)),
            add(end, mul(n, 2)),
        ]
        polygon(s, curve, IRON_L)
        s.line(*pt(add(end, mul(d, 2))), *pt(add(add(end, mul(d, 12)), mul(n, -2))), IRON_LL)
        s.rect(pt(add(end, mul(n, -1))), pt(add(end, mul(n, 1))), GOLD)
    else:
        s.line(*pt(add(end, mul(n, -6))), *pt(add(end, mul(n, 6))), IRON_L)
        for k in (-6, 0, 6):
            prong = add(end, mul(n, k))
            s.line(*pt(prong), *pt(add(prong, mul(d, 8))), IRON_L)
            s.px(*pt(add(prong, mul(d, 8))), WHITE)
        s.rect(pt(add(end, mul(n, -1))), pt(add(end, mul(n, 1))), BLUE_L)


def draw_gun(
    s: Sprite,
    hand: tuple[float, float],
    angle: float,
    trigger: int,
) -> None:
    d = (math.cos(angle), math.sin(angle))
    n = (-d[1], d[0])
    stock = add(hand, mul(d, -14))
    barrel = add(hand, mul(d, 38))
    s.line(*pt(stock), *pt(barrel), IRON_D)
    s.line(*pt(add(stock, n)), *pt(add(barrel, n)), IRON_L)
    s.line(*pt(add(stock, mul(d, 4))), *pt(add(barrel, mul(d, -2))), IRON)
    s.line(*pt(add(stock, mul(d, 2))), *pt(add(stock, mul(d, 13))), LEATHER)
    s.line(*pt(add(stock, mul(d, 2))), *pt(add(stock, mul(d, 13))), LEATHER_L)
    s.rect(*[pt(add(hand, mul(d, -1))), pt(add(hand, mul(d, 4)))], GOLD)
    if trigger >= 2:
        flash = add(barrel, mul(d, 4))
        s.circle(*pt(flash), 5, GOLD, fill=True)
        s.circle(*pt(flash), 3, FIRE, fill=True)
        s.px(*pt(add(flash, (1, -1))), WHITE)
        for k in (-1, 0, 1):
            s.line(
                *pt(add(flash, mul(n, k * 4))),
                *pt(add(flash, mul(n, k * 7 + 1))),
                FIRE_L,
            )
        s.px(*pt(add(barrel, mul(d, 8))), IRON_LL)


def draw_bow(
    s: Sprite,
    far_hand: tuple[float, float],
    near_hand: tuple[float, float],
    attack_stage: int,
    walking: bool,
) -> None:
    bx, by = far_hand
    top = (bx - 3, by - 24)
    bottom = (bx - 3, by + 24)
    s.line(*pt(top), *pt((bx + 5, by - 13)), LEATHER_L)
    s.line(*pt((bx + 5, by - 13)), *pt((bx + 7, by)), LEATHER)
    s.line(*pt((bx + 7, by)), *pt((bx + 5, by + 13)), LEATHER_L)
    s.line(*pt((bx + 5, by + 13)), *pt(bottom), LEATHER)
    s.line(*pt(top), *pt((bx + 2, by)), WHITE)
    s.line(*pt((bx + 2, by)), *pt(bottom), WHITE)
    draw_hand = near_hand if not walking else add(far_hand, (-5, 2))
    if attack_stage < 0:
        draw_hand = add(far_hand, (-5, 2))
    s.line(*pt((bx + 2, by)), *pt(draw_hand), WHITE)
    if attack_stage >= 2:
        arrow_tip = (bx + 38, by)
        s.line(*pt((bx + 2, by)), *pt(arrow_tip), IRON_L)
        s.px(*pt(arrow_tip), WHITE)
        polygon(
            s,
            [(bx + 2, by - 2), (bx + 8, by), (bx + 2, by + 2)],
            GOLD,
        )
    elif attack_stage >= 0:
        s.line(*pt(draw_hand), *pt((bx + 8, by)), IRON_L)
        s.px(*pt((bx + 8, by)), WHITE)


def draw_bomb(
    s: Sprite,
    hand: tuple[float, float],
    attack_stage: int,
) -> None:
    cx, cy = hand
    if attack_stage >= 2 and attack_stage <= 4:
        distance = (attack_stage - 1) * 9
        cx += distance
        cy -= int(math.sin((attack_stage - 1) * 0.7) * 12)
    s.circle(*pt((cx, cy)), 8, BLACK, fill=True)
    s.circle(*pt((cx - 1, cy - 1)), 6, BLACK_L, fill=True)
    s.circle(*pt((cx - 2, cy - 2)), 3, IRON_D, fill=True)
    s.line(*pt((cx + 5, cy - 6)), *pt((cx + 10, cy - 12)), GOLD)
    s.px(*pt((cx + 10, cy - 13)), FIRE_L)
    if attack_stage >= 2:
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            s.px(*pt((cx + math.cos(rad) * 12, cy + math.sin(rad) * 12)), FIRE)


def draw_fan(
    s: Sprite,
    hand: tuple[float, float],
    angle: float,
) -> None:
    d = (math.cos(angle), math.sin(angle))
    n = (-d[1], d[0])
    polygon(
        s,
        [hand,
         add(hand, add(mul(d, 16), mul(n, -12))),
         add(hand, add(mul(d, 22), mul(n, -5))),
         add(hand, add(mul(d, 23), mul(n, 4))),
         add(hand, add(mul(d, 15), mul(n, 11)))],
        GOLD,
    )
    for k in (-8, -3, 2, 7):
        s.line(*pt(add(hand, mul(d, 3))), *pt(add(hand, add(mul(d, 18), mul(n, k)))), GOLD_L)
    s.line(*pt(add(hand, mul(d, -4))), *pt(hand), LEATHER_D)


def draw_slash_arc(
    s: Sprite,
    center: tuple[float, float],
    start_deg: float,
    end_deg: float,
    radius: float,
    color: str,
) -> None:
    steps = max(4, int(abs(end_deg - start_deg) / 10))
    previous: tuple[float, float] | None = None
    for i in range(steps + 1):
        t = i / steps
        angle = math.radians(lerp(start_deg, end_deg, t))
        current = add(center, (math.cos(angle) * radius, math.sin(angle) * radius))
        if previous is not None:
            s.line(*pt(previous), *pt(current), color)
        previous = current


def draw_weapon(
    s: Sprite,
    spec: dict,
    ox: int,
    oy: int,
    near_hand: tuple[float, float],
    far_hand: tuple[float, float],
    weapon_angle: float,
    frame: int,
    attack_stage: int,
    phase: float,
    hero: bool = False,
) -> None:
    hand = add(near_hand, (ox, oy))
    far = add(far_hand, (ox, oy))
    kind = "sword" if hero else str(spec["weapon"])
    if spec["shield"]:
        draw_shield(s, far, phase)
    if kind == "bow":
        draw_bow(s, far, hand, attack_stage, 2 <= frame <= 9)
        return
    if kind == "gun":
        draw_gun(s, hand, weapon_angle, attack_stage)
        return
    if kind == "bomb":
        draw_bomb(s, hand, attack_stage)
        return
    if kind == "fan":
        draw_fan(s, hand, weapon_angle)
        if attack_stage >= 2:
            draw_slash_arc(s, hand, -70, 45, 33, GOLD_L)
        return
    if kind in {"spear", "naginata", "trident"}:
        draw_polearm(s, hand, weapon_angle, kind)
        if attack_stage >= 2:
            tip = add(hand, (math.cos(weapon_angle) * 46, math.sin(weapon_angle) * 46))
            s.px(*pt(tip), WHITE)
        return
    if kind == "dual":
        draw_sword(s, hand, weapon_angle, 32, "dual")
        draw_sword(s, far, weapon_angle + math.pi * 0.85, 28, "dual")
        if attack_stage >= 2:
            draw_slash_arc(s, hand, -55, 55, 35, WHITE)
            draw_slash_arc(s, far, 115, 220, 34, GOLD_L)
        return
    length = 40 if hero else (23 if kind == "knife" else 34)
    draw_sword(s, hand, weapon_angle, length, kind)
    if attack_stage >= 2:
        draw_slash_arc(
            s,
            hand,
            math.degrees(weapon_angle) - 55,
            math.degrees(weapon_angle) + 38,
            38 if hero else 33,
            WHITE if attack_stage in (2, 3) else GOLD_L,
        )


def idle_pose(bob: int) -> dict:
    return {
        "bob": bob,
        "lean": 0,
        "far_foot": (50.0, 116.0),
        "near_foot": (70.0, 116.0),
        "far_hand": (40.0, 71.0 + bob),
        "near_hand": (83.0, 71.0 + bob),
        "weapon_angle": math.radians(78),
        "phase": 0.0,
        "attack": -1,
    }


def walk_pose(frame_index: int, spec: dict) -> dict:
    phase = 2.0 * math.pi * frame_index / 8.0
    bob = 1 if frame_index in (2, 3, 6, 7) else 0

    def foot(offset: float) -> tuple[float, float]:
        p = (frame_index / 8.0 + offset) % 1.0
        if p < 0.62:
            x = lerp(8.0, -8.0, p / 0.62)
            lift = 0.0
        else:
            q = (p - 0.62) / 0.38
            x = lerp(-8.0, 8.0, q)
            lift = math.sin(math.pi * q) * 8.0
        return x, lift

    near_x, near_lift = foot(0.0)
    far_x, far_lift = foot(0.5)
    swing = math.cos(phase)
    lean = int(round(math.sin(phase) * 1.2))
    weapon_base = math.radians(78 if spec["weapon"] not in {"spear", "gun"} else 84)
    return {
        "bob": bob,
        "lean": lean,
        "far_foot": (52.0 + far_x, 116.0 - far_lift),
        "near_foot": (68.0 + near_x, 116.0 - near_lift),
        "far_hand": (40.0 + swing * 5.0, 72.0 + bob),
        "near_hand": (83.0 - swing * 5.0, 72.0 + bob),
        "weapon_angle": weapon_base + math.sin(phase) * math.radians(7),
        "phase": phase,
        "attack": -1,
    }


def attack_pose(stage: int, spec: dict, hero: bool) -> dict:
    bob = (-1, -2, 0, 1, 1, 0)[stage]
    lean = (0, -2, 4, 6, 4, 2)[stage]
    near_x = (70.0, 68.0, 79.0, 81.0, 76.0, 72.0)[stage]
    far_x = (50.0, 48.0, 46.0, 44.0, 46.0, 50.0)[stage]
    near_y = (63.0, 50.0, 62.0, 65.0, 74.0, 71.0)[stage]
    near_x_hand = (73.0, 65.0, 82.0, 84.0, 77.0, 73.0)[stage]
    far_x_hand = (42.0, 38.0, 47.0, 49.0, 44.0, 42.0)[stage]
    far_y_hand = (69.0, 66.0, 70.0, 72.0, 74.0, 72.0)[stage]
    kind = "sword" if hero else str(spec["weapon"])
    if kind in {"gun", "bow"}:
        angles = (math.radians(-10), math.radians(-15), math.radians(-2),
                  math.radians(0), math.radians(4), math.radians(8))
        near_x_hand = (62.0, 60.0, 66.0, 68.0, 63.0, 61.0)[stage]
        far_x_hand = (39.0, 37.0, 43.0, 45.0, 41.0, 40.0)[stage]
    elif kind == "spear":
        angles = (math.radians(55), math.radians(35), math.radians(2),
                  math.radians(0), math.radians(10), math.radians(35))
    elif kind == "naginata":
        angles = (math.radians(-70), math.radians(-105), math.radians(-18),
                  math.radians(2), math.radians(45), math.radians(70))
    elif kind == "trident":
        angles = (math.radians(45), math.radians(20), math.radians(0),
                  math.radians(0), math.radians(12), math.radians(40))
    elif kind == "bomb":
        angles = (math.radians(-80), math.radians(-105), math.radians(-20),
                  math.radians(0), math.radians(25), math.radians(55))
    elif kind == "fan":
        angles = (math.radians(-60), math.radians(-95), math.radians(-5),
                  math.radians(10), math.radians(55), math.radians(75))
    else:
        angles = (math.radians(-70), math.radians(-112), math.radians(-12),
                  math.radians(0), math.radians(48), math.radians(74))
    return {
        "bob": bob,
        "lean": lean,
        "far_foot": (far_x, 116.0),
        "near_foot": (near_x, 116.0),
        "far_hand": (far_x_hand, far_y_hand + bob),
        "near_hand": (near_x_hand, near_y + bob),
        "weapon_angle": angles[stage],
        "phase": stage * 0.8,
        "attack": stage,
    }


def pose_for(frame: int, spec: dict, hero: bool) -> dict:
    if frame in IDLE_FRAMES:
        return idle_pose(1 if frame == 1 else 0)
    if frame in WALK_FRAMES:
        return walk_pose(frame - 2, spec)
    return attack_pose(frame - 10, spec, hero)


def draw_actor(s: Sprite, ox: int, oy: int, spec: dict, frame: int, hero: bool = False) -> None:
    pose = pose_for(frame, spec, hero)
    bob = int(pose["bob"])
    lean = int(pose["lean"])
    sx = 60.0
    upper_x = 60.0 + lean
    hip_y = 71.0 + bob
    shoulder_y = 38.0 + bob
    waist_y = 61.0 + bob
    phase = float(pose["phase"])
    attack_stage = int(pose["attack"])
    bulk = int(spec["bulk"])

    s.ellipse(ox + 28, oy + 120, ox + 92, oy + 127, INK, fill=True)
    if hero:
        draw_cape(s, upper_x, bob, phase, hero=True)
    if spec["banner"]:
        draw_banner(s, upper_x, bob, phase, str(spec["cloth"]), str(spec["cloth_l"]))

    far_hip = (sx - 8.0, hip_y)
    near_hip = (sx + 8.0, hip_y)
    far_ankle = (float(pose["far_foot"][0]), float(pose["far_foot"][1]))
    near_ankle = (float(pose["near_foot"][0]), float(pose["near_foot"][1]))
    draw_leg(s, (ox + far_hip[0], oy + far_hip[1]),
             (ox + far_ankle[0], oy + far_ankle[1]), spec, True, hero)

    far_shoulder = (upper_x - 16.0 - bulk, shoulder_y + 2.0)
    near_shoulder = (upper_x + 17.0 + bulk, shoulder_y + 1.0)
    far_hand = (float(pose["far_hand"][0]), float(pose["far_hand"][1]))
    near_hand = (float(pose["near_hand"][0]), float(pose["near_hand"][1]))
    draw_arm(s, (ox + far_shoulder[0], oy + far_shoulder[1]),
             (ox + far_hand[0], oy + far_hand[1]), spec, True, hero, 1)

    draw_torso(s, sx, upper_x, shoulder_y, waist_y, bob, spec, hero)
    draw_pelvis(s, sx, upper_x, waist_y, hip_y, spec, hero)

    draw_leg(s, (ox + near_hip[0], oy + near_hip[1]),
             (ox + near_ankle[0], oy + near_ankle[1]), spec, False, hero)

    draw_neck(s, ox + upper_x + 2.0, oy + 18.0 + bob,
              oy + shoulder_y, spec, hero)
    draw_head(s, ox + upper_x + 2.0, oy + 18.0 + bob, spec, hero)
    draw_arm(s, (ox + near_shoulder[0], oy + near_shoulder[1]),
             (ox + near_hand[0], oy + near_hand[1]), spec, False, hero, -1)

    draw_weapon(
        s, spec, ox, oy, near_hand, far_hand,
        float(pose["weapon_angle"]), frame, attack_stage, phase, hero,
    )

HERO_SPEC = {
    "hat": "ming_helmet", "weapon": "sword", "shield": False, "banner": False,
    "cloth": RED, "cloth_d": RED_D, "armor": IRON, "bulk": 1,
    "beard": True, "cloth_l": RED_L,
}


def render_frame(spec: dict, frame: int, hero: bool = False) -> Image.Image:
    s = Canvas(CELL, CELL, palette=PAL)
    draw_actor(s, 0, -3, spec, frame, hero)
    s.outline(INK, where="outside")
    return s.composite()


def build_hero_strip() -> Image.Image:
    atlas = Image.new("RGBA", (CELL * FRAME_COUNT, CELL), (0, 0, 0, 0))
    for frame in range(FRAME_COUNT):
        atlas.alpha_composite(render_frame(HERO_SPEC, frame, True), (frame * CELL, 0))
    return atlas


def build_wokou_atlas() -> Image.Image:
    atlas = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for row, (_key, spec) in enumerate(SPECS.items()):
        for frame in range(FRAME_COUNT):
            atlas.alpha_composite(
                render_frame(spec, frame),
                (frame * CELL, row * CELL),
            )
    return atlas


def gif_durations() -> list[int]:
    return [380, 380] + [110] * 8 + [95, 80, 55, 85, 120, 150]


def save_gif(img: Image.Image, frame_count: int, path: Path, scale: int = 2) -> None:
    size = CELL * scale
    bg = Image.new("RGBA", (size, size), (14, 20, 24, 255))
    frames: list[Image.Image] = []
    for i in range(frame_count):
        cell = img.crop((i * CELL, 0, (i + 1) * CELL, CELL))
        cell = cell.resize((size, size), Image.Resampling.NEAREST)
        frame = bg.copy()
        frame.alpha_composite(cell)
        frames.append(frame.convert("RGB"))
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=gif_durations(),
        loop=0,
        disposal=2,
    )


def contact_sheet(
    atlas: Image.Image,
    names: list[str],
    frame: int,
    scale: int = 2,
) -> Image.Image:
    cell = CELL * scale
    gap = 10
    label_h = 20
    cols = 4
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new(
        "RGB",
        (cols * (cell + gap) + gap, rows * (cell + label_h + gap) + gap),
        (24, 29, 31),
    )
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, name in enumerate(names):
        row, col = divmod(index, cols)
        crop = atlas.crop((frame * CELL, index * CELL, (frame + 1) * CELL, (index + 1) * CELL))
        crop = crop.resize((cell, cell), Image.Resampling.NEAREST)
        x = gap + col * (cell + gap)
        y = gap + row * (cell + label_h + gap)
        sheet.paste(crop, (x, y), crop)
        draw.text((x + 2, y + cell + 4), f"{name}  row {index:02d}", fill=(225, 219, 205),
                  font=font)
    return sheet


def motion_sheet(strip: Image.Image, scale: int = 2) -> Image.Image:
    cell = CELL * scale
    cols = 8
    gap = 8
    sheet = Image.new("RGB", (cols * (cell + gap) + gap, 2 * (cell + gap) + gap),
                      (24, 29, 31))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for frame in range(FRAME_COUNT):
        row, col = divmod(frame, cols)
        crop = strip.crop((frame * CELL, 0, (frame + 1) * CELL, CELL))
        crop = crop.resize((cell, cell), Image.Resampling.NEAREST)
        x = gap + col * (cell + gap)
        y = gap + row * (cell + gap)
        sheet.paste(crop, (x, y), crop)
        draw.text((x + 2, y + 3), f"{frame:02d}", fill=(225, 219, 205), font=font)
    return sheet


def export_runtime(hero: Image.Image, wokou: Image.Image) -> None:
    target = ROOT / "game" / "assets" / "actors"
    target.mkdir(parents=True, exist_ok=True)
    hero.save(target / "hero_qi_jiguang.png")
    wokou.save(target / "wokou_atlas.png")


def image_stats(name: str, image: Image.Image) -> None:
    colors = image.getcolors(maxcolors=1_000_000) or []
    alpha_values = {pixel[3] for pixel in image.getdata()}
    print(
        f"{name}: {image.width}x{image.height}, "
        f"colors {len(colors)}, alpha {sorted(alpha_values)[:3]}..."
        f"{sorted(alpha_values)[-3:]}"
    )


def main() -> None:
    out = Path(__file__).resolve().parent
    hero = build_hero_strip()
    wokou = build_wokou_atlas()
    hero.save(out / "hero_qi_jiguang_1x.png")
    wokou.save(out / "wokou_atlas_1x.png")
    hero.resize((hero.width * 2, hero.height * 2), Image.Resampling.NEAREST).save(
        out / "hero_qi_jiguang_2x.png"
    )
    motion_sheet(hero, 2).save(out / "hero_motion_sheet.png")
    contact_sheet(wokou, list(SPECS.keys()), 12, 2).save(out / "wokou_contact.png")
    save_gif(hero, FRAME_COUNT, out / "hero_qi_jiguang_anim.gif", 2)
    for row, key in enumerate(SPECS):
        strip = Image.new("RGBA", (CELL * FRAME_COUNT, CELL), (0, 0, 0, 0))
        strip.alpha_composite(
            wokou.crop((0, row * CELL, CELL * FRAME_COUNT, (row + 1) * CELL))
        )
        save_gif(strip, FRAME_COUNT, out / f"wokou_{key}_anim.gif", 2)
    swatch = Image.new("RGBA", (len(PAL) * 8, 8), (0, 0, 0, 0))
    swatch_draw = ImageDraw.Draw(swatch)
    for index, color in enumerate(PAL):
        swatch_draw.rectangle((index * 8, 0, index * 8 + 7, 7), fill=color)
    swatch.resize((swatch.width * 4, 32), Image.Resampling.NEAREST).save(
        out / "actor_palette.png"
    )
    export_runtime(hero, wokou)
    print("hero:", CELL, "x", CELL, "x", FRAME_COUNT, "frames")
    print("wokou:", len(SPECS), "types x", FRAME_COUNT, "frames =", len(SPECS) * FRAME_COUNT)
    image_stats("hero", hero)
    image_stats("wokou", wokou)


if __name__ == "__main__":
    main()
