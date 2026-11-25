# 《守望 · 永昌》AI 使用与素材声明

| 项目 | 内容 |
|---|---|
| 作品 | 《守望 · 永昌》 / Watch of Yongchang |
| 作者 | xingwangzhe |
| 联系方式 | xingwangzhe@outlook.com |
| 版本 | 0.1.0 |
| 声明更新 | 2026-11-25 |
| 赛事 | 2026 OSGJ 开源游戏开发大赛 |
| 代码许可 | AGPL-3.0-or-later |
| 原创非代码资产 | CC BY 4.0；明确标注的原创音频另可选 CC0 1.0 |
| 第三方内容 | 保留原许可，逐项署名 |

本声明按赛事“申报赛前已有代码、工具与素材；如实说明 AI 工具、用途、生成内容与人工修改”的要求编制。
逐文件来源与许可以 [素材授权清单.csv](素材授权清单.csv) 和
[game/data/credits.json](game/data/credits.json) 为准。

## 1. 申报概要

1. **赛前已有内容**：没有赛前完成的游戏本体、私有游戏代码或换皮素材。项目于
   2026-11-22 从空目录开始开发。Godot、GUT、Pixel Art Studio、Pillow、ffmpeg、
   OpenGameArt 音频与 game-icons.net 图标属于赛前已有的开源工具或第三方素材，
   按各自原许可使用。
2. **原创范围**：玩法、数据结构、GDScript 代码、关卡与数值、CharacterForge
   角色配方与烘焙代码、像素图集生成代码、UI 编排、文案与双语文本均由本项目制作。
3. **AI 参与**：AI 用于代码与文档起草、测试辅助、数据整理、图像后处理和条件性
   位图 UI 生成；最终方向、范围、视觉验收、文化边界、数值取舍与发布检查由作者完成。
4. **未使用内容**：没有把未授权网络图片、商业素材、他人角色图集、生成式音乐或
   未核实输出权利的生成语音放入发行包。

## 2. AI 工具与实际用途

| 工具 | 用途 | 生成或处理内容 | 人工介入 |
|---|---|---|---|
| OpenAI Codex / WorkBuddy 会话助手 | 编程、重构、测试与文档起草 | GDScript 实现、数据表结构、GUT 用例、构建与部署文档、双语文本草稿 | 作者确定玩法与架构，逐项审查代码、修正实现、运行测试并验收界面；不以模型输出替代人工确认 |
| WorkBuddy ImageGen | 位图 UI 素材 | UI 图标与面板底图；具体文件以 `素材授权清单.csv` 的生成工具字段为准 | 作者设计风格与提示词，筛掉不合格结果，去背、裁切、缩放并统一接入 UI |
| Pixel Art Studio（MIT） | 程序化像素美术工具链 | 角色、瓦片、主菜单夜景、光标与 UI 控件的确定性绘制脚本和导出图集 | 作者确定画布、调色板、轮廓、帧数与文化取向；每轮看图检查并修改 `build.py`，不手改导出的 PNG |
| Python / Pillow | 图像生成与图集烘焙 | CharacterForge 部件、待机/行走条、瓦片、UI 控件与验收合图 | 作者检查关节、握持、阵营隔离、帧连续性和实际 Godot 场景显示 |
| tesseract、trafilatura、pdftotext | 文化资料检索与文本化 | 仅用于地方史、汤和信俗与永昌堡资料的本地研究 | 作者核对人物、年代、地点与叙事边界；原始 PDF、OCR、缩略图和联系表不随仓库或发行版分发 |
| Bun / TypeScript、ffmpeg、ffprobe | 构建辅助与媒体检查 | JSON 数据校验、音频转码、响度/时长/帧数检查 | 作者确定转换参数与验收标准，逐项复核产物 |
| 生成式语音实验 | 历史本地实验 | 未分发任何生成语音；运行时剧情使用双语定时字幕 | 输出权利未核实，18 个 OGG 已全部移除；模型权重与推理运行时不在发行包 |

AI 辅助不改变以下事实：项目代码与原创资产由作者选择、编排、修改和验收；
第三方素材保留原作者署名与原许可；AI 生成内容的权利状态按适用法律处理，
本项目不对纯模型输出主张超出法律允许范围的排他权利。

## 3. 当前 AI 相关产物

### 3.1 图像与像素资产

