# game/ — Godot 工程

状态（2026-11-23）：v0.4 · M3 表现基线。序章 1386、正篇 1559、王陆 6 种守夜阵位、
3 张地图、8 兵器/12 被动、16 分钟完整胜利流程、双堡图鉴、结算解锁、灯火风险收益、
龙鳞清屏、Boss、剧情字幕与 MOSS-TTS-Nano 语音已接入；三选一卡池扩至
50 属性 / 38 技能 / 22 事件，共 110 张来源可追溯的文化卡，并接入 65 个
game-icons.net SVG。

引擎版本锁定为 **Godot 4.7.2-stable**，唯一来源 `game/.godot-version`。
启动器、CI 与 GUT 都读取/校验该文件；升级引擎必须先改此文件并重跑全平台测试。

新玩法：Vampire Survivors-like 割草生存 Roguelite，16 分钟单局。
设计源：`../design/游戏设计文档-GDD.md`。

## 已实现

- `scenes/main_menu.tscn`：夜城望楼主菜单，开始/继续游戏、设置、关于、语言、退出。
- `scenes/about.tscn`：电影滚幕式关于页；自动上滚，滚轮/方向键接管，
  专用 BGM；来源链接直接内嵌在致谢、音乐、字体、工具与文化参考条目。
- 设置层：BGM/音效滑杆、全屏开关、帧率/VSync、中英语言与 Vulkan/OpenGL
  渲染后端选择；渲染变更需重启，菜单内提供“立即重启”提示。渲染模式会额外写入
  ASCII 镜像配置，供 Linux 与 Windows 启动器读取。
- `scripts/autoload/`：`GameSettings`、`Locale`、`SaveSystem`、`AudioBus`。
- 自动存档：菜单、设置变化、开局、退出与每 20 秒写入 `user://savegame.json`。
- 双语：`data/i18n/zh.json` 与 `en.json`，切换后即时刷新界面。
- BGM：`assets/audio/bgm_watch.ogg`，**Samurai Nights · majadroid · CC-BY 3.0**。
- 战斗 BGM：`assets/audio/bgm_battle.ogg`，**Hard Battle 1 · MintoDog · CC0 1.0**；
  进入正篇时切换，返回菜单恢复 `bgm_watch.ogg`。
- 音效：全局按钮点击、确认与返回，以及经验/灯油/治疗/龙鳞拾取、事件卡、敌兵受击、
  普通/精英击杀、升级、冲刺与 Boss 提示；Kenney UI Audio / Impact Sounds · CC0 1.0。
- 关于页 BGM：`assets/audio/bgm_about.ogg`，
  **Views From Atop the Jade Kings Throne · Hitctrl · CC-BY 3.0**。
- `scenes/prologue.tscn`：1386 宁村所序章，操作汤和点望海灯、定界桩、立乡兵旗。
- `scenes/character_select.tscn`：1559 王陆的六种守夜阵位与三张地图；
  阵位用累计军功解锁，选择持久化。
- `scenes/run.tscn`：1559 永昌堡十六分钟割草生存；单一主角王陆，
  自动攻击、8 兵器（6 件可进化）、升级三选一、灯火/灯油、五色龙鳞、
  回复/复活、Boss 退兵与天亮结算；结算页显示本局解锁的阵位/地图，
  可直接打开双堡图鉴。升级卡分为属性、技能、事件三族，另有兵器升级/新兵器、
  被动与补给；卡面显示品第、阶数、效果、堡志文化说明、来源分类与出处。
  运行期展示池实测 546 项，可重复升级条目 452 个，超过 Brotato 的 64 个
  level-up upgrades 与 VS base game 的被动规模。
- `scenes/codex.tscn`：双堡图鉴；左栏宁村所/汤和，中栏王德移师宁村，
  右栏永昌堡/王叔杲，附时间轴、来源与“不可误写”边界。
- 剧情：`data/narrative.json`；中英语音 `data/voice_lines.json` 与
  `assets/audio/voice/*.ogg`；生成脚本 `../scripts/generate_voice.ts`。
- 历史边界：1386 汤和只做序章；1559 正篇始终是虚构守灯乡勇王陆，
  六张选择卡是兵器/站法阵位，不是六名独立人物。王沛、王德只作前史。
