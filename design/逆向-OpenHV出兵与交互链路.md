# 逆向：OpenHV / OpenRA 的「出兵 + 选择 + 建造 + 侧栏 + 小地图」链路

> 用途：为《守望 · 永昌》重做 RTS 交互层提供**可落地**的参考规格。
> 逆向对象：
> - `/home/xingwangzhe/桌面/OpenRA`（引擎 C# 源码）
> - `/home/xingwangzhe/桌面/OpenHV`（模组 YAML / chrome）
> 全部结论均给出 `文件路径:行号` 证据，未标注出处的内容视为「本项目设计建议」，与参考实现无关。
> 本项目落点以 `game/` 现有脚本为基准（`spawn_system.gd` / `build_system.gd` / `build_preview.gd` / `minimap.gd` / `hud.gd` / `game_state.gd`）。

---

## 一、结论摘要（可执行）

1. **OpenRA 的生产是「玩家点一下 → 入队 → 队列自己 tick → 完成 → 出场」的四段式**，与 Mindustry 的「计时器自动波次」不是同一模型；但**队列 tick / 出场点选择 / 集结点 / 失败回滚**这四块可以整体复用（`ProductionQueue.cs:338-367`、`Production.cs:51-103`）。
2. **扣钱有两种模式，必须显式选一种**：`PayUpFront=false`（默认）时**按进度逐 tick 扣款**（`ProductionItem.Tick` 内 `expectedRemainingCost = TotalCost * RemainingTime / TotalTime`，`ProductionQueue.cs:787-802`）；`PayUpFront=true` 时入队一次性扣全款（同文件 `621-632`）。本项目「银两」是稀缺资源、且 UI 要即时反馈，建议**建单位用逐 tick 扣（有取消退款语义）、建建筑用全额扣**。
3. **build time 的唯一公式**是 `cost × 百分比修饰器`：`BuildDuration == -1` 时直接用 Cost，然后依次乘 `IProductionTimeModifierInfo` / `BuildableInfo.BuildDurationModifier` / `ProductionQueueInfo.BuildDurationModifier`（`ProductionQueue.cs:541-556`）；`ClassicProductionQueue` 再按**同类生产建筑数量**做 `SpeedUp` 折扣（`ClassicProductionQueue.cs:140-159`，OpenHV 配置 `player.yaml:70-73` 为 `100,75,50,25`）。
4. **出场位置由 `Exit` 决定，方向由「出场点 → 出生点」自动算**：`exit = self.Location + ExitInfo.ExitCell`、`spawn = CenterPosition + ExitInfo.SpawnOffset`、朝向 `delta.Yaw`（`Production.cs:59-78`）；同时写入 `ExitDelay`（出场延迟）和 `RallyPointInit`（集结点路径）（`88-89`）。**这就是"兵从建筑门口走出来"的全部机制，没有寻路魔法。**
5. **选择是纯客户端、无 Order 的本地状态**，核心只有三条分支：点选（deadzone 内退化为单点，取最高优先级）、框选（按优先级分组后取最高一组）、双击同类（选屏幕内同 `ISelectable.Class`）（`SelectionUtils.cs:61-74`、`WorldInteractionControllerWidget.cs:127-161`）。
6. **选择变化通过 `INotifySelection.SelectionChanged()` 广播给所有世界 trait**，UI 是被动接收方（`Selection.cs:125-127`）。这是「选择驱动侧栏刷新」的唯一入口，Godot 侧对应一个 `selection_changed` 信号。
7. **侧栏"默认不显示"的准确机制**（与常见误传不同，需按此实现）：`ProductionPaletteWidget.Draw()` 在 `CurrentQueue == null` 时**直接 return**（`ProductionPaletteWidget.cs:551-552`）；而队列只有在玩家**拥有可用生产建筑**时才 `Enabled`（`ClassicProductionQueue.cs:52-73`）。所以"开局空侧栏"成立。但**一旦选中过生产建筑，取消选择后页签不会清空**——`ProductionQueueFromSelection.SelectionChanged()` 在找不到队列时是 `return` 而非置空（`ProductionQueueFromSelection.cs:66-67`），只有生产建筑离开世界才置空（`ProductionPaletteWidget.cs:239-240`）。
8. **建造是「输入模式（IOrderGenerator）切换」，不是布尔开关**：点图标 → `World.OrderGenerator = new PlaceBuildingOrderGenerator(...)`（`ProductionPaletteWidget.cs:298-312`）；取消 → `World.CancelInputMode()` 恢复默认 `UnitOrderGenerator`（`World.cs:172`）。放置模式每帧重算 footprint 合法性给幽灵上色（`PlaceBuildingOrderGenerator.cs:249-304`）。
9. **合法性判定顺序固定为 4 步**：地图内 → 无 actor 占格 + 无建筑影响（除非可替换）→ 非 ramp 且地形允许 → 相邻可建造区（`BuildingUtils.cs:19-88`、`Building.cs:203-247`）。任何一步失败都播放 `CannotPlace` 通知并且**不产生 Order**（`PlaceBuildingOrderGenerator.cs:198-204`）。
10. **OpenRA 落地建筑后不自动选中新建筑**（全库只有 `WorldInteractionControllerWidget` / `ControlGroups` / `Transform` 会改选择，已 grep 确认）。**本项目建议反其道而行：落地即选中并切到对应页签**，因为本作是"建造 + 布防"节奏，玩家连续放塔体验优先。

---

## 二、出兵链路

### 2.1 参与者与职责

| 角色 | OpenRA 实现 | 职责 |
|---|---|---|
| 生产队列 | `ProductionQueue`（per-actor）/ `ClassicProductionQueue`（per-player 共享） | 持有 `Queue` 列表、tick、扣钱、退款、技术树 |
| 生产者 | `Production` trait（挂在建筑上） | 选出场点、创建 actor、处理集结点 |
| 出场点 | `Exit` trait（可多个，`Exit@2`） | `ExitCell` / `SpawnOffset` / `Facing` / `Priority` |
| 集结点 | `RallyPoint` trait | 路径点数组，决定出场朝向与后续移动 |
| 主建筑 | `PrimaryBuilding` trait | 多座同类建筑时指定"由谁出兵" |
| 进度条 | `ProductionBar` trait | 建筑头顶的建造进度条（读队列最小值） |

关键：**队列可以在玩家身上**（`[TraitLocation(SystemActors.Player)]`，`ClassicProductionQueue.cs:21-24`），建筑只负责"提供产能 + 提供出场点"。这是本项目最值得照抄的分层——**队列是数据，建筑是产能**。

### 2.2 完整时序（tick 级）

