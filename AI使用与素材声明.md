# 《守望·永昌》AI 使用与素材声明

| 项目 | 内容 |
|---|---|
| 文档版本 | v1.9 |
| 更新日期 | 2026-11-22 |
| 适用阶段 | 资料收集、设计、Godot 可玩原型、美术重构、UI/HUD、音频与装饰、**永昌堡地形重构 / 定时出兵重构 / 侧栏与滚幕** 阶段 |
| 对应赛事要求 | 2026 开源游戏开发大赛 第五节「内容要求」、第六节「提交材料」、第八节「Dora 开源社区奖」 |
| 逐项清单 | [素材授权清单.csv](素材授权清单.csv)（169 条：含建筑与 UI 素材、8 组 CC0 角色序列帧、第三方音频 1 BGM + 9 音效、第三方 UI 装饰 10 张成品、DCSS 地形具名图块 106 张及索引/文档/脚本条目） |
| 署名呈现 | 游戏内电影式片尾滚幕 `game/scenes/credits.tscn`，数据源 `game/data/credits.json`，逐项含可点击来源链接 |

> 本声明按赛事规则「须申报赛前已有的代码、工具与素材；作品原创，素材来源与授权清晰」「鼓励 AI 辅助创作；使用时须如实说明工具、用途、生成内容与人工修改情况」编制。
> 最终提交前须更新版本号、产出清单与锁定提交哈希，并补齐开发者日志。

---

## 一、申报概要

1. **赛前已有的代码、工具与素材**：无。本项目于 2026-11-22 从空目录初始化，所有设计文档、数据表与素材均在本届开发期内产生。
2. **作品原创性**：游戏概念《守望·永昌》、四阶兵种体系、文化机制转译、关卡结构与数值框架为本项目原创，未使用任何已基本完成的旧项目或换皮内容。
3. **第三方素材进入成品比例**：地形使用 **Dungeon Crawl Stone Soup（DCSS）CC0 图块 106 张**（墙 12 / 地面 54 / 水 26 / 门 5 / 树 9，32×32），按语义分区铺设、未重新着色；角色序列帧使用 **daniloMattos「Simple animated character」与 sebshady「Samurai Sprites」两套 CC0 原帧**，人工重着色并绘制明代乡兵与倭寇道具（详见第五节 5.4）。组委会提供的素材包与官网图片仍仅用于文化考据，未直接嵌入成品。**原 v2 采用的 RWX 派生切图与旧 Hard Vacuum 图块均已全部移除**。
4. **AI 生成素材进入成品比例**：当前成品中的 AI 生成部分为建筑动画、UI 图标与面板；早期批次 42 张 PNG 保留在 `assets/` 作溯源，不再作为当前兵种成品。角色序列帧为第三方 CC0 原帧加人工改绘，地形、BGM、音效、字体与 UI 装饰均为第三方开放许可素材。
5. **许可策略**：项目代码采用 **GPL-3.0-or-later**（许可证全文见仓库根目录 `LICENSE`），原创非代码资产采用 **CC BY 4.0**，第三方内容保留原许可（CC0 / CC-BY 3.0 / OFL 1.1）并逐项署名；全部署名以电影式片尾滚幕呈现，条目可点击溯源。

---

## 二、AI 工具使用明细

按赛事要求，逐项说明工具、用途、生成内容与人工修改情况。

