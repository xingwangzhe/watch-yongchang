# UI 规格：右侧栏（SidebarPanel）· 小地图（MinimapPanel）· 片尾滚幕（CreditsRoll）

> 实现文件
> - `game/scripts/ui/sidebar_panel.gd` —— `class_name SidebarPanel extends Control`
> - `game/scripts/ui/minimap_panel.gd` —— `class_name MinimapPanel extends Control`
> - `game/scripts/ui/credits_roll.gd` + `game/scenes/credits.tscn` —— `class_name CreditsRoll extends Control`
>
> 参考：`OpenHV/mods/hv/chrome/ingame-player.yaml`（右栏 245px / 页签列 29px / 图标格 63×47；RADAR 222×222）
> 配色基线：`game/scripts/hud.gd`（面板 `(0.07,0.10,0.11,0.90)`、金 `(0.84,0.71,0.40)`、正文 `(0.88,0.85,0.74)`、次文 `(0.62,0.62,0.54)`）
> 字体：全部显式 `load("res://assets/fonts/LXGWWenKai-Regular.ttf") as Font`，不依赖主题默认字体。

---

## 0. 集成铁律（踩过的坑）

**三块 UI 都必须挂在 `CanvasLayer` 下，不能直接挂在主场景根 `Node2D` 上。**
`main.gd` 的 `CameraRig`（Camera2D）会施加 canvas 变换，直接挂在根节点下的 Control 会被平移出屏幕（实测：Control 的 `get_global_rect()` 正确但画面上完全不可见）。现有 `main.tscn` 的 `$UI` 就是 CanvasLayer，HUD 挂在那里——新 UI 同理。

---

## 1. 与 main.gd 的集成（3 步）

### 第 1 步：替换小地图（把 `minimap.gd` 换成 `minimap_panel.gd`）

`main.gd::_add_minimap()` 里现有 `preload("res://scripts/minimap.gd")`，改成：

```gdscript
func _add_minimap() -> void:
	if map_result.is_empty() or camera_rig == null:
		return
	var mini := preload("res://scripts/ui/minimap_panel.gd").new() as MinimapPanel
	mini.name = "MinimapPanel"
	mini.setup(map_result, units_layer, camera_rig)
	mini.anchor_left = 1.0
	mini.anchor_right = 1.0
	mini.offset_left = -234.0     # 222 + 右留 12
	mini.offset_right = -12.0
	mini.offset_top = 58.0        # 顶部状态栏（58px）下沿
	mini.offset_bottom = 280.0    # 58 + 222
	mini.jump_requested.connect(_on_minimap_jump)
	hud.add_child(mini)

func _on_minimap_jump(world: Vector2, select: bool) -> void:
	# 左键 select=true / 右键 select=false；相机已由面板内部移动，这里只处理选中
	if select:
		pass   # 接入选择系统后在此按 world 半径选中单位/建筑
```

> `map_result` 需含 `zone_map`。`tile_map_builder.build()` 目前的返回值里**没有** `zone_map`（当前只有 `ground/road/structure/decor/cols/rows/tile/world_size/buildings/blocked`）。缺省时面板不崩，底图退化为单色并在左上角提示「zone_map 未提供」。补齐方式见 §2.3。

### 第 2 步：挂侧栏

```gdscript
var sidebar: SidebarPanel

func _add_sidebar() -> void:
	sidebar = preload("res://scripts/ui/sidebar_panel.gd").new() as SidebarPanel
	sidebar.name = "SidebarPanel"
	hud.add_child(sidebar)          # 必须挂 CanvasLayer（hud）
	sidebar.build_requested.connect(_on_sidebar_build)
	sidebar.produce_requested.connect(_on_sidebar_produce)
	sidebar.closed.connect(func() -> void: pass)
	sidebar.visible = false          # 面板自己也会在 _ready 置 false，双保险
```

### 第 3 步：点击地图 / 打开建造菜单时驱动它

