# Dora SSR 适配说明

本目录提供《守望 · 永昌》Godot 4 工程的最小 Dora SSR `GodotNode` 适配入口。
当前交付包含源码 ZIP、构建器、静态检查和运行文档。Godot 工程已完成导入、单元测试与
场景预检；**本机没有 Dora CLI，尚未执行真实 Dora 运行验收**。桌面 PCK 已随发布包导出，
但没有制成 Dora PCK 专用包，也未上传或发布。

Dora 是默认保留的兼容目标，不是 GitHub Release 的发布方式。`v*.*.*` 标签由
`.github/workflows/release.yml` 使用 Godot 原生导出并创建 GitHub Release；CI 仅对
Dora 适配执行 `python3 dora/build.py --check`，不构建、不上传 Dora 运行时包。

## 1. 当前工程与包结构

- Godot 版本：`game/.godot-version`，当前为 `4.7.2-stable`。
- 脚本：Godot 4 GDScript；工程没有 C# 或原生 GDExtension。
- 主场景：`res://scenes/main_menu.tscn`。
- 视口：1280×720，`canvas_items` / `expand`。
- 渲染：`gl_compatibility`。
- 现有 Godot 导出预设：Linux、Windows、macOS、Web；Web 预设用于 EdgeOne Makers
  单线程静态部署。

`python3 dora/build.py` 默认生成 `artifacts/watch-yongchang-dora.zip`，结构为：

```text
watch-yongchang-dora.zip
├── init.lua                         # Dora 入口，必须在 ZIP 根目录
├── watch-yongchang/                 # Dora 要加载的 Godot 源码工程
│   ├── project.godot
│   ├── .godot-version
│   ├── .godot/.gdignore
│   ├── .godot/global_script_class_cache.cfg
│   ├── .godot/uid_cache.bin         # 当前导入缓存存在时包含
│   ├── .godot/imported/...          # 仅当前 .import 实际引用的输出
│   ├── assets/...                   # 原始资产、.import 及生成的 .translation
│   ├── data/ scripts/ scenes/...
│   └── export_presets.cfg
├── DORA.md
├── LICENSE
├── NOTICE
├── LICENSE-CC-BY-4.0.txt
├── AI使用与素材声明.md
└── 素材授权清单.csv
```

Go Mode 的源码包要求根目录有可运行的 `init` 入口；本包使用根目录 `init.lua`。
不要把 PCK、Web 导出 ZIP 或整个仓库直接当作这个源码包导入。

## 2. 入口与异步启动

入口文件是 `dora/init.lua`，打包后位于 ZIP 根目录。核心设置为：

```lua
local PROJECT_PATH = "watch-yongchang"
local game = Dora.GodotNode(PROJECT_PATH, "", 1280, 720, 3)
```

- `projectPath` 为 `watch-yongchang`，由 Dora `Content` 资源根解析。
- `sceneFile` 留空 `""`，使用 `project.godot` 的 `run/main_scene`。
- 视口为 1280×720；GodotNode 宽高允许 1–8192。
- `buffers` 为 3，允许 2–4。
- 节点加入 `Dora.Director.ui`，按 Dora 视口等比缩放。
- `Dora.GodotNode.getUnsupportedReason()` 只检查 GPU/后端能力；它**不能**
  证明目标平台存在平台、后端、ABI 都匹配的 Godot 运行库。
- Godot 启动是异步的。入口通过 `game:schedule()` 等待 `game.running`，并持续
  检查 `game.lastError`；只有出现 `[Dora] Godot project ready` 后才进入就绪状态。
- 入口不注入合成鼠标或键盘输入。宿主/引擎的键盘转发、触屏和实际输入映射必须
  在真实 Dora 运行时另行验收。
- 同一时间只能有一个活动 `GodotNode`。切换源码工程与 PCK 时，必须等待
  `unloadAsync(callback)` 成功，不能直接创建第二个节点覆盖当前工程。

## 3. 依赖

### 构建依赖

- Python 3.10 或更新版本。
- 仅使用 Python 标准库，不需要安装 Python 包。
- 完整构建需要一次有效的 Godot 4 导入缓存：
  - `game/.godot/imported/`
  - `game/.godot/global_script_class_cache.cfg`
  - `game/.godot/.gdignore`
- 构建器本身不会调用 Godot。若本机还没有导入缓存，维护者需另行执行：

```bash
"$GDA_GODOT" --headless --path game --import
```

2026-11-25 已用 Godot 4.7.2-stable 执行上述导入。当前源码 ZIP 的最终 SHA-256
由 GitHub Actions 构建报告与 `release-manifest.json` 记录。

### Dora 运行依赖