| 工具 | 用途 | AI 生成 / 输出内容 | 人工修改与介入 |
|---|---|---|---|
| **WorkBuddy ImageGen**（内置图像生成） | 游戏美术生产 | 早期批次 42 张 PNG（6 静态 + 36 序列帧，保留溯源）；当前成品使用建筑动作 12 张与 UI 素材批次 11 张（10 图标 64×64 + 1 面板 512×512） | 人工设计提示词与风格基线；建筑按正面+俯视 2.5D 重做；UI 批次逐张人工验收联系表；生成后分拣、去背、切帧并缩放 |
| **WorkBuddy 会话助手**（大语言模型） | 资料归纳、游戏设计、数值设计、文档撰写 | 比赛规则归纳、主题解读、GDD v0.1/v0.2、Mindustry 借鉴分析、60 兵种扩展设计、4 张 CSV 数据表、知识图谱与视觉标注 | 人工确认设计方向（暴兵+塔防+建筑+文化闯关）、选择美术风格与实现范围、审校文化考据与数值平衡；表格由脚本从 CSV 生成以保证一致性 |
| **web-access / CDP 浏览器自动化** | 采集赛事官网公开信息 | 官网页面原文、资源清单、站点图片、榜单 API 数据；加密主题载荷与密钥 | 人工核对路由范围与下载清单；AES-GCM 解密脚本由会话助手生成、人工确认结果；仅采集公开可访问内容 |
| **tesseract（chi_sim+eng）** | 参考资料 OCR | 44 张文化图片的 OCR 文本（约 9.4 万字符） | 人工抽样核对识别结果，写入图片视觉标注与知识图谱 |
| **trafilatura / pdftotext / ZIP+XML 解析** | 文本抽取 | 页面 Markdown、552 页永昌堡 PDF 全文、DOCX/DOC 文本 | 人工按目录归类、建立索引与实体谱 |
| **PIL / Pillow** | 图片后处理 | 缩略图、4 张联系表、透明背景素材 | 人工编写后处理脚本：边缘 flood fill 去米色背景、去右下角水印、裁切留白、nearest 缩放至 512×512 RGBA、统一命名 |
| **ffmpeg** | 素材检查与音频转换 | 抽帧验收板；第三方音频响度归一化、截短、OGG 转码 | 人工查看并判断帧间一致性；人工审校音频转换参数 |
| **OpenGameArt.org 素材采集** | 第三方音频素材获取 | BGM「Samurai Nights」及 9 个 CC0 音效原始文件（curl 直链下载） | 人工/助手逐项核查页面许可标注、作者与来源 URL；仅采用 CC0 或 CC-BY（可商用）素材 |

**未使用**：第三方付费素材库、未授权网络图片、他人游戏源码、生成式语音/音乐（截至本版本）。

---

## 三、AI 生成内容清单

> **补充（2026-11-22 晚，v1.5 第三方 UI 装饰）**：按「装饰素材可商用 + 通用化 + 契合深底金描边风」要求，引入 OpenGameArt 两套 **CC0** 素材：**golden-ui by buch**（裁切琥珀金像素面板 `panel_gold.png` 作九宫格面板）与 **Free UI Asset Pack 1 by ctatz**（9 枚白色符号染金色 → 通用图标：播放/设置/信息/关闭/暂停/音量/静音/勾选/奖杯）。经 `tools/process_thirdparty_ui.py` 处理，`game/scripts/ui/ui_kit.gd` 作统一出口接入主菜单按钮、关于/设置/HUD 暂停与结算/事件横幅面板。TASL 逐项登记见 `generated/ui_thirdparty/LICENSES.md`。
>
> **补充（2026-11-22 晚，v1.4 音频来源调整）**：应素材策略要求（**长音乐/短音效优先采用 CC0 或免费可商用现成素材，脚本合成仅作兜底**），工程 `game/assets/audio/` 全部音频已更换为第三方素材：BGM 采用 OpenGameArt 的 **「Samurai Nights」by majadroid（CC-BY 3.0，二胡/笛/古琴中式器乐）**，9 个事件音效取自 OpenGameArt 的 CC0 音效包（Kenney / artisticdude / remaxim / ogrebane / wobbleboxx），经 `tools/process_thirdparty_audio.py` 响度归一化、截短与 OGG 转码后嵌入。TASL 逐项登记见 `generated/audio_thirdparty/LICENSES.md`；原合成工具 `tools/generate_audio.py` 保留为**短音效兜底方案**（当前无成品使用）。中文 UI 字体统一采用 **lxwk（霞鹜文楷 / LXGW WenKai）**，已设为 Godot 工程全局默认字体；字体许可 **SIL OFL 1.1**，完整协议文本随字体存放于 `assets/fonts/OFL.txt` 与 `game/assets/fonts/OFL.txt`。

### 3.1 图像资产（`assets/` 与 `game/assets/`）

**早期批次（`assets/`，保留作溯源）**

| 类别 | 数量 | 生成方式 | 状态 |
|---|---|---|---|
| 兵种静态图 | 3 | 文本生图 | 已后处理，透明背景 |
| 兵种跑步帧 | 12 | 以静态图为参考的图生图 | 已后处理，4 帧/单位 |
| 兵种攻击帧 | 12 | 以静态图为参考的图生图 | 已后处理，4 帧/单位 |
| 建筑静态图 | 3 | 文本生图 | 已后处理 |
| 建筑工作帧 | 12 | 以静态图为参考的图生图 | 已后处理，4 帧/建筑 |
| 预览联系表 | 4 | 由上述素材用 PIL 拼图 | 派生资产，非独立生成 |

