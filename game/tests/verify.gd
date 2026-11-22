extends SceneTree
## 独立验证脚本：gda script run res://tests/verify.gd
## 不依赖主场景运行，直接校验 autoload 数据层、补给链与终局判定。

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	call_deferred("_run")

func ck(tag: String, cond: bool) -> void:
	if cond:
		pass_count += 1
		print("[PASS] %s" % tag)
	else:
		fail_count += 1
		push_error("[FAIL] %s" % tag)

func _run() -> void:
	var root_node := root
	var gs := root_node.get_node_or_null("GameState") as Node
	var db := root_node.get_node_or_null("DataDB") as Node
	var supply := root_node.get_node_or_null("SupplySystem") as Node

	ck("autoload/GameState存在", gs != null)
	ck("autoload/DataDB存在", db != null)
	ck("autoload/SupplySystem存在", supply != null)
	if gs == null or db == null or supply == null:
		_done()
		return

	# 1. 初始状态
	gs.reset_level()
	var s: Dictionary = gs.get_debug_snapshot()
	ck("初始/grain=200", int(s.get("grain", -1)) == 200)
	ck("初始/silver=120", int(s.get("silver", -1)) == 120)
	ck("初始/ammo=60", int(s.get("ammo", -1)) == 60)
	ck("初始/wave=0", int(s.get("wave", -1)) == 0)
	ck("数据/60兵种已加载", int(s.get("data_counts", {}).get("units", 0)) == 60)
	ck("数据/4塔已加载", int(s.get("data_counts", {}).get("towers", 0)) == 4)

	# 2. 弹药消耗
	supply.reset()
	var before: int = supply.ammo_stock
	ck("弹药/可开火", supply.can_fire())
	var consumed: bool = supply.consume_ammo(1)
	ck("弹药/消耗成功", consumed)
	ck("弹药/消耗后递减", supply.ammo_stock == before - 1)

	# 3. 断供停火
	supply.ammo_stock = 0
	var halt_seen: bool = false
	# 二次消耗应失败并触发 halt
	ck("断供/ammo=0时不可开火", not supply.can_fire())
	var ok: bool = supply.consume_ammo(1)
	ck("断供/消耗失败", not ok)
	halt_seen = supply.halted
	ck("断供/停火标志置位", halt_seen)
	supply.ammo_stock = 10
	supply.produce(1.0)
	ck("断供/恢复供给", not supply.halted)

	# 4. 终局判定
	gs.reset_level()
	gs.damage_enemy_keep(1000)
	var s2: Dictionary = gs.get_debug_snapshot()
	ck("终局/敌堡归零", int(s2.get("enemy_keep_hp", -1)) == 0)
	ck("终局/phase=VICTORY", str(s2.get("phase", "")) == "VICTORY")
	ck("终局/result=victory", str(s2.get("result", "")) == "victory")

	# 5. 定时出兵系统（Mindustry 式：波间倒计时 + 波内逐个放出）
	var SpawnScript: GDScript = load("res://scripts/spawn_system.gd") as GDScript
	var spawn: Node = SpawnScript.new() as Node
	root_node.add_child(spawn)
	spawn.setup()
	ck("刷新点/数量=3", spawn.get_points().size() == 3)
	ck("刷新点/绑定lane递增", int(spawn.get_points()[2]["lane"]) == 2)
	var spawn_events: Array = []
	spawn.enemy_spawn_requested.connect(func(t, l, hs, sp): spawn_events.append([t, l, hs, sp]))
	# 准备期倒计时：先 tick 1 秒不应开波
	spawn.tick(1.0)
	ck("出兵/准备期未开波", spawn.wave == 0)
	# 准备期结束后自动开第 1 波
	spawn.tick(25.0)
	ck("出兵/准备期到点自动开波", spawn.wave == 1)
	ck("出兵/首波数量=6", int(spawn.get_debug_snapshot().get("queued", 0)) +
		int(spawn.get_debug_snapshot().get("spawned_in_wave", 0)) == 6)
	for i2 in range(120):
		spawn.tick(0.1)
	ck("出兵/波内逐个放出=6", spawn_events.size() == 6)
	ck("出兵/波内放完等下一波", not spawn.is_spawning and spawn.countdown > 0.0)
	var lanes_seen: Array = []
	for e3 in spawn_events:
		if not lanes_seen.has(int(e3[1])):
			lanes_seen.append(int(e3[1]))
	ck("出兵/三门轮转覆盖", lanes_seen.size() == 3)
	# 难度曲线单调递增
	ck("出兵/血量随波递增", spawn.hp_scale_for(5) > spawn.hp_scale_for(1))
	ck("出兵/速度随波递增", spawn.speed_scale_for(5) > spawn.speed_scale_for(1))
	ck("出兵/倒计时文本", spawn.countdown_text().contains(":"))
	spawn.queue_free()

	# 5.5 永昌堡地形（DCSS 32px 具名图块，120×90）
	var TB: GDScript = load("res://scripts/tile_map_builder.gd") as GDScript
	var TC: GDScript = load("res://scripts/tile_catalog.gd") as GDScript
	ck("地图/尺寸120x90", TB.COLS == 120 and TB.ROWS == 90)
	ck("地图/瓦片32px", TB.TILE == 32)
	ck("地图/瓦片尺寸与目录一致", TB.TILE == TC.TILE_SIZE)
	var world: Vector2 = TB.WORLD_SIZE
	ck("地图/世界尺寸随瓦片派生", world == Vector2(TB.COLS * TB.TILE, TB.ROWS * TB.TILE))
	ck("地图/三门驿道", TB.LANE_ROWS.size() == 3)
	var lp: PackedVector2Array = TB.lane_points(0)
	ck("驿道/控制点≥3", lp.size() >= 3)
	var a: Vector2 = lp[0]
	var b: Vector2 = lp[lp.size() - 1]
	# 语义判定，不用像素魔法数：一端必须精确落在登陆点（1 格内），
	# 另一端必须落进主堡占格范围（外扩 2 格），这样改 TILE 后断言仍然成立。
	var spawn_pt: Vector2 = TB.spawn_world(0)
	var ka: Vector2i = TB.keep_anchor(false)
	var ks: Vector2i = TB.keep_size(false)
	var keep_rect := Rect2(
		Vector2(ka - Vector2i(2, 2)) * TB.TILE,
		Vector2(ks + Vector2i(4, 4)) * TB.TILE)
	var near_spawn := func(p: Vector2) -> bool: return p.distance_to(spawn_pt) <= TB.TILE
	var in_keep := func(p: Vector2) -> bool: return keep_rect.has_point(p)
	ck("驿道/两端分别接主堡与登陆点",
		(near_spawn.call(a) and in_keep.call(b)) or (near_spawn.call(b) and in_keep.call(a)))
	ck("驿道/穿门名", str(TB.lane_gate_name(1)) != "")
	var map_parent := Node2D.new()
	root_node.add_child(map_parent)
	var bres: Dictionary = TB.build(map_parent)
	ck("地图/构建产出", not bres.is_empty() and int(bres.get("cols", 0)) == 120)
	var ground_layer: TileMapLayer = bres.get("ground")
	ck("地图/图块集已建立", ground_layer != null and ground_layer.tile_set != null)
	var cat_n: int = (load("res://scripts/tile_catalog.gd") as GDScript).CAT_ORDER.size()
	ck("地图/语义图块源数=%d" % cat_n,
		ground_layer != null and ground_layer.tile_set.get_source_count() == cat_n)
	var blocked: Dictionary = bres.get("blocked", {})
	ck("地图/禁建格非空", blocked.size() > 1500)
	var zmap: Dictionary = bres.get("zone_map", {})
	ck("地图/zone_map 非空", zmap.size() > 5000)
	ck("地图/zone 含城墙", zmap.values().has(&"wall"))
	ck("地图/zone 含护城河或河道", zmap.values().has(&"moat") or zmap.values().has(&"river"))
	ck("地图/zone 含城门", zmap.values().has(&"gate"))
	ck("地图/zone_at 与 zone_map 一致",
		TB.zone_at(Vector2i(60, 45)) == StringName(str(zmap.get(Vector2i(60, 45), &"void"))))
	ck("地图/水域判定", typeof(TB.is_water_cell(Vector2i(60, 45))) == TYPE_BOOL)
	ck("地图/相机脚本可加载", ResourceLoader.exists("res://scripts/camera_rig.gd"))
	ck("地图/小地图脚本可加载", ResourceLoader.exists("res://scripts/ui/minimap_panel.gd"))

	# 6. 建造系统（Mindustry 式多格占格）
	var BuildScript: GDScript = load("res://scripts/build_system.gd") as GDScript
	var build: Node = BuildScript.new() as Node
	root_node.add_child(build)
	build.blocked = blocked
	gs.reset_level()
	# 找一个 3×3 全空的可建锚点（不写死坐标，随地形改动自动适配）
	var legal_cell := Vector2i(-1, -1)
	for rr in range(6, TB.ROWS - 6):
		for cc in range(6, TB.COLS - 6):
			if build.can_place(Vector2i(cc, rr), &"jianta"):
				legal_cell = Vector2i(cc, rr)
				break
		if legal_cell.x >= 0:
			break
	ck("建造/能找到合法格", legal_cell.x >= 0)
	ck("建造/水域不可建", bool(TB.is_water_cell(Vector2i(60, 45))) == false
		or not build.can_place(Vector2i(60, 45), &"jianta"))
	var blocked_cell := Vector2i(0, 0)
	for k in blocked.keys():
		blocked_cell = k
		break
	ck("建造/禁建格不可建", not build.can_place(blocked_cell, &"jianta"))
	var silver_before: int = gs.silver
	var holder := Node2D.new()
	root_node.add_child(holder)
	var tower: Node2D = build.place(legal_cell, &"jianta", holder)
	ck("建造/放置成功", tower != null)
	ck("建造/扣银40", gs.silver == silver_before - 40)
	ck("建造/占格9", build.get_occupied_count() == 9)
	ck("建造/建筑进 buildings 组", tower != null and tower.is_in_group("buildings"))
	ck("建造/重复放置被拒", not build.can_place(legal_cell, &"jianta"))
	build.queue_free()
	holder.queue_free()
	map_parent.queue_free()

	# 7. 音频系统
	var audio: Node = root_node.get_node_or_null("AudioManager") as Node
	ck("音频/AudioManager存在", audio != null)
	if audio != null:
		audio.set_bgm_volume(0.85)
		ck("音频/BGM音量设置", is_equal_approx(audio.get_bgm_volume(), 0.85))
		audio.set_sfx_volume(0.42)
		ck("音频/SFX音量设置", is_equal_approx(audio.get_sfx_volume(), 0.42))
		audio.save_settings()
		audio.set_bgm_volume(0.1)
		audio.load_settings()
		ck("音频/配置持久化回读", is_equal_approx(audio.get_bgm_volume(), 0.85))
		var asnap: Dictionary = audio.get_debug_snapshot()
		ck("音频/SFX池=8", int(asnap.get("sfx_pool", 0)) == 8)
		ck("音频/SFX已加载=9", int(asnap.get("sfx_loaded", 0)) == 9)
		audio.set_bgm_volume(0.55)
		audio.set_sfx_volume(0.80)
		audio.save_settings()  # 恢复默认值并写盘，避免污染真实配置

	# 8. 场景导航与 UI 场景
	var flow: Node = root_node.get_node_or_null("GameFlow") as Node
	ck("导航/GameFlow存在", flow != null)
	ck("导航/主菜单场景存在", ResourceLoader.exists("res://scenes/main_menu.tscn"))
	ck("导航/设置场景存在", ResourceLoader.exists("res://scenes/settings.tscn"))
	ck("导航/滚幕场景存在", ResourceLoader.exists("res://scenes/credits.tscn"))
	ck("导航/侧栏脚本存在", ResourceLoader.exists("res://scripts/ui/sidebar_panel.gd"))
	# 10. 片尾滚幕数据（署名可追溯：每条第三方素材都要有 url 与 license）
	var f := FileAccess.open("res://data/credits.json", FileAccess.READ)
	ck("滚幕/credits.json 存在", f != null)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		ck("滚幕/JSON 可解析", parsed is Dictionary)
		if parsed is Dictionary:
			var cd := parsed as Dictionary
			var sections: Array = cd.get("sections", [])
			ck("滚幕/章节数≥8", sections.size() >= 8)
			var entries := 0
			var with_url := 0
			var bad_license := 0
			for sec in sections:
				for e in (sec as Dictionary).get("entries", []):
					entries += 1
					var ed := e as Dictionary
					if str(ed.get("url", "")) != "":
						with_url += 1
					if str(ed.get("license", "")) == "" and str(ed.get("url", "")) == "":
						bad_license += 1
			ck("滚幕/条目数≥30", entries >= 30)
			ck("滚幕/可点击来源≥20", with_url >= 20)
			ck("滚幕/无既无许可又无链接的条目", bad_license == 0)
			ck("滚幕/许可声明 GPL-3", str(cd.get("license", "")).begins_with("GPL-3"))
	var menu_scene := load("res://scenes/main_menu.tscn") as PackedScene
	ck("UI/主菜单可加载", menu_scene != null)
	var settings_scene := load("res://scenes/settings.tscn") as PackedScene
	ck("UI/设置界面可加载", settings_scene != null)

	# 9. 显示系统（模式/分辨率/持久化/自适应配置）
	var disp: Node = root_node.get_node_or_null("DisplayManager") as Node
	ck("显示/DisplayManager存在", disp != null)
	if disp != null:
		ck("显示/默认窗口化", int(disp.get("display_mode")) == 0)
		disp.set_display_mode(2)
		ck("显示/切全屏", int(disp.get("display_mode")) == 2)
		ck("显示/模式标签", str(disp.mode_label()) == "全屏")
		disp.cycle_mode()
		ck("显示/F11循环到窗口全屏", int(disp.get("display_mode")) == 0)
		disp.set_windowed_resolution(Vector2i(1920, 1080))
		ck("显示/分辨率切换1920x1080", Vector2i(disp.get("windowed_resolution")) == Vector2i(1920, 1080))
		disp.set_windowed_resolution(Vector2i(999, 999))
		ck("显示/非法分辨率被拒", Vector2i(disp.get("windowed_resolution")) == Vector2i(1920, 1080))
		disp.set_display_mode(2)  # 全屏 + 1920x1080 一并持久化
		disp.save_settings()
		disp.set("display_mode", 0)
		disp.set("windowed_resolution", Vector2i(1280, 720))
		disp.load_settings()
		ck("显示/配置持久化回读", int(disp.get("display_mode")) == 2
			and Vector2i(disp.get("windowed_resolution")) == Vector2i(1920, 1080))
		var snap: Dictionary = disp.get_debug_snapshot()
		ck("显示/调试快照", snap.has("mode") and snap.has("window_size"))
		# 恢复默认，避免污染真实运行配置
		disp.set("display_mode", 0)
		disp.set("windowed_resolution", Vector2i(1280, 720))
		disp.save_settings()
	var stretch_mode: String = str(ProjectSettings.get_setting("display/window/stretch/mode", ""))
	var stretch_aspect: String = str(ProjectSettings.get_setting("display/window/stretch/aspect", ""))
	ck("显示/拉伸模式canvas_items", stretch_mode == "canvas_items")
	ck("显示/aspect自适应expand", stretch_aspect == "expand")
	ck("显示/窗口可缩放", bool(ProjectSettings.get_setting("display/window/size/resizable", true)))

	_done()

func _done() -> void:
	print("[SUMMARY] PASS=%d FAIL=%d" % [pass_count, fail_count])
	quit(0 if fail_count == 0 else 1)