```
玩家点击图标
  ProductionPaletteWidget.HandleLeftClick()            ProductionPaletteWidget.cs:319-365
    └ World.IssueOrder(Order.StartProduction(actor, item, count, queued))
                                                       Order.cs:314-317
  ProductionQueue.ResolveOrder("StartProduction")      ProductionQueue.cs:447-539
    ├ 校验：该队列能否造 / 数量上限 QueueLimit / ItemLimit / BuildLimit   468-486
    ├ cost = GetProductionCost(unit)                  558-568
    ├ time = GetBuildTime(unit, bi)                   541-556（仅用于"卡住时是否播 Blocked 音"）
    └ BeginProduction(item, hasPriority)              621-663
        └ PayUpFront ? 立即 TakeCash(TotalCost) : 什么都不扣    623-632

每 tick（队列挂载点）
  ProductionQueue.Tick(self)                           ProductionQueue.cs:338-359
    ├ 扫描 productionTraits → anyEnabled / anyUnpaused  346-352
    ├ !anyEnabled → ClearQueue()（全退款）              354-355
    └ TickInner(self, allPaused)                      361-367
        ├ CancelUnbuildableItems()  不再可造 → 退款并出队   369-402
        └ Queue[0].Tick(playerResources)   只 tick 队首！    366

  ProductionItem.Tick(pr)                              ProductionQueue.cs:758-809
    ├ 首次：RemainingTime = TotalTime = GetBuildTime()  760-766
    ├ Done → OnComplete() 后 return（完成后每 tick 都回调） 768-773
    ├ Paused → return                                   775-776
    ├ 低电：Slowdown 攒够 LowPowerModifier 才前进一帧     778-785
    ├ 非 PayUpFront：按时间比例扣款                       787-802
    │    expected = TotalCost * RemainingTime / TotalTime
    │    costThisFrame = RemainingCost - expected
    │    TakeCash(costThisFrame) 失败 → 回滚 ResourcesPaid 并 return
    └ RemainingTime-- ；到 0 → Done = true               804-808

完成回调（AddFrameEndTask 内）
  ProductionQueue.cs:497-527
    ├ unit 是建筑 → 只播 ReadyAudio，**不创建 actor**（等玩家放置）
    └ unit 是单位 → BuildUnit(unit)                    682-709 / ClassicProductionQueue.cs:98-138
        ├ 候选生产建筑排序：IsPrimaryBuilding 优先 → ActorID 降序   106-111
        ├ 逐个尝试 p.Trait.Produce(...)，成功才 EndProduction(item)  126-131
        └ 一个生产者都没有 → CancelProduction(name, 1)             134-135

  Production.Produce(...)                              Production.cs:118-132
    ├ SelectExit()：有集结点 → 取离 rally.Path[0] 最近的 Exit
    │              无集结点 → RandomExitOrDefault（按 Priority 分组洗牌）   105-116
    ├ CanUseExit()：Mobile.CanEnterCell(出口格) 否则换下一个     134-142
    └ DoProduction()                                   51-103

  Production.DoProduction(...)                         Production.cs:51-103
    ├ exit  = self.Location + ExitInfo.ExitCell          61
    ├ spawn = self.CenterPosition + ExitInfo.SpawnOffset 62
    ├ facing = (CenterOfCell(exit) - spawn).Yaw ?? ExitInfo.Facing   65-78
    ├ exitLocations = RallyPoint.Path（非空时）否则 [exit]            80
    ├ inits += LocationInit(exit) / CenterPositionInit(spawn) / FacingInit
    │        + CreationActivityDelayInit(ExitDelay) + RallyPointInit  82-89
    └ World.AddFrameEndTask(w => CreateActor(...)) + INotifyProduction.UnitProduced   92-102
```

### 2.3 失败 / 暂停 / 取消 / 退款

| 场景 | 行为 | 证据 |
|---|---|---|
| 右键图标（未开始或已完成或队列不支持暂停） | `CancelProduction(name, count)`，**立即全退款** | `ProductionPaletteWidget.cs:392-399`、`ProductionQueue.cs:575-611` |
| 右键图标（进行中） | `PauseProduction(name, true)`，不退款，显示 HOLD | `ProductionPaletteWidget.cs:400-407` |
| 左键点已暂停项 | `PauseProduction(name, false)` 恢复 | `ProductionPaletteWidget.cs:327-335` |
| 生产建筑被摧毁 / 被卖 / 变形 / 换主 | `ClearQueue()` 全额退款并清空 | `ProductionQueue.cs:226-232`、`188-203` |
| 玩家失去所有该类生产建筑 | 队列 `Enabled=false` → `ClearQueue()` | `ClassicProductionQueue.cs:52-73` |
| 出口被堵 | `Produce` 返回 false → 播 `BlockedAudio`，item 留在队列（`Done` 仍为 true，下 tick 重试） | `Production.cs:118-132`、`ProductionQueue.cs:513-525` |
| 队列里有 Done 的建筑但长期不放置 | 无超时，一直挂着（放置模式的 `Tick` 只在"队列里没有 Done 的该项"时才 `CancelInputMode`） | `PlaceBuildingOrderGenerator.cs:227-234` |

退款公式（两处一致）：`RefundResources(ResourcesPaid)` + `RefundCash(TotalCost - RemainingCost)`（`ProductionQueue.cs:596-603`、`384-393`）。

### 2.4 集结点（RallyPoint）

- 路径是 `List<CPos>`，初始值来自 `RallyPointInfo.Path`（相对建筑左上角的偏移）（`RallyPoint.cs:45-46`、`73-76`）。
- 下达方式：地形目标 + `SetRallyPoint` 命令；`order.Queued == false` 时先 `Path.Clear()`（`RallyPoint.cs:120-138`）。
- `Stop` 命令会清空路径（`122-126`）——**即"停止"= 取消集结点**。
- `ForceSetType` 允许 Ctrl 指定"只有最靠近的那座同类建筑改集结点"（`RallyPoint.cs:181-190`、`PrimaryBuilding.cs:90-91`）。
- 出场时 `RallyPoint.Path` 会作为新单位的 `RallyPointInit` 注入，单位出生后自己走（`Production.cs:80, 88`）。

### 2.5 OpenRA「玩家点击生产」 vs Mindustry「敌方定时自动出兵」——抽象与可复用点

OpenRA 里**唯一接近"自动出兵"的现成 trait 是 `ActorSpawnManager`**（挂在 world 上）：

- 参数：`Minimum` / `Maximum` / `InitialDelay` / `SpawnInterval: [6000]`（支持 1 或 2 个值 = 定值或区间随机）/ `Actors`（随机池）/ `Owner`（`ActorSpawnManager.cs:22-44`）。
- tick：`--initialDelay` → `actorsPresent >= Maximum` 则跳过 → `--spawnCountdown` 且未到 Minimum 才继续 → 随机刷新点 → `do { Spawn } while (actorsPresent < Minimum)`（`90-121`）。
- 刷新点来自 `ActorSpawner` trait，按 `Types` 集合匹配（`136-143` + `ActorSpawner.cs:16-31`）。
- 创建 actor 用 `World.AddFrameEndTask`（`125-129`），与生产链路同款延迟创建，避免 tick 中途改世界。

**两者的可复用点分解：**

| 能力 | OpenRA 出处 | 是否可移植到"自动出兵" |
|---|---|---|
| 队列 tick + 进度百分比 | `ProductionItem.Tick` | ✅ 完整复用（波内单兵"造出来"的计时） |
| 扣费（按进度/一次性） | `ProductionQueue.cs:787-802` | ✅ 敌方免扣费，但"道具/技能出兵"需要 |
| 出场点选择（多出口/优先级/堵住重试） | `Production.cs:105-142` + `Exit.cs:50-93` | ✅ 完整复用，三路驿道 = 3 个 Exit |
| 集结点 → 出生后自动走位 | `Production.cs:80,88` + `RallyPoint` | ✅ 复用（敌方目标点 = 我方主堡） |
| 上限/间隔/首延迟/随机池 | `ActorSpawnManager` | ✅ 完整复用（这是"定时出兵"的骨架） |
| 强度随时间递增 | ❌ OpenRA 无内建（只有 `BuildLimit` 与 `MapCreeps`） | ⚠️ 需自研曲线 |

**建议的 Godot 侧抽象（三计时器 + 一队列）：**

```
[敌方] WaveDirector（替代并扩展现有 spawn_system.gd）
  batch_interval      : float   波间隔（Mindustry: waveInterval）
  intra_batch_spacing : float   波内放人间隔（Mindustry: waveSpacing）
  initial_delay       : float   开局准备期
  max_alive           : int     场上存活上限（达上限则本波截断，参照 spawn_system.gd:166-170）
  strength(t)         : {count, hp_scale, speed_scale, pool}   随时间单调递增的纯函数
  tick(delta) → 到点则 begin_batch(); 批内到点则 emit unit_requested(...)

[我方] ProductionService（替代 main.gd 里"点按钮立即花钱 spawn"）
  Queue: Array[ProductionItem{type, total_time, remaining_time, total_cost, remaining_cost, paid, done, paused}]
  tick(delta) → 只推进 Queue[0]（对齐 ProductionQueue.cs:366）
  complete → emit unit_ready(type) → 由 ExitRouter 选出口 → 实例化 → 设集结点
```

**强度曲线的两条硬约束（从 OpenRA 学到的）**：
1. **必须有上限**，否则后期必然卡死。OpenRA 用 `BuildLimit` + `Maximum` 双保险（`ProductionQueue.cs:433-439`、`ActorSpawnManager.cs:98-99`）。
2. **必须可被外部暂停**。OpenRA 的 `PausableConditionalTrait`（`Production.cs:21,33`）让"停电/被占领"能整队列冻结；本项目对应"暂停菜单 / 文化事件冻结"。

