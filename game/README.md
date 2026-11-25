# game/ — Godot 工程

状态（2026-11-25）：v0.1.1 表现与音频确权基线。序章 1386、正篇 1559、王陆 6 种守夜阵位、
3 张地图、7 兵器/12 被动、16 分钟完整胜利流程、双堡图鉴、结算解锁、灯火风险收益、
龙鳞清屏、Boss 与双语定时字幕已接入；未核实输出授权的 MOSS-TTS-Nano 语音已停止分发。
三选一卡池扩至 51 属性 / 38 技能 / 22 事件 / 32 箭塔，共 143 张来源可追溯的卡牌，并接入 101 个
game-icons.net SVG。

引擎版本锁定为 **Godot 4.7.2-stable**。唯一版本源是仓库根 `.env` 的
`GODOT_VERSION`；`game/.godot-version`、`project.godot` 与导出预设由
`bun run env:sync` 生成。启动器、CI 与 GUT 读取/校验生成后的
`.godot-version`；升级引擎必须先改 `.env`，同步后重跑全平台测试。

新玩法：Vampire Survivors-like 割草生存 Roguelite，16 分钟单局。
设计稿与内部数值表只在本地保留，不随公开仓库分发。

## 已实现

- `scenes/main_menu.tscn`：夜城望楼主菜单，开始/继续游戏、设置、关于、语言、退出。
- `scenes/about.tscn`：电影滚幕式关于页；自动上滚，滚轮/方向键接管，
  专用 CC BY 3.0 BGM；来源与许可链接直接内嵌在音乐、音效、字体、图标、工具与文化参考条目。
- 设置层：BGM/音效滑杆、全屏开关、帧率/VSync、中英语言与 Vulkan/OpenGL
  渲染后端选择；渲染变更需重启，菜单内提供“立即重启”提示。渲染模式会额外写入
  ASCII 镜像配置，供 Linux 与 Windows 启动器读取。
- `scripts/autoload/`：`GameSettings`、`ProjectMeta`、`Locale`、`SaveSystem`、`AudioBus`。
- 项目元数据：根 `.env` 同步生成 `data/project_meta.json`；关于页从 `ProjectMeta`
  显示版本、作者、邮箱、开源仓库与在线游玩链接。
- Web 退出：检测 `OS.has_feature("web")`，先尝试关闭标签页并聚焦 opener；
  浏览器阻止关闭时显示可重新载入、打开项目主页或返回主菜单的提示层，不调用无效
  的原生 `quit()`。
- 自动存档：菜单、设置变化、开局、退出与每 20 秒写入 `user://savegame.json`。
- 双语：`data/i18n/zh.json` 与 `en.json`，切换后即时刷新界面。
- 菜单 BGM：`assets/audio/bgm_watch.ogg`，
  **Samurai Nights · Maik Hoffmann (Majadroid) · CC BY 4.0**。
  来源 https://opengameart.org/content/samurai-nights；原 Demo MP3 转码为 OGG。
- 战斗 BGM：`assets/audio/bgm_battle.ogg`，**Hard Battle 1 · MintoDog · CC0 1.0**；
  进入正篇时切换，返回菜单恢复 `bgm_watch.ogg`。
- 音效：全局按钮点击、确认与返回，以及经验/灯油/治疗/龙鳞拾取、事件卡、敌兵受击、
  普通/精英击杀、升级、冲刺与 Boss 提示；OpenGameArt 多作者与 Kenney UI Audio /
  Impact Sounds，共 18 个运行时 SFX，全部 **CC0 1.0**。
- 关于页 BGM：`assets/audio/bgm_about.ogg`，
  **Views From Atop the Jade Kings Throne · Hitctrl · CC BY 3.0**；
  来源 https://opengameart.org/content/views-from-atop-the-jade-kings-throne；
  原始 OGG，循环播放。
- 默认 BGM 音量：**0.42**（`GameSettings.DEFAULT_BGM_VOLUME`）。已有存档中的用户设置仍被尊重；
  关于页音量为全局 BGM 的 90%。
