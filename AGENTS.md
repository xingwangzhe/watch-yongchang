# AGENTS.md — 项目协作约定

本文件供所有 AI 编码代理（Claude Code / Codex / Cursor / WorkBuddy 等）阅读。
适用法律与素材许可见根目录 `AI使用与素材声明.md`、`素材授权清单.csv`。

## 0. 资产硬规则（角色与敌兵外观，最高优先级）

以下规则优先于所有历史文档、旧截图和旧提交记录。改动角色、敌兵、选择页、
序章或战斗外观前，必须先读本节。

### 唯一允许的正式来源

- 角色与敌兵的正式外观只能由 CharacterForge 配方生成：
  `game/data/character_templates.json` 是部件与动作图集源；
  `pixel-art/character_forge/build.py` 是绘制源；
  `pixel-art/character_forge/bake_battle_sprites.py` 是战斗/序章烘焙入口。
- 配方必须写在 `game/data/characters.json` 或 `game/data/enemies.json` 的
  `character_recipe` 中，至少包含 `faction`、`skin`、`outfit`、`headgear`、
  `backgear`、`weapon`、`offhand`。阵营必须通过
  `CharacterForge.recipe_faction_valid()`，禁止明军/倭寇装备混装。
- 正式运行资产只允许放在 `game/assets/units/forge/`：
  - 敌兵：`res://assets/units/forge/<enemy>/walk.png`，8 帧横向条。
  - 主角：`res://assets/units/forge/players/<id>/idle.png` 与 `walk.png`，
    4 帧待机、8 帧行走。
- 战斗读取 `battle_idle` / `battle_walk` / `texture`（敌兵）字段；
  选择页头像必须取 `battle_idle` 首帧，序章汤和与明军也必须播放烘焙帧。

### 已删除，禁止恢复或引用

- 旧正式兵种目录已删除，包括：
  `xiangyong`、`gongshou`、`longdeng`、`tengpai`、`huochong`、`jinshi`、
  `wokou_scout`、`wokou_gun`、`wokou_ronin`、`wokou_shield`、`wokou_chief`。
- 禁止创建、恢复或引用以下旧路径及其任何副本：
  `res://assets/units/<旧目录>/static.png`、
  `res://assets/units/<旧目录>/run/frame_*.png`、
  `res://assets/units/<旧目录>/attack/frame_*.png`。
- 禁止用 `git checkout`、旧提交、旧截图或回收站恢复这些目录；禁止把它们
  重新加入 `game/assets/`、导出包或 `素材授权清单.csv` 的“已使用”状态。
- 根目录旧副本 `assets/units/` 与 `assets/预览-*.jpg` 同样已删除；根目录
  只保留 `assets/audio/` 与 `assets/fonts/`，不得从旧 README 或旧预览恢复兵种图。
- `characters.json` 禁止重新出现 `texture` 字段；角色只允许
  `battle_idle` / `battle_walk`。缺图时必须显式失败，不得回退旧静态图。
- `game/assets/actors/`、`game/data/actors.json` 与
  `game/scenes/actors_preview.tscn` 仅用于开发预览/图集检查，
  不得作为正式战斗、选择页或序章外观来源。

### 新增或修改角色外观的固定流程

1. 在 `characters.json` / `enemies.json` 写合法 `character_recipe`。
2. 如新增部件或动作，修改 `pixel-art/character_forge/build.py` 并重建图集。
3. 运行 `python3 pixel-art/character_forge/bake_battle_sprites.py` 生成正式条带。
4. 查看 `pixel-art/character_forge/enemy_roster.png` 与 `player_roster.png`
   做视觉自检，禁止手改导出的 PNG。
5. 同步更新 `素材授权清单.csv`、`AI使用与素材声明.md` 与 `credits.json`。
6. 跑完整 GUT；战斗、选择页、序章至少各留一张验收截图。

### 随机组合统计（2026-11-23，以当前图集与配方为准）

当前部件池：`skin 4 × outfit 16 × headgear 14 × backgear 5 × loadout 59`。
其中 `loadout` 指“每把主武器单体姿态 + 单手武器可用的合法副手组合”，
不是武器与任意副手的无条件相乘。

