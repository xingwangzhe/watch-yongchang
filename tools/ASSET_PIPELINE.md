# Runtime asset pipeline

The game uses generated runtime derivatives so development source files never
need to be shipped unchanged.

## Commands

```bash
bun install --frozen-lockfile
bun run assets:font
bun run assets:images
bun run assets:check
```

`assets:font` scans runtime scripts, scenes, data and `.env` values, then
subsets the full LXGW WenKai WOFF2 source to the reachable character set. The
full source lives in `tools/fonts/` and is intentionally outside `game/`.

`assets:images` writes lossless WebP next to each runtime PNG; `panel_dark.png`
uses near-lossless WebP quality 92 because it is a large UI texture. Pixel-art
sprites and atlases stay lossless. `--check` re-encodes in memory and compares
the bytes with the committed WebP, so a stale derivative fails CI. The original
PNG files remain the editable source and are excluded from export.

The generated runtime derivatives are recorded at group level in
`素材授权清单.csv`; their per-file source and license rows remain the PNG rows.

Neither command modifies map tile atlases or the application icon.