- `scenes/prologue.tscn`：1386 宁村所序章，操作汤和点望海灯、定界桩、立乡兵旗。
- `scenes/character_select.tscn`：1559 王陆的六种守夜阵位与三张地图；
  阵位用累计军功解锁，选择持久化。
- `scenes/run.tscn`：1559 永昌堡十六分钟割草生存；单一主角王陆，
  手动/自动攻击、7 兵器（5 件可进化）、升级三选一、灯火/灯油、五色龙鳞、
  回复/复活、Boss 退兵与天亮结算；结算页显示本局解锁的阵位/地图，
  可直接打开双堡图鉴。升级卡分为属性、技能、事件三族，另有兵器升级/新兵器、
  被动与补给；卡面显示品第、阶数、效果、堡志文化说明、来源分类与出处。
  143 张 authored cards 按 `max_level` 展开后共 580 个卡阶条目；兵器、被动、进化与补给
  选项另行生成。卡阶规模超过 Brotato 的 64 个 level-up upgrades 与 VS base game 的被动规模。
- `scenes/codex.tscn`：双堡图鉴；左栏宁村所/汤和，中栏王德移师宁村，
  右栏永昌堡/王叔杲，附时间轴、来源与“不可误写”边界。
- 剧情：`data/narrative.json` 与 `data/voice_lines.json` 保留完整双语字幕、说话人、
  叙事分类与 `source_ref`。MOSS 官方 Apache-2.0 代码/模型许可未明确覆盖生成音频输出，
  因此 18 个 OGG 已删除，`audio_enabled=false`、`distribution=subtitles_only`；
  `VoiceLinePlayer` 按约 4.35 音节/秒提供定时字幕回退；生成器与模型权重均不随仓库分发。
- 历史边界：1386 汤和只做序章；1559 正篇始终是虚构守灯乡勇王陆，
  六张选择卡是兵器/站法阵位，不是六名独立人物。王沛、王德只作前史。
- 主菜单与开局页：接入 game-icons.net 的灯火、望楼、藤牌、百家宴、图鉴与
  八项首夜军备图标；卡池另接入算盘、莲灯、龙首、药囊、纺车、潮月等 SVG。
  合计 101 个 game-icons.net 图标，全部登记作者、CC BY 3.0 许可与可点击来源；
  白色 SVG 在运行时按卡族和品第调制。
- 战斗框架：在自动兵器之外加入齐射、灯火爆发、迟滞、灼烧、震晕、连锁、
  回复、收魂、护盾、反伤、饮血与灯影步等可叠加主动技法；敌人可被减速、
  灼烧与眩晕，经验/灯油/药包/龙鳞可被“收魂”全场牵引。

## 运行

Linux / macOS：

```bash
./game/launch.sh
```

Windows：

```bat
game\launch.bat
```

启动器优先读取渲染镜像配置，Unix 端再回退到 `user://settings.cfg`：

- Windows：`%APPDATA%\WatchYongchang\renderer.cfg`
- Linux：`$XDG_CONFIG_HOME/watch-yongchang/renderer.cfg` 或 `~/.config/watch-yongchang/renderer.cfg`
- macOS：`~/Library/Application Support/WatchYongchang/renderer.cfg`

镜像与用户设置支持：

- `auto`（默认）：检测到 Vulkan 时用 `forward_plus + vulkan`，否则回退 `gl_compatibility + opengl3`。
- `vulkan`：优先 Vulkan；不可用时回退 OpenGL。
- `opengl`：强制 OpenGL Compatibility。

临时指定后端可用 `WATCH_RENDERER=vulkan ./game/launch.sh`，Windows
可用 `set WATCH_RENDERER=vulkan && game\launch.bat`。
`launch.bat` 使用纯批处理，不依赖 PowerShell。
启动器会读取 `game/.godot-version` 并拒绝补丁版本不匹配的 Godot；
仅本地临时排查时可设置 `WATCH_SKIP_GODOT_VERSION_CHECK=1` 跳过。
直接运行 `"$GDA_GODOT" --path game` 时项目文件仍以 OpenGL 兜底；设置页会提示重启应用所选后端。

主菜单键盘操作：`↑↓` 选择，`Enter` 确认，`Esc` 关闭设置。

游戏内操作：