**建筑与 UI 批次（`game/assets/`，当前成品实际使用）**

> 2026-11-22 晚按统一规格重做：建筑为**正面+俯视 2.5D**。角色序列帧随后改用 CC0 原帧与人工改绘，不再使用 ImageGen 兵种成品。原始条带图存 `generated/` 供溯源。

| 类别 | 数量 | 规格 | 生成方式 |
|---|---|---|---|
| 建筑攻击/生产/激活帧 | 12 | 96×96 RGBA | ImageGen 4 帧条带 → 同上处理 |
| 建筑静态图 | 3 | 96×96 RGBA | 首帧派生 |

合计：早期批次 **42 张 PNG + 4 张 JPG**；当前 AI 成品为建筑 **15 张 PNG** 与 UI **11 张 PNG**；7 张原始条带保留溯源。

**CC0 角色精灵批次（`game/assets/units/`，当前成品实际使用）**

| 类别 | 数量 | 规格 | 来源与处理 |
|---|---|---|---|
| 友军序列帧 | 3 组 | 64×64 RGBA，4 帧跑 + 4–5 帧攻击 + 静态 | daniloMattos CC0 原帧；重着色、去底影、绘制头巾/短刀/弓/龙头 |
| 倭寇序列帧 | 5 组 | 64×64 RGBA，4 帧跑 + 4–5 帧攻击 + 静态 | daniloMattos / sebshady CC0 原帧；重着色、绘制头巾/火绳枪/藤牌/盔饰 |

流水线：`tools/process_cc0_sprites.ts`。原始条带保存在 `generated/sprites_thirdparty/raw/`，许可登记见 `generated/sprites_thirdparty/LICENSES.md`。

**UI 素材批次（2026-11-22 晚，`game/assets/ui/`，当前 HUD 实际使用）**

| 类别 | 数量 | 规格 | 生成方式 |
|---|---|---|---|
| 资源图标（粮/银/弹/主堡） | 4 | 64×64 RGBA | ImageGen 4 联条带 → `tools/process_ui_sprites.py` 切图抠图 |
| 建造图标（箭塔/军械坊/烽火台） | 3 | 64×64 RGBA | ImageGen 3 联条带 → 同上 |
| 出兵图标（乡勇/弓手/龙灯队） | 3 | 64×64 RGBA | ImageGen 3 联条带 → 同上 |
| 面板底板 | 1 | 512×512 RGBA | ImageGen 单张 → 去白底缩放 |

合计：UI 批次 **11 张成品 PNG** + 4 张原始条带（`generated/ui_art/`，溯源不入成品）。图标经边界 flood fill 去白底、抗锯齿白点二轮清除、tight crop、nearest 缩放；联系表人工逐张验收后导入工程并接入 HUD（顶栏 chip 图标 + 底栏建造/出兵按钮图标）。逐文件路径见 `素材授权清单.csv`。

### 3.2 文本与数据资产

| 文件 | AI 参与方式 | 人工介入 |
|---|---|---|
| `docs/比赛规则与主题归纳.md` | 从爬取原文归纳 | 人工核对规则条款与奖项条件 |
| `docs/06-资料文本化/AI资料索引与知识图谱.md` | 实体抽取与关系整理 | 人工核对人物、地点、年代等关键事实 |
| `docs/06-资料文本化/图片视觉标注.md` | 图像内容描述 | 人工复核五龙配色、拼字内容等文化元素 |
| `design/游戏设计文档-GDD.md` | 完整撰写 | 人工定方向、取舍系统优先级 |
| `design/Mindustry借鉴分析.md` | 联网调研与机制转译 | 人工确认三层落地方案 |
| `design/兵种扩展设计.md` | 调研与 60 兵种设计 | 人工确认阶位结构、文化映射与数值带宽 |
| `design/data/*.csv` | 数值表生成 | 人工校验字段、BOM、ID 唯一性与行数 |

### 3.3 代码

Godot 工程 `game/` 的运行代码由 WorkBuddy 会话助手（LLM）辅助编写，人工确认架构、接口契约与逐项验收。主要文件：

