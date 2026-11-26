#!/usr/bin/env python3
"""Bake faction-valid CharacterForge enemy appearance variants.

Every base enemy receives twelve distinct foot-combat recipes. Cavalry, the
general, and the daimyo also receive twelve mounted recipes so a runtime
loadout can keep its role while changing clothing, headgear, backgear, weapon,
shield, horse, and palette silhouette.

Run from the project root:
    python3 pixel-art/character_forge/bake_enemy_variants.py
"""

from __future__ import annotations

import hashlib
import json
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

import bake_battle_sprites as foot_baker  # noqa: E402
import build as forge  # noqa: E402
import build_cavalry as mounted_baker  # noqa: E402
import cavalry_data as cavalry  # noqa: E402


ENEMY_DATA = ROOT / "game" / "data" / "enemies.json"
TEMPLATE_DATA = ROOT / "game" / "data" / "character_templates.json"
VARIANT_DATA = ROOT / "game" / "data" / "enemy_variants.json"
OUTPUT_ROOT = ROOT / "game" / "assets" / "units" / "forge" / "enemy_variants"
FOOT_SHEET = HERE / "enemy_variants_roster.png"
MOUNTED_SHEET = HERE / "enemy_variants_mounted_roster.png"
DETAIL_SHEET = HERE / "enemy_variants_detail.png"
MANIFEST = HERE / "enemy_variants_manifest.txt"

CELL = forge.CELL
FOOT_FRAMES = len(foot_baker.clip_frames("walk"))
FOOT_FPS = int(forge.CLIPS["walk"]["fps"])
MOUNTED_FRAMES = cavalry.WALK_FRAMES
MOUNTED_FPS = cavalry.WALK_FPS
VARIANTS_PER_ENEMY = 12
MOUNTED_VARIANTS_PER_ENEMY = 12

WOKOU_OUTFITS = [
    "wokou_ragged_brown",
    "wokou_dark_navy",
    "pirate_teal",
    "wokou_domaru",
    "monk_grey",
    "wokou_haramaki",
    "general_purple",
    "oni_red",
    "villager_linen",
    "common_leather_vest",
]
WOKOU_HEADGEAR = [
    "wokou_headband",
    "wokou_kasa",
    "wokou_helmet",
    "monk_hood",
    "pirate_bandana",
    "oni_mask",
    "common_headwrap",
    "none",
]
WOKOU_BACKGEAR = ["none", "wokou_cloak_dark"]
SKINS = ["light", "tan", "deep", "pale"]

LIGHT_MELEE = ["dao", "jian", "gou", "qiang", "wokou_dao", "cha", "ji"]
ARMORED_MELEE = ["dao", "jian", "gou", "qiang", "ji", "fu", "yue", "wokou_dao"]
POLEARMS = ["qiang", "ji", "cha", "yue", "fu"]
RANGED = ["niaochong", "nu", "gong"]
CAVALRY_FOOT = [
    "wokou_dao",
    "qiang",
    "dao",
    "gong",
    "ji",
    "nu",
    "fu",
    "yue",
    "gou",
    "niaochong",
]
COMMAND_FOOT = [
    "ji",
    "qiang",
    "yue",
    "fu",
    "dao",
    "gong",
    "nu",
    "wokou_dao",
    "cha",
    "niaochong",
]
DAIMYO_FOOT = [
    "ji",
    "yue",
    "fu",
    "cha",
    "qiang",
    "wokou_dao",
    "gong",
    "nu",
    "niaochong",
    "dao",
]