- 主菜单与开局页：接入 game-icons.net 的灯火、望楼、藤牌、百家宴、图鉴与
  八项首夜军备图标；卡池另接入算盘、莲灯、龙首、药囊、纺车、潮月等 53 个
  SVG。合计 65 个 game-icons.net 图标，全部登记作者、许可与可点击来源；
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
- `Space`：灯影步，短距离冲刺（3 秒冷却，短无敌，带残影）
- `1/2/3` 或方向键 + `Enter`：升级三选一
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
  关于页自动滚幕/滚轮接管/来源链接、玩法数据完整性、波次到 Boss/黎明、
  空间哈希伤害与经验掉落、叙事分类与来源、双堡图鉴边界、语音资源存在性、
  王陆六阵位与解锁、3 地图修正、局内图鉴暂停/返回、经验曲线、
  角色图集与瓦片图集、110 张卡的双语/来源/图标完整性、149+ 条目规模、
  三选一唯一性、减速/灼烧/眩晕/收魂、选项卡渲染、事件结算、
  触屏巡灯语言、敌兵组合配方与批渲染方向、引擎补丁版本与 `.godot-version` 一致性。
- 当前 Linux 结果：**72 tests / 72 passed / 21446 asserts**。
- 敌兵外观由 `game/data/enemies.json` 的 `character_recipe` 驱动，
  `pixel-art/character_forge/bake_battle_sprites.py` 从裸体基底、服装、头饰、
  背挂、主副手图集烘焙 8 帧行走条；战斗仍按 MultiMesh 批次绘制。
- 王陆六个守夜阵位与序章汤和同样使用 `characters.json` 的 `character_recipe`，
  分别烘焙 4 帧待机与 8 帧行走条；战斗、选择页头像和序章都不再绘制旧
  `static.png` 角色，旧兵种目录已删除。
- 16 分钟无头平衡跑测：`tests/balance/balance_bot.gd`，日志见
  `../docs/balance_2026-11-23.log`。
- CI 使用 `ubuntu-latest` 与原生 `windows-latest` 两套 GUT；Windows 任务直接运行
  Godot win64，不使用 Wine。本地 Wine 11 + Godot 4.7.2-stable 仅作额外预检，
  已验证 `auto`、`opengl` 与镜像配置读取。
- 数据与平衡模拟走 Bun + TypeScript，不启动引擎。

## 截图

验收截图属于本地临时产物，不随仓库分发。需要时用 `gda` 现场生成，
统一放到 `docs/screenshots/`（已在 `.gitignore` 中忽略）；文档只保留文字验收结论。
已完成的视觉验收范围：主菜单（中/英）、设置、关于页滚幕、图鉴、选择页、
序章、正篇战斗与三选一升级帧、触屏控制、结算画面。

## 资产

- `assets/units/forge/`：CharacterForge 烘焙的正式角色/敌兵条带；
  旧 11 组 64×64 兵种序列已删除，不得复用。
- `assets/tiles/dcss/`：CC0 地形图块 106 张。
- `assets/ui/`、`assets/audio/`、`assets/fonts/`：已登记素材。
- `assets/icons/game_icons/`：12 个 game-icons.net SVG，CC BY 3.0；
  逐项作者与来源见 `ATTRIBUTION.md`，完整许可见 `LICENSE-CC-BY-3.0.txt`。
- BGM、音效与字体署名数据在 `data/credits.json`；音频逐文件映射见
  `assets/audio/LICENSES.md`。
- 文化背景与赛事创作方向来源：
  [2026 OSGJ 开源游戏开发大赛官网](https://2026gamejam.osgame.org/)。
- 新像素素材用 `skills/pixel-art-studio/` 生成，源文件放 `../pixel-art/<slug>/build.py`。

## 导出

三平台预设已写入 `export_presets.cfg`，并已实际导出构建：

- Linux：`build/linux/watch-yongchang.x86_64` + `.pck`；`gda export smoke`
  `--quit-after 3 --strict` 通过，`exit_status=0`。
- Windows：`build/windows/watch-yongchang.exe` + `.pck`；本地 Wine
  `--headless --quit-after 3` 预检通过，原生 Windows CI 仍需复验。
- macOS：`build/macos/watch-yongchang.zip`，内含 `守望·永昌.app`；本机无法运行
  macOS 产物，需在 macOS 上做启动验收。

导出模板已安装到 `~/.local/share/godot/export_templates/4.7.2.stable/`。
构建产物在 `game/build/`，已被 `.gitignore` 排除，不入版本库。
产物清单、哈希与 smoke 记录见 `../docs/build_2026-11-23.md`。

## 下一步

1. 补 Windows 原生 GUT 与启动器 smoke test，确认新增 M3 内容跨平台。
2. 在正常唤醒的原生桌面复测 400–460 敌人；当前已把压力场景 draw calls 从 930 降到 14，
   但本机会话被显示器/合成器限到约 1 帧/秒，绝对 FPS 仍需实机复测。详见
   `../docs/perf_2026-11-23.md`。
3. 在原生 Windows 与 macOS 上跑构建启动 smoke test；Windows 任务仍以 CI 为准。
4. 继续平衡进化节奏、灯油压力、Boss 血量与敌人上限。
