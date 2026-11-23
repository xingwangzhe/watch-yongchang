#!/usr/bin/env python3
"""Modular 128x128 character forge for WATCH · YONGCHANG.

The forge renders a shared human body, grip-specific clothing layers, universal
headgear/backgear, and weapon action layers on the same 48-frame timeline. All
art is drawn pixel by pixel with skills/pixel-art-studio; the downloaded CC0 /
CC-BY-SA packs are visual and architectural references only and never enter the
exported atlases.

Run from the project root:
    python3 pixel-art/character_forge/build.py
"""

from __future__ import annotations

import json
import math
import os
import random
import shutil
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "skills" / "pixel-art-studio" / "scripts"))

from pixelstudio import Sprite  # noqa: E402


CELL = 128
FRAME_COUNT = 48
ARM_UPPER = 17.0
ARM_LOWER = 17.0
LEG_UPPER = 21.0
LEG_LOWER = 21.0
BODY_Y = {
    "shoulder": 40.0,
    "waist": 62.0,
    "hip": 74.0,
    "ankle": 115.0,
    "head": 25.0,
    "foot_origin": 123,
}

GRIPS = ("one_hand", "two_hand", "ranged", "offhand")
ARM_LAYER_RULES = {
    "two_hand": "both_front",
    "ranged": "both_front",
    "one_hand": "both_front",
    "offhand": "both_front",
}
ARM_LAYER_POLICY = "all_arms_front"

CLIPS = {
    "idle": {"start": 0, "count": 4, "fps": 6},
    "walk": {"start": 4, "count": 8, "fps": 10},
    "attack_1": {"start": 12, "count": 6, "fps": 13},
    "attack_2": {"start": 18, "count": 6, "fps": 13},
    "attack_3": {"start": 24, "count": 6, "fps": 11},
    "attack_4": {"start": 30, "count": 6, "fps": 12},
    "attack_5": {"start": 36, "count": 6, "fps": 10},
    "hit": {"start": 42, "count": 2, "fps": 10},
    "guard": {"start": 44, "count": 4, "fps": 6},
}
ATTACK_ACTIONS = (1, 2, 3, 4, 5)
ACTION_NAMES = {
    "dao": (
        ("劈山式", "Mountain Split"),
        ("撩云式", "Cloud Rise"),
        ("横斩式", "Cross Cut"),
        ("回风式", "Backwind Cut"),
        ("断浪式", "Wave Breaker"),
    ),
    "jian": (
        ("点星式", "Star Point"),
        ("撩月式", "Moon Rise"),
        ("刺虹式", "Rainbow Thrust"),
        ("回锋式", "Returning Edge"),
        ("贯日式", "Sun Piercer"),
    ),
    "qiang": (
        ("中平刺", "Level Thrust"),
        ("拦拿扎", "Parry and Pierce"),
        ("崩枪式", "Spear Snap"),
        ("回马枪", "Turning Spear"),
        ("穿云刺", "Cloud Piercer"),
    ),
    "ji": (
        ("横戟式", "Level Halberd"),
        ("勾啄式", "Hook and Peck"),
        ("回旋斩", "Whirl Cut"),
        ("挑月式", "Moon Lift"),
        ("破阵式", "Formation Breaker"),
    ),
    "fu": (
        ("开山劈", "Mountain Cleave"),
        ("横抡斧", "Side Swing"),
        ("回风劈", "Backwind Cleave"),
        ("撩斧式", "Axe Rise"),
        ("断岳式", "Ridge Breaker"),
    ),
    "yue": (
        ("横扫千军", "Army Sweep"),
        ("回旋钺", "Whirl Axe"),
        ("上撩式", "Upward Rise"),
        ("压顶式", "Crown Press"),
        ("裂阵式", "Line Breaker"),
    ),
    "gou": (
        ("锁喉钩", "Throat Hook"),
        ("回勾式", "Returning Hook"),
        ("双撩钩", "Twin Hook Rise"),
        ("缠腕式", "Wrist Coil"),
        ("破甲钩", "Armour Hook"),
    ),
    "cha": (
        ("中平叉", "Level Trident"),
        ("挑刺式", "Rising Thrust"),
        ("横扫式", "Side Sweep"),
        ("锁兵式", "Weapon Lock"),
        ("破阵叉", "Formation Fork"),
    ),
    "gong": (
        ("开弓式", "Bow Draw"),
        ("满月式", "Full Moon"),
        ("连珠式", "Rapid Volley"),
        ("仰射式", "High Shot"),
        ("回身射", "Turning Shot"),
    ),
    "nu": (
        ("上弦式", "Crossbow Span"),
        ("平射式", "Level Shot"),
        ("连弩式", "Repeating Volley"),
        ("压弩式", "Press Shot"),
        ("回身射", "Turning Shot"),
    ),
    "niaochong": (
        ("举铳式", "Cannon Raise"),
        ("瞄准式", "Take Aim"),
        ("击发式", "Fire"),
        ("压铳式", "Recoil Brace"),
        ("回身铳", "Turning Shot"),
    ),
    "longdeng": (
        ("龙灯起式", "Lantern Rise"),
        ("盘龙式", "Coiled Dragon"),
        ("摆灯式", "Lantern Swing"),
        ("回龙式", "Returning Dragon"),
        ("龙腾式", "Dragon Soars"),
    ),
    "lingqi": (
        ("举旗式", "Flag Raise"),
        ("挥旗式", "Flag Sweep"),
        ("卷旗式", "Flag Coil"),
        ("指阵式", "Formation Call"),
        ("破阵旗", "Formation Breaker"),
    ),
    "dun": (
        ("举盾式", "Shield Raise"),
        ("盾击式", "Shield Bash"),
        ("格挡式", "Shield Block"),
        ("撞阵式", "Shield Charge"),
        ("回盾式", "Shield Return"),
    ),
}
COMBO_ACTION_NAMES = {
    "same": (
        ("同心斩", "Twin Heart Cut"),
        ("双回风", "Twin Backwind"),
        ("叠浪式", "Twin Wave"),
        ("合璧式", "Paired Jade"),
        ("双龙出海", "Twin Dragons"),
    ),
    "mixed": (
        ("左牵右引", "Left Draw, Right Guide"),
        ("长短互济", "Long and Short"),
        ("错锋式", "Crossed Edges"),
        ("阴阳式", "Yin and Yang"),
        ("合击式", "Joint Strike"),
    ),
    "shield": (
        ("盾掩刀锋", "Shield Covers Blade"),
        ("撞盾斩", "Shield Charge Cut"),
        ("守势反击", "Guard Counter"),
        ("压盾式", "Shield Press"),
        ("破阵合击", "Breaker Combo"),
    ),
}

INK = "#07090b"
OUTLINE = "#07090b"
WHITE = "#e7e2d4"
WARM_WHITE = "#f5e5bf"
HAIR = "#2a201b"
HAIR_D = "#15110f"
HAIR_L = "#4a3828"
WRAP = "#6b5a45"
WRAP_D = "#3d3228"
WRAP_L = "#978064"
GOLD = "#b9853f"
GOLD_L = "#edbc62"
GOLD_D = "#6d491f"
IRON = "#687572"
IRON_D = "#333e3d"
IRON_L = "#a5b1aa"
IRON_LL = "#d2dbcf"
LEATHER = "#5b3a24"
LEATHER_D = "#352116"
LEATHER_L = "#8b5b35"
WOOD = "#4e3527"
WOOD_L = "#7c5738"
RED = "#8d3028"
RED_D = "#521b1a"
RED_L = "#c6533e"
BLUE = "#2f4c5d"
BLUE_D = "#1d2e39"
BLUE_L = "#4e7585"
GREEN = "#3d5a3c"
GREEN_D = "#233323"
GREEN_L = "#6f8d53"
PURPLE = "#4c3050"
PURPLE_D = "#2a1930"
PURPLE_L = "#805578"
OCHRE = "#8a6b38"
OCHRE_D = "#4f3b20"
OCHRE_L = "#b99557"
GREY = "#77756d"
GREY_D = "#3f3e3a"
GREY_L = "#a7a397"
BLACK = "#17191a"
BLACK_L = "#33383a"
FIRE = "#ff9b38"
FIRE_L = "#ffd36a"

SKINS = [
    {"id": "light", "name_zh": "浅肤", "name_en": "Light",
     "base": "#e5bd94", "dark": "#a97756", "light": "#f3d5ad", "deep": "#7d4d38"},
    {"id": "tan", "name_zh": "麦色", "name_en": "Tan",
     "base": "#c9986c", "dark": "#8a5c40", "light": "#e1b486", "deep": "#623c2d"},
    {"id": "deep", "name_zh": "深肤", "name_en": "Deep",
     "base": "#8f5f43", "dark": "#5d3928", "light": "#b57d58", "deep": "#42251b"},
    {"id": "pale", "name_zh": "冷白", "name_en": "Pale",
     "base": "#ebc7a2", "dark": "#b48a6d", "light": "#f8ddbd", "deep": "#85614d"},
]

OUTFITS = [
    {
        "id": "ming_lamellar_red", "name_zh": "明军朱红札甲", "name_en": "Ming Red Lamellar",
        "cloth": RED, "cloth_d": RED_D, "cloth_l": RED_L,
        "metal": IRON, "metal_d": IRON_D, "metal_l": IRON_L,
        "accent": GOLD, "accent_l": GOLD_L,
        "sleeve": "long", "legs": "greaves", "shoulders": "plate",
        "skirt": True, "armored": True, "tags": ["ming", "army"],
    },
    {
        "id": "ming_brigandine_blue", "name_zh": "明军青布罩甲", "name_en": "Ming Blue Brigandine",
        "cloth": BLUE, "cloth_d": BLUE_D, "cloth_l": BLUE_L,
        "metal": IRON, "metal_d": IRON_D, "metal_l": IRON_L,
        "accent": GOLD, "accent_l": GOLD_L,
        "sleeve": "long", "legs": "pants", "shoulders": "plate",
        "skirt": True, "armored": True, "tags": ["ming", "army"],
    },
    {
        "id": "ming_robe_ochre", "name_zh": "明军赭褐短打", "name_en": "Ming Ochre Short Robe",
        "cloth": OCHRE, "cloth_d": OCHRE_D, "cloth_l": OCHRE_L,
        "metal": IRON, "metal_d": IRON_D, "metal_l": IRON_L,
        "accent": LEATHER, "accent_l": LEATHER_L,
        "sleeve": "short", "legs": "pants", "shoulders": "cloth",
        "skirt": True, "armored": False, "tags": ["ming", "militia"],
    },
    {
        "id": "ming_guard_iron", "name_zh": "明军铁灰札甲", "name_en": "Ming Iron Guard",
        "cloth": IRON_D, "cloth_d": BLACK, "cloth_l": IRON,
        "metal": IRON, "metal_d": IRON_D, "metal_l": IRON_LL,
        "accent": GOLD, "accent_l": GOLD_L,
        "sleeve": "long", "legs": "greaves", "shoulders": "plate",
        "skirt": True, "armored": True, "tags": ["ming", "army"],
    },
    {
        "id": "ming_navy_green", "name_zh": "明军水营绿袄", "name_en": "Ming Navy Green Coat",
        "cloth": GREEN, "cloth_d": GREEN_D, "cloth_l": GREEN_L,
        "metal": IRON, "metal_d": IRON_D, "metal_l": IRON_L,
        "accent": GOLD, "accent_l": GOLD_L,
        "sleeve": "short", "legs": "pants", "shoulders": "cloth",
        "skirt": True, "armored": False, "tags": ["ming", "navy"],
    },
    {
        "id": "wokou_ragged_brown", "name_zh": "倭寇褐布破衣", "name_en": "Wokou Ragged Brown",
        "cloth": "#6d5138", "cloth_d": "#3f2e21", "cloth_l": "#957455",
        "metal": IRON, "metal_d": IRON_D, "metal_l": IRON_L,
        "accent": LEATHER, "accent_l": LEATHER_L,
        "sleeve": "none", "legs": "shorts", "shoulders": "cloth",
        "skirt": False, "armored": False, "tags": ["wokou"],
    },
    {
        "id": "wokou_dark_navy", "name_zh": "倭寇深蓝短甲", "name_en": "Wokou Dark Navy",
        "cloth": "#263947", "cloth_d": "#14212a", "cloth_l": "#426175",
        "metal": IRON_D, "metal_d": BLACK, "metal_l": IRON,
        "accent": GOLD, "accent_l": GOLD_L,
        "sleeve": "long", "legs": "pants", "shoulders": "plate",
        "skirt": True, "armored": True, "tags": ["wokou"],
    },
    {
        "id": "pirate_teal", "name_zh": "海盗青皮甲", "name_en": "Pirate Teal",
        "cloth": "#2d5557", "cloth_d": "#183333", "cloth_l": "#4e7d79",
        "metal": LEATHER, "metal_d": LEATHER_D, "metal_l": LEATHER_L,
        "accent": GOLD, "accent_l": GOLD_L,
        "sleeve": "short", "legs": "pants", "shoulders": "cloth",
        "skirt": False, "armored": False, "tags": ["wokou", "pirate"],
    },
    {
        "id": "monk_grey", "name_zh": "僧兵灰褐法衣", "name_en": "Sohei Grey Robe",
        "cloth": GREY, "cloth_d": GREY_D, "cloth_l": GREY_L,
        "metal": LEATHER, "metal_d": LEATHER_D, "metal_l": LEATHER_L,
        "accent": OCHRE, "accent_l": OCHRE_L,
        "sleeve": "long", "legs": "pants", "shoulders": "cloth",
        "skirt": True, "armored": False, "tags": ["wokou", "monk"],
    },
    {
        "id": "general_purple", "name_zh": "将官紫金重甲", "name_en": "Purple Gold General",
        "cloth": PURPLE, "cloth_d": PURPLE_D, "cloth_l": PURPLE_L,
        "metal": GOLD, "metal_d": GOLD_D, "metal_l": GOLD_L,
        "accent": IRON_LL, "accent_l": WHITE,
        "sleeve": "long", "legs": "greaves", "shoulders": "plate",
        "skirt": True, "armored": True, "tags": ["wokou", "elite"],
    },
    {
        "id": "oni_red", "name_zh": "鬼面赤甲", "name_en": "Oni Red Armour",
        "cloth": "#7e2925", "cloth_d": "#461411", "cloth_l": "#b84a38",
        "metal": IRON_D, "metal_d": BLACK, "metal_l": IRON,
        "accent": GOLD, "accent_l": GOLD_L,
        "sleeve": "none", "legs": "greaves", "shoulders": "plate",
        "skirt": True, "armored": True, "tags": ["wokou", "oni"],
    },
    {
        "id": "villager_linen", "name_zh": "乡勇本色麻衣", "name_en": "Villager Linen",
        "cloth": "#a38f6f", "cloth_d": "#665844", "cloth_l": "#cbb894",
        "metal": LEATHER, "metal_d": LEATHER_D, "metal_l": LEATHER_L,
        "accent": WRAP, "accent_l": WRAP_L,
        "sleeve": "short", "legs": "shorts", "shoulders": "none",
        "skirt": False, "armored": False, "tags": ["ming", "militia", "neutral"],
    },
]

HEADGEAR = [
    {"id": "none", "name_zh": "无冠", "name_en": "Bare Head", "kind": "none", "tags": ["neutral"]},
    {"id": "ming_helmet_red", "name_zh": "明军红缨铁盔", "name_en": "Ming Red-Plume Helmet",
     "kind": "ming_helmet", "cloth": RED, "cloth_d": RED_D, "cloth_l": RED_L, "tags": ["ming"]},
    {"id": "ming_helmet_iron", "name_zh": "明军素铁盔", "name_en": "Ming Iron Helmet",
     "kind": "ming_helmet", "cloth": IRON_D, "cloth_d": BLACK, "cloth_l": IRON_L, "tags": ["ming"]},
    {"id": "ming_hat", "name_zh": "明军毡帽", "name_en": "Ming Felt Hat",
     "kind": "felt_hat", "cloth": OCHRE, "cloth_d": OCHRE_D, "cloth_l": OCHRE_L, "tags": ["ming"]},
    {"id": "ming_officer", "name_zh": "明军乌纱帽", "name_en": "Ming Officer Cap",
     "kind": "officer", "cloth": BLACK, "cloth_d": INK, "cloth_l": BLACK_L, "tags": ["ming"]},
    {"id": "wokou_headband", "name_zh": "倭寇头巾", "name_en": "Wokou Headband",
     "kind": "headband", "cloth": "#7b3c32", "cloth_d": "#3f1e1a", "cloth_l": "#b35f4f", "tags": ["wokou"]},
    {"id": "wokou_kasa", "name_zh": "倭寇阵笠", "name_en": "Wokou War Hat",
     "kind": "kasa", "cloth": "#8d764f", "cloth_d": "#4d3f29", "cloth_l": "#b99c68", "tags": ["wokou"]},
    {"id": "wokou_helmet", "name_zh": "倭寇铁兜", "name_en": "Wokou Iron Helmet",
     "kind": "horned_helmet", "cloth": IRON_D, "cloth_d": BLACK, "cloth_l": IRON_L, "tags": ["wokou"]},
    {"id": "monk_hood", "name_zh": "僧兵头巾", "name_en": "Sohei Hood",
     "kind": "monk_hood", "cloth": GREY, "cloth_d": GREY_D, "cloth_l": GREY_L, "tags": ["wokou"]},
    {"id": "oni_mask", "name_zh": "鬼面", "name_en": "Oni Mask",
     "kind": "oni_mask", "cloth": RED, "cloth_d": RED_D, "cloth_l": RED_L, "tags": ["wokou"]},
    {"id": "pirate_bandana", "name_zh": "海盗红巾", "name_en": "Pirate Bandana",
     "kind": "bandana", "cloth": RED, "cloth_d": RED_D, "cloth_l": RED_L, "tags": ["wokou"]},
]

BACKGEAR = [
    {"id": "none", "name_zh": "无披挂", "name_en": "No Backgear", "kind": "none", "tags": ["neutral"]},
    {"id": "ming_cape_red", "name_zh": "明军红披风", "name_en": "Ming Red Cape",
     "kind": "cape", "cloth": RED, "cloth_d": RED_D, "cloth_l": RED_L, "tags": ["ming"]},
    {"id": "wokou_cloak_dark", "name_zh": "倭寇黑披风", "name_en": "Wokou Dark Cloak",
     "kind": "cape", "cloth": "#28303a", "cloth_d": "#14181e", "cloth_l": "#465463", "tags": ["wokou"]},
    {"id": "ming_banner", "name_zh": "明军令旗", "name_en": "Ming Signal Banner",
     "kind": "banner", "cloth": RED, "cloth_d": RED_D, "cloth_l": RED_L, "tags": ["ming"]},
]

