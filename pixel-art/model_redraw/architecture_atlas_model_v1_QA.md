# Generated architecture atlas v1 QA

## Source and target

- Generated source: `architecture_atlas_model_v1_source.png` (OpenAI image-generation tool).
- Source size: 1448×1086 RGBA. It divides exactly into 8×6 cells of 181×181.
- Target format: `game/assets/tiles/yongchang/architecture_atlas_ai_v1.png`, 256×192 RGBA, matching `game/data/yongchang_tiles.json` architecture atlas dimensions and row-major tile-name order.
- The processing script crops the generated cells, thresholds alpha below 128, and resizes each crop to 32×32 using nearest-neighbor sampling. It keeps the existing `wood_railing_vertical` tile because the generated cell fails the bridge-edge coverage contract. It does not draw, repair, or repaint art.
- Processing source: `qa_architecture_atlas_v1.py`.

## Results

- All 48 runtime cells are non-empty. Forty-seven use generated art; `wood_railing_vertical` is copied from the prior project atlas to preserve its north/south bridge seam. No opaque content reaches the generated source-cell boundary.
- `asset_report.py --expect-size 256x192 --require-alpha` passed. The derived atlas contains 13,639 colors, so its palette is not locked to the project's small palette.
- The atlas is loaded by `game/data/yongchang_tiles.json` and rendered through the existing `MapRenderer` architecture layer. An in-game 1920×1080 capture was inspected at `/tmp/yongchang-architecture-qa/map_ai_v1_gameplay.png`.
- Contact sheet: `/tmp/yongchang-architecture-qa/architecture_atlas_contact.png`.
- 3×3 repeat contact: `/tmp/yongchang-architecture-qa/architecture_3x3_seam_contact.png`.
- Machine report with all cell bounds and edge comparisons: `/tmp/yongchang-architecture-qa/architecture_atlas_model_v1_report.json`.

| Repeated tile | Horizontal edge mismatches (>32 max-channel delta) | Vertical edge mismatches (>32 max-channel delta) | Visual/readability note |
|---|---:|---:|---|
| `stone_wall_a` | 1/32 | 0/32 | Stone pattern repeats cleanly; texture repetition is visible over 3×3. |
| `stone_wall_moss` | 1/32 | 0/32 | Edges align; moss placement repeats obviously. |
| `wall_water_base` | 15/32 | 0/32 | Do not repeat horizontally as a seamless shoreline; use along vertical runs only. |
| `roof_slope` | 4/32 | 1/32 | Minor joins show at some repeated edges; use as roof fill, not a seamless surface claim. |
| `roof_slope_b` | 1/32 | 0/32 | Best repeated roof-fill candidate; regular 3×3 repetition still visible. |
| `hall_roof_slope` | 1/32 | 3/32 | Small edge differences remain; keep within a single building roof patch. |

Edge comparisons can under-report visible joins because the sprites have transparent outlines/margins. The 3×3 image was visually inspected at 4× nearest-neighbor scale. This is a modular architecture atlas, not a general-purpose seamless terrain texture.

## Existing map renderer fit

The order of all 48 cells exactly follows `game/data/yongchang_tiles.json`; the map renderer's tile names and atlas coordinates are unchanged. Use the new atlas with these constraints:

- Walls: `stone_wall_a`, `stone_wall_b`, `stone_wall_moss`; use `wall_cap`, `merlon`, and `wall_corner` only at their current wall/tower boundaries.
- House roofs: keep each footprint's current `roof_slope*`, `roof_ridge`, `roof_eave*`, `roof_verge*`, `roof_hip_*`, and `gable_*` assembly together. Do not tile roof-edge pieces as generic fill.
- Gates: preserve the current left/arch/right triplets for land and water gates.
- Canal: use `wall_water_base` on its low-mismatch vertical edge only; inspect water highlights before horizontal reuse.
- `red_lantern`, doors, storefront, rails, and steps are isolated architectural overlays, not repeat textures.

## Limits

- Terrain, props and animated props still use their existing atlas sources; only architecture uses the generated atlas.
- Palette count remains high and some source edges have soft alpha; the processing script removes only alpha below 128.
- The 3×3 checks cover representative repeats, not every terrain neighbor combination. The runtime map screenshot confirms placement, but does not remove the listed seam limitations.