---

## 三、选择链路

### 3.1 状态机

```
                    ┌──────────────────────────────────────────┐
                    │              NO_SELECTION                │
                    └───┬──────────────┬───────────────┬───────┘
     左键 down+up 在单位上│              │左键 down      │双击
     (deadzone 内)       │              │再 up 拖出框    │(MultiTapCount>=2)
                        ▼              ▼               ▼
                  SINGLE_SELECT     DRAG_BOXING    SAME_CLASS_ON_SCREEN
                        │              │ 框选完成        │
                        │              ▼                 │
                        │        MULTI_SELECT ◄──────────┘
                        │              │
        Shift+点选(切换) │              │ Shift+框选(并集)
                        └──────────────┴──────► 仍是 / 变 MULTI_SELECT
                        │
   右键 up（无有效拖框） │  → Clear()（Classic 鼠标风格，且当前是 UnitOrderGenerator）
                        ▼
                  NO_SELECTION

  独立分支：PLACING（放置模式）
    进入：点建造图标且 item.Done 且是建筑 → OrderGenerator = PlaceBuildingOrderGenerator
    期间：Classic 风格下 Selection.Clear()，且 HandleMouseInput 走"非 UnitOrderGenerator"捷径直通 ApplyOrders
    退出：落地成功 / 右键取消 / 队列无该项 / Esc
```

### 3.2 各路证据

**① 点选 / 框选的入口统一在 `HandleMouseInput`**

```csharp
// WorldInteractionControllerWidget.cs:94-100
if (World.OrderGenerator is not UnitOrderGenerator uog)
{
    ApplyOrders(World, mi);      // 放置模式：鼠标事件直接变成 Order
    isDragging = false; YieldMouseFocus(mi); return true;
}
```

- deadzone：`IsValidDragbox => isDragging && (dragStart - mousePos).Length > SelectionDeadzone`（`:38`）。
- 左键 Down 开始拖（只有 Classic 风格或 ActionButton 不是左键时才记拖框起点）（`:102-112`）。
- 左键 Up 的三分支（`:114-168`）：
  1. 若"命令覆盖选择"（`uog.InputOverridesSelection`）且选择非空且无有效拖框 → **当成下令**，返回（`:116-125`）。
  2. `multiClick`（`mi.MultiTapCount >= 2`）→ 取鼠标下最高优先级单位，读其 `ISelectable.Class`，**选屏幕上所有同 Class 单位**，`Combine(..., isCombine:true, isClick:false)`（`:127-145`）。
  3. 否则框选：`Combine(World, newSelection, shift, dragStart == mousePos)`（`:157-161`）——**`isClick = dragStart == mousePos` 就是"没拖动=点选"的判定**。
- 结束时**一定 `World.CancelInputMode()`**（`:164`）——退出放置模式。
- 右键 Up：非有效拖框时，Classic 风格先 `Selection.Clear()` 再 `ApplyOrders`（`:170-180`）。

**② 框内取谁：`SelectionUtils`**

```csharp
// SelectionUtils.cs:61-74
if ((a - b).Length <= SelectionDeadzone) a = b;        // 框太小 → 退化为点选
if (a == b) return SelectHighestPriorityActorAtPoint(world, a, modifiers);
return world.ScreenMap.ActorsInMouseBox(a, b).Select(...)
        .SubsetWithHighestSelectionPriority(modifiers); // 框选：只取最高优先级那一组
```

**③ 优先级算法（很关键，决定"点重叠单位时选中谁"）**

```csharp
// SelectableExts.cs:29-61
basePriority = ISelectableInfo.Priority
              （Ctrl 或 Alt 且 info.PriorityModifiers 命中 → int.MaxValue）
关系修正：自己 0 / 盟友 -30 / 中立 -60 / 敌方 -90
// SelectableExts.cs:73-88
最终 key = basePriority - (pixelDistance << 16)   // 距离比优先级低 16 位
```
→ **优先级是主序，像素距离是次序**。本项目照抄即可（塔 > 单位 > 建筑）。

**④ 选择集合的写入：`Selection.Combine`**

```csharp
// Selection.cs:91-117
if (isClick) {                                  // 点选
    var one = newSelection.Take(1);
    if (isCombine) actors.SymmetricExceptWith(one);   // Shift+点选 = 反选
    else           { actors.Clear(); actors.UnionWith(one); }
} else {                                        // 框选
    if (isCombine) actors.UnionWith(newSelection);    // Shift+框选 = 并集
    else           { actors.Clear(); actors.UnionWith(newSelection); }
}
UpdateHash();
// 125-127：广播
Sync.RunUnsynced(world, () => world.OrderGenerator.SelectionChanged(world, actors));
foreach (var ns in worldNotifySelection) ns.SelectionChanged();
```

`SelectionChanged` 同时通知 **OrderGenerator** 和 **所有 `INotifySelection`**（`:125-127`）——侧栏就是后者。

**⑤ 自动清理与悬停高亮**

- `Selection.Tick`：移除"已不在世界"或"敌方且在迷雾中"的项（`Selection.cs:167-177`）。
- `SetRollover` / `RolloverContains`：鼠标悬停高亮是独立列表，不污染选择（`:156-165`）。
- 拖框过程中的实时高亮：`Draw()` 里用同一套 `SelectActorsInBoxWithDeadzone` 算 rollover（`WorldInteractionControllerWidget.cs:56-83`）。

### 3.3 选择结果如何驱动侧栏刷新

唯一通道：`INotifySelection.SelectionChanged()` → `ProductionQueueFromSelection`（见 §5.2）。**本项目对应一个 Autoload 信号**，不要让 HUD 去轮询 `get_tree().get_nodes_in_group()`。

---

## 四、建造链路

### 4.1 状态机

```
NORMAL（OrderGenerator = UnitOrderGenerator）
  │ 侧栏点建筑图标（item.Done 且 actor 有 BuildingInfo）
  │   ProductionPaletteWidget.cs:298-312
  ▼
PLACING（OrderGenerator = PlaceBuildingOrderGenerator）
  │
  ├─ 每帧：TopLeft = 鼠标 + Preview.TopLeftScreenOffset          :154-164
  ├─ 每帧：重算 footprint（每格 Valid / Invalid）                :249-304
  │    isCloseEnoughToBase && IsCellBuildable  ← 注意是 &&  顺序：:298-300
  │
  ├─ 左键 Down ──► InnerOrder()                                  :166-225
  │     ① world.CanPlaceBuilding(topLeft, ...) 失败 → ClearBlockersOrders + CannotPlace 音 + 不产 Order  :195-205
  │     ② buildingInfo.IsCloseEnoughToBase(...) 失败 → 同上                              :196
  │     ③ 都通过 → yield Order("PlaceBuilding", owner.PlayerActor, Target.FromCell(topLeft), ...)
  │                TargetString=actorName, ExtraData=queueActor.ActorID, ExtraLocation=variant :211-223
  │     └ Order() 外层：若返回里有 PlaceBuilding → world.CancelInputMode()  → 回到 NORMAL  :141-146
  │
  ├─ 取消键 Up → world.CancelInputMode() 立刻 + 走一次 InnerOrder（可能为空）  :134-137
  ├─ IOrderGenerator.Tick：队列里已无该项 Done → CancelInputMode()             :227-234
  └─ 切换建筑变体键（ToggleVariantKey）                                       :317-328

落到世界之后（PlaceBuilding.ResolveOrder，AddFrameEndTask 内）           PlaceBuilding.cs:60-237
  ① 二次校验 CanPlaceBuilding + IsCloseEnoughToBase（防作弊/防竞态）        :204-206
  ② CreateActor(LocationInit, OwnerInit, FactionInit, PlaceBuildingInit)   :208-214
  ③ 播放 BuildSounds + 通知 INotifyBuildingPlaced                          :216-224
  ④ queue.EndProduction(item)  ← 这里才真正出队                            :227
  ⑤ RequiresBaseProvider → FindBaseProvider().BeginCooldown()              :231-232
  ⑥ 可建造项数量增加 → 延迟 10 tick 播 NewOptions 通知                      :234-235, 239-255
```

