# 《守望 · 永昌》 / Watch of Yongchang

《守望 · 永昌》是一款以明代沿海卫所文化为背景的 2D 割草生存 Roguelite，参加 2026 OSGJ 开源游戏开发大赛。玩家扮演虚构守灯乡勇王陆，在永昌堡度过 16 分钟守夜：移动、自动或手动攻击、升级三选一、管理灯火风险，并抵御敌兵与 Boss。

当前游戏版本为 **`1.1.0`**；公开 Release 资产由 `v1.1.0` 标签的 CI 重新构建。

当前版本包含三张地图、王陆六种守夜阵位、七种兵器与十二种被动、箭塔连发/并发与塔内经验、外围奇遇、RTS 式流场寻路、双堡玩法图鉴、双语界面与字幕、首次游玩教程及完整结算流程。敌兵、精英与 Boss 在运行时抽取随机配装；CharacterForge 提供 3 种马与 6 个骑手动作条带。1386 年汤和序章与 1559 年王陆正篇分开叙事；六张选择卡是阵位，不是六名独立人物。

## 公开仓库范围

本仓库按 2026 OSGJ 开源奖要求公开可运行工程、构建说明、授权材料与可复核的文化索引。以下内容只在本地保留，不进入公开仓库或源码包：

公开树只保留必要内容：

- `game/`：Godot 工程、运行资产、测试与导出预设。
- `pixel-art/`：可复现的像素素材构建脚本；仅保留骑兵验收合图，其他预览与中间图不入库。
- `assets/`：仅保留原创音频源；运行字体的唯一副本在 `game/assets/fonts/`。
- `dora/`：Dora 兼容入口与静态构建器。
- `docs/`：仅保留三篇开发者日志、文化来源与 EdgeOne / Cloudflare Pages 部署说明。
- `.github/`、根目录许可、授权清单、`README.md` 与 `DORA.md`。
- 根 `.env`：仅公开构建配置与版本源，不含密钥。

以下内容只在本地保留：

- 开发助手工作区、会话记忆、技能缓存；设计稿、数值表、评审记录与内部过程文档只在
  本地保留，不进入公开仓库。
- 赛事官网抓取缓存、主题解密载荷与密钥、站点图片和榜单原始数据。
- 授权未明或明确不得再分发的第三方原始语料、PDF、OCR、缩略图与联系表。
- 导出包、截图、日志、演示视频、测试产物与一次性迁移脚本。

一次性脚本、设计源文件、研究缓存与本地构建产物由 [`.gitignore`](.gitignore) 统一排除；
新文件只有确认可再分发后才会显式加入公开树。

公开文化来源与叙事边界见 [`docs/文化来源.md`](docs/文化来源.md)；原始研究档案不随仓库分发。游戏运行不依赖这些本地档案。

## 开源奖对照

- **完整工程与运行说明**：Godot 工程在 `game/`，启动器、依赖与导出说明见本文件与
  [`game/README.md`](game/README.md)。
- **Dora 兼容版本**：入口 `init.lua`、适配说明 [`DORA.md`](DORA.md)、静态构建器
  `dora/build.py`；真实 Dora 运行验收仍待对应运行库环境。
- **代码许可**：AGPL-3.0-or-later，见 [`LICENSE`](LICENSE)。
- **原创资产许可**：CC BY 4.0，见 [`LICENSE-CC-BY-4.0.txt`](LICENSE-CC-BY-4.0.txt)；
  第三方素材保留原许可，逐项来源见 [`素材授权清单.csv`](素材授权清单.csv)。
