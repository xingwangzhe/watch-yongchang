# 技术借鉴：Mindustry 与 RWX 的图块 / 多格建筑架构

> 面向后续 AI Agent 的技术参考文档。记录两个开源项目的架构方法，以及本项目
> 《守望·永昌》的实际落地方案与踩坑经验。所有引用均基于实际克隆的源码。
>
> - Mindustry：`/home/xingwangzhe/桌面/Mindustry`（Anuken/Mindustry，Java）
> - RWX：`/home/xingwangzhe/桌面/RWX`（yomi2539/RWX，Rusted Warfare 重建版，Java/Kotlin）
> - 本项目实现：`game/scripts/tile_map_builder.gd`、`game/scripts/main.gd`

## 1. 为什么要借鉴这两个项目

本项目从「Path2D 画线 + Line2D 画路」迁移到图块地图，核心诉求来自用户：
- "绘制路径不太对，应该改成像 Mindustry 那样的图块 2D 图层，设计地图方便很多"
- "块也太大了，应该是小块，然后建筑可以占据多个瓦片才对"

Mindustry 是图块建造 +  logistics 的代表；RWX 是 RTS 多格建筑 + 精灵动画的代表。
两者覆盖了本项目图块系统的两个关键问题：**地形分层**与**多格建筑管理**。

## 2. Mindustry 的方法

### 2.1 瓦片数据模型（核心）
- **一维数组存储**：`Tiles.java:15` 用 `Tile[] array`，线性索引 `y*width+x`（`Tiles.java:79`）。
  一维数组比二维 `Tile[][]` 更缓存友好，且便于网络同步与序列化。
- **Tile 三层分离**（`Tile.java:39-47`）：同一个 Tile 内并存 `floor`（地板）、`overlay`（覆盖层，
  如矿脉/道路）、`block`（建筑/墙）。空瓦片三层均为 `Blocks.air`。
- **坐标转换**：`tilesize=8`（逻辑单位，`Vars.java:135`）；`worldx()=x*tilesize`（`Tile.java:166`），
  像素→瓦片 `Math.round(x/tilesize)`（`World.java:152`）。

### 2.2 传送带 / 物流（可映射为驿道补给线）
- `Conveyor.java:254` 每件物品用「段内进度 `pos∈[0,1]` + 方向」表示，到达 1.0 时经
  `pass()`（:300）移交下一瓦片；`acceptItem()/handleItem()`（:353,362）校验方向与容量。
- 方向用 0/1/2/3 = 左/下/右/上，`Geometry.d4[rotation]` 取偏移。
- **借鉴点**：驿道补给线用「next 指针 + 段内进度」轻量模型，转弯用 4bit 连接掩码选贴图
  （参考 `TileBitmask.java` 的 47 态 autotile，本项目简化为直道即可）。

### 2.3 寻路
- 主力是**流场 + Dijkstra 波前**（`Pathfinder.java:98` 的 `Flowfield[][][] cache`，
  `updateFrontier()` :498，`getNextTile()` :673），大量同类单位共享一张目标流场，成本远低于逐个 A*。
- 少量定点寻路用 `Astar.java:21-90`（PQueue + 曼哈顿启发式）。

### 2.4 素材组织
- 图集命名规范（`Floor.java:134-171`、`TileBitmask.java`）：`{name}` 基础图、
  `{name}1..N` 变体、`{name}-{0..46}` 八向 autotile 位掩码、`{name}-team-{team}` 阵营染色。
- **借鉴点**：瓦片命名带语义前缀，便于代码按规则加载变体。

## 3. RWX 的方法

### 3.1 多格建筑占格：锚点 + 双 Rect（关键差异）
- 建筑存世界坐标 `posX/posY`（`GameObject.java:37-40`），锚点在瓦片中心，
  `getTileOffsetX/Y()` 返回半格宽（`BaseUnit.java:2446-2453`）。
- 占格用两个**相对锚点的偏移矩形**（`BaseBuilding.java:30-33`）：
  - `buildingTargetRect`（`cc()`，视觉占格）
  - `buildingVelocityRect`（`cd()`，放置/寻路占格，通常更大）
  - 子类构造写死偏移，如 `CommandCenter` 为 `(-1,-1,1,1)` 即 3×3（`CommandCenter.java:96-97`），
    `NukeLauncher` 为 `(-2,-1,2,1)` 即 4×2。
- 网格本身只存**派生索引**：`PathCostMap` 用 `byte[] d/e/f` 标记阻挡，不存单位引用；
  `c(OrderableUnit)`（:395-433）遍历单位按 Rect 逐格写 -1。

### 3.2 建筑动画：单张大精灵 + 帧号状态机
- `BaseBuilding.c(float)`（:343-350）以 `currentAnimationFrame * es` 取帧条矩形，
  **一次性绘制整栋建筑**（非逐格瓦片拼接）。帧宽高由 `T()/U()` 设置。
- 帧推进由各建筑 `update` 手动计时：`AirFactory` 0..4 循环（:124-141），
  `CommandCenter` 0..6 乒乓 + 播完置 70 待机（:196-208）。无统一 AnimationPlayer。
- **动画与占格彻底解耦**：占格只读 Rect，动画只改帧号。炮塔顶盖是另一张可旋转精灵
  （`TurretFactory.java:621-638` `drawTurret()`），在底座绘制后单独叠上去。
- 渲染排序：`drawLayer → drawOrder → posY` 的 **Y-sort**（`GameObjectComparator.java:14-30`）。