### 4.2 合法性判定顺序（必须先 cheap 后 expensive）

```
1. bi.AllowInvalidPlacement → 直接 true（OpenRA 用它做"红格也允许放"的调试建筑）   BuildingUtils.cs:84-85
2. 全 footprint 每格：world.Map.Contains(t)                                        :87
3. 每格 IsCellBuildable：                                                          :19-80
   3.1 格内 actor 是否存在（可忽略 toIgnore）        → false
   3.2 格内有 BuildingInfluence 建筑（含 bib）        → 除非 ReplacementInfo 匹配，否则 false
   3.3 Map.Ramp[cell] != 0（斜坡不可建）              → false
   3.4 地形类型不在 bi.TerrainTypes 内                → false
4. BuildingInfo.IsCloseEnoughToBase（"基地附近"限制）                              Building.cs:203-247
   4.1 无 RequiresBuildableArea → true
   4.2 BuildAnywhere 作弊 → true
   4.3 MapBuildRadius 开启且 RequiresBaseProvider → 必须在某个 BaseProvider.Range 内
   4.4 扫描 topLeft ± (adjacent + Dimensions) 范围内是否有己方/盟友的 GivesBuildableArea
```

`BuildingInfluence` 是一张 `CellLayer<InfluenceNode>` 链表（每格可叠多个建筑，因为 bib / 多格建筑）（`BuildingInfluence.cs:26-50`），提供 `GetBuildingsAt(cell)` / `AnyBuildingAt(cell)`（`:73-90`）。**注意 `IsCellBuildable` 的注释说明：多格建筑的 bib 与可通行格不在 ActorMap 里，只能靠 BuildingInfluence 查**（`BuildingUtils.cs:235-237`）。

### 4.3 失败反馈（三级）

| 级别 | 表现 | 证据 |
|---|---|---|
| 逐格 | 该格画 `build-invalid` 序列图（红），合法格画 `build-valid`（绿） | `FootprintPlaceBuildingPreview.cs:70-86, 90-107` |
| 整体 | 幽灵本体半透明（`PreviewAlpha`），footprint 叠在实体上下层 | `ActorPreviewPlaceBuildingPreview.cs:76-101` |
| 点击 | 播 `CannotPlaceAudio`（可被队列覆盖）+ 文字通知；**不产生 Order** | `PlaceBuildingOrderGenerator.cs:174, 198-204` |

另外：点击失败时还会 `ClearBlockersOrders`——**主动命令挡路单位让开**（`:198-199`、`AIUtils.ClearBlockersOrders`）。本项目若是"不能站人的格子直接不可建"就没这个必要，但值得知道 OpenRA 选择了"让路"。

### 4.4 落地后是否自动选中新建筑

**OpenRA：不自动选中。** 证据：全库 `Selection.Combine` / `Selection.Add` 的调用点只有 3 处，均在 `WorldInteractionControllerWidget.cs:142,160`、`ControlGroups.cs:45,72`、`Transform.cs:157`（变形后重新选中）；`PlaceBuilding.cs` 全文无 Selection 调用。并且 Classic 鼠标风格在**进入**放置模式时反而会 `world.Selection.Clear()`（`PlaceBuildingOrderGenerator.cs:104-105`）。

**本项目建议**：落地后 `select(newBuilding)` + 右侧面板切到该建筑的页签。理由：本作建筑数量少、以"连续布防"为主，自动选中能直接看到该建筑的升级/血量；与 OpenRA 的"一次性大批量建造"场景不同。

---

## 五、侧栏 / 右栏联动

### 5.1 chrome 结构（OpenHV 实测）

```
Container@SIDEBAR_PRODUCTION            ingame-player.yaml:466-471
  Logic: ClassicProductionLogic         :467
  Children:
    Container@PALETTE_BACKGROUND          :473  （动态行背景，按图标行数生成）
    LogicTicker@PRODUCTION_TICKER         :491
    ProductionPalette@PRODUCTION_PALETTE  :492-507
      ReadyText / HoldText / IconSize 63,47 / IconMargin 1,4
      MinimumRows 5 / HotkeyPrefix Production / HotkeyCount 24
    Container@PRODUCTION_TYPES            :508-513
      ProductionTypeButton@BUILDING       :514-527  ProductionGroup: Building
      ProductionTypeButton@DEFENSE        :528-542  ProductionGroup: Defense
      ProductionTypeButton@POD            :543-557  ProductionGroup: Pod
      ProductionTypeButton@UTILITY        :558-572  ProductionGroup: Utility
      ProductionTypeButton@TANK           :573-587  ProductionGroup: Tank
      ProductionTypeButton@AIRCRAFT       :588-602  ProductionGroup: Aircraft
      ProductionTypeButton@SHIP           :603-617  ProductionGroup: Ship
      ProductionTypeButton@TRADE          :618-632  ProductionGroup: Trade
```

右栏其它块（同文件）：`Container@RADAR`（`:402-419`）、`Label@GAME_TIMER`（`:420-427`）、`LabelWithTooltip@CASH`（`:428-443`）、`LabelWithTooltip@POWER`（`:444-460`）、`Container@SUPPORT_POWERS`（`:17-30`，独立 bin）。

**注意 widget 的 ID 与 `ProductionGroup` 不同名**（如 `@SHIP` 对应 `ProductionGroup: Ship`），而队列侧 `player.yaml:162-166` 是 `Type: Ship`——匹配键是 **`Group ?? Type`**，见下。

### 5.2 「建筑 → 页签」的绑定机制（三层）

**第一层：YAML 数据 → 队列**
`ClassicProductionQueue@{Building|Defense|Pod|Utility|Tank|Aircraft|Ship|Trade}`，全部配 `Type:`，OpenHV **没有配 `Group:`**（grep `mods/hv/rules/*.yaml` 的 `Group:` 结果为空）→ 因此 `Group ?? Type` 退化为 `Type`。

**第二层：页签按钮 ↔ 队列集合**（`ClassicProductionLogic.SetupProductionGroupButton`，`:24-55`）

```csharp
var queues = world.LocalPlayer.PlayerActor.TraitsImplementing<ProductionQueue>()
    .Where(q => (q.Info.Group ?? q.Info.Type) == button.ProductionGroup).ToArray();   // :30-32

void SelectTab(bool reverse) {
    palette.CurrentQueue = queues.FirstOrDefault(q => q.Enabled);   // :36
    palette.ScrollToTop();                                          // :39
    palette.PickUpCompletedBuilding();                              // :42  ← 顺手拾起已完成建筑进放置模式
}
button.IsDisabled = () => !queues.Any(q => q.AnyItemsToBuild());     // :45
button.IsHighlighted = () => queues.Contains(palette.CurrentQueue);  // :49
// 图标三态：disabled / alert（有 Done 项）/ normal                          :51-54
```

**第三层：选择 → 队列**（`ProductionQueueFromSelection.SelectionChanged`，`:43-73`）

```csharp
// ① queue-per-actor：选中的己方 actor 自己身上的 ProductionQueue
var queue = world.Selection.Actors
    .Where(a => a.IsInWorld && a.World.LocalPlayer == a.Owner)
    .SelectMany(a => a.TraitsImplementing<ProductionQueue>())
    .FirstOrDefault(q => q.Enabled);                       // :50-53

// ② queue-per-player：选中建筑的 Produces 类型 → 去玩家身上找同类型队列
if (queue == null) {
    var types = world.Selection.Actors.Where(己方)
        .SelectMany(a => a.TraitsImplementing<Production>())
        .SelectMany(t => t.Info.Produces);                 // :58-60
    queue = world.LocalPlayer.PlayerActor.TraitsImplementing<ProductionQueue>()
        .FirstOrDefault(q => q.Enabled && types.Contains(q.Info.Type));  // :62-63
}

if (queue == null || !queue.AnyItemsToBuild())
    return;                                                // :66-67  ← 注意：return，不是置空
tabsWidget.CurrentQueue = queue;                            // :70
```

