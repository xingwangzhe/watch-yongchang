#!/usr/bin/env python3
"""Cavalry recipes shared by CharacterForge data and the mounted-sprite baker.

The module deliberately contains data only. It can therefore be imported by
``build.py`` without creating a dependency on the renderer or its atlases.
"""

from __future__ import annotations

from copy import deepcopy


CELL = 128
IDLE_FRAMES = 4
WALK_FRAMES = 8
IDLE_FPS = 6
WALK_FPS = 10
OUTPUT_ROOT = "res://assets/units/forge/cavalry"

MOUNTS = [
    {
        "id": "zhaohong",
        "name_zh": "枣红马",
        "name_en": "Chestnut Bay",
        "kind": "mount",
        "faction": "neutral",
        "allowed_factions": ["ming", "wokou", "neutral"],
        "tags": ["horse", "bay", "warmblood", "cavalry"],
        "idle_frames": IDLE_FRAMES,
        "walk_frames": WALK_FRAMES,
        "gait": "diagonal_trot",
        "model_art_source": "pixel-art/model_redraw/horse_gaits_v5_source.png",
        "model_art_row": 0,
        "anchor": {"x": 64, "y": 122},
        "palette": {
            "coat_dark": "#451c16",
            "coat": "#793522",
            "coat_mid": "#9b4b2e",
            "coat_light": "#c47446",
            "coat_hi": "#e2a06a",
            "mane": "#261611",
            "mane_light": "#593325",
            "muzzle": "#d1a077",
            "sock": "#d8c6a5",
            "hoof": "#211917",
            "hoof_light": "#51443a",
            "eye": "#111314",
        },
    },
    {
        "id": "black",
        "name_zh": "乌骓马",
        "name_en": "Black Warhorse",
        "kind": "mount",
        "faction": "neutral",
        "allowed_factions": ["ming", "wokou", "neutral"],
        "tags": ["horse", "black", "charger", "cavalry"],
        "idle_frames": IDLE_FRAMES,
        "walk_frames": WALK_FRAMES,
        "gait": "diagonal_trot",
        "model_art_source": "pixel-art/model_redraw/horse_gaits_v5_source.png",
        "model_art_row": 1,
        "anchor": {"x": 64, "y": 122},
        "palette": {
            "coat_dark": "#111319",
            "coat": "#222630",
            "coat_mid": "#343a47",
            "coat_light": "#525b6d",
            "coat_hi": "#798395",
            "mane": "#0b0d11",
            "mane_light": "#303540",
            "muzzle": "#6f665b",
            "sock": "#4e5664",
            "hoof": "#171615",
            "hoof_light": "#47433e",
            "eye": "#d8c7a4",
        },
    },
    {
        "id": "grey",
        "name_zh": "霜灰马",
        "name_en": "Frost Grey",
        "kind": "mount",
        "faction": "neutral",
        "allowed_factions": ["ming", "wokou", "neutral"],
        "tags": ["horse", "grey", "courser", "cavalry"],
        "idle_frames": IDLE_FRAMES,
        "walk_frames": WALK_FRAMES,
        "gait": "diagonal_trot",
        "model_art_source": "pixel-art/model_redraw/horse_gaits_v5_source.png",
        "model_art_row": 2,
        "anchor": {"x": 64, "y": 122},
        "palette": {
            "coat_dark": "#4d4f4d",
            "coat": "#70716b",
            "coat_mid": "#929287",
            "coat_light": "#bbb9a9",
            "coat_hi": "#e1deca",
            "mane": "#595a56",
            "mane_light": "#9c9a8d",
            "muzzle": "#c3b9a6",
            "sock": "#e1deca",
            "hoof": "#272522",
            "hoof_light": "#5b554d",
            "eye": "#111314",
        },
    },
]

ACTIONS = [
    {
        "id": "lance_charge",
        "name_zh": "骑枪近战",
        "name_en": "Couched Lance",
        "kind": "cavalry_action",
        "range": "melee",
        "weapon": "qiang",
        "offhand": "none",
        "grip": "mounted_couched",
        "weapon_layer": "mounted_lance",
        "arm_layer": "both_front",
        "facing": "right",
        "tags": ["cavalry", "melee", "anti_cavalry"],
    },
    {
        "id": "mounted_bow",
        "name_zh": "骑弓远程",
        "name_en": "Mounted Archery",
        "kind": "cavalry_action",
        "range": "ranged",
        "weapon": "gong",
        "offhand": "none",
        "grip": "mounted_bow",
        "weapon_layer": "gong",
        "arm_layer": "both_front",
        "facing": "right",
        "tags": ["cavalry", "ranged", "skirmisher"],
    },
    {
        "id": "saber_cut",
        "name_zh": "骑刀近战",
        "name_en": "Mounted Saber",
        "kind": "cavalry_action",
        "range": "melee",
        "weapon": "dao",
        "offhand": "none",
        "grip": "mounted_one_hand",
        "weapon_layer": "dao",
        "arm_layer": "both_front",
        "facing": "right",
        "tags": ["cavalry", "melee", "pursuit"],
    },
]

