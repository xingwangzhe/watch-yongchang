#!/usr/bin/env python3
"""Pillow-only modular sprite crop/compose preview; never paints new pixels."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
OUT = Path("/tmp/yongchang-asset-qa/wanglu_model_preview")
CELL = 128


def grid_cell(path: Path, columns: int, rows: int, row: int, column: int) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    bounds = (
        round(column * width / columns),
        round(row * height / rows),
        round((column + 1) * width / columns),
        round((row + 1) * height / rows),
    )
    return image.crop(bounds)


def hard_alpha(image: Image.Image, threshold: int = 128) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    image.putalpha(alpha)
    bounds = alpha.getbbox()
    return image.crop(bounds) if bounds else image


def fit(image: Image.Image, width: int, height: int) -> Image.Image:
    image = hard_alpha(image)
    scale = min(width / image.width, height / image.height)
    target = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return image.resize(target, Image.Resampling.NEAREST)


def skin_components(image: Image.Image) -> list[tuple[int, int, int]]:
    """Return (center_x, center_y, pixel_count) for connected skin-tone regions."""
    rgba = image.convert("RGBA")
    w, h = rgba.size
    pixels = rgba.load()
    mask: set[tuple[int, int]] = set()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a >= 128 and r >= 115 and g >= 62 and r > g * 1.13 and g > b * 1.08:
                mask.add((x, y))
    regions: list[tuple[int, int, int]] = []
    while mask:
        seed = mask.pop()
        stack = [seed]
        xs, ys = [], []
        while stack:
            x, y = stack.pop()
            xs.append(x); ys.append(y)
            for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if (nx, ny) in mask:
                    mask.remove((nx, ny)); stack.append((nx, ny))
        if len(xs) >= 3:
            regions.append((round(sum(xs)/len(xs)), round(sum(ys)/len(ys)), len(xs)))
    return regions


def hand_anchors(body: Image.Image) -> tuple[tuple[int, int], tuple[int, int]]:
    """Choose left/right lower skin clusters; excludes the face by its upper y position."""
    w, h = body.size
    candidates = [(x, y, n) for x, y, n in skin_components(body)
                  if y >= h * 0.39 and y <= h * 0.78]
    if len(candidates) < 2:
        raise ValueError(f"could not find two hand-tone regions: {candidates}")
    candidates.sort(key=lambda item: item[0])
    left = candidates[0]
    right = candidates[-1]
    return (left[0], left[1]), (right[0], right[1])


def place_at_point(canvas: Image.Image, overlay: Image.Image, source_point: tuple[int, int],
                   target_point: tuple[int, int]) -> None:
    canvas.alpha_composite(overlay, (target_point[0] - source_point[0],
                                     target_point[1] - source_point[1]))


def body_cell(row: int, column: int) -> Image.Image:
    return grid_cell(ROOT / "ground_body_actions_v3.png", 8, 6, row, column)


def parts() -> tuple[Image.Image, Image.Image, Image.Image, Image.Image]:
    armor = grid_cell(ROOT / "armor_chestplates_atlas.png", 8, 2, 0, 4)
    headwear = grid_cell(ROOT / "headwear_atlas_v2.png", 8, 2, 0, 6)
    weapons = ROOT / "weapons_implements_v2.png"
    dao = grid_cell(weapons, 5, 4, 0, 0)
    dun = grid_cell(weapons, 5, 4, 3, 2)
    return tuple(hard_alpha(item) for item in (armor, headwear, dao, dun))


def compose(body_source: Image.Image, armor_source: Image.Image, head_source: Image.Image,
            dao_source: Image.Image, shield_source: Image.Image) -> Image.Image:
    body = hard_alpha(body_source)
    body = fit(body, 82, 112)
    body_left = (CELL - body.width) // 2
    # Keep every pose on one 119px foot baseline; derive overlays from that pose's bbox.
    body_top = CELL - 9 - body.height
    left_hand, right_hand = hand_anchors(body)

    frame = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    frame.alpha_composite(body, (body_left, body_top))

    # Equipment anchors are recalculated from each frame's alpha bounds and normalized body height.
    armor = fit(armor_source, round(body.width * 0.52), round(body.height * 0.43))
    frame.alpha_composite(armor, (body_left + (body.width - armor.width) // 2,
                                  body_top + round(body.height * 0.32)))

    head = fit(head_source, round(body.width * 0.42), round(body.height * 0.19))
    frame.alpha_composite(head, (body_left + (body.width - head.width) // 2,
                                 body_top + round(body.height * 0.015)))

    # The source dao points down-left; its hilt is at the upper-right end.
    dao = fit(dao_source, round(body.width * 0.64), round(body.height * 0.72))
    dao_grip = (round(dao.width * 0.84), round(dao.height * 0.12))
    place_at_point(frame, dao, dao_grip,
                   (body_left + right_hand[0], body_top + right_hand[1]))

    shield = fit(shield_source, round(body.width * 0.36), round(body.height * 0.36))
    # Center the shield around the left hand so the palm reads as holding its rim/handle.
    place_at_point(frame, shield, (shield.width // 2, shield.height // 2),
                   (body_left + left_hand[0], body_top + left_hand[1]))
    return frame


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    armor, headwear, dao, shield = parts()
    idle_frames = [compose(body_cell(0, index), armor, headwear, dao, shield)
                   for index in range(4)]
    walk_frames = [compose(body_cell(1, index), armor, headwear, dao, shield)
                   for index in range(8)]
    idle = Image.new("RGBA", (CELL * 4, CELL), (0, 0, 0, 0))
    walk = Image.new("RGBA", (CELL * 8, CELL), (0, 0, 0, 0))
    for index, frame in enumerate(idle_frames):
        idle.alpha_composite(frame, (index * CELL, 0))
    for index, frame in enumerate(walk_frames):
        walk.alpha_composite(frame, (index * CELL, 0))
    idle.save(OUT / "wanglu_idle.png")
    walk.save(OUT / "wanglu_walk.png")

    contact = Image.new("RGBA", (CELL * 12, CELL * 2), (27, 33, 38, 255))
    for index, frame in enumerate(idle_frames):
        contact.alpha_composite(frame, (index * CELL, 0))
    for index, frame in enumerate(walk_frames):
        contact.alpha_composite(frame, (index * CELL, CELL))
    contact.save(OUT / "wanglu_contact.png")
    print(f"written: {OUT}/wanglu_idle.png 512x128, {OUT}/wanglu_walk.png 1024x128")


if __name__ == "__main__":
    main()