**这一层就是"点不同建筑切不同页签"的全部真相**：不是按建筑 ID 映射，而是**按建筑的 `Production.Produces` 类型集合反查对应的共享队列**。所以"兵营 → Infantry 页签"、"车厂 → Vehicle 页签"是数据驱动的，加建筑只要加 `Produces:`。

### 5.3 「默认不显示」的准确规则

| 时机 | 表现 | 证据 |
|---|---|---|
| 开局（无生产建筑） | 所有队列 `Enabled=false` → `AnyItemsToBuild()=false` → 所有页签按钮 `IsDisabled`，`ClassicProductionLogic` 的 ticker 挑不到按钮，`CurrentQueue` 保持 null → **palette 不绘制任何图标** | `ClassicProductionQueue.cs:52-73`、`ClassicProductionLogic.cs:128-143`、`ProductionPaletteWidget.cs:551-552` |
| 造出第一个生产建筑 | 队列 `Enabled=true`（tick 时扫描到 `Production` trait）→ 按钮可用 → ticker 自动点第一个可用页签 | `ClassicProductionLogic.cs:128-143` |
| 选中生产建筑 | `ProductionQueueFromSelection` 把该队列塞进 palette | `:66-73` |
| **取消选择** | **页签保留**（`return` 而非清空） | `ProductionQueueFromSelection.cs:66-67` |
| 生产建筑被摧毁 | `ProductionPaletteWidget.Tick` 发现 `CurrentQueue.Actor` 不在世界 → `CurrentQueue = null` | `:239-240` |

### 5.4 图标点击语义（一套按钮三套操作）

```csharp
// ProductionPaletteWidget.cs:428-443
startCount  = Shift ? 5 : 1;
cancelCount = Ctrl  ? 队列总长度 : startCount;
左键 HandleLeftClick :319-365
    Done + BuildingInfo → 进放置模式                       :321-325
    Paused              → 恢复生产                         :327-336
    否则                → StartProduction(count, queued = !Ctrl)   :358-359
                          （Ctrl = 插队，普通 = 排到队尾）        :636-639
右键 HandleRightClick:367-410
    DisallowPaused / item.Paused / item.Done / 未开始 → CancelProduction(count)
    否则                                              → PauseProduction(true)
中键 HandleMiddleClick:412-426 → 无条件 CancelProduction(count)
```

### 5.5 数据来源小结（每个 UI 元素读什么）

| UI 元素 | 数据源 | 证据 |
|---|---|---|
| 页签按钮可用/高亮 | `queue.AnyItemsToBuild()` / `palette.CurrentQueue` | `ClassicProductionLogic.cs:45,49` |
| 图标列表 | `CurrentQueue.AllItems()` 按 `BuildableInfo.BuildPaletteOrder` 排序 | `ProductionPaletteWidget.cs:224-233` |
| 图标变暗 | `!CurrentQueue.BuildableItems().Any(name)` | `:577-578` |
| 时钟指针 | `(TotalTime - RemainingTime) / TotalTime` 映射到 `clock` 动画帧 | `:570-575` |
| READY / HOLD / 剩余时间 / 队列数 | `icon.Queued[0]` 的 `Done/Paused/RemainingTimeActual/Infinite` | `:584-630` |
| 剩余时间（低电修正） | `ProductionItem.RemainingTimeActual`（`LowPowerModifier`） | `ProductionQueue.cs:728-730` |
| 建筑头顶进度条 | 队列中 `Started` 项的最小 `RemainingTime` | `ProductionBar.cs:74-99` |

---

## 六、小地图

### 6.1 一张纹理，四层数据

```csharp
// RadarWidget.cs:109-111
radarSheet = new Sheet(BGRA, Size(2*previewWidth, 2*previewHeight).NextPowerOf2());
// :113-115  先整张填 ColorShroud（不透明黑），再"揭示"可玩格
// :231-233  从同一张 sheet 切 4 个 Sprite：
terrainSprite = new Sprite(radarSheet, b, ...);                       // 地形层（静态，只在地形/视野变化时更新）
shroudSprite  = new Sprite(radarSheet, b + (previewWidth, 0), ...);   // 迷雾层
actorSprite   = new Sprite(radarSheet, b + (0, previewHeight), ...);  // 单位层（每 tick 全清重画）
```

绘制顺序：`terrain → actor → shroud → 视口框 → pings`（`Draw()`，`:370-397`）。**先画单位再画迷雾**，所以迷雾会正确盖住敌单位。

### 6.2 各层的更新策略（性能关键）

| 层 | 更新时机 | 证据 |
|---|---|---|
| 地形 | 一次性 + `PlayerRadarTerrain.CellTerrainColorChanged` / `Map.Tiles.CellEntryChanged` / 各 `IRadarTerrainLayer.CellEntryChanged` 事件 | `:236-262`、`PlayerRadarTerrain.cs:59-83` |
| 迷雾 | `Shroud.OnShroudChanged` → `UpdateShroudCell`，按 `Explored/Visible` 写 `ColorShroud`(黑) 或 `ColorFog`(50% 黑) | `RadarWidget.cs:27-28, 264-296` |
| 单位 | **每 tick** 清空整块 actor 层，然后遍历 `world.ActorsWithTrait<IRadarSignature>()`，跳过 `world.FogObscures(actor)` | `:413-468` |
| 视口框 | 每帧 Draw 时算 | `:386-396` |

单位点的取色：`AppearsOnRadar.PopulateRadarSignatureCells` 用 `self.OwnerColor()`，可选 `IRadarColorModifier` 覆盖；`UseLocation=false` 时按 `OccupiesSpace.OccupiedCells()` 逐格画（多格单位更"胖"）（`AppearsOnRadar.cs:43-66`）。

### 6.3 交互：左键跳转 / 右键下令

```csharp
// RadarWidget.cs:326-368
if (!mapRect.Contains(mi.Location)) return false;

var worldCoords = MinimapPixelToWorldCoords(mi.Location);

// ① 非"动作键"的 Down，或按住某键拖动 → 视口居中并持续跟随
if ((mi.Event == Down && mi.Button != world.OrderGenerator.ActionButton) ||
    (mi.Event == Move && isMinimapMoving && mi.Button == minimapMoveButton))
{
    worldRenderer.Viewport.Center(worldCoords);
    isMinimapMoving = true; minimapMoveButton = mi.Button;
}
// ② 动作键（默认左键）的 Down → 伪造一对 Down/Up 转交给世界交互控件
else if (mi.Event == Down && WorldInteractionController != null)
{
    var fakemi = new MouseInput { Event = Down, Button = mi.Button, Modifiers = mi.Modifiers,
                                  Location = worldRenderer.Viewport.WorldToViewPx(...) };
    var controller = Ui.Root.Get<WorldInteractionControllerWidget>(WorldInteractionController);
    controller.HandleMouseInput(fakemi);
    fakemi.Event = Up;
    controller.HandleMouseInput(fakemi);
}
// ③ 松开结束拖动
else if (mi.Event == Up && mi.Button == minimapMoveButton) { isMinimapMoving = false; }
```

**核心设计：右键在小地图上不是"特殊命令"，而是把点击坐标换算回世界屏幕坐标后，伪造一次完整的鼠标点击丢给世界交互控件**（`:342-360`）。于是"小地图右键 = 给选中单位下达移动命令"零成本实现，且**自动继承放置模式、集结点模式等所有当前输入模式**。

坐标系换算（矩形地图）：

```csharp
// CellToMinimapPixel   :495-506
dx = previewScale * cellWidth * (uv.U - Bounds.Left);  dy = previewScale * (uv.V - Bounds.Top);
// MinimapPixelToWorldCoords :508-523
u = (pixel.X - mapRect.X) / (previewScale * cellWidth) + Bounds.Left;
v = (pixel.Y - mapRect.Y) / previewScale + Bounds.Top;
return new Vector2(1024 * u + 512, 1024 * v + 512);   // 矩形格 1024x1024 中心偏移 512
```

### 6.4 雷达开关