- 支持 `GodotNode` 的 Dora SSR；本文按官方 1.10.2 文档编写。
- Dora 自带的 Godot 4 运行库必须覆盖 `GodotNode` 能力。
- Godot 运行库的平台、后端和 ABI 必须与 Dora 构建一致，例如：
  - Linux：Linux 的 Godot 4 运行库，后端须与 Dora Linux 包一致。
  - Windows：x64 Windows Godot 4 运行库；本项目默认 OpenGL，应优先验证
    Dora 的 WGL/OpenGL 包，不能混用其他后端或位数。
  - macOS：macOS Godot 4 运行库；须验证 Dora 包所用后端与本项目
    `gl_compatibility` 的实际兼容性。
  - Android / Web：分别使用对应的 Android / Web Godot 4 运行库；Web 还需要
    WebGL2。不能加载桌面动态库或桌面 PCK。
- Dora 引擎与 Godot 运行库是第三方运行依赖，不包含在本源码 ZIP 中。

Web 预设使用单线程导出，不要求 COOP/COEP 响应头；EdgeOne Makers 可直接托管。

## 4. 构建与静态检查

以下命令适用于本仓库源码树；Dora 运行 ZIP 内不包含构建器本身。在仓库根目录执行：

```bash
# 不读取导入缓存，不生成 ZIP；适合无 Godot 的 CI 静态检查
python3 dora/build.py --check

# 生成默认源码 ZIP
python3 dora/build.py

# 指定其他输出位置（必须位于 game/ 之外）
python3 dora/build.py --output artifacts/watch-yongchang-dora.zip

# 可选：查看构建产物哈希
sha256sum artifacts/watch-yongchang-dora.zip
```

完整构建会检查：

1. Godot 4 版本、GL Compatibility、主场景、全局字体和运行时 autoload 路径。
2. 没有 C#、`.gdextension` 或 `.cs` 输入。
3. 每个 `.import` 的 remap / `dest_files` 引用的输出都存在。
4. ZIP 根入口、`watch-yongchang/project.godot`、许可/署名文档和 CRC 完整。
5. 包内不含测试、GUT、gda harness、编辑器/着色器/导出缓存或未引用的导入缓存。

正式 `game/project.godot` 不再注册开发工具 autoload；`gda daemon start` 需要 harness 时
会自行安装，导出与 Dora 运行不依赖它。构建器同时拒绝包内副本残留
`GdaHarness=`，避免开发环境误把测试工具带入成品。包内同时排除 `tests/`、`addons/gut/`、
`addons/gda_harness/`、`game/build/`、`game/export/` 以及
`.godot/editor/`、`.godot/exported/`、`.godot/shader_cache/`。
`.godot/imported/` 不整目录复制，只复制当前 `.import` 引用的文件及相邻 `.md5`，
避免把已删除旧兵种的陈旧缓存带入成品。

## 5. 运行源码 ZIP

### Dora Web IDE

1. 打开 Dora SSR Web IDE，新建 Lua 项目。
2. 导入 `artifacts/watch-yongchang-dora.zip`，保持 `init.lua` 在项目根目录。
3. 确认 `watch-yongchang/project.godot` 与 `init.lua` 同级目录关系正确。
4. 运行项目，等待 `[Dora] Godot project ready`，随后应进入 Godot 主菜单。
5. 若日志出现 `Godot error:`，以 `game.lastError` 和 Dora 日志为准；不要继续
   注入输入或重复创建 `GodotNode`。

### Go Mode

1. 在 Go Mode 的「本地」页面选择「+ 新建」→「导入游戏包」。
2. 选择 `artifacts/watch-yongchang-dora.zip`。
3. 使用「导入并游玩」；源码 ZIP 依赖根目录可运行的 `init` 入口。

### Dora CLI

CLI 只控制一个已经正常启动、且 Web IDE 可连接的 Dora SSR。先启动 Dora SSR，
然后在仓库根目录或包解压目录执行：

```bash
# 确认 Dora 服务状态
Dora cli status

# 运行解压后的源码包
Dora cli run -p /absolute/path/to/unzipped/package --entry init.lua

# 停止当前交互项目
Dora cli stop
```

`Dora` 若不在 `PATH` 中，替换为实际 Dora 可执行文件路径。CLI 的 `run` 不会
自动修复缺失或不匹配的 Godot 运行库。可选解压命令为：

```bash
mkdir -p artifacts/dora-source
python3 -m zipfile -e artifacts/watch-yongchang-dora.zip artifacts/dora-source
Dora cli run -p "$PWD/artifacts/dora-source" --entry init.lua
```

## 6. 可选的 PCK 流程

PCK 路线仍由 Dora `GodotNode` 加载，但 `projectPath` 改为 PCK 文件名。PCK 必须
由匹配目标平台/后端的 Godot 4 导出预设生成；例如使用现有桌面预设：

```bash
# Linux PCK
"$GDA_GODOT" --headless --path game --export-pack "Linux" artifacts/watch-yongchang-linux.pck

# Windows PCK；只能配合匹配的 Windows Dora/Godot 运行库
"$GDA_GODOT" --headless --path game --export-pack "Windows" artifacts/watch-yongchang-windows.pck

# macOS PCK；只能配合匹配的 macOS Dora/Godot 运行库
"$GDA_GODOT" --headless --path game --export-pack "macOS" artifacts/watch-yongchang-macos.pck
```