```gdscript
func _on_sidebar_build(id: StringName) -> void:
	# 映射到现有 BUILD_TYPES 下标并复用既有放置链路
	selected_build = BUILD_TYPES.find(id)
	if selected_build < 0:
		selected_build = 0
	hud.set_selected_build(selected_build)

func _open_build_menu() -> void:
	sidebar.show_context(&"build", {
		"title": "建造",
		"subtitle": "银 %d" % GameState.silver,
		"tabs": [
			{"id": &"def", "label": "防御"},
			{"id": &"util", "label": "辅助"},
		],
		"items": [
			{"id": &"jianta", "label": "箭塔", "icon": "res://assets/ui/icon_tower.png",
			 "cost": 40, "hotkey": "Q", "enabled": GameState.silver >= 40, "tab": &"def"},
			{"id": &"junxiefang", "label": "军械坊", "icon": "res://assets/ui/icon_armory.png",
			 "cost": 35, "hotkey": "E", "enabled": GameState.silver >= 35, "tab": &"def"},
			{"id": &"fenghuotai", "label": "烽火台", "icon": "res://assets/ui/icon_signal.png",
			 "cost": 30, "hotkey": "-", "enabled": GameState.silver >= 30, "tab": &"util"},
		],
	})

func _open_inspect(title: String, subtitle: String, hp: int, max_hp: int, stats: Array) -> void:
	sidebar.show_context(&"inspect", {
		"title": title, "subtitle": subtitle, "hp": hp, "max_hp": max_hp, "stats": stats,
	})
```

挂在 `_build_hud()` 末尾调用 `_add_sidebar()` 即可（约 2 行）。片尾入口加到主菜单：`GameFlow` 里加 `SCENE_CREDITS = "res://scenes/credits.tscn"` + `goto_credits()`，主菜单按钮调它。

---

## 2. SidebarPanel 规格

### 2.1 尺寸 / 锚点表

| 项 | 值 | 说明 |
|---|---|---|
| `anchor_left/right` | `1.0 / 1.0` | 贴右 |
| `offset_left` | `-257`（= `-(245+12)`） | 常量 `PANEL_W=245`、`MARGIN_RIGHT=12` |
| `offset_right` | `-12` | 距屏右 12 |
| `anchor_top/bottom` | `0.0 / 1.0` | 纵向拉伸 |
| `offset_top` | `300` | 小地图（58–280）下方留 20 起 |
| `offset_bottom` | `-12` | 距屏底 12 |
| `grow_horizontal/vertical` | `BEGIN / BOTH` | 窗口变化时向正确方向生长 |
| `mouse_filter` | `STOP` | 吃掉自身区域内的点击 |
| 页签列宽 | `29` | `TAB_COL_W`，对齐 OpenHV |
| 行高 | `47` | `ROW_H`，对齐 OpenHV 图标格 63×47 |
| 行内图标 | `32×32` | `ICON_SIZE`（245 宽下 63 太挤，取 32，`KEEP_ASPECT_CENTERED`） |
| 触摸热区 | 行 47px 高 ≥ 44px 达标；关闭按钮 26×26（桌面够用，移动端建议放大到 44×44，见 §2.6） |

### 2.2 场景树（全部代码构建）

```
SidebarPanel (Control)                        ← 锚定右侧，见上表
└─ Frame (PanelContainer)                     ← 半透明深色 + 金边 + 圆角 6
   └─ Margin (MarginContainer)                ← 10/10/8/8
      └─ RootVBox (VBoxContainer, sep=6)
         ├─ Header (HBoxContainer, sep=6)
         │  ├─ TitleBox (VBoxContainer, sep=0, EXPAND_FILL)
         │  │  ├─ Title (Label, 19, 金)        ← 上下文名，超长省略号
         │  │  └─ Subtitle (Label, 12, 次文)   ← 空则隐藏
         │  └─ CloseButton (Button, 26×26)     ← icon_close，hover 变金
         ├─ HSeparator (ColorRect, h=1)
         ├─ Body (HBoxContainer, sep=6, 纵向 EXPAND_FILL)
         │  ├─ TabColumn (VBoxContainer, min_w=29, sep=3)   ← 页签由内容驱动
         │  └─ ContentScroll (ScrollContainer, 横滚关/纵滚自动, EXPAND_FILL)
         │     └─ Content (VBoxContainer, sep=4)
         └─ Footer (Label, 11, 次文)           ← "Esc 关闭 · 点击空地收起"（inspect 隐藏）
```

页签按钮：`Button` 29×47，优先用 `tab.icon` 贴图，无图标则用 `label` 首字（13 号）；激活态背景 `C_BTN_SELECTED` + 金边，非激活 `(0.10,0.14,0.15,0.90)` + 灰边。**只有页签数 > 1 时 `TabColumn` 才显示**，单页签时整列隐藏、内容区自动占满宽度。