WEAPONS = [
    {"id": "dao", "name_zh": "腰刀", "name_en": "Dao Saber", "kind": "dao",
     "grip": "one_hand", "slot": "main", "attack_profile": "saber_diagonal", "offhand": True},
    {"id": "jian", "name_zh": "长剑", "name_en": "Jian Sword", "kind": "jian",
     "grip": "one_hand", "slot": "main", "attack_profile": "sword_thrust", "offhand": True},
    {"id": "qiang", "name_zh": "长枪", "name_en": "Qiang Spear", "kind": "qiang",
     "grip": "two_hand", "slot": "main", "attack_profile": "spear_lunge", "offhand": False},
    {"id": "ji", "name_zh": "画戟", "name_en": "Ji Halberd", "kind": "ji",
     "grip": "two_hand", "slot": "main", "attack_profile": "halberd_sweep", "offhand": False},
    {"id": "fu", "name_zh": "战斧", "name_en": "Fu Axe", "kind": "fu",
     "grip": "two_hand", "slot": "main", "attack_profile": "axe_chop", "offhand": False},
    {"id": "yue", "name_zh": "大钺", "name_en": "Yue Battle-Axe", "kind": "yue",
     "grip": "two_hand", "slot": "main", "attack_profile": "yue_wide_sweep", "offhand": False},
    {"id": "gou", "name_zh": "钩", "name_en": "Gou Hook", "kind": "gou",
     "grip": "one_hand", "slot": "main", "attack_profile": "hook_cross", "offhand": True},
    {"id": "cha", "name_zh": "三股叉", "name_en": "Cha Trident", "kind": "cha",
     "grip": "two_hand", "slot": "main", "attack_profile": "trident_triple", "offhand": False},
    {"id": "gong", "name_zh": "弓", "name_en": "Bow", "kind": "gong",
     "grip": "ranged", "slot": "main", "attack_profile": "bow_draw", "offhand": False},
    {"id": "nu", "name_zh": "弩", "name_en": "Crossbow", "kind": "nu",
     "grip": "ranged", "slot": "main", "attack_profile": "crossbow_volley", "offhand": False},
    {"id": "niaochong", "name_zh": "手铳", "name_en": "Hand Cannon", "kind": "niaochong",
     "grip": "ranged", "slot": "main", "attack_profile": "hand_cannon", "offhand": False},
    {"id": "longdeng", "name_zh": "龙灯", "name_en": "Dragon Lantern", "kind": "longdeng",
     "grip": "one_hand", "slot": "main", "attack_profile": "lantern_sweep", "offhand": True},
    {"id": "lingqi", "name_zh": "令旗", "name_en": "Signal Flag", "kind": "lingqi",
     "grip": "one_hand", "slot": "main", "attack_profile": "signal_command", "offhand": True},
    {"id": "dun", "name_zh": "盾", "name_en": "Shield", "kind": "dun",
     "grip": "offhand", "slot": "offhand", "attack_profile": "shield_bash", "offhand": True},
]

WEAPON_BY_ID = {item["id"]: item for item in WEAPONS}
MAIN_WEAPONS = [item for item in WEAPONS if item["slot"] == "main"]
OFFHAND_WEAPONS = [item for item in WEAPONS if item["offhand"]]
OFFHAND_ALLOWED_IDS = ("dao", "jian", "gou", "longdeng", "lingqi", "dun")
POSE_SETS = tuple(item["id"] for item in WEAPONS)
REQUIRED_WEAPONS = (
    "dao", "qiang", "jian", "ji", "fu", "yue", "gou", "cha", "dun", "gong", "nu",
)
ONE_HAND_MAIN_IDS = tuple(item["id"] for item in MAIN_WEAPONS if item["grip"] == "one_hand")
COMBO_FAMILIES = ("same", "mixed", "shield")


def combo_family(main_id: str, offhand_id: str) -> str:
    if offhand_id == "dun":
        return "shield"
    if main_id == offhand_id:
        return "same"
    return "mixed"


def combo_pairs() -> list[tuple[str, str]]:
    return [
        (main_id, offhand_id)
        for main_id in ONE_HAND_MAIN_IDS
        for offhand_id in OFFHAND_ALLOWED_IDS
    ]


def pose_variant(weapon_id: str, offhand_id: str) -> str:
    if offhand_id == "none":
        return weapon_id
    return f"combo_{combo_family(weapon_id, offhand_id)}"


COMBO_POSE_IDS = tuple(f"combo_{family}" for family in COMBO_FAMILIES)
POSE_VARIANTS = POSE_SETS + COMBO_POSE_IDS
COMBO_REPRESENTATIVES = {
    "combo_same": ("dao", "dao"),
    "combo_mixed": ("dao", "jian"),
    "combo_shield": ("dao", "dun"),
}
PAIR_STYLE_OFFSETS = {
    ("dao", "dao"): 0,
    ("jian", "jian"): 8,
    ("gou", "gou"): -10,
    ("dao", "jian"): 0,
    ("jian", "dao"): 6,
    ("gou", "dao"): -8,
    ("dao", "gou"): 8,
    ("jian", "gou"): -6,
    ("gou", "jian"): 10,
    ("dao", "dun"): 0,
    ("jian", "dun"): 4,
    ("gou", "dun"): -4,
}


def _all_colors() -> list[str]:
    values = {
        INK, OUTLINE, WHITE, WARM_WHITE, HAIR, HAIR_D, HAIR_L, WRAP, WRAP_D, WRAP_L,
        GOLD, GOLD_L, GOLD_D, IRON, IRON_D, IRON_L, IRON_LL, LEATHER, LEATHER_D,
        LEATHER_L, WOOD, WOOD_L, RED, RED_D, RED_L, BLUE, BLUE_D, BLUE_L, GREEN,
        GREEN_D, GREEN_L, PURPLE, PURPLE_D, PURPLE_L, OCHRE, OCHRE_D, OCHRE_L,
        GREY, GREY_D, GREY_L, BLACK, BLACK_L, FIRE, FIRE_L,
    }
    for skin in SKINS:
        values.update((skin["base"], skin["dark"], skin["light"], skin["deep"]))
    for group in (OUTFITS, HEADGEAR, BACKGEAR):
        for item in group:
            for key, value in item.items():
                if isinstance(value, str) and value.startswith("#"):
                    values.add(value)
    return sorted(values)


PAL = _all_colors()


class Canvas(Sprite):
    def rect(self, *args: object) -> None:
        if len(args) == 3 and isinstance(args[0], tuple) and isinstance(args[1], tuple):
            x0, y0 = args[0]
            x1, y1 = args[1]
            super().rect(int(x0), int(y0), int(x1), int(y1), args[2])
            return
        super().rect(*args)


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
    dist = length(delta)
    if dist > upper + lower:
        scale = dist / (upper + lower)
        upper *= scale
        lower *= scale
    dist = max(1.0, dist)
    direction = unit(delta)
    base = math.atan2(direction[1], direction[0])
    cosine = (upper * upper + dist * dist - lower * lower) / (2.0 * upper * dist)
    angle = math.acos(max(-1.0, min(1.0, cosine)))
    joint_angle = base + bend * angle
    return add(root, (math.cos(joint_angle) * upper, math.sin(joint_angle) * upper))


def polygon(s: Sprite, points: list[tuple[float, float]], color: str) -> None:
    s.polygon([pt(p) for p in points], color)


def line(s: Sprite, a: tuple[float, float], b: tuple[float, float], color: str) -> None:
    s.line(*pt(a), *pt(b), color)


def draw_segment(
    s: Sprite,
    a: tuple[float, float],
    b: tuple[float, float],
    w0: float,
    w1: float,
    base: str,
    dark: str,
    light: str,
    rim: bool = True,
    shade_dir: tuple[float, float] | None = None,
) -> None:
    direction = sub(b, a)
    n = unit((-direction[1], direction[0]))
    outer = [
        add(a, mul(n, w0 / 2.0)), add(b, mul(n, w1 / 2.0)),
        add(b, mul(n, -w1 / 2.0)), add(a, mul(n, -w0 / 2.0)),
    ]
    polygon(s, outer, dark if rim else base)
    if not rim:
        if shade_dir is None:
            shadow_n = n if n[0] + n[1] > 0 else mul(n, -1.0)
        else:
            shadow_n = n if n[0] * shade_dir[0] + n[1] * shade_dir[1] >= 0 else mul(n, -1.0)
        light_n = mul(shadow_n, -1.0)
        line(
            s,
            add(a, mul(shadow_n, max(0.5, w0 / 2.0 - 0.7))),
            add(b, mul(shadow_n, max(0.5, w1 / 2.0 - 0.7))),
            dark,
        )
        line(
            s,
            add(a, mul(light_n, max(0.5, w0 / 2.0 - 1.1))),
            add(b, mul(light_n, max(0.5, w1 / 2.0 - 1.1))),
            light,
        )
        return
    inner0 = max(1.0, w0 - 2.0)
    inner1 = max(1.0, w1 - 2.0)
    inner = [
        add(a, mul(n, inner0 / 2.0)), add(b, mul(n, inner1 / 2.0)),
        add(b, mul(n, -inner1 / 2.0)), add(a, mul(n, -inner0 / 2.0)),
    ]
    polygon(s, inner, base)
    hl_n = n if n[0] + n[1] <= 0 else mul(n, -1.0)
    line(
        s,
        add(a, mul(hl_n, max(0.0, inner0 / 2.0 - 0.6))),
        add(b, mul(hl_n, max(0.0, inner1 / 2.0 - 0.6))),
        light,
    )


def draw_joint(
    s: Sprite,
    p: tuple[float, float],
    radius: int,
    base: str,
    dark: str,
    light: str,
    fold: tuple[float, float] = (0.0, 0.0),
) -> None:
    s.circle(*pt(p), radius, base, fill=True)
    if length(fold) > 0.001:
        f = unit(fold)
        tangent = (-f[1], f[0])
        crease = add(p, mul(f, max(1.0, radius - 0.8)))
        line(
            s,
            add(crease, mul(tangent, max(1.0, radius - 1.0))),
            add(crease, mul(tangent, -max(1.0, radius - 1.0))),
            dark,
        )
        cap = add(p, mul(f, -max(1.0, radius - 1.2)))
        line(
            s,
            add(cap, mul(tangent, max(1.0, radius - 1.5))),
            add(cap, mul(tangent, -max(1.0, radius - 1.5))),
            light,
        )
    else:
        s.px(*pt(add(p, (-max(1, radius - 2), -1))), light)


def draw_foot(
    s: Sprite,
    ankle: tuple[float, float],
    base: str,
    dark: str,
    light: str,
    boot: bool,
) -> None:
    x, y = pt(ankle)
    toe = 9 if boot else 7
    polygon(
        s,
        [(x - 5, y - 2), (x + 5, y - 2), (x + toe, y + 1),
         (x + toe - 1, y + 4), (x - 5, y + 4)],
        dark,
    )
    polygon(
        s,
        [(x - 4, y - 1), (x + 5, y - 1), (x + toe - 2, y + 2),
         (x + toe - 2, y + 3), (x - 4, y + 3)],
        base,
    )
    line(s, (x - 4, y + 1), (x + toe - 3, y + 1), light)
    if boot:
        line(s, (x - 4, y + 3), (x + toe - 2, y + 3), dark)
    else:
        for k in range(3):
            s.px(x + 3 + k, y + 3, dark)


def draw_shadow(s: Sprite) -> None:
    s.ellipse(32, 118, 90, 123, INK, fill=True)
    s.ellipse(39, 119, 83, 121, "#101416", fill=True)


def leg_points(pose: dict, side: str) -> tuple[tuple[float, float], tuple[float, float]]:
    hip_x = 54.0 if side == "far" else 66.0
    return (hip_x, float(pose["hip_y"])), tuple(pose[f"{side}_foot"])


def shoulder_points(pose: dict, side: str) -> tuple[float, float]:
    upper_x = 60.0 + float(pose["lean"])
    if side == "far":
        return upper_x - 19.0, float(pose["shoulder_y"]) + 2.0
    return upper_x + 19.0, float(pose["shoulder_y"]) + 1.0


def far_arm_mode(pose: dict) -> str:
    if ARM_LAYER_POLICY == "all_arms_front":
        return "front"
    if ARM_LAYER_RULES[pose["grip"]] == "both_front":
        return "front"
    upper_x = 60.0 + float(pose["lean"])
    return "split" if float(pose["far_hand"][0]) > upper_x - 2.0 else "back"


def clamped_ik(
    root: tuple[float, float],
    target: tuple[float, float],
    upper: float,
    lower: float,
    bend: int,
    name: str,
) -> tuple[float, float]:
    reach = length(sub(target, root))
    if reach > (upper + lower) * 1.08:
        print(f"warning: {name} target unreachable at {target}; root {root}")
    return solve_ik(root, target, upper, lower, bend)