ENEMY_POOLS = {
    "scout": {
        "role": "infantry",
        "outfits": [
            "wokou_ragged_brown",
            "wokou_dark_navy",
            "pirate_teal",
            "monk_grey",
            "villager_linen",
            "common_leather_vest",
        ],
        "headgear": [
            "wokou_headband",
            "common_headwrap",
            "pirate_bandana",
            "wokou_kasa",
            "monk_hood",
            "none",
        ],
        "weapons": LIGHT_MELEE,
        "offhand": "sometimes",
    },
    "ronin": {
        "role": "infantry",
        "outfits": [
            "wokou_haramaki",
            "wokou_ragged_brown",
            "wokou_dark_navy",
            "monk_grey",
            "pirate_teal",
            "wokou_domaru",
            "villager_linen",
            "common_leather_vest",
        ],
        "headgear": [
            "wokou_kasa",
            "monk_hood",
            "wokou_headband",
            "common_headwrap",
            "none",
            "pirate_bandana",
        ],
        "weapons": ["wokou_dao", "dao", "jian", "gou", "qiang", "ji"],
        "offhand": "sometimes",
    },
    "shield": {
        "role": "infantry",
        "outfits": [
            "pirate_teal",
            "wokou_haramaki",
            "wokou_domaru",
            "wokou_dark_navy",
            "wokou_ragged_brown",
            "general_purple",
        ],
        "headgear": [
            "wokou_helmet",
            "wokou_kasa",
            "wokou_headband",
            "pirate_bandana",
            "none",
            "monk_hood",
        ],
        "weapons": ["dao", "jian", "gou", "qiang", "ji", "fu"],
        "offhand": "shield_first",
    },
    "gun": {
        "role": "ranged",
        "outfits": [
            "wokou_dark_navy",
            "wokou_ragged_brown",
            "pirate_teal",
            "monk_grey",
            "wokou_haramaki",
            "common_leather_vest",
            "villager_linen",
            "wokou_domaru",
        ],
        "headgear": [
            "wokou_kasa",
            "pirate_bandana",
            "wokou_headband",
            "common_headwrap",
            "none",
            "wokou_helmet",
        ],
        "weapons": RANGED,
        "offhand": "never",
    },
    "archer": {
        "role": "ranged",
        "outfits": [
            "monk_grey",
            "wokou_ragged_brown",
            "wokou_dark_navy",
            "pirate_teal",
            "villager_linen",
            "common_leather_vest",
            "wokou_haramaki",
            "wokou_domaru",
        ],
        "headgear": [
            "pirate_bandana",
            "wokou_kasa",
            "monk_hood",
            "wokou_headband",
            "common_headwrap",
            "none",
        ],
        "weapons": ["gong", "nu", "niaochong"],
        "offhand": "never",
    },
    "banner": {
        "role": "infantry",
        "outfits": [
            "general_purple",
            "wokou_domaru",
            "wokou_haramaki",
            "wokou_ragged_brown",
            "wokou_dark_navy",
            "pirate_teal",
            "oni_red",
        ],
        "headgear": [
            "wokou_helmet",
            "wokou_kasa",
            "wokou_headband",
            "oni_mask",
            "pirate_bandana",
            "none",
        ],
        "weapons": POLEARMS,
        "offhand": "never",
    },
    "cavalry": {
        "role": "mixed",
        "outfits": [
            "wokou_haramaki",
            "wokou_domaru",
            "wokou_dark_navy",
            "wokou_ragged_brown",
            "pirate_teal",
            "general_purple",
            "oni_red",
        ],
        "headgear": [
            "wokou_helmet",
            "wokou_kasa",
            "wokou_headband",
            "oni_mask",
            "pirate_bandana",
            "none",
        ],
        "weapons": CAVALRY_FOOT,
        "offhand": "sometimes",
    },
    "general": {
        "role": "mixed",
        "outfits": [
            "general_purple",
            "wokou_domaru",
            "oni_red",
            "wokou_haramaki",
            "wokou_dark_navy",
            "pirate_teal",
        ],
        "headgear": [
            "wokou_helmet",
            "oni_mask",
            "wokou_kasa",
            "wokou_headband",
            "pirate_bandana",
        ],
        "weapons": COMMAND_FOOT,
        "offhand": "sometimes",
    },
    "daimyo": {
        "role": "mixed",
        "outfits": ["oni_red", "general_purple", "wokou_domaru"],
        "headgear": ["oni_mask", "wokou_helmet", "wokou_kasa", "pirate_bandana", "wokou_headband"],
        "weapons": DAIMYO_FOOT,
        "offhand": "sometimes",
    },
}

MOUNTED_ENEMIES = ("cavalry", "general", "daimyo")


def stable_int(text: str) -> int:
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return int(digest[:12], 16)