- `game/assets/ui/`：位图 UI 图标与面板底图。ImageGen 产物经过人工筛选、去背、
  裁切与缩放；按钮、滑条、开关和滚动条另由
  `pixel-art/ui_kit/build.py` 程序化绘制。
- `game/assets/character_forge/`：CharacterForge 的裸体基底、服装、头饰、背挂、
  武器和副手图集。由 `pixel-art/character_forge/build.py` 按确定性规则绘制。
- `game/assets/units/forge/`：正式角色、敌兵与佣兵的待机/行走条。由
  `pixel-art/character_forge/bake_battle_sprites.py` 从合法
  `character_recipe` 烘焙；战斗、选择页与序章只使用这些文件。
- `game/assets/tiles/yongchang/`：原创明式抗倭瓦片与环境动效。
- `game/assets/ui/menu_*.png`、`watch_cursor.png`：原创主菜单分层夜景与游戏光标。
- `game/assets/icons/game_icons/`：第三方 game-icons.net SVG，不是 AI 生成；
  运行时仅着色，不改变图形。

以上像素资产不是扩散模型生成的成品图。AI 参与的是绘制代码与工作流编写，
美术结果由可重跑的 Python/Pillow 规则生成并由作者逐轮视觉验收。

### 3.2 文本、数据与剧情

- `game/data/*.json` 的卡牌、兵器、敌兵、地图、波次、军市、图鉴与剧情结构由
  AI 辅助起草，作者完成文化核查、数值取舍与运行时验证。
- 剧情每句包含 `category`（史实/制度/民俗/演绎）和 `source_ref`。没有公开
  史料支撑的台词明确标为“演绎”，不冒充史料。
- 1386 序章主角为汤和；1559 正篇唯一可操作人物为虚构守灯乡勇王陆（乳名阿六）。
  六张选择卡是王陆的守夜阵位，不是六名独立人物。

### 3.3 代码与构建

- GDScript、测试、构建工具和文档在 AI 辅助下编写，由作者确定架构、审查差异、
  运行 GUT、检查场景与导出产物。
- CharacterForge、瓦片、UI 和菜单背景的 Python 生成器可由对应 `build.py`
  重建；导出的 PNG 不手工修改。
- Web 构建使用 Godot 官方 SCons 参数、Emscripten 稳定工具链和 Binaryen
  `wasm-opt`，不使用自写 wasm 分片或浏览器端拼接脚本。

## 4. 人工修改与质量控制

1. **方向与范围**：作者确定 16 分钟割草生存、灯火风险收益、双堡叙事、
   角色阵营隔离和 Web 单文件产物策略。
2. **代码审查**：逐项检查 AI 生成的 GDScript 接口、节点连接、存档迁移、
   输入锁、空间哈希、渲染批次与导出过滤。
3. **美术验收**：每轮导出后查看角色、敌兵、瓦片、UI 和菜单图集；
   修正关节、握持、阵营混装、瓦片接缝、可读性和缩放伪影。
4. **叙事核查**：按公开史实桥“洪武十九年汤和筑宁村所 → 嘉靖三十七年王德移师
   宁村策应 → 次日殉国金岙 → 王氏筑永昌堡 → 1559 守灯”检查台词与图鉴边界。
5. **构建验证**：在 Godot 4.7.2-stable 上运行 GUT、场景预检与导出；
   检查 PCK/ZIP 法律文件、禁止路径、Web 单线程配置、wasm/PCK 文件大小和
   EdgeOne 生产环境。
6. **媒体验收**：封面与演示视频由作者确定脚本、画面顺序与字幕；检查解码、
   帧数、音视频时长、响度和首尾画面。媒体不进入 Git 仓库。

## 5. 第三方素材