MOUNT_VARIANTS = [
    {
        "id": "mount_zhaohong",
        "kind": "mount",
        "mount": "zhaohong",
        "gait": "diagonal_trot",
        "facing": "right",
        "anchor": {"x": 64, "y": 122},
        "battle_cell": CELL,
        "battle_idle": f"{OUTPUT_ROOT}/mount_zhaohong/idle.png",
        "battle_walk": f"{OUTPUT_ROOT}/mount_zhaohong/walk.png",
        "battle_idle_frames": IDLE_FRAMES,
        "battle_walk_frames": WALK_FRAMES,
    },
    {
        "id": "mount_black",
        "kind": "mount",
        "mount": "black",
        "gait": "diagonal_trot",
        "facing": "right",
        "anchor": {"x": 64, "y": 122},
        "battle_cell": CELL,
        "battle_idle": f"{OUTPUT_ROOT}/mount_black/idle.png",
        "battle_walk": f"{OUTPUT_ROOT}/mount_black/walk.png",
        "battle_idle_frames": IDLE_FRAMES,
        "battle_walk_frames": WALK_FRAMES,
    },
    {
        "id": "mount_grey",
        "kind": "mount",
        "mount": "grey",
        "gait": "diagonal_trot",
        "facing": "right",
        "anchor": {"x": 64, "y": 122},
        "battle_cell": CELL,
        "battle_idle": f"{OUTPUT_ROOT}/mount_grey/idle.png",
        "battle_walk": f"{OUTPUT_ROOT}/mount_grey/walk.png",
        "battle_idle_frames": IDLE_FRAMES,
        "battle_walk_frames": WALK_FRAMES,
    },
]

MOUNTED_VARIANTS = [
    {
        "id": "ming_zhaohong_lancer",
        "kind": "cavalry",
        "faction": "ming",
        "mount": "zhaohong",
        "action": "lance_charge",
        "skin": "light",
        "outfit": "ming_lamellar_red",
        "headgear": "ming_helmet_red",
        "backgear": "ming_cape_red",
        "weapon": "qiang",
        "offhand": "none",
        "gait": "diagonal_trot",
        "facing": "right",
        "anchor": {"x": 64, "y": 122},
        "battle_cell": CELL,
        "battle_idle": f"{OUTPUT_ROOT}/ming_zhaohong_lancer/idle.png",
        "battle_walk": f"{OUTPUT_ROOT}/ming_zhaohong_lancer/walk.png",
        "battle_idle_frames": IDLE_FRAMES,
        "battle_walk_frames": WALK_FRAMES,
    },
    {
        "id": "ming_black_bow",
        "kind": "cavalry",
        "faction": "ming",
        "mount": "black",
        "action": "mounted_bow",
        "skin": "tan",
        "outfit": "ming_navy_green",
        "headgear": "ming_scout_cap",
        "backgear": "ming_quiver",
        "weapon": "gong",
        "offhand": "none",
        "gait": "diagonal_trot",
        "facing": "right",
        "anchor": {"x": 64, "y": 122},
        "battle_cell": CELL,
        "battle_idle": f"{OUTPUT_ROOT}/ming_black_bow/idle.png",
        "battle_walk": f"{OUTPUT_ROOT}/ming_black_bow/walk.png",
        "battle_idle_frames": IDLE_FRAMES,
        "battle_walk_frames": WALK_FRAMES,
    },
    {
        "id": "wokou_grey_saber",
        "kind": "cavalry",
        "faction": "wokou",
        "mount": "grey",
        "action": "saber_cut",
        "skin": "deep",
        "outfit": "wokou_haramaki",
        "headgear": "wokou_helmet",
        "backgear": "wokou_cloak_dark",
        "weapon": "dao",
        "offhand": "none",
        "gait": "diagonal_trot",
        "facing": "right",
        "anchor": {"x": 64, "y": 122},
        "battle_cell": CELL,
        "battle_idle": f"{OUTPUT_ROOT}/wokou_grey_saber/idle.png",
        "battle_walk": f"{OUTPUT_ROOT}/wokou_grey_saber/walk.png",
        "battle_idle_frames": IDLE_FRAMES,
        "battle_walk_frames": WALK_FRAMES,
    },
    {
        "id": "wokou_black_bow",
        "kind": "cavalry",
        "faction": "wokou",
        "mount": "black",
        "action": "mounted_bow",
        "skin": "tan",
        "outfit": "wokou_haramaki",
        "headgear": "wokou_kasa",
        "backgear": "none",
        "weapon": "gong",
        "offhand": "none",
        "gait": "diagonal_trot",
        "facing": "right",
        "anchor": {"x": 64, "y": 122},
        "battle_cell": CELL,
        "battle_idle": f"{OUTPUT_ROOT}/wokou_black_bow/idle.png",
        "battle_walk": f"{OUTPUT_ROOT}/wokou_black_bow/walk.png",
        "battle_idle_frames": IDLE_FRAMES,
        "battle_walk_frames": WALK_FRAMES,
    },
    {
        "id": "wokou_black_lancer",
        "kind": "cavalry",
        "faction": "wokou",
        "mount": "black",
        "action": "lance_charge",
        "skin": "deep",
        "outfit": "wokou_haramaki",
        "headgear": "wokou_helmet",
        "backgear": "wokou_cloak_dark",
        "weapon": "qiang",
        "offhand": "none",
        "gait": "diagonal_trot",
        "facing": "right",
        "anchor": {"x": 64, "y": 122},
        "battle_cell": CELL,
        "battle_idle": f"{OUTPUT_ROOT}/wokou_black_lancer/idle.png",
        "battle_walk": f"{OUTPUT_ROOT}/wokou_black_lancer/walk.png",
        "battle_idle_frames": IDLE_FRAMES,
        "battle_walk_frames": WALK_FRAMES,
    },
    {
        "id": "wokou_oni_lancer",
        "kind": "cavalry",
        "faction": "wokou",
        "mount": "black",
        "action": "lance_charge",
        "skin": "tan",
        "outfit": "oni_red",
        "headgear": "oni_mask",
        "backgear": "wokou_cloak_dark",
        "weapon": "qiang",
        "offhand": "none",
        "gait": "diagonal_trot",
        "facing": "right",
        "anchor": {"x": 64, "y": 122},
        "battle_cell": CELL,
        "battle_idle": f"{OUTPUT_ROOT}/wokou_oni_lancer/idle.png",
        "battle_walk": f"{OUTPUT_ROOT}/wokou_oni_lancer/walk.png",
        "battle_idle_frames": IDLE_FRAMES,
        "battle_walk_frames": WALK_FRAMES,
    },
]