列表行（`Button` 作为容器，内嵌 `MarginContainer → HBoxContainer`）：

```
Button (min_h=47, 全宽, focus_mode=ALL, disabled=enabled取反)
└─ Margin (4/4/3/3, IGNORE)
   └─ Row (HBoxContainer, sep=8, IGNORE)
      ├─ Icon (TextureRect 32×32, KEEP_ASPECT_CENTERED, disabled 时 alpha 0.45)
      ├─ TextBox (VBoxContainer, EXPAND_FILL, SHRINK_CENTER, sep=2, IGNORE)
      │  ├─ Name (Label 15, 正文/次文)
      │  ├─ ProgressBar (高 5) —— 仅 produce 上下文，progress=0 时隐藏
      │  └─ Sub / Cost (Label 11) —— produce 用 sub 文案，build 用"N 银"
      └─ RightCol (VBoxContainer, SHRINK_CENTER, sep=2, IGNORE)
         ├─ RightLabel (Label 12, 金)  —— produce: "×队列数"；build: "价格"
         └─ KeyLabel (Label 11, 次文)  —— "[Q]"
```

### 2.3 上下文 payload schema

```jsonc
// kind = &"build"
{
  "title": "建造",                       // 可选，缺省 "建造"
  "subtitle": "永昌城防 · 银 120",        // 可选
  "tabs": [ {"id": &"def", "label": "防御", "icon": "res://..."} ],  // 可选
  "items": [
    { "id": &"jianta", "label": "箭塔", "icon": "res://assets/ui/icon_tower.png",
      "cost": 40, "hotkey": "Q", "enabled": true,
      "tab": &"def", "tab_label": "防御",  // 无 tabs 时用 tab 自动生成页签
      "tooltip": "..." }                   // 可选
  ]
}
// 点击行为：build_requested(id)

// kind = &"produce"（某个已选生产建筑）
{
  "title": "军械坊", "subtitle": "生产队列 · 队列 2",
  "building": &"junxiefang",              // ★ 会存入 _context_id，可用 get_context_id() 取
  "items": [
    { "id": &"xiangyong", "label": "乡勇", "icon": "res://...", "cost": 10,
      "progress": 0.62,                    // 0..1，0 时进度条隐藏
      "queued": 2, "hotkey": "1", "sub": "可生产", "tab": &"inf" }
  ]
}
// 点击行为：produce_requested(id)（建筑 id 用 get_context_id() 拿）

// kind = &"inspect"（只读）
{
  "title": "箭塔", "subtitle": "己方建筑 · 已绑定中路驿道",
  "hp": 268, "max_hp": 500,                // max_hp>0 才画血条；≤30% 红、≤60% 金、其余绿
  "stats": [ {"k": "攻击", "v": "12"}, {"k": "射程", "v": "180"} ]
}
```

页签解析优先级：`payload.tabs` → 从 `items[].tab` 去重生成 → 单个默认页签（`建造`/`生产`）。`inspect` 不显示页签列。

### 2.4 信号契约

| 信号 | 参数 | 触发时机 |
|---|---|---|
| `build_requested` | `id: StringName` | `&"build"` 上下文点击某列表行 |
| `produce_requested` | `id: StringName` | `&"produce"` 上下文点击某列表行 |
| `closed` | — | `close()` 让面板从可见变为隐藏时（已在隐藏态再 close 不重复发） |
| `context_changed` | `kind: StringName` | `show_context()` 完成重建后 |

公开方法：

| 方法 | 说明 |
|---|---|
| `show_context(kind: StringName, payload: Dictionary = {}) -> void` | 打开/切换上下文；自动 `visible = true` 并重建 |
| `close() -> void` | 隐藏 + 清空上下文/页签/行引用，可见时发 `closed` |
| `is_open() -> bool` | == `visible` |
| `get_context() -> StringName` | 当前 kind |
| `get_context_id() -> StringName` | produce 的建筑 id / inspect 的对象 id |
| `update_item(id: StringName, fields: Dictionary) -> void` | 局部刷新，**避免重建控件**。fields: `progress`(float) / `queued`(int) / `cost`(int) / `enabled`(bool) |
| `close_on_outside_click: bool`（属性，默认 `true`） | 点面板外空地是否自动关闭 |

### 2.5 交互状态机

