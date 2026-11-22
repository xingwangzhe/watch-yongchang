# AGENTS.md — 项目协作约定

本文件供所有 AI 编码代理（Claude Code / Codex / Cursor / WorkBuddy 等）阅读。
适用法律与素材许可见根目录 `AI使用与素材声明.md`、`素材授权清单.csv`。

## 项目概况

- 名称：《守望 · 永昌》—— 2026 OSGJ 开源游戏开发大赛参赛作品
- 主题：守 · 望（官方隐藏主题，解密结果见 `docs/02-主题资料/theme-payload.decrypted.json`）
- 玩法：暴兵对推 + 塔防 + 物流经营 + 文化闯关（GDD 见 `design/游戏设计文档-GDD.md`）
- **技术借鉴文档**：`design/技术借鉴-Mindustry与RWX.md` —— 改造图块/多格建筑/动画前**必读**，含 Mindustry/RWX 架构方法、本项目落地方案与 5 条踩坑记录
- 运行时：Godot 4.7.2-stable；工程根 `game/`；主场景 `res://scenes/main.tscn`
- 字体：霞鹜文楷 / LXGW WenKai（OFL 1.1），全局默认主题 `game/themes/default.tres`
- 地形瓦片：Hard Vacuum（Mark Ferrari, CC BY 3.0）派生，见 `game/assets/tiles/` 与 AI 声明 5.4 节

## Git 约定（重要）

- **频繁提交**：每完成一个可独立验证的改动就 commit 一次，不攒大包。用户明确要求"多 commit 暂存"。
- 提交信息用 Conventional Commits：`feat:` / `fix:` / `render:` / `docs:` / `tools:` / `chore:`。
- 提交前确认工作区干净（`git status --short`）；大型第三方素材包已在 `.gitignore` 排除，勿强行纳入。
- 验证通过后再提交，禁止提交已知编译失败的代码。

## 命令执行约定（重要）

- **默认使用 `rtk` 前缀执行 shell 命令以节省 Token**，例如：
  - `rtk ls` / `rtk tree` / `rtk read <file>` 代替 `ls` / `find` / `cat`
  - `rtk git status` / `rtk git log` / `rtk diff` 代替裸 git 读命令
  - `rtk grep` / `rtk rg` / `rtk find` 代替 `grep` / `rg` / `find`
  - `rtk test` / `rtk err` / `rtk summary <cmd>` 包裹测试与构建命令
- 写操作（重定向、`rm`、`mv`、`cp`）、交互式命令、需实时观察的命令裸跑。
- rtk 输出偏短属正常，视为完整结果；仅在明显残缺或与退出码矛盾时用 `rtk bypass <cmd>`。
- 累计节省量用 `rtk gain` 查看。rtk 路径 `~/.local/bin/rtk`。

## 代码索引（codegraph）

- 项目已用 `codegraph` 建立索引（版本 1.6.3，索引库 `.codegraph/codegraph.db`，已加入 `.codegraph/.gitignore` 不入库）。
- 查询符号用 `codegraph query "<关键词>"`；带行号读文件用 `codegraph node <name>`；
  构建任务上下文用 `codegraph context "<任务>"`；查看影响面用 `codegraph impact <symbol>`。
- **能力边界**：当前 codegraph 只索引 `tools/generate_audio.py`（Python）。GDScript（`.gd`）、
  Godot 场景（`.tscn`）、CSV/JSON 数据表不在其语言支持范围内。查这些文件请直接用
  `Grep` / `Read` 工具，或 `gda scene get` / `gda game tree` 读取场景结构。
- 改动 Python 代码后运行 `codegraph sync` 增量同步；大规模重构后 `codegraph index` 全量重建。

## Godot / gda CLI 约定

- 引擎路径由环境变量 `GDA_GODOT` 指定；CLI 为 `gda`（`~/.local/bin/gda`）。
- 一键脚本：`./run-test.sh`（play / verify / live / stop / check）。
- 静态校验：`gda scene validate res://scenes/main.tscn --project game --json`。
- 启动预检：`gda scene preflight res://scenes/main.tscn --project game --frames 20 --json`。
- 自动断言：`gda script run res://tests/verify.gd --project game --json`（应 PASS=19 FAIL=0）。
- 视口截图：先 `gda daemon start --project game --windowed --json`，
  再 `gda screen capture --project game --output <path>.png --json`，
  结束用 `./run-test.sh stop` 清理 harness。
- autoload 顺序：`GameState` 必须在 `SupplySystem` 之前（`project.godot` 中已固定）。
- `PathFollow2D` 用 `rotates` 属性，不是 `rotation_mode`。

## 素材与版权

- 原创非代码资产：CC BY 4.0；代码：AGPL-3.0；音频：CC0 1.0；字体：SIL OFL 1.1。
- 所有新增素材必须在 `素材授权清单.csv` 登记来源、工具、许可、是否入包。
- 第三方参考资料包（约 1.2GB）不纳入版本库，不进入成品。
- AI 生成内容须在 `AI使用与素材声明.md` 如实披露工具、用途与人工修改。

## 当前验证基线

- `./run-test.sh verify` → PASS=19 FAIL=0
- `gda diag errors` → `{"errors":[]}`
- 视口截图确认：背景、三路驿道、三座塔、敌我主堡、单位、弹道均可见。
