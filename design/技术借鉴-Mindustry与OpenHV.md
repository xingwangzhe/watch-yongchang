# 技术借鉴：Mindustry 的出兵节奏 与 OpenHV/OpenRA 的交互链路

> 本文是**动手改前必读**的索引文档。细节证据（文件路径:行号）见
> [`逆向-OpenHV出兵与交互链路.md`](逆向-OpenHV出兵与交互链路.md)。
>
> 参考仓库只读、不入库：
> - OpenHV <https://github.com/OpenHV/OpenHV>（GPL-3.0）→ 本地 `/home/xingwangzhe/桌面/OpenHV`
> - OpenRA <https://github.com/OpenRA/OpenRA>（GPL-3.0）→ 本地 `/home/xingwangzhe/桌面/OpenRA`
> - Mindustry <https://github.com/Anuken/Mindustry>（GPL-3.0）→ 仅作思路参考
>
> **本项目为独立实现，未复制上述项目代码。** 原 `技术借鉴-Mindustry与RWX.md` 已删除，
> RWX（yomi2539/RWX）派生的代码与切图资产已从仓库移除，**禁止再引入**。

---

## 一、出兵：从「米拉奇战记式三波」改为「Mindustry 式定时波次」

| 维度 | 旧（米拉奇战记式） | 新（Mindustry 式） |
|---|---|---|
| 节奏 | 三波写死，清场→间歇→下一波 | **永远有下一波在倒计时**，波间隔固定 |
| 触发 | 波清空后进 PREPARE，12s 后开波 | `WAVE_INTERVAL` 到点即开，不依赖清场 |
| 波内 | 按 `interval` 连续放 | `SPAWN_SPACING` 逐个放，波内形成「流」 |
| 难度 | 波表写死数量/兵种 | 由波号推导：数量 `4+2n`、血量 `+15%/波`、速度 `+1.5%/波`、兵种分段解锁 |
| 终局 | 三波全清即胜 | 撑满 `TIME_LIMIT_SEC`（480s）即胜，主堡破即败 |
| 上限 | 无 | 单波 ≤26、场上 ≤120，防爆量卡顿 |

实现：`game/scripts/spawn_system.gd`
- 两个计时器：`countdown`（波间）+ `_spacing_timer`（波内）
- 波号 → 强度的三个纯函数：`hp_scale_for()` / `speed_scale_for()` / `_composition()`
- `tick(delta, alive_enemies)` 由 `main._process` 驱动；`rush_next_wave()` 让玩家提前迎敌（空格）
- HUD 每帧读 `wave_countdown_changed` → 顶栏「下一波 mm:ss」

Mindustry 侧对应概念（只借鉴思路）：`WaveSpawner.waveInterval` / `waveSpacing`、
按波号递增的 enemy 强度、以及「场上单位过多时截断本波」的保护。

---

## 二、交互链路：选择 → 侧栏 → 建造

### 2.1 状态机（本项目落点：`main.gd`）

```
[idle]  左键点空地 → 清空选择 → 右栏 close()（默认不出现）
        左键点单位/建筑 → _select_object() → sidebar.show_context()
        按 B / 点右下「营建」→ sidebar.show_context(&"build")

[build] 右栏点建造项 → build_requested → build_mode=true，BuildPreview 可见
        左键 → _try_build_at() → 成功：退出放置模式并自动选中新建筑 → produce/inspect
        右键 / Esc → _cancel_build() → 回到建造菜单

[pause] Esc 无放置模式且无选中 → 暂停面板
```

### 2.2 三条来自 OpenRA 的关键结论（按此实现）

1. **放置是「输入模式」而不是「一直可造」**：只有 `build_mode=true` 时左键才落建筑，
   否则左键只做选择。这解决了旧版「任何左键都尝试建造」的错位。
2. **合法性判定四步**：地图内 → 未被占用 → 地形允许（非水/墙/路）→ 资源足够；
   任一步失败只发 `build_failed`，不产生任何副作用。
3. **侧栏默认空的机制**：内容为空就直接不画（这里是 `visible=false`），
   只有「选中对象」或「主动打开建造菜单」才出现；关闭时清空上下文，不残留上一次的页签。

> 与 OpenRA 的一处**刻意不同**：OpenRA 放下建筑后不自动选中；本作**落地即选中**，
> 因为连续布防时右栏能立刻显示新建筑的产能，操作更顺。

### 2.3 侧栏三态（`game/scripts/ui/sidebar_panel.gd`）

| 上下文 | 触发 | 右侧栏内容 |
|---|---|---|
| `build` | 按 B / 点「营建」 | 建筑列表：图标 + 名称 + 造价 + 快捷键，点选进入放置模式 |
| `produce` | 选中军械坊 / 烽火台 | 该建筑可生产的兵种列表，点击直接出兵（扣银） |
| `inspect` | 选中单位 / 箭塔 | 只读：名称、阵营、血量条、数值 |

### 2.4 小地图（`game/scripts/ui/minimap_panel.gd`）

复刻 OpenRA `Radar` 组件的四件事：
1. 1px/格离屏底图（按 `zone_map` 语义上色，nearest 放大）
2. 己方单位青点 / 敌方单位红点 / 己方建筑方框
3. 当前视口白框
4. 点击/拖拽跳转（左键跳转并保持选择，右键只跳转）

---

## 三、地形：具名图块，按语义铺设

旧实现从精灵表里**随机取块**拼地面，被明确否决。现方案：

- 图块来源：`game/assets/tiles/hardvacuum/{ground,road,rock,water}/*.png`，32×32，**文件名即语义**
  - `moss_*` 草地/农田 · `sand_*` 沙地/滩涂 · `road_*` 土路 · `road_rock_*` 石板路
  - `road_sand_*` 沙路 · `cliff_*` 亮崖石（城墙）· `cliff_dark_*` 暗崖石 · `stone_00` 石块 · `water_*` 水面
- 查表：`game/scripts/tile_catalog.gd`（名字 → 图块 source/坐标）
- 变体：**只允许同语义内确定性轮换**（如 `(c*7+r*3) % 13`），禁止跨语义随机
- 分区：`tile_map_builder.gd` 按《永昌堡十三进士与抗倭纪略》的城池形制分区铺设，
  并输出 `zone_map`（`wall/gate/moat/river/road/city/field/sea`）供小地图上色

---

## 四、踩坑记录（本轮新增）

1. **`PathFollow2D` 的 `progress` 与敌人方向**：己方折线必须定义为「城内主堡 → 城外刷新点」，
   玩家兵 `direction=+1` 从 0 出发，敌兵 `direction=-1` 从 `baked_length` 出发；
   反过来定义会让敌兵出生就在城门口、直接扣主堡血。
2. **侧栏控件必须在 `CanvasLayer` 里**：直接挂 `Node2D` 会跟世界坐标一起缩放/平移。
3. **`class_name` 的全局缓存不可靠**：跨脚本引用统一用 `const X = preload(...)`。
4. **放置模式不关掉时，左键会一直尝试建造**：必须显式 `build_mode` 门控 + 右键/Esc 取消。
5. **TileMapLayer 用 32px 原生图块**：`tile_set.tile_size = Vector2i(32,32)`，不要再靠
   `layer.scale = 2` 放大 20px 图，否则变体边界会出现 1px 缝隙。