```
                  ┌──────────────── HIDDEN（默认，visible=false，_context=&""）────────────────┐
                  │                                                                          │
   show_context(kind, payload)                    close() / 关闭按钮 / Esc / 点面板外空地    │
                  │                                                                          │
                  ▼                                                                          │
              SHOWN(kind)  ── show_context(其它kind) ──▶ SHOWN(其它kind)  ──────────────────┘
                  │  ▲
       点击页签   │  │  重建内容区（仍在 SHOWN）
                  ▼  │
              SHOWN(kind, tab=T)
```

- **默认完全隐藏**：`_ready()` 里 `visible = false`，调用方不调 `show_context()` 就永远不出现。
- **关闭途径 3 条**：① 右上 `CloseButton.pressed` → `close()`；② `_input` 收到 `KEY_ESCAPE`（未 echo）→ `close()` + `get_viewport().set_input_as_handled()`；③ `_input` 收到左键按下且落点在自己矩形外 → `close()`（受 `close_on_outside_click` 控制）。
- **Esc 优先级**：面板 `_input` 比 `_unhandled_input` 早，所以在侧栏打开时按 Esc 只关侧栏，不会同时触发 `main.gd` 的暂停。关掉侧栏后再按 Esc 才走暂停 —— 天然的两级返回。
- **关闭即清空**：`_context`、`_payload`、`_tabs`、`_active_tab`、`Content`/`TabColumn` 子节点、`_row_refs` 全部清空，不留脏引用。
- **页签切换不重建页签列本身**（只重刷 `normal` 样式），只重建 `Content` 子节点。

### 2.6 移动端适配差异

| 项 | PC / 键鼠 | 移动端（触摸） |
|---|---|---|
| 关闭按钮 | 26×26 够用 | 放大到 ≥44×44（改 `close_btn.custom_minimum_size`） |
| 行高 | 47 | 保持 47（≥44 达标）；若字体放大建议 56 |
| 焦点 | `focus_mode = ALL`，手柄/键盘可 `grab_focus()` 后上下切换 | 无需焦点环，`focus_mode = NONE` 省电 |
| 点击反馈 | hover 变金边 + `pressed` 深色底 | 补 `pressed` 底色足够；面板整体建议加 `modulate` 0.92 |
| 位置 | 右栏 245 宽 | 竖屏建议整块改底部抽屉（改 `_apply_layout()` 的锚点为 `PRESET_BOTTOM_WIDE` + `offset_top=-320`），行内图标放大到 40 |

---

## 3. MinimapPanel 规格

### 3.1 尺寸 / 锚点表

| 项 | 值 |
|---|---|
| `custom_minimum_size` | `(222, 222)`（常量 `MAP_SIZE`，对齐 OpenHV RADAR） |
| 常见锚点（由调用方设） | `anchor_left/right = 1.0`、`offset_left = -234`、`offset_right = -12`、`offset_top = 58`、`offset_bottom = 280` |
| `clip_contents` | `true`（缩放 >1 时不溢出） |
| `texture_filter` | `CanvasItem.TEXTURE_FILTER_NEAREST`（底图放大不发虚） |
| `mouse_filter` | `STOP`（吃掉点击，避免穿透到地图放置建筑） |

### 3.2 绘制管线（`_draw()`，自下而上）

1. 背景 `C_BG (0.05,0.07,0.08,0.94)`
2. **离屏底图**：`Image.create(cols, rows, RGBA8)` 逐格 `set_pixel`，颜色由 `zone_map[Vector2i(c,r)]` 查 `ZONE_COLORS`，打包成 `ImageTexture`，用 `draw_texture_rect(..., false)` 拉伸到控件尺寸（nearest）。
   - 只在 `setup()` 时构建一次；`zone_map` 为空则不建，画单色 + 「zone_map 未提供」提示。
   - **不引用任何 `TileMapBuilder.S_*` 常量**，区域语义与瓦片实现解耦。
3. 悬停格高亮（仅 `scale ≥ 2.0` 时画，低缩放下 1 格太小无意义）
4. 建筑：`map_result.buildings` 的 `anchor/size` → `keep_own` 金框 2px、`keep_enemy` 红框 2px、其余（塔）实心 `C_TOWER`
5. 单位：遍历 `units_root` 子节点，读 `is_dead`（跳过）、`is_enemy`（选色），画 2–4px 方块（随缩放自适应的 `dot = clamp(scale*1.1, 2, 4)`）；己方青 `(0.40,0.85,0.90)`、敌方红 `(0.90,0.36,0.30)`
6. 视口白框：`camera.get_screen_center_position()` ± `viewport_size * 0.5 / zoom`，1.5px 白描边
7. 金色外框 2px + 悬停区域 tooltip（`ZONE_LABELS` 中文名，如 `驿道/城内/护城河/城墙/田野/河道/海面/城门`）