- 原始笛卡尔积：`4 × 16 × 14 × 5 × 59 = 264,320`。
  该数包含明军/倭寇混装与不合规副手，不能当作可运行组合数。
- 正式战斗合法组合（`character_templates.json` 的 `combination_count`，
  仅统计明军与倭寇）：
  - 明军：`4 × 8 × 8 × 4 × 58 = 59,392`
  - 倭寇：`4 × 10 × 8 × 2 × 24 = 15,360`
  - 合计：`59,392 + 15,360 = 74,752`
- `CharacterForge.random_recipe()` 还接受 `neutral` 通用阵营：
  `4 × 2 × 2 × 1 × 23 = 368`。若把三条运行时阵营分支全部计入，
  可抽取组合总数为 `74,752 + 368 = 75,120`。
- 抽取不是对全部组合等概率：外层部件分别均匀抽取；主武器均匀抽取；
  单手武器有 `0.62` 概率再抽取合法副手。修改掉率或部件池后，必须同步
  重算 `combination_count`、`raw_combination_count` 与两阵营计数。

### 提交前资产自检（必须为空）

```bash
rtk rg -n 'static\.png' game/scripts game/data game/scenes
rtk rg -n 'assets/units/(xiangyong|gongshou|longdeng|tengpai|huochong|jinshi|wokou_scout|wokou_gun|wokou_ronin|wokou_shield|wokou_chief)' game/scripts game/data game/scenes
rtk rg -n '"texture"' game/data/characters.json
find game/assets/units -maxdepth 1 -mindepth 1 -type d ! -name forge ! -name towers # towers 是箭塔工事，不是旧兵种
find assets -maxdepth 3 -type f \( -name '*.png' -o -name '预览-*.jpg' \)
```

任一命令有输出即视为回归，禁止提交。随后运行：

```bash
"$GDA_GODOT" --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

## 项目概况

- 名称：《守望 · 永昌》—— 2026 OSGJ 开源游戏开发大赛参赛作品
- 主题：守 · 望（解密结果见 `docs/02-主题资料/theme-payload.decrypted.json`）
- 玩法：**Vampire Survivors-like 割草生存 Roguelite**。16 分钟单局，自动攻击，
  升级三选一，灯火风险收益，文化阵法与龙灯清屏。
- 设计大纲：`design/游戏设计文档-GDD.md`（当前唯一设计源；旧守城 GDD 已删除）
- 状态：M3 表现基线（2026-11-24）。主菜单/设置/双语/自动存档/关于页已完成；
  1386 汤和序章、1559 王陆 16 分钟守夜、王陆 6 种守夜阵位、3 张地图、
  7 兵器/12 被动、双堡图鉴与结算解锁已接入；藤牌只作防具，不作兵器。
  2026-11-24 因生成音频输出授权无法核实，已移除 18 个 MOSS-TTS-Nano 语音
  文件并保留双语字幕回退；不得在权利核实前恢复语音分发。
  角色、敌兵、选择页与序章外观已统一到 `units/forge/`，旧兵种目录已删除。
  3 首 BGM 均为开放许可（Samurai Nights CC BY 4.0、Jade Kings Throne CC BY 3.0、
  Hard Battle 1 CC0），20 个运行时 SFX 均为 CC0；默认 BGM 音量为 `0.42`。
  Linux/Windows/macOS 构建已产出，但 `game/build/` 中 2026-11-23 的旧导出
  仍可能含与当前运行时不同的 BGM 与 MOSS 语音，重新导出并核验前不得分发。
  Linux smoke 已通过；历史 Windows Wine 预检通过，但本次发行版 Wine smoke
  未通过，原生 Windows CI 复验仍待跑。
- 运行时：Godot **4.7.2-stable**；唯一版本源 `game/.godot-version`；工程根 `game/`；
  主场景 `game/scenes/main_menu.tscn`。
- 字体：**全局默认字体固定为霞鹜文楷 / LXGW WenKai（OFL 1.1）**，资产在 `game/assets/fonts/`。
- 许可：**代码 AGPL-3.0-or-later**；原创非代码资产 CC BY 4.0（原创 BGM 母版可另选 CC0）；第三方保留原许可（含 CC BY 4.0 / CC BY 3.0）；字体 OFL 1.1。范围见根 `NOTICE`。

## 目录

```text
design/       新 GDD 与设计文档（旧文档已清空）
docs/         文化资料、主题资料、截图、来源清单（保留）
game/         Godot 工程；scenes/ scripts/ data/ tests/ assets/
  assets/     地形、UI、音频、字体；角色/敌兵外观仅在 units/forge/
