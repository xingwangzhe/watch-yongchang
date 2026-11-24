# Jeff-FX-forge attack effects

Runtime attack effects are baked sprite atlases exported from
[Jeff-FX-forge 1.1](https://github.com/jeffstudio-dev/Jeff-FX-forge).

- Tool code: MIT (Jeff Studio, 2026).
- Original plugin FX art: CC0 1.0.
- Project integration: CC BY 4.0 with attribution retained in `credits.json`.
- Atlas metadata, frame rects, pivots, and combination profiles live in
  `game/data/attack_fx.json`.

Included recipes:

`slash_basic`, `slash_fire`, `slash_ice`, `slash_shadow`, `slash_ink`,
`slash_spin`, `thrust`, `hit_basic`, `hit_heavy`, `hit_crit`, `block_sparks`,
`ground_shockwave`, `energy_ring`, `explosion_small`, `explosion_big`,
`explosion_poison`.

Do not hand-edit the exported PNGs. Re-export from the source recipe, update
`attack_fx.json` if frame metadata changes, and keep the license text beside
the atlases.