`zone_map` 值 → 颜色 / 中文（`ZONE_COLORS` / `ZONE_LABELS`，两张表都在 `minimap_panel.gd` 顶部，改色只改这里）：

| zone | 颜色 | 中文 |
|---|---|---|
| `city` | (0.34,0.40,0.30) | 城内 |
| `moat` | (0.16,0.36,0.46) | 护城河 |
| `river` | (0.14,0.32,0.44) | 河道 |
| `field` | (0.30,0.38,0.20) | 田野 |
| `road` | (0.52,0.44,0.30) | 驿道 |
| `wall` | (0.46,0.44,0.40) | 城墙 |
| `sea` | (0.10,0.24,0.36) | 海面 |
| `gate` | (0.62,0.50,0.24) | 城门 |

### 3.3 交互

| 输入 | 行为 |
|---|---|
| 左键按下 | 若落点在**视口白框内** → 进入「拖视口框」模式（相对平移，关闭相机平滑）；否则 → 相机瞬移 + `jump_requested(world, true)` |
| 左键拖动 | 视口框模式：按位移平移相机；非视口框模式：持续跳到指针（等效擦洗） |
| 左键抬起 | 恢复相机平滑设置 |
| 右键按下 | 只跳转，`jump_requested(world, false)`，不选中 |
| 滚轮上下 | 以鼠标为锚点缩放，乘除 1.25，钳制 `[0.5, 2.0]`。锚点算法：记录鼠标下的世界点 → 改 `_zoom_level` → 反算 `_origin` 使该世界点仍在鼠标下 → 钳制回边 |
| 悬停移动 | 更新 `_hover_cell` / `_hover_zone`，变化时发 `zone_hovered(zone)` 并重绘 tooltip |
| 移出控件 | 清空 hover，`zone_hovered(&"")` |

缩放/平移全部只影响「底图在控件内的摆放」，不改变相机；唯一动相机的是跳转与拖视口框。

### 3.4 信号与方法

| 成员 | 说明 |
|---|---|
| `signal jump_requested(world: Vector2, select: bool)` | 跳转后发；`select=true` 表示左键（应选中该点对象），`false` 表示右键（只跳转） |
| `signal zone_hovered(zone: StringName)` | 悬停区域变化（含清空为 `&""`） |
| `setup(map_result: Dictionary, units_root: Node2D, camera: Camera2D) -> void` | 注入依赖并生成底图；`units_root` 可为 `null` |
| `refresh() -> void` | 手动请求重绘（默认每帧已自动重绘，通常不需要） |
| `get_zoom() -> float` | 当前小地图缩放 |

> `setup()` 后 `_origin_inited = false`，首次 `_draw` 时按当前尺寸居中对齐，所以**先设锚点再 setup 或先 setup 再设锚点都不会错位**。

### 3.5 `zone_map` 数据来源（需 tile_map_builder 配合）

`tile_map_builder.build()` 目前不返回 `zone_map`。两种补法，任选其一（**不要在本 UI 里硬编码瓦片常量**）：

- **A（推荐，改动小）**：`build()` 里构建 `Dictionary`，键 `Vector2i`、值 `StringName`，与现有区域生成逻辑同行写入：
  ```gdscript
  var zone_map: Dictionary = {}
  # 初始全图
  for r in range(ROWS):
      for c in range(COLS):
          zone_map[Vector2i(c, r)] = &"field"
  # 水池 → &"river"
  for r in range(int(WATER_RECT.position.y), int(WATER_RECT.position.y) + int(WATER_RECT.size.y)):
      for c in range(int(WATER_RECT.position.x), int(WATER_RECT.position.x) + int(WATER_RECT.size.x)):
          zone_map[Vector2i(c, r)] = &"river"
  # 驿道 → &"road"（三条 LANE_ROWS 各 ROAD_THICKNESS 行）
  # 建筑地基 → &"city"（keep）/ &"wall"（塔）；外圈 2 格 → &"wall"
  return { ..., "zone_map": zone_map }
  ```