def load_json(path: Path) -> dict:
    parsed = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(parsed, dict):
        raise ValueError(f"expected JSON object: {path}")
    return parsed


def recipe_signature(recipe: dict, *extra_fields: str) -> tuple[str, ...]:
    fields = [
        "faction",
        "skin",
        "outfit",
        "headgear",
        "backgear",
        "weapon",
        "offhand",
    ]
    fields.extend(extra_fields)
    return tuple(str(recipe.get(field, "")) for field in fields)


def attack_class_for(weapon_id: str) -> str:
    weapon = forge.WEAPON_BY_ID[weapon_id]
    return "ranged" if str(weapon["grip"]) == "ranged" else "melee"


def pose_variant_for(templates: dict, weapon_id: str, offhand_id: str) -> str:
    if offhand_id == "none":
        return weapon_id
    family = str(templates.get("combo_pairs", {}).get(f"{weapon_id}+{offhand_id}", ""))
    if not family:
        raise ValueError(f"no combo pose for {weapon_id}+{offhand_id}")
    return f"combo_{family}"


def offhand_for(config: dict, weapon_id: str, index: int) -> str:
    weapon = forge.WEAPON_BY_ID[weapon_id]
    if str(weapon["grip"]) != "one_hand":
        return "none"
    mode = str(config["offhand"])
    if mode == "never":
        return "none"
    if mode == "shield_first":
        return "dun"
    if mode == "sometimes":
        return "dun" if index % 3 == 0 else "none"
    raise ValueError(f"unknown offhand mode: {mode}")


def validate_recipe_against_templates(recipe: dict, templates: dict) -> None:
    forge.validate_recipe_faction(recipe)
    indexes = {
        "outfits": {item["id"] for item in templates["outfits"]},
        "headgear": {item["id"] for item in templates["headgear"]},
        "backgear": {item["id"] for item in templates["backgear"]},
        "weapons": {item["id"] for item in templates["weapons"]},
    }
    for group, field in (
        ("outfits", "outfit"),
        ("headgear", "headgear"),
        ("backgear", "backgear"),
        ("weapons", "weapon"),
    ):
        item_id = str(recipe[field])
        if item_id not in indexes[group]:
            raise ValueError(f"{field} is not in runtime template pool: {item_id}")
    offhand_id = str(recipe.get("offhand", "none"))
    if offhand_id != "none" and offhand_id not in indexes["weapons"]:
        raise ValueError(f"offhand is not in runtime template pool: {offhand_id}")


def build_foot_recipes(
    enemy_id: str,
    base_recipe: dict,
    templates: dict,
) -> list[dict]:
    config = ENEMY_POOLS[enemy_id]
    rng = random.Random(stable_int(f"foot:{enemy_id}"))
    seen = {recipe_signature(base_recipe)}
    gear_fields = ("skin", "outfit", "headgear", "backgear", "weapon", "offhand")
    recipes: list[dict] = []
    attempt = 0
    while len(recipes) < VARIANTS_PER_ENEMY:
        outfit = rng.choice(config["outfits"])
        headgear = rng.choice(config["headgear"])
        backgear = rng.choice(WOKOU_BACKGEAR)
        skin = rng.choice(SKINS)
        weapon = rng.choice(config["weapons"])
        offhand = offhand_for(config, weapon, attempt)
        recipe = {
            "faction": "wokou",
            "skin": skin,
            "outfit": outfit,
            "headgear": headgear,
            "backgear": backgear,
            "weapon": weapon,
            "offhand": offhand,
            "pose_variant": pose_variant_for(templates, weapon, offhand),
        }
        signature = recipe_signature(recipe)
        distinct_enough = all(
            sum(recipe[field] != previous[field] for field in gear_fields) >= 2
            for previous in recipes
        )
        if signature not in seen and distinct_enough:
            validate_recipe_against_templates(recipe, templates)
            seen.add(signature)
            recipes.append(recipe)
        attempt += 1
        if attempt > 5000:
            raise ValueError(f"cannot find distinct recipes for {enemy_id}")
    return recipes


