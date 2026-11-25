# Audio licenses and TASL / 音频许可与逐文件溯源

Last verified: 2026-11-25. This is the complete rights manifest for audio shipped
in `game/assets/audio/`. All three runtime BGM tracks and all 20 SFX use open
licenses that permit redistribution: CC BY 4.0, CC BY 3.0, or CC0 1.0. Project
originals retained only as source masters keep their existing CC0 / CC BY 4.0
terms.

CC0 1.0 Universal: https://creativecommons.org/publicdomain/zero/1.0/
CC BY 4.0: https://creativecommons.org/licenses/by/4.0/
CC BY 3.0: https://creativecommons.org/licenses/by/3.0/

## Runtime BGM / 运行时背景音乐

### Samurai Nights

- Title: Samurai Nights
- Author: Maik Hoffmann (Majadroid)
- Source: https://opengameart.org/content/samurai-nights
- Original file: `samurai-nights-demo_majadroid_CC-BY.mp3`
- Runtime file: `game/assets/audio/bgm_watch.ogg`
- License: CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
- Use: main menu, character select, and pre-run scenes; looped in game.
- Changes: original demo MP3 re-encoded to Ogg Vorbis; audio content unchanged.
- SHA-256: `5351dd48614a513cd805dc10e9aefcd6690868d9f0c5b31a5aabc9fedeefa25a`
- Rights note: the official page also offers CC BY 3.0 and OGA-BY 3.0; this
  project elects CC BY 4.0. No samples or edits beyond container re-encoding.

### Views From Atop the Jade Kings Throne

- Title: Views From Atop the Jade Kings Throne
- Author: Hitctrl
- Source: https://opengameart.org/content/views-from-atop-the-jade-kings-throne
- Runtime file: `game/assets/audio/bgm_about.ogg`
- License: CC BY 3.0, https://creativecommons.org/licenses/by/3.0/
- Use: about-page credits music; looped in game.
- Changes: original OGG data retained; no audio-data modification.
- SHA-256: `21af784efac14e8a168ee1992cb002b521172a2ff39dc68ab603218c215d6335`

### Hard Battle 1

- Title: Hard Battle 1
- Author: MintoDog
- Source: https://opengameart.org/content/hard-battle-1
- Original file: `hard_battle_1_bpm170_0.ogg`
- Runtime file: `game/assets/audio/bgm_battle.ogg`
- License: CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/
- Use: 1559 combat BGM; looped in game.
- Changes: original OGG data retained; no audio-data modification.
- SHA-256: `f26e56b12a10811403dfb1ae3c23a9af4ec0721fcbdb17001b2888917efdd36e`

## Shipped SFX / 成品音效

All rows below are CC0 1.0:
https://creativecommons.org/publicdomain/zero/1.0/

### OpenGameArt sources

| Runtime file | Original work / selected sound | Author | Source | Use and changes |
|---|---|---|---|---|
| `sfx_fire.ogg` | Battle Sound Effects: Bow | ogrebane | https://opengameart.org/content/battle-sound-effects | Tower/ranged attack; loudness normalized and re-encoded to Ogg. |
| `sfx_hit.ogg` | 3 Melee Sounds | remaxim | https://opengameart.org/content/3-melee-sounds | Unit hit; loudness normalized and re-encoded to Ogg. |
| `sfx_build.ogg` | RPG Audio: Chop | Kenney | https://opengameart.org/content/50-rpg-sound-effects | Build complete; loudness normalized. |
| `sfx_spawn.ogg` | RPG Sound Pack: Sword Unsheath | artisticdude | https://opengameart.org/content/rpg-sound-pack | Unit spawn; loudness normalized and re-encoded to Ogg. |
| `sfx_wave.ogg` | Sound Pack 01: Rise01 | wobbleboxx | https://opengameart.org/content/level-up-power-up-coin-get-13-sounds | Wave start; AIF source converted to Ogg and loudness normalized. |
| `sfx_alarm.ogg` | Sound Pack 01: Alarm | wobbleboxx | https://opengameart.org/content/level-up-power-up-coin-get-13-sounds | Fort alarm; shortened to 2.2 s, faded, loudness normalized, and re-encoded. |
| `sfx_merge.ogg` | RPG Sound Pack: Metal Ringing | artisticdude | https://opengameart.org/content/rpg-sound-pack | Workshop merge; loudness normalized and re-encoded to Ogg. |
| `sfx_win.ogg` | Sound Pack 01: Upper01 | wobbleboxx | https://opengameart.org/content/level-up-power-up-coin-get-13-sounds | Victory; AIF source converted to Ogg and loudness normalized. |
| `sfx_lose.ogg` | Sound Pack 01: Downer01 | wobbleboxx | https://opengameart.org/content/level-up-power-up-coin-get-13-sounds | Defeat; AIF source converted to Ogg and loudness normalized. |

