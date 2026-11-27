"""Force source, generated sprites and formal tower runtime data to stay linked."""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pixel-art/towers"))
import build  # noqa: E402


class TowerAssetPipelineTest(unittest.TestCase):
    def test_source_to_runtime_tower_assets_are_current(self) -> None:
        source = Image.open(build.SOURCE).convert("RGBA")
        self.assertEqual(source.size, (1254, 1254))
        definitions = json.loads(build.DATA.read_text(encoding="utf-8"))["towers"]
        expected = {"watchtower": 2, "arrow_tower": 0, "dragon_tower": 3}
        self.assertEqual(set(definitions), set(expected))

        for tower_id, cell_index in expected.items():
            definition = definitions[tower_id]
            self.assertEqual(definition["art_source"], "pixel-art/renewed_composable/source/watchtowers.png")
            self.assertEqual(definition["art_cell"], cell_index)
            self.assertEqual(
                definition["texture"], f"res://assets/units/towers/{tower_id}.webp"
            )

        for tower_id, expected_image in build.build():
            png_path = build.OUT / f"{tower_id}.png"
            webp_path = build.OUT / f"{tower_id}.webp"
            self.assertTrue(png_path.is_file(), f"missing formal PNG: {png_path}")
            self.assertTrue(webp_path.is_file(), f"missing runtime WebP: {webp_path}")
            self.assertEqual(Image.open(png_path).convert("RGBA"), expected_image)
            runtime = Image.open(webp_path).convert("RGBA")
            self.assertIsNone(
                ImageChops.difference(runtime.getchannel("A"), expected_image.getchannel("A")).getbbox()
            )
            self.assertEqual(
                [p[:3] for p in runtime.get_flattened_data() if p[3] > 0],
                [p[:3] for p in expected_image.get_flattened_data() if p[3] > 0],
            )
            self.assertEqual(expected_image.size, build.SIZE)
            self.assertIsNotNone(expected_image.getchannel("A").getbbox())
            self.assertEqual(expected_image.getpixel((0, 0))[3], 0)

    def test_generated_crossbow_source_to_runtime_asset_is_current(self) -> None:
        source = Image.open(build.WEAPON_SOURCE).convert("RGBA")
        bounds = build._grid_cell_bounds(source.width, source.height, 4, 4, build.WEAPON_CELL)
        expected = build._fit_weapon(source.crop(bounds))
        metadata = json.loads(build.DATA.read_text(encoding="utf-8"))["weapon_art"]
        self.assertEqual(metadata["source"], "pixel-art/renewed_composable/source/weapon_props.png")
        self.assertEqual(metadata["cell"], 10)
        self.assertEqual(metadata["item"], "nu")
        self.assertEqual(metadata["texture"], "res://assets/units/towers/tower_crossbow.webp")
        for suffix in ("png", "webp"):
            path = build.OUT / f"tower_crossbow.{suffix}"
            self.assertTrue(path.is_file(), f"missing crossbow asset: {path}")
            actual = Image.open(path).convert("RGBA")
            self.assertIsNone(
                ImageChops.difference(actual.getchannel("A"), expected.getchannel("A")).getbbox()
            )
            self.assertEqual(
                [p[:3] for p in actual.get_flattened_data() if p[3] > 0],
                [p[:3] for p in expected.get_flattened_data() if p[3] > 0],
            )

        source_text = (ROOT / "game/scripts/actors/battlefield.gd").read_text(encoding="utf-8")
        start = source_text.index("func _draw_tower_weapon(")
        end = source_text.index("func _draw_tower_shots()", start)
        section = source_text[start:end]
        self.assertIn("draw_texture_rect", section)
        self.assertNotIn("draw_line", section)
        self.assertNotIn("draw_colored_polygon", section)

    def test_tower_aim_overlay_uses_generated_crossbow_texture(self) -> None:
        source = (ROOT / "game/scripts/actors/battlefield.gd").read_text(encoding="utf-8")
        start = source.index("func _draw_tower_weapon(")
        end = source.index("func _draw_tower_shots()", start)
        section = source[start:end]
        self.assertIn("draw_texture_rect", section)
        self.assertIn('"weapon_tex"', source)
        self.assertNotIn("draw_line", section)
        self.assertNotIn("draw_colored_polygon", section)


if __name__ == "__main__":
    unittest.main()