| 素材 | 作者 | 许可 | 用途与修改 |
|---|---|---|---|
| Godot Engine | Godot contributors | MIT | 游戏引擎；项目锁定 4.7.2-stable |
| GUT 9.7.1 | Bitwes 与贡献者 | MIT | 仅测试，不进入发行包 |
| Pixel Art Studio | Gamezxz | MIT | 开发期像素工具；不进入发行包 |
| game-icons.net SVG 101 个 | Delapouite、Lorc、Skoll、Willdabeast、Faithtoken、Caro Asercion | CC BY 3.0 | UI 与卡牌图标；运行时着色，图形未改；逐项来源见 `ATTRIBUTION.md` |
| LXGW WenKai / 霞鹜文楷 | LXGW / Klee Project | SIL OFL 1.1 | 全局字体；TTF 转为 WOFF2 以缩小 Web 包，字形未改 |
| Samurai Nights | Maik Hoffmann (Majadroid) | CC BY 4.0 | 主菜单/选择页 BGM；MP3 转 OGG |
| Views From Atop the Jade Kings Throne | Hitctrl | CC BY 3.0 | 关于页 BGM；原始 OGG |
| Hard Battle 1 | MintoDog | CC0 1.0 | 正篇战斗 BGM；原始 OGG |
| OpenGameArt 与 Kenney 音效 | 逐项见 `game/assets/audio/LICENSES.md` | CC0 1.0 | 20 个运行时 SFX；响度归一化、截短与 OGG 转码 |
| Jeff-FX-forge 1.1 | Jeff Studio | 代码 MIT；预设特效 CC0 1.0 | 战斗特效图集；帧矩形和锚点接入项目数据 |
| golden-ui / Free UI Asset Pack 1 | buch / ctatz | CC0 1.0 | 面板裁切与符号染色 |
| Dungeon Crawl Stone Soup 图块 106 张 | DCSS contributors | CC0 1.0 | 保留作历史参考；当前地图使用项目原创瓦片 |
| 2026 OSGJ 组委会文化资料 | 各原作者 | 原权利保留 | 仅本地考据；原始包、OCR、图片和主题密钥不进入仓库、发行包或演示视频 |

完整来源链接、修改说明、逐文件许可和是否入包见
[素材授权清单.csv](素材授权清单.csv)、[NOTICE](NOTICE)、
[game/data/credits.json](game/data/credits.json) 与
[game/assets/audio/LICENSES.md](game/assets/audio/LICENSES.md)。

## 6. 许可与分发

- **代码**：AGPL-3.0-or-later，全文见 [LICENSE](LICENSE)。分发修改版或提供网络交互时，
  按 AGPL 提供对应源码。
- **原创非代码资产**：CC BY 4.0，全文见
  [LICENSE-CC-BY-4.0.txt](LICENSE-CC-BY-4.0.txt)。转载须署名 xingwangzhe、
  链接许可并注明修改。
- **原创音频**：明确标注的原创母版可选 CC0 1.0 或 CC BY 4.0；既有 CC0 奉献保留。
- **第三方内容**：保留原许可。不得把整个仓库或发行包重新许可为单一许可。
- **字体**：OFL 1.1；保留字体名 `霞鹜`、`霞鶩`、`落霞孤鹜`、`落霞孤鶩`、`LXGW`。

## 7. 公开仓库边界

以下内容只在本地保留，不进入公开仓库或发行包：

- 设计稿、内部数值表、评审记录、调研草稿与一次性脚本；
- 赛事官网抓取缓存、主题载荷、密钥、站点图片和榜单原始数据；
- 授权未明的 PDF、DOCX、OCR、缩略图、联系表与第三方参考包；
- 截图、演示视频、导出包、调试日志、缓存和本地验收产物。

具体忽略规则见 [.gitignore](.gitignore)。公开文化索引只保留可公开复述的结论与来源，
不包含研究过程或未授权原文。

## 8. 赛事合规对照

| 要求 | 处理 |
|---|---|
| 申报赛前已有代码、工具与素材 | 第 1 节；第三方工具与素材逐项列明 |
| 作品原创、来源与授权清晰 | 第 3、5、6 节；逐文件清单随仓库提供 |
| AI 工具、用途、生成内容与人工修改 | 第 2、3、4 节 |
| 完整 AI 使用与素材声明 | 本文件；随仓库、源码包和发行说明提供 |
| 开源奖：公开源码、可运行版本与说明 | GitHub 仓库、README、四平台 Release 与在线 Web 版 |
| Dora 开源社区奖：Dora 兼容版本 | `dora/init.lua`、`dora/build.py` 与 [DORA.md](DORA.md) |
| 第三方素材逐项署名 | `game/data/credits.json`、关于页滚幕与 `素材授权清单.csv` |

外部平台事项（B 站视频、原子派 20 个点赞、AtomGit 提交、赛事互评）需在对应平台实际完成后填写，
不能用本地构建结果推定完成。
