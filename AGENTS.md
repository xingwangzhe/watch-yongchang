# AGENTS.md — 项目协作约定

本文件供所有 AI 编码代理（Claude Code / Codex / Cursor / WorkBuddy 等）阅读。
适用法律与素材许可见根目录 `AI使用与素材声明.md`、`素材授权清单.csv`。

## 项目概况

- 名称：《守望 · 永昌》—— 2026 OSGJ 开源游戏开发大赛参赛作品
- 主题：守 · 望（解密结果见 `docs/02-主题资料/theme-payload.decrypted.json`）
- 玩法：**Vampire Survivors-like 割草生存 Roguelite**。16 分钟单局，自动攻击，
  升级三选一，灯火风险收益，文化阵法与龙灯清屏。
- 设计大纲：`design/游戏设计文档-GDD.md`（当前唯一设计源；旧守城 GDD 已删除）
- 状态：旧守城玩法已清空，按 GDD 重建；基础 UI 骨架（主菜单/设置/双语/自动存档/
  关于页/占位开局）已完成，M0 玩法待建。保留 `game/assets/` 美术、`docs/` 文化资料、`skills/`。
- 运行时：Godot 4.7.2-stable；工程根 `game/`；主场景 `game/scenes/main_menu.tscn`。
- 字体：**全局默认字体固定为霞鹜文楷 / LXGW WenKai（OFL 1.1）**，资产在 `game/assets/fonts/`。
- 许可：**代码 GPL-3.0-or-later**；原创非代码资产 CC BY 4.0；音频 CC0/CC-BY；字体 OFL 1.1。

## 目录

```text
design/       新 GDD 与设计文档（旧文档已清空）
docs/         文化资料、主题资料、截图、来源清单（保留）
game/         Godot 工程；scenes/ scripts/ data/ tests/ assets/
  assets/     兵种、地形、UI、音频、字体
skills/       项目内 Agent Skills（必须保留）
assets/       原始美术/音频源文件（与 game/assets 有重复，勿删）
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
  pgrep -af "Godot_v4|gda.daemon|Xvfb :99" | grep -v pgrep || echo "clean"
  ```
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

## Godot / gda CLI 约定

- 引擎路径由 `GDA_GODOT` 指定；CLI 为 `gda`（`~/.local/bin/gda`）。
- **测试框架固定为 GUT 9.7.1**（MIT，位于 `game/addons/gut/`，对应 Godot 4.7.x），
  已写入 `game/project.godot` 的 `[editor_plugins]`。不引入 GdUnit4：当前项目只用
  GDScript，GUT 的 CLI、JUnit XML、Mock/Spy、参数化测试已经够用；GdUnit4 的编辑器
  Inspector/Scene Runner 和 C# 支持暂时用不上，且其兼容表尚未列出 Godot 4.7.2。
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

## 素材与版权

- 原创非代码资产：CC BY 4.0；**代码：GPL-3.0-or-later**；音频 CC0 / CC-BY 3.0；字体 OFL 1.1。
- 所有新增素材必须在 `素材授权清单.csv` 登记来源、工具、许可、是否入包。
- 第三方参考资料包（约 1.2GB）不纳入版本库，不进入成品。
- AI 生成内容须在 `AI使用与素材声明.md` 如实披露工具、用途与人工修改。
- **片尾/关于页滚幕**：`game/data/credits.json` 是唯一署名数据源；新增第三方素材必须
  同步加条目（可点击 `url` + `license`），关于页与未来的 `credits.tscn` 直接渲染该文件。
- 现有 `game/assets/` 兵种与地形资产已登记，可复用；新游戏不重复登记同一文件。

## 当前验证基线

- `game/project.godot` 已建立：Godot 4.7.2、1280×720、`gl_compatibility`、nearest 过滤，
  全局字体霞鹜文楷，并启用 GUT。
- GUT 9.7.1 验证通过：`game/tests/unit/` 覆盖工程基线、双语、存档、设置、BGM、
  主菜单与关于页；运行命令见「Godot / gda CLI 约定」。
- 主菜单与关于页已通过 `gda scene preflight`，截图验收图在
  `docs/screenshots/ui_2026-11-23/`。M0 玩法仍待补。