- **B**：在 `main.gd` 里由 `map_result` 的 `blocked` + `buildings` 推导后 `map_result["zone_map"] = ...` 再传给面板。

---

## 4. CreditsRoll 规格（片尾滚幕）

### 4.1 数据 schema（`res://data/credits.json`，由 team-lead 提供）

```jsonc
{
  "license": "GPL-3.0-or-later",          // 可选，顶部小字
  "project": "守望 · 永昌",                // 可选，缺省用固定抬头
  "subtitle": "SHOUWANG · YONGCHANG",     // 可选
  "sections": [
    { "title": "章节名",
      "entries": [
        { "name": "名称", "role": "用途/角色", "author": "作者",
          "license": "许可", "url": "https://...", "note": "备注" }
      ] }
  ]
}
```

- 渲染顺序：抬头（project/subtitle/「片 尾 字 幕」/分隔线）→ `license` 小字 → 各 section → 尾块（分隔线 + 「感 谢 观 看」+ 落款）。
- section 标题：36 号金；entry `name`：22 号正文；`role · author · license` 合并成一行 15 号灰（自动跳过空值）；`note` 13 号暗灰，自动换行。
- **`url` 非空 → `name` 用 `LinkButton`**：20/22 号浅蓝 `(0.58,0.76,0.90)` + 常显下划线，hover 变金，`tooltip_text = url`，`pressed → OS.shell_open(url)`；失败仅 `push_warning` 不中断。web 导出时 Godot 的 `OS.shell_open` 内部走 `window.open`，因此不额外引 `JavaScriptBridge`；桌面直接交给系统浏览器（`OS.shell_open` 在 Godot 4 桌面端可用）。
- 数据缺失/非法：不崩，滚幕里显示红字「片尾数据缺失 / 请确认该文件存在且为合法 JSON」。

### 4.2 布局与性能

```
Credits (Control, FULL_RECT, mouse_filter=STOP)
├─ Background (ColorRect, 全屏, (0.02,0.02,0.02), IGNORE)
├─ RollClip (Control, FULL_RECT 但 offset_bottom=-56, clip_contents=true)
│  └─ RollBox (VBoxContainer, sep=6)          ← ★ 全部 Label 预生成，滚动只改 position.y
├─ FadeTop (TextureRect, 顶部 72px, GradientTexture2D 黑→透明, IGNORE)
├─ FadeBottom (TextureRect, 底部条上方 72px, 反向渐变, IGNORE)
└─ BottomBar (PanelContainer, 底部 56px, PASS)
   └─ Margin → HBox
      ├─ Hint (Label 14, 暗灰, EXPAND_FILL)   ← 操作提示
      └─ BackButton (Button 150×38)           ← "返回主菜单"
```

- **不每帧重建 Label**：约 32 条 entry + 每章标题，全部在 `_ready()` 一次性生成；`_process` 只做 `_scroll -= auto_speed * delta; _box.position.y = _scroll`。
- 内容宽度 `clamp(clip_width - 160, 320, 900)`，居中；窗口 resize 时重排 + 重新测高 + 钳制滚动量。
- 顶/底各 72px 渐变遮罩，文字进出画面有电影感（纯 `GradientTexture2D`，无外部贴图）。
- 底栏 `mouse_filter = PASS`，让滚轮事件穿透到根节点，在底部也能滚。

### 4.3 行为状态机

```
   ┌──────────── AUTO ────────────┐        用户操作（滚轮/拖拽/↑↓/PgUp/PgDn/Home/End）
   │  _scroll -= 28 px/s          │───────────────────────────────────┐
   └──────────────────────────────┘                                   ▼
            ▲                                              ┌──── MANUAL_HOLD ────┐
            │                                              │ _auto_resume_left=2.5│
            │ 2.5s 倒计时结束                               │ 只响应手动输入        │
            └──────────────────────────────────────────────└──────────────────────┘
                                                            │
                        _scroll 触到 _min_scroll（尾部）      ▼
                                                   ┌──── FINISHED ────┐
                                                   │ 停在「感谢观看」   │
                                                   │ 停止自动滚动       │
                                                   └──────────────────┘
```