| 文件 | AI 参与方式 | 人工介入 |
|---|---|---|
| `game/scripts/main.gd` | 主场景玩法编排（定时出兵、建造链路、选择链路、右栏联动、终局判定） | 人工定玩法方向：撑到时限即胜、城镇血量归零失败；统一接线各子系统 |
| `game/scripts/spawn_system.gd` | 定时出兵系统（Mindustry 式 waveInterval / waveSpacing 双计时器，难度按波号递增） | 人工定节拍参数（准备期 20s、波间隔 26s、波内 0.8s）、数量上限与兵种解锁梯度 |
| `game/scripts/build_system.gd` | 多格建造系统（Mindustry 式 multiblock 占格） | 人工定 3×3 占格、水域/城墙/主堡禁建、资源校验规则 |
| `game/scripts/tile_catalog.gd` / `tile_map_builder.gd` | DCSS 具名图块目录（名字→图块映射）+ 永昌堡地形分区铺设（城墙/瓮城/护城河/上河下河/河浃/农田/驿道） | 人工否决「随机取块拼凑」，改为按语义具名引用；逐块测量四边不透明度、亮度与接缝比后选材；人工依据《永昌堡十三进士与抗倭纪略》原文核城池形制（周长 2688m、四门四水门、十二敌台、二十铺舍、二百余亩水田） |
| `game/scripts/unit.gd` / `tower.gd` | 单位双向行进、塔索敌与攻击动画；单位交战系统（数值表 + 索敌停走 + 攻击硬直）、头顶血条；塔射程圈绘制 | 人工发现「单位互穿不交战」玩法缺口并定拦截方案；人工修复 tscn 注释导致 Sprite 节点丢失的解析 bug |
| `game/scripts/hud.gd` | 战斗 HUD：顶栏资源 chip 与主堡血条、波次倒计时、事件横幅、暂停/结算面板 | 人工定 UI 规划原则（不遮挡地图、面板化布局）；修复 Control 锚点与 Variant 推断导致的渲染 bug |
| `game/scripts/ui/sidebar_panel.gd` | 右侧栏：默认隐藏，选中对象或打开建造菜单才出现；建造菜单/生产队列/只读详情三态 | 人工定「默认右栏不出现」「点建筑改右栏」的交互规则 |
| `game/scripts/ui/minimap_panel.gd` | 右上角小地图：逐格读取 Ground/Road/Structure/Decor 四层真实图块并合成底图；图层变动自动重采样；单位点、建筑、视口框与历史地名 tooltip | 人工定尺寸 222×222 与跳转/拖拽行为；人工否定独立手绘色表，要求小地图始终从大地图取样 |
| `game/scripts/ui/credits_roll.gd` | 电影式片尾滚幕：自然匀速滚动 + 鼠标滚轮/拖拽/键盘自由操控 + 可点击链接 | 人工定「自然滚动优先、手动操作后自动恢复」的节奏规则 |
| `game/scripts/build_preview.gd` | 建造 3×3 占格预览（合法绿/非法红，仅放置模式显示） | 人工定判定反馈配色与跟随鼠标定位规则 |
| `game/tests/verify.gd` | 自动化断言（含地形分区、定时出兵曲线、建造合法性、滚幕数据完整性） | 人工设计覆盖点，捕获并修复解析与逻辑 bug |
| `game/scripts/autoload/audio_manager.gd` | 音频管理：BGM 循环、SFX 池、音量分离与配置持久化 | 人工定音效事件映射、音量对数与退出资源释放 |
| `game/scripts/autoload/game_flow.gd` | 场景导航：主菜单/战斗/设置切换 | 人工定界面流转与设置返回栈 |
| `game/scripts/ui/*.gd` / `scenes/main_menu.tscn` / `scenes/settings.tscn` | 主菜单、设置、暂停面板、国风背景绘制、`ui_kit.gd` 通用装饰套件（金框面板九宫格 + CC0 图标接入） | 人工定 UI 结构、lxwk 字体统一、国风配色与交互；修复隐藏面板抢焦点 bug |
| `tools/process_new_sprites.py` / `tools/process_ui_sprites.py` | 切帧与切图抠图脚本 | 人工调参（chroma、白底阈值、缩放尺寸） |
| `tools/process_cc0_sprites.ts` | CC0 角色原帧抽帧、重着色与道具绘制流水线 | 人工定兵种轮廓、配色、武器位置与帧数；逐帧联系表验收 |
| `tools/process_thirdparty_audio.py` | 第三方音频转换流水线（响度归一化、Alarm 截短、OGG 转码） | 人工定响度目标与截短时长；人工选曲与逐项映射音效 |
| `tools/generate_audio.py` | 短音效合成兜底工具（五声音阶加法合成，当前无成品使用） | 人工定「第三方素材优先、合成兜底」策略 |
| `tools/process_thirdparty_ui.py` | 第三方 UI 装饰流水线（golden-ui 面板裁切、ctatz 符号染金色） | 人工选源、定裁切框与金色基线；联系表人工验收 |

