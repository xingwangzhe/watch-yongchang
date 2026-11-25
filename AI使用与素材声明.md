# 《守望·永昌》AI 使用与素材声明

> **2026-11-25 整改状态**：旧守城玩法已移除；当前作品为 16 分钟 Vampire Survivors-like
> Roguelite，包含三张地图、七种兵器、十二种被动、首次教程、手动/自动攻击、箭塔连发与并发、
> 双语、自动存档、关于页与结算解锁。下文较早条目保留为历史溯源，不作为当前运行时依据；
> 正式角色外观只取 CharacterForge 的 `game/assets/units/forge/` 烘焙条。

> **公开仓库范围**：赛事官网抓取件、主题密钥、授权未明的原始参考资料、OCR、
> 缩略图、联系表与站点图片仅作本地研究，不随公开仓库、源码包或发行版分发。
> 下文对 `docs/01`–`docs/06` 原始语料的引用是本地研究记录；公开文化索引见
> `docs/06-资料文本化/*.md`。

| 项目 | 内容 |
|---|---|
| 文档版本 | v2.2 |
| 更新日期 | 2026-11-25 |
| 锁定版本 | Git 标签 `v0.1.0`；解析后的提交哈希记录于 GitHub Release 的 `release-manifest.json` 与赛事提交材料 |
| 适用阶段 | 资料收集、设计、Godot 可玩原型、美术重构、UI/HUD、音频与装饰、永昌堡地形重构 / 定时出兵重构 / 侧栏与滚幕、**明代兵种精灵重绘**、**主菜单动态夜景**、**原创明式抗倭瓦片**、**原创主角与敌兵精灵**、**音频确权与 MOSS 语音下线**、**开放许可 BGM 与事件音效**、**赛事封面与演示视频** 阶段 |
| 对应赛事要求 | 2026 开源游戏开发大赛 第五节「内容要求」、第六节「提交材料」、第八节「Dora 开源社区奖」 |
| 逐项清单 | [素材授权清单.csv](素材授权清单.csv)（含 UI 素材、已删除的 11 组旧兵种序列帧记录、开放许可音频 3 BGM（CC BY 4.0 / CC BY 3.0 / CC0）+ 20 CC0 音效、第三方 UI 装饰 10 张成品、101 个 game-icons.net SVG、**原创明式抗倭瓦片 88 格（地形 40 / 建筑 32 / 道具 16）**、历史 DCSS 地形图块 106 张及索引/文档/脚本条目；每行含 source_url、license_url、rights_status） |
| 署名呈现 | 游戏内关于页电影滚幕 `game/scenes/about.tscn` 与片尾滚幕 `game/scenes/credits.tscn`，数据源 `game/data/credits.json`，逐项含可点击来源链接 |

> 本声明按赛事规则「须申报赛前已有的代码、工具与素材；作品原创，素材来源与授权清晰」「鼓励 AI 辅助创作；使用时须如实说明工具、用途、生成内容与人工修改情况」编制。
> 三篇开发者日志已补齐；本声明随 `v0.1.0` 锁定版本提交，最终提交哈希与产物哈希以发布 manifest 为准。

---

## 一、申报概要

1. **赛前已有的代码、工具与素材**：无。本项目于 2026-11-22 从空目录初始化，所有设计文档、数据表与素材均在本届开发期内产生。
2. **作品原创性**：游戏概念《守望·永昌》、四阶兵种体系、文化机制转译、关卡结构与数值框架为本项目原创，未使用任何已基本完成的旧项目或换皮内容。
3. **第三方素材进入成品比例**：当前地图使用**项目原创明式抗倭瓦片 88 格**（地形 40 / 建筑与城防 32 / 道具 16，32×32，CC BY 4.0），由 `pixel-art/yongchang_tiles/build.py` 程序化绘制；新增山体、横纵桥面与栏杆，水面可通行，桥面连续且视觉与碰撞一致。历史 DCSS CC0 图块 106 张仍保留作参考，当前场景未引用。正式角色为 CharacterForge 程序化烘焙：1386 序章主角汤和；1559 正篇唯一主角为虚构守夜乡勇王陆，六张卡是同一人物的阵位；八类敌兵与八类佣兵使用 `game/assets/units/forge/` 待机/行走条。旧 `actors` 预览与旧兵种目录不作为正式外观来源。组委会素材仅用于文化考据，未直接嵌入成品。
4. **AI 生成素材进入成品比例**：当前成品中的 AI 生成部分为 UI 图标与面板；旧塔防建筑两套共 30 张 PNG 已从成品、原始素材与授权清单中清理，早期批次 27 张 PNG 及其根目录旧兵种图已删除，不再作为当前兵种成品。当前角色/敌兵外观为 CharacterForge 程序化合成；明式抗倭瓦片为**程序化像素绘制**（非扩散模型生图、无第三方角色骨架）。运行时 3 首 BGM 均为允许再分发的开放许可：菜单 **Samurai Nights（CC BY 4.0）**、关于页 **Views From Atop the Jade Kings Throne（CC BY 3.0）**、战斗曲 **Hard Battle 1（CC0 1.0）**；20 个 SFX 全部为 CC0 1.0。字体与部分 UI 装饰为第三方开放许可素材。
5. **许可策略**：项目代码采用 **AGPL-3.0-or-later**（全文见根 `LICENSE`，网络使用与对应源码义务见 `NOTICE`），原创非代码资产采用 **CC BY 4.0**（全文见 `LICENSE-CC-BY-4.0.txt`）。项目原创 BGM 母版与开发音效母版保留 **CC0 1.0 或 CC BY 4.0** 选择，既有 CC0 奉献不可撤销；第三方内容保留原许可（CC0 / CC BY 4.0 / CC BY 3.0 / OFL 1.1 / MIT / Apache-2.0）并逐项署名。关于页与片尾滚幕使用 `game/data/credits.json`，来源与许可链接可点击。

---

## 二、AI 工具使用明细

按赛事要求，逐项说明工具、用途、生成内容与人工修改情况。