`IngameRadarDisplayLogic` 用 `LogicTicker` 每 tick 判断 `world.ActorsHavingTrait<ProvidesRadar>(...)` 是否存在己方实例（或 `DeveloperMode.DisableShroud`），写入 `radar.IsEnabled`（`:23-41`）。`RadarWidget.Tick` 里做 5 帧的展开/收起动画，动画期间用 `ColorBlock` 盖黑（`:470-492` + `IngameRadarDisplayLogic.cs:43-49`）。

---

## 七、给 Godot 的落地映射表

> 约定：左列为 OpenRA 概念（含证据），右列为本项目 `res://` 落点。**标 ⚠️ 的是需要新写的模块**，标 ♻️ 的是可以改造现有脚本。

### 7.1 模块级

| OpenRA 概念 | 证据 | 本项目 Godot 落点 | 备注 |
|---|---|---|---|
| `ProductionQueue` + `ClassicProductionQueue` | `ProductionQueue.cs:136-710`、`ClassicProductionQueue.cs:38-161` | ⚠️ **新增** `res://scripts/autoload/production_service.gd`（Autoload，排在 `GameState` 之后） | 全局单例，因为本作是"玩家一份队列"，天然对应 `ClassicProductionQueue`（per-player）而非 per-actor |
| `Production` trait | `Production.cs:33-149` | ♻️ `res://scripts/build_system.gd` 扩 `get_exit_cells(kind)` / `get_spawn_point(kind)` | 建筑只提供出口点，不持有队列 |
| `Exit` trait | `Exit.cs:21-46` | ⚠️ 建筑数据加 `exit_cell: Vector2i`、`exit_priority: int`（放 `res://data/buildings.json`） | 三路驿道 = 3 个 `exit_cell` 或 1 个按 lane 匹配 |
| `RallyPoint` | `RallyPoint.cs:62-198` | ♻️ `GameState` 加 `rally_point: Vector2` + `res://scripts/main.gd` 右键设点 | 现在敌人直接走 `Path2D`，我方单位可用 `PathFollow2D` |
| `PrimaryBuilding` | `PrimaryBuilding.cs:85-124` | ⚠️ `BuildSystem` 加 `primary_of: Dictionary[StringName, Node2D]` | 多座军械坊时决定由谁出兵 |
| `ProductionBar` | `ProductionBar.cs:74-99` | ♻️ `hud.gd` 顶部波次区旁边加"当前建造"进度条 | 也可画在建筑头顶 |
| `Selection` | `Selection.cs:24-197` | ⚠️ **新增** `res://scripts/select_system.gd`（Node，挂到 main 下或 Autoload） | 见 7.2 |
| `INotifySelection` 广播 | `Selection.cs:125-127` | ⚠️ `EventBus` 加 `signal selection_changed(actors: Array[Node])` | 现有 `EventBus` 只有 9 个信号，加这一个即可 |
| `IOrderGenerator`（输入模式） | `World.cs:156-172` | ⚠️ **新增** `res://scripts/input_mode.gd`（enum + 栈） | ⚠️ 这是本项目当前**最缺**的一层：`main.gd:_unhandled_input` 现在把所有左键都当建造（`main.gd:220-222`），无模式隔离 |
| `PlaceBuildingOrderGenerator` | `PlaceBuildingOrderGenerator.cs:41-336` | ♻️ `res://scripts/build_preview.gd`（已有逐格着色，补"点击前校验"） | 现 `build_preview.gd:38` 用 `can_place`，缺"每次点击再判一次"（`main.gd:_try_build_at` 已调 `place`，OK） |
| `BuildingInfluence` | `BuildingInfluence.cs:24-91` | ♻️ `build_system.gd` 的 `occupied: Dictionary`（`"c,r" -> kind`） | 语义等价；⚠️ 加 `bib`（多格建筑的"不可通行但不占 actor"格） |
| `BuildingUtils.IsCellBuildable` | `BuildingUtils.cs:19-80` | ♻️ `build_system.gd:is_buildable_cell` | ⚠️ 需补"斜坡/地形类型"（现只判 `blocked`） |
| `BuildingInfo.IsCloseEnoughToBase` | `Building.cs:203-247` | ⚠️ **新增** `build_system.gd:in_build_radius(cell)` + `GivesBuildableArea` 列表 | 本作塔防多半限制"塔只能建在道路旁"，正好用这个 |
| `PlaceBuilding.ResolveOrder` | `PlaceBuilding.cs:60-237` | ♻️ `build_system.gd:place()`（`56-81`） | ⚠️ 把"扣钱"从 `place` 里移到"进入建造队列"（见 7.3） |
| `RadarWidget` | `RadarWidget.cs:25-541` | ♻️ `res://scripts/minimap.gd` | 见 7.4 |
| `PlayerRadarTerrain` | `PlayerRadarTerrain.cs:28-96` | ♻️ `minimap.gd:_build_base_image()`（一次性生成底图） | 已有缓存底图，等价 |
| `IngameRadarDisplayLogic` | `IngameRadarDisplayLogic.cs:23-51` | ⚠️ `minimap.gd` 加 `set_radar_online(bool)`（本作可不做，先常开） | — |
| `ClassicProductionLogic` | `ClassicProductionLogic.cs:19-185` | ⚠️ **新增** `res://scripts/ui/sidebar.gd` | 见 7.5 |
| `ProductionPaletteWidget` | `ProductionPaletteWidget.cs:42-650` | ⚠️ **新增** `res://scripts/ui/production_palette.gd`（`GridContainer` + `TextureButton`） | — |
| `ProductionTabsWidget` | `ProductionTabsWidget.cs:67-370` | ⚠️ **新增** `res://scripts/ui/production_tabs.gd`（`HBoxContainer` 手动布局） | — |
| `ActorSpawnManager` | `ActorSpawnManager.cs:63-149` | ♻️ `res://scripts/spawn_system.gd`（已高度相似） | 只需补 `initial_delay` 与"刷新点随机化" |

### 7.2 选择系统（新写，约 120 行）

```gdscript
# res://scripts/select_system.gd  —— 对齐 OpenRA Selection + SelectionUtils + SelectableExts
extends Node
class_name SelectSystem

signal selection_changed(actors: Array[Node])

const DEADZONE: float = 6.0          # 对齐 SelectionDeadzone（WorldInteractionControllerWidget.cs:38）

var selected: Array[Node2D] = []
var rollover: Array[Node2D] = []

func select_at(world_pos: Vector2, additive: bool) -> void: ...
func select_in_rect(a: Vector2, b: Vector2, additive: bool) -> void: ...
func select_by_class(cls: StringName, additive: bool = true) -> void: ...   # 双击同类
func clear() -> void: ...

# 对齐 SelectableExts.cs:73-88：优先级主序，像素距离次序
func _priority_key(n: Node2D, mouse: Vector2) -> int:
    var base: int = n.get("select_priority")        # 塔 20 / 单位 10 / 建筑 5
    var d: int = int(n.global_position.distance_to(mouse))
    return base - (d << 16)
```

要点（全部来自证据）：
- **点选**：deadzone 内取 `_priority_key` 最大的单个（`SelectionUtils.cs:61-68`）。
- **框选**：先按 `select_priority` 分组，取最高一组的全部（`SelectableExts.cs:92-99`）——**框选不混选塔和兵**。
- **Shift+点选 = 反选（`SymmetricExceptWith`）**，不是加选（`Selection.cs:100-101`）。这条容易做错。
- 每次变更后 `EventBus.selection_changed.emit(selected)`；HUD 只监听，不轮询。
- 每帧清理"已 `queue_free` 或死亡"的项（`Selection.cs:167-177`）。

### 7.3 出兵系统改造（♻️ `spawn_system.gd`）

现状：`main.gd:266-283 spawn_player_unit()` 是**点了就扣钱、立刻 `load().instantiate()`**，没有队列、没有进度、没有出口。

建议按 OpenRA 四段式重构：