def build_mounted_recipes(
    enemy_id: str,
    templates: dict,
) -> list[dict]:
    offset = stable_int(f"mounted:{enemy_id}") % 997
    seen: set[tuple[str, ...]] = set()
    recipes: list[dict] = []

    def add(recipe: dict) -> None:
        validate_recipe_against_templates(recipe, templates)
        signature = recipe_signature(recipe, "mount", "action", "mount_motion")
        if signature in seen:
            return
        seen.add(signature)
        recipes.append(recipe)

    for index in range(MOUNTED_VARIANTS_PER_ENEMY):
        ranged = index >= MOUNTED_VARIANTS_PER_ENEMY // 2
        local = index - MOUNTED_VARIANTS_PER_ENEMY // 2 if ranged else index
        outfit = WOKOU_OUTFITS[(offset + index * 3) % len(WOKOU_OUTFITS)]
        headgear = WOKOU_HEADGEAR[(offset * 2 + index * 5) % len(WOKOU_HEADGEAR)]
        backgear = WOKOU_BACKGEAR[(offset + index) % len(WOKOU_BACKGEAR)]
        skin = SKINS[(offset + index * 2) % len(SKINS)]
        mount = cav_mount_for(enemy_id, offset + index)
        if ranged:
            action = "mounted_bow"
            weapon = "gong"
            offhand = "none"
        else:
            action = "saber_cut" if local % 2 == 0 else "lance_charge"
            weapon = "dao" if action == "saber_cut" else "qiang"
            offhand = "none"
        recipe = {
            "faction": "wokou",
            "skin": skin,
            "outfit": outfit,
            "headgear": headgear,
            "backgear": backgear,
            "weapon": weapon,
            "offhand": offhand,
            "mount": mount,
            "mount_motion": "walk",
            "mount_pose_variant": f"cavalry_{weapon}_walk",
            "pose_variant": f"cavalry_{weapon}_walk",
            "action": action,
        }
        add(recipe)

    attempt = 0
    while len(recipes) < MOUNTED_VARIANTS_PER_ENEMY:
        index = len(recipes) + attempt
        ranged = len(recipes) >= MOUNTED_VARIANTS_PER_ENEMY // 2
        action = "mounted_bow" if ranged else ("saber_cut" if index % 2 == 0 else "lance_charge")
        weapon = "gong" if ranged else ("dao" if action == "saber_cut" else "qiang")
        recipe = {
            "faction": "wokou",
            "skin": SKINS[(offset + index * 3) % len(SKINS)],
            "outfit": WOKOU_OUTFITS[(offset + index * 7) % len(WOKOU_OUTFITS)],
            "headgear": WOKOU_HEADGEAR[(offset + index * 3) % len(WOKOU_HEADGEAR)],
            "backgear": WOKOU_BACKGEAR[(offset + index * 5) % len(WOKOU_BACKGEAR)],
            "weapon": weapon,
            "offhand": "none",
            "mount": cav_mount_for(enemy_id, offset + index),
            "mount_motion": "walk",
            "mount_pose_variant": f"cavalry_{weapon}_walk",
            "pose_variant": f"cavalry_{weapon}_walk",
            "action": action,
        }
        add(recipe)
        attempt += 1
        if attempt > 5000:
            raise ValueError(f"cannot find distinct mounted recipes for {enemy_id}")
    return recipes


def cav_mount_for(enemy_id: str, index: int) -> str:
    mounts = ["grey", "zhaohong", "black"]
    if enemy_id == "daimyo":
        mounts = ["black", "grey", "zhaohong"]
    return mounts[index % len(mounts)]


def validate_strip(strip: Image.Image, label: str, frames: int) -> None:
    if strip.mode != "RGBA":
        raise ValueError(f"{label} must be RGBA")
    if strip.size != (CELL * frames, CELL):
        raise ValueError(f"{label} must be {CELL * frames}x{CELL}, got {strip.size}")
    for index in range(frames):
        frame = strip.crop((index * CELL, 0, (index + 1) * CELL, CELL))
        alpha = frame.getchannel("A")
        bbox = alpha.getbbox()
        if bbox is None:
            raise ValueError(f"{label} frame {index} is empty")
        if bbox[0] <= 0 or bbox[1] <= 0 or bbox[2] >= CELL or bbox[3] >= CELL:
            raise ValueError(f"{label} frame {index} clips the cell: {bbox}")
        if sum(alpha.histogram()[1:255]) != 0:
            raise ValueError(f"{label} frame {index} contains semi-transparent pixels")


