#!/usr/bin/env python3
"""QA-test CharacterForge dao overlays on inferred generated action poses.

Outputs are contact sheets only. They do not create runtime assets or alter the
CharacterForge baker. Action rows and hand anchors remain hypotheses.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.parent / "character_forge"))
import build as forge  # noqa: E402
import bake_ground_attack_qa as ground_qa  # noqa: E402

DEFAULT_OUTPUT = Path("/tmp/yongchang-dao-action-qa")
MAP_PATH = ROOT / "ground_attack_action_mapping.json"
RECIPES = {
    "ming": {
        "faction": "ming", "skin": "tan", "outfit": "ming_navy_green",
        "headgear": "common_headwrap", "backgear": "none", "weapon": "dao", "offhand": "none",
    },
    "wokou": {
        "faction": "wokou", "skin": "tan", "outfit": "wokou_domaru",
        "headgear": "wokou_kasa", "backgear": "none", "weapon": "wokou_dao", "offhand": "none",
    },
}
ACTION_TESTS = {
    2: {"attack": 2, "label": "overhead descending slash"},
    3: {"attack": 3, "label": "forward lunge thrust"},
}
CELL = 128


def action_cells(source: list[Image.Image], row: int) -> list[Image.Image]:
    return source[row * 6:(row + 1) * 6]


def action_contacts(output: Path, row: int, faction: str, frames: list[Image.Image]) -> Path:
    gap, label_h = 14, 30
    sheet = Image.new("RGBA", (6 * CELL + 7 * gap, CELL + label_h + 2 * gap), (29, 34, 40, 255))
    draw = ImageDraw.Draw(sheet)
    for index, frame in enumerate(frames):
        x, y = gap + index * (CELL + gap), gap
        for cy in range(0, CELL, 16):
            for cx in range(0, CELL, 16):
                tone = (61, 67, 75, 255) if (cx // 16 + cy // 16) % 2 == 0 else (43, 48, 55, 255)
                draw.rectangle((x + cx, y + cy, x + cx + 15, y + cy + 15), fill=tone)
        sheet.alpha_composite(frame, (x, y))
    draw.text((gap, CELL + gap + 3), f"{faction} · row {row} · dao overlay QA", fill=(242, 232, 212, 255))
    target = output / f"{faction}_row{row}_dao_overlay_qa.png"
    sheet.save(target)
    return target


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    mapping = json.loads(MAP_PATH.read_text(encoding="utf-8"))
    body = ground_qa.slice_sheet(ground_qa.BODY_SOURCE, "body", args.output / "slices" / "body")
    faction_clothing = {
        "ming": ground_qa.slice_sheet(ground_qa.FACTIONS["ming"], "clothing", args.output / "slices" / "ming"),
        "wokou": ground_qa.slice_sheet(ground_qa.FACTIONS["wokou"], "clothing", args.output / "slices" / "wokou"),
    }
    anchor_data = mapping["dao_qa_front_hand_anchors"]
    results: dict[str, object] = {"mapping_file": str(MAP_PATH), "runtime_use": False, "cases": []}
    for faction, recipe in RECIPES.items():
        if forge.recipe_faction(recipe) != faction:
            raise ValueError(f"recipe faction mismatch for {faction}: {recipe}")
        resolved = forge.resolve_recipe(recipe)
        skin, outfit, headgear, backgear, weapon, offhand, _grip = resolved
        for row, action in ACTION_TESTS.items():
            hands = anchor_data[f"row_{row}"]
            rendered: list[Image.Image] = []
            hand_boxes: list[list[float]] = []
            for index, front_hand in enumerate(hands):
                base = body[row * 6 + index].copy()
                cloth = faction_clothing[faction][row * 6 + index]
                base.alpha_composite(cloth)
                frame_number = int(forge.CLIPS[f"attack_{action['attack']}"]["start"]) + index
                pose = forge.pose_for(frame_number, str(weapon["id"]), "none")
                pose["near_hand"] = tuple(float(v) for v in front_hand)
                # Keep stock arm metadata for comparison; only the prop grip is replaced.
                prop = forge.render_layer("weapon", skin, outfit, headgear, backgear, weapon, offhand,
                                          str(weapon["id"]), frame_number, pose_override=pose)
                result = base.copy()
                result.alpha_composite(prop)
                rendered.append(result)
                hand_boxes.append([float(front_hand[0]), float(front_hand[1])])
            contact = action_contacts(args.output, row, faction, rendered)
            # For Wokou's two-handed dao, sample torso/back hand estimate too;
            # this provides a two-hand span check without drawing another person.
            results["cases"].append({
                "faction": faction,
                "weapon_id": str(weapon["id"]),
                "body_row": row,
                "hypothesis": action["label"],
                "characterforge_attack_clip": f"attack_{action['attack']}",
                "front_hand_anchor_px": hand_boxes,
                "contact_sheet": str(contact),
                "weapon_grip": str(weapon["grip"]),
                "grip_assessment": "near-hand only; Wokou far-hand alignment is unverified" if faction == "wokou" else "single-hand anchor only",
            })
    report = args.output / "dao_action_overlay_qa_report.json"
    report.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote 4 dao overlay QA contacts and report to {args.output}")


if __name__ == "__main__":
    main()
