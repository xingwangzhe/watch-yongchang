#!/usr/bin/env python3
"""Bake CharacterForge cavalry strips: unridden mounts and mounted riders.

The horse is drawn as a parametric side-view rig. Four legs use a diagonal
trot cycle, the barrel breathes/bobs independently, and the rider's torso lags
one frame behind the saddle. Rider clothing, headgear, backgear and weapons
come from the existing CharacterForge layer data, so cavalry obeys the same
faction rules as the standing units.

Run from the project root:
    python3 pixel-art/character_forge/build_cavalry.py
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / "skills" / "pixel-art-studio" / "scripts"))

import build as forge  # noqa: E402
import cavalry_data as cd  # noqa: E402


CELL = forge.CELL
OUTPUT_ROOT = ROOT / "game" / "assets" / "units" / "forge" / "cavalry"
PREVIEW_ROOT = HERE
TAU = math.pi * 2.0


def harness_palette(faction: str | None) -> dict:
    if faction == "ming":
        return {
            "blanket": forge.RED,
            "blanket_d": forge.RED_D,
            "blanket_l": forge.RED_L,
            "trim": forge.GOLD,
            "trim_l": forge.GOLD_L,
            "saddle": forge.LEATHER,
            "saddle_d": forge.LEATHER_D,
            "saddle_l": forge.LEATHER_L,
        }
    if faction == "wokou":
        return {
            "blanket": "#263b42",
            "blanket_d": "#122127",
            "blanket_l": "#42606a",
            "trim": forge.IRON,
            "trim_l": forge.IRON_L,
            "saddle": "#3b2b25",
            "saddle_d": "#1c1512",
            "saddle_l": "#6b5041",
        }
    return {
        "blanket": forge.OCHRE,
        "blanket_d": forge.OCHRE_D,
        "blanket_l": forge.OCHRE_L,
        "trim": forge.GOLD,
        "trim_l": forge.GOLD_L,
        "saddle": forge.LEATHER,
        "saddle_d": forge.LEATHER_D,
        "saddle_l": forge.LEATHER_L,
    }


def clip_phase(clip: str, index: int) -> tuple[float, int, int, int]:
    if clip == "idle":
        phase = TAU * index / cd.IDLE_FRAMES
        body_dy = (0, -1, -1, 0)[index]
        head_dx = round(math.sin(phase) * 0.8)
        head_dy = (0, 0, 1, 0)[index]
        return phase, body_dy, head_dx, head_dy
    phase = TAU * index / cd.WALK_FRAMES
    body_dy = (0, -1, -2, -1, 0, -1, -2, -1)[index]
    head_dx = round(math.sin(phase - 0.25) * 1.1)
    head_dy = round(math.sin(phase - 0.7) * 1.0)
    return phase, body_dy, head_dx, head_dy


def horse_pose(clip: str, index: int) -> dict:
    phase, body_dy, head_dx, head_dy = clip_phase(clip, index)
    if clip == "idle":
        rider_dy = body_dy
    else:
        rider_dy = (0, -1, -2, -1, 0, -1, -2, -1)[(index - 1) % cd.WALK_FRAMES]
    return {
        "clip": clip,
        "index": index,
        "phase": phase,
        "body_dy": body_dy,
        "head_dx": head_dx,
        "head_dy": head_dy,
        "rider_dy": rider_dy,
        "tail_sway": math.sin(phase * 1.25) * 3.0,
    }


def leg_phase(pose: dict, kind: str, near: bool) -> float | None:
    if pose["clip"] == "idle":
        return None
    same_diagonal = (kind == "fore" and near) or (kind == "hind" and not near)
    return pose["phase"] if same_diagonal else pose["phase"] + math.pi


def leg_points(pose: dict, kind: str, near: bool) -> tuple[tuple, tuple, tuple, tuple]:
    dy = int(pose["body_dy"])
    phase = leg_phase(pose, kind, near)
    if phase is None:
        reach = 0.0
        lift = 0.0
    else:
        reach = 7.5 * math.cos(phase)
        lift = 8.0 * max(0.0, -math.sin(phase))
    if kind == "fore":
        root_x = 86.0 if near else 73.0
        root = (root_x, 83.0 + dy)
        knee = (root_x + reach * 0.28, 102.5 + dy - lift * 0.08)
        fetlock = (root_x + reach * 0.82 + 1.0, 115.0 - lift * 0.52)
        hoof = (root_x + reach + 3.0, 121.0 - lift)
        return root, knee, fetlock, hoof
    root_x = 52.0 if near else 38.0
    root = (root_x, 82.0 + dy)
    stifle = (root_x - 2.0 + reach * 0.08, 94.0 + dy)
    hock = (root_x - 5.0 + reach * 0.23, 103.0 + dy - lift * 0.08)
    fetlock = (root_x + reach * 0.72 + 1.0, 114.5 - lift * 0.5)
    hoof = (root_x + reach + 2.0, 121.0 - lift)
    return root, hock, fetlock, hoof


def draw_hoof(
    s: forge.Sprite,
    point: tuple[float, float],
    mount: dict,
    far: bool,
    lifted: bool,
) -> None:
    pal = mount["palette"]
    x, y = forge.pt(point)
    base = pal["hoof"]
    light = pal["hoof_light"] if not far else pal["coat_dark"]
    if lifted:
        polygon = [(x - 1, y - 3), (x + 3, y - 3), (x + 5, y), (x + 2, y + 2), (x - 1, y + 2)]
    else:
        polygon = [(x - 1, y - 2), (x + 3, y - 2), (x + 5, y + 1), (x + 3, y + 2), (x - 1, y + 2)]
    forge.polygon(s, polygon, base)
    forge.line(s, (x - 1, y - 2), (x + 3, y - 2), light)
    forge.line(s, (x - 1, y + 2), (x + 3, y + 2), forge.INK)


def draw_mount_leg(
    s: forge.Sprite,
    mount: dict,
    pose: dict,
    kind: str,
    near: bool,
) -> None:
    pal = mount["palette"]
    root, joint_a, joint_b, hoof = leg_points(pose, kind, near)
    far = not near
    if far:
        base = pal["coat_dark"]
        dark = forge.INK
        light = pal["coat"]
    else:
        base = pal["coat"]
        dark = pal["coat_dark"]
        light = pal["coat_light"]
    width_scale = 0.66 if far else 0.82
    if kind == "fore":
        forge.draw_segment(
            s, root, joint_a, 8.8 * width_scale, 5.7 * width_scale,
            base, dark, light, rim=False, edge=1.0,
        )
        forge.draw_segment(
            s, joint_a, joint_b, 5.4 * width_scale, 3.8 * width_scale,
            base, dark, light, rim=False, edge=1.0,
        )
        s.circle(*forge.pt(joint_a), 2, light, fill=True)
        forge.line(
            s,
            forge.add(joint_a, (-3, 0)),
            forge.add(joint_a, (3, 0)),
            dark,
        )
    else:
        forge.draw_segment(
            s, root, joint_a, 11.2 * width_scale, 8.0 * width_scale,
            base, dark, light, rim=False, edge=1.0,
        )
        forge.draw_segment(
            s, joint_a, joint_b, 7.4 * width_scale, 5.2 * width_scale,
            base, dark, light, rim=False, edge=1.0,
        )
        s.circle(*forge.pt(joint_a), 3 if near else 2, light, fill=True)
        forge.line(
            s,
            forge.add(joint_a, (-4, 0)),
            forge.add(joint_a, (3, 1)),
            dark,
        )
    sock = pal["sock"] if (not far or mount["id"] != "black") else pal["coat_dark"]
    forge.draw_segment(
        s, joint_b, hoof, 3.6 * width_scale, 2.8 * width_scale,
        sock, dark, light, rim=False, edge=1.0,
    )
    s.circle(*forge.pt(joint_b), 2 if near else 1, pal["coat_dark"], fill=True)
    s.px(*forge.pt(joint_b), light)
    draw_hoof(s, hoof, mount, far, lift_value(pose, kind, near) > 0.5)


def lift_value(pose: dict, kind: str, near: bool) -> float:
    phase = leg_phase(pose, kind, near)
    if phase is None:
        return 0.0
    return 7.0 * max(0.0, -math.sin(phase))


def draw_tail(s: forge.Sprite, mount: dict, pose: dict) -> None:
    pal = mount["palette"]
    dy = int(pose["body_dy"])
    sway = float(pose["tail_sway"])
    root = (38.0, 77.0 + dy)
    mid = (26.0 + sway * 0.45, 83.0 + dy)
    tip = (15.0 + sway, 96.0 + dy)
    forge.draw_segment(
        s, root, mid, 8.0, 5.8,
        pal["mane"], forge.INK, pal["mane_light"],
        rim=False, edge=1.0,
    )
    forge.draw_segment(
        s, mid, tip, 5.8, 1.8,
        pal["mane"], forge.INK, pal["mane_light"],
        rim=False, edge=1.0,
    )
    for offset, length in ((-3, 5), (0, 8), (3, 7)):
        strand = forge.add(tip, (offset, -2))
        end = forge.add(strand, (-2 + offset * 0.25, length))
        forge.line(s, strand, end, pal["mane_light"])
    forge.line(
        s,
        forge.add(mid, (-2, -3)),
        forge.add(tip, (2, 4)),
        pal["mane_light"],
    )


def draw_barrel(s: forge.Sprite, mount: dict, pose: dict) -> None:
    pal = mount["palette"]
    dy = int(pose["body_dy"])
    s.ellipse(29, 64 + dy, 103, 96 + dy, pal["coat_dark"], fill=True)
    s.ellipse(32, 66 + dy, 100, 94 + dy, pal["coat"], fill=True)
    s.ellipse(36, 67 + dy, 82, 83 + dy, pal["coat_mid"], fill=True)
    s.ellipse(41, 68 + dy, 74, 79 + dy, pal["coat_light"], fill=True)
    s.ellipse(49, 69 + dy, 67, 76 + dy, pal["coat_hi"], fill=True)
    s.ellipse(83, 71 + dy, 100, 92 + dy, pal["coat_mid"], fill=True)
    s.ellipse(87, 72 + dy, 97, 85 + dy, pal["coat_light"], fill=True)
    s.ellipse(44, 86 + dy, 91, 96 + dy, pal["coat_mid"], fill=True)
    s.ellipse(48, 91 + dy, 88, 96 + dy, pal["coat_dark"], fill=True)
    # Shoulder and haunch seams keep the barrel from reading as one soft blob.
    forge.line(s, (83, 70 + dy), (88, 80 + dy), pal["coat_dark"])
    forge.line(s, (89, 80 + dy), (86, 92 + dy), pal["coat_light"])
    forge.line(s, (40, 79 + dy), (48, 81 + dy), pal["coat_dark"])
    forge.line(s, (45, 86 + dy), (56, 88 + dy), pal["coat_light"])
    for x, y in ((47, 73), (58, 71), (69, 71), (80, 73)):
        s.px(x, y + dy, pal["coat_hi"])


def draw_neck(s: forge.Sprite, mount: dict, pose: dict) -> None:
    pal = mount["palette"]
    dy = int(pose["body_dy"])
    hx = int(pose["head_dx"])
    hy = int(pose["head_dy"])
    outer = [
        (82, 89 + dy), (83, 76 + dy), (88, 62 + dy), (96, 50 + dy),
        (103, 42 + dy + hy), (111, 38 + dy + hy), (118, 41 + dy + hy),
        (121, 46 + dy + hy), (117, 53 + dy + hy), (109, 57 + dy + hy),
        (103, 64 + dy), (99, 79 + dy), (96, 92 + dy),
    ]
    outer = [(x + hx * 0.35, y) for x, y in outer]
    forge.polygon(s, outer, pal["coat_dark"])
    inner = [
        (85, 88 + dy), (86, 76 + dy), (91, 63 + dy), (98, 52 + dy),
        (105, 45 + dy + hy), (112, 42 + dy + hy), (117, 44 + dy + hy),
        (118, 47 + dy + hy), (113, 52 + dy + hy), (106, 57 + dy + hy),
        (100, 68 + dy), (96, 81 + dy), (94, 91 + dy),
    ]
    inner = [(x + hx * 0.35, y) for x, y in inner]
    forge.polygon(s, inner, pal["coat"])
    forge.polygon(
        s,
        [
            (88, 74 + dy), (93, 62 + dy), (99, 52 + dy),
            (105, 45 + dy + hy), (111, 43 + dy + hy),
            (105, 52 + dy), (98, 65 + dy), (94, 79 + dy),
        ],
        pal["coat_mid"],
    )
    forge.line(s, (92, 66 + dy), (99, 55 + dy), pal["coat_light"])
    forge.line(s, (87, 86 + dy), (92, 89 + dy), pal["coat_dark"])


def draw_mane(s: forge.Sprite, mount: dict, pose: dict) -> None:
    pal = mount["palette"]
    dy = int(pose["body_dy"])
    hx = int(pose["head_dx"])
    hy = int(pose["head_dy"])
    wave = math.sin(float(pose["phase"])) * 1.0
    points = [
        (116 + hx, 40 + dy + hy),
        (109 + hx, 38 + dy + hy),
        (102 + hx, 43 + dy + hy),
        (95, 51 + dy),
        (88, 62 + dy),
        (82, 75 + dy),
        (79, 88 + dy),
    ]
    outer = []
    inner = []
    for index, (x, y) in enumerate(points):
        outer.append((x - 3 - (index % 2) * 2, y + 1))
        inner.append((x, y))
    outer.extend(reversed([(x + 5, y + 7) for x, y in points]))
    forge.polygon(s, outer, forge.INK)
    forge.polygon(s, points + [(87 + wave, 84 + dy), (93, 70 + dy), (101, 57 + dy), (110, 47 + dy)], pal["mane"])
    for index, (x, y) in enumerate(points[:-1]):
        nx, ny = points[index + 1]
        forge.line(s, (x - 2, y + 3), (nx - 1, ny + 3), pal["mane_light"])
        if index % 2 == 0:
            forge.line(s, (x - 5 - wave, y + 6), (x - 1, y + 4), pal["mane_light"])
    # Forelock hangs over the brow instead of leaving a hard neck/head seam.
    forge.polygon(
        s,
        [
            (108 + hx, 41 + dy + hy), (113 + hx, 38 + dy + hy),
            (118 + hx, 42 + dy + hy), (115 + hx, 49 + dy + hy),
            (111 + hx, 45 + dy + hy),
        ],
        pal["mane"],
    )
    forge.line(
        s,
        (111 + hx, 42 + dy + hy),
        (114 + hx, 47 + dy + hy),
        pal["mane_light"],
    )


def head_anchor(pose: dict) -> tuple[int, int]:
    return int(pose["head_dx"]), int(pose["body_dy"]) + int(pose["head_dy"])


def bit_point(pose: dict) -> tuple[float, float]:
    hx, hy = head_anchor(pose)
    return 121.0 + hx, 53.0 + hy


def draw_head(s: forge.Sprite, mount: dict, pose: dict) -> None:
    pal = mount["palette"]
    hx, hy = head_anchor(pose)
    outline = [
        (101 + hx, 45 + hy), (107 + hx, 39 + hy), (114 + hx, 39 + hy),
        (120 + hx, 43 + hy), (124 + hx, 49 + hy), (124 + hx, 54 + hy),
        (120 + hx, 57 + hy), (114 + hx, 57 + hy), (109 + hx, 60 + hy),
        (103 + hx, 58 + hy), (99 + hx, 52 + hy),
    ]
    forge.polygon(s, outline, pal["coat_dark"])
    inner = [
        (103 + hx, 46 + hy), (109 + hx, 42 + hy), (114 + hx, 42 + hy),
        (119 + hx, 45 + hy), (122 + hx, 50 + hy), (121 + hx, 53 + hy),
        (118 + hx, 55 + hy), (113 + hx, 55 + hy), (108 + hx, 57 + hy),
        (104 + hx, 55 + hy), (101 + hx, 51 + hy),
    ]
    forge.polygon(s, inner, pal["coat"])
    forge.polygon(
        s,
        [
            (104 + hx, 45 + hy), (111 + hx, 42 + hy),
            (115 + hx, 43 + hy), (109 + hx, 50 + hy),
            (102 + hx, 52 + hy),
        ],
        pal["coat_mid"],
    )
    forge.polygon(
        s,
        [
            (115 + hx, 49 + hy), (123 + hx, 49 + hy),
            (124 + hx, 54 + hy), (120 + hx, 57 + hy),
            (114 + hx, 56 + hy),
        ],
        pal["muzzle"],
    )
    # Ears and inner ear.
    forge.polygon(
        s,
        [(105 + hx, 44 + hy), (108 + hx, 33 + hy), (113 + hx, 42 + hy)],
        pal["coat_dark"],
    )
    forge.polygon(
        s,
        [(107 + hx, 42 + hy), (109 + hx, 36 + hy), (111 + hx, 42 + hy)],
        pal["mane"],
    )
    forge.polygon(
        s,
        [(113 + hx, 42 + hy), (116 + hx, 34 + hy), (120 + hx, 43 + hy)],
        pal["coat_dark"],
    )
    forge.polygon(
        s,
        [(115 + hx, 41 + hy), (117 + hx, 37 + hy), (118 + hx, 42 + hy)],
        pal["mane"],
    )
    # Cheek plane, eye, nostril and mouth.
    forge.polygon(
        s,
        [(107 + hx, 48 + hy), (114 + hx, 48 + hy), (113 + hx, 55 + hy), (107 + hx, 54 + hy)],
        pal["coat_mid"],
    )
    s.px(112 + hx, 49 + hy, forge.WHITE)
    s.px(113 + hx, 49 + hy, pal["eye"])
    s.px(113 + hx, 50 + hy, pal["eye"])
    s.px(121 + hx, 52 + hy, pal["coat_dark"])
    s.px(122 + hx, 52 + hy, forge.INK)
    forge.line(s, (117 + hx, 55 + hy), (122 + hx, 55 + hy), forge.INK)
    forge.line(s, (112 + hx, 56 + hy), (116 + hx, 58 + hy), pal["coat_dark"])
    forge.line(s, (106 + hx, 44 + hy), (110 + hx, 46 + hy), pal["coat_light"])
    # Bridle: cheek strap, noseband and bit ring.
    forge.line(s, (111 + hx, 43 + hy), (115 + hx, 56 + hy), forge.LEATHER_D)
    forge.line(s, (112 + hx, 43 + hy), (115 + hx, 55 + hy), forge.LEATHER_L)
    forge.line(s, (116 + hx, 48 + hy), (123 + hx, 48 + hy), forge.LEATHER_D)
    forge.line(s, (117 + hx, 47 + hy), (122 + hx, 47 + hy), forge.LEATHER_L)
    s.circle(121 + hx, 53 + hy, 2, forge.GOLD_D, fill=True)
    s.px(121 + hx, 53 + hy, forge.GOLD_L)


def draw_tack(s: forge.Sprite, mount: dict, pose: dict, faction: str | None) -> None:
    pal = mount["palette"]
    tack = harness_palette(faction)
    dy = int(pose["body_dy"])
    blanket_outer = [
        (51, 69 + dy), (82, 67 + dy), (88, 79 + dy),
        (83, 88 + dy), (77, 86 + dy), (71, 89 + dy),
        (65, 86 + dy), (58, 88 + dy), (49, 80 + dy),
    ]
    forge.polygon(s, blanket_outer, tack["blanket_d"])
    forge.polygon(
        s,
        [
            (53, 71 + dy), (80, 69 + dy), (85, 78 + dy),
            (81, 85 + dy), (75, 83 + dy), (69, 86 + dy),
            (63, 83 + dy), (57, 85 + dy), (51, 79 + dy),
        ],
        tack["blanket"],
    )
    forge.line(s, (54, 72 + dy), (79, 70 + dy), tack["blanket_l"])
    forge.line(s, (52, 83 + dy), (84, 85 + dy), tack["trim"])
    for x, y in ((58, 86), (65, 87), (72, 87), (79, 84)):
        s.px(x, y + dy, tack["trim"])
    # Girth wraps the barrel and visually ties pad to horse.
    forge.line(s, (69, 76 + dy), (67, 97 + dy), tack["saddle_d"])
    forge.line(s, (70, 76 + dy), (68, 96 + dy), tack["saddle_l"])
    s.rect(67, 84 + dy, 70, 86 + dy, tack["saddle_l"])
    s.px(67, 85 + dy, tack["trim"])
    # Curved saddle seat with a slight waist; no rectangular luggage silhouette.
    forge.polygon(
        s,
        [
            (55, 68 + dy), (58, 64 + dy), (62, 63 + dy),
            (66, 65 + dy), (72, 65 + dy), (77, 63 + dy),
            (82, 65 + dy), (84, 69 + dy), (81, 73 + dy),
            (76, 72 + dy), (68, 73 + dy), (61, 72 + dy),
        ],
        tack["saddle_d"],
    )
    forge.polygon(
        s,
        [
            (57, 68 + dy), (60, 66 + dy), (63, 65 + dy),
            (67, 67 + dy), (73, 67 + dy), (77, 65 + dy),
            (81, 67 + dy), (82, 69 + dy), (79, 71 + dy),
            (73, 70 + dy), (66, 71 + dy), (61, 70 + dy),
        ],
        tack["saddle"],
    )
    forge.line(s, (60, 66 + dy), (66, 66 + dy), tack["saddle_l"])
    forge.line(s, (73, 66 + dy), (79, 67 + dy), tack["saddle_l"])
    forge.line(s, (61, 70 + dy), (78, 70 + dy), tack["saddle_d"])
    forge.polygon(
        s,
        [(79, 63 + dy), (83, 65 + dy), (81, 69 + dy), (78, 67 + dy)],
        tack["saddle_d"],
    )
    forge.polygon(
        s,
        [(54, 64 + dy), (58, 61 + dy), (60, 65 + dy), (58, 68 + dy)],
        tack["saddle_d"],
    )
    s.px(81, 64 + dy, tack["trim"])
    # Stirrup leather and iron; the near rider boot covers the upper loop.
    forge.line(s, (79, 74 + dy), (86, 91 + dy), tack["saddle_d"])
    forge.line(s, (80, 74 + dy), (87, 90 + dy), tack["saddle_l"])
    forge.line(s, (84, 91 + dy), (89, 94 + dy), forge.IRON_D)
    forge.line(s, (89, 94 + dy), (91, 90 + dy), forge.IRON_D)
    s.px(84, 92 + dy, forge.IRON_L)
    s.px(90, 92 + dy, forge.IRON_L)


def draw_horse_layer(mount: dict, pose: dict, faction: str | None) -> Image.Image:
    s = forge.Canvas(CELL, CELL)
    draw_tail(s, mount, pose)
    draw_mount_leg(s, mount, pose, "hind", False)
    draw_mount_leg(s, mount, pose, "fore", False)
    draw_barrel(s, mount, pose)
    draw_mount_leg(s, mount, pose, "hind", True)
    draw_mount_leg(s, mount, pose, "fore", True)
    draw_neck(s, mount, pose)
    draw_mane(s, mount, pose)
    draw_head(s, mount, pose)
    draw_tack(s, mount, pose, faction)
    s.outline(forge.OUTLINE, where="outside")
    return s.composite()


def draw_ground_shadow(clip: str, index: int) -> Image.Image:
    s = forge.Canvas(CELL, CELL)
    if clip == "idle":
        widths = ((24, 108), (26, 106), (25, 107), (23, 109))
    else:
        widths = ((21, 110), (24, 108), (27, 106), (25, 107),
                  (22, 109), (24, 108), (27, 106), (25, 107))
    x0, x1 = widths[index]
    s.ellipse(x0, 119, x1, 126, "#0b0e10", fill=True)
    s.ellipse(x0 + 6, 120, x1 - 6, 125, "#151b1e", fill=True)
    s.ellipse(x0 + 13, 121, x1 - 13, 124, "#20272a", fill=True)
    return s.composite()


def rider_leg_points(pose: dict, side: str) -> tuple[tuple, tuple, tuple, tuple]:
    lean = float(pose["lean"])
    upper_x = 60.0 + lean
    far = side == "far"
    dy = int(pose["rider_dy"]) if "rider_dy" in pose else int(pose["bob"])
    hip = (upper_x - 4.0, 67.0 + dy) if far else (upper_x + 5.0, 68.0 + dy)
    knee = (upper_x + 15.0, 78.0 + dy) if far else (upper_x + 21.0, 79.0 + dy)
    ankle = (upper_x + 25.0, 91.0 + dy) if far else (upper_x + 31.0, 93.0 + dy)
    toe = (ankle[0] + 7.0, ankle[1] + 2.0)
    return hip, knee, ankle, toe


def draw_rider_leg(
    s: forge.Sprite,
    pose: dict,
    outfit: dict,
    side: str,
) -> None:
    far = side == "far"
    hip, knee, ankle, toe = rider_leg_points(pose, side)
    cloth, cloth_d, cloth_l = forge._cloth_colors(outfit, far)
    metal, metal_d, metal_l = forge._metal_colors(outfit, far)
    forge.draw_segment(
        s, hip, knee, 11.5, 9.0,
        cloth, cloth_d, cloth_l,
        rim=False, edge=1.0,
    )
    if outfit["legs"] == "greaves":
        forge.draw_segment(
            s, knee, ankle, 8.5, 6.2,
            metal, metal_d, metal_l,
            rim=False, edge=1.0,
        )
        forge.line(
            s,
            forge.add(knee, (-4, 0)),
            forge.add(knee, (4, 1)),
            metal_d,
        )
        forge.line(
            s,
            forge.add(knee, (-3, -1)),
            forge.add(knee, (3, 0)),
            metal_l,
        )
    else:
        forge.draw_segment(
            s, knee, ankle, 8.2, 6.1,
            cloth, cloth_d, cloth_l,
            rim=False, edge=1.0,
        )
        if str(outfit.get("style", "")) == "scout":
            band = forge.add(knee, forge.mul(forge.sub(ankle, knee), 0.55))
            forge.line(s, forge.add(band, (-3, 0)), forge.add(band, (3, 1)), forge.LEATHER)
            forge.line(s, forge.add(band, (-3, 1)), forge.add(band, (3, 2)), forge.LEATHER_L)
    s.circle(*forge.pt(knee), 4 if not far else 3, cloth_l if outfit["legs"] != "greaves" else metal_l, fill=True)
    forge.line(
        s,
        forge.add(hip, (-2, 1)),
        forge.add(knee, (-2, -1)),
        cloth_d,
    )
    draw_riding_boot(s, ankle, toe, far)
    if not far:
        # Stirrup sits outside the boot without swallowing the toe.
        x, y = forge.pt(ankle)
        forge.line(s, (x + 3, y + 2), (x + 7, y + 4), forge.IRON_D)
        forge.line(s, (x + 7, y + 4), (x + 10, y), forge.IRON_D)
        s.px(x + 4, y + 3, forge.IRON_L)
        s.px(x + 9, y + 2, forge.IRON_L)


def draw_riding_boot(
    s: forge.Sprite,
    ankle: tuple[float, float],
    toe: tuple[float, float],
    far: bool,
) -> None:
    base = forge.LEATHER if not far else forge.LEATHER_D
    dark = forge.LEATHER_D if not far else forge.INK
    light = forge.LEATHER_L if not far else forge.LEATHER
    forge.draw_segment(s, ankle, toe, 7.0, 5.2, base, dark, light, rim=False, edge=1.0)
    x, y = forge.pt(toe)
    forge.polygon(
        s,
        [(x - 2, y - 3), (x + 4, y - 2), (x + 4, y + 2), (x - 2, y + 3)],
        dark,
    )
    forge.polygon(
        s,
        [(x - 1, y - 2), (x + 3, y - 1), (x + 3, y + 1), (x - 1, y + 2)],
        base,
    )
    forge.line(s, (x - 1, y - 1), (x + 3, y - 1), light)


def mounted_shoulder(pose: dict, side: str) -> tuple[float, float]:
    upper_x = 60.0 + float(pose["lean"])
    return (
        upper_x + (10.5 if side == "near" else -10.5),
        float(pose["shoulder_y"]) + 2.0,
    )


def draw_mounted_torso(
    s: forge.Canvas,
    pose: dict,
    outfit: dict,
) -> None:
    upper_x = 60.0 + float(pose["lean"])
    shoulder_y = float(pose["shoulder_y"])
    waist_y = float(pose["waist_y"])
    hip_y = float(pose["hip_y"])
    cloth, cloth_d, cloth_l = forge._cloth_colors(outfit, False)
    metal, metal_d, metal_l = forge._metal_colors(outfit, False)
    style = str(outfit.get("style", ""))
    outer = [
        (upper_x - 12, shoulder_y + 5),
        (upper_x - 7, shoulder_y),
        (upper_x + 7, shoulder_y),
        (upper_x + 12, shoulder_y + 4),
        (upper_x + 10, waist_y),
        (upper_x + 8, hip_y + 1),
        (upper_x - 8, hip_y + 1),
        (upper_x - 10, waist_y),
    ]
    forge.polygon(s, outer, cloth_d)
    inner = [
        (upper_x - 10, shoulder_y + 5),
        (upper_x - 6, shoulder_y + 2),
        (upper_x + 6, shoulder_y + 2),
        (upper_x + 10, shoulder_y + 5),
        (upper_x + 8, waist_y - 1),
        (upper_x + 7, hip_y),
        (upper_x - 7, hip_y),
        (upper_x - 8, waist_y - 1),
    ]
    forge.polygon(s, inner, cloth)
    if outfit["armored"]:
        plate = [
            (upper_x - 8, shoulder_y + 5),
            (upper_x + 8, shoulder_y + 4),
            (upper_x + 7, waist_y - 1),
            (upper_x - 7, waist_y - 1),
        ]
        forge.polygon(s, plate, metal_d)
        forge.polygon(
            s,
            [
                (upper_x - 7, shoulder_y + 6),
                (upper_x + 7, shoulder_y + 5),
                (upper_x + 6, waist_y - 2),
                (upper_x - 6, waist_y - 2),
            ],
            metal,
        )
        for row, y in enumerate(range(int(shoulder_y) + 9, int(waist_y) - 2, 4)):
            forge.line(s, (upper_x - 6, y), (upper_x + 6, y), metal_d)
            forge.line(s, (upper_x - 5, y + 1), (upper_x + 5, y + 1), metal_l)
            if row % 2 == 0:
                s.px(int(upper_x - 4), y + 1, outfit["accent"])
                s.px(int(upper_x + 4), y + 1, outfit["accent"])
        if style == "field":
            forge.polygon(
                s,
                [
                    (upper_x - 6, shoulder_y + 5),
                    (upper_x, shoulder_y + 5),
                    (upper_x, shoulder_y + 13),
                    (upper_x - 6, shoulder_y + 11),
                ],
                "#d4c59b",
            )
            forge.line(
                s,
                (upper_x - 5, shoulder_y + 6),
                (upper_x - 1, shoulder_y + 6),
                "#eee0b6",
            )
            forge.line(
                s,
                (upper_x - 8, shoulder_y + 8),
                (upper_x + 6, waist_y - 4),
                outfit["accent"],
            )
        elif str(outfit.get("armor_style", "")) == "qijia":
            s.rect(
                int(upper_x - 3),
                int(shoulder_y + 9),
                int(upper_x + 3),
                int(shoulder_y + 14),
                forge.GOLD_D,
            )
            s.rect(
                int(upper_x - 2),
                int(shoulder_y + 10),
                int(upper_x + 2),
                int(shoulder_y + 13),
                forge.GOLD_L,
            )
        elif str(outfit.get("armor_style", "")) == "domaru":
            for y in (shoulder_y + 10, waist_y - 4):
                forge.line(s, (upper_x - 7, y), (upper_x + 7, y), forge.RED_L)
                forge.line(s, (upper_x - 6, y + 1), (upper_x + 6, y + 1), forge.RED_D)
        elif str(outfit.get("armor_style", "")) == "haramaki":
            s.rect(
                int(upper_x - 2),
                int(shoulder_y + 6),
                int(upper_x + 2),
                int(waist_y - 2),
                cloth,
            )
            forge.line(
                s,
                (upper_x - 1, shoulder_y + 7),
                (upper_x - 1, waist_y - 3),
                cloth_l,
            )
            forge.line(
                s,
                (upper_x + 1, shoulder_y + 7),
                (upper_x + 1, waist_y - 3),
                cloth_d,
            )
    else:
        forge.polygon(
            s,
            [
                (upper_x - 9, shoulder_y + 6),
                (upper_x - 3, shoulder_y + 3),
                (upper_x - 4, waist_y - 2),
                (upper_x - 8, waist_y - 1),
            ],
            cloth_l,
        )
        forge.polygon(
            s,
            [
                (upper_x + 3, shoulder_y + 3),
                (upper_x + 10, shoulder_y + 6),
                (upper_x + 8, waist_y - 1),
                (upper_x + 4, waist_y - 2),
            ],
            cloth_d,
        )
        if style == "dragon":
            s.circle(int(upper_x), int(shoulder_y + 12), 3, forge.GOLD_D, fill=True)
            s.circle(int(upper_x), int(shoulder_y + 12), 2, forge.GOLD, fill=True)
            s.px(int(upper_x), int(shoulder_y + 12), forge.RED)
            forge.line(
                s,
                (upper_x - 8, shoulder_y + 18),
                (upper_x + 8, shoulder_y + 18),
                forge.GOLD,
            )
        elif style == "scout":
            forge.line(
                s,
                (upper_x - 7, shoulder_y + 9),
                (upper_x + 6, waist_y - 5),
                forge.LEATHER,
            )
            forge.line(
                s,
                (upper_x - 6, shoulder_y + 10),
                (upper_x + 7, waist_y - 4),
                forge.LEATHER_L,
            )
            forge.line(
                s,
                (upper_x - 8, shoulder_y + 17),
                (upper_x + 8, shoulder_y + 17),
                forge.GREEN,
            )
    belt_y = waist_y + 1
    s.rect(
        int(upper_x - 9),
        int(belt_y),
        int(upper_x + 9),
        int(belt_y + 3),
        forge.LEATHER_D,
    )
    s.rect(
        int(upper_x - 8),
        int(belt_y + 1),
        int(upper_x + 8),
        int(belt_y + 2),
        outfit["accent"],
    )
    s.rect(
        int(upper_x - 2),
        int(belt_y),
        int(upper_x + 2),
        int(belt_y + 2),
        outfit["accent_l"],
    )


def draw_mounted_arm(
    s: forge.Canvas,
    pose: dict,
    side: str,
    skin: dict,
    outfit: dict,
) -> None:
    far = side == "far"
    shoulder = mounted_shoulder(pose, side)
    hand = tuple(pose[f"{side}_hand"])
    elbow = forge.solve_joint(
        shoulder,
        hand,
        14.0,
        15.0,
        (-4.0, 7.0) if far else (4.0, 7.0),
    )
    cloth, cloth_d, cloth_l = forge._cloth_colors(outfit, far)
    metal, metal_d, metal_l = forge._metal_colors(outfit, far)
    skin_base, skin_dark, skin_light = forge._skin_colors(skin, far)
    if outfit["sleeve"] == "long":
        upper_base, upper_dark, upper_light = cloth, cloth_d, cloth_l
    elif outfit["armored"]:
        upper_base, upper_dark, upper_light = metal, metal_d, metal_l
    else:
        upper_base, upper_dark, upper_light = cloth, cloth_d, cloth_l
    forge.draw_segment(
        s,
        shoulder,
        elbow,
        8.5,
        6.5,
        upper_base,
        upper_dark,
        upper_light,
        rim=False,
        edge=1.0,
    )
    if outfit["sleeve"] == "long":
        lower_base, lower_dark, lower_light = cloth, cloth_d, cloth_l
    elif outfit["armored"]:
        lower_base, lower_dark, lower_light = metal, metal_d, metal_l
    else:
        lower_base, lower_dark, lower_light = skin_base, skin_dark, skin_light
    forge.draw_segment(
        s,
        elbow,
        hand,
        6.5,
        4.8,
        lower_base,
        lower_dark,
        lower_light,
        rim=False,
        edge=1.0,
    )
    s.circle(*forge.pt(elbow), 3 if not far else 2, lower_base, fill=True)
    forge.line(
        s,
        forge.add(elbow, (-2, 0)),
        forge.add(elbow, (2, 0)),
        lower_dark,
    )
    cuff = forge.add(hand, forge.mul(forge.unit(forge.sub(hand, elbow)), -2.0))
    forge.line(
        s,
        forge.add(cuff, (-2.5, -2.0)),
        forge.add(cuff, (2.5, 2.0)),
        outfit["accent"],
    )
    s.circle(*forge.pt(hand), 3, skin_base, fill=True)
    forge.line(
        s,
        forge.add(hand, (-2, 1)),
        forge.add(hand, (2, 1)),
        skin_dark,
    )
    forge.line(
        s,
        forge.add(hand, (-1, -2)),
        forge.add(hand, (2, -2)),
        skin_light,
    )


def draw_mounted_pauldron(
    s: forge.Canvas,
    pose: dict,
    side: str,
    outfit: dict,
) -> None:
    far = side == "far"
    shoulder = mounted_shoulder(pose, side)
    cx, cy = forge.pt(shoulder)
    if outfit["shoulders"] == "plate":
        base, dark, light = forge._metal_colors(outfit, far)
    elif outfit["shoulders"] == "cloth":
        base, dark, light = forge._cloth_colors(outfit, far)
    else:
        return
    forge.polygon(
        s,
        [
            (cx - 7, cy - 3),
            (cx + 6, cy - 3),
            (cx + 8, cy + 2),
            (cx + 5, cy + 6),
            (cx - 5, cy + 6),
            (cx - 8, cy + 1),
        ],
        dark,
    )
    forge.polygon(
        s,
        [
            (cx - 6, cy - 2),
            (cx + 5, cy - 2),
            (cx + 6, cy + 2),
            (cx + 4, cy + 4),
            (cx - 4, cy + 4),
            (cx - 6, cy + 1),
        ],
        base,
    )
    forge.line(s, (cx - 5, cy), (cx + 5, cy), light)
    forge.line(s, (cx - 4, cy + 3), (cx + 4, cy + 3), outfit["accent"])


def draw_mounted_skirt(
    s: forge.Canvas,
    pose: dict,
    outfit: dict,
) -> None:
    upper_x = 60.0 + float(pose["lean"])
    waist_y = float(pose["waist_y"])
    hip_y = float(pose["hip_y"])
    cloth, cloth_d, cloth_l = forge._cloth_colors(outfit, False)
    metal, metal_d, metal_l = forge._metal_colors(outfit, False)
    if outfit["skirt"] and outfit["armored"]:
        base, dark, light = metal, metal_d, metal_l
        for x0, x1 in ((-8, -2), (-1, 2), (3, 8)):
            forge.polygon(
                s,
                [
                    (upper_x + x0, waist_y + 2),
                    (upper_x + x1, waist_y + 2),
                    (upper_x + x1, hip_y + 5),
                    (upper_x + x0, hip_y + 6),
                ],
                dark,
            )
            forge.polygon(
                s,
                [
                    (upper_x + x0 + 1, waist_y + 3),
                    (upper_x + x1 - 1, waist_y + 3),
                    (upper_x + x1 - 1, hip_y + 4),
                    (upper_x + x0 + 1, hip_y + 5),
                ],
                base,
            )
            forge.line(
                s,
                (upper_x + x0 + 1, hip_y + 4),
                (upper_x + x1 - 1, hip_y + 4),
                light,
            )
            s.px(int(upper_x + x0 + 2), int(waist_y + 5), outfit["accent"])
    elif outfit["skirt"]:
        forge.polygon(
            s,
            [
                (upper_x - 8, waist_y + 2),
                (upper_x + 8, waist_y + 2),
                (upper_x + 9, hip_y + 5),
                (upper_x, hip_y + 8),
                (upper_x - 9, hip_y + 5),
            ],
            cloth_d,
        )
        forge.polygon(
            s,
            [
                (upper_x - 6, waist_y + 3),
                (upper_x + 6, waist_y + 3),
                (upper_x + 7, hip_y + 4),
                (upper_x, hip_y + 6),
                (upper_x - 7, hip_y + 4),
            ],
            cloth,
        )
        forge.line(
            s,
            (upper_x - 5, waist_y + 4),
            (upper_x - 5, hip_y + 3),
            cloth_l,
        )
        forge.line(
            s,
            (upper_x + 5, waist_y + 4),
            (upper_x + 5, hip_y + 3),
            cloth_d,
        )
    else:
        forge.polygon(
            s,
            [
                (upper_x - 8, waist_y + 2),
                (upper_x + 8, waist_y + 2),
                (upper_x + 7, hip_y + 2),
                (upper_x - 7, hip_y + 2),
            ],
            cloth,
        )


def rider_pose_from_action(action: dict, horse: dict, clip: str, index: int) -> dict:
    sway = math.sin(float(horse["phase"]))
    lag = math.sin(float(horse["phase"]) - 0.6)
    dy = int(horse["rider_dy"])
    lean = 7 + round(lag * 0.9)
    head_dx = round(math.sin(float(horse["phase"]) - 0.3) * 0.7)
    head_dy = 1 if clip == "walk" and index in (2, 3, 6, 7) else 0
    pose = {
        "grip": action["grip"],
        "bob": dy,
        "lean": lean,
        "head_dx": float(head_dx),
        "head_dy": float(head_dy),
        "shoulder_y": 44.0 + dy,
        "waist_y": 61.0 + dy,
        "hip_y": 68.0 + dy,
        "phase": float(horse["phase"]),
        "attack": 0,
        "stage": -1,
        "blink": clip == "idle" and index == 3,
        "rider_dy": dy,
    }
    if action["id"] == "lance_charge":
        pose["near_hand"] = (88.0 + sway * 0.7, 68.0 + dy)
        pose["far_hand"] = (91.0 + sway * 0.2, 61.0 + dy)
        pose["weapon_angle"] = math.radians(4.0 + sway * 1.0)
        pose["offhand_angle"] = 0.0
        pose["rein_hand"] = pose["far_hand"]
        pose["rein_aim"] = (1.0, 0.15)
    elif action["id"] == "mounted_bow":
        pose["near_hand"] = (97.0 + sway * 0.8, 49.0 + dy)
        pose["far_hand"] = (77.0 + sway * 0.4, 46.0 + dy)
        aim = forge.sub(pose["near_hand"], pose["far_hand"])
        pose["weapon_angle"] = math.atan2(aim[1], aim[0])
        pose["offhand_angle"] = pose["weapon_angle"]
        pose["rein_hand"] = pose["near_hand"]
        pose["rein_aim"] = (1.0, 0.1)
    else:
        pose["near_hand"] = (98.0 + sway * 0.8, 57.0 + dy)
        pose["far_hand"] = (86.0 + sway * 0.4, 60.0 + dy)
        pose["weapon_angle"] = math.radians(34 + sway * 2.0)
        pose["offhand_angle"] = 0.0
        pose["rein_hand"] = pose["far_hand"]
        pose["rein_aim"] = (1.0, 0.0)
    return pose


def draw_rein_overlay(
    bit: tuple[float, float],
    hand: tuple[float, float],
    phase: float,
) -> Image.Image:
    s = forge.Canvas(CELL, CELL)
    sag = 4.0 + math.sin(phase * 1.2) * 1.0
    ctrl = (
        (bit[0] + hand[0]) * 0.5,
        (bit[1] + hand[1]) * 0.5 + sag,
    )
    previous = bit
    for step in range(1, 9):
        t = step / 8.0
        x = (1 - t) ** 2 * bit[0] + 2 * (1 - t) * t * ctrl[0] + t**2 * hand[0]
        y = (1 - t) ** 2 * bit[1] + 2 * (1 - t) * t * ctrl[1] + t**2 * hand[1]
        current = (x, y)
        forge.line(s, previous, current, "#2b1a12")
        previous = current
    previous = forge.add(bit, (0, -1))
    for step in range(1, 9):
        t = step / 8.0
        x = (1 - t) ** 2 * bit[0] + 2 * (1 - t) * t * ctrl[0] + t**2 * hand[0]
        y = (1 - t) ** 2 * (bit[1] - 1) + 2 * (1 - t) * t * (ctrl[1] - 1) + t**2 * (hand[1] - 1)
        current = (x, y)
        forge.line(s, previous, current, "#68422a")
        previous = current
    return s.composite()


def draw_parked_reins(
    bit: tuple[float, float],
    pommel: tuple[float, float],
    phase: float,
) -> Image.Image:
    return draw_rein_overlay(bit, pommel, phase + 1.2)


def draw_rider_layer(
    recipe: dict,
    mount: dict,
    action: dict,
    horse: dict,
) -> tuple[Image.Image, dict]:
    skin, outfit, headgear, backgear, weapon, offhand, _grip = forge.resolve_recipe(recipe)
    pose = rider_pose_from_action(action, horse, horse["clip"], horse["index"])
    s = forge.Canvas(CELL, CELL)
    forge.draw_backgear_layer(s, pose, backgear)
    draw_rider_leg(s, pose, outfit, "far")
    upper_x = 60.0 + float(pose["lean"])
    draw_mounted_torso(s, pose, outfit)
    draw_mounted_skirt(s, pose, outfit)
    draw_rider_leg(s, pose, outfit, "near")
    for side in ("far", "near"):
        draw_mounted_arm(s, pose, side, skin, outfit)
        draw_mounted_pauldron(s, pose, side, outfit)
    forge.draw_outfit_collar(s, pose, outfit)
    head_x = upper_x + 2.0 + float(pose["head_dx"])
    head_y = forge.BODY_Y["head"] + float(pose["bob"]) + float(pose["head_dy"])
    forge.draw_body_neck(s, head_x, head_y, upper_x, float(pose["shoulder_y"]), skin)
    forge.draw_body_head(s, head_x, head_y, skin, bool(pose["blink"]))
    forge.draw_headgear_layer(s, pose, headgear)
    draw_cavalry_weapon(s, pose, action, weapon)
    if offhand:
        forge.draw_offhand_layer(s, pose, offhand)
    # Rein hand is gloved even when it does not grip the weapon.
    if action["id"] != "mounted_bow":
        forge._draw_grip_fist(s, pose["rein_hand"], pose["rein_aim"])
    s.outline(forge.OUTLINE, where="outside")
    return s.composite(), pose


def draw_cavalry_weapon(
    s: forge.Sprite,
    pose: dict,
    action: dict,
    weapon: dict,
) -> None:
    if action["weapon_layer"] == "mounted_lance":
        draw_mounted_lance(s, pose)
        return
    forge.draw_weapon_layer(s, pose, weapon)


def draw_mounted_lance(s: forge.Sprite, pose: dict) -> None:
    hand = pose["near_hand"]
    angle = float(pose["weapon_angle"])
    d = (math.cos(angle), math.sin(angle))
    n = (-d[1], d[0])
    start = forge.add(hand, forge.mul(d, -43))
    end = forge.add(hand, forge.mul(d, 27))
    forge.draw_segment(
        s, start, end, 4.8, 3.4,
        forge.WOOD, forge.LEATHER_D, forge.WOOD_L,
        rim=False, edge=1.0,
    )
    forge.line(
        s,
        forge.add(start, forge.mul(n, 1.1)),
        forge.add(end, forge.mul(n, 0.9)),
        forge.OCHRE_L,
    )
    forge.polygon(
        s,
        [
            forge.add(start, forge.mul(n, -2.5)),
            forge.add(start, forge.mul(n, 2.5)),
            forge.add(start, forge.mul(d, -6)),
        ],
        forge.IRON_D,
    )
    tip = forge.add(end, forge.mul(d, 8.5))
    mid = forge.add(end, forge.mul(d, 4.8))
    forge.polygon(
        s,
        [
            forge.add(end, forge.mul(n, -4)),
            forge.add(mid, forge.mul(n, -5)),
            forge.add(tip, (0, 0)),
            forge.add(mid, forge.mul(n, 5)),
            forge.add(end, forge.mul(n, 4)),
        ],
        forge.IRON_D,
    )
    forge.polygon(
        s,
        [
            forge.add(end, forge.mul(n, -3)),
            forge.add(mid, forge.mul(n, -3.7)),
            forge.add(tip, (0, 0)),
            forge.add(mid, forge.mul(n, 3.5)),
            forge.add(end, forge.mul(n, 2.6)),
        ],
        forge.IRON,
    )
    forge.line(s, forge.add(end, forge.mul(n, -1.5)), tip, forge.IRON_LL)
    s.px(*forge.pt(forge.add(tip, forge.mul(n, -0.5))), forge.WHITE)
    # Small pennant identifies the action at 1x without expanding the cell.
    tassel = forge.add(end, forge.mul(d, -4))
    forge.line(
        s,
        tassel,
        forge.add(tassel, forge.add(forge.mul(n, 5), forge.mul(d, -7))),
        forge.RED,
    )
    forge.line(
        s,
        forge.add(tassel, (0, 1)),
        forge.add(tassel, forge.add(forge.mul(n, 4), forge.mul(d, -5))),
        forge.RED_L,
    )
    forge._draw_grip_fist(s, hand, d)


def compose_mounted_frame(
    recipe: dict,
    action: dict,
    mount: dict,
    clip: str,
    index: int,
) -> Image.Image:
    horse = horse_pose(clip, index)
    shadow = draw_ground_shadow(clip, index)
    horse_image = draw_horse_layer(mount, horse, str(recipe["faction"]))
    rider_image, rider_pose = draw_rider_layer(recipe, mount, action, horse)
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(horse_image)
    rein = draw_rein_overlay(bit_point(horse), rider_pose["rein_hand"], horse["phase"])
    canvas.alpha_composite(rein)
    canvas.alpha_composite(rider_image)
    return canvas


def render_mount_frame(mount: dict, clip: str, index: int) -> Image.Image:
    horse = horse_pose(clip, index)
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    canvas.alpha_composite(draw_ground_shadow(clip, index))
    canvas.alpha_composite(draw_horse_layer(mount, horse, None))
    pommel = (78.0, 65.0 + int(horse["body_dy"]))
    canvas.alpha_composite(
        draw_parked_reins(bit_point(horse), pommel, float(horse["phase"]))
    )
    return canvas


def frame_count(clip: str) -> int:
    return cd.IDLE_FRAMES if clip == "idle" else cd.WALK_FRAMES


def bake_strip(render, clip: str, label: str) -> Image.Image:
    count = frame_count(clip)
    strip = Image.new("RGBA", (CELL * count, CELL), (0, 0, 0, 0))
    for index in range(count):
        frame = render(clip, index)
        validate_frame(frame, f"{label}/{clip}/f{index}")
        strip.alpha_composite(frame, (index * CELL, 0))
    return strip


def validate_frame(frame: Image.Image, label: str) -> None:
    if frame.mode != "RGBA":
        raise ValueError(f"{label} must be RGBA")
    if frame.size != (CELL, CELL):
        raise ValueError(f"{label} must be {CELL}x{CELL}, got {frame.size}")
    alpha = frame.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError(f"{label} is empty")
    if bbox[0] <= 0 or bbox[1] <= 0 or bbox[2] >= CELL or bbox[3] >= CELL:
        raise ValueError(f"{label} clips the cell: {bbox}")
    histogram = alpha.histogram()
    if sum(histogram[1:255]) != 0:
        raise ValueError(f"{label} contains semi-transparent pixels")


def output_path(resource_path: str) -> Path:
    if not resource_path.startswith("res://"):
        raise ValueError(f"expected res:// path: {resource_path}")
    return ROOT / "game" / resource_path.removeprefix("res://")


def export_assets() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    for variant in cd.MOUNT_VARIANTS:
        mount = cd.mount_by_id(str(variant["mount"]))
        if mount is None:
            raise ValueError(f"unknown mount {variant['mount']}")
        for clip in ("idle", "walk"):
            strip = bake_strip(
                lambda c, i, m=mount: render_mount_frame(m, c, i),
                clip,
                str(variant["id"]),
            )
            path = output_path(str(variant[f"battle_{clip}"]))
            path.parent.mkdir(parents=True, exist_ok=True)
            strip.save(path, optimize=True)
            print(
                f"baked {variant['id']}/{clip}: {strip.width}x{strip.height} "
                f"-> {path.relative_to(ROOT)}"
            )
    for recipe in cd.MOUNTED_VARIANTS:
        forge.validate_recipe_faction(recipe)
        mount = cd.mount_by_id(str(recipe["mount"]))
        action = cd.action_by_id(str(recipe["action"]))
        if mount is None or action is None:
            raise ValueError(f"bad cavalry recipe: {recipe['id']}")
        for clip in ("idle", "walk"):
            strip = bake_strip(
                lambda c, i, r=recipe, a=action, m=mount: compose_mounted_frame(r, a, m, c, i),
                clip,
                str(recipe["id"]),
            )
            path = output_path(str(recipe[f"battle_{clip}"]))
            path.parent.mkdir(parents=True, exist_ok=True)
            strip.save(path, optimize=True)
            print(
                f"baked {recipe['id']}/{clip}: {strip.width}x{strip.height} "
                f"-> {path.relative_to(ROOT)}"
            )


def scaled(frame: Image.Image, scale: int) -> Image.Image:
    return frame.resize((CELL * scale, CELL * scale), Image.Resampling.NEAREST)


def label(draw: ImageDraw.ImageDraw, text: str, xy: tuple[int, int], size: int = 14) -> None:
    draw.text(xy, text, fill=(229, 220, 201), font=forge.font(size))


def build_roster() -> None:
    scale = 2
    frames = cd.IDLE_FRAMES + cd.WALK_FRAMES
    cell_w = CELL * scale
    label_w = 250
    header_h = 44
    row_h = cell_w + 30
    entries = [("mount", item) for item in cd.MOUNT_VARIANTS] + [
        ("cavalry", item) for item in cd.MOUNTED_VARIANTS
    ]
    sheet = Image.new(
        "RGB",
        (label_w + frames * cell_w + 16, header_h + len(entries) * row_h + 16),
        (12, 18, 21),
    )
    draw = ImageDraw.Draw(sheet)
    label(draw, "CharacterForge cavalry roster · 4 idle + 8 walk", (12, 8), 20)
    x = label_w
    for index in range(frames):
        clip = "idle" if index < cd.IDLE_FRAMES else "walk"
        local = index if clip == "idle" else index - cd.IDLE_FRAMES
        label(draw, f"{clip[0].upper()}{local}", (x + 18, 20), 11)
        x += cell_w
    for row, (kind, variant) in enumerate(entries):
        y = header_h + row * row_h
        draw.line((0, y - 4, sheet.width, y - 4), fill=(38, 52, 56), width=2)
        label(draw, str(variant["id"]), (12, y + 8), 16)
        if kind == "mount":
            mount = cd.mount_by_id(str(variant["mount"]))
            action = None
            label(draw, "unridden · saddle / bridle", (12, y + 34), 12)
            label(draw, "diagonal-trot leg cycle", (12, y + 52), 11)
        else:
            mount = cd.mount_by_id(str(variant["mount"]))
            action = cd.action_by_id(str(variant["action"]))
            label(draw, f"{mount['name_zh']} · {action['name_zh']}", (12, y + 34), 12)
            label(
                draw,
                f"{variant['faction']} · {variant['outfit']}",
                (12, y + 52),
                10,
            )
        x = label_w
        for clip in ("idle", "walk"):
            for index in range(frame_count(clip)):
                if kind == "mount":
                    frame = render_mount_frame(mount, clip, index)
                else:
                    frame = compose_mounted_frame(variant, action, mount, clip, index)
                sheet.paste(scaled(frame, scale), (x, y), scaled(frame, scale))
                x += cell_w
    path = PREVIEW_ROOT / "cavalry_roster.png"
    sheet.save(path, optimize=True)
    print(f"preview -> {path.relative_to(ROOT)}")


def build_gait_sheet() -> None:
    scale = 3
    cell_w = CELL * scale
    label_h = 34
    label_w = 210
    sheet = Image.new(
        "RGB",
        (label_w + cd.WALK_FRAMES * cell_w, len(cd.MOUNT_VARIANTS) * (cell_w + label_h)),
        (12, 18, 21),
    )
    draw = ImageDraw.Draw(sheet)
    for row, variant in enumerate(cd.MOUNT_VARIANTS):
        mount = cd.mount_by_id(str(variant["mount"]))
        y = row * (cell_w + label_h)
        label(draw, str(mount["name_zh"]), (12, y + 20), 18)
        label(draw, str(mount["name_en"]), (12, y + 44), 11)
        for index in range(cd.WALK_FRAMES):
            frame = render_mount_frame(mount, "walk", index)
            x = label_w + index * cell_w
            sheet.paste(scaled(frame, scale), (x, y), scaled(frame, scale))
            label(draw, f"W{index + 1}", (x + 8, y + cell_w + 6), 11)
    path = PREVIEW_ROOT / "cavalry_gait_sheet.png"
    sheet.save(path, optimize=True)
    print(f"preview -> {path.relative_to(ROOT)}")


def build_detail_sheet() -> None:
    scale = 4
    cell_w = CELL * scale
    label_h = 38
    label_w = 240
    choices = (("idle", 1), ("walk", 1), ("walk", 3), ("walk", 5))
    entries = [("mount", item) for item in cd.MOUNT_VARIANTS] + [
        ("cavalry", item) for item in cd.MOUNTED_VARIANTS
    ]
    sheet = Image.new(
        "RGB",
        (label_w + len(choices) * cell_w, len(entries) * (cell_w + label_h) + 20),
        (12, 18, 21),
    )
    draw = ImageDraw.Draw(sheet)
    label(draw, "Cavalry close inspection · 4x", (12, 8), 19)
    for row, (kind, variant) in enumerate(entries):
        y = 20 + row * (cell_w + label_h)
        label(draw, str(variant["id"]), (12, y + 18), 15)
        mount = cd.mount_by_id(str(variant["mount"]))
        action = cd.action_by_id(str(variant["action"])) if kind == "cavalry" else None
        label(
            draw,
            str(mount["id"]) if kind == "mount" else str(action["id"]),
            (12, y + 42),
            11,
        )
        for col, (clip, index) in enumerate(choices):
            if kind == "mount":
                frame = render_mount_frame(mount, clip, index)
            else:
                frame = compose_mounted_frame(variant, action, mount, clip, index)
            x = label_w + col * cell_w
            image = scaled(frame, scale)
            sheet.paste(image, (x, y), image)
            label(draw, f"{clip} {index}", (x + 8, y + cell_w + 4), 11)
    path = PREVIEW_ROOT / "cavalry_detail_sheet.png"
    sheet.save(path, optimize=True)
    print(f"preview -> {path.relative_to(ROOT)}")


def build_layer_breakdown() -> None:
    recipe = cd.MOUNTED_VARIANTS[0]
    mount = cd.mount_by_id(str(recipe["mount"]))
    action = cd.action_by_id(str(recipe["action"]))
    horse = horse_pose("walk", 3)
    shadow = draw_ground_shadow("walk", 3)
    horse_image = draw_horse_layer(mount, horse, str(recipe["faction"]))
    rider_image, rider_pose = draw_rider_layer(recipe, mount, action, horse)
    rein = draw_rein_overlay(bit_point(horse), rider_pose["rein_hand"], horse["phase"])
    composite = compose_mounted_frame(recipe, action, mount, "walk", 3)
    horse_only = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    horse_only.alpha_composite(shadow)
    horse_only.alpha_composite(horse_image)
    rider_only = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    rider_only.alpha_composite(rider_image)
    rein_only = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    rein_only.alpha_composite(rein)
    scale = 4
    labels = ("horse + shadow", "rein", "rider", "composite", "silhouette")
    images = (horse_only, rein_only, rider_only, composite, composite)
    sheet = Image.new("RGB", (5 * CELL * scale + 40, CELL * scale + 40), (12, 18, 21))
    draw = ImageDraw.Draw(sheet)
    for index, (name, image) in enumerate(zip(labels, images)):
        x = 8 + index * (CELL * scale + 8)
        if name == "silhouette":
            alpha = image.getchannel("A")
            image = Image.new("RGBA", image.size, (0, 0, 0, 0))
            image.putalpha(alpha)
            image = Image.composite(
                Image.new("RGBA", image.size, (7, 9, 11, 255)),
                Image.new("RGBA", image.size, (0, 0, 0, 0)),
                alpha,
            )
        image = scaled(image, scale)
        sheet.paste(image, (x, 8), image)
        label(draw, name, (x, CELL * scale + 14), 12)
    path = PREVIEW_ROOT / "cavalry_layer_breakdown.png"
    sheet.save(path, optimize=True)
    print(f"preview -> {path.relative_to(ROOT)}")


def main() -> None:
    export_assets()
    forge.write_data(ROOT / "game" / "data")
    build_roster()
    build_gait_sheet()
    build_detail_sheet()
    build_layer_breakdown()


if __name__ == "__main__":
    main()
