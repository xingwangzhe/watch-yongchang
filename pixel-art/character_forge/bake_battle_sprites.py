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
OUTPUT_ROOT = ROOT / "game" / "assets" / "units" / "forge"
ENEMY_CONTACT_SHEET = Path(__file__).resolve().parent / "enemy_roster.png"
PLAYER_CONTACT_SHEET = Path(__file__).resolve().parent / "player_roster.png"


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


def output_path(resource_path: str) -> Path:
    if not resource_path.startswith("res://"):
        raise ValueError(f"expected res:// path, got {resource_path}")
    return ROOT / "game" / resource_path.removeprefix("res://")


def main() -> None:
    enemies = load_enemies()
    characters = json.loads(CHARACTER_DATA.read_text(encoding="utf-8")).get("characters", {})
    atlases = forge.load_preview_atlases()
    enemy_rows: list[tuple[str, Image.Image]] = []
    player_rows: list[tuple[str, Image.Image]] = []
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
    build_contact_sheet(enemy_rows, ENEMY_CONTACT_SHEET)
    build_contact_sheet(player_rows, PLAYER_CONTACT_SHEET)


if __name__ == "__main__":
    main()
