#!/usr/bin/env python3
"""Rebuild formal arrow-tower sprites from the generated source sheet."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "pixel-art/renewed_composable/source/watchtowers.png"
WEAPON_SOURCE = ROOT / "pixel-art/renewed_composable/source/weapon_props.png"
DATA = ROOT / "game/data/towers.json"
OUT = ROOT / "game/assets/units/towers"
PREVIEW = ROOT / "pixel-art/towers/preview.png"
SIZE = (168, 168)
KEY = (0, 255, 0)
KEY_TOLERANCE = 210
PADDING = 5
WEAPON_CELL = 10
WEAPON_KEY = (255, 0, 255)
WEAPON_KEY_TOLERANCE = 190


def _cell_bounds(width: int, height: int, columns: int, column: int) -> tuple[int, int, int, int]:
    return (round(column * width / columns), 0, round((column + 1) * width / columns), height)


def _grid_cell_bounds(width: int, height: int, columns: int, rows: int, index: int) -> tuple[int, int, int, int]:
    row, column = divmod(index, columns)
    return (
        round(column * width / columns),
        round(row * height / rows),
        round((column + 1) * width / columns),
        round((row + 1) * height / rows),
    )


def _remove_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    kr, kg, kb = KEY
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, alpha = pixels[x, y]
            if alpha == 0:
                continue
            distance = (r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2
            if distance <= KEY_TOLERANCE**2:
                pixels[x, y] = (r, g, b, 0)
    return rgba


def _fit_tower(cell: Image.Image) -> Image.Image:
    keyed = _remove_key(cell)
    bbox = keyed.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("tower cell has no opaque pixels after chroma removal")
    content = keyed.crop(bbox)
    max_w = SIZE[0] - PADDING * 2
    max_h = SIZE[1] - PADDING * 2
    scale = min(max_w / content.width, max_h / content.height)
    fitted = content.resize(
        (max(1, round(content.width * scale)), max(1, round(content.height * scale))),
        Image.Resampling.NEAREST,
    )
    canvas = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(fitted, ((SIZE[0] - fitted.width) // 2, SIZE[1] - PADDING - fitted.height))
    return canvas


def _fit_weapon(cell: Image.Image) -> Image.Image:
    rgba = cell.convert("RGBA")
    pixels = rgba.load()
    kr, kg, kb = WEAPON_KEY
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, alpha = pixels[x, y]
            if alpha == 0:
                continue
            if (r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2 <= WEAPON_KEY_TOLERANCE**2:
                pixels[x, y] = (r, g, b, 0)
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("crossbow source cell is empty after chroma removal")
    content = rgba.crop(bbox)
    max_w, max_h = SIZE[0] - 2 * PADDING, SIZE[1] - 2 * PADDING
    scale = min(max_w / content.width, max_h / content.height)
    resized = content.resize(
        (max(1, round(content.width * scale)), max(1, round(content.height * scale))),
        Image.Resampling.NEAREST,
    )
    result = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    result.alpha_composite(resized, ((SIZE[0] - resized.width) // 2, (SIZE[1] - resized.height) // 2))
    return result


def build() -> list[tuple[str, Image.Image]]:
    if not SOURCE.is_file():
        raise FileNotFoundError(f"missing generated tower source: {SOURCE}")
    source = Image.open(SOURCE).convert("RGBA")
    data = json.loads(DATA.read_text(encoding="utf-8"))
    weapon_art = data.get("weapon_art", {})
    if weapon_art.get("source") != "pixel-art/renewed_composable/source/weapon_props.png":
        raise ValueError("tower crossbow source is not registered in towers.json")
    if int(weapon_art.get("cell", -1)) != WEAPON_CELL:
        raise ValueError("tower crossbow must use v5 weapon atlas cell 10")
    if weapon_art.get("texture") != "res://assets/units/towers/tower_crossbow.webp":
        raise ValueError("tower crossbow runtime texture is not registered")
    definitions = data.get("towers", {})
    if len(definitions) != 3:
        raise ValueError("expected exactly three formal tower definitions")
    result: list[tuple[str, Image.Image]] = []
    for tower_id in ("watchtower", "arrow_tower", "dragon_tower"):
        definition = definitions.get(tower_id)
        if not isinstance(definition, dict):
            raise ValueError(f"missing tower definition: {tower_id}")
        if definition.get("art_source") != "pixel-art/renewed_composable/source/watchtowers.png":
            raise ValueError(f"{tower_id} does not declare the generated tower source")
        cell_index = int(definition.get("art_cell", -1))
        if not 0 <= cell_index < 4:
            raise ValueError(f"invalid ImageGen source cell for {tower_id}: {cell_index}")
        bounds = _grid_cell_bounds(source.width, source.height, 2, 2, cell_index)
        result.append((tower_id, _fit_tower(source.crop(bounds))))
    return result


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sprites = build()
    for tower_id, sprite in sprites:
        sprite.save(OUT / f"{tower_id}.png", optimize=True)
        sprite.save(OUT / f"{tower_id}.webp", lossless=True, quality=100, method=6)
        print(f"built source cell -> game/assets/units/towers/{tower_id}.png + .webp")

    weapon_source = Image.open(WEAPON_SOURCE).convert("RGBA")
    weapon_bounds = _grid_cell_bounds(weapon_source.width, weapon_source.height, 4, 4, WEAPON_CELL)
    crossbow = _fit_weapon(weapon_source.crop(weapon_bounds))
    crossbow.save(OUT / "tower_crossbow.png", optimize=True)
    crossbow.save(OUT / "tower_crossbow.webp", lossless=True, quality=100, method=6)
    print("built v5 weapon atlas cell 10 -> game/assets/units/towers/tower_crossbow.png + .webp")

    pad = 10
    sheet = Image.new(
        "RGBA",
        (SIZE[0] * len(sprites) + pad * (len(sprites) + 1), SIZE[1] + pad * 2),
        (20, 24, 30, 255),
    )
    draw = ImageDraw.Draw(sheet)
    for index, (tower_id, sprite) in enumerate(sprites):
        x = pad + index * (SIZE[0] + pad)
        sheet.alpha_composite(sprite, (x, pad))
        draw.text((x + 4, pad + 4), tower_id, fill=(255, 240, 190, 255), stroke_width=1, stroke_fill=(20, 24, 30, 255))
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.Resampling.NEAREST).save(PREVIEW)
    crossbow_card = Image.new("RGBA", SIZE, (35, 33, 32, 255))
    crossbow_card.alpha_composite(crossbow)
    weapon_draw = ImageDraw.Draw(crossbow_card)
    weapon_draw.text((5, SIZE[1] - 13), "Cell 10 · Crossbow", fill=(255, 241, 202, 255))
    crossbow_card.resize((SIZE[0] * 3, SIZE[1] * 3), Image.Resampling.NEAREST).save(
        ROOT / "pixel-art/towers/crossbow_preview.png"
    )
    mounted = sprites[0][1].copy()
    mounted_weapon = crossbow.rotate(45, resample=Image.Resampling.NEAREST)
    mounted_weapon = mounted_weapon.resize((round(SIZE[0] * 0.224), round(SIZE[1] * 0.224)), Image.Resampling.NEAREST)
    mounted.alpha_composite(mounted_weapon, ((SIZE[0] - mounted_weapon.width) // 2, round(SIZE[1] * 0.33) - mounted_weapon.height // 2))
    mounted.resize((SIZE[0] * 3, SIZE[1] * 3), Image.Resampling.NEAREST).save(
        ROOT / "pixel-art/towers/tower_weapon_preview.png"
    )
    print(f"wrote {PREVIEW}")


if __name__ == "__main__":
    main()