def save_strip(strip: Image.Image, target_dir: Path) -> tuple[str, str]:
    target_dir.mkdir(parents=True, exist_ok=True)
    png_path = target_dir / "walk.png"
    webp_path = target_dir / "walk.webp"
    strip.save(png_path, optimize=True)
    strip.save(webp_path, format="WEBP", lossless=True, quality=100, method=6)
    return (
        f"res://{png_path.relative_to(ROOT / 'game').as_posix()}",
        f"res://{webp_path.relative_to(ROOT / 'game').as_posix()}",
    )


def foot_variant_entry(
    enemy_id: str,
    index: int,
    recipe: dict,
    preview: str,
    texture: str,
) -> dict:
    weapon = str(recipe["weapon"])
    offhand = str(recipe["offhand"])
    attack_class = attack_class_for(weapon)
    role = str(ENEMY_POOLS[enemy_id]["role"])
    if role == "mixed":
        role = "ranged" if attack_class == "ranged" else "infantry"
    variant_id = f"{enemy_id}_foot_{index:02d}"
    return {
        "enemy_id": enemy_id,
        "variant_id": variant_id,
        "draw_id": variant_id,
        "visual_mode": "foot",
        "texture": texture,
        "preview": preview,
        "frames": FOOT_FRAMES,
        "fps": FOOT_FPS,
        "role": role,
        "attack_class": attack_class,
        "weapon": weapon,
        "offhand": offhand,
        "mount": "none",
        "mount_motion": "none",
        "recipe": recipe,
        "tags": ["wokou", "foot", role, attack_class, weapon],
    }


def mounted_variant_entry(
    enemy_id: str,
    index: int,
    recipe: dict,
    preview: str,
    texture: str,
) -> dict:
    action = cavalry.action_by_id(str(recipe["action"]))
    if action is None:
        raise ValueError(f"unknown mounted action: {recipe['action']}")
    attack_class = str(action["range"])
    variant_id = f"{enemy_id}_mounted_{index:02d}"
    return {
        "enemy_id": enemy_id,
        "variant_id": variant_id,
        "draw_id": variant_id,
        "visual_mode": "mounted",
        "texture": texture,
        "preview": preview,
        "frames": MOUNTED_FRAMES,
        "fps": MOUNTED_FPS,
        "role": "cavalry",
        "attack_class": attack_class,
        "weapon": str(recipe["weapon"]),
        "offhand": str(recipe["offhand"]),
        "mount": str(recipe["mount"]),
        "mount_motion": "walk",
        "action": str(recipe["action"]),
        "recipe": recipe,
        "tags": ["wokou", "mounted", attack_class, str(recipe["weapon"]), str(recipe["mount"])],
    }


def bake_foot_variants(
    enemy_id: str,
    recipes: list[dict],
    atlases: dict[str, Image.Image],
) -> list[tuple[dict, Image.Image]]:
    baked: list[tuple[dict, Image.Image]] = []
    for index, recipe in enumerate(recipes):
        label = f"{enemy_id}_foot_{index:02d}"
        strip = foot_baker.bake_strip(recipe, "walk", atlases)
        validate_strip(strip, label, FOOT_FRAMES)
        preview, texture = save_strip(strip, OUTPUT_ROOT / enemy_id / label)
        entry = foot_variant_entry(enemy_id, index, recipe, preview, texture)
        baked.append((entry, strip))
        print(f"baked {label} -> {texture}")
    return baked


