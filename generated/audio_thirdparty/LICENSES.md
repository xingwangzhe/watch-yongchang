# 第三方音频素材许可清单（TASL）

> 本目录存放进入成品的第三方音频原始素材与许可登记。转换脚本：
> `tools/process_thirdparty_audio.py`（输出至 `game/assets/audio/`，文件名与旧合成版一致，代码零改动）。

## 采用的许可策略（用户指定）

- **长音乐（BGM）**：优先寻找 CC0 或免费可商用现成素材，不使用脚本合成。
- **短音效（SFX）**：优先寻找 CC0/免费可商用现成素材；找不到合适音源时才以
  `tools/generate_audio.py` 合成兜底。

## 素材清单

| 成品目标 | 原始文件（raw/） | Title | Author | Source | License | 修改说明 |
|---|---|---|---|---|---|---|
| `bgm_watch.ogg` | samurai-nights-demo_majadroid_CC-BY.mp3 | Samurai Nights (Demo) | Maik Hoffmann (majadroid) | https://opengameart.org/content/samurai-nights | **CC-BY 3.0**（亦提供 CC-BY 4.0 / OGA-BY 3.0） | mp3 → ogg 重编码，其余未修改 |
| `sfx_fire.ogg` | bow_ogrebane_CC0.wav | Battle Sound Effects: Bow | ogrebane | https://opengameart.org/content/battle-sound-effects | CC0（多许可包，本作选用 CC0） | 响度归一化，wav → ogg |
| `sfx_hit.ogg` | melee-sound_remaxim_CC0.wav | 3 Melee Sounds: Melee Sound | remaxim | https://opengameart.org/content/3-melee-sounds | CC0 | 响度归一化，wav → ogg |
| `sfx_build.ogg` | chop_kenney_CC0.ogg | RPG Audio: Chop | Kenney (kenney.nl) | https://opengameart.org/content/50-rpg-sound-effects | CC0 | 响度归一化 |
| `sfx_spawn.ogg` | sword-unsheathe_artisticdude_CC0.wav | RPG Sound Pack: Sword Unsheath | artisticdude | https://opengameart.org/content/rpg-sound-pack | CC0 | 响度归一化，wav → ogg |
| `sfx_wave.ogg` | rise01_wobbleboxx_CC0.aif | Sound Pack 01: Rise01 | wobbleboxx | https://opengameart.org/content/level-up-power-up-coin-get-13-sounds | CC0 | 响度归一化，aif → ogg |
| `sfx_alarm.ogg` | alarm_wobbleboxx_CC0.aif | Sound Pack 01: Alarm | wobbleboxx | 同上 | CC0 | 截短至 2.2s + 淡出，响度归一化 |
| `sfx_merge.ogg` | metal-ringing_artisticdude_CC0.wav | RPG Sound Pack: Metal Ringing | artisticdude | https://opengameart.org/content/rpg-sound-pack | CC0 | 响度归一化，wav → ogg |
| `sfx_win.ogg` | upper01_wobbleboxx_CC0.aif | Sound Pack 01: Upper01 | wobbleboxx | 同上 | CC0 | 响度归一化，aif → ogg |
| `sfx_lose.ogg` | downer01_wobbleboxx_CC0.aif | Sound Pack 01: Downer01 | wobbleboxx | 同上 | CC0 | 响度归一化，aif → ogg |

## 备选素材（暂未进入成品，留作后续切换）

| 原始文件 | Title | Author | Source | License |
|---|---|---|---|---|
| views-from-atop-the-jade-kings-throne_hitctrl_CC-BY.ogg | Views From Atop the Jade Kings Throne | hitctrl | https://opengameart.org/content/views-from-atop-the-jade-kings-throne | CC-BY 3.0 |

## 署名要求（游戏内 About 面板与演示片尾须保留）

> Music: "Samurai Nights" by Maik Hoffmann (majadroid), licensed CC-BY 3.0.
> Source: https://opengameart.org/content/samurai-nights — Changes: re-encoded to Ogg Vorbis.
> Sound effects from OpenGameArt.org, CC0: Bow (ogrebane), Melee Sound (remaxim),
> Chop (Kenney), Sword Unsheath / Metal Ringing (artisticdude),
> Rise01 / Alarm / Upper01 / Downer01 (wobbleboxx).
