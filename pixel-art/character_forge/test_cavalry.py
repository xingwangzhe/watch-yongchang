#!/usr/bin/env python3
"""Regression tests for the CharacterForge cavalry strips and metadata."""

from __future__ import annotations

import json
import math
import sys
import unittest
from copy import deepcopy
from pathlib import Path

from PIL import Image, ImageChops

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

import build as forge  # noqa: E402
import build_cavalry as baker  # noqa: E402
import cavalry_data as cd  # noqa: E402


DATA_PATH = ROOT / "game" / "data" / "character_templates.json"


def resolve_resource(path: str) -> Path:
    if not path.startswith("res://"):
        raise ValueError(f"not a res:// path: {path}")
    return ROOT / "game" / path.removeprefix("res://")


def faction_compatible(item: dict, faction: str) -> bool:
    item_faction = str(item.get("faction", "neutral"))
    if faction == "neutral":
        return item_faction == "neutral"
    return item_faction in (faction, "neutral")


class CavalryMetadataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.data = json.loads(DATA_PATH.read_text(encoding="utf-8"))

    def test_recipe_ids_and_metadata(self) -> None:
        self.assertEqual(
            [item["id"] for item in self.data["mounts"]],
            ["zhaohong", "black", "grey"],
        )
        self.assertEqual(
            [item["id"] for item in self.data["cavalry_actions"]],
            ["lance_charge", "mounted_bow", "saber_cut"],
        )
        self.assertEqual(
            [item["id"] for item in self.data["mount_recipes"]],
            ["mount_zhaohong", "mount_black", "mount_grey"],
        )
        self.assertEqual(
            [item["id"] for item in self.data["cavalry_recipes"]],
            [
                "ming_zhaohong_lancer",
                "ming_black_bow",
                "wokou_grey_saber",
            ],
        )
        for group in ("mount_recipes", "cavalry_recipes"):
            for variant in self.data[group]:
                self.assertEqual(variant["facing"], "right")
                self.assertEqual(variant["gait"], "diagonal_trot")
                self.assertEqual(variant["battle_cell"], 128)
                self.assertEqual(variant["anchor"], {"x": 64, "y": 122})
                self.assertEqual(variant["battle_idle_frames"], 4)
                self.assertEqual(variant["battle_walk_frames"], 8)
                for clip in ("idle", "walk"):
                    resource = variant[f"battle_{clip}"]
                    self.assertTrue(
                        resource.startswith("res://assets/units/forge/cavalry/")
                    )
                    self.assertTrue(resolve_resource(resource).is_file())

    def test_gait_metadata(self) -> None:
        gait = self.data["cavalry_gait"]
        self.assertEqual(gait["id"], "diagonal_trot")
        self.assertEqual(gait["idle_frames"], 4)
        self.assertEqual(gait["walk_frames"], 8)
        self.assertEqual(gait["idle_fps"], 6)
        self.assertEqual(gait["walk_fps"], 10)
        self.assertIn("近前腿与远后腿同相", gait["description_zh"])

    def test_style_counts_are_derived_not_dropped(self) -> None:
        expected = {}
        for faction in ("ming", "wokou", "neutral"):
            looks = (
                len(self.data["skins"])
                * sum(
                    faction_compatible(item, faction)
                    for item in self.data["outfits"]
                )
                * sum(
                    faction_compatible(item, faction)
                    for item in self.data["headgear"]
                )
                * sum(
                    faction_compatible(item, faction) and item.get("pool", True)
                    for item in self.data["backgear"]
                )
            )
            expected[faction] = (
                len(self.data["mounts"])
                * len(self.data["cavalry_actions"])
                * looks
            )
        self.assertEqual(expected, {"ming": 9216, "wokou": 5760, "neutral": 144})
        self.assertEqual(
            self.data["cavalry_faction_combination_counts"],
            expected,
        )
        self.assertEqual(self.data["cavalry_combination_count"], 15120)
        self.assertEqual(self.data["combination_count"], 74752)

    def test_recipe_validation(self) -> None:
        for recipe in self.data["mount_recipes"]:
            forge.validate_recipe_faction(recipe)
        for recipe in self.data["cavalry_recipes"]:
            forge.validate_recipe_faction(recipe)

        wrong_faction = deepcopy(self.data["cavalry_recipes"][1])
        wrong_faction["faction"] = "wokou"
        with self.assertRaises(ValueError):
            forge.validate_recipe_faction(wrong_faction)

        wrong_weapon = deepcopy(self.data["cavalry_recipes"][0])
        wrong_weapon["weapon"] = "dao"
        with self.assertRaises(ValueError):
            forge.validate_recipe_faction(wrong_weapon)

        unknown_mount = deepcopy(self.data["mount_recipes"][0])
        unknown_mount["mount"] = "dragon"
        with self.assertRaises(ValueError):
            forge.validate_recipe_faction(unknown_mount)


class CavalryStripTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.data = json.loads(DATA_PATH.read_text(encoding="utf-8"))
        cls.variants = cls.data["mount_recipes"] + cls.data["cavalry_recipes"]

    def test_strips_are_transparent_nearest_neighbour_rgba(self) -> None:
        for variant in self.variants:
            for clip, frames in (("idle", 4), ("walk", 8)):
                with self.subTest(variant=variant["id"], clip=clip):
                    image = Image.open(
                        resolve_resource(variant[f"battle_{clip}"])
                    ).convert("RGBA")
                    self.assertEqual(image.size, (baker.CELL * frames, baker.CELL))
                    for index in range(frames):
                        frame = image.crop(
                            (
                                index * baker.CELL,
                                0,
                                (index + 1) * baker.CELL,
                                baker.CELL,
                            )
                        )
                        baker.validate_frame(
                            frame, f"{variant['id']}/{clip}/f{index}"
                        )
                        alpha = frame.getchannel("A")
                        self.assertEqual(alpha.getpixel((0, 0)), 0)
                        self.assertEqual(alpha.getpixel((127, 0)), 0)
                        self.assertEqual(alpha.getpixel((0, 127)), 0)
                        self.assertEqual(alpha.getpixel((127, 127)), 0)
                        histogram = alpha.histogram()
                        self.assertEqual(sum(histogram[1:255]), 0)

    def test_render_is_deterministic(self) -> None:
        for variant in self.data["mount_recipes"]:
            mount = cd.mount_by_id(str(variant["mount"]))
            first = baker.render_mount_frame(mount, "walk", 3)
            second = baker.render_mount_frame(mount, "walk", 3)
            self.assertIsNone(ImageChops.difference(first, second).getbbox())
        for recipe in self.data["cavalry_recipes"]:
            mount = cd.mount_by_id(str(recipe["mount"]))
            action = cd.action_by_id(str(recipe["action"]))
            first = baker.compose_mounted_frame(
                recipe, action, mount, "walk", 3
            )
            second = baker.compose_mounted_frame(
                recipe, action, mount, "walk", 3
            )
            self.assertIsNone(ImageChops.difference(first, second).getbbox())


class CavalryAnimationTests(unittest.TestCase):
    def test_diagonal_trot_and_rider_lag(self) -> None:
        poses = [baker.horse_pose("walk", index) for index in range(8)]
        for pose in poses:
            near_fore = baker.leg_phase(pose, "fore", True)
            far_hind = baker.leg_phase(pose, "hind", False)
            near_hind = baker.leg_phase(pose, "hind", True)
            far_fore = baker.leg_phase(pose, "fore", False)
            self.assertAlmostEqual(near_fore, far_hind)
            self.assertAlmostEqual(
                math.sin(near_hind),
                math.sin(far_fore),
                places=6,
            )
            self.assertAlmostEqual(
                math.cos(near_hind),
                math.cos(far_fore),
                places=6,
            )
            self.assertAlmostEqual(
                math.sin(near_hind),
                math.sin(near_fore + math.pi),
                places=6,
            )
            self.assertAlmostEqual(
                math.cos(near_hind),
                math.cos(near_fore + math.pi),
                places=6,
            )
        bobs = [pose["body_dy"] for pose in poses]
        self.assertGreaterEqual(max(bobs) - min(bobs), 2)
        for index, pose in enumerate(poses):
            self.assertEqual(pose["rider_dy"], bobs[(index - 1) % 8])
        self.assertTrue(
            any(pose["rider_dy"] != pose["body_dy"] for pose in poses)
        )

    def test_idle_keeps_hooves_planted(self) -> None:
        for index in range(4):
            pose = baker.horse_pose("idle", index)
            for kind in ("fore", "hind"):
                for near in (False, True):
                    self.assertIsNone(baker.leg_phase(pose, kind, near))
                    self.assertEqual(baker.lift_value(pose, kind, near), 0.0)
            self.assertEqual(pose["rider_dy"], pose["body_dy"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