def bake_mounted_variants(enemy_id: str, recipes: list[dict]) -> list[tuple[dict, Image.Image]]:
    baked: list[tuple[dict, Image.Image]] = []
    for index, recipe in enumerate(recipes):
        action = cavalry.action_by_id(str(recipe["action"]))
        mount = cavalry.mount_by_id(str(recipe["mount"]))
        if action is None or mount is None:
            raise ValueError(f"bad mounted recipe for {enemy_id}: {recipe}")
        frames = [
            mounted_baker.compose_mounted_frame(recipe, action, mount, "walk", frame)
            for frame in range(MOUNTED_FRAMES)
        ]
        strip = Image.new("RGBA", (CELL * MOUNTED_FRAMES, CELL), (0, 0, 0, 0))
        for frame_index, frame in enumerate(frames):
            mounted_baker.validate_frame(frame, f"{enemy_id}_mounted_{index:02d}/f{frame_index}")
            strip.alpha_composite(frame, (frame_index * CELL, 0))
        validate_strip(strip, f"{enemy_id}_mounted_{index:02d}", MOUNTED_FRAMES)
        label = f"{enemy_id}_mounted_{index:02d}"
        preview, texture = save_strip(strip, OUTPUT_ROOT / enemy_id / label)
        entry = mounted_variant_entry(enemy_id, index, recipe, preview, texture)
        baked.append((entry, strip))
        print(f"baked {label} -> {texture}")
    return baked


def thumbnail(strip: Image.Image, frame_index: int, scale: int = 2) -> Image.Image:
    frame = strip.crop((frame_index * CELL, 0, (frame_index + 1) * CELL, CELL))
    return frame.resize((CELL * scale, CELL * scale), Image.Resampling.NEAREST)


def build_variant_sheet(
    rows: list[tuple[str, list[dict], list[Image.Image]]],
    target: Path,
    title: str,
) -> None:
    scale = 2
    label_width = 176
    header_height = 48
    cell_width = CELL * scale
    cell_height = CELL * scale + 46
    columns = max(len(row[1]) for row in rows)
    width = label_width + columns * cell_width + 12
    height = header_height + len(rows) * cell_height + 12
    sheet = Image.new("RGBA", (width, height), (7, 13, 16, 255))
    draw = ImageDraw.Draw(sheet)
    title_font = forge.font(19)
    row_font = forge.font(15)
    small_font = forge.font(10)
    draw.text((12, 10), title, fill=(235, 224, 201, 255), font=title_font)
    for row_index, (enemy_id, entries, strips) in enumerate(rows):
        y = header_height + row_index * cell_height
        draw.line((0, y - 2, width, y - 2), fill=(42, 57, 61, 255), width=2)
        draw.text((12, y + 8), enemy_id, fill=(235, 224, 201, 255), font=row_font)
        draw.text(
            (12, y + 32),
            f"{len(entries)} variants",
            fill=(143, 169, 163, 255),
            font=small_font,
        )
        for column, (entry, strip) in enumerate(zip(entries, strips)):
            x = label_width + column * cell_width
            image = thumbnail(strip, 3, scale)
            sheet.alpha_composite(image, (x, y))
            label = str(entry["variant_id"]).replace(f"{enemy_id}_", "")
            gear = f"{entry['weapon']}+{entry['offhand']}"
            if entry["visual_mode"] == "mounted":
                gear = f"{entry['mount']} · {gear}"
            draw.text((x + 3, y + CELL * scale + 5), label, fill=(229, 216, 189, 255), font=small_font)
            draw.text((x + 3, y + CELL * scale + 21), gear, fill=(139, 161, 157, 255), font=small_font)
    sheet.convert("RGB").save(target, optimize=True)
    print(f"contact sheet -> {target.relative_to(ROOT)}")