skills/       项目内 Agent Skills（必须保留）
assets/       原始音频/字体；旧兵种图与预览已删除
pixel-art/    新像素素材的 build.py 与导出（按需创建）
```

## Pixel Art Studio Skill

- 已安装：`skills/pixel-art-studio/`（MIT，来源 https://github.com/Gamezxz/pixel-art-studio）。
- 依赖：`python3` + Pillow（已装，版本 13.0.0）。
- 新像素素材按其约定放在 `pixel-art/<slug>/build.py`，渲染预览后必须**看图自检**，
  至少 2–3 轮再交付；导出到 `game/assets/`。
- 该 skill 是 Python/Pillow 工具链，属于「任务本身依赖 Python」的例外，正常使用。
- 不要手改导出的 PNG；改 build.py 重跑。

## 字体与关于页规范（固定）

- **默认字体**：全项目固定使用 **LXGW WenKai / 霞鹜文楷**，
  `game/assets/fonts/LXGWWenKai-Regular.ttf`。`project.godot` 的
  `gui/theme/custom_font` 与所有运行时 `Theme.default_font` 必须指向该字体；
  新增 UI 不得改用系统字体或未登记字体。
- **字体版权说明**：`Copyright 2021-2026 LXGW (https://github.com/lxgw/LxgwWenKai)`，
  并包含 `Copyright 2020 The Klee Project Authors`；许可为 **SIL Open Font
  License 1.1（OFL 1.1）**，全文随包于 `game/assets/fonts/OFL.txt`。
  保留字体名称 `霞鹜`、`霞鶩`、`落霞孤鹜`、`落霞孤鶩`、`LXGW`；
  不得单独售卖字体，不得改用其他许可。关于页与片尾必须保留此署名。
- **关于页**：`game/scenes/about.tscn`，电影滚幕式自动上滚，内容必须覆盖
  项目信息、致谢、参考、版权与第三方素材；数据统一读 `game/data/credits.json`，
  第三方条目的来源链接必须可点击。
- **滚轮接管**：自动滚幕期间一旦收到鼠标滚轮事件，立即停止自动滚动并由玩家接管；
  不得自动恢复。键盘 `Esc` 返回主菜单。
- **关于页 BGM**：播放专属 BGM，进入时先调用 `AudioBus.stop_bgm()` 停止全局菜单 BGM；
  返回主菜单时由主菜单 `AudioBus.resume_bgm()` 恢复。关于页 BGM 必须登记来源、
  作者、许可与修改说明，并在滚幕中显示。

## Git 约定（重要）

- **频繁提交**：每完成一个可独立验证的改动就 commit 一次，不攒大包。
- 提交信息用 Conventional Commits：`feat:` / `fix:` / `render:` / `docs:` / `tools:` / `chore:`。
- 提交前确认工作区干净（`git status --short`）；大型第三方素材包已在 `.gitignore` 排除。
- 验证通过后再提交，禁止提交已知编译失败的代码。

## 测试运行与进程清理（红线，必须遵守）

- **任何**启动 Godot、gda daemon、Xvfb 的测试/预览动作，**结束当轮必须立即杀干净后台进程**。
- 统一收尾命令：
  ```bash
  pkill -f "Godot_v4[0-9]" ; pkill -f "gda.daemon" ; pkill -f "Xvfb :99"
  wineserver -k 2>/dev/null || true
  pgrep -af "Godot_v4|gda.daemon|Xvfb :99|wineserver" | grep -v pgrep || echo "clean"
  ```
- `wineserver -k` 仅在本轮启动过 Wine 测试时执行；不要在用户有其他 Wine 程序运行时清理。
- 取完图立刻 `gda daemon stop --project game`（或新脚本的 stop），再跑收尾命令确认 `clean`。
- 长任务用后台运行并在同轮结束前回收；不要跨轮遗留进程。
- 报告里若跑过引擎，必须写明「已清理后台进程」的核对结果。

## 命令执行约定（重要）

- **默认使用 `rtk` 前缀执行 shell 命令以节省 Token**：
  `rtk ls` / `rtk read` / `rtk git status` / `rtk grep` / `rtk rg` / `rtk summary <cmd>`。
- 写操作（重定向、`rm`、`mv`、`cp`）、交互式命令、需实时观察的命令裸跑。
- rtk 输出偏短属正常；仅在明显残缺或与退出码矛盾时用 `rtk bypass <cmd>`。

## 代码索引（codegraph）

- 旧 `.codegraph/` 索引已删除。等新 GDScript 成形后再决定是否重建；
  codegraph 不支持 GDScript，查 `.gd`/`.tscn` 直接用 `rg`/`Read` 或 `gda`。

## 开源参考实现（仅本地研究）

- 忽略目录：`third_party/reference-games/`，已写入 `.gitignore`。
  该目录只供本地阅读与 CodeGraph 索引，不进入成品、版本库或赛事提交包。
- `canvas-vampire-survivors/`：<https://github.com/ricardo-foundry/canvas-vampire-survivors>，
  MIT。借鉴固定步长循环、武器进化、经验/升级卡池、Boss 与结算记录流程；
  不直接拷贝其美术、文案或存档格式。
- `c-blob-survival/`：<https://github.com/bones-ai/c-blob-survival>，MIT。
  借鉴四叉树/空间分割宽相位、密集敌人清理、拾取物查询与弹幕更新顺序；
  本项目先实现 64px 空间哈希，只有实测需要时才替换为 C++ 四叉树。
- `starfish-room/`：<https://github.com/SketBestReal/StarfishROOM>，作者公开的
  GDevelop 源工程；itch 页面标注代码 MIT，但素材不自动随代码授权。
  CodeGraph 不支持 GDevelop JSON，已索引但返回 inactive；用 `rg` 手工查
  `game.json`。只借鉴卡牌框架、受击反馈、紧凑敌人对白与本地化结构，
  不复制角色、音频、字体或图像素材。
- 索引命令：
  `codegraph init third_party/reference-games/<repo>`，
  `codegraph explore "<query>"`（在对应仓库目录内执行）。
- 任何来自 MIT 参考实现的实质性代码片段，必须在文件头注明来源、作者、
  原仓库与 MIT 许可；仅借鉴玩法思路时不复制代码。素材授权以各仓库明确
  条款为准，`NOASSERTION` 或未单列素材许可时不得入包。

### 借鉴边界与 C++ 策略

- Canvas VS：循环、武器行为枚举、升级三选一、经验曲线、Boss/成就节奏。
- c-blob：先空间哈希，后按 profiler 结果决定是否写 GDExtension/C++ 四叉树；
  C++ 只做宽相位与密集碰撞查询，保留纯 GDScript 回退路径，且必须通过
  Windows 原生构建与 Linux 构建。
- Starfish：受击闪白/暗角、卡牌信息层级、短对白、语言表对齐与手感反馈。
- 不引入参考项目的运行时依赖，不把参考项目整体嵌入 Godot 工程。

### 文化叙事与 TTS 红线

- 1386 序章主角为汤和；1559 正篇只有一名可操作人物：虚构守灯乡勇王陆（乳名阿六）。
  选择页六张卡是王陆的守夜阵位，不是六名独立人物；不得把汤和写成 1559 的活人主角，
  也不得写“汤和筑永昌堡”。
- 史实桥只走：洪武十九年汤和筑宁村所 → 嘉靖三十七年王德移师宁村策应
  → 次日殉国金岙 → 王氏筑永昌堡 → 1559 守灯。出处统一引用
  `docs/06-资料文本化/堡与汤和关系索引.md`。
- 每句剧情/语音都必须带 `category`（`史实`/`制度`/`民俗`/`演绎`）和
  `source_ref`。没有出处的台词只能标为“演绎”，不得冒充史料。
- 当前默认 `game/data/voice_lines.json` 为 `audio_enabled=false` 的纯字幕模式；
  普通话字幕按约 4.35 音节/秒估算时长，TTS 不可用或未授权时必须回退字幕，
  不得静默跳过剧情。`scripts/generate_voice.ts` 默认拒绝生成/输出语音。
- 只有取得可核实的生成音频输出授权后，才可研究恢复 MOSS-TTS-Nano：
  女声 Xiaoyu/Lingyu，男声 Junhao；必须同时满足 manifest 权利门控与环境变量
  `MOSS_OUTPUT_RIGHTS_VERIFIED=1`，并登记到 `game/data/credits.json`、
  `AI使用与素材声明.md` 与 `素材授权清单.csv`。模型/代码 Apache-2.0 许可
  本身不得当作生成语音录音的授权。

## Godot / gda CLI 约定

- 引擎路径由 `GDA_GODOT` 指定；CLI 为 `gda`（`~/.local/bin/gda`）。
- **测试框架固定为 GUT 9.7.1**（MIT，位于 `game/addons/gut/`，对应
  `game/.godot-version` 锁定的 Godot 4.7.2-stable），
  已写入 `game/project.godot` 的 `[editor_plugins]`。不引入 GdUnit4：当前项目只用
  GDScript，GUT 的 CLI、JUnit XML、Mock/Spy、参数化测试已经够用；GdUnit4 的编辑器
  Inspector/Scene Runner 和 C# 支持暂时用不上，且其兼容表尚未列出 Godot 4.7.2-stable。
- GUT 首次安装或新增 `class_name` 后先导入一次：
  `"$GDA_GODOT" --headless --path game --import`；该命令在无头环境可能停在编辑器，
  必须用超时或进程清理收尾，不要留后台进程。
- GUT 单元测试统一放 `game/tests/unit/test_*.gd`，继承 `GutTest`，运行：
  `"$GDA_GODOT" --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- 测试分层：GUT 只测引擎内 GDScript 逻辑、场景、信号与对象池；数据/平衡模拟继续走
  Bun + TypeScript 读取 `game/data/*.json`，不启动 Godot。
- 新主场景建成后：`gda scene validate <scene> --project game --json`。
- 启动预检：`gda scene preflight <scene> --project game --frames 20 --json`。
- 启动级烟雾测试仍可用：`gda script run res://tests/<test>.gd --project game --json`。
- 视口截图：`gda daemon start --project game --windowed --scene <scene> --json`，
  再 `gda screen capture --project game --output <path>.png --json`；结束必须清理。
- 数据驱动：兵器/敌人/波次/角色放 `game/data/*.json`，不要写死在脚本里。
- 性能红线：小怪用数据数组 + `MultiMeshInstance2D`，弹幕/经验袋对象池，空间哈希 64px。

## 跨平台与 CI 验证（重要）

- 目标平台为 Linux、Windows、macOS；其中 **Windows 是必测平台**，不能只靠 Linux/Wine 推断。
- **Godot 版本锁定**：`game/.godot-version` 是唯一版本源（当前 `4.7.2-stable`）。
  CI、`launch.sh`、`launch.bat` 必须读取该文件；文档可注明当前值，但升级时以该文件为准。
- CI 唯一配置为 `.github/workflows/verify.yml`，必须同时包含：
  - Linux GUT：`ubuntu-latest`，从 `game/.godot-version` 读取版本并下载 Linux Godot。
  - Windows GUT：`windows-latest`，从 `game/.godot-version` 读取版本并下载
    `Godot_v${GODOT_VERSION}_win64.exe.zip`，
    使用 `_console.exe` 运行 `--headless --path game --import` 与 GUT。
- **CI 不使用 Wine**：Windows 任务必须直接在 `windows-latest` 上运行原生 Windows Godot；
  本地 Linux 的 Wine 验证只能作为额外预检，不能替代 CI 的原生 Windows 任务。
- Windows 启动器 smoke test 使用临时 `WATCH_SETTINGS_PATH`，不读取/写入真实 `%APPDATA%`；
  设置 `WATCH_RENDERER=opengl`，执行 `game\launch.bat --headless --quit-after 2`，
  并断言输出包含 `[launch] renderer=opengl`。
- 修改 `game/launch.bat`、`game/launch.sh`、`game/scripts/autoload/game_settings.gd`
  或渲染路径时，必须至少本地通过 Linux GUT，并由 CI 通过 Windows GUT 与启动器 smoke test。
- 本地 Windows/Wine 检查命令（Wine 仅用于本地预检）：
  ```powershell
  $godotVersion = (Get-Content game/.godot-version -Raw).Trim()
  $env:WATCH_GODOT = "C:\path\to\Godot_v${godotVersion}_win64_console.exe"
  $env:WATCH_RENDERER = "opengl"
  cmd /c "game\launch.bat --headless --quit-after 2"
  ```
- 直接运行 Windows Godot 测试：
  ```powershell
  & $env:GODOT_BIN --headless --path game --import
  & $env:GODOT_BIN --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
  ```

## 素材与版权

- 原创非代码资产：CC BY 4.0（原创 BGM 母版可另选 CC0）；**代码：AGPL-3.0-or-later**；第三方保留原许可（含 CC BY 4.0 / CC BY 3.0）；字体 OFL 1.1。代码与资产范围见根 `NOTICE`。
- 所有新增素材必须在 `素材授权清单.csv` 登记来源、工具、许可、是否入包。
- 第三方参考资料包（约 1.2GB）不纳入版本库，不进入成品。
- AI 生成内容须在 `AI使用与素材声明.md` 如实披露工具、用途与人工修改。
- **片尾/关于页滚幕**：`game/data/credits.json` 是唯一署名数据源；新增第三方素材必须
  同步加条目（可点击 `url` + `license`），关于页与未来的 `credits.tscn` 直接渲染该文件。
- 现有 `game/assets/` 地形、UI、音频与字体资产已登记，可复用；角色、敌兵、
  选择页与序章外观一律遵守 §0，正式文件只登记 `game/assets/units/forge/`。
- `素材授权清单.csv` 中旧兵种行保留为“已删除（旧运行时）”，不得改回“已使用”；
  新增角色条带必须登记生成工具、配方来源、帧数与许可。

## 当前验证基线

- `game/project.godot` 已建立：Godot 4.7.2-stable（`game/.godot-version` 锁定）、
  1280×720、`gl_compatibility`、nearest 过滤，
  全局字体霞鹜文楷，并启用 GUT。
- GUT 9.7.1 验证通过：`game/tests/unit/` 覆盖工程基线、双语、存档、设置、BGM、
  主菜单/关于页、王陆阵位、3 地图、16 分钟波次、空间哈希、双堡图鉴、叙事来源
  与结算解锁、三平台导出预设；当前 Linux 基线
  **165 tests / 165 passed / 41201 asserts**；运行命令见
  「Godot / gda CLI 约定」。
- GUT 的 `test_engine_version_matches_pinned_version` 校验实际引擎补丁版本与
  `game/.godot-version` 一致；升级引擎必须先改该文件并跑 Linux + Windows 测试。
- Windows 原生验证基线：GitHub Actions `windows-latest` 运行 GUT；本地 Wine 11 +
  Godot 4.7.2-stable win64 曾通过旧 UI 基线 `19/19`、`327 asserts`，
  `launch.bat` 的 Vulkan/OpenGL/渲染镜像读取已实测。新增玩法仍需 Windows CI 复验；
  CI 不以 Wine 结果代替原生 Windows 结果。
- 导出基线：Linux x86_64 `export smoke --strict` 通过；Windows exe 在 Wine
  `--headless --quit-after 3` 下退出码 0；macOS `.app` zip 已产出，待 macOS 实机验收。
  产物清单与哈希见 `docs/build_2026-11-23.md`。
- 主菜单、关于页、序章、选择页、正篇与图鉴已通过 `gda scene preflight`；
  验收截图与调试日志属于本地临时产物，统一放 `docs/screenshots/`
  （已被 `.gitignore` 忽略），需要时用 `gda` 现场生成，不入库、不在文档中引用。
- 460 敌人压力场景已把 draw calls 从 930 降到 14；当前桌面会话只有约 1 实际帧/秒，
  空场景也如此，故绝对 FPS 必须在正常唤醒的原生桌面/Windows 复测。记录见
  `docs/perf_2026-11-23.md`，暂不写 C++ GDExtension。
