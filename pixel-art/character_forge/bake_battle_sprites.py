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
MODEL_REDRAW_DIR = ROOT / "pixel-art" / "model_redraw"
MODEL_SLICES = MODEL_REDRAW_DIR / "slices_v3"
MODEL_WALK_HEAD_CROP = (41, 0, 88, 44)
MODEL_WALK_OUTFIT_SIZE = (40, 29)
MODEL_WALK_OUTFIT_POSITION = (44, 43)
_MODEL_WALK_CELLS: dict[str, list[Image.Image]] = {}
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


def _load_model_walk_cells(faction: str, layer: str) -> list[Image.Image]:
    key = f"{faction}:{layer}"
    if key not in _MODEL_WALK_CELLS:
        if layer == "body":
            folder = MODEL_SLICES / "walk_base_v4"
            prefix = "walk_base_v4_source"
        else:
            folder = MODEL_SLICES / f"{faction}_walk_clothing_overlay_v1"
            prefix = f"{faction}_walk_clothing_overlay_v1_source"
        cells = []
        for frame in range(8):
            path = folder / f"{prefix}_r{frame // 4:02d}_c{frame % 4:02d}.png"
            with Image.open(path) as source:
                cell = source.convert("RGBA")
                if layer == "outfit":
                    # The generated overlays drifted violet; remap those cloth
                    # pixels to late-Ming indigo or Wokou charcoal brown.
                    pixels = cell.load()
                    shadow, mid, light = ((19, 35, 46), (42, 61, 69), (83, 95, 94)) if faction == "ming" else ((28, 27, 27), (55, 43, 35), (92, 69, 49))
                    for y in range(cell.height):
                        for x in range(cell.width):
                            red, green, blue, alpha = pixels[x, y]
                            if alpha and blue > red * 1.12 and blue > green * 1.08:
                                value = (red + green + blue) / (3 * 255)
                                target = shadow if value < 0.34 else mid if value < 0.58 else light
                                pixels[x, y] = (*target, alpha)
                cells.append(cell)
        _MODEL_WALK_CELLS[key] = cells
    return _MODEL_WALK_CELLS[key]


def _recolor_model_skin(body: Image.Image, skin: dict) -> Image.Image:
    """Palette-shift only the generated body's face, neck, and exposed hands."""
    from PIL import ImageColor

    palette = {
        "light": ImageColor.getrgb(skin["light"]) + (255,),
        "base": ImageColor.getrgb(skin["base"]) + (255,),
        "dark": ImageColor.getrgb(skin["dark"]) + (255,),
        "deep": ImageColor.getrgb(skin["deep"]) + (255,),
    }
    pixels = body.load()
    for y in range(body.height):
        for x in range(body.width):
            if not ((48 <= x <= 95 and 14 <= y <= 54) or
                    (18 <= x <= 58 and 56 <= y <= 80) or
                    (66 <= x <= 105 and 56 <= y <= 80)):
                continue
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0 or red < 175 or green < 85 or blue > 195 or red < green * 1.08 or green < blue * 1.08:
                continue
            value = (red + green + blue) / 3
            target = "light" if value >= 225 else "base" if value >= 190 else "dark" if value >= 155 else "deep"
            pixels[x, y] = palette[target]
    return body


def _model_walk_body(recipe: dict, walk_index: int) -> Image.Image:
    faction = str(recipe["faction"])
    skin, _, _, _, _, _, _ = forge.resolve_recipe(recipe)
    body = _recolor_model_skin(_load_model_walk_cells(faction, "body")[walk_index].copy(), skin)
    garment = _load_model_walk_cells(faction, "outfit")[walk_index].copy()
    canvas = Image.new("RGBA", (forge.CELL, forge.CELL), (0, 0, 0, 0))
    canvas.alpha_composite(body)
    garment_box = garment.getchannel("A").getbbox()
    if garment_box:
        garment = garment.crop(garment_box).resize(MODEL_WALK_OUTFIT_SIZE, Image.Resampling.NEAREST)
        canvas.alpha_composite(garment, MODEL_WALK_OUTFIT_POSITION)
    head = body.crop(MODEL_WALK_HEAD_CROP)
    canvas.alpha_composite(head, (MODEL_WALK_HEAD_CROP[0], MODEL_WALK_HEAD_CROP[1]))
    return canvas


def _model_hand_anchors(body: Image.Image) -> tuple[tuple[float, float], tuple[float, float]]:
    """Measure exposed hand pixels on each generated walk frame for held gear."""
    pixels = body.load()
    def anchor(x_min: int, x_max: int) -> tuple[float, float]:
        points = []
        for y in range(58, 80):
            for x in range(x_min, x_max):
                red, green, blue, alpha = pixels[x, y]
                if alpha and red > 180 and green > 85 and blue < 195 and red > green * 1.08 and green > blue * 1.08:
                    points.append((x, y))
        if not points:
            return (float((x_min + x_max) / 2), 70.0)
        return (sum(point[0] for point in points) / len(points),
                sum(point[1] for point in points) / len(points))
    return anchor(18, 58), anchor(68, 106)


def _render_recipe_layer(layer: str, recipe: dict, frame: int, pose: dict) -> Image.Image:
    skin, outfit, headgear, backgear, weapon, offhand, _grip = forge.resolve_recipe(recipe)
    pose_id = str(weapon["id"])
    return forge.render_layer(layer, skin, outfit, headgear, backgear, weapon, offhand,
                              pose_id, frame, pose_override=pose)


def bake_model_walk_frame(recipe: dict, frame: int) -> Image.Image:
    """Use independent generated body/clothing art, then compose recipe gear."""
    _, _, _, _, weapon, offhand, _grip = forge.resolve_recipe(recipe)
    pose_id = str(weapon["id"])
    walk_index = frame - int(forge.CLIPS["walk"]["start"])
    base = _model_walk_body(recipe, walk_index)
    far_hand, near_hand = _model_hand_anchors(base)
    pose = forge.pose_for(frame, pose_id, str(offhand["id"]) if offhand else "none")
    pose["far_hand"] = far_hand
    pose["near_hand"] = near_hand
    image = Image.new("RGBA", (forge.CELL, forge.CELL), (0, 0, 0, 0))
    image.alpha_composite(_render_recipe_layer("backgear", recipe, frame, pose))
    image.alpha_composite(base)
    image.alpha_composite(_render_recipe_layer("headgear", recipe, frame, pose))
    if offhand is not None:
        image.alpha_composite(_render_recipe_layer("offhand", recipe, frame, pose))
    image.alpha_composite(_render_recipe_layer("weapon", recipe, frame, pose))
    return image


def bake_strip(
    recipe: dict,
    clip_name: str,
    atlases: dict[str, Image.Image],
) -> Image.Image:
    frames = clip_frames(clip_name)
    strip = Image.new("RGBA", (forge.CELL * len(frames), forge.CELL), (0, 0, 0, 0))
    for column, frame in enumerate(frames):
        faction = recipe.get("faction")
        if clip_name == "walk" and faction in ("ming", "wokou"):
            image = bake_model_walk_frame(recipe, frame)
        else:
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


def save_runtime_strip(strip: Image.Image, output: Path) -> None:
    """Keep PNG as the editable bake source; Bun derives referenced WebP files."""
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.suffix.lower() == ".webp":
        strip.save(output.with_suffix(".png"), optimize=True)
        return
    strip.save(output, optimize=True)


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
            save_runtime_strip(strip, output)
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
            save_runtime_strip(strip, output)
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