def build_detail_sheet(entries: list[dict], strips: list[Image.Image]) -> None:
    scale = 3
    label_width = 235
    header_height = 42
    row_height = CELL * scale + 34
    frame_columns = 8
    sheet = Image.new(
        "RGB",
        (label_width + frame_columns * CELL * scale + 14, header_height + len(entries) * row_height + 14),
        (7, 13, 16),
    )
    draw = ImageDraw.Draw(sheet)
    draw.text(
        (12, 8),
        "Enemy variant motion check · 8 walk frames · 3x",
        fill=(235, 224, 201),
        font=forge.font(19),
    )
    for row, (entry, strip) in enumerate(zip(entries, strips)):
        y = header_height + row * row_height
        draw.line((0, y - 2, sheet.width, y - 2), fill=(42, 57, 61), width=2)
        draw.text(
            (12, y + 8),
            str(entry["variant_id"]),
            fill=(235, 224, 201),
            font=forge.font(14),
        )
        draw.text(
            (12, y + 30),
            f"{entry['role']} / {entry['attack_class']} / {entry['weapon']}+{entry['offhand']}",
            fill=(143, 169, 163),
            font=forge.font(10),
        )
        draw.text(
            (12, y + 47),
            str(entry["recipe"]["outfit"]),
            fill=(143, 169, 163),
            font=forge.font(10),
        )
        draw.text(
            (12, y + 64),
            str(entry["recipe"]["headgear"]),
            fill=(143, 169, 163),
            font=forge.font(10),
        )
        for frame in range(frame_columns):
            x = label_width + frame * CELL * scale
            image = thumbnail(strip, frame, scale)
            sheet.paste(image, (x, y), image)
            draw.text(
                (x + 5, y + CELL * scale + 5),
                f"W{frame + 1}",
                fill=(139, 161, 157),
                font=forge.font(10),
            )
    sheet.save(DETAIL_SHEET, optimize=True)
    print(f"detail sheet -> {DETAIL_SHEET.relative_to(ROOT)}")


def write_manifest(catalog: dict) -> None:
    lines = [
        "CharacterForge enemy variant manifest",
        f"generated_by={VARIANT_DATA.relative_to(ROOT).as_posix()}",
        f"cell={CELL}",
        f"foot_frames={FOOT_FRAMES}",
        f"mounted_frames={MOUNTED_FRAMES}",
        "",
    ]
    for enemy_id, entries in catalog["variants"].items():
        lines.append(f"[{enemy_id}] {len(entries)}")
        for entry in entries:
            lines.append(f"{entry['variant_id']}\t{entry['texture']}\t{entry['preview']}")
        lines.append("")
    MANIFEST.write_text("\n".join(lines), encoding="utf-8")
    print(f"manifest -> {MANIFEST.relative_to(ROOT)}")