| 工具 | 用途 | AI 生成 / 输出内容 | 人工修改与介入 |
|---|---|---|---|
| **WorkBuddy ImageGen**（内置图像生成） | 游戏美术生产 | 早期批次 27 张 PNG（3 静态 + 24 序列帧，保留溯源）；旧塔防建筑动作 12 张已清理；当前成品使用 UI 素材批次 11 张（10 图标 64×64 + 1 面板 512×512） | 人工设计提示词与风格基线；UI 批次逐张人工验收联系表；生成后分拣、去背、切帧并缩放 |
| **WorkBuddy 会话助手**（大语言模型） | 资料归纳、游戏设计、数值设计、文档撰写 | 比赛规则归纳、主题解读、GDD v0.1/v0.2、Mindustry 借鉴分析、60 兵种扩展设计、4 张 CSV 数据表、知识图谱与视觉标注 | 人工确认设计方向（暴兵+塔防+建筑+文化闯关）、选择美术风格与实现范围、审校文化考据与数值平衡；表格由脚本从 CSV 生成以保证一致性 |
| **web-access / CDP 浏览器自动化** | 采集赛事官网公开信息 | 官网页面原文、资源清单、站点图片、榜单 API 数据；加密主题载荷与密钥 | 人工核对路由范围与下载清单；AES-GCM 解密脚本由会话助手生成、人工确认结果；仅采集公开可访问内容 |
| **tesseract（chi_sim+eng）** | 参考资料 OCR | 44 张文化图片的 OCR 文本（约 9.4 万字符） | 人工抽样核对识别结果，写入图片视觉标注与知识图谱 |
| **trafilatura / pdftotext / ZIP+XML 解析** | 文本抽取 | 页面 Markdown、552 页永昌堡 PDF 全文、DOCX/DOC 文本 | 人工按目录归类、建立索引与实体谱 |
| **PIL / Pillow** | 图片后处理 | 缩略图、3 张联系表、透明背景素材 | 人工编写后处理脚本：边缘 flood fill 去米色背景、去右下角水印、裁切留白、nearest 缩放至 512×512 RGBA、统一命名 |
| **Bun / TypeScript / Sharp** | 历史原创像素兵种生成 | 11 组 64×64 RGBA 行走/攻击/静态帧；按明代与倭寇服饰、甲胄、武器参数绘制；现已删除，不再进入成品 | 人工确定兵种轮廓、帽式、甲片、武器位置、帧数与配色；逐帧联系表和主视口截图验收；后续角色改用 CharacterForge |
| **Pixel Art Studio**（MIT，`skills/pixel-art-studio/`） | 新像素素材生成 | 程序化绘制角色、兵器、图块与动画帧；当前明式抗倭 32×32 瓦片为 88 格（地形 40 / 建筑 32 / 道具 16），另新增 24×24 时代风格光标；角色由 CharacterForge 烘焙 | 人工定画布尺寸、调色板、轮廓规则与帧数；每轮渲染后看图自检并修改 `build.py`；瓦片按浙南沿海抗倭堡垒考据，正式角色按汤和/王陆阵位与敌兵配方生成，不手改 PNG |
| **ffmpeg / ffprobe** | 素材检查与音频转换 | 第三方音效响度归一化、截短、OGG 转码；第三方 BGM 的 MP3→OGG 转码与运行时恢复；原创 BGM 母版 WAV→OGG 编码；音频时长、声道、采样率与哈希核验 | 人工审校转换参数；逐条核对 OGG 时长、峰值与资源路径；2026-11-25 复核 OpenGameArt 页面后恢复两首 BGM |
| **Pillow + ffmpeg / ffprobe（赛事媒体）** | 赛事封面与演示视频编排、编码、验收 | 1920×1080 PNG 封面；91 秒、1920×1080、30 fps、H.264/AAC 演示视频；10 段原创字幕/标签/片尾排版 | AI 辅助编写临时生成/验证脚本，人工确定叙事顺序、文案与验收标准；仅使用已验收游戏截图和既有 CC0 BGM；人工查看封面、联系表与视频实际解码末帧；完整解码、2730 帧、音视频等长、响度与 SHA-256 均通过 |
| **MOSS-TTS-Nano 100M ONNX / Rust ONNX 运行时** | 历史剧情语音实验；现已停止分发 | 曾生成 9 段中文 + 9 段英文 OGG；因官方材料未明确授予生成音频输出许可，18 个文件已删除 | 保留 9 条双语字幕、说话人、音色偏好、category/source_ref 与按时长回退；`scripts/generate_voice.ts` 改为默认失败关闭，须同时更新清单并显式设置 `MOSS_OUTPUT_RIGHTS_VERIFIED=1` 才能再生成 |
| **OpenGameArt.org / Kenney.nl 素材采集** | 第三方音频素材获取 | 运行时 BGM：Samurai Nights（CC BY 4.0）、Views From Atop the Jade Kings Throne（CC BY 3.0）、Hard Battle 1（CC0）；20 个 CC0 音效 | 人工/助手逐项核查官方页面许可、作者、来源 URL 与修改记录；2026-11-25 再次确认两首前述 BGM 均为非 NC/ND 开放许可；Kenney UI Audio 与 Impact Sounds 均复核为 CC0 1.0 |
| **Python 标准库音频合成** | 原创 BGM 母版与开发音效母版 | 根目录菜单母版「Yongchang Watch / 永昌守望」、可再生成关于页母版「Watchfires of Credits / 守灯致意」及 9 个开发音效母版 | `tools/generate_audio.py` 以确定性的加法合成、噪声与包络生成，无采样、无第三方旋律、无模型输出；默认只写根 `assets/audio/`，不覆盖第三方运行时 BGM |

**未使用**：第三方付费素材库、未授权网络图片、他人游戏源码、生成式音乐模型。
**历史生成式语音**：MOSS-TTS-Nano 实验音频已全部从运行时移除，模型权重不进入成品；当前剧情仅以定时字幕播放，未核实输出授权的语音不得重新加入分发包。

---

## 三、AI 生成内容清单