### 3.3 放置预览与寻路更新
- 校验 `getPlacementFailureReason`（`OrderableUnit.java:5032-5067`）返回 i18n 错误键而非 bool；
  预览逐格画绿边（合法）/红填充（非法）（`TileMap.java:1232-1257`）。
- 建筑增删触发 `PathEngine.a()`（`PathEngine.java:285-296`）**全量重建**阻挡数组，带 50 次节流
  （`PathCostMap.java:398-402`），无增量更新。

## 4. 本项目落地方案

### 4.1 当前实现（`tile_map_builder.gd`）
- **32px 瓦片、40×22 网格**（源材料 20×20 放大到 32×32，nearest 保持像素风）。
- 四层 `TileMapLayer`：`GroundLayer`(-40) / `RoadLayer`(-30) / `StructureLayer`(-20) / `DecorLayer`(-10)。
- 多格建筑：塔 3×3（`TOWER_SIZE`）、主堡 3×8（`KEEP_SIZE`），用静态函数
  `tower_anchor()/tower_center()/keep_anchor()/keep_center()` 派生坐标。
- **路径从网格派生**：`LANE_ROWS=[7,11,15]`，`lane_y(row) = (row+2)*tile/2`；
  Path2D 只是不可见运动骨架，`unit.gd`/`tower.gd` 零改动。

### 4.2 与 RWX 的差距及后续改进方向
1. **锚点 + footprint 资源管理**：当前建筑的 anchor/size 是散落的常量，尚未封装成
   `BuildingPlacement` 资源（含 `footprint: Rect2i` 与更大的 `path_footprint: Rect2i`）。
   按 RWX 模式重构可从根上消除塔精灵与塔基色块的对齐问题。
2. **Y-sort**：塔与单位目前靠 `z_index` 分层，多格建筑重叠时顺序不对。应给父节点开
   `y_sort_enabled`，建筑精灵 `offset = -size/2` 使锚点落在中心格。
3. **动画与占格解耦**：当前塔用 `Sprite2D` 静态贴图。可仿 RWX 用一张覆盖 3×3 的
   `AnimatedSprite2D`（帧条 `frame*es`），攻击/待机状态机独立驱动，占格只读 footprint。
4. **寻路阻挡**：当前无寻路（单位沿固定路径）。若将来加建筑放置，用 `AStarGrid2D`
   在建筑增删时按 `path_footprint` 批量 `set_point_solid`，并加 dirty 节流。
5. **放置预览**：复用 footprint 逐格画绿/红，校验返回失败原因字符串供 UI 提示。

## 5. 素材：Hard Vacuum（CC BY 3.0）

- 来源：https://lostgardenhome.files.wordpress.com/2019/09/hardvacuum.zip
- 作者：**Mark Ferrari（Lost Garden）**，许可 **CC BY 3.0**（署名 + 相同方式共享非强制，商用允许）。
- 技术：Amiga DPaint / Brilliance 绘制，8-bit 调色板 BMP。
- 本项目使用：`assets/third_party/hardvacuum/` 原始包 + `tools/convert_hardvacuum_tiles.py`
  切图并重着色 → `game/assets/tiles/hardvacuum/`（109 张 32×32 RGBA）→
  `game/assets/tiles/atlas_geology.png`（10 类代表瓦片图集）。
- **署名模板**（须写入游戏内 About 与 `AI使用与素材声明.md`）：
  > Terrain tiles derived from "Hard Vacuum" by Mark Ferrari (Lost Garden),
  > licensed CC BY 3.0. Source: https://lostgardenhome.files.wordpress.com/2019/09/hardvacuum.zip
  > Changes: chroma-key removed, tiles re-colored to geology palette, rescaled to 32x32.

## 6. 踩坑记录（重要，避免重复）

1. **新建脚本的 `class_name` 在 gda 静态校验时全局缓存未刷新** → 报 `Identifier not declared`。
   解法：用 `const TileMapBuilder = preload("res://scripts/tile_map_builder.gd")` 显式引用。
2. **新 PNG 未生成 `.import` 时，`load()` 返回空纹理**，画面只剩清屏灰底且 `diag` 无错误。
   解法：新增资源后必须 `godot --path game --headless --import` 重建导入缓存。
   删过 `.godot/imported` 后同样要执行，否则启动报一堆 `resource_load_failed`。
3. **Hard Vacuum 图集的瓦片不是 32px 连续排列**：真实瓦片 20×20，步长 40px，
   列起点 `0/40/80`、行起点 `1/41/...`（中间 20px 是透明间隔）。按 32px 步长切会得到
   带缝隙的错位瓦片。解法：先用列/行投影检测真实边界，再 resize 到 32×32。
4. **无头截图不占桌面焦点**：启动 Xvfb（`Xvfb :99 -screen 0 1280x720x24`），
   用 `DISPLAY=:99 gda daemon start --project game --windowed` 启动，
   再 `DISPLAY=:99 gda screen capture --output <png>`。`--windowed` 是裸布尔标志，
   不能写成 `--windowed true`。
5. **道路上下各铺一层边缘瓦片会吃掉草地层次**：Mindustry 的 overlay 是单层薄覆盖。
   本项目只在道路行本身铺路面，草地透出来后视觉明显改善。

## 7. 验收基线（改动后必须保持）

- `./run-test.sh verify` → `PASS=19 FAIL=0`
- `gda scene preflight res://scenes/main.tscn --project game --frames 20 --json` → `started=true`
- Xvfb 无头截图确认：三路驿道、水渠、多格塔基/主堡、单位与塔均可见