def main() -> None:
    enemies = load_json(ENEMY_DATA)["enemies"]
    templates = load_json(TEMPLATE_DATA)
    atlases = forge.load_preview_atlases()
    all_variants: dict[str, list[dict]] = {}
    foot_rows: list[tuple[str, list[dict], list[Image.Image]]] = []
    mounted_rows: list[tuple[str, list[dict], list[Image.Image]]] = []
    all_foot: list[tuple[dict, Image.Image]] = []
    all_mounted: list[tuple[dict, Image.Image]] = []

    for enemy_id, definition in enemies.items():
        if enemy_id not in ENEMY_POOLS:
            raise ValueError(f"missing enemy variant pool: {enemy_id}")
        base_recipe = definition["character_recipe"]
        foot_recipes = build_foot_recipes(enemy_id, base_recipe, templates)
        foot_baked = bake_foot_variants(enemy_id, foot_recipes, atlases)
        entries = [entry for entry, _strip in foot_baked]
        strips = [strip for _entry, strip in foot_baked]
        if enemy_id in MOUNTED_ENEMIES:
            mounted_recipes = build_mounted_recipes(enemy_id, templates)
            mounted_baked = bake_mounted_variants(enemy_id, mounted_recipes)
            mounted_entries = [entry for entry, _strip in mounted_baked]
            mounted_strips = [strip for _entry, strip in mounted_baked]
            entries.extend(mounted_entries)
            all_mounted.extend(mounted_baked)
            mounted_rows.append((enemy_id, mounted_entries, mounted_strips))
        all_variants[enemy_id] = entries
        foot_rows.append((enemy_id, [entry for entry in entries if entry["visual_mode"] == "foot"], strips))
        all_foot.extend(foot_baked)

    variant_ids: set[str] = set()
    for entries in all_variants.values():
        for entry in entries:
            variant_id = str(entry["variant_id"])
            if variant_id in variant_ids:
                raise ValueError(f"duplicate variant id: {variant_id}")
            variant_ids.add(variant_id)
            texture_path = ROOT / "game" / str(entry["texture"]).removeprefix("res://")
            preview_path = ROOT / "game" / str(entry["preview"]).removeprefix("res://")
            if not texture_path.exists() or not preview_path.exists():
                raise ValueError(f"missing baked asset for {variant_id}")

    counts = {
        "foot": sum(len([entry for entry in entries if entry["visual_mode"] == "foot"]) for entries in all_variants.values()),
        "mounted": sum(len([entry for entry in entries if entry["visual_mode"] == "mounted"]) for entries in all_variants.values()),
    }
    counts["total"] = counts["foot"] + counts["mounted"]
    per_enemy = {
        enemy_id: {
            "foot": len([entry for entry in entries if entry["visual_mode"] == "foot"]),
            "mounted": len([entry for entry in entries if entry["visual_mode"] == "mounted"]),
            "total": len(entries),
        }
        for enemy_id, entries in all_variants.items()
    }
    equipment = {
        "outfits": sorted({str(entry["recipe"]["outfit"]) for entries in all_variants.values() for entry in entries}),
        "headgear": sorted({str(entry["recipe"]["headgear"]) for entries in all_variants.values() for entry in entries}),
        "backgear": sorted({str(entry["recipe"]["backgear"]) for entries in all_variants.values() for entry in entries}),
        "weapons": sorted({str(entry["weapon"]) for entries in all_variants.values() for entry in entries}),
        "offhands": sorted({str(entry["offhand"]) for entries in all_variants.values() for entry in entries}),
        "mounts": sorted(
            {
                str(entry["mount"])
                for entries in all_variants.values()
                for entry in entries
                if entry["visual_mode"] == "mounted"
            }
        ),
    }
    catalog = {
        "version": 1,
        "catalog": "enemy_variants",
        "source": "pixel-art/character_forge/bake_enemy_variants.py",
        "license": "CC BY 4.0",
        "author": "xingwangzhe",
        "cell": CELL,
        "frames": FOOT_FRAMES,
        "fps": FOOT_FPS,
        "counts": counts,
        "per_enemy": per_enemy,
        "equipment": equipment,
        "selection": {
            "foot": "Use visual_mode=foot for infantry/ranged spawns.",
            "mounted": "Use visual_mode=mounted when runtime role is cavalry.",
            "matching": "Prefer variants matching role and attack_class; fall back to the base enemies.json texture.",
        },
        "variants": all_variants,
    }
    VARIANT_DATA.write_text(
        json.dumps(catalog, ensure_ascii=False, indent="\t") + "\n",
        encoding="utf-8",
    )
    print(f"variant catalog -> {VARIANT_DATA.relative_to(ROOT)}")

    build_variant_sheet(foot_rows, FOOT_SHEET, "Enemy foot-combat CharacterForge variants")
    build_variant_sheet(mounted_rows, MOUNTED_SHEET, "Enemy mounted CharacterForge variants")
    representative = [
        all_foot[0],
        all_foot[VARIANTS_PER_ENEMY],
        all_foot[VARIANTS_PER_ENEMY * 2],
        all_foot[VARIANTS_PER_ENEMY * 5],
        all_foot[VARIANTS_PER_ENEMY * 6],
        all_foot[VARIANTS_PER_ENEMY * 7],
        all_mounted[0],
        all_mounted[MOUNTED_VARIANTS_PER_ENEMY // 2],
        all_mounted[MOUNTED_VARIANTS_PER_ENEMY],
        all_mounted[MOUNTED_VARIANTS_PER_ENEMY + MOUNTED_VARIANTS_PER_ENEMY // 2],
        all_mounted[MOUNTED_VARIANTS_PER_ENEMY * 2],
        all_mounted[MOUNTED_VARIANTS_PER_ENEMY * 2 + MOUNTED_VARIANTS_PER_ENEMY // 2],
    ]
    build_detail_sheet(
        [entry for entry, _strip in representative],
        [strip for _entry, strip in representative],
    )
    write_manifest(catalog)

    print(
        "summary: "
        f"{counts['foot']} foot + {counts['mounted']} mounted = {counts['total']} variants, "
        f"{len(equipment['outfits'])} outfits, {len(equipment['headgear'])} headgear, "
        f"{len(equipment['backgear'])} backgear, {len(equipment['weapons'])} weapons, "
        f"{len(equipment['offhands'])} offhand states, {len(equipment['mounts'])} mounts"
    )


if __name__ == "__main__":
    main()