项目代码许可 **GPL-3.0-or-later**。

---

## 四、人工修改与质量控制

为区分「AI 直接输出」与「人工创作成果」，记录以下实际介入点：

1. **风格基线确立**：人工选定国风像素风、青灰城墙 + 暖红/金/翡翠绿 + 米色调，兵种横版侧视、建筑等距视角。
2. **提示词设计**：逐单位、逐动作编写提示词；序列帧用 `Frame A/B/C/D` 前缀锁定动作阶段，规避并行生成时的文件名冲突。
3. **生成结果分拣**：并行生图出现输出目录串目录问题，人工按图内容识别并移动到正确单位目录。
4. **像素级后处理**：去米色背景、去水印、裁切、nearest 缩放、统一 512×512 RGBA；建筑图使用更宽松阈值清理残留。
5. **验收与取舍**：生成联系表逐张检查，保留可用帧；发现烽火台静态图噪点后改用帧图作为正式资源。
6. **设计审校**：兵种数量与阶位结构参考《米拉奇战记》公开资料，人工确认口径差异（49 种分类清单 / 57 种含替换兵种）并如实记录，不做唯一化断言。
7. **数据一致性**：设计文档中的 60 行兵种表由脚本从 CSV 生成，避免手写与数据表不一致；校验字段数、ID 唯一性与四阶各 15 种。

---

## 五、素材来源与授权

### 5.1 AI 生成资产

- 范围：`assets/` 下全部 PNG 与预览 JPG。
- 授权：作为本项目原创非代码资产，采用 **CC BY 4.0** 许可（若申请 Dora 开源社区奖，按赛事要求执行）。
- 权利说明：AI 生成内容的著作权认定在不同法域存在差异。本项目不主张对纯 AI 原始输出享有排他著作权；对人工提示词设计、筛选、编排、后处理所形成的汇编与衍生结果，在适用法律允许范围内主张相应权益。赛事申报中如实披露 AI 参与情况。

### 5.2 第三方参考资料（均未进入成品）

| 来源 | 内容 | 授权状态 | 使用方式 |
|---|---|---|---|
| 2026 OSGJ 官网下载区 | 汤和信俗素材包（`汤和信俗(11.18).zip`，含 42 JPG / 2 PNG / 3 DOCX / 1 DOC / 1 PDF） | 未见明确开放许可声明 | 解压、OCR、文本化，仅用于文化考据；原始包已从 Git 库排除 |
| 2026 OSGJ 官网下载区 | 《永昌堡十三进士与抗倭纪略内文9.14.pdf》（552 页） | 未见明确开放许可声明 | 抽取全文用于史实考据；未复制原文入游戏 |
| 2026 OSGJ 官网 | 站点图片、合作伙伴标识 | 原权利归各权利人 | 仅存档与界面风格参考 |
| 2026 OSGJ 官网 | 主题加密载荷、密钥、榜单 API 数据 | 赛事官方公开信息 | 主题解读与资料归档 |

**处理原则**：授权不明的第三方内容一律不进入成品、演示视频与封面；如需使用，须先取得权利人许可并在本声明中署名与补充许可条款。

### 5.3 工具与引擎

- 游戏引擎：Godot（开源，MIT 许可）——引擎本身不属于项目资产，按原许可使用。
- 开发与采集工具：Python 3、PIL、Bun、Sharp、tesseract、trafilatura、pdftotext、Chrome DevTools Protocol、Git——均为通用工具，其输出数据按本节分类处理。

### 5.4 第三方可商用素材（CC0 / CC-BY 3.0 / OFL 1.1）