### Kenney UI Audio

- Pack: UI Audio
- Author: Kenney Vleugels (Kenney)
- Source: https://kenney.nl/assets/ui-audio
- License: CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/

| Runtime file | Original file | Use and changes |
|---|---|---|
| `ui_click.ogg` | `click2.ogg` | Global click; original OGG data retained. |
| `ui_confirm.ogg` | `switch3.ogg` | Confirm/upgrade selection; original OGG data retained. |
| `ui_back.ogg` | `click4.ogg` | Back/close; original OGG data retained. |
| `sfx_pickup.ogg` | `switch1.ogg` | Pickups; original OGG data retained, pitch varied in game. |
| `sfx_event.ogg` | `switch9.ogg` | Event cues; original OGG data retained, pitch varied in game. |

### Kenney Impact Sounds

- Pack: Impact Sounds
- Author: Kenney
- Source: https://kenney.nl/assets/impact-sounds
- License: CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/

| Runtime file | Original file | Use and changes |
|---|---|---|
| `sfx_enemy_hit.ogg` | `impactSoft_medium_001.ogg` | Enemy hit; original OGG data retained, pitch varied/throttled in game. |
| `sfx_enemy_kill.ogg` | `impactPunch_medium_002.ogg` | Normal kill; original OGG data retained, pitch varied/throttled in game. |
| `sfx_elite_kill.ogg` | `impactPlate_medium_002.ogg` | Elite/Boss kill; original OGG data retained, pitch varied in game. |
| `sfx_level_up.ogg` | `impactBell_heavy_002.ogg` | Level-up cue; original OGG data retained, pitch varied in game. |
| `sfx_dash.ogg` | `impactGeneric_light_001.ogg` | Dash; original OGG data retained, pitch varied in game. |
| `sfx_boss.ogg` | `impactMetal_heavy_003.ogg` | Boss appearance; original OGG data retained, pitch varied in game. |

## Repository-only original audio sources / 仅源码仓库保留

`assets/audio/bgm_watch.ogg` is the project's original 45.6-second menu cue.
It was removed from the runtime on 2026-11-25 when the licensed OpenGameArt menu
track was restored; it is not an alias for the current runtime BGM. Author:
xingwangzhe. License: CC0 1.0. Reproducible source:
`tools/generate_audio.py --legacy`.

`tools/generate_audio.py` still generates the project-original 72-second
`bgm_about.ogg` cue under `assets/audio/` by default. It does not overwrite the
third-party runtime about cue. Author: xingwangzhe. License: CC0 1.0.

`assets/audio/sfx_alarm.ogg`, `sfx_build.ogg`, `sfx_fire.ogg`, `sfx_hit.ogg`,
`sfx_lose.ogg`, `sfx_merge.ogg`, `sfx_spawn.ogg`, `sfx_wave.ogg`, and
`sfx_win.ogg` are the project's original sample-free CC0 synthesis outputs. They
are preserved as development sources, are not runtime aliases for the third-party
SFX above, and are not included in the game export. Author: xingwangzhe. License:
CC0 1.0. Reproducible source: `tools/generate_audio.py --legacy`.

## Removed voice audio / 已移除语音

The former 18 MOSS-TTS-Nano OGG files (nine Chinese and nine English lines) are
not shipped. Official repository/model materials identify Apache-2.0 for code and
model artifacts but do not explicitly state a grant for generated voice recordings.
The project therefore keeps only timed subtitles. Reviewed sources:

- https://github.com/OpenMOSS/MOSS-TTS-Nano
- https://github.com/OpenMOSS/MOSS-TTS-Nano/blob/main/LICENSE
- https://huggingface.co/OpenMOSS-Team/MOSS-TTS-Nano
- https://huggingface.co/OpenMOSS-Team/MOSS-TTS-Nano-100M-ONNX
- https://huggingface.co/OpenMOSS-Team/MOSS-TTS-Nano-100M-ONNX/raw/main/README.md

See `game/data/voice_lines.json` for the explicit `audio_enabled: false` flag and
`AI使用与素材声明.md` for the decision record. `scripts/generate_voice.ts` refuses
to generate distributable voice unless output rights are verified and an explicit
environment opt-in is supplied.

## Rights review / 许可复核

The OpenGameArt source pages were rechecked on 2026-11-25. Samurai Nights offers
CC BY 4.0, CC BY 3.0, and OGA-BY 3.0; Views From Atop the Jade Kings Throne is
CC BY 3.0. Neither license is NC or ND. Both permit redistribution and adaptation
with attribution, so they are acceptable third-party assets under the 2026 OSGJ
rules. Credits and change notes are supplied in the in-game about roll, this
manifest, `素材授权清单.csv`, and `AI使用与素材声明.md`.
