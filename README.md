# 《守望 · 永昌》 / Watch of Yongchang

《守望 · 永昌》是一款以明代沿海卫所文化为背景的 2D 割草生存 Roguelite，参加 2026 OSGJ 开源游戏开发大赛。玩家扮演虚构守灯乡勇王陆，在永昌堡度过 16 分钟守夜：移动、自动或手动攻击、升级三选一、管理灯火风险，并抵御敌兵与 Boss。

当前游戏版本为 **`0.1.0`**，对应 Git 标签 `v0.1.0`。

当前版本包含三张地图、王陆六种守夜阵位、七种兵器与十二种被动、箭塔连发/并发、双堡图鉴、双语界面与字幕、首次游玩教程及完整结算流程。1386 年汤和序章与 1559 年王陆正篇分开叙事；六张选择卡是阵位，不是六名独立人物。

## 公开仓库范围

本仓库按 2026 OSGJ 开源奖要求公开可运行工程、构建说明、授权材料与可复核的文化索引。以下内容只在本地保留，不进入公开仓库或源码包：

- 开发助手工作区、会话记忆、技能缓存与内部设计草稿。
- 赛事官网抓取缓存、主题解密载荷与密钥、站点图片和榜单原始数据。
- 授权未明或明确不得再分发的第三方原始语料、PDF、OCR、缩略图与联系表。
- 导出包、截图、日志、演示视频、测试产物与一次性迁移脚本。

公开文化结论见 [`docs/06-资料文本化/`](docs/06-资料文本化/) 顶层索引；原始研究档案不随仓库分发。游戏运行不依赖这些本地档案。

## 快速运行

### 桌面版本

- Linux / macOS：`./game/launch.sh`
- Windows：`game\launch.bat`

引擎锁定为 **Godot 4.7.2-stable**，版本来源是 `game/.godot-version`。直接运行 Godot 时，工程根目录为 `game/`，主场景为 `res://scenes/main_menu.tscn`。启动器支持 Vulkan / OpenGL 选择；不可用时回退 OpenGL Compatibility。

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
- `X`：开关自动攻击；自动模式优先瞄准最近的存活敌人。
- `Space`：灯影步冲刺。
- `1` / `2` / `3` 或点击卡片：选择升级；三选一出现后的第一秒禁止选择。
- `Esc`：暂停；`C`：打开双堡图鉴。

第一次进入会显示操作、文化背景与游戏系统三页教程，也可从主菜单或暂停菜单重播。游戏内使用时代风格箭头；主角周围的方向圆弧跟随鼠标矢量，旧攻击辅助圆弧已移除。

## 测试与构建

```bash
"$GDA_GODOT" --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

测试框架为 GUT 9.7.1。当前 Linux 基线为 **165 tests / 165 passed / 41214 asserts**。CI 同时包含 Linux 与原生 Windows GUT；Windows 原生结果以 CI 为准，Wine 仅作本地预检。

推送 `v*.*.*` 标签会触发 `.github/workflows/release.yml`：工作流校验标签与 `game/project.godot` 的 `config/version` 一致，随后运行 GUT、三平台 Godot 导出、PCK/ZIP/许可证审计与 Linux 发行版 smoke，最后通过 GitHub CLI 创建 GitHub Release。发布包包含 Linux / Windows 可执行文件及外部 PCK、macOS ZIP、完整源码 ZIP、`release-manifest.json` 和 `SHA256SUMS.txt`；Dora 源码包不随 Release 发布。

## 赛事提交媒体

赛事封面与 91 秒演示视频作为作品提交附件单独交付，不进入 Git 仓库；演示视频须另发 Bilibili 并添加「2026 开源游戏开发大赛」标签。演示片使用已验收游戏截图、原创字幕/排版与项目原创 CC0 菜单母版 `assets/audio/bgm_watch.ogg`，不是连续实机录屏，也不代表当前运行时菜单 BGM。完整解码、音视频等长、2730 帧、实际末帧与响度检查均已通过。

## 文档

- [游戏设计文档](design/游戏设计文档-GDD.md)
- [Godot 工程说明](game/README.md)
- [Dora 适配说明](DORA.md)
- [构建与审计报告](docs/build_2026-11-25.md)
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

原生 Windows CI、macOS 实机运行、公开仓库 Release 页面、原子派社区 20 个点赞及赛事互评需要对应账号、平台或硬件环境，不能由本地构建结果推定完成。Dora 兼容运行不再是发版门槛。

赛事官网：<https://2026gamejam.osgame.org/>