| 素材（Title） | 作者（Author） | 来源（Source） | 许可（License） | 修改说明 |
|---|---|---|---|---|
| Dungeon Crawl Stone Soup **具名图块 106 张** | DCSS contributors（维护：Chris Hamons；原始美术含 DENZI 等多人） | https://opengameart.org/content/dungeon-crawl-32x32-tiles | CC0 1.0（公有领域贡献） | 原始包逐块导出为 32×32 PNG，保留 light/dark 等原始文件名；**未改色**，仅建立语义分组与确定性取块。索引 `game/assets/tiles/dcss/manifest.csv` |
| Simple animated character | daniloMattos | https://opengameart.org/content/simple-animated-character | CC0 1.0 | 抽取 64×64 行走/近战/远程帧；按兵种重着色；手工绘制短刀、弓、火绳枪、龙头与头巾；清底影；输出 64×64 RGBA |
| Samurai Sprites | sebshady | https://opengameart.org/content/samurai-sprites | CC0 1.0 | 抽取 48×48 侧向行走/攻击帧；重着色；手工绘制藤牌、肩甲与盔饰；输出 64×64 RGBA |
| Samurai Nights（Demo） | Maik Hoffmann（majadroid） | https://opengameart.org/content/samurai-nights | CC BY 3.0（亦提供 CC-BY 4.0 / OGA-BY 3.0） | MP3 → OGG Vorbis 重编码（游戏内 BGM） |
| Battle Sound Effects: Bow / RPG Sound Pack / 3 Melee Sounds / RPG Audio / Sound Pack 01 | ogrebane / artisticdude / remaxim / Kenney / wobbleboxx | https://opengameart.org/content/battle-sound-effects 等（逐项见 `generated/audio_thirdparty/LICENSES.md`） | CC0（多许可包选用 CC0） | 响度归一化、Alarm 截短 2.2s、OGG 转码（游戏内 9 个事件音效） |
| golden-ui / Free UI Asset Pack 1 | buch / ctatz | https://opengameart.org/content/golden-ui ；https://opengameart.org/content/free-ui-asset-pack-1 | CC0 | 面板精灵裁切（九宫格）；白色符号染金色缩放 64×64（游戏内 UI 装饰与图标，详见 `generated/ui_thirdparty/LICENSES.md`） |
| 霞鹜文楷 LXGW WenKai | LXGW（落霞孤鹜） | https://github.com/lxgw/LxgwWenKai | SIL Open Font License 1.1 | 未修改字体文件；随包 `game/assets/fonts/OFL.txt` |

- 用途：`game/assets/tiles/dcss/{wall,floor,water,door,tree}/*.png` 按**语义分区**铺设永昌堡地形（城内水田/夯土院落/街巷、灰石城墙、护城河与上河下河水面、东海滩涂、驿道、门与植被）。**图块一律按名引用**（`TileCatalog` 名字→图块映射），同一语义大面积只取一块，区域级换材质，禁止跨语义随机取块。
- 转换链：DCSS 原始包 → 逐块导出 32×32 PNG（`manifest.csv` 记录 category/name/opaque/edge_opaque/tileable）→ `TileCatalog` 建立具名查表 → `TileMapBuilder` 分区铺设。CC0 来源链完整。
- **已移除**：v1 `atlas_geology.png` 重着色图集、v2 由第三方 RWX 项目切分的 20×20 Tiled 图块集（`tiles/hv/**`）及其构建脚本、旧 Hard Vacuum 图块与切图脚本，均不再进入成品与仓库。
- 署名（片尾滚幕 `game/data/credits.json` 中为可点击条目）：
  > Terrain tiles from "Dungeon Crawl Stone Soup" by DCSS contributors, dedicated to the public domain under CC0 1.0. Source: https://opengameart.org/content/dungeon-crawl-32x32-tiles. Changes: exported as 32x32 PNG tiles and grouped semantically; colours unmodified.
  > Music: "Samurai Nights" by Maik Hoffmann (majadroid), licensed CC-BY 3.0. Source: https://opengameart.org/content/samurai-nights. Changes: re-encoded to Ogg Vorbis.
  > Sound effects from OpenGameArt.org, CC0: Bow (ogrebane), Melee Sound (remaxim), Chop (Kenney), Sword Unsheath / Metal Ringing (artisticdude), Rise01 / Alarm / Upper01 / Downer01 (wobbleboxx).
  > Font: LXGW WenKai by LXGW, licensed SIL OFL 1.1. Source: https://github.com/lxgw/LxgwWenKai.
  > UI: golden-ui (buch, CC0), Free UI Asset Pack 1 (ctatz, CC0).
- 合规说明：DCSS 图块为 CC0 1.0 公有领域贡献，允许商用与改编且不强制署名；本项目仍按 TASL（Title/Author/Source/License）完整披露，并在游戏内滚幕给出可点击链接。