- **AI 使用声明**：见 [`AI使用与素材声明.md`](AI使用与素材声明.md)。
- **公开构建与在线版**：GitHub Actions 按 Linux、Windows、macOS、Web 并行验证；
  `main` 的 Web 构建部署到 <https://2026shouwang.needhelp.icu>。已核验的四平台全绿记录见
  [Verify #45594130561](https://github.com/xingwangzhe/watch-yongchang/actions/runs/45594130561)。
- **开发者日志**：三篇公开日志见下方“文档”列表。

## 快速运行

### 桌面版本

- Linux / macOS：`./game/launch.sh`
- Windows：`game\launch.bat`

引擎锁定为 **Godot 4.7.2-stable**。根 `.env` 的 `GODOT_VERSION` 是唯一版本源，
`game/.godot-version`、`game/project.godot` 与导出预设由同步工具生成。直接运行 Godot 时，
工程根目录为 `game/`，主场景为 `res://scenes/main_menu.tscn`。启动器支持 Vulkan / OpenGL
选择；不可用时回退 OpenGL Compatibility。

### 版本、元数据与 Web 退出

根 `.env` 统一管理 `APP_VERSION`、`GODOT_VERSION`、中英文名称、作者、仓库、Web 地址、
应用图标 `APP_ICON` 与 Cloudflare Pages 项目名。修改后运行：

```bash
bun run env:sync
bun run env:check
bun run env:test
```

`env:sync` 同步 `game/.godot-version`、`game/project.godot`、`game/export_presets.cfg`
与运行时元数据 `game/data/project_meta.json`；`--check` 只校验，不写文件。关于页从生成
元数据读取作者、邮箱、版本、仓库与 Web 链接。Web 版退出按钮会明确标记“返回浏览器”，
先尝试关闭标签页；浏览器阻止关闭时显示可重新载入、打开项目主页或返回主菜单的提示层，
不会调用无效的 `get_tree().quit()`。

### Dora SSR

Dora 源码包入口为根目录 `init.lua`，Godot 工程位于包内 `watch-yongchang/`。依赖支持 `GodotNode` 的 Dora SSR，以及平台、后端、ABI 匹配的 Godot 4 运行库；这些第三方运行库不包含在源码包中。

```bash
python3 dora/build.py --check
python3 dora/build.py
```

生成 `artifacts/watch-yongchang-dora.zip`。Web IDE / Go Mode / CLI 的导入步骤、异步启动检查与 PCK 可选路线见 [DORA.md](DORA.md)。本机尚未安装 Dora CLI，真实 Dora 运行仍需验收。

Dora 只保留源码兼容与静态检查，不作为 GitHub Release 发布路径。

## 操作

- `WASD` / 方向键：八向移动。
- 鼠标左键长按：持续攻击；快速单点也会攻击一次。
- `X`：开关自动攻击；自动模式只锁定已进入或即将进入兵器射程的敌人。
- `Space`：灯影步冲刺。
- `1` / `2` / `3` 或点击卡片：选择升级；三选一出现后的 `0.2` 秒禁止选择。
- `Esc`：暂停；`C`：打开双堡图鉴。

第一次进入会显示操作、文化背景与游戏系统三页教程，也可从主菜单或暂停菜单重播。游戏内使用时代风格箭头；主角周围的方向圆弧跟随鼠标矢量，旧攻击辅助圆弧已移除。

## 测试与构建

```bash
"$GDA_GODOT" --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
bun run verify:env
```

测试框架为 GUT 9.7.1。当前 Linux 基线为 **189 tests / 189 passed / 50518 asserts**。CI 并行执行 Linux、Windows、macOS GUT 与 Web 构建；Windows 原生结果以 CI 为准，Wine 仅作本地预检。

`main` 分支的 Web 构建会以单线程模式导出，并并行部署至 Cloudflare Pages 项目
`shouwang` 与 EdgeOne Makers 镜像。自定义域名 <https://2026shouwang.needhelp.icu>
由既有 DNSPod 海内外分流配置承接；不要由部署脚本改 DNS。境外流量使用 Cloudflare
Pages，境内继续使用 EdgeOne 镜像。
Web 构建不要求 COOP/COEP 响应头。CI 用 Godot 官方 SCons 参数裁剪 Emscripten
运行时，再用 Binaryen `wasm-opt -Oz` 优化；wasm 与 PCK 不切分、不预压缩，由
Cloudflare Pages 与 EdgeOne 自动压缩传输。

推送 `v*.*.*` 标签会触发 `.github/workflows/release.yml`：工作流校验标签与根
`.env` 的 `APP_VERSION` 一致；`game/project.godot` 等文件由该配置生成，提交前用
`bun run env:check` 可提前发现版本漂移。随后按操作系统并行执行
Linux、Windows、macOS、Web 四个构建作业，每个平台都运行 GUT 并导出原生产物。汇总作业
执行 PCK/ZIP/许可证审计、Linux 发行版 smoke、Web 静态产物检查与 EdgeOne / Cloudflare
Pages 并行部署，最后通过 GitHub CLI 创建 GitHub Release。发布包包含 Linux / Windows
可执行文件及外部 PCK、macOS
ZIP、Web ZIP、完整源码 ZIP、`release-manifest.json` 和 `SHA256SUMS.txt`；Dora 源码包不随
Release 发布。

## 赛事提交媒体

赛事封面与 91 秒演示视频作为作品提交附件单独交付，不进入 Git 仓库；演示视频须另发 Bilibili 并添加「2026 开源游戏开发大赛」标签。演示片使用已验收游戏截图、原创字幕/排版与项目原创 CC0 菜单母版 `assets/audio/bgm_watch.ogg`，不是连续实机录屏，也不代表当前运行时菜单 BGM。完整解码、音视频等长、2730 帧、实际末帧与响度检查均已通过。

## 文档

- [Godot 工程说明](game/README.md)
- [Dora 适配说明](DORA.md)
- [Cloudflare Pages Web 部署](docs/cloudflare-pages.md)
- [EdgeOne Makers Web 部署](docs/edgeone-deploy.md)
- [开发者日志 01：核心玩法与文化](docs/开发者日志-01-核心玩法与文化.md)
- [开发者日志 02：战斗表现与操作手感](docs/开发者日志-02-战斗表现与操作手感.md)
- [开发者日志 03：音频确权与 Dora 发布](docs/开发者日志-03-音频确权与Dora发布.md)
- [AI 使用与素材声明](AI使用与素材声明.md)
- [素材授权清单](素材授权清单.csv)
- [完整署名数据](game/data/credits.json)

## 授权范围

- **项目代码：AGPL-3.0-or-later**，全文见 [LICENSE](LICENSE)。分发修改版本时须提供对应源码；网络交互还涉及 AGPL 第 13 条义务。
- **团队原创非代码资产：CC BY 4.0**，全文见 [LICENSE-CC-BY-4.0.txt](LICENSE-CC-BY-4.0.txt)，许可链接为 <https://creativecommons.org/licenses/by/4.0/>。署名 xingwangzhe、链接许可并注明修改。
- 特定原创音频提供 **CC0 1.0 或 CC BY 4.0** 选择，既有 CC0 奉献保留。
- 第三方内容保留原许可，包括 CC0 音频、game-icons.net 的 CC BY 3.0 图标、LXGW WenKai / Klee 的 SIL OFL 1.1 字体及 Jeff-FX-forge 的 MIT 代码 / CC0 特效。逐项来源与使用范围见 [NOTICE](NOTICE) 和相关清单。
- MOSS-TTS-Nano 生成语音的输出授权未获明确核实，18 个 OGG 已停止分发；剧情保留双语字幕回退。

## 尚未完成的外部验收

Windows 原生 CI 与 macOS 原生 GUT 已通过；macOS 发行包实机运行、公开仓库
Release 页面重建、AtomGit 仓库与提交标识、原子派社区 20 个点赞及赛事互评仍需
对应平台或账号操作，不能由本地构建结果推定完成。赛事提交要求 AtomGit 仓库；
当前 GitHub 仓库不能替代该提交入口。Dora 兼容运行不再是普通发行门槛，但申请
Dora 开源社区奖仍须提供真实可运行的 Dora 兼容版本。

赛事官网：<https://2026gamejam.osgame.org/>