```gdscript
# res://scripts/autoload/production_service.gd
extends Node

signal item_queued(type_id: StringName)
signal item_progress(type_id: StringName, ratio: float)   # 0..1，供 HUD 画时钟
signal item_ready(type_id: StringName)                    # Done，等待出场（单位则立刻出场）
signal item_cancelled(type_id: StringName, refunded: int)

class Item:
    var type_id: StringName
    var total_time: float
    var remaining_time: float
    var total_cost: int
    var remaining_cost: int
    var paid: int
    var done: bool = false
    var paused: bool = false

var queue: Array[Item] = []

func start(type_id: StringName, count: int = 1, queued: bool = true) -> bool:
    # 校验 → 建 Item → 按 hasPriority 插入 queue[1] 或 append（ProductionQueue.cs:636-639）
    ...

func _process(delta: float) -> void:
    if queue.is_empty(): return
    var it := queue[0]                       # 只推进队首（ProductionQueue.cs:366）
    if it.paused or it.done: 
        if it.done: _complete(it)
        return
    # 按进度扣款（ProductionQueue.cs:787-802）
    var expected := int(it.total_cost * it.remaining_time / it.total_time)
    var this_frame := it.remaining_cost - expected
    var paid_now := mini(this_frame, GameState.silver)
    GameState.add_silver(-paid_now)
    it.paid += paid_now
    it.remaining_cost -= paid_now
    it.remaining_time -= delta
    item_progress.emit(it.type_id, 1.0 - it.remaining_time / it.total_time)
    if it.remaining_time <= 0.0:
        it.done = true

func cancel(type_id: StringName) -> void:
    # 退款 = paid + (total_cost - remaining_cost)（ProductionQueue.cs:596-603）
    ...
```

出场部分照抄 `Production.DoProduction`（`Production.cs:51-103`）：

```gdscript
func _spawn_from_exit(it: Item) -> void:
    var exits := build_system.get_exits(it.type_id)      # 按 exit_priority 降序
    for e in exits:
        if not build_system.exit_is_free(e): continue     # 对齐 CanUseExit
        var unit := unit_scene.instantiate()
        unit.global_position = e.spawn_pos                # CenterPosition + SpawnOffset
        unit.rotation = (e.exit_world - e.spawn_pos).angle()  # 对齐 delta.Yaw
        unit.rally_point = GameState.rally_point          # 对齐 RallyPointInit
        units_layer.add_child(unit)
        return
    # 全堵 → 保持 Done，下一帧重试（对齐 BlockedAudio 分支）
```

**敌方定时出兵**保持现有 `spawn_system.gd` 的波次模型，只补两点（对齐 `ActorSpawnManager.cs:29-44`）：
- 加 `initial_delay`（现在用 `PREPARE_SEC` 兼任，语义混了）；
- `SpawnInterval` 支持区间随机（现在 `WAVE_INTERVAL` 是常量）。

> ⚠️ 已发现潜在缺陷（仅记录，不改代码）：`main.gd:348` 调 `spawn_system.tick(delta)` 未传 `alive_enemies`，而 `spawn_system.gd:85` 的签名是 `tick(delta, alive_enemies := 0)`，导致 `MAX_ALIVE` 上限（`spawn_system.gd:166`）永远不会触发。

### 7.4 小地图改造（♻️ `minimap.gd`）

现有实现已覆盖"底图 + 单位点 + 视口框 + 点击跳转"（`minimap.gd:65-113`），对齐 OpenRA 需补 3 项：

| 缺口 | OpenRA 对应 | 补法 |
|---|---|---|
| 右键/左键都"跳转"（`minimap.gd:100-109` 两键同效） | 左键跳转、右键转交世界（`RadarWidget.cs:326-360`） | 右键改为"换算世界坐标 → `select_system`/`build_system` 走一次点击"，从而支持小地图右键下令 |
| 无迷雾层 | `RadarWidget.cs:264-296` | 加一张同尺寸 `Image` 作迷雾层，`draw_texture_rect` 叠加 |
| 每帧遍历所有单位 child（`minimap.gd:71-79`） | 每 tick 全清 actor 层后按 `IRadarSignature` 重画（`:413-468`） | 本作单位数 <200，现有做法可接受；⚠️ 加 `if not u.is_inside_tree()` 保护 |

坐标系：现用 `world_pos / world_size * size`（`minimap.gd:91-98`）——对正交网格正确，**不需要** OpenRA 那套等距投影换算（`RadarWidget.cs:495-523`）。

### 7.5 侧栏 / 右栏重做（⚠️ 新写）

现在 `hud.gd:186-234` 是"底部一条 122px 高的建造+出兵按钮栏"，与 OpenRA 的"右侧竖栏 + 页签 + 图标网格"是两种范式。建议：

```
UI (CanvasLayer, res://scripts/hud.gd)
├── TopBar                  ♻️ 保留（hud.gd:67-139）
├── MiniMap                 ♻️ 保留位置（右上，main.gd:184-197）
└── SidebarRoot  ⚠️ 新增，右侧竖栏
    ├── ProductionTabs      ⚠️ 页签条（对齐 ProductionTabsWidget）
    │     └─ 每个 Button.metadata = { group: StringName }
    ├── ProductionPalette   ⚠️ GridContainer(columns=3)
    │     └─ 每格 TextureButton：底部时钟扇/READY/HOLD/数量
    └── SelectionPanel      ⚠️ 选中建筑/单位时显示（血量、升级、出售）
```

绑定规则（照抄 `ClassicProductionLogic` + `ProductionQueueFromSelection`）：

```gdscript
# 页签按钮 ↔ 队列组
func _setup_tab_button(btn: Button, group_id: StringName) -> void:
    btn.set_meta(&"group", group_id)
    btn.disabled = not production_service.any_buildable(group_id)     # :45
    btn.pressed.connect(func(): production_service.current_group = group_id)  # :36

# 选择 → 页签（:43-73）
func _on_selection_changed(actors: Array[Node]) -> void:
    var groups: Array[StringName] = []
    for a in actors:
        if a.owner_player != &"player": continue
        groups.append_array(a.get("produces") as Array[StringName])
    if groups.is_empty(): return          # ← 注意：不清空（ProductionQueueFromSelection.cs:66-67）
    tabs.highlight(groups[0])
```

**默认隐藏规则**（严格按 §5.3）：
- `SidebarRoot.production_visible = production_service.has_enabled_queue()`；
- 无生产建筑时页签全灰、palette 空；
- 首次出现生产建筑时，`_process` 里自动选中第一个可用页签（对齐 `ClassicProductionLogic.cs:128-143`）。

### 7.6 建造链路改造（♻️ `build_system.gd` + `build_preview.gd`）

1. **扣款时机搬到队列**：`build_system.gd:61` 现在在 `place()` 里 `add_silver(-cost)`。改成"入队时按 `PayUpFront` 扣全款 → 完成 → 放置"（`ProductionQueue.cs:623-632`），失败时 `build_failed` 全额退。
2. **补 `why_not(cell, kind) -> StringName`**：把 `_reject_reason`（`build_system.gd:93-101`）拆成可枚举的失败码（`out_of_bounds` / `blocked_tile` / `occupied` / `no_silver` / `out_of_radius`），供 `build_preview.gd` 分色 + HUD 提示文案。
3. **加基地半径**：`is_buildable_cell`（`build_system.gd:25-34`）末尾加 `in_build_radius(cell)`（对齐 `Building.cs:203-247`）。
4. **输入模式隔离**（最重要）：`main.gd:220-222` 现在"任何左键 = 建造"。改为：
   ```gdscript
   enum Mode { NORMAL, PLACING }
   var mode: Mode = Mode.NORMAL
   # 进 PLACING 时 select_system.clear()（对齐 PlaceBuildingOrderGenerator.cs:104-105）
   # 落地/右键/Esc → mode = NORMAL（对齐 World.cs:172 CancelInputMode）
   ```
   否则"选中单位后左键点地面"会同时触发建造和选择。

---

## 八、引用文件清单

**OpenRA（引擎）**