### 5.5 设计参考（未复制代码）

| 项目 | 许可 | 用途 | 说明 |
|---|---|---|---|
| [OpenHV](https://github.com/OpenHV/OpenHV) | GPL-3.0 | 右栏结构、小地图、选择与建造链路的**交互参考** | 仅阅读其 `chrome/ingame-player.yaml` 等界面定义与规则文件，重写为 Godot 实现，未复制代码 |
| [OpenRA](https://github.com/OpenRA/OpenRA) | GPL-3.0 | 生产队列 / 侧栏逻辑 / 雷达组件的**结构参考** | 仅阅读引擎源码理解链路，未复制代码 |
| [Mindustry](https://github.com/Anuken/Mindustry) | GPL-3.0 | 定时出兵节奏（waveInterval / waveSpacing）与多格建筑的**思路参考** | 独立实现，未复制代码 |

> 本项目代码为 GPL-3.0-or-later，与上述参考项目许可兼容；即便如此，本项目仍以「独立实现」为准，未做代码搬运。

---

## 六、版权与许可声明

1. **项目代码**：原创代码采用 **GPL-3.0-or-later**，许可证全文见仓库根目录 `LICENSE`。任何分发或衍生作品须以同一许可开源并提供对应源码。
2. **原创非代码资产**：设计文档、数值表、AI 生成并后处理的图片采用 **CC BY 4.0**。转载须署名并注明许可。
3. **第三方内容**：成品地形使用 CC0 素材 DCSS 的 106 张具名图块（DCSS contributors）；角色序列帧基于 daniloMattos 与 sebshady 的 CC0 原帧并经人工改绘；成品音频引入 CC-BY 3.0 BGM「Samurai Nights」（majadroid）与 CC0 音效（OpenGameArt 多作者）；字体为 OFL 1.1 霞鹜文楷；UI 装饰为 CC0。均保留原许可并按 TASL 署名，详见 5.4、5.5 与各第三方目录下的 `LICENSES.md`。
4. **署名呈现**：全部署名以电影式片尾滚幕（自然滚动、可手动上下滚动、来源链接可点击）在游戏内呈现，数据源 `game/data/credits.json`，与 `素材授权清单.csv` 一一对应。
5. **赛事资料**：主题、规则、文化素材的权利归组委会及相关权利人；本项目引用仅限本届参赛用途。
6. **商标与标识**：官网合作伙伴标识未用于成品，不构成任何授权或背书表示。

---

## 七、赛事合规自查

| 规则条款 | 要求 | 当前状态 |
|---|---|---|
| 第五节 | 申报赛前已有代码、工具与素材 | 已申报：无（第一节） |
| 第五节 | 作品原创、素材来源与授权清晰 | 已声明；逐项清单见 `素材授权清单.csv` |
| 第五节 | AI 辅助创作如实说明工具、用途、生成内容与人工修改 | 已逐项说明（第二、三、四节） |
| 第六节 | 提交完整《AI 使用与素材声明》 | 本文件即声明；提交时随仓库提供 |
| 第八节 | 最佳视听奖：第三方素材 >50% 不参与 | 第三方素材为 CC0 DCSS 地形图块（已署名）与 CC-BY 3.0 BGM（已署名）+ CC0 音效，占成品素材比例远低于 50%，不构成排除情形 |
| 第八节 | Dora 开源社区奖：代码 GPL-3.0-or-later、原创非代码资产 CC BY 4.0、第三方保留原许可并署名 | 已按此策略声明（第六节），`LICENSE` 全文随仓库提供 |
| 第六节 | 提交材料含可追溯署名 | 游戏内片尾滚幕逐项列出作者/许可/可点击来源，数据源 `game/data/credits.json` |

---

## 八、待补充事项

提交锁定版本前须完成：

1. 将本声明版本号升至 v2.0，在提交锁定版本时更新最终素材清单与 Git 哈希。
2. 记录锁定提交的 Git 哈希与提交时间。
3. 补齐至少 3 篇内容不重复的开发者日志（赛事强制要求）。
4. ~~若引入音效、音乐、字体或第三方素材，逐项补入清单~~ 已完成：字体/DCSS 具名图块/建筑与 UI 素材/CC0 角色序列帧/第三方音频（BGM+音效）/第三方 UI 装饰均已登记（清单共 169 条）。
5. 若以私有项目提交，重新核对第六节许可声明与实际情况的一致性。