def draw_arc(
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
            line(s, previous, current, color)
        previous = current


def _pose_shell(grip: str) -> dict:
    return {
        "grip": grip,
        "bob": 0,
        "lean": 0,
        "head_dx": 0.0,
        "head_dy": 0.0,
        "shoulder_y": BODY_Y["shoulder"],
        "waist_y": BODY_Y["waist"],
        "hip_y": BODY_Y["hip"],
        "far_foot": (52.0, BODY_Y["ankle"]),
        "near_foot": (68.0, BODY_Y["ankle"]),
        "far_hand": (52.0, 72.0),
        "near_hand": (82.0, 73.0),
        "weapon_angle": math.radians(78),
        "offhand_angle": math.radians(-82),
        "phase": 0.0,
        "attack": 0,
        "stage": -1,
    }


def _apply_bob(pose: dict, bob: int) -> None:
    pose["bob"] = bob
    pose["shoulder_y"] = BODY_Y["shoulder"] + bob
    pose["waist_y"] = BODY_Y["waist"] + bob
    pose["hip_y"] = BODY_Y["hip"] + bob
    pose["far_hand"] = add(pose["far_hand"], (0.0, float(bob)))
    pose["near_hand"] = add(pose["near_hand"], (0.0, float(bob)))


def idle_pose(index: int, grip: str) -> dict:
    grip = "one_hand" if grip == "offhand" else grip
    pose = _pose_shell(grip)
    phase = 2.0 * math.pi * index / 4.0
    bob = 1 if index in (1, 2) else 0
    sway = math.sin(phase)
    pose["phase"] = phase
    pose["lean"] = 0
    pose["far_foot"] = (52.0 - sway, BODY_Y["ankle"])
    pose["near_foot"] = (68.0 - sway * 0.5, BODY_Y["ankle"])
    if grip == "one_hand":
        pose["far_hand"] = (40.0 + sway, 73.0)
        pose["near_hand"] = (84.0 - sway * 0.5, 75.0)
        pose["weapon_angle"] = math.radians(78 + sway * 3)
        pose["offhand_angle"] = math.radians(-82 - sway * 2)
    elif grip == "two_hand":
        pose["far_hand"] = (54.0, 68.0)
        pose["near_hand"] = (70.0, 60.0)
        delta = sub(pose["near_hand"], pose["far_hand"])
        pose["weapon_angle"] = math.atan2(delta[1], delta[0])
    else:
        pose["far_hand"] = (36.0, 64.0)
        pose["near_hand"] = (66.0, 66.0)
        pose["weapon_angle"] = math.radians(-3 + sway * 2)
    _apply_bob(pose, bob)
    pose["head_dy"] = float(bob)
    return pose


def walk_pose(index: int, grip: str) -> dict:
    grip = "one_hand" if grip == "offhand" else grip
    pose = _pose_shell(grip)
    phase = 2.0 * math.pi * index / 8.0
    bob = 1 if index in (1, 2, 5, 6) else 0

    def foot(offset: float) -> tuple[float, float]:
        p = (index / 8.0 + offset) % 1.0
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
    pose["phase"] = phase
    pose["lean"] = int(round(math.sin(phase) * 1.4))
    pose["far_foot"] = (52.0 + far_x, BODY_Y["ankle"] - far_lift)
    pose["near_foot"] = (68.0 + near_x, BODY_Y["ankle"] - near_lift)
    if grip == "one_hand":
        pose["far_hand"] = (40.0 + swing * 1.5, 73.0 + math.sin(phase * 2.0) * 0.5)
        pose["near_hand"] = (84.0 - swing * 2.0, 75.0 - math.sin(phase * 2.0) * 0.5)
        pose["weapon_angle"] = math.radians(80 + math.sin(phase) * 5)
        pose["offhand_angle"] = math.radians(-82 - math.sin(phase) * 4)
    elif grip == "two_hand":
        pose["far_hand"] = (54.0 + swing * 1.5, 66.0)
        pose["near_hand"] = (70.0 + swing * 1.5, 62.0)
        delta = sub(pose["near_hand"], pose["far_hand"])
        pose["weapon_angle"] = math.atan2(delta[1], delta[0])
    else:
        pose["far_hand"] = (36.0 + swing * 1.0, 64.0)
        pose["near_hand"] = (65.0 + swing * 1.5, 65.0)
        pose["weapon_angle"] = math.radians(-4 + math.sin(phase) * 2)
    _apply_bob(pose, bob)
    pose["head_dy"] = float(bob)
    return pose


ATTACK_BASE = {
    "bob": (0, 0, 0, 1, 1, 0),
    "lean": (0, -1, 2, 4, 3, 1),
    "head_dx": (0, 0, 1, 1, 0, 0),
    "head_dy": (0, 0, 0, 1, 0, 0),
    "near_foot_x": (68, 68, 70, 72, 71, 69),
    "far_foot_x": (52, 51, 49, 47, 49, 50),
}


def _blend_point(a: tuple[float, float], b: tuple[float, float], t: float) -> tuple[float, float]:
    return lerp(a[0], b[0], t), lerp(a[1], b[1], t)


def _blend_scalar(a: float, b: float, t: float) -> float:
    return lerp(a, b, t)


def _stage_value(
    stage: int,
    guard: tuple[float, float],
    wind: tuple[float, float],
    hit: tuple[float, float],
    follow: tuple[float, float],
) -> tuple[float, float]:
    if stage == 0:
        return guard
    if stage == 1:
        return _blend_point(guard, wind, 0.72)
    if stage == 2:
        return _blend_point(wind, hit, 0.62)
    if stage == 3:
        return hit
    if stage == 4:
        return follow
    return _blend_point(follow, guard, 0.38)


def _stage_angle(stage: int, guard: float, wind: float, hit: float, follow: float) -> float:
    if stage == 0:
        return guard
    if stage == 1:
        return _blend_scalar(guard, wind, 0.72)
    if stage == 2:
        return _blend_scalar(wind, hit, 0.62)
    if stage == 3:
        return hit
    if stage == 4:
        return follow
    return _blend_scalar(follow, guard, 0.38)


def _action(
    near: tuple[tuple[float, float], tuple[float, float], tuple[float, float], tuple[float, float]],
    far: tuple[tuple[float, float], tuple[float, float], tuple[float, float], tuple[float, float]],
    near_angle: tuple[float, float, float, float],
    far_angle: tuple[float, float, float, float] = (-82, -96, -52, -72),
    lunge: int = 3,
) -> dict:
    return {
        "near": near,
        "far": far,
        "near_angle": near_angle,
        "far_angle": far_angle,
        "lunge": lunge,
    }


ATTACK_SPECS = {
    "dao": {
        1: _action(
            ((76, 62), (74, 50), (92, 68), (84, 74)),
            ((54, 70), (52, 64), (60, 68), (58, 72)),
            (-105, -128, 18, 72),
        ),
        2: _action(
            ((70, 68), (58, 64), (86, 66), (90, 72)),
            ((54, 70), (50, 66), (76, 58), (68, 67)),
            (160, 196, 20, -35),
            (-82, -108, 24, 62),
        ),
        3: _action(
            ((70, 66), (62, 60), (90, 70), (90, 72)),
            ((54, 68), (50, 64), (72, 64), (66, 70)),
            (-8, -20, 8, 10),
            (-82, -104, -18, -58),
        ),
    },
    "jian": {
        1: _action(
            ((74, 64), (64, 58), (94, 72), (90, 74)),
            ((52, 70), (50, 68), (60, 70), (56, 72)),
            (-30, -50, 0, 4),
        ),
        2: _action(
            ((74, 62), (66, 52), (94, 62), (88, 70)),
            ((52, 70), (50, 68), (62, 66), (56, 72)),
            (-50, -90, 0, 10),
        ),
        3: _action(
            ((72, 66), (64, 70), (94, 76), (84, 74)),
            ((52, 70), (50, 68), (60, 72), (56, 72)),
            (0, 15, 6, 12),
        ),
    },
    "gou": {
        1: _action(
            ((72, 64), (62, 52), (92, 68), (80, 74)),
            ((52, 70), (48, 66), (58, 66), (56, 72)),
            (-100, -135, 25, 80),
        ),
        2: _action(
            ((70, 70), (58, 66), (74, 64), (84, 72)),
            ((54, 72), (50, 64), (74, 60), (68, 68)),
            (150, 190, 15, -45),
            (-80, -120, 35, 65),
        ),
        3: _action(
            ((70, 64), (58, 58), (88, 62), (82, 72)),
            ((54, 68), (48, 60), (70, 68), (66, 70)),
            (-60, -110, 40, 70),
            (-100, -140, 50, 80),
        ),
    },
    "longdeng": {
        1: _action(
            ((76, 64), (64, 58), (92, 68), (86, 74)),
            ((52, 70), (48, 66), (58, 68), (56, 72)),
            (-70, -100, 15, 60),
        ),
        2: _action(
            ((70, 66), (60, 62), (88, 72), (76, 72)),
            ((52, 70), (48, 66), (60, 68), (56, 72)),
            (-30, -80, 40, 80),
        ),
        3: _action(
            ((74, 60), (60, 54), (88, 60), (82, 70)),
            ((52, 68), (48, 64), (60, 66), (56, 72)),
            (-100, -140, -35, -80),
        ),
    },
    "lingqi": {
        1: _action(
            ((76, 64), (70, 56), (82, 42), (82, 50)),
            ((52, 72), (50, 68), (58, 68), (56, 72)),
            (-80, -105, -75, -88),
            lunge=1,
        ),
        2: _action(
            ((70, 68), (60, 60), (68, 50), (78, 58)),
            ((52, 72), (50, 68), (58, 68), (56, 72)),
            (-45, -90, -120, -70),
            lunge=1,
        ),
        3: _action(
            ((70, 66), (82, 54), (64, 52), (78, 64)),
            ((52, 72), (50, 68), (58, 68), (56, 72)),
            (-70, -120, -60, -80),
            lunge=2,
        ),
    },
    "dun": {
        1: _action(
            ((64, 64), (56, 60), (82, 64), (74, 68)),
            ((52, 70), (48, 64), (62, 66), (58, 70)),
            (-82, -96, -72, -78),
            lunge=4,
        ),
        2: _action(
            ((64, 66), (52, 62), (78, 58), (72, 68)),
            ((52, 70), (46, 62), (66, 56), (60, 68)),
            (-82, -105, -55, -75),
            lunge=3,
        ),
        3: _action(
            ((66, 64), (56, 54), (82, 72), (74, 70)),
            ((52, 70), (48, 62), (68, 70), (60, 70)),
            (-82, -100, -35, -72),
            lunge=3,
        ),
    },
    "qiang": {
        1: _action(
            ((68, 48), (64, 50), (88, 70), (76, 74)),
            ((54, 58), (50, 62), (58, 72), (56, 74)),
            (0, 0, 0, 0),
            lunge=5,
        ),
        2: _action(
            ((68, 52), (60, 64), (84, 64), (84, 68)),
            ((56, 58), (48, 68), (54, 66), (62, 70)),
            (0, 0, 0, 0),
            lunge=4,
        ),
        3: _action(
            ((70, 66), (72, 68), (86, 72), (76, 72)),
            ((54, 68), (52, 70), (58, 72), (56, 72)),
            (0, 0, 0, 0),
            lunge=3,
        ),
    },
    "ji": {
        1: _action(
            ((68, 50), (58, 54), (86, 68), (80, 72)),
            ((54, 60), (48, 62), (62, 66), (58, 70)),
            (0, 0, 0, 0),
            lunge=4,
        ),
        2: _action(
            ((68, 52), (80, 58), (72, 64), (84, 68)),
            ((56, 60), (62, 58), (50, 68), (64, 70)),
            (0, 0, 0, 0),
            lunge=3,
        ),
        3: _action(
            ((70, 54), (60, 44), (86, 72), (78, 72)),
            ((54, 58), (50, 52), (60, 70), (58, 72)),
            (0, 0, 0, 0),
            lunge=5,
        ),
    },
    "fu": {
        1: _action(
            ((68, 46), (62, 38), (78, 74), (74, 72)),
            ((54, 56), (48, 58), (56, 70), (54, 72)),
            (0, 0, 0, 0),
            lunge=4,
        ),
        2: _action(
            ((68, 50), (58, 46), (86, 62), (80, 72)),
            ((54, 58), (50, 54), (62, 66), (58, 72)),
            (0, 0, 0, 0),
            lunge=4,
        ),
        3: _action(
            ((68, 50), (62, 40), (86, 70), (78, 72)),
            ((54, 60), (50, 54), (62, 70), (58, 72)),
            (0, 0, 0, 0),
            lunge=5,
        ),
    },
    "yue": {
        1: _action(
            ((68, 48), (58, 54), (84, 64), (80, 72)),
            ((54, 58), (48, 60), (64, 66), (60, 70)),
            (0, 0, 0, 0),
            lunge=4,
        ),
        2: _action(
            ((68, 54), (78, 50), (66, 68), (82, 70)),
            ((54, 60), (62, 58), (48, 68), (64, 70)),
            (0, 0, 0, 0),
            lunge=4,
        ),
        3: _action(
            ((68, 48), (56, 40), (86, 70), (80, 72)),
            ((54, 58), (48, 52), (60, 70), (58, 72)),
            (0, 0, 0, 0),
            lunge=5,
        ),
    },
    "cha": {
        1: _action(
            ((68, 48), (62, 50), (88, 70), (78, 74)),
            ((54, 58), (50, 62), (58, 72), (56, 74)),
            (0, 0, 0, 0),
            lunge=5,
        ),
        2: _action(
            ((68, 54), (60, 58), (86, 62), (82, 70)),
            ((54, 60), (48, 66), (56, 64), (62, 70)),
            (0, 0, 0, 0),
            lunge=4,
        ),
        3: _action(
            ((70, 64), (62, 70), (88, 72), (78, 74)),
            ((54, 68), (50, 72), (56, 72), (58, 72)),
            (0, 0, 0, 0),
            lunge=5,
        ),
    },
    "gong": {
        1: _action(
            ((64, 67), (64, 66), (66, 64), (66, 66)),
            ((36, 64), (34, 62), (31, 58), (34, 61)),
            (-5, -3, 2, 4),
            lunge=1,
        ),
        2: _action(
            ((64, 67), (63, 66), (64, 63), (64, 66)),
            ((35, 66), (33, 64), (30, 60), (33, 62)),
            (0, -5, 0, 2),
            lunge=1,
        ),
        3: _action(
            ((62, 64), (62, 62), (63, 59), (64, 63)),
            ((34, 60), (32, 58), (29, 55), (32, 58)),
            (-20, -25, -28, -15),
            lunge=1,
        ),
    },
    "nu": {
        1: _action(
            ((64, 66), (60, 62), (70, 64), (66, 66)),
            ((44, 64), (42, 62), (48, 62), (45, 64)),
            (-2, -4, 0, 1),
            lunge=2,
        ),
        2: _action(
            ((64, 66), (58, 64), (68, 62), (66, 66)),
            ((44, 64), (48, 66), (45, 62), (45, 64)),
            (0, -8, -2, 1),
            lunge=2,
        ),
        3: _action(
            ((64, 64), (58, 60), (72, 66), (66, 66)),
            ((44, 64), (42, 60), (48, 64), (45, 64)),
            (-8, -14, 4, 1),
            lunge=3,
        ),
    },
    "niaochong": {
        1: _action(
            ((68, 66), (64, 62), (84, 62), (74, 68)),
            ((56, 62), (54, 60), (62, 60), (58, 64)),
            (-3, -5, 0, 2),
            lunge=2,
        ),
        2: _action(
            ((68, 66), (62, 62), (82, 64), (72, 68)),
            ((56, 62), (52, 58), (60, 62), (58, 64)),
            (0, -8, -2, 2),
            lunge=3,
        ),
        3: _action(
            ((68, 64), (60, 58), (84, 66), (74, 68)),
            ((56, 62), (52, 56), (62, 62), (58, 64)),
            (-10, -16, 6, 2),
            lunge=4,
        ),
    },
}

EXTRA_ATTACK_SPECS = {
    "dao": {
        4: _action(
            ((76, 64), (60, 54), (92, 72), (86, 74)),
            ((48, 70), (44, 64), (54, 68), (50, 72)),
            (100, 145, -20, -70),
            (-82, -100, -40, -68),
        ),
        5: _action(
            ((70, 66), (56, 58), (94, 64), (88, 72)),
            ((54, 68), (48, 62), (72, 58), (64, 66)),
            (160, 210, 10, -40),
            (-80, -130, 30, 62),
            lunge=4,
        ),
    },
    "jian": {
        4: _action(
            ((76, 66), (66, 62), (96, 70), (90, 72)),
            ((52, 70), (48, 68), (58, 72), (54, 72)),
            (-10, -25, 5, 8),
        ),
        5: _action(
            ((74, 62), (62, 54), (98, 66), (92, 70)),
            ((52, 68), (48, 64), (60, 66), (56, 70)),
            (-30, -60, 0, 5),
            lunge=4,
        ),
    },
    "gou": {
        4: _action(
            ((72, 60), (60, 46), (90, 62), (82, 72)),
            ((52, 70), (48, 62), (60, 64), (56, 72)),
            (-100, -150, 10, 70),
            (-90, -130, 20, 60),
        ),
        5: _action(
            ((70, 70), (56, 72), (94, 76), (86, 72)),
            ((52, 72), (46, 66), (68, 66), (60, 72)),
            (150, 200, -10, -60),
            (-80, -120, 40, 70),
            lunge=4,
        ),
    },
    "longdeng": {
        4: _action(
            ((76, 66), (62, 72), (92, 72), (86, 74)),
            ((52, 70), (48, 66), (58, 68), (56, 72)),
            (120, 160, -15, -70),
        ),
        5: _action(
            ((74, 60), (62, 48), (88, 58), (84, 70)),
            ((52, 68), (48, 64), (58, 66), (56, 72)),
            (-90, -140, -30, -80),
        ),
    },
    "lingqi": {
        4: _action(
            ((74, 64), (62, 70), (92, 68), (82, 72)),
            ((52, 72), (50, 68), (58, 68), (56, 72)),
            (100, 150, -20, -60),
            lunge=2,
        ),
        5: _action(
            ((72, 60), (68, 46), (82, 38), (82, 48)),
            ((52, 72), (50, 68), (58, 68), (56, 72)),
            (-80, -110, -95, -85),
            lunge=1,
        ),
    },
    "dun": {
        4: _action(
            ((64, 64), (56, 58), (82, 62), (74, 68)),
            ((52, 70), (48, 62), (62, 66), (58, 70)),
            (-82, -95, -72, -80),
            lunge=3,
        ),
        5: _action(
            ((66, 64), (58, 54), (86, 68), (76, 70)),
            ((52, 70), (46, 62), (68, 66), (60, 70)),
            (-82, -100, -60, -78),
            lunge=4,
        ),
    },
    "qiang": {
        4: _action(
            ((64, 62), (56, 58), (78, 68), (70, 70)),
            ((54, 66), (48, 64), (58, 70), (56, 72)),
            (0, 0, 0, 0),
            lunge=3,
        ),
        5: _action(
            ((70, 50), (64, 44), (90, 66), (78, 72)),
            ((54, 58), (48, 54), (58, 68), (56, 72)),
            (0, 0, 0, 0),
            lunge=5,
        ),
    },
    "ji": {
        4: _action(
            ((68, 54), (58, 48), (88, 64), (80, 70)),
            ((54, 60), (48, 56), (62, 66), (58, 70)),
            (0, 0, 0, 0),
            lunge=4,
        ),
        5: _action(
            ((68, 44), (60, 38), (82, 72), (76, 72)),
            ((54, 56), (48, 52), (60, 70), (58, 72)),
            (0, 0, 0, 0),
            lunge=5,
        ),
    },
    "fu": {
        4: _action(
            ((68, 52), (60, 46), (82, 76), (76, 74)),
            ((54, 58), (48, 54), (62, 72), (58, 72)),
            (0, 0, 0, 0),
            lunge=4,
        ),
        5: _action(
            ((68, 50), (80, 54), (62, 68), (80, 70)),
            ((54, 60), (62, 62), (50, 68), (60, 70)),
            (0, 0, 0, 0),
            lunge=4,
        ),
    },
    "yue": {
        4: _action(
            ((68, 54), (56, 50), (86, 60), (80, 68)),
            ((54, 60), (48, 56), (62, 64), (58, 68)),
            (0, 0, 0, 0),
            lunge=4,
        ),
        5: _action(
            ((68, 42), (60, 36), (84, 74), (78, 72)),
            ((54, 56), (48, 52), (62, 72), (58, 72)),
            (0, 0, 0, 0),
            lunge=5,
        ),
    },
    "cha": {
        4: _action(
            ((68, 56), (60, 60), (88, 74), (80, 74)),
            ((54, 62), (48, 66), (58, 72), (56, 72)),
            (0, 0, 0, 0),
            lunge=5,
        ),
        5: _action(
            ((68, 54), (56, 60), (90, 64), (82, 70)),
            ((54, 60), (48, 66), (64, 64), (60, 68)),
            (0, 0, 0, 0),
            lunge=4,
        ),
    },
    "gong": {
        4: _action(
            ((64, 67), (63, 65), (67, 64), (66, 66)),
            ((36, 64), (34, 63), (32, 60), (34, 62)),
            (-5, -8, 4, 5),
            lunge=1,
        ),
        5: _action(
            ((63, 66), (62, 64), (65, 62), (66, 66)),
            ((36, 64), (32, 62), (28, 56), (33, 60)),
            (-8, -12, -2, 3),
            lunge=1,
        ),
    },
    "nu": {
        4: _action(
            ((64, 66), (58, 64), (70, 65), (66, 66)),
            ((44, 64), (42, 60), (48, 62), (45, 64)),
            (-2, -6, 0, 1),
            lunge=2,
        ),
        5: _action(
            ((64, 64), (58, 58), (72, 62), (66, 66)),
            ((44, 62), (40, 58), (49, 62), (45, 64)),
            (-5, -10, 2, 1),
            lunge=3,
        ),
    },
    "niaochong": {
        4: _action(
            ((68, 66), (62, 64), (82, 66), (72, 68)),
            ((56, 62), (52, 60), (60, 62), (58, 64)),
            (-4, -8, 0, 2),
            lunge=2,
        ),
        5: _action(
            ((68, 64), (60, 58), (86, 64), (74, 68)),
            ((56, 62), (50, 58), (64, 62), (58, 64)),
            (-6, -12, 3, 2),
            lunge=3,
        ),
    },
}

for _weapon_id, _extra_actions in EXTRA_ATTACK_SPECS.items():
    ATTACK_SPECS[_weapon_id].update(_extra_actions)


COMBO_ATTACK_SPECS = {
    "same": {
        1: _action(
            ((76, 64), (64, 54), (94, 70), (86, 74)),
            ((48, 70), (44, 64), (58, 66), (54, 72)),
            (-105, -130, 15, 65),
            (-82, -100, -30, -70),
        ),
        2: _action(
            ((72, 66), (60, 60), (86, 70), (84, 74)),
            ((50, 66), (40, 56), (70, 64), (62, 72)),
            (-80, -100, -20, -60),
            (-110, -140, 10, 70),
        ),
        3: _action(
            ((72, 60), (62, 48), (94, 64), (88, 72)),
            ((52, 64), (42, 52), (76, 58), (66, 68)),
            (-120, -160, 20, 70),
            (-80, -130, 30, 80),
            lunge=4,
        ),
        4: _action(
            ((74, 70), (62, 72), (92, 74), (86, 72)),
            ((50, 60), (42, 50), (74, 62), (64, 70)),
            (140, 180, -10, -50),
            (-110, -150, 20, 60),
        ),
        5: _action(
            ((70, 62), (58, 50), (96, 66), (88, 72)),
            ((52, 68), (44, 58), (74, 60), (66, 68)),
            (-60, -120, 10, 50),
            (-70, -130, 20, 70),
            lunge=5,
        ),
    },
    "mixed": {
        1: _action(
            ((74, 60), (62, 50), (94, 66), (86, 72)),
            ((52, 68), (46, 62), (70, 66), (62, 72)),
            (-110, -140, 20, 70),
            (-80, -95, -5, 5),
        ),
        2: _action(
            ((72, 68), (62, 72), (92, 66), (86, 72)),
            ((50, 60), (40, 50), (64, 58), (58, 68)),
            (150, 190, 15, -30),
            (-120, -160, 20, 60),
        ),
        3: _action(
            ((70, 58), (60, 46), (92, 68), (86, 72)),
            ((52, 66), (42, 56), (74, 62), (64, 70)),
            (-90, -130, 35, 80),
            (-70, -120, 45, 85),
            lunge=4,
        ),
        4: _action(
            ((72, 52), (62, 44), (88, 66), (82, 72)),
            ((50, 70), (42, 72), (68, 66), (62, 70)),
            (-80, -120, 15, 60),
            (130, 170, -10, -50),
        ),
        5: _action(
            ((70, 64), (60, 58), (96, 66), (88, 70)),
            ((52, 66), (42, 56), (72, 60), (62, 68)),
            (-10, -25, 5, 8),
            (-100, -140, 30, 70),
            lunge=5,
        ),
    },
    "shield": {
        1: _action(
            ((70, 68), (60, 70), (88, 70), (82, 72)),
            ((56, 58), (52, 56), (60, 60), (58, 62)),
            (140, 180, -10, -40),
            (-82, -95, -82, -85),
        ),
        2: _action(
            ((72, 64), (62, 54), (92, 68), (84, 72)),
            ((48, 64), (58, 58), (70, 62), (64, 66)),
            (-100, -130, 15, 60),
            (-82, -90, -70, -80),
            lunge=4,
        ),
        3: _action(
            ((70, 60), (60, 56), (94, 64), (88, 70)),
            ((52, 54), (48, 52), (58, 56), (56, 60)),
            (-20, -40, 0, 5),
            (-82, -100, -80, -85),
        ),
        4: _action(
            ((72, 52), (62, 44), (88, 66), (82, 72)),
            ((52, 64), (44, 60), (66, 64), (60, 68)),
            (-80, -120, 15, 60),
            (-82, -95, -60, -75),
        ),
        5: _action(
            ((70, 64), (58, 58), (96, 66), (88, 72)),
            ((50, 62), (60, 56), (74, 60), (66, 66)),
            (-60, -110, 10, 50),
            (-82, -95, -70, -80),
            lunge=5,
        ),
    },
}


def attack_pose(action: int, stage: int, pose_id: str, offhand_id: str = "none") -> dict:
    weapon = WEAPON_BY_ID.get(pose_id, WEAPONS[0])
    grip = "one_hand" if weapon["grip"] == "offhand" else weapon["grip"]
    pose = _pose_shell(grip)
    family = None if offhand_id == "none" else combo_family(weapon["id"], offhand_id)
    spec = (
        COMBO_ATTACK_SPECS[family][action]
        if family is not None
        else ATTACK_SPECS[weapon["id"]][action]
    )
    pair_offset = PAIR_STYLE_OFFSETS.get((weapon["id"], offhand_id), 0) if family else 0
    bob = ATTACK_BASE["bob"][stage]
    lean = ATTACK_BASE["lean"][stage]
    pose["lean"] = lean
    pose["head_dx"] = float(ATTACK_BASE["head_dx"][stage])
    pose["head_dy"] = float(ATTACK_BASE["head_dy"][stage])
    pose["phase"] = (action - 1) * 2.1 + stage * 0.8
    pose["attack"] = action
    pose["stage"] = stage
    pose["near_hand"] = _stage_value(stage, *spec["near"])
    pose["far_hand"] = _stage_value(stage, *spec["far"])
    near_angle = _stage_angle(stage, *spec["near_angle"]) + pair_offset
    far_angle = _stage_angle(stage, *spec["far_angle"]) - pair_offset
    pose["weapon_angle"] = math.radians(near_angle)
    pose["offhand_angle"] = math.radians(far_angle)
    if family is not None:
        pose["combo"] = family
        pose["pair"] = f"{weapon['id']}+{offhand_id}"
    lunge = int(spec.get("lunge", 3))
    lunge = max(1, min(3, lunge))
    lunge_shift = (0, 0, lunge, lunge, lunge - 1, 0)[stage]
    pose["near_foot"] = (
        float(ATTACK_BASE["near_foot_x"][stage] + lunge_shift),
        BODY_Y["ankle"],
    )
    pose["far_foot"] = (
        float(ATTACK_BASE["far_foot_x"][stage] - lunge_shift * 0.45),
        BODY_Y["ankle"],
    )
    if grip == "two_hand":
        delta = sub(pose["near_hand"], pose["far_hand"])
        pose["weapon_angle"] = math.atan2(delta[1], delta[0])
    _apply_bob(pose, bob)
    pose["near_foot"] = (
        float(ATTACK_BASE["near_foot_x"][stage] + lunge_shift),
        BODY_Y["ankle"],
    )
    pose["far_foot"] = (
        float(ATTACK_BASE["far_foot_x"][stage] - lunge_shift * 0.45),
        BODY_Y["ankle"],
    )
    return pose


def hit_pose(index: int, grip: str) -> dict:
    pose = idle_pose(0, grip)
    pose["lean"] = -3 + index
    pose["head_dx"] = -3.0 + index
    pose["head_dy"] = -1.0
    pose["phase"] = 0.4 + index
    pose["far_hand"] = add(pose["far_hand"], (-1.0, -1.0))
    pose["near_hand"] = add(pose["near_hand"], (1.0, 1.0))
    pose["far_foot"] = (50.0, BODY_Y["ankle"])
    pose["near_foot"] = (70.0, BODY_Y["ankle"])
    pose["hit"] = index + 1
    return pose


def guard_pose(index: int, grip: str, offhand_id: str = "none") -> dict:
    pose = idle_pose(index, grip)
    sway = math.sin(pose["phase"]) * 1.0
    if offhand_id != "none":
        pose["near_hand"] = (72.0 + sway, 62.0)
        pose["far_hand"] = (54.0 - sway, 64.0)
        pose["weapon_angle"] = math.radians(-35 + sway * 2)
        pose["offhand_angle"] = math.radians(-115 - sway * 2)
    elif grip == "two_hand":
        pose["far_hand"] = (56.0, 64.0)
        pose["near_hand"] = (72.0 + sway, 58.0)
        delta = sub(pose["near_hand"], pose["far_hand"])
        pose["weapon_angle"] = math.atan2(delta[1], delta[0])
    elif grip == "ranged":
        pose["far_hand"] = (36.0 - sway, 62.0)
        pose["near_hand"] = (66.0, 64.0)
        pose["weapon_angle"] = math.radians(-5 + sway)
    else:
        pose["near_hand"] = (72.0 + sway, 64.0)
        pose["weapon_angle"] = math.radians(-25 + sway * 3)
    pose["guard"] = index + 1
    return pose


def pose_for(frame: int, pose_id: str, offhand_id: str = "none") -> dict:
    weapon = WEAPON_BY_ID.get(pose_id, WEAPONS[0])
    grip = weapon["grip"]
    if frame < CLIPS["walk"]["start"]:
        return idle_pose(frame, grip)
    if frame < CLIPS["attack_1"]["start"]:
        return walk_pose(frame - CLIPS["walk"]["start"], grip)
    for action in ATTACK_ACTIONS:
        clip = CLIPS[f"attack_{action}"]
        if clip["start"] <= frame < clip["start"] + clip["count"]:
            return attack_pose(action, frame - clip["start"], weapon["id"], offhand_id)
    hit_clip = CLIPS["hit"]
    if frame < CLIPS["guard"]["start"]:
        return hit_pose(frame - hit_clip["start"], grip)
    return guard_pose(frame - CLIPS["guard"]["start"], grip, offhand_id)


def validate_pose_reach() -> None:
    failures = []
    cases = [(pose_id, "none") for pose_id in POSE_SETS] + combo_pairs()
    for pose_id, offhand_id in cases:
        for frame in range(FRAME_COUNT):
            pose = pose_for(frame, pose_id, offhand_id)
            far_shoulder = shoulder_points(pose, "far")
            near_shoulder = shoulder_points(pose, "near")
            for side, shoulder in (("far", far_shoulder), ("near", near_shoulder)):
                distance = length(sub(pose[f"{side}_hand"], shoulder))
                if distance > (ARM_UPPER + ARM_LOWER) * 1.08:
                    failures.append(
                        f"{pose_id}+{offhand_id} frame={frame} {side} arm reach={distance:.2f}"
                    )
            for side in ("far", "near"):
                hip, ankle = leg_points(pose, side)
                distance = length(sub(ankle, hip))
                if distance > (LEG_UPPER + LEG_LOWER) * 1.01:
                    failures.append(
                        f"{pose_id}+{offhand_id} frame={frame} {side} leg reach={distance:.2f}"
                    )
    if failures:
        raise ValueError("unreachable poses:\n" + "\n".join(failures))


def validate_arm_layering() -> None:
    if ARM_LAYER_POLICY != "all_arms_front" or set(ARM_LAYER_RULES.values()) != {"both_front"}:
        raise ValueError("arm layering must stay locked to both_front for every grip")
    failures = []
    cases = [(pose_id, "none") for pose_id in POSE_SETS] + combo_pairs()
    for pose_id, offhand_id in cases:
        for frame in range(FRAME_COUNT):
            pose = pose_for(frame, pose_id, offhand_id)
            mode = far_arm_mode(pose)
            expected = ARM_LAYER_RULES[pose["grip"]]
            if expected == "both_front" and mode != "front":
                failures.append(f"{pose_id}+{offhand_id} frame={frame} grip={pose['grip']} mode={mode}")
            if expected == "far_back_near_front" and mode == "front":
                failures.append(f"{pose_id}+{offhand_id} frame={frame} grip={pose['grip']} mode={mode}")
    if failures:
        raise ValueError("invalid arm layering:\n" + "\n".join(failures))


def _skin_colors(skin: dict, far: bool) -> tuple[str, str, str]:
    if far:
        return skin["dark"], skin["deep"], skin["base"]
    return skin["base"], skin["dark"], skin["light"]


def draw_body_leg(
    s: Sprite,
    hip: tuple[float, float],
    ankle: tuple[float, float],
    skin: dict,
    far: bool,
) -> None:
    base, dark, light = _skin_colors(skin, far)
    bend = 1 if far else -1
    knee = clamped_ik(hip, ankle, LEG_UPPER, LEG_LOWER, bend, "leg")
    hx, hy = pt(hip)
    s.circle(hx, hy, 6, base, fill=True)
    shade_dir = (1.0, 0.0) if far else (-1.0, 0.0)
    draw_segment(s, hip, knee, 13.0, 10.5, base, dark, light, rim=False, shade_dir=shade_dir)
    draw_segment(s, knee, ankle, 10.0, 7.5, base, dark, light, rim=False, shade_dir=shade_dir)
    chord_mid = add(hip, mul(sub(ankle, hip), 0.5))
    draw_joint(s, knee, 4, base, dark, light, sub(chord_mid, knee))
    ax, ay = pt(ankle)
    s.circle(ax, ay, 3, base, fill=True)
    line(s, (ax - 3, ay - 1), (ax + 2, ay), dark)
    line(s, (ax - 2, ay - 2), (ax + 2, ay - 2), light)
    line(s, (hx - 3, hy + 1), (hx + 3, hy + 2), dark)
    mid = add(hip, mul(sub(knee, hip), 0.55))
    line(s, add(mid, (-2, 0)), add(mid, (2, 1)), light)
    calf = add(knee, mul(sub(ankle, knee), 0.42))
    line(s, add(calf, (-2, 0)), add(calf, (2, 1)), light)
    draw_foot(s, ankle, base, dark, light, boot=False)


def draw_body_arm(
    s: Sprite,
    shoulder: tuple[float, float],
    hand: tuple[float, float],
    skin: dict,
    far: bool,
    lower_only: bool = False,
) -> None:
    base, dark, light = _skin_colors(skin, far)
    bend = 1 if far else -1
    elbow = clamped_ik(shoulder, hand, ARM_UPPER, ARM_LOWER, bend, "arm")
    shade_dir = (1.0, 0.0) if far else (-1.0, 0.0)
    if not lower_only:
        sx, sy = pt(shoulder)
        s.circle(sx, sy, 5, base, fill=True)
        draw_segment(s, shoulder, elbow, 10.0, 9.0, base, dark, light, rim=False, shade_dir=shade_dir)
    draw_segment(s, elbow, hand, 8.0, 6.0, base, dark, light, rim=False, shade_dir=shade_dir)
    chord_mid = add(shoulder, mul(sub(hand, shoulder), 0.5))
    draw_joint(s, elbow, 3, base, dark, light, sub(chord_mid, elbow))
    ex, ey = pt(elbow)
    s.line(ex - 2, ey, ex + 2, ey, dark)
    s.line(ex - 2, ey - 1, ex + 2, ey - 1, light)
    if not lower_only:
        upper_mid = add(shoulder, mul(sub(elbow, shoulder), 0.55))
        s.px(*pt(add(upper_mid, (-1, -2))), light)
        line(s, (sx - 3, sy + 2), (sx + 2, sy + 3), dark)
    s.circle(*pt(hand), 3, base, fill=True)
    line(s, add(hand, (-2, 1)), add(hand, (2, 1)), dark)
    s.px(*pt(add(hand, (-1, -1))), light)


def draw_body_torso(
    s: Sprite,
    upper_x: float,
    shoulder_y: float,
    waist_y: float,
    hip_y: float,
    skin: dict,
) -> None:
    base, dark, light = _skin_colors(skin, False)
    outer = [
        (upper_x - 18, shoulder_y + 4), (upper_x - 14, shoulder_y + 1),
        (upper_x - 5, shoulder_y), (upper_x + 6, shoulder_y),
        (upper_x + 14, shoulder_y + 1), (upper_x + 18, shoulder_y + 4),
        (upper_x + 16, shoulder_y + 11), (upper_x + 12, waist_y - 2),
        (upper_x + 11, hip_y - 2), (upper_x - 11, hip_y - 2),
        (upper_x - 12, waist_y - 2), (upper_x - 16, shoulder_y + 11),
    ]
    polygon(s, outer, dark)
    inner = [
        (upper_x - 16, shoulder_y + 5), (upper_x - 13, shoulder_y + 2),
        (upper_x - 5, shoulder_y + 1), (upper_x + 6, shoulder_y + 1),
        (upper_x + 13, shoulder_y + 2), (upper_x + 16, shoulder_y + 5),
        (upper_x + 14, shoulder_y + 11), (upper_x + 10, waist_y - 2),
        (upper_x + 9, hip_y - 3), (upper_x - 9, hip_y - 3),
        (upper_x - 10, waist_y - 2), (upper_x - 14, shoulder_y + 11),
    ]
    polygon(s, inner, base)
    line(s, (upper_x - 15, shoulder_y + 6), (upper_x - 5, shoulder_y + 9), light)
    line(s, (upper_x + 15, shoulder_y + 5), (upper_x + 6, shoulder_y + 8), dark)
    line(s, (upper_x - 12, shoulder_y + 10), (upper_x - 4, shoulder_y + 8), dark)
    line(s, (upper_x + 11, shoulder_y + 10), (upper_x + 3, shoulder_y + 8), dark)
    polygon(
        s,
        [(upper_x - 12, shoulder_y + 14), (upper_x - 2, shoulder_y + 13),
         (upper_x - 1, waist_y - 5), (upper_x - 8, waist_y - 5)],
        light,
    )
    polygon(
        s,
        [(upper_x + 12, shoulder_y + 13), (upper_x + 2, shoulder_y + 13),
         (upper_x + 2, waist_y - 6), (upper_x + 9, waist_y - 5)],
        dark,
    )
    line(s, (upper_x - 1, shoulder_y + 15), (upper_x - 1, hip_y - 4), dark)
    for y in (shoulder_y + 20, shoulder_y + 26):
        line(s, (upper_x - 4, y), (upper_x + 4, y), dark)
    line(s, (upper_x - 8, waist_y - 3), (upper_x + 8, waist_y - 3), dark)
    s.px(*pt((upper_x - 7, shoulder_y + 16)), light)
    s.px(*pt((upper_x + 6, shoulder_y + 17)), light)


def draw_body_pelvis(
    s: Sprite,
    upper_x: float,
    waist_y: float,
    hip_y: float,
    skin: dict,
) -> None:
    base, dark, light = _skin_colors(skin, False)
    outer = [
        (upper_x - 12, waist_y - 2), (upper_x + 12, waist_y - 2),
        (upper_x + 15, hip_y + 1), (upper_x + 10, hip_y + 5),
        (upper_x + 4, hip_y + 4), (upper_x, hip_y + 6),
        (upper_x - 4, hip_y + 4), (upper_x - 10, hip_y + 5),
        (upper_x - 15, hip_y + 1),
    ]
    polygon(s, outer, dark)
    inner = [
        (upper_x - 10, waist_y - 1), (upper_x + 10, waist_y - 1),
        (upper_x + 12, hip_y), (upper_x + 8, hip_y + 3),
        (upper_x + 3, hip_y + 2), (upper_x, hip_y + 4),
        (upper_x - 3, hip_y + 2), (upper_x - 8, hip_y + 3),
        (upper_x - 12, hip_y),
    ]
    polygon(s, inner, base)
    line(s, (upper_x - 10, waist_y + 1), (upper_x + 10, waist_y + 1), WRAP_D)
    line(s, (upper_x - 11, waist_y + 2), (upper_x + 11, waist_y + 2), WRAP)
    s.rect(
        pt((upper_x - 7, waist_y + 3)),
        pt((upper_x + 7, hip_y - 1)),
        WRAP_D,
    )
    s.rect(
        pt((upper_x - 6, waist_y + 3)),
        pt((upper_x + 6, hip_y - 2)),
        WRAP,
    )
    line(s, (upper_x - 4, waist_y + 5), (upper_x + 4, hip_y - 3), WRAP_L)
    line(s, (upper_x - 9, hip_y), (upper_x + 9, hip_y), dark)
    line(s, (upper_x - 10, hip_y + 1), (upper_x - 4, hip_y + 4), light)
    line(s, (upper_x + 10, hip_y + 1), (upper_x + 4, hip_y + 4), dark)


def draw_body_neck(
    s: Sprite,
    hx: float,
    hy: float,
    upper_x: float,
    shoulder_y: float,
    skin: dict,
) -> None:
    base, dark, light = _skin_colors(skin, False)
    polygon(
        s,
        [(hx - 4, hy + 6), (hx + 4, hy + 6),
         (hx + 5, shoulder_y + 1), (hx - 5, shoulder_y + 1)],
        dark,
    )
    polygon(
        s,
        [(hx - 3, hy + 7), (hx + 3, hy + 7),
         (hx + 3, shoulder_y), (hx - 3, shoulder_y)],
        base,
    )
    line(s, (hx - 2, hy + 8), (hx + 3, hy + 8), light)
    line(s, (upper_x - 12, shoulder_y + 3), (hx - 4, shoulder_y), dark)
    line(s, (upper_x + 12, shoulder_y + 3), (hx + 4, shoulder_y), dark)
    line(s, (upper_x - 8, shoulder_y + 5), (hx - 3, shoulder_y + 3), light)
    line(s, (upper_x + 8, shoulder_y + 5), (hx + 3, shoulder_y + 3), light)


def draw_body_head(
    s: Sprite,
    hx: float,
    hy: float,
    skin: dict,
) -> None:
    base, dark, light = _skin_colors(skin, False)
    x, y = pt((hx, hy))
    s.rect((x - 4, y + 7), (x + 4, y + 12), dark)
    s.ellipse(x - 9, y - 10, x + 8, y + 10, HAIR_D, fill=True)
    s.ellipse(x - 8, y - 9, x + 8, y + 9, HAIR, fill=True)
    s.ellipse(x - 8, y - 8, x + 8, y + 8, dark, fill=True)
    s.ellipse(x - 7, y - 8, x + 7, y + 7, base, fill=True)
    s.ellipse(x - 5, y - 7, x + 5, y + 5, light, fill=True)
    s.px(x + 8, y - 1, base)
    s.px(x + 9, y, dark)
    s.px(x + 8, y + 1, dark)
    s.rect((x - 8, y - 5), (x - 6, y + 3), HAIR)
    s.rect((x - 8, y + 4), (x - 6, y + 9), HAIR_D)
    s.rect((x - 2, y - 1), (x, y), INK)
    s.rect((x + 4, y - 1), (x + 6, y), INK)
    s.px(x - 2, y - 1, WHITE)
    s.px(x + 4, y - 1, WHITE)
    line(s, (x - 3, y - 3), (x, y - 4), HAIR_D)
    line(s, (x + 4, y - 4), (x + 7, y - 3), HAIR_D)
    s.rect((x + 7, y + 3), (x + 9, y + 4), dark)
    line(s, (x + 3, y + 4), (x + 7, y + 4), dark)
    line(s, (x + 1, y + 7), (x + 6, y + 7), dark)
    s.px(x + 4, y + 8, base)
    line(s, (x - 6, y - 10), (x + 5, y - 10), HAIR_D)
    line(s, (x - 8, y - 7), (x - 6, y - 2), HAIR_L)


def draw_body_layer(s: Sprite, pose: dict, skin: dict) -> None:
    upper_x = 60.0 + float(pose["lean"])
    shoulder_y = float(pose["shoulder_y"])
    waist_y = float(pose["waist_y"])
    hip_y = float(pose["hip_y"])
    draw_shadow(s)
    far_hip, far_ankle = leg_points(pose, "far")
    near_hip, near_ankle = leg_points(pose, "near")
    draw_body_leg(s, far_hip, far_ankle, skin, True)
    draw_body_leg(s, near_hip, near_ankle, skin, False)
    far_shoulder = shoulder_points(pose, "far")
    near_shoulder = shoulder_points(pose, "near")
    far_mode = far_arm_mode(pose)
    if far_mode in ("back", "split"):
        draw_body_arm(s, far_shoulder, pose["far_hand"], skin, True)
    draw_body_torso(s, upper_x, shoulder_y, waist_y, hip_y, skin)
    draw_body_pelvis(s, upper_x, waist_y, hip_y, skin)
    if far_mode == "front":
        draw_body_arm(s, far_shoulder, pose["far_hand"], skin, True)
    elif far_mode == "split":
        draw_body_arm(s, far_shoulder, pose["far_hand"], skin, True, lower_only=True)
    draw_body_arm(s, near_shoulder, pose["near_hand"], skin, False)
    head_x = upper_x + 2.0 + float(pose["head_dx"])
    head_y = BODY_Y["head"] + float(pose["bob"]) + float(pose["head_dy"])
    draw_body_neck(s, head_x, head_y, upper_x, shoulder_y, skin)
    draw_body_head(s, head_x, head_y, skin)


def _cloth_colors(outfit: dict, far: bool) -> tuple[str, str, str]:
    if far:
        return outfit["cloth_d"], INK, outfit["cloth"]
    return outfit["cloth"], outfit["cloth_d"], outfit["cloth_l"]


def _metal_colors(outfit: dict, far: bool) -> tuple[str, str, str]:
    if far:
        return outfit["metal_d"], INK, outfit["metal"]
    return outfit["metal"], outfit["metal_d"], outfit["metal_l"]


def draw_outfit_leg(
    s: Sprite,
    pose: dict,
    side: str,
    outfit: dict,
) -> None:
    far = side == "far"
    hip, ankle = leg_points(pose, side)
    knee = clamped_ik(hip, ankle, LEG_UPPER, LEG_LOWER, 1 if far else -1, "outfit leg")
    cloth, cloth_d, cloth_l = _cloth_colors(outfit, far)
    metal, metal_d, metal_l = _metal_colors(outfit, far)
    hx, hy = pt(hip)
    s.circle(hx, hy, 5, cloth_d, fill=True)
    s.circle(hx, hy, 4, cloth, fill=True)
    draw_segment(s, hip, knee, 12.0, 10.0, cloth, cloth_d, cloth_l, rim=False)
    legs = outfit["legs"]
    if legs == "greaves":
        draw_segment(s, knee, ankle, 10.0, 8.0, metal, metal_d, metal_l, rim=False)
        kx, ky = pt(knee)
        polygon(
            s,
            [(kx - 5, ky - 3), (kx + 5, ky - 3),
             (kx + 4, ky + 4), (kx - 4, ky + 4)],
            metal_d,
        )
        polygon(
            s,
            [(kx - 4, ky - 2), (kx + 4, ky - 2),
             (kx + 3, ky + 3), (kx - 3, ky + 3)],
            metal,
        )
        line(s, (kx - 3, ky - 1), (kx + 3, ky - 1), metal_l)
        s.px(kx - 1, ky + 1, outfit["accent"])
        s.px(kx + 2, ky + 1, outfit["accent"])
        draw_foot(s, ankle, LEATHER_D, LEATHER_D, LEATHER_L, boot=True)
    elif legs == "pants":
        draw_segment(s, knee, ankle, 9.0, 7.0, cloth, cloth_d, cloth_l, rim=False)
        chord_mid = add(hip, mul(sub(ankle, hip), 0.5))
        draw_joint(s, knee, 4, cloth, cloth_d, cloth_l, sub(chord_mid, knee))
        ax, ay = pt(ankle)
        s.circle(ax, ay, 3, cloth_d, fill=True)
        s.circle(ax, ay, 2, cloth, fill=True)
        line(s, (ax - 3, ay - 2), (ax + 3, ay - 2), cloth_l)
        draw_foot(s, ankle, LEATHER_D, LEATHER_D, LEATHER_L, boot=True)
    else:
        line(s, (hx - 3, hy + 1), (hx + 3, hy + 2), cloth_d)
        ax, ay = pt(ankle)
        s.circle(ax, ay, 3, LEATHER_D, fill=True)
        s.circle(ax, ay, 2, LEATHER, fill=True)
        draw_foot(s, ankle, LEATHER, LEATHER_D, LEATHER_L, boot=True)


def draw_outfit_arm(
    s: Sprite,
    pose: dict,
    side: str,
    outfit: dict,
    lower_only: bool = False,
) -> None:
    far = side == "far"
    shoulder = shoulder_points(pose, side)
    hand = tuple(pose[f"{side}_hand"])
    elbow = clamped_ik(shoulder, hand, ARM_UPPER, ARM_LOWER, 1 if far else -1, "outfit arm")
    cloth, cloth_d, cloth_l = _cloth_colors(outfit, far)
    metal, metal_d, metal_l = _metal_colors(outfit, far)
    sleeve = outfit["sleeve"]
    if sleeve == "none":
        if outfit["armored"]:
            draw_segment(s, elbow, hand, 8.0, 6.0, metal, metal_d, metal_l, rim=False)
        else:
            draw_segment(s, elbow, hand, 8.0, 6.0, LEATHER, LEATHER_D, LEATHER_L, rim=False)
    elif sleeve == "short":
        if not lower_only:
            sx, sy = pt(shoulder)
            s.circle(sx, sy, 6, cloth_d, fill=True)
            s.circle(sx, sy, 5, cloth, fill=True)
            draw_segment(s, shoulder, elbow, 11.0, 9.0, cloth, cloth_d, cloth_l, rim=False)
        if outfit["armored"]:
            draw_segment(s, elbow, hand, 8.0, 6.0, metal, metal_d, metal_l, rim=False)
        else:
            draw_segment(s, elbow, hand, 8.0, 6.0, LEATHER, LEATHER_D, LEATHER_L, rim=False)
    else:
        if not lower_only:
            sx, sy = pt(shoulder)
            s.circle(sx, sy, 6, cloth_d, fill=True)
            s.circle(sx, sy, 5, cloth, fill=True)
            draw_segment(s, shoulder, elbow, 11.0, 9.0, cloth, cloth_d, cloth_l, rim=False)
        chord_mid = add(shoulder, mul(sub(hand, shoulder), 0.5))
        draw_joint(s, elbow, 4, cloth, cloth_d, cloth_l, sub(chord_mid, elbow))
        if outfit["armored"]:
            draw_segment(s, elbow, hand, 8.0, 6.0, metal, metal_d, metal_l, rim=False)
        else:
            draw_segment(s, elbow, hand, 8.0, 6.0, cloth, cloth_d, cloth_l, rim=False)
    forearm_dir = unit(sub(hand, elbow))
    cuff = add(hand, mul(forearm_dir, -2.5))
    n = (-forearm_dir[1], forearm_dir[0])
    line(s, add(cuff, mul(n, -3.5)), add(cuff, mul(n, 3.5)), outfit["accent"])
    line(s, add(cuff, mul(n, -2.5)), add(cuff, mul(n, 2.5)), outfit["accent_l"])


def draw_outfit_torso(
    s: Sprite,
    upper_x: float,
    shoulder_y: float,
    waist_y: float,
    outfit: dict,
) -> None:
    cloth = outfit["cloth"]
    cloth_d = outfit["cloth_d"]
    cloth_l = outfit["cloth_l"]
    outer = [
        (upper_x - 17, shoulder_y + 2), (upper_x + 17, shoulder_y + 1),
        (upper_x + 15, shoulder_y + 11), (upper_x + 11, waist_y),
        (upper_x - 11, waist_y), (upper_x - 15, shoulder_y + 11),
    ]
    polygon(s, outer, cloth_d)
    inner = [
        (upper_x - 15, shoulder_y + 3), (upper_x + 15, shoulder_y + 2),
        (upper_x + 13, shoulder_y + 11), (upper_x + 9, waist_y - 1),
        (upper_x - 9, waist_y - 1), (upper_x - 13, shoulder_y + 11),
    ]
    polygon(s, inner, cloth)
    if outfit["armored"]:
        metal, metal_d, metal_l = _metal_colors(outfit, False)
        plate = [
            (upper_x - 13, shoulder_y + 4), (upper_x + 13, shoulder_y + 3),
            (upper_x + 9, waist_y - 3), (upper_x - 9, waist_y - 3),
        ]
        polygon(s, plate, metal_d)
        inner_plate = [
            (upper_x - 12, shoulder_y + 5), (upper_x + 12, shoulder_y + 4),
            (upper_x + 8, waist_y - 4), (upper_x - 8, waist_y - 4),
        ]
        polygon(s, inner_plate, metal)
        for y in range(int(shoulder_y) + 8, int(waist_y) - 3, 4):
            line(s, (upper_x - 10, y), (upper_x + 10, y), metal_d)
            line(s, (upper_x - 9, y + 1), (upper_x + 9, y + 1), metal_l)
            s.px(*pt((upper_x - 7, y + 1)), outfit["accent"])
            s.px(*pt((upper_x + 8, y + 1)), outfit["accent"])
        s.px(*pt((upper_x, shoulder_y + 7)), outfit["accent_l"])
    else:
        line(s, (upper_x - 10, shoulder_y + 4), (upper_x + 3, waist_y - 3), cloth_l)
        line(s, (upper_x + 9, shoulder_y + 4), (upper_x - 2, waist_y - 3), cloth_d)
        line(s, (upper_x - 8, shoulder_y + 9), (upper_x + 10, shoulder_y + 9), outfit["accent"])
        s.px(*pt((upper_x + 2, shoulder_y + 10)), outfit["accent_l"])
    belt_y = waist_y + 1
    s.rect(pt((upper_x - 12, belt_y)), pt((upper_x + 12, belt_y + 3)), LEATHER_D)
    s.rect(pt((upper_x - 11, belt_y + 1)), pt((upper_x + 11, belt_y + 2)), outfit["accent"])
    s.rect(pt((upper_x - 2, belt_y)), pt((upper_x + 2, belt_y + 3)), outfit["accent_l"])


def draw_outfit_pelvis(
    s: Sprite,
    upper_x: float,
    waist_y: float,
    hip_y: float,
    outfit: dict,
) -> None:
    cloth = outfit["cloth"]
    cloth_d = outfit["cloth_d"]
    cloth_l = outfit["cloth_l"]
    if outfit["skirt"]:
        if outfit["armored"]:
            metal, metal_d, metal_l = _metal_colors(outfit, False)
            tasset = [
                (upper_x - 12, waist_y + 1), (upper_x + 12, waist_y + 1),
                (upper_x + 16, hip_y + 4), (upper_x + 8, hip_y + 7),
                (upper_x, hip_y + 5), (upper_x - 8, hip_y + 7),
                (upper_x - 16, hip_y + 4),
            ]
            polygon(s, tasset, metal_d)
            for x0, x1 in ((-16, -7), (-4, 4), (7, 16)):
                polygon(
                    s,
                    [(upper_x + x0, waist_y + 2), (upper_x + x1, waist_y + 2),
                     (upper_x + x1 - 2, hip_y + 5), (upper_x + x0 + 1, hip_y + 6)],
                    metal,
                )
                line(s, (upper_x + x0 + 1, waist_y + 3), (upper_x + x1 - 1, waist_y + 3), metal_l)
                s.px(*pt((upper_x + x0 + 2, hip_y + 3)), outfit["accent"])
                s.px(*pt((upper_x + x1 - 2, hip_y + 3)), outfit["accent"])
        else:
            skirt = [
                (upper_x - 11, waist_y + 1), (upper_x + 11, waist_y + 1),
                (upper_x + 15, hip_y + 5), (upper_x + 7, hip_y + 8),
                (upper_x, hip_y + 5), (upper_x - 7, hip_y + 8),
                (upper_x - 15, hip_y + 5),
            ]
            polygon(s, skirt, cloth_d)
            inner = [
                (upper_x - 9, waist_y + 2), (upper_x + 9, waist_y + 2),
                (upper_x + 12, hip_y + 4), (upper_x + 6, hip_y + 6),
                (upper_x, hip_y + 4), (upper_x - 6, hip_y + 6),
                (upper_x - 12, hip_y + 4),
            ]
            polygon(s, inner, cloth)
            line(s, (upper_x - 4, waist_y + 3), (upper_x - 7, hip_y + 5), cloth_l)
            line(s, (upper_x + 4, waist_y + 3), (upper_x + 7, hip_y + 5), cloth_d)
    else:
        s.rect(pt((upper_x - 11, waist_y + 1)), pt((upper_x + 11, hip_y)), cloth_d)
        s.rect(pt((upper_x - 10, waist_y + 2)), pt((upper_x + 10, hip_y - 1)), cloth)
    line(s, (upper_x - 10, waist_y + 2), (upper_x + 10, waist_y + 2), outfit["accent"])
    s.px(*pt((upper_x, waist_y + 2)), outfit["accent_l"])


def draw_shoulder_guard(
    s: Sprite,
    pose: dict,
    side: str,
    outfit: dict,
) -> None:
    shoulder = shoulder_points(pose, side)
    far = side == "far"
    cx, cy = pt((shoulder[0], shoulder[1] + 2))
    armored = outfit["shoulders"] == "plate"
    if armored:
        base, dark, light = _metal_colors(outfit, far)
        rim = outfit["accent"]
    elif outfit["shoulders"] == "cloth":
        base, dark, light = _cloth_colors(outfit, far)
        rim = outfit["cloth_l"]
    else:
        return
    outer = [
        (cx - 9, cy + 6), (cx - 10, cy + 1), (cx - 7, cy - 4),
        (cx - 3, cy - 7), (cx + 2, cy - 7), (cx + 6, cy - 4),
        (cx + 8, cy), (cx + 8, cy + 6), (cx + 4, cy + 8),
        (cx - 4, cy + 8),
    ]
    inner = [
        (cx - 7, cy + 5), (cx - 8, cy + 1), (cx - 5, cy - 3),
        (cx - 2, cy - 5), (cx + 1, cy - 5), (cx + 4, cy - 3),
        (cx + 6, cy), (cx + 6, cy + 5), (cx + 3, cy + 6),
        (cx - 3, cy + 6),
    ]
    polygon(s, outer, dark)
    polygon(s, inner, base)
    line(s, (cx - 7, cy - 1), (cx - 1, cy - 6), light)
    line(s, (cx - 1, cy - 6), (cx + 5, cy - 2), light)
    line(s, (cx - 8, cy + 2), (cx + 6, cy + 2), rim)
    if armored:
        s.px(cx - 5, cy + 3, outfit["accent_l"])
        s.px(cx + 4, cy + 3, outfit["accent_l"])
        line(s, (cx - 4, cy + 6), (cx + 4, cy + 6), dark)
    else:
        line(s, (cx - 5, cy + 5), (cx + 4, cy + 5), dark)


def draw_outfit_collar(
    s: Sprite,
    pose: dict,
    outfit: dict,
) -> None:
    upper_x = 60.0 + float(pose["lean"])
    shoulder_y = float(pose["shoulder_y"])
    head_x = upper_x + 2.0 + float(pose["head_dx"])
    collar_top = shoulder_y - 4
    cloth, cloth_d, cloth_l = _cloth_colors(outfit, False)
    if outfit["armored"]:
        metal, metal_d, metal_l = _metal_colors(outfit, False)
        polygon(
            s,
            [(head_x - 9, collar_top), (head_x + 9, collar_top),
             (head_x + 7, shoulder_y + 3), (head_x - 7, shoulder_y + 3)],
            metal_d,
        )
        polygon(
            s,
            [(head_x - 8, collar_top + 1), (head_x + 8, collar_top + 1),
             (head_x + 6, shoulder_y + 2), (head_x - 6, shoulder_y + 2)],
            metal,
        )
        line(s, (head_x - 7, collar_top + 2), (head_x + 7, collar_top + 2), metal_l)
        line(s, (head_x - 5, collar_top + 4), (head_x + 5, collar_top + 4), outfit["accent"])
    else:
        polygon(
            s,
            [(head_x - 9, collar_top), (head_x + 9, collar_top),
             (head_x + 7, shoulder_y + 3), (head_x - 7, shoulder_y + 3)],
            cloth_d,
        )
        polygon(
            s,
            [(head_x - 8, collar_top + 1), (head_x - 1, collar_top + 1),
             (head_x - 2, shoulder_y + 1), (head_x - 6, shoulder_y + 2)],
            cloth,
        )
        polygon(
            s,
            [(head_x + 1, collar_top + 1), (head_x + 8, collar_top + 1),
             (head_x + 6, shoulder_y + 2), (head_x + 2, shoulder_y + 1)],
            cloth,
        )
        line(s, (head_x - 7, collar_top + 1), (head_x - 2, shoulder_y + 1), cloth_l)
        line(s, (head_x + 7, collar_top + 1), (head_x + 2, shoulder_y + 1), cloth_l)


def draw_outfit_layer(s: Sprite, pose: dict, outfit: dict) -> None:
    upper_x = 60.0 + float(pose["lean"])
    shoulder_y = float(pose["shoulder_y"])
    waist_y = float(pose["waist_y"])
    hip_y = float(pose["hip_y"])
    draw_outfit_leg(s, pose, "far", outfit)
    draw_outfit_leg(s, pose, "near", outfit)
    far_mode = far_arm_mode(pose)
    if far_mode in ("back", "split"):
        draw_outfit_arm(s, pose, "far", outfit)
        draw_shoulder_guard(s, pose, "far", outfit)
    draw_outfit_torso(s, upper_x, shoulder_y, waist_y, outfit)
    draw_outfit_pelvis(s, upper_x, waist_y, hip_y, outfit)
    if far_mode == "front":
        draw_outfit_arm(s, pose, "far", outfit)
        draw_shoulder_guard(s, pose, "far", outfit)
    elif far_mode == "split":
        draw_outfit_arm(s, pose, "far", outfit, lower_only=True)
    draw_outfit_arm(s, pose, "near", outfit)
    draw_shoulder_guard(s, pose, "near", outfit)
    draw_outfit_collar(s, pose, outfit)


def _head_point(pose: dict) -> tuple[float, float]:
    upper_x = 60.0 + float(pose["lean"])
    return (
        upper_x + 2.0 + float(pose["head_dx"]),
        BODY_Y["head"] + float(pose["bob"]) + float(pose["head_dy"]),
    )


def draw_headgear_layer(s: Sprite, pose: dict, gear: dict) -> None:
    kind = gear["kind"]
    if kind == "none":
        return
    hx, hy = _head_point(pose)
    x, y = pt((hx, hy))
    if kind == "ming_helmet":
        cloth = gear["cloth"]
        cloth_d = gear["cloth_d"]
        cloth_l = gear["cloth_l"]
        s.ellipse(x - 11, y - 15, x + 11, y - 4, IRON_D, fill=True)
        s.ellipse(x - 10, y - 14, x + 10, y - 5, IRON, fill=True)
        s.ellipse(x - 8, y - 13, x + 6, y - 8, IRON_L, fill=True)
        s.rect((x - 12, y - 5), (x + 12, y - 3), IRON_D)
        s.rect((x - 11, y - 4), (x + 11, y - 3), GOLD)
        s.rect((x - 2, y - 19), (x + 2, y - 14), GOLD)
        polygon(
            s,
            [(x - 1, y - 20), (x + 1, y - 20), (x + 5, y - 17),
             (x, y - 15), (x - 5, y - 17)],
            cloth_d,
        )
        polygon(
            s,
            [(x, y - 19), (x + 2, y - 17), (x, y - 16), (x - 2, y - 17)],
            cloth_l if cloth_l != cloth else cloth,
        )
        line(s, (x - 11, y - 3), (x - 6, y + 8), IRON_D)
        line(s, (x + 11, y - 3), (x + 6, y + 8), IRON_D)
        line(s, (x - 9, y - 6), (x - 7, y + 2), IRON_L)
        line(s, (x + 9, y - 6), (x + 7, y + 2), IRON_L)
        s.px(x - 9, y - 4, GOLD)
        s.px(x + 9, y - 4, GOLD)
    elif kind == "felt_hat":
        cloth = gear["cloth"]
        cloth_d = gear["cloth_d"]
        cloth_l = gear["cloth_l"]
        polygon(
            s,
            [(x - 18, y - 4), (x + 18, y - 4),
             (x + 11, y - 13), (x - 11, y - 13)],
            cloth_d,
        )
        polygon(
            s,
            [(x - 16, y - 5), (x + 16, y - 5),
             (x + 9, y - 12), (x - 9, y - 12)],
            cloth,
        )
        line(s, (x - 16, y - 4), (x + 16, y - 4), cloth_l)
        s.rect((x - 2, y - 12), (x + 2, y - 10), GOLD)
    elif kind == "officer":
        polygon(
            s,
            [(x - 10, y - 8), (x + 10, y - 8),
             (x + 8, y - 13), (x - 8, y - 13)],
            gear["cloth_d"],
        )
        polygon(
            s,
            [(x - 9, y - 9), (x + 9, y - 9),
             (x + 7, y - 12), (x - 7, y - 12)],
            gear["cloth"],
        )
        line(s, (x - 12, y - 7), (x - 19, y - 4), gear["cloth_l"])
        line(s, (x + 12, y - 7), (x + 19, y - 4), gear["cloth_l"])
        s.px(x - 20, y - 4, GOLD)
        s.px(x + 20, y - 4, GOLD)
        s.rect((x - 8, y - 8), (x + 8, y - 7), GOLD)
    elif kind == "headband":
        s.rect((x - 10, y - 6), (x + 10, y - 3), gear["cloth_d"])
        s.rect((x - 9, y - 6), (x + 9, y - 4), gear["cloth"])
        line(s, (x + 8, y - 4), (x + 15, y - 8), gear["cloth"])
        s.px(x + 16, y - 9, gear["cloth_l"])
    elif kind == "kasa":
        cloth = gear["cloth"]
        cloth_d = gear["cloth_d"]
        cloth_l = gear["cloth_l"]
        polygon(
            s,
            [(x - 21, y - 4), (x + 21, y - 4), (x, y - 17)],
            cloth_d,
        )
        polygon(
            s,
            [(x - 18, y - 5), (x + 18, y - 5), (x, y - 15)],
            cloth,
        )
        for dx in (-12, -6, 6, 12):
            line(s, (x + dx, y - 5), (x, y - 13), cloth_d)
        s.rect((x - 2, y - 18), (x + 2, y - 13), cloth_l)
        line(s, (x - 18, y - 4), (x + 18, y - 4), cloth_l)
    elif kind == "horned_helmet":
        s.ellipse(x - 11, y - 15, x + 11, y - 4, IRON_D, fill=True)
        s.ellipse(x - 10, y - 14, x + 10, y - 5, IRON, fill=True)
        s.ellipse(x - 8, y - 13, x + 6, y - 8, IRON_L, fill=True)
        s.rect((x - 11, y - 5), (x + 11, y - 3), IRON_D)
        line(s, (x - 10, y - 4), (x + 10, y - 4), IRON_L)
        s.rect((x - 2, y - 20), (x + 2, y - 14), GOLD)
        polygon(
            s,
            [(x - 5, y - 13), (x - 18, y - 20), (x - 3, y - 8)],
            GOLD_D,
        )
        polygon(
            s,
            [(x + 5, y - 13), (x + 18, y - 20), (x + 3, y - 8)],
            GOLD_D,
        )
        line(s, (x - 5, y - 13), (x - 17, y - 19), GOLD_L)
        line(s, (x + 5, y - 13), (x + 17, y - 19), GOLD_L)
    elif kind == "monk_hood":
        cloth = gear["cloth"]
        cloth_d = gear["cloth_d"]
        cloth_l = gear["cloth_l"]
        s.ellipse(x - 12, y - 11, x + 12, y + 11, cloth_d, fill=True)
        s.ellipse(x - 8, y - 9, x + 9, y + 9, cloth, fill=True)
        polygon(
            s,
            [(x - 9, y + 1), (x + 9, y + 1),
             (x + 8, y + 9), (x - 8, y + 9)],
            cloth_d,
        )
        line(s, (x - 8, y - 8), (x - 8, y + 7), cloth_l)
        line(s, (x + 7, y - 7), (x + 7, y + 7), cloth_d)
        s.px(x - 7, y - 1, WHITE)
        s.px(x + 7, y - 1, WHITE)
    elif kind == "oni_mask":
        cloth = gear["cloth"]
        cloth_d = gear["cloth_d"]
        s.ellipse(x - 11, y - 7, x + 10, y + 10, cloth_d, fill=True)
        s.ellipse(x - 9, y - 6, x + 9, y + 9, cloth, fill=True)
        s.rect((x - 8, y - 2), (x + 8, y + 1), WHITE)
        s.rect((x - 5, y - 1), (x - 1, y + 1), INK)
        s.rect((x + 3, y - 1), (x + 7, y + 1), INK)
        s.rect((x - 3, y + 5), (x + 6, y + 7), INK)
        for dx in (-1, 2, 5):
            s.px(x + dx, y + 5, WHITE)
        polygon(
            s,
            [(x - 7, y - 6), (x - 17, y - 17), (x - 3, y - 7)],
            GOLD,
        )
        polygon(
            s,
            [(x + 7, y - 6), (x + 17, y - 17), (x + 3, y - 7)],
            GOLD,
        )
    elif kind == "bandana":
        s.rect((x - 10, y - 6), (x + 10, y - 3), gear["cloth_d"])
        s.rect((x - 9, y - 6), (x + 9, y - 4), gear["cloth"])
        line(s, (x + 7, y - 4), (x + 14, y - 8), gear["cloth"])
        s.px(x + 15, y - 9, gear["cloth_l"])
        s.px(x - 8, y - 5, gear["cloth_l"])


def draw_backgear_layer(s: Sprite, pose: dict, gear: dict) -> None:
    kind = gear["kind"]
    if kind == "none":
        return
    upper_x = 60.0 + float(pose["lean"])
    bob = int(pose["bob"])
    phase = float(pose["phase"])
    sway = math.sin(phase) * 3.0
    if kind == "cape":
        cloth = gear["cloth"]
        cloth_d = gear["cloth_d"]
        cloth_l = gear["cloth_l"]
        top_y = 40 + bob
        points = [
            (upper_x - 15, top_y), (upper_x + 18, top_y),
            (upper_x + 29 + sway, 92), (upper_x + 18 + sway, 88),
            (upper_x + 12, 98), (upper_x + 3 + sway, 89),
            (upper_x - 5, 96), (upper_x - 18 + sway, 87),
        ]
        polygon(s, points, cloth_d)
        inner = [
            (upper_x - 12, top_y + 2), (upper_x + 15, top_y + 2),
            (upper_x + 25 + sway, 89), (upper_x + 15 + sway, 85),
            (upper_x + 10, 94), (upper_x + 2 + sway, 86),
            (upper_x - 3, 92), (upper_x - 15 + sway, 84),
        ]
        polygon(s, inner, cloth)
        line(s, (upper_x - 2, top_y + 10), (upper_x - 10 + sway, 83), cloth_l)
        line(s, (upper_x + 11, top_y + 12), (upper_x + 13 + sway, 88), cloth_l)
    elif kind == "banner":
        cloth = gear["cloth"]
        cloth_d = gear["cloth_d"]
        cloth_l = gear["cloth_l"]
        wave = math.sin(phase * 1.3) * 3.0
        pole_x = upper_x - 28
        s.rect(pt((pole_x, 20 + bob)), pt((pole_x + 2, 96)), LEATHER_D)
        line(s, (pole_x + 1, 23 + bob), (pole_x + 1, 92), LEATHER_L)
        polygon(
            s,
            [(pole_x + 2, 21 + bob), (pole_x + 33 + wave, 25 + bob),
             (pole_x + 31 + wave, 53 + bob), (pole_x + 21, 58 + bob),
             (pole_x + 12, 53 + bob), (pole_x + 2, 56 + bob)],
            cloth_d,
        )
        polygon(
            s,
            [(pole_x + 4, 24 + bob), (pole_x + 30 + wave, 28 + bob),
             (pole_x + 28 + wave, 49 + bob), (pole_x + 19, 53 + bob),
             (pole_x + 11, 49 + bob), (pole_x + 4, 52 + bob)],
            cloth,
        )
        line(s, (pole_x + 5, 27 + bob), (pole_x + 29 + wave, 31 + bob), cloth_l)
        for y in (35, 44):
            s.rect(
                pt((pole_x + 7, y + bob)),
                pt((pole_x + 26 + int(wave), y + bob + 1)),
                GOLD,
            )
        s.rect(pt((pole_x + 15, 29 + bob)), pt((pole_x + 20, 45 + bob)), GOLD)
        s.rect(pt((pole_x + 17, 31 + bob)), pt((pole_x + 18, 43 + bob)), cloth)


def _blade_polygon(
    s: Sprite,
    near: tuple[float, float],
    angle: float,
    blade_length: float,
    width: float,
    base: str,
    light: str,
    curve: float = 0.0,
) -> tuple[tuple[float, float], tuple[float, float]]:
    d = (math.cos(angle), math.sin(angle))
    n = (-d[1], d[0])
    tip = add(near, mul(d, blade_length))
    mid = add(near, add(mul(d, blade_length * 0.58), mul(n, curve)))
    pts = [
        add(near, mul(n, -width)),
        add(mid, mul(n, -width * 1.05)),
        add(tip, mul(n, -width * 0.25)),
        add(tip, mul(n, width * 0.25)),
        add(mid, mul(n, width * 1.05)),
        add(near, mul(n, width)),
    ]
    polygon(s, pts, base)
    line(s, add(mid, mul(n, -width * 0.55)), add(tip, mul(n, -width * 0.15)), light)
    s.px(*pt(tip), WHITE)
    return tip, n


def _slash_effect(s: Sprite, pose: dict, center: tuple[float, float], radius: float, color: str) -> None:
    stage = int(pose["stage"])
    if stage < 2 or stage > 4:
        return
    angle = math.degrees(float(pose["weapon_angle"]))
    spread = 48 if stage == 3 else 34
    draw_arc(s, center, angle - spread, angle + spread * 0.65, radius, color)


def draw_weapon_dao(s: Sprite, pose: dict) -> None:
    hand = pose["near_hand"]
    angle = float(pose["weapon_angle"])
    d = (math.cos(angle), math.sin(angle))
    n = (-d[1], d[0])
    line(s, add(hand, mul(d, -7)), hand, LEATHER_D)
    line(s, add(hand, mul(d, -6)), add(hand, mul(d, -2)), LEATHER_L)
    line(s, add(hand, mul(n, -5)), add(hand, mul(n, 5)), GOLD)
    line(s, add(hand, mul(n, -4)), add(hand, mul(n, 4)), GOLD_L)
    s.px(*pt(add(hand, mul(d, -8))), RED_L)
    tip, n2 = _blade_polygon(s, hand, angle, 29, 2.6, IRON, IRON_LL, -2.1)
    line(s, add(hand, mul(d, 3)), add(tip, mul(n2, 0.8)), IRON_L)
    _slash_effect(s, pose, hand, 31, WHITE if int(pose["stage"]) == 3 else GOLD_L)


def draw_weapon_jian(s: Sprite, pose: dict) -> None:
    near = pose["near_hand"]
    angle = float(pose["weapon_angle"])
    d = (math.cos(angle), math.sin(angle))
    n = (-d[1], d[0])
    line(s, add(near, mul(d, -7)), near, LEATHER_D)
    line(s, add(near, mul(d, -6)), add(near, mul(d, -2)), LEATHER_L)
    line(s, add(near, mul(n, -5)), add(near, mul(n, 5)), GOLD)
    line(s, add(near, mul(n, -4)), add(near, mul(n, 4)), GOLD_L)
    tip, _ = _blade_polygon(s, near, angle, 29, 2.4, IRON, IRON_LL, 0.0)
    line(s, add(near, mul(d, 3)), add(tip, mul(n, -0.4)), IRON_L)
    _slash_effect(s, pose, near, 31, WHITE if int(pose["stage"]) == 3 else GOLD_L)


def _draw_pole(
    s: Sprite,
    start: tuple[float, float],
    end: tuple[float, float],
) -> None:
    draw_segment(s, start, end, 4.0, 3.0, WOOD, LEATHER_D, WOOD_L)


def draw_weapon_qiang(s: Sprite, pose: dict) -> None:
    far = pose["far_hand"]
    near = pose["near_hand"]
    d = unit(sub(near, far))
    n = (-d[1], d[0])
    start = add(far, mul(d, -14))
    end = add(near, mul(d, 29))
    _draw_pole(s, start, end)
    polygon(
        s,
        [add(end, mul(n, -4)), add(end, mul(d, 10)), add(end, mul(n, 4))],
        IRON_L,
    )
    line(s, add(end, mul(d, 1)), add(end, mul(d, 8)), IRON_LL)
    s.rect(pt(add(end, mul(n, -1))), pt(add(end, mul(n, 1))), GOLD)
    tassel = add(end, mul(d, -1))
    line(s, tassel, add(tassel, mul(n, 5)), RED_L)
    line(s, tassel, add(tassel, mul(n, -3)), RED)
    if int(pose["stage"]) in (2, 3, 4):
        tip = add(end, mul(d, 10))
        for offset in (-6, 0, 6):
            line(s, add(tip, mul(n, offset)), add(tip, add(mul(d, 10), mul(n, offset))), WARM_WHITE)


def draw_weapon_ji(s: Sprite, pose: dict) -> None:
    far = pose["far_hand"]
    near = pose["near_hand"]
    d = unit(sub(near, far))
    n = (-d[1], d[0])
    start = add(far, mul(d, -12))
    end = add(near, mul(d, 27))
    _draw_pole(s, start, end)
    tip = add(end, mul(d, 8))
    polygon(s, [add(end, mul(n, -3)), tip, add(end, mul(n, 3))], IRON_L)
    s.px(*pt(tip), WHITE)
    crescent = [
        add(end, mul(n, -1)),
        add(add(end, mul(n, -10)), mul(d, 1)),
        add(add(end, mul(n, -15)), mul(d, 9)),
        add(add(end, mul(n, -5)), mul(d, 13)),
        add(end, mul(n, 2)),
    ]
    polygon(s, crescent, IRON_L)
    line(s, add(add(end, mul(n, -7)), mul(d, 3)), add(add(end, mul(n, -11)), mul(d, 8)), IRON_LL)
    s.rect(pt(add(end, mul(n, -1))), pt(add(end, mul(n, 1))), GOLD)
    _slash_effect(s, pose, near, 32, GOLD_L)


def draw_weapon_fu(s: Sprite, pose: dict) -> None:
    far = pose["far_hand"]
    near = pose["near_hand"]
    d = unit(sub(near, far))
    n = (-d[1], d[0])
    start = add(far, mul(d, -10))
    end = add(near, mul(d, 19))
    _draw_pole(s, start, end)
    head_center = add(near, mul(d, 17))
    blade = [
        add(head_center, mul(n, -1)),
        add(head_center, add(mul(n, -10), mul(d, -1))),
        add(head_center, add(mul(n, -13), mul(d, 9))),
        add(head_center, add(mul(n, -7), mul(d, 15))),
        add(head_center, add(mul(n, 6), mul(d, 11))),
        add(head_center, add(mul(n, 3), mul(d, 2))),
    ]
    polygon(s, blade, IRON_D)
    polygon(
        s,
        [add(p, mul(n, 1)) for p in blade[1:5]],
        IRON,
    )
    line(s, add(head_center, add(mul(n, -9), mul(d, 3))), add(head_center, add(mul(n, -5), mul(d, 10))), IRON_LL)
    s.rect(pt(add(head_center, mul(n, -1))), pt(add(head_center, mul(n, 1))), GOLD)
    _slash_effect(s, pose, near, 33, GOLD_L)


def draw_weapon_yue(s: Sprite, pose: dict) -> None:
    far = pose["far_hand"]
    near = pose["near_hand"]
    d = unit(sub(near, far))
    n = (-d[1], d[0])
    start = add(far, mul(d, -10))
    end = add(near, mul(d, 22))
    _draw_pole(s, start, end)
    head = add(near, mul(d, 18))
    for side in (-1, 1):
        blade = [
            add(head, mul(n, 1 * side)),
            add(head, add(mul(n, 11 * side), mul(d, -2))),
            add(head, add(mul(n, 15 * side), mul(d, 8))),
            add(head, add(mul(n, 10 * side), mul(d, 16))),
            add(head, add(mul(n, 2 * side), mul(d, 10))),
        ]
        polygon(s, blade, IRON_D)
        polygon(
            s,
            [add(p, mul(d, 1)) for p in blade[1:4]],
            IRON,
        )
        line(
            s,
            add(head, add(mul(n, 11 * side), mul(d, 1))),
            add(head, add(mul(n, 7 * side), mul(d, 12))),
            IRON_LL,
        )
    s.rect(pt(add(head, mul(n, -2))), pt(add(head, mul(n, 2))), GOLD)
    s.px(*pt(add(head, mul(d, 4))), GOLD_L)
    _slash_effect(s, pose, near, 34, GOLD_L)


def _draw_hook(
    s: Sprite,
    hand: tuple[float, float],
    angle: float,
    blade_length: float,
    color: str,
) -> None:
    d = (math.cos(angle), math.sin(angle))
    n = (-d[1], d[0])
    line(s, add(hand, mul(d, -6)), hand, LEATHER_D)
    line(s, add(hand, mul(n, -4)), add(hand, mul(n, 4)), GOLD)
    tip, _ = _blade_polygon(s, hand, angle, blade_length, 2.0, color, IRON_LL, 1.4)
    hook_tip = add(tip, add(mul(d, 5), mul(n, 5)))
    line(s, tip, add(tip, mul(n, 4)), IRON_LL)
    line(s, add(tip, mul(n, 4)), add(hook_tip, mul(d, -2)), IRON_L)
    s.px(*pt(hook_tip), WHITE)


def draw_weapon_gou(s: Sprite, pose: dict) -> None:
    angle = float(pose["weapon_angle"])
    _draw_hook(s, pose["near_hand"], angle, 25, IRON)
    stage = int(pose["stage"])
    if 2 <= stage <= 4:
        draw_arc(s, pose["near_hand"], math.degrees(angle) - 45, math.degrees(angle) + 45, 28, GOLD_L)


def draw_weapon_cha(s: Sprite, pose: dict) -> None:
    far = pose["far_hand"]
    near = pose["near_hand"]
    d = unit(sub(near, far))
    n = (-d[1], d[0])
    start = add(far, mul(d, -12))
    end = add(near, mul(d, 28))
    _draw_pole(s, start, end)
    line(s, add(end, mul(n, -6)), add(end, mul(n, 6)), IRON_L)
    for offset in (-6, 0, 6):
        prong = add(end, mul(n, offset))
        tip = add(prong, mul(d, 8))
        line(s, prong, tip, IRON_L)
        s.px(*pt(tip), WHITE)
    s.rect(pt(add(end, mul(n, -1))), pt(add(end, mul(n, 1))), GOLD)
    if int(pose["stage"]) in (2, 3, 4):
        for offset in (-4, 0, 4):
            line(s, add(end, add(mul(d, 11), mul(n, offset))), add(end, add(mul(d, 20), mul(n, offset))), WARM_WHITE)


def draw_weapon_gong(s: Sprite, pose: dict) -> None:
    far = pose["far_hand"]
    near = pose["near_hand"]
    bx, by = far
    top = (bx, by - 24)
    bottom = (bx, by + 24)
    limbs = (
        top,
        (bx + 7, by - 17),
        (bx + 11, by - 8),
        (bx + 10, by),
        (bx + 11, by + 8),
        (bx + 7, by + 17),
        bottom,
    )
    for index in range(len(limbs) - 1):
        draw_segment(
            s, limbs[index], limbs[index + 1], 3.0, 2.5,
            WOOD, LEATHER_D, OCHRE_L, rim=False, shade_dir=(-1.0, 0.0),
        )
    s.rect((int(bx) + 8, int(by) - 4), (int(bx) + 12, int(by) + 4), LEATHER_D)
    line(s, (bx + 9, by - 3), (bx + 11, by + 3), GOLD)
    line(s, top, near, WARM_WHITE)
    line(s, near, bottom, WARM_WHITE)
    s.circle(*pt((bx + 9, by)), 2, LEATHER_D, fill=True)
    stage = int(pose["stage"])
    if stage >= 2:
        arrow_tip = (bx + 44, by)
        line(s, near, arrow_tip, IRON_L)
        polygon(s, [(bx + 11, by - 2), (bx + 17, by), (bx + 11, by + 2)], GOLD)
        s.px(*pt(arrow_tip), WHITE)
        if stage == 2:
            draw_arc(s, near, -18, 18, 24, WARM_WHITE)
    else:
        line(s, near, (bx + 10, by), IRON_L)


def draw_weapon_nu(s: Sprite, pose: dict) -> None:
    far = pose["far_hand"]
    near = pose["near_hand"]
    d = unit(sub(near, far))
    n = (-d[1], d[0])
    rear = add(far, mul(d, -8))
    muzzle = add(near, mul(d, 24))
    draw_segment(s, rear, muzzle, 5.0, 4.0, WOOD, LEATHER_D, WOOD_L)
    line(s, add(rear, mul(n, -2)), add(muzzle, mul(n, -2)), IRON_D)
    line(s, add(rear, mul(n, 2)), add(muzzle, mul(n, 2)), IRON_L)
    bow_center = add(near, mul(d, 18))
    left_limb = add(bow_center, add(mul(n, -13), mul(d, -4)))
    right_limb = add(bow_center, add(mul(n, 13), mul(d, -4)))
    line(s, left_limb, bow_center, IRON)
    line(s, bow_center, right_limb, IRON)
    line(s, add(left_limb, mul(d, 3)), add(right_limb, mul(d, 3)), WARM_WHITE)
    line(s, add(near, mul(d, 2)), add(bow_center, mul(d, 3)), LEATHER_D)
    s.rect(pt(add(near, mul(d, -1))), pt(add(near, mul(d, 5))), GOLD)
    if int(pose["stage"]) >= 2:
        bolt = add(muzzle, mul(d, 8))
        line(s, add(near, mul(d, 3)), bolt, IRON_L)
        polygon(s, [add(bolt, mul(d, 4)), add(bolt, add(mul(n, -2), mul(d, -3))),
                    add(bolt, add(mul(n, 2), mul(d, -3)))], WHITE)
        draw_arc(s, bow_center, -25, 25, 22, GOLD_L)


def draw_weapon_dun(s: Sprite, pose: dict) -> None:
    center = pose["near_hand"]
    x, y = pt(add(center, (1, -1)))
    s.ellipse(x - 13, y - 16, x + 13, y + 16, IRON_D, fill=True)
    s.ellipse(x - 12, y - 15, x + 12, y + 15, IRON, fill=True)
    s.ellipse(x - 10, y - 13, x + 10, y + 13, RED_D, fill=True)
    s.ellipse(x - 9, y - 12, x + 9, y + 12, RED, fill=True)
    s.ellipse(x - 7, y - 10, x + 5, y - 1, RED_L, fill=True)
    s.ellipse(x - 4, y - 4, x + 4, y + 4, GOLD_D, fill=True)
    s.ellipse(x - 3, y - 3, x + 3, y + 3, GOLD, fill=True)
    s.px(x - 1, y - 2, GOLD_L)
    for dx, dy in ((-7, -8), (7, -8), (-8, 7), (8, 7), (-5, 11), (5, 11)):
        s.circle(x + dx, y + dy, 1, GOLD_L, fill=True)
    line(s, (x - 9, y + 12), (x + 9, y + 12), GOLD_D)
    if int(pose["stage"]) in (2, 3, 4):
        draw_arc(s, center, -70, 55, 25, GOLD_L)


def draw_weapon_niaochong(s: Sprite, pose: dict) -> None:
    hand = pose["near_hand"]
    support = pose["far_hand"]
    angle = float(pose["weapon_angle"])
    d = (math.cos(angle), math.sin(angle))
    n = (-d[1], d[0])
    stock = add(hand, mul(d, -13))
    barrel = add(hand, mul(d, 25))
    line(s, stock, barrel, IRON_D)
    line(s, add(stock, n), add(barrel, n), IRON_L)
    line(s, add(stock, mul(d, 3)), add(barrel, mul(d, -1)), IRON)
    line(s, support, add(hand, mul(d, 9)), LEATHER_D)
    line(s, add(support, (0, 1)), add(hand, add(mul(d, 9), (0, 1))), LEATHER_L)
    s.rect(pt(add(hand, mul(d, -1))), pt(add(hand, mul(d, 4))), GOLD)
    stage = int(pose["stage"])
    if stage >= 2:
        flash = add(barrel, mul(d, 4))
        s.circle(*pt(flash), 5, GOLD, fill=True)
        s.circle(*pt(flash), 3, FIRE, fill=True)
        s.px(*pt(add(flash, (1, -1))), WHITE)
        for k in (-1, 0, 1):
            line(s, add(flash, mul(n, k * 4)), add(flash, mul(n, k * 7 + 1)), FIRE_L)


def draw_weapon_longdeng(s: Sprite, pose: dict) -> None:
    hand = pose["near_hand"]
    angle = float(pose["weapon_angle"])
    d = (math.cos(angle), math.sin(angle))
    n = (-d[1], d[0])
    start = add(hand, mul(d, -19))
    end = add(hand, mul(d, 20))
    _draw_pole(s, start, end)
    head = add(end, mul(d, 5))
    hx, hy = pt(head)
    s.ellipse(hx - 9, hy - 8, hx + 9, hy + 8, RED_D, fill=True)
    s.ellipse(hx - 8, hy - 7, hx + 8, hy + 7, RED, fill=True)
    s.ellipse(hx - 5, hy - 5, hx + 5, hy + 4, GOLD, fill=True)
    s.rect((hx - 4, hy - 2), (hx + 4, hy + 1), WHITE)
    s.rect((hx - 2, hy - 1), (hx, hy), INK)
    s.rect((hx + 2, hy - 1), (hx + 4, hy), INK)
    line(s, (hx - 5, hy + 5), (hx + 5, hy + 5), GOLD_L)
    for dx, dy in ((-8, -9), (0, -12), (8, -9)):
        line(s, (hx + dx, hy + dy), (hx + dx - 2, hy + dy - 5), GOLD_L)
    if int(pose["stage"]) in (2, 3, 4):
        draw_arc(s, head, -80, 60, 28, GOLD_L)
        draw_arc(s, head, 120, 250, 22, FIRE)


def draw_weapon_lingqi(s: Sprite, pose: dict) -> None:
    hand = pose["near_hand"]
    angle = float(pose["weapon_angle"])
    d = (math.cos(angle), math.sin(angle))
    n = (-d[1], d[0])
    start = add(hand, mul(d, -24))
    end = add(hand, mul(d, 22))
    _draw_pole(s, start, end)
    flag_top = add(hand, mul(d, 17))
    wave = math.sin(float(pose["phase"]) * 1.4) * 3.0
    polygon(
        s,
        [flag_top,
         add(flag_top, (18 + wave, 3)),
         add(flag_top, (16 + wave, 24)),
         add(flag_top, (4, 20)),
         add(flag_top, (-4, 23))],
        RED_D,
    )
    polygon(
        s,
        [add(flag_top, (1, 2)),
         add(flag_top, (15 + wave, 5)),
         add(flag_top, (13 + wave, 20)),
         add(flag_top, (5, 17)),
         add(flag_top, (-1, 19))],
        RED,
    )
    line(s, add(flag_top, (3, 5)), add(flag_top, (13 + wave, 8)), RED_L)
    s.rect(pt(add(flag_top, (5, 7))), pt(add(flag_top, (10, 13))), GOLD)
    if int(pose["stage"]) in (2, 3, 4):
        draw_arc(s, add(hand, mul(d, 10)), -30, 60, 26, GOLD_L)


def draw_weapon_layer(s: Sprite, pose: dict, weapon: dict) -> None:
    kind = weapon["kind"]
    if kind == "dao":
        draw_weapon_dao(s, pose)
    elif kind == "jian":
        draw_weapon_jian(s, pose)
    elif kind == "qiang":
        draw_weapon_qiang(s, pose)
    elif kind == "ji":
        draw_weapon_ji(s, pose)
    elif kind == "fu":
        draw_weapon_fu(s, pose)
    elif kind == "yue":
        draw_weapon_yue(s, pose)
    elif kind == "gou":
        draw_weapon_gou(s, pose)
    elif kind == "cha":
        draw_weapon_cha(s, pose)
    elif kind == "gong":
        draw_weapon_gong(s, pose)
    elif kind == "nu":
        draw_weapon_nu(s, pose)
    elif kind == "niaochong":
        draw_weapon_niaochong(s, pose)
    elif kind == "dun":
        draw_weapon_dun(s, pose)
    elif kind == "longdeng":
        draw_weapon_longdeng(s, pose)
    elif kind == "lingqi":
        draw_weapon_lingqi(s, pose)


def draw_offhand_layer(s: Sprite, pose: dict, offhand: dict | None) -> None:
    if not offhand or offhand["kind"] == "none":
        return
    offhand_pose = dict(pose)
    offhand_pose["near_hand"] = pose["far_hand"]
    offhand_pose["weapon_angle"] = pose["offhand_angle"]
    offhand_pose["offhand"] = True
    draw_weapon_layer(s, offhand_pose, offhand)


def render_layer(
    layer: str,
    skin: dict,
    outfit: dict,
    headgear: dict,
    backgear: dict,
    weapon: dict,
    offhand: dict | None,
    pose_id: str,
    frame: int,
) -> Image.Image:
    s = Canvas(CELL, CELL, palette=PAL)
    offhand_id = str(offhand["id"]) if offhand else "none"
    pose = pose_for(frame, pose_id, offhand_id)
    if layer == "body":
        draw_body_layer(s, pose, skin)
    elif layer == "outfit":
        draw_outfit_layer(s, pose, outfit)
    elif layer == "headgear":
        draw_headgear_layer(s, pose, headgear)
    elif layer == "backgear":
        draw_backgear_layer(s, pose, backgear)
    elif layer == "weapon":
        draw_weapon_layer(s, pose, weapon)
    elif layer == "offhand":
        draw_offhand_layer(s, pose, offhand)
    s.outline(OUTLINE, where="outside")
    return s.composite()


def build_row(args: tuple[str, tuple[dict, dict, dict, dict, dict, dict | None, str]]) -> Image.Image:
    kind, row = args
    skin, outfit, headgear, backgear, weapon, offhand, pose_id = row
    image = Image.new("RGBA", (CELL * FRAME_COUNT, CELL), (0, 0, 0, 0))
    for frame in range(FRAME_COUNT):
        frame_image = render_layer(
            kind, skin, outfit, headgear, backgear, weapon, offhand, pose_id, frame
        )
        image.alpha_composite(frame_image, (frame * CELL, 0))
    return image


def build_atlas(
    kind: str,
    rows: list[tuple[dict, dict, dict, dict, dict, dict | None, str]],
) -> Image.Image:
    atlas = Image.new("RGBA", (CELL * FRAME_COUNT, CELL * len(rows)), (0, 0, 0, 0))
    jobs = max(1, min(8, os.cpu_count() or 1, len(rows)))
    tasks = [(kind, row) for row in rows]
    if jobs == 1:
        row_images = [build_row(task) for task in tasks]
    else:
        with ProcessPoolExecutor(max_workers=jobs) as pool:
            row_images = list(pool.map(build_row, tasks))
    for row, image in enumerate(row_images):
        atlas.alpha_composite(image, (0, row * CELL))
    return atlas


def variant_actor(variant: str) -> tuple[dict, dict | None, str]:
    if variant in COMBO_REPRESENTATIVES:
        main_id, offhand_id = COMBO_REPRESENTATIVES[variant]
        return WEAPON_BY_ID[main_id], WEAPON_BY_ID[offhand_id], main_id
    return WEAPON_BY_ID[variant], None, variant


def body_rows() -> list[tuple[dict, dict, dict, dict, dict, dict | None, str]]:
    rows = []
    for skin in SKINS:
        for variant in POSE_VARIANTS:
            weapon, offhand, pose_id = variant_actor(variant)
            rows.append((skin, OUTFITS[0], HEADGEAR[0], BACKGEAR[0], weapon, offhand, pose_id))
    return rows


def outfit_rows() -> list[tuple[dict, dict, dict, dict, dict, dict | None, str]]:
    rows = []
    for outfit in OUTFITS:
        for variant in POSE_VARIANTS:
            weapon, offhand, pose_id = variant_actor(variant)
            rows.append((SKINS[0], outfit, HEADGEAR[0], BACKGEAR[0], weapon, offhand, pose_id))
    return rows


def headgear_rows() -> list[tuple[dict, dict, dict, dict, dict, dict | None, str]]:
    rows = []
    for item in HEADGEAR:
        for pose_id in POSE_SETS:
            weapon = WEAPON_BY_ID[pose_id]
            rows.append((SKINS[0], OUTFITS[0], item, BACKGEAR[0], weapon, None, pose_id))
    return rows


def backgear_rows() -> list[tuple[dict, dict, dict, dict, dict, dict | None, str]]:
    rows = []
    for item in BACKGEAR:
        for pose_id in POSE_SETS:
            weapon = WEAPON_BY_ID[pose_id]
            rows.append((SKINS[0], OUTFITS[0], HEADGEAR[0], item, weapon, None, pose_id))
    return rows


def weapon_rows() -> list[tuple[dict, dict, dict, dict, dict, dict | None, str]]:
    rows = []
    for item in WEAPONS:
        rows.append((SKINS[0], OUTFITS[0], HEADGEAR[0], BACKGEAR[0], item, None, item["id"]))
    for main_id, offhand_id in combo_pairs():
        rows.append((
            SKINS[0], OUTFITS[0], HEADGEAR[0], BACKGEAR[0],
            WEAPON_BY_ID[main_id], WEAPON_BY_ID[offhand_id], main_id,
        ))
    return rows


def offhand_rows() -> list[tuple[dict, dict, dict, dict, dict, dict | None, str]]:
    rows = []
    allowed = [WEAPON_BY_ID[item_id] for item_id in OFFHAND_ALLOWED_IDS]
    for main in MAIN_WEAPONS:
        if main["grip"] != "one_hand":
            continue
        for offhand in allowed:
            rows.append((SKINS[0], OUTFITS[0], HEADGEAR[0], BACKGEAR[0], main, offhand, main["id"]))
    return rows


def row_maps() -> dict:
    body = {}
    for index, skin in enumerate(SKINS):
        for pose_index, variant in enumerate(POSE_VARIANTS):
            body[f"{skin['id']}|{variant}"] = index * len(POSE_VARIANTS) + pose_index
    outfits = {}
    for index, outfit in enumerate(OUTFITS):
        for pose_index, variant in enumerate(POSE_VARIANTS):
            outfits[f"{outfit['id']}|{variant}"] = index * len(POSE_VARIANTS) + pose_index
    headgear = {}
    for index, item in enumerate(HEADGEAR):
        for pose_index, pose_id in enumerate(POSE_SETS):
            headgear[f"{item['id']}|{pose_id}"] = index * len(POSE_SETS) + pose_index
    backgear = {}
    for index, item in enumerate(BACKGEAR):
        for pose_index, pose_id in enumerate(POSE_SETS):
            backgear[f"{item['id']}|{pose_id}"] = index * len(POSE_SETS) + pose_index
    offhands = {}
    row = 0
    for main_id, offhand_id in combo_pairs():
        offhands[f"{main_id}|{offhand_id}"] = row
        row += 1
    weapons = {item["id"]: i for i, item in enumerate(WEAPONS)}
    row = len(WEAPONS)
    for main_id, offhand_id in combo_pairs():
        weapons[f"{main_id}+{offhand_id}"] = row
        row += 1
    return {
        "body": body,
        "outfits": outfits,
        "headgear": headgear,
        "backgear": backgear,
        "weapons": weapons,
        "offhands": offhands,
    }


def make_recipe(
    seed: int,
    faction: str | None = None,
) -> dict:
    rng = random.Random(seed)
    skins = SKINS
    outfits = OUTFITS
    headgear = HEADGEAR
    backgear = BACKGEAR
    weapons = MAIN_WEAPONS
    if faction:
        outfits = [item for item in outfits if faction in item.get("tags", [])] or OUTFITS
        headgear = [item for item in headgear if faction in item.get("tags", []) or "neutral" in item.get("tags", [])] or HEADGEAR
        backgear = [item for item in backgear if faction in item.get("tags", []) or "neutral" in item.get("tags", [])] or BACKGEAR
    weapon = rng.choice(weapons)
    offhand = "none"
    if weapon["grip"] == "one_hand" and rng.random() < 0.62:
        offhand = rng.choice([WEAPON_BY_ID[item_id] for item_id in OFFHAND_ALLOWED_IDS])["id"]
    return {
        "skin": rng.choice(skins)["id"],
        "outfit": rng.choice(outfits)["id"],
        "headgear": rng.choice(headgear)["id"],
        "backgear": rng.choice(backgear)["id"],
        "weapon": weapon["id"],
        "offhand": offhand,
    }


def item_by_id(items: list[dict], item_id: str) -> dict:
    for item in items:
        if item["id"] == item_id:
            return item
    return items[0]


def can_equip_offhand(main: dict, offhand: dict | None) -> bool:
    return (
        offhand is not None
        and main["grip"] == "one_hand"
        and offhand["id"] in OFFHAND_ALLOWED_IDS
    )


def resolve_recipe(recipe: dict) -> tuple[dict, dict, dict, dict, dict, dict | None, str]:
    skin = item_by_id(SKINS, str(recipe["skin"]))
    outfit = item_by_id(OUTFITS, str(recipe["outfit"]))
    headgear = item_by_id(HEADGEAR, str(recipe["headgear"]))
    backgear = item_by_id(BACKGEAR, str(recipe["backgear"]))
    weapon = item_by_id(MAIN_WEAPONS, str(recipe["weapon"]))
    offhand_id = str(recipe.get("offhand", "none"))
    offhand = None if offhand_id == "none" else item_by_id(OFFHAND_WEAPONS, offhand_id)
    if not can_equip_offhand(weapon, offhand):
        offhand = None
    return skin, outfit, headgear, backgear, weapon, offhand, str(weapon["grip"])


def compose_recipe_frame(
    recipe: dict,
    frame: int,
    atlases: dict[str, Image.Image] | None = None,
) -> Image.Image:
    skin, outfit, headgear, backgear, weapon, offhand, _grip = resolve_recipe(recipe)
    if atlases is None:
        atlases = load_preview_atlases()
    maps = row_maps()
    pose_id = weapon["id"]
    offhand_id = str(offhand["id"]) if offhand else "none"
    variant = pose_variant(pose_id, offhand_id)
    body_row = maps["body"][f"{skin['id']}|{variant}"]
    outfit_row = maps["outfits"][f"{outfit['id']}|{variant}"]
    head_row = maps["headgear"][f"{headgear['id']}|{pose_id}"]
    back_row = maps["backgear"][f"{backgear['id']}|{pose_id}"]
    weapon_key = weapon["id"] if offhand is None else f"{pose_id}+{offhand['id']}"
    weapon_row = maps["weapons"][weapon_key]
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    layers = [
        ("backgear", back_row),
        ("body", body_row),
        ("outfit", outfit_row),
        ("headgear", head_row),
    ]
    if offhand is not None:
        layers.append(("offhand", maps["offhands"][f"{pose_id}|{offhand['id']}"]))
    layers.append(("weapon", weapon_row))
    for key, row in layers:
        crop = atlases[key].crop(
            (frame * CELL, row * CELL, (frame + 1) * CELL, (row + 1) * CELL)
        )
        canvas.alpha_composite(crop)
    return canvas


def save_atlas(name: str, atlas: Image.Image, target: Path) -> None:
    target.mkdir(parents=True, exist_ok=True)
    path = target / name
    atlas.save(path, optimize=True)
    print(f"saved {path.relative_to(ROOT)} {atlas.width}x{atlas.height}")


def preview_atlases(
    body: Image.Image,
    outfits: Image.Image,
    headgear: Image.Image,
    backgear: Image.Image,
    weapons: Image.Image,
    offhands: Image.Image,
) -> dict[str, Image.Image]:
    return {
        "body": body,
        "outfit": outfits,
        "headgear": headgear,
        "backgear": backgear,
        "weapon": weapons,
        "offhand": offhands,
    }


def load_preview_atlases() -> dict[str, Image.Image]:
    out = Path(__file__).resolve().parent
    return {
        "body": Image.open(out / "body_base.png").convert("RGBA"),
        "outfit": Image.open(out / "outfits.png").convert("RGBA"),
        "headgear": Image.open(out / "headgear.png").convert("RGBA"),
        "backgear": Image.open(out / "backgear.png").convert("RGBA"),
        "weapon": Image.open(out / "weapons.png").convert("RGBA"),
        "offhand": Image.open(out / "offhands.png").convert("RGBA"),
    }


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    path = ROOT / "game" / "assets" / "fonts" / "LXGWWenKai-Regular.ttf"
    if path.exists():
        return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def _label(draw: ImageDraw.ImageDraw, text: str, xy: tuple[int, int], size: int = 14) -> None:
    draw.text(xy, text, fill=(226, 218, 201), font=font(size))


def random_combo_sheet(atlases: dict[str, Image.Image]) -> Image.Image:
    count = 24
    cols = 4
    rows = (count + cols - 1) // cols
    cell = CELL * 2
    gap = 10
    label_h = 34
    sheet = Image.new(
        "RGB",
        (cols * (cell + gap) + gap, rows * (cell + label_h + gap) + gap),
        (18, 23, 26),
    )
    draw = ImageDraw.Draw(sheet)
    frames = (15, 21, 27, 33, 39, 9, 45, 3)
    for index in range(count):
        recipe = make_recipe(7000 + index * 13)
        frame = frames[index % len(frames)]
        image = compose_recipe_frame(recipe, frame, atlases)
        image = image.resize((cell, cell), Image.Resampling.NEAREST)
        col = index % cols
        row = index // cols
        x = gap + col * (cell + gap)
        y = gap + row * (cell + label_h + gap)
        sheet.paste(image, (x, y), image)
        _label(
            draw,
            f"{recipe['weapon']}+{recipe.get('offhand', 'none')} · {recipe['outfit']} · f{frame:02d}",
            (x + 2, y + cell + 3),
            13,
        )
    return sheet


def dual_combo_sheet(atlases: dict[str, Image.Image]) -> Image.Image:
    pairs = combo_pairs()
    frames = [CLIPS[f"attack_{action}"]["start"] + 3 for action in ATTACK_ACTIONS]
    cols = len(frames)
    rows = len(pairs)
    cell = CELL * 2
    gap = 10
    label_h = 28
    sheet = Image.new(
        "RGB",
        (cols * (cell + gap) + gap, rows * (cell + label_h + gap) + gap),
        (18, 23, 26),
    )
    draw = ImageDraw.Draw(sheet)
    for row, (main, offhand) in enumerate(pairs):
        for col, frame in enumerate(frames):
            recipe = {
                "skin": "tan" if row % 2 else "light",
                "outfit": OUTFITS[row % len(OUTFITS)]["id"],
                "headgear": "ming_helmet_red" if row % 3 else "none",
                "backgear": "ming_cape_red" if row % 4 == 0 else "none",
                "weapon": main,
                "offhand": offhand,
            }
            image = compose_recipe_frame(recipe, frame, atlases)
            image = image.resize((cell, cell), Image.Resampling.NEAREST)
            x = gap + col * (cell + gap)
            y = gap + row * (cell + label_h + gap)
            sheet.paste(image, (x, y), image)
        _label(
            draw,
            f"{main} + {offhand} · combo/{combo_family(main, offhand)} · attacks 1-5",
            (gap + 2, gap + row * (cell + label_h + gap) + cell + 2),
            13,
        )
    return sheet


def joint_contact_sheet(body: Image.Image) -> Image.Image:
    frames = (0, 7, 15, 21, 27, 33, 39, 45)
    crops = (
        ("shoulders / elbows", (32, 24, 96, 88)),
        ("torso / hip roots", (36, 40, 100, 104)),
        ("hips / knees", (40, 56, 104, 120)),
        ("ankles / feet", (36, 80, 100, 127)),
    )
    scale = 5
    gap = 8
    label_h = 24
    cell = 64 * scale
    sheet = Image.new(
        "RGB",
        (len(crops) * (cell + gap) + gap, len(frames) * (cell + label_h + gap) + gap),
        (18, 23, 26),
    )
    draw = ImageDraw.Draw(sheet)
    row_index = row_maps()["body"]["tan|dao"]
    for row, frame in enumerate(frames):
        for col, (name, box) in enumerate(crops):
            crop = body.crop(
                (frame * CELL + box[0], row_index * CELL + box[1],
                 frame * CELL + box[2], row_index * CELL + box[3])
            )
            padded = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            padded.alpha_composite(crop, ((64 - crop.width) // 2, (64 - crop.height) // 2))
            image = padded.resize((cell, cell), Image.Resampling.NEAREST)
            x = gap + col * (cell + gap)
            y = gap + row * (cell + label_h + gap)
            sheet.paste(image, (x, y), image)
            _label(draw, f"f{frame:02d} · {name}", (x + 2, y + cell + 3), 13)
    return sheet


def weapon_action_sheet(atlases: dict[str, Image.Image]) -> Image.Image:
    cols = len(ATTACK_ACTIONS)
    showcase = MAIN_WEAPONS + [WEAPON_BY_ID["dun"]]
    rows = len(showcase)
    cell = CELL * 2
    gap = 8
    label_h = 28
    sheet = Image.new(
        "RGB",
        (cols * (cell + gap) + gap, rows * (cell + label_h + gap) + gap),
        (18, 23, 26),
    )
    draw = ImageDraw.Draw(sheet)
    frames = [CLIPS[f"attack_{action}"]["start"] + 3 for action in ATTACK_ACTIONS]
    for row, weapon in enumerate(showcase):
        for col, frame in enumerate(frames):
            outfit = OUTFITS[0] if row % 2 == 0 else OUTFITS[1]
            recipe = {
                "skin": "tan",
                "outfit": outfit["id"],
                "headgear": "none",
                "backgear": "none",
                "weapon": "dao" if weapon["slot"] == "offhand" else weapon["id"],
                "offhand": "dun" if weapon["slot"] == "offhand" else "none",
            }
            image = compose_recipe_frame(recipe, frame, atlases)
            image = image.resize((cell, cell), Image.Resampling.NEAREST)
            x = gap + col * (cell + gap)
            y = gap + row * (cell + label_h + gap)
            sheet.paste(image, (x, y), image)
        _label(
            draw,
            f"{weapon['name_zh']} / {weapon['name_en']} · {weapon['grip']}",
            (gap + 2, gap + row * (cell + label_h + gap) + cell + 2),
            13,
        )
    return sheet


def body_pose_sheet(body: Image.Image) -> Image.Image:
    cols = 8
    rows = FRAME_COUNT // cols
    cell = CELL * 2
    gap = 8
    sheet = Image.new(
        "RGB",
        (cols * (cell + gap) + gap, rows * (cell + gap) + gap),
        (18, 23, 26),
    )
    draw = ImageDraw.Draw(sheet)
    row_index = row_maps()["body"]["tan|dao"]
    for frame in range(FRAME_COUNT):
        col = frame % cols
        row = frame // cols
        crop = body.crop(
            (frame * CELL, row_index * CELL, (frame + 1) * CELL, (row_index + 1) * CELL)
        ).resize((cell, cell), Image.Resampling.NEAREST)
        x = gap + col * (cell + gap)
        y = gap + row * (cell + gap)
        sheet.paste(crop, (x, y), crop)
        _label(draw, f"{frame:02d}", (x + 3, y + 3), 13)
    return sheet


def naked_pose_sheet(body: Image.Image) -> Image.Image:
    frames = (0, 7, 15, 21, 27, 33, 39, 45)
    cols = len(frames)
    rows = len(POSE_VARIANTS)
    cell = CELL * 2
    gap = 8
    label_h = 24
    sheet = Image.new(
        "RGB",
        (cols * (cell + gap) + gap, rows * (cell + label_h + gap) + gap),
        (18, 23, 26),
    )
    draw = ImageDraw.Draw(sheet)
    maps = row_maps()["body"]
    for row, variant in enumerate(POSE_VARIANTS):
        row_index = maps[f"tan|{variant}"]
        for col, frame in enumerate(frames):
            crop = body.crop(
                (frame * CELL, row_index * CELL,
                 (frame + 1) * CELL, (row_index + 1) * CELL)
            ).resize((cell, cell), Image.Resampling.NEAREST)
            x = gap + col * (cell + gap)
            y = gap + row * (cell + label_h + gap)
            sheet.paste(crop, (x, y), crop)
        _label(draw, variant, (gap + 2, gap + row * (cell + label_h + gap) + cell + 2), 13)
    return sheet


def layer_breakdown(atlases: dict[str, Image.Image]) -> Image.Image:
    recipe = {
        "skin": "tan",
        "outfit": "ming_lamellar_red",
        "headgear": "ming_helmet_red",
        "backgear": "ming_cape_red",
        "weapon": "dao",
        "offhand": "dun",
    }
    skin, outfit, headgear, backgear, weapon, _offhand, _grip = resolve_recipe(recipe)
    maps = row_maps()
    frame = 15
    names = ("backgear", "body", "outfit", "headgear", "offhand", "weapon")
    pose_id = weapon["id"]
    variant = pose_variant(pose_id, "dun")
    row_ids = {
        "backgear": maps["backgear"][f"{backgear['id']}|{pose_id}"],
        "body": maps["body"][f"{skin['id']}|{variant}"],
        "outfit": maps["outfits"][f"{outfit['id']}|{variant}"],
        "headgear": maps["headgear"][f"{headgear['id']}|{pose_id}"],
        "offhand": maps["offhands"][f"{pose_id}|dun"],
        "weapon": maps["weapons"][f"{pose_id}+dun"],
    }
    cell = CELL * 2
    gap = 10
    label_h = 24
    sheet = Image.new("RGB", (7 * (cell + gap) + gap, cell + label_h + 2 * gap), (18, 23, 26))
    draw = ImageDraw.Draw(sheet)
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    for index, name in enumerate(names + ("composite",)):
        if name != "composite":
            crop = atlases[name].crop(
                (frame * CELL, row_ids[name] * CELL, (frame + 1) * CELL, (row_ids[name] + 1) * CELL)
            )
            canvas.alpha_composite(crop)
            image = crop
        else:
            image = canvas
        image = image.resize((cell, cell), Image.Resampling.NEAREST)
        x = gap + index * (cell + gap)
        y = gap
        sheet.paste(image, (x, y), image)
        _label(draw, name, (x + 2, y + cell + 3), 13)
    return sheet


def save_gif(atlases: dict[str, Image.Image], path: Path) -> None:
    recipe = {
        "skin": "tan",
        "outfit": "ming_lamellar_red",
        "headgear": "ming_helmet_red",
        "backgear": "ming_cape_red",
        "weapon": "dao",
        "offhand": "dun",
    }
    bg = Image.new("RGB", (CELL * 2, CELL * 2), (14, 20, 24))
    frames = []
    for frame in range(FRAME_COUNT):
        image = compose_recipe_frame(recipe, frame, atlases)
        image = image.resize((CELL * 2, CELL * 2), Image.Resampling.NEAREST)
        merged = bg.copy()
        merged.paste(image, (0, 0), image)
        frames.append(merged)
    durations = [int(1000 / CLIPS[clip]["fps"]) for clip in CLIPS for _ in range(CLIPS[clip]["count"])]
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        disposal=2,
    )


def data_document() -> dict:
    maps = row_maps()
    loadouts = sum(
        1 + (len(OFFHAND_ALLOWED_IDS) if item["grip"] == "one_hand" else 0)
        for item in MAIN_WEAPONS
    )
    combinations = len(SKINS) * len(OUTFITS) * len(HEADGEAR) * len(BACKGEAR) * loadouts
    return {
        "version": 3,
        "license": "CC BY 4.0",
        "author": "xingwangzhe",
        "source": "pixel-art/character_forge/build.py",
        "cell": CELL,
        "frame_count": FRAME_COUNT,
        "columns": FRAME_COUNT,
        "attack_action_count": len(ATTACK_ACTIONS),
        "clips": CLIPS,
        "grips": list(GRIPS),
        "arm_layer_rules": ARM_LAYER_RULES,
        "arm_layer_policy": ARM_LAYER_POLICY,
        "pose_variants": list(POSE_VARIANTS),
        "combo_families": list(COMBO_FAMILIES),
        "combo_actions": {
            family: [
                {"id": f"attack_{index}", "name_zh": name_zh, "name_en": name_en}
                for index, (name_zh, name_en) in enumerate(names, start=1)
            ]
            for family, names in COMBO_ACTION_NAMES.items()
        },
        "combo_pairs": {
            f"{main_id}+{offhand_id}": combo_family(main_id, offhand_id)
            for main_id, offhand_id in combo_pairs()
        },
        "layer_order": ["backgear", "body", "outfit", "headgear", "offhand", "weapon"],
        "combination_count": combinations,
        "loadout_count": loadouts,
        "skins": [
            {"id": item["id"], "name_zh": item["name_zh"], "name_en": item["name_en"]}
            for item in SKINS
        ],
        "outfits": [
            {"id": item["id"], "name_zh": item["name_zh"], "name_en": item["name_en"],
             "tags": item["tags"]}
            for item in OUTFITS
        ],
        "headgear": [
            {"id": item["id"], "name_zh": item["name_zh"], "name_en": item["name_en"],
             "tags": item["tags"]}
            for item in HEADGEAR
        ],
        "backgear": [
            {"id": item["id"], "name_zh": item["name_zh"], "name_en": item["name_en"],
             "tags": item["tags"]}
            for item in BACKGEAR
        ],
        "weapons": [
            {"id": item["id"], "name_zh": item["name_zh"], "name_en": item["name_en"],
             "grip": item["grip"], "slot": item["slot"],
             "arm_layer": ARM_LAYER_RULES[item["grip"]],
             "actions": [
                 {
                     "id": f"attack_{action}",
                     "name_zh": ACTION_NAMES[item["id"]][action - 1][0],
                     "name_en": ACTION_NAMES[item["id"]][action - 1][1],
                 }
                 for action in ATTACK_ACTIONS
             ],
             "attack_profile": item["attack_profile"], "offhand": item["offhand"],
             "required": item["id"] in REQUIRED_WEAPONS}
            for item in WEAPONS
        ],
        "offhand_allowed": list(OFFHAND_ALLOWED_IDS),
        "atlases": {
            "body": {"path": "res://assets/character_forge/body_base.png", "rows": maps["body"]},
            "outfit": {"path": "res://assets/character_forge/outfits.png", "rows": maps["outfits"]},
            "headgear": {"path": "res://assets/character_forge/headgear.png", "rows": maps["headgear"]},
            "backgear": {"path": "res://assets/character_forge/backgear.png", "rows": maps["backgear"]},
            "weapon": {"path": "res://assets/character_forge/weapons.png", "rows": maps["weapons"]},
            "offhand": {"path": "res://assets/character_forge/offhands.png", "rows": maps["offhands"]},
        },
        "recipes": {
            "hero": {
                "skin": "tan", "outfit": "ming_lamellar_red",
                "headgear": "ming_helmet_red", "backgear": "ming_cape_red",
                "weapon": "dao", "offhand": "dun",
            },
            "ming_guard": {
                "skin": "light", "outfit": "ming_guard_iron",
                "headgear": "ming_helmet_iron", "backgear": "ming_banner",
                "weapon": "qiang", "offhand": "none",
            },
            "wokou_raider": {
                "skin": "deep", "outfit": "wokou_ragged_brown",
                "headgear": "wokou_headband", "backgear": "none",
                "weapon": "dao", "offhand": "none",
            },
            "wokou_gunner": {
                "skin": "tan", "outfit": "wokou_dark_navy",
                "headgear": "wokou_kasa", "backgear": "none",
                "weapon": "niaochong", "offhand": "none",
            },
            "wokou_general": {
                "skin": "deep", "outfit": "general_purple",
                "headgear": "wokou_helmet", "backgear": "wokou_cloak_dark",
                "weapon": "ji", "offhand": "none",
            },
            "oni_duelist": {
                "skin": "deep", "outfit": "oni_red",
                "headgear": "oni_mask", "backgear": "none",
                "weapon": "gou", "offhand": "gou",
            },
        },
    }


def write_data(target: Path) -> None:
    target.mkdir(parents=True, exist_ok=True)
    path = target / "character_templates.json"
    path.write_text(
        json.dumps(data_document(), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"saved {path.relative_to(ROOT)}")


def check_edge_clipping(name: str, image: Image.Image) -> None:
    alpha = image.getchannel("A")
    width, height = image.size
    edges = [
        alpha.crop((0, 0, width, 1)),
        alpha.crop((0, height - 1, width, height)),
        alpha.crop((0, 0, 1, height)),
        alpha.crop((width - 1, 0, width, height)),
    ]
    for index, edge in enumerate(edges):
        if edge.getbbox() is not None:
            print(f"warning: {name} touches edge {index}")


def image_stats(name: str, image: Image.Image) -> None:
    colors = image.getcolors(maxcolors=1_000_000) or []
    alpha = image.getchannel("A")
    print(
        f"{name}: {image.width}x{image.height}, colors={len(colors)}, "
        f"bbox={alpha.getbbox()}"
    )


def main() -> None:
    validate_pose_reach()
    validate_arm_layering()
    out = Path(__file__).resolve().parent
    runtime = ROOT / "game" / "assets" / "character_forge"
    data_dir = ROOT / "game" / "data"
    out.mkdir(parents=True, exist_ok=True)

    if "--previews-only" in sys.argv:
        atlases = load_preview_atlases()
        body = atlases["body"]
        body_pose_sheet(body).save(out / "body_pose_sheet.png")
        naked_pose_sheet(body).save(out / "naked_pose_sheet.png")
        joint_contact_sheet(body).save(out / "joint_contact_sheet.png")
        layer_breakdown(atlases).save(out / "layer_breakdown.png")
        random_combo_sheet(atlases).save(out / "random_combo_sheet.png")
        dual_combo_sheet(atlases).save(out / "dual_combo_sheet.png")
        weapon_action_sheet(atlases).save(out / "weapon_action_sheet.png")
        save_gif(atlases, out / "hero_forge_demo.gif")
        write_data(data_dir)
        print("previews and data refreshed from saved atlases")
        return

    body = build_atlas("body", body_rows())
    outfits = build_atlas("outfit", outfit_rows())
    headgear = build_atlas("headgear", headgear_rows())
    backgear = build_atlas("backgear", backgear_rows())
    weapons = build_atlas("weapon", weapon_rows())
    offhands = build_atlas("offhand", offhand_rows())

    save_atlas("body_base.png", body, out)
    save_atlas("outfits.png", outfits, out)
    save_atlas("headgear.png", headgear, out)
    save_atlas("backgear.png", backgear, out)
    save_atlas("weapons.png", weapons, out)
    save_atlas("offhands.png", offhands, out)
    save_atlas("body_base.png", body, runtime)
    save_atlas("outfits.png", outfits, runtime)
    save_atlas("headgear.png", headgear, runtime)
    save_atlas("backgear.png", backgear, runtime)
    save_atlas("weapons.png", weapons, runtime)
    save_atlas("offhands.png", offhands, runtime)

    atlases = preview_atlases(body, outfits, headgear, backgear, weapons, offhands)
    body_pose_sheet(body).save(out / "body_pose_sheet.png")
    naked_pose_sheet(body).save(out / "naked_pose_sheet.png")
    joint_contact_sheet(body).save(out / "joint_contact_sheet.png")
    layer_breakdown(atlases).save(out / "layer_breakdown.png")
    random_combo_sheet(atlases).save(out / "random_combo_sheet.png")
    dual_combo_sheet(atlases).save(out / "dual_combo_sheet.png")
    weapon_action_sheet(atlases).save(out / "weapon_action_sheet.png")
    save_gif(atlases, out / "hero_forge_demo.gif")
    write_data(data_dir)

    for name, image in (
        ("body", body), ("outfits", outfits), ("headgear", headgear),
        ("backgear", backgear), ("weapons", weapons), ("offhands", offhands),
    ):
        image_stats(name, image)
        check_edge_clipping(name, image)
    count = data_document()["combination_count"]
    print(f"combinations: {count}")
    print(f"required weapons: {', '.join(REQUIRED_WEAPONS)}")


if __name__ == "__main__":
    main()