> **补充（2026-11-23，v1.17 原创明式抗倭瓦片）**：新增原创 32×32 瓦片图集，
> 由 `skills/pixel-art-studio`（MIT）配合 Python/Pillow **程序化像素绘制**，
> 源文件为 `pixel-art/yongchang_tiles/build.py`，不是扩散模型生图、未使用第三方瓦片。
> 产出（2026-11-25 已扩至 88 格）：地形 40 格（滩涂、沙地、浅/深水、石板路、土路、木码头、岸线与岸角、水洼、盐洼、碎石、浮木、龟裂泥地、山体与横纵桥面）、
> 建筑与城防 32 格（青灰石墙、箭孔、雉堞、墙帽、白灰墙、木格窗、红漆门、黛瓦屋顶、陆门、水关、马头墙、红灯笼、店面、横纵栏杆）、
> 道具 16 格（芦苇、烽火、拒马、渔舟、明字旗、石敢当、箭袋、渔网、牌匾、竹篱等）。
> 文化取向为明代浙南沿海抗倭堡垒，明确排除鸟居、暖帘、日本家纹、武士旗等日式识别物。
> 人工介入：确定文化方向与调色板、逐轮看图批评并修改 `build.py`（窗纸过曝、水门黑洞、瓦垄过密、岸线锯齿、军旗日式燕尾等问题）、
> 用 `pixelstudio` 的 `preview / zoom / silhouette / stats` 检查，再在 Godot `game/scenes/tile_preview.tscn`
> 以 `TileMapLayer` 实际切片验证。授权：**原创非代码资产 CC BY 4.0**；署名：xingwangzhe。
>
> **补充（2026-11-23，v1.18 原创主角与十六类倭寇精灵）**：新增两套角色图集，
> 同样由 `skills/pixel-art-studio`（MIT）配合 Python/Pillow **程序化像素绘制**，
> 源文件为 `pixel-art/actors/build.py`，不是扩散模型生图，未使用 itch.io 或任何第三方角色素材。
> 产出：主角**戚继光** 128×128×16 帧（待机 2 / 行走 8 / 攻击 6），明式铁盔红缨、山文甲、红披风、腰刀；
> 敌方**倭寇 16 类**，每类 128×128×16 帧（待机 2 / 行走 8 / 攻击 6）：斥候、浪人、火枪倭、藤牌武士、倭弓手、旗手、海盗、倭谍、
> 倭将、大名、足轻、铁炮队长、僧兵、鬼面武者、水鬼、投弹手。倭寇的阵笠、胴丸、铁炮等仅作为反派识别，
> 不用于明军与主角。人工介入：按约 6 头身的人体比例重建肩、肘、髋、膝、踝关节与两段式四肢，
> 逐帧解算膝关节和肘关节，补齐颈部、骨盆与关节护片，避免断肢与浮头；
> 多轮看图修正头身比、关节接缝、肩髋球关节过大、武器裁切、刀身过细、弓弧不可读、行走/攻击幅度过小等问题；
> 用 Godot `game/scenes/actors_preview.tscn` 实际播放四帧循环验证。
> 授权：**原创非代码资产 CC BY 4.0**；主角为原创像素形象，非历史肖像；署名：xingwangzhe。
>
> **补充（2026-11-23，v1.20 地图环境动效）**：新增 `animated_props.png`，
> 4 列×4 行、每格 32×32，含红灯笼呼吸/光晕、渔舟浮沉、明军旗摆动、烽火与火星四组 4 帧循环；
> 源文件同 `pixel-art/yongchang_tiles/build.py`。Godot 预览用 `ambient_props.gd`
> 按数据表放置并以 8fps 播放；仍属项目原创程序化像素绘制，CC BY 4.0。
>
> **补充（2026-11-23，v1.22 阵营隔离）**：新增模块化角色锻造系统，
> 源文件 `pixel-art/character_forge/build.py`，导出 `body_base.png`、`outfits*.png`、
> `headgear*.png`、`backgear.png`、`weapons.png` 与 `offhands.png` 共九张 128×128 分页图集，
> 每页最多 128 行，每行 48 帧；4 肤色 × 16 服装 × 14 头饰 × 5 背挂 × 59 套主副手组合，
> 原始组合 264,320 条；按阵营隔离后明军 **59,392** 种、倭寇 **15,360** 种，合法合计
> **74,752** 种。武器含刀、枪、剑、戟、斧、钺、钩、叉、盾、弓、弩、手铳、龙灯、令旗、
> 狼筅、戚家刀、镋钯、倭刀与藤牌；明军专属与倭寇专属不得混装，通用装备可供双方组合。
> 19 类武器各绑定 5 段具名动作：劈、斩、刺、扫、砸、勾、射、架盾等，不再只复用握法级动作；
> 双持组合另有同种、异种、盾击各 5 段合击。肩、肘、髋、膝、踝共享同一骨架端点，
> 构建时同时校验臂长与腿长；双手、远程与单手武器均把双臂固定在躯干前层，双持主手与副手
> 使用真实配对姿态行，保证挥动、持握与武器和手的贴合可读。每轮导出后查看
> `joint_contact_sheet.png`、`dual_combo_sheet.png`、`faction_combo_sheet.png`、
> `random_combo_sheet.png` 与 `weapon_action_sheet.png`。参考包仅用于观察比例、关节连接和动作节奏：
> LPC Character Bases（CC-BY-SA 3.0 / GPL 3.0）、RGS_Dev modular characters（CC0 1.0）、
> Kenney Modular Characters（CC0 1.0）；原始包下载到已忽略的
> `generated/character_candidates/`，**没有 PNG/GIF/SVG/ZIP 或描摹结果进入成品**。
> 本批次不是扩散模型生图，由 `skills/pixel-art-studio`（MIT）配合 Python/Pillow 程序化绘制；
> 授权为**原创非代码资产 CC BY 4.0**，署名 xingwangzhe。Godot 运行时为
> `game/scripts/character/character_forge.gd`，验收场景为
> `game/scenes/character_forge_preview.tscn`，GUT 覆盖图集尺寸、行映射、双持与配方。
>
> **补充（2026-11-23，v1.24 战斗角色组合烘焙）**：八类敌兵与七名战斗角色改用
> `enemies.json` / `characters.json` 内的 `character_recipe`，由
> `pixel-art/character_forge/bake_battle_sprites.py` 从裸体基底、服装、头饰、
> 背挂、主副手图集烘焙待机与行走条，导出到 `game/assets/units/forge/`。
> 旧 `assets/units/*/static.png`、`run/`、`attack/` 序列已从运行时与资产目录删除；
> 敌兵继续走 MultiMesh 批次，主角按其守夜阵位播放待机/行走帧，选择页头像取
> 同一套 CharacterForge 待机帧，序章汤和与明军也改画同一套烘焙帧。
> 本批次同样由 Python/Pillow 程序化合成，无扩散模型生图，授权为
> **原创非代码资产 CC BY 4.0**，署名 xingwangzhe。
>
> **补充（2026-11-23，v1.25 三角色参考重绘）**：按用户提供的三张 64×64 参考图，
> 重画远射位 `agong`、龙灯位 `amei` 与旗令位 `aqi` 的脸部轮廓、体态、服装与装备。
> 新增明军弓手软帽、龙灯朱金抹额、明军箭囊；弓手改为深青短袄与绿色绑带，
> 龙灯改为朱红礼衣与侧向长吻龙首，旗令改为米色分层札甲、蓝色下装与宽叶枪。
> 三人仍是同一名虚构守夜乡勇王陆的不同阵位，共享一张脸、一套骨架与肤色体系；
> 参考图不入库、不打包。验收输出 `pixel-art/character_forge/reference_trio_actions.png`
> 与 `reference_agong_actions.gif`、`reference_amei_actions.gif`、`reference_aqi_actions.gif`，
> 每个角色含待机 4 帧、行走 8 帧、攻击 6 帧；仍属项目原创程序化像素绘制，
> 授权 **原创非代码资产 CC BY 4.0**，署名 xingwangzhe。
>
> **补充（2026-11-24，v1.26 军市佣兵）**：新增 8 类同代佣兵与义师单位：
> 义师枪兵、义师弓手、藤牌乡兵、鸟铳手、令旗手、戚家军客兵、王沛英魂、王德英魂。
> 外观仍由 `pixel-art/character_forge/build.py` 的裸体基底、服装、头饰、背挂与主副手
> 图层程序化合成，`bake_battle_sprites.py` 读取 `game/data/mercenaries.json`，
> 导出 `game/assets/units/forge/allies/<id>/{idle,walk}.png`；每类 4 帧待机 + 8 帧行走，
> 128×128，不手改 PNG。配方强制 `faction=ming`；王沛、王德只作乡贤香火英魂，
> 标 `民俗`，不写复生或亲临 1559。验收合图
> `pixel-art/character_forge/mercenary_roster.png`。军市与佣兵攻击层复用
> Jeff-FX-forge 已导出图集，新增 8 条友军攻击 profile；玩家 24 + 敌兵 16 + 友军 8，
> 共 48 种战斗特效组合。以上均为项目原创程序化像素与原创配置，
> 授权 **原创非代码资产 CC BY 4.0**，署名 xingwangzhe。
>
> **补充（2026-11-24，v1.27 像素美术提档）**：重写 `pixel-art/character_forge/build.py`
> 的绘制基元——四肢由单色平涂改为三阶体积明暗并自带 1px 描边（手臂、腿从躯干色块中分离）；
> 大腿与小腿加粗约 10%–15%；靴子重做为带鞋底、鞋头受光与踝口的形体；面部补齐瞳孔、
> 加粗眉毛、鼻侧影、颧部受光与下唇高光；袖山由圆盘改为沿上臂方向的胶囊，去掉「气球肩」；
> 布甲躯干增加受光面、背光面与领口投影三段结构；札甲肩甲去掉刺眼白色铆点，改为暗缝叠片。
> UI 控件改由新增的 `pixel-art/ui_kit/build.py` 程序化绘制（漆面底板 + 3px 描金带 +
> 四角卷角与铆点），旧 `tools/build_ui_controls.py` 已删除，避免两份生成源并存。
> 战斗攻击特效沿用已登记的 Jeff-FX-forge 图集，本轮未新增第三方素材。
> 本批次仍为 Python/Pillow 程序化绘制，无扩散模型生图、无外部描摹，
> 授权 **原创非代码资产 CC BY 4.0**，署名 xingwangzhe。
>
> **补充（2026-11-24，v1.28 角色与敌兵握持修正）**：继续在
> `pixel-art/character_forge/build.py` 内以代码修正六类观感问题：
> 腰刀改为向前握持并补上握拳与刀柄短柄；鸟铳重画为木质枪托、铁质铳管、
> 加固箍、喇叭铳口与下垂火绳，拉开与斥候的剪影；新增仅配方使用、不进入随机
> 部件池的 `wokou_banner` 倭寇阵旗背挂，旗手敌兵改配该背挂并绘制旗面与波浪纹；
> 弓弦端点补握弦手与握弓手，箭袋前移贴合肩背；长枪改为腰际斜持，枪尖避开面部与
> 肩线；按兵器加入轻微重心偏移与站距差异，靴口补踝部阴影，投影改为三层柔和
> 过渡并与鞋底相接、随重心微移。部件随机池仍为 5 类背挂，明军 **59,392** / 倭寇 **15,360** 组合数不变。
> 本批次仍为 Python/Pillow 程序化像素绘制，授权 **原创非代码资产 CC BY 4.0**，
> 署名 xingwangzhe。
>
> **补充（2026-11-24，v1.29 音频确权与 AGPL/CC BY 许可整治）**：
> - 默认 BGM 音量由 `0.62` 降至 `0.42`；已保存的用户设置仍被尊重，测试锁定新默认值。
> - 菜单改用根目录原有 CC0 原创合成 `assets/audio/bgm_watch.ogg`，运行时文件与其字节一致；
>   关于页新增独立 CC0 原创曲「Watchfires of Credits / 守灯致意」（72 秒、无采样、无模型输出）；
>   保留 MintoDog「Hard Battle 1」CC0 战斗曲与全部 20 个 CC0 SFX。原两首 CC-BY BGM 当时退出运行时；
>   2026-11-25 复核官方页面后恢复，详见下方 v2.1 记录。
> - 核查 OpenMOSS 官方仓库 LICENSE/README 与 Hugging Face 模型卡后，只确认代码/模型为 Apache-2.0，
>   未找到生成音频输出的明确授权条款。因此删除 9 中文 + 9 英文共 18 个 OGG 及 import sidecar；
>   `voice_lines.json` 明确 `audio_enabled=false`、`distribution=subtitles_only`，保留完整字幕与来源元数据，
>   `VoiceLinePlayer` 继续按约 4.35 音节/秒计时。再生成脚本默认拒绝输出，须先取得可验证授权并显式 opt-in。
> - 项目代码改为 **AGPL-3.0-or-later**，原创非代码资产为 **CC BY 4.0**；特定原创音频提供
>   **CC0 1.0 或 CC BY 4.0** 选择，既有 CC0 奉献保留，第三方保留原许可。新增 `NOTICE`、
>   官方法律全文与 `game/` 导出副本；导出预设显式包含许可与署名文件。
> - `credits.json`、关于页主/备选许可链接、音频 TASL、资产 CSV 与相关测试已同步。
>
> **补充（2026-11-25，v1.30 赛事整改与验证）**：新增首次操作/文化/系统三页双语教程及
> `tutorial_seen` 存档迁移；加入长按攻击、0.18 秒单击缓冲、X 自动攻击与 HUD 状态；新增
> 原创时代风格像素箭头；主角攻击方向改为 36° 短圆弧和切线箭头；升级三选一加入 1000ms 输入锁。
> 地图水面可通行、实心障碍不可通行、桥梁连续且视觉/碰撞一致，瓦片扩为 88 格；藤牌只作防具，
> 退出七种兵器池；箭塔新增连发箭槽与双机括并射，主齐射和两条独立 burst 通道可重叠。
> 已执行 Godot 4.7.2-stable import、完整 GUT 与场景 preflight，并查看教程、升级锁、自动攻击、
> 地图/箭塔与方向指示截图。Dora 源码 ZIP 已构建并校验 CRC、引用资源与禁止路径；本机无 Dora CLI，
> 真实 Dora 运行仍未验收。新构建必须重新导出并审计；旧 `game/build/` 含与当前运行时不同的 BGM/语音，不得分发。
>
> **补充（2026-11-25，v2.0 赛事封面与演示视频）**：
> - 封面 `artifacts/watch-yongchang-cover.png` 为 1920×1080 PNG，以已验收箭塔截图
>   `docs/screenshots/2026-11-25-tower.png` 为底图，叠加原创标题、玩法标签与「守」字印章；
>   使用 LXGW WenKai，人工查看成图并验收。
> - 演示 `artifacts/watch-yongchang-demo-2026-11-25.mp4` 为 91 秒、1920×1080、30 fps、
>   H.264/yuv420p + AAC，共 2730 帧。源图依次为赛事封面、教程操作、教程文化、方向指示、
>   自动攻击 HUD、箭塔、升级卡、地图一致性、教程系统与不透明片尾；另使用项目原创
>   `bgm_watch.ogg`（xingwangzhe，CC0）。这是截图驱动的演示剪辑，不是连续实机录屏。
> - 未新增第三方图片、视频或音频；封面/视频的原创编排、字幕与衍生贡献按 CC BY 4.0 提供，
>   截图内既有第三方成分保留原许可，字体保留 OFL 1.1，BGM 保留 CC0。验收截图属于本地
>   `docs/screenshots/` 忽略产物，不进入游戏运行包；最终媒体作为赛事附件单独交付。
> - 已通过 ffprobe 流信息、完整 FFmpeg 解码、实际第 2729 帧像素提取、联系表与响度检查：
>   容器/音频/视频均为 91 秒，约 −20.79 LUFS、真峰值 −9.18 dBTP，无削波；封面与视频
>   SHA-256 已写入 `docs/build_2026-11-25.md` 和 `artifacts/release-manifest.json`。
> - Bilibili 上传与「2026 开源游戏开发大赛」标签仍待完成，不以本地 MP4 推定平台发布成功。
>
> **补充（2026-11-25，v2.1 恢复两首合规 BGM）**：
> - 重新打开 OpenGameArt 官方页面核对：**Samurai Nights** 作者 Maik Hoffmann（Majadroid），
>   页面同时提供 **CC BY 4.0 / CC BY 3.0 / OGA-BY 3.0**，本项目选择 CC BY 4.0；
>   **Views From Atop the Jade Kings Throne** 作者 Hitctrl，许可 **CC BY 3.0**。两者均允许
>   公开传播、复制、再分发与修改，均不含 NC/ND 限制，符合赛事对第三方素材的开放许可要求。
> - 从历史提交恢复 `game/assets/audio/bgm_watch.ogg` 与 `bgm_about.ogg`，分别用于主菜单/选择页
>   与关于页滚幕；战斗曲仍为 MintoDog 的 CC0「Hard Battle 1」。三首运行时 BGM 均保留来源、
>   作者、许可链接、用途与修改说明。
> - 恢复文件 SHA-256：菜单 `5351dd48614a513cd805dc10e9aefcd6690868d9f0c5b31a5aabc9fedeefa25a`；
>   关于页 `21af784efac14e8a168ee1992cb002b521172a2ff39dc68ab603218c215d6335`。
> - 同步更新 `game/data/credits.json`、`game/assets/audio/LICENSES.md`、`NOTICE`、
>   `素材授权清单.csv`、主菜单曲名与 GUT 断言；`tools/generate_audio.py` 默认改写入根
>   `assets/audio/`，不再覆盖第三方运行时 BGM。
>
> **历史记录（2026-11-23，v1.23 剧情语音；2026-11-24 已停止分发）**：曾新增 18 个剧情语音 OGG，覆盖 9 条核心对白的中英双语。
> 文本来自 `game/data/narrative.json`，语音清单为 `game/data/voice_lines.json`；生成工具为
> **OpenMOSS MOSS-TTS-Nano 100M ONNX**，本地 CPU 推理，Rust ONNX 运行时为
> [mzdk100/moss-tts-nano](https://github.com/mzdk100/moss-tts-nano)（Apache-2.0）。
> 声线固定为 **Lingyu（旁白）、Junhao（汤和/王陆）**；长句按标点分句，压缩模型插入的
> 1–2 秒长静音，再补 0.28–0.55 秒短停顿，目标普通话自然对话约 4.35 音节/秒。
> 人工修改包括：逐条核对 `source_ref`、区分史实/制度/民俗/演绎、检查时长与峰值、
> 将 WAV 转码为 OGG。模型权重不进入成品。**现状：官方模型/代码的 Apache-2.0 许可未明确覆盖生成音频输出，
> 上述 18 个文件已于 2026-11-24 全部移除；当前仅保留双语字幕回退，详见 v1.29 记录。**
>
> **补充（2026-11-22 晚，v1.5 第三方 UI 装饰）**：按「装饰素材可商用 + 通用化 + 契合深底金描边风」要求，引入 OpenGameArt 两套 **CC0** 素材：**golden-ui by buch**（裁切琥珀金像素面板 `panel_gold.png` 作九宫格面板）与 **Free UI Asset Pack 1 by ctatz**（9 枚白色符号染金色 → 通用图标：播放/设置/信息/关闭/暂停/音量/静音/勾选/奖杯）。经 `tools/process_thirdparty_ui.py` 处理，`game/scripts/ui/ui_kit.gd` 作统一出口接入主菜单按钮、关于/设置/HUD 暂停与结算/事件横幅面板。TASL 逐项登记见 `game/data/credits.json` 与 `素材授权清单.csv`；原始文件仅保留历史溯源记录。
>
> **历史记录（2026-11-22 晚，v1.4 音频来源调整；BGM 于 2026-11-24 暂退、2026-11-25 恢复）**：当时要求「长音乐/短音效优先采用 CC0 或免费可商用现成素材，脚本合成仅作兜底」，工程 `game/assets/audio/` 曾全部更换为第三方素材：BGM 采用 OpenGameArt 的 **「Samurai Nights」by Majadroid（页面现提供 CC BY 4.0 / 3.0）**，9 个事件音效取自 OpenGameArt 的 CC0 音效包（Kenney / artisticdude / remaxim / ogrebane / wobbleboxx），经音频转换流程响度归一化、截短与 OGG 转码后嵌入。该曲在 2026-11-24 曾从运行时移除；2026-11-25 复核许可后恢复。当前完整音频 TASL 见 `game/assets/audio/LICENSES.md`。原合成工具 `tools/generate_audio.py` 保留用于生成原创母版。中文 UI 字体统一采用 **霞鹜文楷 / LXGW WenKai**，已设为 Godot 工程全局默认字体；字体许可 **SIL OFL 1.1**，完整协议文本随字体存放于 `assets/fonts/OFL.txt` 与 `game/assets/fonts/OFL.txt`。
>
> **历史记录（2026-11-23，基础 UI 骨架）**：重建的主菜单仅复用已登记资源，未新增第三方素材。
> 当时继续使用 **「Samurai Nights」by Maik Hoffmann（Majadroid）**；
> 2026-11-24 曾改用 CC0 原创「Yongchang Watch / 永昌守望」，2026-11-25 复核许可后恢复
> **Samurai Nights · CC BY 4.0**。
> 初版 UI 背景、印章、城楼、灯笼与月夜由 GDScript 绘制；2026-11-23 晚已将顶部夜景替换为
> `pixel-art-studio` 程序化像素图，面板复用 `game/assets/ui/panel_dark.png`，
> 字体继续使用霞鹜文楷（OFL 1.1）。新增代码由 Codex 生成，结构与交互由人工确认。
>
> **历史记录（2026-11-23，关于页与滚幕音乐；原曲 2026-11-24 暂退、2026-11-25 恢复）**：新增关于页 `game/scenes/about.tscn`，
> 以电影滚幕自动上滚展示项目信息、致谢、参考、版权与第三方素材；首次鼠标滚轮事件即停止
> 自动滚动，由玩家接管。当时使用 OpenGameArt 的
> **「Views From Atop the Jade Kings Throne」by Hitctrl（CC BY 3.0）** 作为专属 BGM，
> 进入关于页时停止全局菜单 BGM，返回时恢复。2026-11-24 曾改用原创「Watchfires of Credits / 守灯致意」，
> 2026-11-25 复核许可后恢复 Jade Kings Throne；
> 来源、署名与修改说明已写入 `game/data/credits.json`、`素材授权清单.csv` 与本声明。
>
> **补充（2026-11-23，v1.24 战斗 BGM 与全事件音效；2026-11-24 菜单部分更新）**：新增 OpenGameArt 的
> **「Hard Battle 1」by MintoDog（CC0 1.0）**，原始 OGG 数据，循环用于 1559 正篇战斗；
> 主菜单、选择页与守夜前场景在 2026-11-24 至 2026-11-25 之间曾使用 CC0 原创
> 「Yongchang Watch / 永昌守望」，现恢复 Samurai Nights。新增 Kenney
> **UI Audio**（click2 / switch3 / click4 / switch1 / switch9）与 **Impact Sounds**
> （Soft / Punch / Plate / Generic / Bell / Metal 各一条）共 11 个 CC0 音效，
> 用于全局按钮点击、确认/返回、经验/灯油/治疗/龙鳞拾取、事件卡、敌兵受击、普通/精英击杀、
> 升级、冲刺与 Boss 出现。音频未改数据，仅按事件变调与节流；来源与逐文件映射见
> `game/assets/audio/LICENSES.md`、`game/data/credits.json` 与 `素材授权清单.csv`。
>
> **补充（2026-11-23，主菜单动态像素夜景）**：主菜单背景改用项目内
> `skills/pixel-art-studio` 生成，画布为 640×360 母版、统一 32 色调色板、整数 2x 最近邻导出；
> 构图包含月光云带、远山、永昌城墙与敌楼、海面渔船、前景芦苇和烽火台。为保证背景不是纯静态图，
> 资产拆为 `menu_backdrop.png` 底层、`menu_clouds.png` 循环云层、`menu_waves.png` 循环浪层、
> `menu_boat.png` 渔船精灵与 `menu_beacon.png` 6 帧烽火序列；`menu_backdrop.gd` 以不同速度叠加，
> 并保留星点闪烁、月光碎影、灯火呼吸与飘散火星。所有像素由 `pixel-art/menu_backdrop/build.py`
> 重新生成，未使用扩散模型生图，也未新增第三方图片素材。
>
> **补充（2026-11-23，第三方 UI 与卡牌图标；2026-11-24 扩至 101 个）**：主菜单“首夜支点”、开局页
> “首夜军备”与三选一卡池接入 **game-icons.net** 的 101 个 SVG 图标，作者为
> Delapouite、Lorc、Skoll、Willdabeast、Faithtoken 与 Caro Asercion。
> 许可为 **CC BY 3.0**；白色透明 SVG 在游戏内按 UI/卡牌类型着色，图形未改。
> 逐项来源、用途与修改说明见
> `game/assets/icons/game_icons/ATTRIBUTION.md`、`game/data/credits.json` 与
> `素材授权清单.csv`；完整许可全文随包于
> `game/assets/icons/game_icons/LICENSE-CC-BY-3.0.txt`。

### 3.1 图像资产（`assets/` 与 `game/assets/`）

**早期批次（`assets/`，保留作溯源）**

| 类别 | 数量 | 生成方式 | 状态 |
|---|---|---|---|
| 兵种静态图 | 3 | 文本生图 | 已后处理，透明背景 |
| 兵种跑步帧 | 12 | 以静态图为参考的图生图 | 已后处理，4 帧/单位 |
| 兵种攻击帧 | 12 | 以静态图为参考的图生图 | 已后处理，4 帧/单位 |
| 预览联系表 | 3 | 由上述素材用 PIL 拼图 | 派生资产，非独立生成 |

**UI 批次（`game/assets/`，当前成品实际使用）**

> 旧塔防建筑素材已于 2026-11-23 清理，不再进入成品、原始素材目录或授权清单。2026-11-23 角色序列帧改为项目原创程序化像素绘制，不再使用 ImageGen 兵种成品，也不再套用第三方角色骨架。

| 类别 | 数量 | 规格 | 生成方式 |
|---|---|---|---|
| UI 素材批次 | 11 | 64×64 图标 10 张 + 512×512 面板 1 张 | ImageGen 条带/单张 → 后处理 |

合计：早期批次 **27 张 PNG + 3 张 JPG**；当前 AI 成品为 UI **11 张 PNG**；4 张原始条带保留溯源。

**历史角色精灵批次（旧 `game/assets/units/`，已删除，不得使用）**

| 类别 | 数量 | 规格 | 来源与处理 |
|---|---|---|---|
| 友军序列帧 | 6 组 | 64×64 RGBA，4 帧跑 + 4–5 帧攻击 + 静态 | 项目原创像素绘制；短褐/交领袍/罩甲/毡帽/头巾/铁盔/藤盔/乌纱帽、腰刀/弓/龙灯/藤牌/手铳/令旗 |
| 倭寇序列帧 | 5 组 | 64×64 RGBA，4 帧跑 + 4–5 帧攻击 + 静态 | 项目原创像素绘制；头巾/月代头/阵笠/铁兜、胴丸/袴、打刀/种子岛火绳枪/藤牌/太刀 |

流水线：原 `tools/generate_ming_sprites.ts` 已在清库重建时移除；11 组 64×64 RGBA 帧及其根目录副本已删除，不得从旧提交、回收站或旧预览恢复。当前正式外观改用 `pixel-art/character_forge/bake_battle_sprites.py` 从 `character_recipe` 烘焙。

**UI 素材批次（2026-11-22 晚，`game/assets/ui/`，当前 HUD 实际使用）**

| 类别 | 数量 | 规格 | 生成方式 |
|---|---|---|---|
| 资源图标（粮/银/弹/主堡） | 4 | 64×64 RGBA | ImageGen 4 联条带 → `tools/process_ui_sprites.py` 切图抠图 |
| 建造图标（箭塔/军械坊/烽火台） | 3 | 64×64 RGBA | ImageGen 3 联条带 → 同上 |
| 出兵图标（乡勇/弓手/龙灯队） | 3 | 64×64 RGBA | ImageGen 3 联条带 → 同上 |
| 面板底板 | 1 | 512×512 RGBA | ImageGen 单张 → 去白底缩放 |

合计：UI 批次 **11 张成品 PNG** + 4 张原始条带（`generated/ui_art/`，溯源不入成品）。图标经边界 flood fill 去白底、抗锯齿白点二轮清除、tight crop、nearest 缩放；联系表人工逐张验收后导入工程并接入 HUD（顶栏 chip 图标 + 底栏建造/出兵按钮图标）。逐文件路径见 `素材授权清单.csv`。

**UI 控件批次（2026-11-24 重制，`game/assets/ui/controls/`，菜单与设置实际使用）**

| 类别 | 数量 | 规格 | 生成方式 |
|---|---|---|---|
| 普通/主按钮 | 6 | 176×72 RGBA，九宫格 | 程序化绘制漆面底板：1px 墨线轮廓 + 3px 描金带（左上受光、右下压深）+ 四角金线卷角与方形铆点；normal/hover/pressed 三态 |
| 紧凑按钮/下拉 | 3 | 144×48 RGBA，九宫格 | 同上，缩尺版，用于小尺寸返回键与 OptionButton |
| 滑条轨道/填充/滑块 | 4 | 64×16 / 24×24 RGBA | 深色凹槽 + 金色进度 + 象牙滑块（中心金钉） |
| 开关 | 2 | 52×28 RGBA | 红/黑轨道、金边、象牙滑块左右状态 |
| 下拉箭头/弹层/提示框/滚动条 | 6 | 18×12 至 112×112 RGBA | 与面板同色系的金线九宫格、四角纹样与玉扣滚动条 |

合计 **21 张控件 PNG**，生成脚本为 `pixel-art/ui_kit/build.py`（Python + Pillow，纯程序化绘制，不再从 `panel_dark.png` 采样）。所有装饰都限制在九宫格角块与 1px 边带内，缩放拉伸时中心不会出现涂抹；生成后逐张看图自检，并在主菜单、设置页、关于页返回键与占位开局页截图验收。登记见 `素材授权清单.csv` 的 `ui_control_kit`。

**游戏鼠标光标（2026-11-24，`game/assets/ui/watch_cursor.png`）**：AI 辅助编写 `pixel-art/watch_cursor/build.py`，以墨线、描金、朱砂与纸色绘制项目原创 24×24 时代风格箭头；人工确定配色、热点 `(3, 0)` 与 gameplay-only scope。导出 PNG 未手改，运行时仅正式游玩启用，菜单、暂停、教程、升级、军市、图鉴与结算均恢复系统光标。按原创非代码资产 **CC BY 4.0** 发布，已登记 `credits.json` 与 `素材授权清单.csv` 的 `watch_cursor_pixel_art`。

**赛事封面与演示视频（2026-11-25，`artifacts/`）**：封面以 `2026-11-25-tower.png` 为底图；演示视频使用 `2026-11-25-tutorial-controls.png`、`2026-11-25-tutorial-culture.png`、`2026-11-25-aim-indicator.png`、`2026-11-25-auto-attack-hud.png`、`2026-11-25-tower.png`、`2026-11-25-levelup-ready.png`、`after_map.png`、`2026-11-25-tutorial-systems.png` 及封面/片尾。以上截图均为本项目已验收本地画面，原图中的角色、地形、特效、图标等沿用各自登记许可；新增排版、字幕、标签、印章与剪辑按 **CC BY 4.0** 提供。字体为 LXGW WenKai（OFL 1.1），音频为 `bgm_watch.ogg`（xingwangzhe，CC0）。两项媒体已登记 `素材授权清单.csv` 的 `watch_yongchang_cover` 与 `watch_yongchang_demo`，不进入游戏运行包。

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

> **当前 UI 骨架（2026-11-23）**：`game/scripts/autoload/game_settings.gd`（设置持久化）、
> `locale.gd`（中英双语）、`save_system.gd`（自动存档）、`audio_bus.gd`（BGM 循环）、
> `game/scripts/ui/main_menu.gd`（主菜单/设置层）、`menu_backdrop.gd`（月夜城堡绘制）、
> `about_roll.gd`（关于页电影滚幕/滚轮接管/专属 BGM）、`run_placeholder.gd`（占位开局），
> 以及 `game/tests/unit/test_ui_foundation.gd`。
> 下列旧守城代码条目保留为历史记录，实际文件已移除。

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
| `tools/generate_ming_sprites.ts` | 原创 64×64 像素兵种行走/攻击帧生成流水线（明代友军 6 组、倭寇 5 组） | 人工定兵种轮廓、帽式、甲片、配色、武器位置与帧数；逐帧联系表与主视口截图验收 |
| `tools/process_thirdparty_audio.py` | 第三方音频转换流水线（响度归一化、Alarm 截短、OGG 转码） | 人工定响度目标与截短时长；人工选曲与逐项映射音效 |
| `tools/generate_audio.py` | 原创 BGM 母版与开发音效母版生成（Python 标准库加法合成/噪声 + ffmpeg 编码）；默认写入根 `assets/audio/`，不覆盖第三方运行时 BGM | 人工确定和弦、包络、立体声与循环淡化；恢复历史菜单旋律并新作独立关于页曲；`--legacy` 再生成根目录母版 |
| `tools/process_thirdparty_ui.py` | 第三方 UI 装饰流水线（golden-ui 面板裁切、ctatz 符号染金色） | 人工选源、定裁切框与金色基线；联系表人工验收 |

项目代码许可 **AGPL-3.0-or-later**；原创非代码资产 **CC BY 4.0**，特定原创音频 **CC0 1.0 或 CC BY 4.0（由接收者选择，既有 CC0 奉献保留）**，第三方保留原许可。

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
8. **兵种精灵重绘**：人工否决「套用不相干角色骨架」的做法，按明代乡兵与倭寇的服饰、帽式、甲胄与武器重新设定轮廓；用 `tools/generate_ming_sprites.ts` 生成固定 64×64 帧，逐帧检查帽形、朝向、武器侧向与行走连续性，并在主视口截图中修正 `PathFollow2D` 初始 90° 旋转。

---

## 五、素材来源与授权

### 5.1 AI 生成资产

- 范围：`assets/` 下全部 PNG 与预览 JPG。
- 授权：作为本项目原创非代码资产，采用 **CC BY 4.0** 许可（若申请 Dora 开源社区奖，按赛事要求执行）。
- 权利说明：AI 生成内容的著作权认定在不同法域存在差异。本项目不主张对纯 AI 原始输出享有排他著作权；对人工提示词设计、筛选、编排、后处理所形成的汇编与衍生结果，在适用法律允许范围内主张相应权益。赛事申报中如实披露 AI 参与情况。

**项目原创像素兵种（非 AI 生图；旧运行时版本）**

- 范围：`game/assets/units/{xiangyong,gongshou,longdeng,tengpai,huochong,jinshi,wokou_scout,wokou_ronin,wokou_shield,wokou_gun,wokou_chief}/`。
- 授权：原创非代码资产 **CC BY 4.0**；不依赖第三方角色骨架或第三方序列帧。
- 生成方式：原 `tools/generate_ming_sprites.ts`（Bun + TypeScript + Sharp）程序化绘制 64×64 RGBA 像素帧；该脚本已在清库时移除。
- 运行时状态：这些 `static.png` / `run` / `attack` 序列已删除，不再进入成品；当前外观统一由 `pixel-art/character_forge/bake_battle_sprites.py` 从裸体基底与装备配方烘焙，不得重新接回游戏。
- 造型依据：明代短褐、交领袍、罩甲、毡帽、头巾、铁盔、藤盔、乌纱帽、藤牌、腰刀、手铳、令旗；倭寇头巾、月代头、阵笠、铁兜、胴丸、袴、打刀、种子岛火绳枪。历史与民俗参考集中于 `docs/06-资料文本化/`：`AI资料索引与知识图谱.md` 的兵种文化映射、`文档文本/永昌堡-十三进士与抗倭纪略-全文.txt` 的城池与乡兵记载、`文档文本/汤和信俗(11.18)__抵御倭患第一人+汤和(1)(1).txt` 的抗倭与龙灯背景；未直接复制参考图入成品。

### 5.2 第三方参考资料（均未进入成品）

| 来源 | 内容 | 授权状态 | 使用方式 |
|---|---|---|---|
| 2026 OSGJ 官网（https://2026gamejam.osgame.org/）下载区 | 汤和信俗素材包（`汤和信俗(11.18).zip`，含 42 JPG / 2 PNG / 3 DOCX / 1 DOC / 1 PDF） | 未见明确开放许可声明 | 解压、OCR、文本化，仅用于文化考据；原始包已从 Git 库排除 |
| 2026 OSGJ 官网（https://2026gamejam.osgame.org/）下载区 | 《永昌堡十三进士与抗倭纪略内文9.14.pdf》（552 页） | 未见明确开放许可声明 | 抽取全文用于史实考据；未复制原文入游戏 |
| 2026 OSGJ 官网（https://2026gamejam.osgame.org/） | 站点图片、合作伙伴标识 | 原权利归各权利人 | 仅存档与界面风格参考 |
| 2026 OSGJ 官网（https://2026gamejam.osgame.org/） | 主题加密载荷、密钥、榜单 API 数据 | 赛事官方公开信息 | 仅本地解密与资料归档，密钥不入库 |

文化背景、赛事主题「守 · 望」与六个创作方向均来自
[2026 OSGJ 开源游戏开发大赛官网](https://2026gamejam.osgame.org/)；关于页不再单列
“参考资料”块，官网、永昌堡、汤和信俗、音乐、字体与工具来源均直接内嵌在对应致谢条目。

**处理原则**：授权不明的第三方内容一律不进入成品、演示视频与封面；如需使用，须先取得权利人许可并在本声明中署名与补充许可条款。

### 5.3 工具与引擎

- 游戏引擎：Godot 4.7.2-stable（开源，MIT 许可；版本锁定于 `game/.godot-version`）
  ——引擎本身不属于项目资产，按原许可使用。
- 开发与采集工具：Python 3、PIL、Bun、Sharp、tesseract、trafilatura、pdftotext、Chrome DevTools Protocol、Git——均为通用工具，其输出数据按本节分类处理。
- 攻击特效工具：Jeff-FX-forge 1.1（Jeff Studio，代码 MIT；原创特效 CC0 1.0）。
  本作使用其像素工坊预设导出 `slash_*`、`hit_*`、`thrust`、`block_sparks`、
  `ground_shockwave`、`energy_ring` 与 `explosion_*` 图集，再把帧矩形、锚点和
  打击停顿接入 `game/data/attack_fx.json`。导出 PNG 未手改；组合、旋转、缩放与
  命中叠层由项目 GDScript 完成。

### 5.4 第三方可商用素材（CC0 / CC BY 4.0 / CC BY 3.0 / OFL 1.1）

| 素材（Title） | 作者（Author） | 来源（Source） | 许可（License） | 用途与修改说明 |
|---|---|---|---|---|
| Samurai Nights | Maik Hoffmann (Majadroid) | https://opengameart.org/content/samurai-nights | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | 原 Demo MP3 转码为 OGG；音频内容未改；主菜单/选择页循环。官方页同时提供 CC BY 3.0 / OGA-BY 3.0，本项目选择 CC BY 4.0 |
| Views From Atop the Jade Kings Throne | Hitctrl | https://opengameart.org/content/views-from-atop-the-jade-kings-throne | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) | 原始 OGG；未改音频数据；关于页滚幕专属循环 |
| Hard Battle 1 | MintoDog | https://opengameart.org/content/hard-battle-1 | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 原始 OGG；未改音频数据；1559 正篇战斗 BGM 循环播放 |
| Battle Sound Effects: Bow / RPG Sound Pack / 3 Melee Sounds / RPG Audio / Sound Pack 01 | ogrebane / artisticdude / remaxim / Kenney / wobbleboxx | https://opengameart.org/content/battle-sound-effects 等（逐项 URL 见 `game/assets/audio/LICENSES.md`） | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 响度归一化、Alarm 截短 2.2s、OGG 转码；游戏内 9 个事件音效 |
| Kenney UI Audio | Kenney | https://kenney.nl/assets/ui-audio | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 原始 OGG；选取 click2 / switch3 / click4 / switch1 / switch9；全局点击、确认、返回、拾取与事件提示 |
| Kenney Impact Sounds | Kenney | https://kenney.nl/assets/impact-sounds | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 原始 OGG；选取 Soft / Punch / Plate / Generic / Bell / Metal 各一条；敌兵受击、击杀、精英击杀、升级、冲刺与 Boss 提示 |
| golden-ui / Free UI Asset Pack 1 | buch / ctatz | https://opengameart.org/content/golden-ui ；https://opengameart.org/content/free-ui-asset-pack-1 | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 面板精灵裁切（九宫格）；白色符号染金色缩放 64×64；逐项署名见 `game/data/credits.json` |
| Jeff-FX-forge 1.1 像素攻击特效 16 组 | Jeff Studio | https://github.com/jeffstudio-dev/Jeff-FX-forge | 工具代码 [MIT](https://opensource.org/license/mit)；原创特效 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 使用像素工坊预设导出的精灵图；按武器/命中/敌兵事件旋转、缩放、叠层播放；帧图未手改；许可全文随 `game/assets/fx/jeff_fx/LICENSE.txt` |
| 霞鹜文楷 LXGW WenKai | LXGW（落霞孤鹜） | https://github.com/lxgw/LxgwWenKai | [SIL Open Font License 1.1](https://openfontlicense.org/open-font-license-official-text/) | 未修改字体文件；随包 `game/assets/fonts/OFL.txt` |
| game-icons.net SVG 101 个 | Delapouite / Lorc / Skoll / Willdabeast / Faithtoken / Caro Asercion | 每个图标的精确 URL 见 `game/assets/icons/game_icons/ATTRIBUTION.md` 与 `credits.json` | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) | 白色透明 SVG 在游戏内按 UI/卡牌类型调制；图形未改；逐项作者、来源、许可与文件映射完整登记 |
| Dungeon Crawl Stone Soup 具名图块 106 张 | DCSS contributors（维护：Chris Hamons；原始美术含 DENZI 等多人） | https://opengameart.org/content/dungeon-crawl-32x32-tiles | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | 原始包逐块导出为 32×32 PNG，保留原始文件名；未改色；目录仍在源码/包内，但当前场景改用地形原创瓦片，DCSS 仅作历史参考 |

- **历史说明（v1.17）**：以下 DCSS 用途描述属于重建前旧守城玩法；当前重构场景使用 `game/assets/tiles/yongchang/` 的原创明式抗倭瓦片（CC BY 4.0），DCSS 目录保留作参考但当前场景未引用。
- 用途：`game/assets/tiles/dcss/{wall,floor,water,door,tree}/*.png` 按**语义分区**铺设永昌堡地形（城内水田/夯土院落/街巷、灰石城墙、护城河与上河下河水面、东海滩涂、驿道、门与植被）。**图块一律按名引用**（`TileCatalog` 名字→图块映射），同一语义大面积只取一块，区域级换材质，禁止跨语义随机取块。
- 转换链：DCSS 原始包 → 逐块导出 32×32 PNG（`manifest.csv` 记录 category/name/opaque/edge_opaque/tileable）→ `TileCatalog` 建立具名查表 → `TileMapBuilder` 分区铺设。CC0 来源链完整。
- **已移除**：v1 `atlas_geology.png` 重着色图集、v2 由第三方 RWX 项目切分的 20×20 Tiled 图块集（`tiles/hv/**`）及其构建脚本、旧 Hard Vacuum 图块与切图脚本，均不再进入成品与仓库。
- 署名（片尾滚幕 `game/data/credits.json` 中为可点击条目）：
  > Terrain tiles from "Dungeon Crawl Stone Soup" by DCSS contributors, dedicated to the public domain under CC0 1.0. Source: https://opengameart.org/content/dungeon-crawl-32x32-tiles. Changes: exported as 32x32 PNG tiles and grouped semantically; colours unmodified.
  > Music: "Samurai Nights" by Maik Hoffmann (Majadroid), licensed CC BY 4.0. Source: https://opengameart.org/content/samurai-nights. License: https://creativecommons.org/licenses/by/4.0/. Changes: original demo MP3 re-encoded to Ogg Vorbis; looped in-game.
  > Music: "Views From Atop the Jade Kings Throne" by Hitctrl, licensed CC BY 3.0. Source: https://opengameart.org/content/views-from-atop-the-jade-kings-throne. License: https://creativecommons.org/licenses/by/3.0/. Changes: none to the original OGG audio data; looped in-game.
  > Music: "Hard Battle 1" by MintoDog, dedicated to the public domain under CC0 1.0. Source: https://opengameart.org/content/hard-battle-1. Changes: none; looped in-game.
  > Sound effects from OpenGameArt.org, CC0 1.0: Bow (ogrebane), Melee Sound (remaxim), Chop (Kenney), Sword Unsheath / Metal Ringing (artisticdude), Rise01 / Alarm / Upper01 / Downer01 (wobbleboxx). Exact source URLs and per-file changes: game/assets/audio/LICENSES.md.
  > Sound effects from Kenney UI Audio and Impact Sounds, CC0 1.0. Source: https://kenney.nl/assets/ui-audio and https://kenney.nl/assets/impact-sounds. Changes: selected files, pitch variation, and event throttling in-engine.
  > Icons: 101 game-icons.net SVG assets by Delapouite, Lorc, Skoll, Willdabeast, Faithtoken, and Caro Asercion, CC BY 3.0. Exact per-icon titles, authors, URLs, files, and runtime tinting: game/assets/icons/game_icons/ATTRIBUTION.md.
  > Font: LXGW WenKai by LXGW, licensed SIL OFL 1.1. Source: https://github.com/lxgw/LxgwWenKai.
  > UI: golden-ui (buch, CC0), Free UI Asset Pack 1 (ctatz, CC0).
- **恢复的第三方 BGM（2026-11-25 复核）**：Samurai Nights（Maik Hoffmann / Majadroid，CC BY 4.0，https://opengameart.org/content/samurai-nights）用于主菜单/选择页；Views From Atop the Jade Kings Throne（Hitctrl，CC BY 3.0，https://opengameart.org/content/views-from-atop-the-jade-kings-throne）用于关于页。两页均明确允许再分发与修改，不含 NC/ND；运行时文件、哈希与转换说明见 `game/assets/audio/LICENSES.md`。
- 合规说明：DCSS 图块为 CC0 1.0 公有领域贡献，允许商用与改编且不强制署名；本项目仍按 TASL（Title/Author/Source/License）完整披露，并在游戏内滚幕给出可点击链接。

### 5.5 设计参考（未复制代码）

| 项目 | 许可 | 用途 | 说明 |
|---|---|---|---|
| [OpenHV](https://github.com/OpenHV/OpenHV) | GPL-3.0 | 右栏结构、小地图、选择与建造链路的**交互参考** | 仅阅读其 `chrome/ingame-player.yaml` 等界面定义与规则文件，重写为 Godot 实现，未复制代码 |
| [OpenRA](https://github.com/OpenRA/OpenRA) | GPL-3.0 | 生产队列 / 侧栏逻辑 / 雷达组件的**结构参考** | 仅阅读引擎源码理解链路，未复制代码 |
| [Mindustry](https://github.com/Anuken/Mindustry) | GPL-3.0 | 定时出兵节奏（waveInterval / waveSpacing）与多格建筑的**思路参考** | 独立实现，未复制代码 |

> 本项目代码为 AGPL-3.0-or-later，与上述 GPL 参考项目的许可兼容；即便如此，本项目仍以「独立实现」为准，未做代码搬运，也未引入参考项目运行时依赖。

---

## 六、版权与许可声明

1. **项目代码**：原创代码采用 **AGPL-3.0-or-later**，许可证全文见仓库根目录 `LICENSE`，代码/资产范围与网络使用、对应源码义务见 `NOTICE`。任何分发或衍生作品须遵守 AGPL 条款并提供对应源码。
2. **原创非代码资产**：设计文档、数值表、AI 生成并后处理的图片采用 **CC BY 4.0**，全文见 `LICENSE-CC-BY-4.0.txt`。转载须署名、链接许可并注明修改；明确标识的原创 BGM 与开发音效母版提供 **CC0 1.0 或 CC BY 4.0** 选择，既有 CC0 奉献保留，第三方资产保留原许可。
3. **第三方内容**：当前场景地形为项目原创明式抗倭瓦片 88 格（CC BY 4.0）；历史 DCSS CC0 图块 106 张仍在目录中但当前场景未引用。正式角色序列帧为 CharacterForge 原创像素资产（CC BY 4.0），不含第三方角色骨架；攻击特效来自 Jeff-FX-forge 1.1 的 MIT/CC0 工具与原创预设。运行时 3 首 BGM 为 Samurai Nights（CC BY 4.0）、Views From Atop the Jade Kings Throne（CC BY 3.0）与 MintoDog「Hard Battle 1」（CC0 1.0）；20 个 SFX 全部为 CC0 1.0。字体为 OFL 1.1 霞鹜文楷；101 个 game-icons.net 图标为 CC BY 3.0。均按 TASL 署名，详见 `game/assets/audio/LICENSES.md` 与 `素材授权清单.csv`。MOSS 生成语音因输出授权未核实已移除，当前仅保留字幕回退。
4. **署名呈现**：全部署名以关于页/片尾电影滚幕（自然滚动、滚轮接管、来源链接可点击）在游戏内呈现，数据源 `game/data/credits.json`，与 `素材授权清单.csv` 一一对应。
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
| 第八节 | 最佳视听奖：第三方素材 >50% 不参与 | 当前场景地形为项目原创明式抗倭瓦片（CC BY 4.0）；运行时音频为 3 首第三方开放许可 BGM（CC BY 4.0 / CC BY 3.0 / CC0）+ 20 个 CC0 SFX，第三方图标/UI 装饰逐项署名；音频数量占比不作为素材体量比例，完整清单见 `素材授权清单.csv` |
| 第八节 | Dora 开源社区奖：代码 AGPL-3.0-or-later、原创非代码资产 CC BY 4.0、第三方保留原许可并署名 | 已按此策略声明（第六节）；`LICENSE`、`NOTICE`、`LICENSE-CC-BY-4.0.txt` 全文随仓库与导出包提供 |
| 第六节 | 提交材料含可追溯署名 | 游戏内片尾滚幕逐项列出作者/许可/可点击来源，数据源 `game/data/credits.json` |
| 第六节 | 提交封面与 5 分钟以内演示视频 | 1920×1080 封面与 91 秒 MP4 已完成本地验收并登记；Bilibili 上传与赛事标签待完成 |

---

## 八、锁定与外部提交事项

1. ~~将本声明版本号升至 v2.0~~ 已完成；2026-11-25 恢复两首合规 BGM 后升至 v2.1，标签发版流程调整后升至 v2.2，最终素材清单见 `素材授权清单.csv`。
2. 锁定提交使用 Git 标签 `v0.1.0`；标签触发 `.github/workflows/release.yml`，标签解析后的完整哈希、提交时间与产物 SHA-256 记录于 GitHub Release 的 `release-manifest.json`。
3. ~~补齐至少 3 篇内容不重复的开发者日志~~ 已完成：[核心玩法与文化](docs/开发者日志-01-核心玩法与文化.md)、[战斗表现与操作手感](docs/开发者日志-02-战斗表现与操作手感.md)、[音频确权与 Dora 发布](docs/开发者日志-03-音频确权与Dora发布.md)。
4. ~~若引入音效、音乐、字体或第三方素材，逐项补入清单~~ 已完成：字体/DCSS 具名图块/建筑与 UI 素材/原创角色序列帧/第三方音频（BGM+音效）/第三方 UI 装饰均已登记（具体条数以 `素材授权清单.csv` 为准）。
5. 外部提交仍需完成：Bilibili 视频与赛事标签、原子派公开发布与至少 20 个点赞、赛事项目提交和作品互评；这些结果不得由本地构建通过推定。Dora 仅保留默认源码兼容与静态检查，不作为 Release 或外部提交门槛。