def mount_by_id(mount_id: str) -> dict | None:
    for mount in MOUNTS:
        if mount["id"] == mount_id:
            return mount
    return None


def action_by_id(action_id: str) -> dict | None:
    for action in ACTIONS:
        if action["id"] == action_id:
            return action
    return None


def validate_cavalry_recipe(recipe: dict) -> None:
    """Validate the mount-specific fields without duplicating gear checks."""
    if recipe.get("kind") != "cavalry" and "mount" not in recipe:
        return
    mount = mount_by_id(str(recipe.get("mount", "")))
    if mount is None:
        raise ValueError(f"unknown cavalry mount: {recipe.get('mount')}")
    faction = str(recipe.get("faction", "neutral"))
    if faction not in mount["allowed_factions"]:
        raise ValueError(f"mount {mount['id']} is not allowed for faction {faction}")
    if recipe.get("kind") == "mount":
        return
    action = action_by_id(str(recipe.get("action", "")))
    if action is None:
        raise ValueError(f"unknown cavalry action: {recipe.get('action')}")
    if str(recipe.get("weapon", "")) != action["weapon"]:
        raise ValueError(
            f"cavalry action {action['id']} requires {action['weapon']}, "
            f"got {recipe.get('weapon')}"
        )
    if str(recipe.get("offhand", "none")) != action["offhand"]:
        raise ValueError(
            f"cavalry action {action['id']} requires offhand {action['offhand']}"
        )


def cavalry_document_fields() -> dict:
    """Return the JSON block merged into game/data/character_templates.json."""
    return {
        "mounts": deepcopy(MOUNTS),
        "cavalry_actions": deepcopy(ACTIONS),
        "mount_recipes": deepcopy(MOUNT_VARIANTS),
        "cavalry_recipes": deepcopy(MOUNTED_VARIANTS),
        "cavalry_gait": {
            "id": "diagonal_trot",
            "name_zh": "斜对角快步",
            "name_en": "Diagonal Trot",
            "description_zh": "近前腿与远后腿同相，近后腿与远前腿反相；鞍桥与骑手滞后一帧起伏。",
            "description_en": "Near fore and far hind move together; near hind and far fore oppose. Saddle and rider bob one frame behind the barrel.",
            "idle_frames": IDLE_FRAMES,
            "walk_frames": WALK_FRAMES,
            "idle_fps": IDLE_FPS,
            "walk_fps": WALK_FPS,
        },
        "cavalry_compatibility": {
            "mount_factions": ["neutral"],
            "rider_factions": ["ming", "wokou", "neutral"],
            "mount_action_pairs": len(MOUNTS) * len(ACTIONS),
            "representative_mounted_assets": [item["id"] for item in MOUNTED_VARIANTS],
            "representative_mount_assets": [item["id"] for item in MOUNT_VARIANTS],
        },
    }