| 路径（相对 `/home/xingwangzhe/桌面/OpenRA`） | 关键行 |
|---|---|
| `OpenRA.Mods.Common/Traits/Player/ProductionQueue.cs` | 21-56, 136-203, 226-247, 278-341, 343-367, 369-445, 447-539, 541-568, 570-663, 682-709, 712-813 |
| `OpenRA.Mods.Common/Traits/Player/ClassicProductionQueue.cs` | 21-36, 52-73, 85-96, 98-138, 140-159 |
| `OpenRA.Mods.Common/Traits/Player/PlayerResources.cs` | 154-166, 215-242 |
| `OpenRA.Mods.Common/Traits/Player/PlaceBuilding.cs` | 20-47, 49-118, 120-225, 227-266 |
| `OpenRA.Mods.Common/Traits/Player/PlayerRadarTerrain.cs` | 19-96 |
| `OpenRA.Mods.Common/Traits/Production.cs` | 21-31, 51-103, 105-116, 118-142, 151-156 |
| `OpenRA.Mods.Common/Traits/ProductionQueueFromSelection.cs` | 20-75 |
| `OpenRA.Mods.Common/Traits/ActorSpawner.cs` | 16-31 |
| `OpenRA.Mods.Common/Traits/World/ActorSpawnManager.cs` | 19-61, 63-149 |
| `OpenRA.Mods.Common/Traits/World/Selection.cs` | 24-197 |
| `OpenRA.Mods.Common/Traits/Buildings/Exit.cs` | 21-46, 48-94 |
| `OpenRA.Mods.Common/Traits/Buildings/RallyPoint.cs` | 21-60, 62-198 |
| `OpenRA.Mods.Common/Traits/Buildings/PrimaryBuilding.cs` | 20-27, 85-133 |
| `OpenRA.Mods.Common/Traits/Buildings/Building.cs` | 34-48, 159-181, 183-201, 203-247, 266-284 |
| `OpenRA.Mods.Common/Traits/Buildings/BuildingInfluence.cs` | 24-91 |
| `OpenRA.Mods.Common/Traits/Buildings/BuildingUtils.cs` | 19-88, 90-137 |
| `OpenRA.Mods.Common/Traits/Buildings/FootprintPlaceBuildingPreview.cs` | 23-44, 58-107, 117-135 |
| `OpenRA.Mods.Common/Traits/Buildings/ActorPreviewPlaceBuildingPreview.cs` | 22-34, 52-102 |
| `OpenRA.Mods.Common/Traits/Render/ProductionBar.cs` | 19-42, 44-104 |
| `OpenRA.Mods.Common/Traits/Radar/AppearsOnRadar.cs` | 17-67 |
| `OpenRA.Mods.Common/Orders/PlaceBuildingOrderGenerator.cs` | 25-39, 41-117, 130-152, 154-164, 166-225, 227-234, 249-304, 306-335 |
| `OpenRA.Mods.Common/Widgets/WorldInteractionControllerWidget.cs` | 23-54, 56-83, 85-183, 185-211, 235-248 |
| `OpenRA.Mods.Common/Widgets/SelectionUtils.cs` | 23-49, 51-59, 61-74, 76-84 |
| `OpenRA.Mods.Common/Widgets/ProductionPaletteWidget.cs` | 28-40, 42-120, 195-233, 235-296, 298-317, 319-365, 367-410, 412-443, 445-481, 489-545, 547-640 |
| `OpenRA.Mods.Common/Widgets/ProductionTabsWidget.cs` | 24-65, 67-123, 138-185, 187-236, 245-273, 275-299, 307-349 |
| `OpenRA.Mods.Common/Widgets/RadarWidget.cs` | 25-93, 105-130, 188-234, 236-262, 264-296, 298-324, 326-368, 370-397, 413-493, 495-523 |
| `OpenRA.Mods.Common/Widgets/Logic/Ingame/ClassicProductionLogic.cs` | 19-55, 57-122, 124-143, 145-162, 167-185 |
| `OpenRA.Mods.Common/Widgets/Logic/Ingame/IngameRadarDisplayLogic.cs` | 20-51 |
| `OpenRA.Game/SelectableExts.cs` | 19-61, 63-99 |
| `OpenRA.Game/World.cs` | 152-172 |
| `OpenRA.Game/Network/Order.cs` | 314-327 |
| `OpenRA.Game/Widgets/WidgetLoader.cs` | 46-82 |

**OpenHV（模组）**

| 路径（相对 `/home/xingwangzhe/桌面/OpenHV`） | 关键行 |
|---|---|
| `mods/hv/chrome/ingame-player.yaml` | 1-30, 402-419, 420-460, 466-513, 514-632 |
| `mods/hv/chrome/ingame.yaml` | 41-42（`WorldInteractionController@INTERACTION_CONTROLLER`） |
| `mods/hv/rules/world.yaml` | 303-304（`ProductionQueueFromSelection`） |
| `mods/hv/rules/player.yaml` | 58-176（8 个 `ClassicProductionQueue`） |

**本项目（`/home/xingwangzhe/桌面/2026游戏赛事/game`，仅阅读，未修改）**

| 路径 | 关键行 |
|---|---|
| `scripts/main.gd` | 45-58, 147-163, 174-203, 208-242, 266-294, 305-358 |
| `scripts/spawn_system.gd` | 17-19, 21-30, 57-70, 84-121, 123-158, 160-183 |
| `scripts/build_system.gd` | 7-18, 20-53, 55-81, 83-101 |
| `scripts/build_preview.gd` | 5-16, 18-51 |
| `scripts/minimap.gd` | 6-33, 35-59, 65-112 |
| `scripts/hud.gd` | 5-30, 67-139, 186-234, 389-408, 411-478 |
| `scripts/autoload/game_state.gd` | 4-25, 27-67, 71-88 |
| `scripts/autoload/event_bus.gd` | 4-13 |
| `project.godot` | autoload 段（`GameState` 必须在 `SupplySystem` 之前） |

---

## 九、待确认 / 风险

1. **OpenHV 的 `ProductionGroup` 与队列 `Type` 完全一一对应**，但 widget ID 与 group 名不同（`@SHIP` vs `Ship`）。本项目若做页签，**匹配键请用 group 名而非节点名**，否则改名即断。
2. **OpenRA 侧栏在取消选择后不清空**（§5.3）。这是"历史行为"而非设计意图（`ProductionQueueFromSelection.cs:66-67` 只 `return`）。本作建议**改成"取消选择 → 保留页签但置灰 palette"**，以免玩家失去建造入口。
3. **`ProductionQueue` 完成回调在 `AddFrameEndTask` 里做，但 `Done` 判定在 tick 里**（`ProductionQueue.cs:497-527` vs `768-773`）。二者跨帧，所以代码里要处理"item 在回调前被取消"的竞态（OpenRA 用 `if (!Queue.Any(i => i.Done && i.Item == unit.Name)) return;` 兜，`:500-504`）。Godot 侧建议**用 `is_instance_valid` + 队列成员检查**做同样兜底。
4. **`Production.BuildUnit` 里"一个生产者都没有就 `CancelProduction`"**（`ClassicProductionQueue.cs:134-135`）——意味着"生产建筑被打掉 → 队列项立即退款消失"，不是"暂停等重建"。本项目若想让玩家"重建建筑后继续造"，需要显式改这条。
5. **小地图右键转发**（`RadarWidget.cs:342-360`）依赖"世界交互控件与雷达共享同一套 MouseInput 语义"。Godot 侧等价做法是**在 `minimap.gd` 里把 `event.position` 换算成世界坐标后调用 `main_ref` 的 `try_command_at(world_pos)`**，比伪造 InputEvent 干净，但要注意 `accept_event()` 防重复消费（`minimap.gd:109` 已有）。
6. 精确查询关键词（Godot 4.x，落地时自行核对）：
   - `Control._gui_input` / `Control.accept_event` / `Control.mouse_filter`
   - `Node2D.get_global_mouse_position` / `Camera2D.get_viewport_rect` / `Camera2D.get_canvas_transform`
   - `TileMapLayer.get_cell_source_id` / `TileMapLayer.local_to_map` / `map_to_local`
   - `Image.fill_rect` / `ImageTexture.create_from_image` / `CanvasItem.draw_texture_rect`
   - `PathFollow2D.progress` / `PathFollow2D.progress_ratio`（本项目注意：`rotates` 而非 `rotation_mode`）
   - `Node.get_tree().paused` / `Node.process_mode`