- `W/A/S/D` 或方向键：巡灯步，八向移动；沿堡墙、水门与街巷走位，灯火越亮，
  拾取与暴击越高，但敌人也更早发现你
- 鼠标左键长按：持续攻击；快速单点也会在 0.18 秒缓冲内攻击一次
- `X`：开关自动攻击；自动模式优先瞄准最近的存活敌人
- `Space`：灯影步，短距离冲刺（3 秒冷却，短无敌，带残影）
- `1/2/3` 或方向键 + `Enter`：升级三选一（出现后 1 秒内禁止选择）
- `Esc`：暂停
- `C`：打开双堡图鉴

触屏设备自动显示左下“巡灯”虚拟摇杆与右下“灯影步”按键；卡牌可直接点选，
暂停、图鉴与结算按钮均为触屏可点击尺寸。

## 测试

- GUT 9.7.1（MIT），位于 `addons/gut/`，固定对应 `game/.godot-version`
  锁定的 Godot 4.7.2-stable。
- 运行全部单元测试：
  `"$GDA_GODOT" --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- 当前覆盖：工程基线、双语表一致性、存档往返、自动存档、设置持久化、
  BGM 循环与音量、菜单构建/设置层、语言热切换、Vulkan/OpenGL 自动选择、渲染镜像与重启参数、
  关于页自动滚幕/滚轮接管/来源与许可链接、玩法数据完整性、波次到 Boss/黎明、
  空间哈希伤害与经验掉落、叙事分类与来源、双堡图鉴边界、MOSS 语音关闭与字幕时长回退、
  3 首开放许可 BGM（CC BY 4.0 / CC BY 3.0 / CC0）与 18 个 CC0 SFX 的完整署名覆盖、王陆六阵位与解锁、3 地图修正、局内图鉴暂停/返回、经验曲线、
  角色图集与瓦片图集、143 张卡的双语/来源/图标完整性、149+ 条目规模、
  三选一唯一性、减速/灼烧/眩晕/收魂、选项卡渲染、事件结算、
  触屏巡灯语言、敌兵组合配方与批渲染方向、引擎补丁版本与 `.godot-version` 一致性。
- 最近一次 Linux 基线：**174 tests / 174 passed / 50418 asserts**（Godot 4.7.2-stable）。
  Windows 原生 GUT 与启动器 smoke test 仍由 CI 复验。
- 敌兵外观由 `game/data/enemies.json` 的 `character_recipe` 驱动，
  `pixel-art/character_forge/bake_battle_sprites.py` 从裸体基底、服装、头饰、
  背挂、主副手图集烘焙 8 帧行走条；战斗仍按 MultiMesh 批次绘制。
- 王陆六个守夜阵位与序章汤和同样使用 `characters.json` 的 `character_recipe`，
  分别烘焙 4 帧待机与 8 帧行走条；战斗、选择页头像和序章都不再绘制旧
  `static.png` 角色，旧兵种目录已删除。
- 16 分钟无头平衡跑测入口：`tests/balance/balance_bot.gd`；运行日志属于本地临时产物，
  不随公开仓库分发。
- CI 使用 `ubuntu-latest` 与原生 `windows-latest` 两套 GUT；Windows 任务直接运行
  Godot win64，不使用 Wine。本地 Wine 11 + Godot 4.7.2-stable 仅作额外预检，
  已验证 `auto`、`opengl` 与镜像配置读取。
- 数据与平衡模拟走 Bun + TypeScript，不启动引擎。
- 版本与元数据漂移检查：`bun run verify:env`。

## 截图

验收截图属于本地临时产物，不随仓库分发。需要时用 `gda` 现场生成，
统一放到 `docs/screenshots/`（已在 `.gitignore` 中忽略）；文档只保留文字验收结论。
已完成的视觉验收范围：主菜单（中/英）、设置、关于页滚幕、图鉴、选择页、
序章、正篇战斗与三选一升级帧、触屏控制、结算画面。

## 资产

- `assets/units/forge/`：CharacterForge 烘焙的正式角色/敌兵条带；
  旧 11 组 64×64 兵种序列已删除，不得复用。
- `assets/ui/`、`assets/audio/`、`assets/fonts/`：已登记素材。
- `assets/icons/game_icons/`：101 个 game-icons.net SVG，CC BY 3.0；
  逐项作者与来源见 `ATTRIBUTION.md`，完整许可见 `LICENSE-CC-BY-3.0.txt`。
- BGM、音效与字体署名数据在 `data/credits.json`；音频逐文件 TASL（作者、来源、许可链接、
  用途、修改与 BGM 哈希）见 `assets/audio/LICENSES.md`。运行时 BGM 为 CC BY 4.0、CC BY 3.0 与 CC0 1.0 各一首；18 个 SFX 全部为 CC0 1.0。
- 文化背景与赛事创作方向来源：
  [2026 OSGJ 开源游戏开发大赛官网](https://2026gamejam.osgame.org/)。
- 新像素素材用 `skills/pixel-art-studio/` 生成，源文件放 `../pixel-art/<slug>/build.py`。

## 许可范围

- **项目代码：AGPL-3.0-or-later**。全文见 `LICENSE`；对应源码与网络使用义务、代码/资产边界见 `NOTICE`。
- **原创非代码资产：CC BY 4.0**。全文见 `LICENSE-CC-BY-4.0.txt`；明确标识的原创菜单/关于页 BGM
  与根目录开发音效母版可选 CC0 1.0 或 CC BY 4.0，既有 CC0 奉献保留。
- **第三方资产保留原许可**：音频 CC0、game-icons.net CC BY 3.0、字体 OFL 1.1、Jeff-FX-forge
  代码 MIT / 原创特效 CC0，其余工具按各自许可。逐项清单见上级仓库 `素材授权清单.csv`，
  每行包含 `source_url`、`license_url` 与 `rights_status`。
- 根目录三份法律文件在 `game/` 内有逐字节副本，四个平台导出预设显式包含法律文本、音频 TASL、
  图标署名与字体/特效许可。MOSS 语音输出授权未核实，已从运行时删除，仅保留字幕回退。

## 导出

四平台预设已写入 `export_presets.cfg`。2026-11-23 的旧忽略产物早于音频/许可整改，
在重新导出与复查前不得分发。当前版本为 `0.1.1`；重建与审计结果记录在
GitHub Actions 的 `release.yml` 构建报告中。GitHub Release 只由 `v*.*.*` 标签触发
`.github/workflows/release.yml` 生成。
历史验收记录：

- Linux：`build/linux/watch-yongchang.x86_64` + `.pck`；`gda export smoke`
  `--quit-after 3 --strict` 通过，`exit_status=0`。
- Windows：`build/windows/watch-yongchang.exe` + `.pck`；本地 Wine
  `--headless --quit-after 3` 预检通过，原生 Windows CI 仍需复验。
- macOS：`build/macos/watch-yongchang.zip`，内含 `守望·永昌.app`；本机无法运行
  macOS 产物，需在 macOS 上做启动验收。

导出模板已安装到 `~/.local/share/godot/export_templates/4.7.2.stable/`。
构建产物在 `game/build/`，已被 `.gitignore` 排除，不入版本库。

### Dora SSR 源码包

仓库根目录提供最小 `GodotNode` 适配入口与无 Godot 构建器：

```bash
python3 dora/build.py --check
python3 dora/build.py
```

源码 ZIP 输出到 `artifacts/watch-yongchang-dora.zip`。安装依赖、Web IDE / Go Mode /
CLI 运行方式、可选 PCK 流程、平台运行库与许可范围见 `../DORA.md`。
当前只做静态和包结构验证，尚未进行真实 Dora 运行时验收；该 ZIP 不进入 GitHub Release。

## 下一步

1. 补 Windows 原生 GUT 与启动器 smoke test，确认新增 M3 内容跨平台。
2. 在正常唤醒的原生桌面复测 400–460 敌人；当前已把压力场景 draw calls 从 930 降到 14，
   但本机会话被显示器/合成器限到约 1 帧/秒，绝对 FPS 仍需实机复测。
3. 在原生 Windows 与 macOS 上跑构建启动 smoke test；Windows 任务仍以 CI 为准。
4. 继续平衡进化节奏、灯油压力、Boss 血量与敌人上限。
