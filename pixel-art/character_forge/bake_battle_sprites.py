#!/usr/bin/env python3
"""Bake battlefield sprite strips from character-forge recipes.

The combat renderer must never fall back to the retired hand-drawn
``game/assets/units/*/static.png`` sheets. Every enemy and playable battle
character carries a faction-valid recipe, and this script composes that recipe
from the same naked body / outfit / headgear / backgear / weapon layers used by
CharacterForge.

Run from the project root:
    python3 pixel-art/character_forge/bake_battle_sprites.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build as forge  # noqa: E402


ROOT = forge.ROOT
ENEMY_DATA = ROOT / "game" / "data" / "enemies.json"
CHARACTER_DATA = ROOT / "game" / "data" / "characters.json"
MERCENARY_DATA = ROOT / "game" / "data" / "mercenaries.json"
OUTPUT_ROOT = ROOT / "game" / "assets" / "units" / "forge"
ENEMY_CONTACT_SHEET = Path(__file__).resolve().parent / "enemy_roster.png"
PLAYER_CONTACT_SHEET = Path(__file__).resolve().parent / "player_roster.png"
MERCENARY_CONTACT_SHEET = Path(__file__).resolve().parent / "mercenary_roster.png"
REFERENCE_TRIO_SHEET = Path(__file__).resolve().parent / "reference_trio_actions.png"
REFERENCE_TRIO_IDS = ("agong", "amei", "aqi")
REFERENCE_TRIO_CLIPS = ("idle", "walk", "attack_1")


def load_enemies() -> dict:
    data = json.loads(ENEMY_DATA.read_text(encoding="utf-8"))
    enemies = data.get("enemies", {})
    if not isinstance(enemies, dict) or not enemies:
        raise ValueError(f"no enemies found in {ENEMY_DATA}")
    return enemies


def clip_frames(clip_name: str) -> list[int]:
    clip = forge.CLIPS[clip_name]
    start = int(clip["start"])
    return list(range(start, start + int(clip["count"])))


def bake_strip(
    recipe: dict,
    clip_name: str,
    atlases: dict[str, Image.Image],
) -> Image.Image:
    frames = clip_frames(clip_name)
    strip = Image.new("RGBA", (forge.CELL * len(frames), forge.CELL), (0, 0, 0, 0))
    for column, frame in enumerate(frames):
        image = forge.compose_recipe_frame(recipe, frame, atlases)
        strip.alpha_composite(image, (column * forge.CELL, 0))
    return strip


def build_contact_sheet(
    rows: list[tuple[str, Image.Image]],
    target: Path,
) -> None:
    scale = 2
    label_height = 30
    cell_w = forge.CELL * scale
    cell_h = forge.CELL * scale + label_height
    sheet = Image.new("RGBA", (cell_w * len(rows), cell_h), (8, 16, 20, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (enemy_id, strip) in enumerate(rows):
        first = strip.crop((0, 0, forge.CELL, forge.CELL)).resize(
            (cell_w, forge.CELL * scale),
            Image.Resampling.NEAREST,
        )
        x = index * cell_w
        sheet.alpha_composite(first, (x, 0))
        draw.text((x + 10, forge.CELL * scale + 8), enemy_id, fill=(229, 216, 189, 255))
    sheet.save(target, optimize=True)
    print(f"contact sheet -> {target.relative_to(ROOT)}")


def build_reference_trio_sheet(
    characters: dict,
    atlases: dict[str, Image.Image],
) -> None:
    scale = 2
    label_width = 128
    header_height = 34
    row_height = forge.CELL * scale + 8
    frame_count = sum(int(forge.CLIPS[clip]["count"]) for clip in REFERENCE_TRIO_CLIPS)
    width = label_width + frame_count * forge.CELL * scale
    height = header_height + len(REFERENCE_TRIO_IDS) * row_height
    sheet = Image.new("RGBA", (width, height), (8, 16, 20, 255))
    draw = ImageDraw.Draw(sheet)
    label_font = forge.font(17)
    small_font = forge.font(13)
    x = label_width
    for clip in REFERENCE_TRIO_CLIPS:
        clip_width = int(forge.CLIPS[clip]["count"]) * forge.CELL * scale
        draw.text(
            (x + 8, 8),
            f"{clip}  {forge.CLIPS[clip]['count']}f @ {forge.CLIPS[clip]['fps']}fps",
            fill=(229, 216, 189, 255),
            font=small_font,
        )
        draw.line((x, header_height, x, height), fill=(50, 67, 72, 255), width=2)
        x += clip_width

    for row, character_id in enumerate(REFERENCE_TRIO_IDS):
        definition = characters[character_id]
        recipe = definition["character_recipe"]
        y = header_height + row * row_height
        draw.text(
            (12, y + 26),
            character_id,
            fill=(235, 222, 194, 255),
            font=label_font,
        )
        draw.text(
            (12, y + 52),
            str(definition["preset_name_en"]),
            fill=(149, 171, 167, 255),
            font=small_font,
        )
        x = label_width
        for clip in REFERENCE_TRIO_CLIPS:
            for frame in clip_frames(clip):
                image = forge.compose_recipe_frame(recipe, frame, atlases)
                image = image.resize(
                    (forge.CELL * scale, forge.CELL * scale),
                    Image.Resampling.NEAREST,
                )
                sheet.alpha_composite(image, (x, y))
                x += forge.CELL * scale
        draw.line((0, y + row_height, width, y + row_height), fill=(37, 52, 57, 255), width=2)
    sheet.save(REFERENCE_TRIO_SHEET, optimize=True)
    print(f"reference trio sheet -> {REFERENCE_TRIO_SHEET.relative_to(ROOT)}")

    for character_id in REFERENCE_TRIO_IDS:
        recipe = characters[character_id]["character_recipe"]
        frames: list[Image.Image] = []
        durations: list[int] = []
        for clip in REFERENCE_TRIO_CLIPS:
            clip_data = forge.CLIPS[clip]
            frame_duration = max(1, round(1000 / int(clip_data["fps"])))
            for frame in clip_frames(clip):
                image = forge.compose_recipe_frame(recipe, frame, atlases)
                canvas = Image.new("RGB", (forge.CELL * scale, forge.CELL * scale), (8, 16, 20))
                enlarged = image.resize(canvas.size, Image.Resampling.NEAREST)
                canvas.paste(enlarged, (0, 0), enlarged)
                frames.append(canvas)
                durations.append(frame_duration)
        target = REFERENCE_TRIO_SHEET.with_name(
            f"reference_{character_id}_actions.gif"
        )
        frames[0].save(
            target,
            save_all=True,
            append_images=frames[1:],
            duration=durations,
            loop=0,
            disposal=2,
        )
        print(f"reference gif -> {target.relative_to(ROOT)}")


def output_path(resource_path: str) -> Path:
    if not resource_path.startswith("res://"):
        raise ValueError(f"expected res:// path, got {resource_path}")
    return ROOT / "game" / resource_path.removeprefix("res://")


def main() -> None:
    enemies = load_enemies()
    characters = json.loads(CHARACTER_DATA.read_text(encoding="utf-8")).get("characters", {})
    mercenaries = json.loads(MERCENARY_DATA.read_text(encoding="utf-8")).get("mercenaries", {})
    atlases = forge.load_preview_atlases()
    enemy_rows: list[tuple[str, Image.Image]] = []
    player_rows: list[tuple[str, Image.Image]] = []
    mercenary_rows: list[tuple[str, Image.Image]] = []
    for enemy_id, definition in enemies.items():
        recipe = definition.get("character_recipe")
        if not isinstance(recipe, dict):
            raise ValueError(f"{enemy_id} is missing character_recipe")
        if str(recipe.get("faction", "")) != "wokou":
            raise ValueError(f"{enemy_id} must be a Wokou battlefield enemy")
        strip = bake_strip(recipe, "walk", atlases)
        output = OUTPUT_ROOT / enemy_id / "walk.png"
        output.parent.mkdir(parents=True, exist_ok=True)
        strip.save(output, optimize=True)
        declared_frames = int(definition.get("sprite_frames", 0))
        if declared_frames != len(clip_frames("walk")):
            raise ValueError(
                f"{enemy_id} declares {declared_frames} frames, "
                f"but walk strip contains {len(clip_frames('walk'))}"
            )
        print(
            f"baked {enemy_id}: {strip.width}x{strip.height} "
            f"-> {output.relative_to(ROOT)}"
        )
        enemy_rows.append((enemy_id, strip))
    for character_id, definition in characters.items():
        recipe = definition.get("character_recipe")
        if not isinstance(recipe, dict):
            continue
        if str(recipe.get("faction", "")) != "ming":
            raise ValueError(f"{character_id} must be a Ming battle character")
        idle = bake_strip(recipe, "idle", atlases)
        walk = bake_strip(recipe, "walk", atlases)
        for clip_name, strip, path_key, frames_key in (
            ("idle", idle, "battle_idle", "battle_idle_frames"),
            ("walk", walk, "battle_walk", "battle_walk_frames"),
        ):
            output = output_path(str(definition[path_key]))
            output.parent.mkdir(parents=True, exist_ok=True)
            strip.save(output, optimize=True)
            if int(definition.get(frames_key, 0)) != len(clip_frames(clip_name)):
                raise ValueError(
                    f"{character_id} {clip_name} frame count does not match "
                    f"{len(clip_frames(clip_name))}"
                )
            print(
                f"baked {character_id}/{clip_name}: {strip.width}x{strip.height} "
                f"-> {output.relative_to(ROOT)}"
            )
        player_rows.append((character_id, walk))
    for mercenary_id, definition in mercenaries.items():
        recipe = definition.get("character_recipe")
        if not isinstance(recipe, dict):
            raise ValueError(f"{mercenary_id} is missing character_recipe")
        if str(recipe.get("faction", "")) != "ming":
            raise ValueError(f"{mercenary_id} must be a Ming allied unit")
        idle = bake_strip(recipe, "idle", atlases)
        walk = bake_strip(recipe, "walk", atlases)
        for clip_name, strip, path_key, frames_key in (
            ("idle", idle, "battle_idle", "battle_idle_frames"),
            ("walk", walk, "battle_walk", "battle_walk_frames"),
        ):
            output = output_path(str(definition[path_key]))
            output.parent.mkdir(parents=True, exist_ok=True)
            strip.save(output, optimize=True)
            if int(definition.get(frames_key, 0)) != len(clip_frames(clip_name)):
                raise ValueError(
                    f"{mercenary_id} {clip_name} frame count does not match "
                    f"{len(clip_frames(clip_name))}"
                )
            print(
                f"baked ally {mercenary_id}/{clip_name}: {strip.width}x{strip.height} "
                f"-> {output.relative_to(ROOT)}"
            )
        mercenary_rows.append((mercenary_id, walk))
    missing_trio = [character_id for character_id in REFERENCE_TRIO_IDS if character_id not in characters]
    if missing_trio:
        raise ValueError(f"reference trio characters missing: {missing_trio}")
    build_reference_trio_sheet(characters, atlases)
    build_contact_sheet(enemy_rows, ENEMY_CONTACT_SHEET)
    build_contact_sheet(player_rows, PLAYER_CONTACT_SHEET)
    build_contact_sheet(mercenary_rows, MERCENARY_CONTACT_SHEET)


if __name__ == "__main__":
    main()
