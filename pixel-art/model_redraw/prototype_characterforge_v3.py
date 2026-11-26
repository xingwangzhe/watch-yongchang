#!/usr/bin/env python3
"""Prototype separate generated body and faction-clothing layer composition.

Only slices/composites generated pixels. Outputs stay in /tmp for visual QA and
never replace CharacterForge runtime assets.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
SLICES = ROOT / "slices_v3"
DEFAULT_OUT = Path("/tmp/yongchang-asset-qa/characterforge_v3_prototype")
CELL = 128
OUTFIT_SIZE = (74, 75)
OUTFIT_BOTTOM = 104
HEAD_CROP = (28, 0, 101, 43)


def load_cells(name: str, columns: int, rows: int, prefix: str | None = None) -> list[Image.Image]:
    prefix = prefix or f"{name}_source"
    images = []
    for row in range(rows):
        for col in range(columns):
            path = SLICES / name / f"{prefix}_r{row:02d}_c{col:02d}.png"
            image = Image.open(path).convert("RGBA")
            if image.size != (CELL, CELL):
                raise ValueError(f"{path} has size {image.size}; expected {(CELL, CELL)}")
            images.append(image)
    return images


def compose(body: Image.Image, garment: Image.Image, *, fit_clothing: bool = True) -> Image.Image:
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    canvas.alpha_composite(body)
    fitted = garment.resize(OUTFIT_SIZE, Image.Resampling.NEAREST) if fit_clothing else garment
    garment_pos = ((CELL - fitted.width) // 2, OUTFIT_BOTTOM - fitted.height) if fit_clothing else (0, 0)
    canvas.alpha_composite(fitted, garment_pos)
    # Reapply the source face/hair region over the garment to keep the face clear.
    head = body.crop(HEAD_CROP)
    canvas.alpha_composite(head, (HEAD_CROP[0], HEAD_CROP[1]))
    return canvas


def compose_mounted(
    horse: Image.Image,
    tack: Image.Image,
    rider: Image.Image,
    rider_clothes: Image.Image,
) -> Image.Image:
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    canvas.alpha_composite(horse)
    canvas.alpha_composite(tack)
    canvas.alpha_composite(rider)
    canvas.alpha_composite(rider_clothes)
    head = rider.crop(HEAD_CROP)
    canvas.alpha_composite(head, (HEAD_CROP[0], HEAD_CROP[1]))
    return canvas


def save_strip(frames: list[Image.Image], path: Path, columns: int = 8) -> None:
    rows = (len(frames) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * CELL, rows * CELL), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, ((index % columns) * CELL, (index // columns) * CELL))
    sheet.save(path)


def contact_sheet(groups: list[tuple[str, list[Image.Image]]], path: Path) -> None:
    gap, label_h = 8, 24
    columns = max(len(frames) for _, frames in groups)
    rows = len(groups)
    sheet = Image.new(
        "RGBA",
        (columns * CELL + (columns + 1) * gap, rows * (CELL + label_h) + (rows + 1) * gap),
        (35, 39, 45, 255),
    )
    draw = ImageDraw.Draw(sheet)
    checker = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    checker_draw = ImageDraw.Draw(checker)
    for y in range(0, CELL, 16):
        for x in range(0, CELL, 16):
            if (x // 16 + y // 16) % 2 == 0:
                checker_draw.rectangle((x, y, x + 15, y + 15), fill=(67, 72, 80, 255))
    for row, (label, frames) in enumerate(groups):
        y = gap + row * (CELL + label_h + gap)
        draw.text((gap, y + CELL + 4), label, fill=(245, 236, 214, 255))
        for col, frame in enumerate(frames):
            x = gap + col * (CELL + gap)
            sheet.alpha_composite(checker, (x, y))
            sheet.alpha_composite(frame, (x, y))
    sheet.save(path)


def changed_fraction(a: Image.Image, b: Image.Image) -> float:
    aa, bb = a.convert("RGBA"), b.convert("RGBA")
    diff = sum(
        1
        for p, q in zip(aa.get_flattened_data(), bb.get_flattened_data())
        if max(abs(p[i] - q[i]) for i in range(4)) > 12
    )
    return round(diff / (aa.width * aa.height), 5)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--include-attacks", action="store_true", help="compatibility flag; action composites are always generated")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    walk = load_cells("walk_base_v3", 4, 2)
    attack = load_cells("ground_attack_bodies_v3", 6, 5)
    horse_gaits = load_cells("horse_gaits_v5", 8, 3)
    horse_tack = load_cells("horse_tack_v1", 8, 3)
    rider_base = load_cells("rider_base_v1", 4, 2)
    source_by_faction = {
        "ming": {
            "walk": "ming_walk_clothing_overlay_v1",
            "attack": ("ming_ground_attack_overlay_raw", "ming_ground_attack_clothing_overlay_v1_source"),
            "rider": "ming_rider_walk_overlay_v1",
            "tack_row": 0,
        },
        "wokou": {
            "walk": "wokou_walk_clothing_overlay_v1",
            "attack": ("wokou_ground_attack_overlay_raw", "wokou_ground_attack_clothing_overlay_v1_source"),
            "rider": "wokou_rider_walk_overlay_v1",
            "tack_row": 1,
        },
    }
    audit: dict[str, object] = {
        "source_body": "walk_base_v3_source.png",
        "source_actions": "ground_attack_bodies_v3_source.png",
        "layer_order": ["base body", "faction clothing overlay", "head and face crop from base body"],
        "cell_size": [CELL, CELL],
        "clothing_size": list(OUTFIT_SIZE),
        "clothing_bottom_y": OUTFIT_BOTTOM,
        "head_crop": list(HEAD_CROP),
        "runtime_asset_replaced": False,
        "faction_separation": "Ming and Wokou use separate ground-action, rider clothing, and tack rows; body bases are shared",
        "mounted_layer_order": ["horse gait", "matched horse tack", "rider base", "faction rider overlay", "rider head and face crop"],
        "factions": {},
    }
    walk_groups: list[tuple[str, list[Image.Image]]] = []
    action_contact_groups: dict[str, list[tuple[str, list[Image.Image]]]] = {"ming": [], "wokou": []}
    mount_contact_groups: dict[str, list[tuple[str, list[Image.Image]]]] = {"ming": [], "wokou": []}
    for faction, sources in source_by_faction.items():
        overlays = load_cells(sources["walk"], 4, 2)
        frames = [compose(body, garment) for body, garment in zip(walk, overlays)]
        strip_path = args.output / f"{faction}_walk_composite.png"
        save_strip(frames, strip_path)
        walk_groups.append((f"{faction} walk", frames))
        data: dict[str, object] = {
            "source_overlay": f"{sources['walk']}_source.png",
            "walk_output": str(strip_path),
            "walk_adjacent_frame_delta": [changed_fraction(frames[i - 1], frames[i]) for i in range(1, len(frames))],
        }
        attack_folder, attack_prefix = sources["attack"]
        attack_overlays = load_cells(attack_folder, 6, 5, prefix=attack_prefix)
        # Action overlay crops were generated on the same fixed 128px pose canvas;
        # keep their pixel position and scale to preserve pose-specific sleeves.
        action_frames = [compose(body, garment, fit_clothing=False) for body, garment in zip(attack, attack_overlays)]
        action_path = args.output / f"{faction}_action_composite_qa.png"
        save_strip(action_frames, action_path, columns=6)
        row_data = []
        for row in range(5):
            row_frames = action_frames[row * 6:(row + 1) * 6]
            row_data.append({
                "action_row": row,
                "source_overlay_indices": list(range(row * 6, row * 6 + 6)),
                "frame_delta": [changed_fraction(row_frames[i - 1], row_frames[i]) for i in range(1, 6)],
            })
            action_contact_groups[faction].append((f"{faction} action row {row}", row_frames))
        data["action_output_qa_only"] = str(action_path)
        data["action_rows"] = row_data
        data["action_overlay_source"] = attack_prefix

        rider_overlays = load_cells(sources["rider"], 4, 2)
        tack_row = int(sources["tack_row"])
        for horse_row, coat_name in enumerate(("chestnut", "black", "grey")):
            mounted_frames = []
            for frame_index in range(8):
                rider_index = frame_index
                frame = compose_mounted(
                    horse_gaits[horse_row * 8 + frame_index],
                    horse_tack[tack_row * 8 + frame_index],
                    rider_base[rider_index],
                    rider_overlays[rider_index],
                )
                mounted_frames.append(frame)
            mount_path = args.output / f"{faction}_mounted_{coat_name}_qa.png"
            save_strip(mounted_frames, mount_path)
            mount_contact_groups[faction].append((f"{faction} {coat_name} mount", mounted_frames))
            data.setdefault("mounted", []).append({
                "coat_row": horse_row,
                "coat_name_assumption": coat_name,
                "tack_row": tack_row,
                "output_qa_only": str(mount_path),
                "frame_delta": [changed_fraction(mounted_frames[i - 1], mounted_frames[i]) for i in range(1, 8)],
            })
        audit["factions"][faction] = data

    contact_path = args.output / "walk_composite_contact.png"
    contact_sheet(walk_groups, contact_path)
    audit["walk_contact"] = str(contact_path)
    for faction, groups in action_contact_groups.items():
        contact_path = args.output / f"{faction}_action_contact.png"
        contact_sheet(groups, contact_path)
        audit["factions"][faction]["action_contact"] = str(contact_path)
    for faction, groups in mount_contact_groups.items():
        contact_path = args.output / f"{faction}_mounted_contact.png"
        contact_sheet(groups, contact_path)
        audit["factions"][faction]["mounted_contact"] = str(contact_path)
    report_path = args.output / "prototype_report.json"
    report_path.write_text(json.dumps(audit, indent=2) + "\n")
    print(f"wrote walk, exact-action, and mounted composites for {len(source_by_faction)} factions to {args.output}")
    print("formal CharacterForge/runtime atlases were not changed")


if __name__ == "__main__":
    main()