上述命令会启动 Godot。2026-11-25 已通过三平台 `--export-release` 生成桌面发布产物，
Linux / Windows 使用同目录外部 PCK，macOS PCK 位于 `.app/Contents/Resources/`；
这些桌面包尚未在 Dora 中运行。Dora PCK 专用包结构应为：

```text
dora-pck-package/
├── init.lua                         # 将 PROJECT_PATH 改为 "watch-yongchang.pck"
├── watch-yongchang.pck
├── DORA.md
├── LICENSE
├── NOTICE
├── LICENSE-CC-BY-4.0.txt
├── AI使用与素材声明.md
└── 素材授权清单.csv
```

切换时只修改包内 `init.lua` 的 `PROJECT_PATH`，并确保解压后两者同级。
`dora/build.py` 刻意不导出 PCK，也不会把 PCK 混入源码 ZIP。

当前没有 Web 导出预设。若要生成 Godot Web PCK，需先在 Godot 中新增并验证
`Web` 预设，再导出；源码 ZIP 路线不依赖这个预设。无论哪条 Web 路线，都必须
满足上面的 COOP/COEP，并使用匹配的 WebGL2 Godot 运行库。

## 7. CI 边界

`.github/workflows/verify.yml` 中：

- `asset-guard` 运行 `python3 dora/build.py --check`，不启动 Godot。
- `linux-gut` 在既有 Godot 导入之后运行完整源码 ZIP 构建，输出到
  `$RUNNER_TEMP/watch-yongchang-dora.zip`。
- 没有 Dora 运行任务、没有 PCK 导出任务，也没有上传/发布 artifact 的步骤。

因此 CI 只能证明静态约束和源码包布局可构建，不能证明 Dora 运行库、输入、
音频、存档或 Web 隔离头实际工作。

## 8. 许可范围

- `dora/init.lua` 与 `dora/build.py` 是项目代码，按 **AGPL-3.0-or-later** 提供，
  并带对应 SPDX 标记。仓库根 `LICENSE`、各文件许可标记及项目声明共同约束分发；
  若根许可证与单个文件标记不同，不能据此自动重新许可该文件。
- `game/` 内项目代码按 **AGPL-3.0-or-later** 提供；第三方代码组件与开发依赖保留各自
  许可和署名。运行包已排除 GUT 与 gda harness；Pixel Art Studio、Pillow 等构建工具
  不随运行包分发。
- 原创非代码资产按项目声明为 CC BY 4.0；音频按逐文件清单使用 CC0 / CC BY 等
  原始许可；LXGW WenKai 字体为 SIL OFL 1.1。不能把整个源码 ZIP 统一重新许可为
  某一种资产许可。
- 第三方署名与链接以 `game/data/credits.json`、`game/NOTICE`、
  `game/assets/audio/LICENSES.md`、`AI使用与素材声明.md` 和
  `素材授权清单.csv` 为准；这些文件随包保留。
- Dora SSR、其 Godot 运行库以及 Godot 引擎是独立第三方组件，不随本包重新许可。
  GUT 仅用于开发测试，已排除在运行包外。

## 9. 仍需真实 Dora 运行时验收

- [ ] 目标平台的 Dora 构建确实附带匹配平台、后端、ABI 的 Godot 4 运行库。
- [ ] 源码 ZIP 在 Web IDE、Go Mode 和 CLI 中均可导入并出现就绪日志。
- [ ] 空 `sceneFile` 能进入主菜单，1280×720 缩放与不同宿主视口正常。
- [ ] 键盘、鼠标、触屏、升级三选一和菜单返回的实际输入链路正常。
- [ ] 音频、存档、字体、翻译与 `.godot/imported` 资源在运行包中正常。
- [ ] `lastError`、工程切换和 `unloadAsync` 失败路径行为可接受。
- [ ] 如走 PCK：目标平台 PCK 与运行库匹配；不会跨平台复用 PCK。
- [ ] 如走 Web：WebGL2、COOP/COEP、资源加载和浏览器控制台无隔离错误。
- [ ] Linux / Windows / macOS / Android / Web 实机性能与退出/切后台行为。

## 官方参考

- [使用 GodotNode](https://ippclub.gitee.io/Dora-SSR/zh-Hans/docs/tutorial/Using%20Nodes/using-godot-node)
- [GodotNode API](https://dora-ssr.net/zh-Hans/docs/api/Class/GodotNode/)
- [导入项目](https://dora-ssr.net/docs/tutorial/import-project)
- [打包独立游戏应用](https://dora-ssr.net/zh-Hans/docs/tutorial/game-app-pack/)
- [Dora CLI](https://dora-ssr.net/zh-Hans/docs/tutorial/command-line-interface)
