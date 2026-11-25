# 开发者日志 03：从可玩版本到可审计的开源交付

- 日期：2026-11-25
- 作者：xingwangzhe
- 阶段：音频确权、许可分层、Dora 适配与发布审计

## 授权审计

逐项追踪运行时音频、字体、图标、特效和文化素材后，采取了以下处理：

- 三首运行时 BGM 均使用允许再分发的开放许可：菜单为 Maik Hoffmann（Majadroid）的《Samurai Nights》（CC BY 4.0），关于页为 Hitctrl 的《Views From Atop the Jade Kings Throne》（CC BY 3.0），战斗曲为 MintoDog 的《Hard Battle 1》（CC0 1.0）。两首 OpenGameArt 曲目于 2026-11-25 复核来源页后恢复，均不含 NC/ND 限制。
- 20 个运行时 SFX 全部使用 CC0，来源包括 OpenGameArt 与 Kenney。
- 删除 18 个输出授权未明确核实的 MOSS 生成语音 OGG；剧情保留双语字幕回退，生成器与模型权重均不随公开仓库分发。
- 代码采用 AGPL-3.0-or-later，原创非代码资产采用 CC BY 4.0；第三方内容保留 CC0、CC BY 4.0、CC BY 3.0、OFL 1.1、MIT 等原许可并逐项署名。

## Dora 适配

新增 `dora/build.py` 与根目录 `init.lua`。构建器只复制当前 `.import` sidecar 实际引用的导入产物，排除测试、GUT、gda harness 和缓存，并检查 ZIP 布局、CRC、法律文件与不安全路径。运行时通过 `GodotNode` 加载工程，等待 `game.running`，同时检查 `game.lastError`，避免把异步创建成功误判为启动成功。

## 发布修复

重新导出时发现开发用 `GdaHarness` 仍登记为 autoload，而导出包又排除了该插件，导致 Linux 发行版启动失败。修复方式是移除开发 autoload、加入回归断言并重新导出。三个平台 PCK 均审计为格式 v4、848 个文件，禁用路径、旧兵种、法律文件缺失和 MD5 错误均为 0。

2026-11-25 起 Release 改为标签驱动：`.github/workflows/release.yml` 仅在 `v*.*.*` 标签上运行，校验 `game/project.godot` 的 `config/version` 后，用官方 Godot CLI 完成测试、Linux/Windows/macOS/Web 四平台导出、审计与 GitHub CLI 发布。Dora 兼容入口与静态检查保留，但不再作为 Release 路径。

## 当前结果与边界

Linux、Windows、macOS 原生 GUT 与 Web 构建已在
[Verify #45594130561](https://github.com/xingwangzhe/watch-yongchang/actions/runs/45594130561)
全部通过；Dora 静态检查、源码 ZIP、Linux/Windows/macOS ZIP 与 PCK 审计通过。
真实 Dora、macOS 发行包实机验收、AtomGit 提交与赛事平台操作仍未完成。构建证据见
GitHub Actions 的 `release.yml` 报告，运行说明见 [Dora 运行说明](../DORA.md)。