- **默认自然匀速上滚**：`auto_speed`（`@export_range(10, 90, 1)`，默认 28 px/s；32 条 / 4812px 内容约 2.9 分钟走完）。不循环。
- **自由操控**：滚轮 ±90px/次；按住左键上下拖（`relative.y` 直接加）；`↑/↓` ±64px；`PgUp/PgDn`、`Space` ±(可视高 × 0.8)；`Home` 回开头、`End` 到尾部。滚轮/拖拽都 `accept_event()` 防止穿透到下层。
- **手动后暂停 2.5 秒再继续**（`RESUME_DELAY`）：每次手动输入刷新 `_auto_resume_left = 2.5`，倒计时期间不自动滚；归零后重新自然滚动 —— 关键体验点：玩家可随时回看，又不会永久打断节奏。
- **不反向锁死**：手动滚到中途后，自动滚动会从该处继续往上走（`_finished` 只在触及尾部时置 true）。手动把滚动条拉到底（尾部）即视为看完，不再自动滚。
- **退出**：`Esc` 或「返回主菜单」→ `GameFlow.goto_main_menu()`（取不到 autoload 时退回 `change_scene_to_file("res://scenes/main_menu.tscn")`）。

### 4.4 公开成员

| 成员 | 说明 |
|---|---|
| `@export var auto_speed: float = 28.0` | 自然滚速 px/s |
| `get_scroll_state() -> Dictionary` | `{scroll, min, max, content_height, finished, auto_resume_left}`，调试/断言用 |
| `get_entry_count() -> int` | 已渲染条目数 |
| 常量 | `AUTO_SPEED=28`、`RESUME_DELAY=2.5`、`WHEEL_STEP=90`、`KEY_STEP=64`、`PAGE_STEP_FACTOR=0.8`、`TAIL_ANCHOR=0.70`、`BOTTOM_BAR_H=56`、`FADE_H=72` |

### 4.5 移动端适配差异

| 项 | PC | 移动端 |
|---|---|---|
| 滚动 | 滚轮 / 拖拽 / 键盘全覆盖 | 触摸拖动天然映射到左键拖拽（`InputEventScreenDrag` 在 Godot 4 会合成 `InputEventMouseMotion`），无需额外代码 |
| 链接 | 鼠标 hover 变色 | 无 hover，靠常显下划线 + `tooltip` 视觉暗示；点击热区建议 `LinkButton` 加 `custom_minimum_size.y = 44` |
| 返回按钮 | 150×38 | 放大到 ≥44 高 |
| 自动滚动 | 28 px/s | 建议降到 20–24 px/s（小屏阅读速度更慢），改 `auto_speed` 导出值即可 |

---

## 5. 验证记录

| 项 | 命令 | 结果 |
|---|---|---|
| 脚本解析 | `gda script validate res://scripts/ui/sidebar_panel.gd --project game --json` | `valid=true`，0 diagnostics |
| 脚本解析 | `gda script validate res://scripts/ui/minimap_panel.gd --project game --json` | `valid=true` |
| 脚本解析 | `gda script validate res://scripts/ui/credits_roll.gd --project game --json` | `valid=true` |
| 场景校验 | `gda scene validate res://scenes/credits.tscn --project game --json` | `valid=true`，0 problems |
| 功能冒烟（26 项断言） | 临时 SceneTree 脚本：侧栏 3 上下文 / 信号 / 关闭清空；小地图缩放钳制 / 跳转 / 悬停；滚幕测量 / 手动 / 2.5s 恢复 / 尾部停住 | 26 PASS / 0 FAIL |
| 视觉验收 | `godot --path game <scene> --write-movie out.png --fixed-fps 30 --quit-after N` 逐帧 PNG | 侧栏 3 上下文、小地图、滚幕中段与尾部均渲染正确（见 §0 的 CanvasLayer 坑） |

**已知未验证 / 待接入**

1. `zone_map` 尚未由 `tile_map_builder.build()` 提供 —— 面板对缺失做了降级，但真实地图配色需 builder 补字段（§3.5）。
2. `jump_requested` 的「选中」语义未接选择系统（`main.gd` 里目前没有选中链路），当前只移动相机。
3. 侧栏 `produce` 上下文的队列/进度刷新需 `main.gd` 每帧调 `update_item()`；未接时静态显示传入的初值。
4. 触摸真机未测（当前环境无触摸设备）；触摸拖拽依赖 Godot 的鼠标事件合成，逻辑上等价。
5. `credits.tscn` 未加入 `project.godot` 入口，需 `GameFlow` 加 `goto_credits()` 才能从主菜单进入。
