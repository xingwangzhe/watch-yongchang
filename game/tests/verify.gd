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

	# 5. 刷新点系统（借鉴 RWX attack_point）
	var SpawnScript: GDScript = load("res://scripts/spawn_system.gd") as GDScript
	var spawn: Node = SpawnScript.new() as Node
	root_node.add_child(spawn)
	spawn.setup()
	ck("刷新点/数量=3", spawn.get_points().size() == 3)
	ck("刷新点/绑定lane递增", int(spawn.get_points()[2]["lane"]) == 2)
	spawn.begin_wave(1)
	ck("波次/首波count=6", spawn.wave_count(1) == 6)
	var spawn_events: Array = []
	spawn.enemy_spawn_requested.connect(func(t, l, hs, sp): spawn_events.append([t, l, hs, sp]))
	for i in range(100):
		spawn.tick(0.1)
	ck("波次/刷兵数=6", spawn_events.size() == 6)
	ck("波次/刷兵后结束", spawn.is_wave_finished())
	ck("波次/ lane轮转", int(spawn_events[3][1]) == 0)
	spawn.queue_free()

	# 5.5 Hard Vacuum 大地图（Tiled 标准图块，96×72 @ 40px）
	ck("地图/尺寸96x72", TileMapBuilder.COLS == 96 and TileMapBuilder.ROWS == 72)
	ck("地图/瓦片40px", TileMapBuilder.TILE == 40)
	var world: Vector2 = TileMapBuilder.WORLD_SIZE
	ck("地图/世界3840x2880", world == Vector2(3840, 2880))
	ck("地图/刷新点在右缘", TileMapBuilder.spawn_world(0).x > 3600.0)
	var map_parent := Node2D.new()
	root_node.add_child(map_parent)
	var bres: Dictionary = TileMapBuilder.build(map_parent)
	ck("地图/构建产出", not bres.is_empty() and int(bres.get("cols", 0)) == 96)
	var ground_layer: TileMapLayer = bres.get("ground")
	ck("地图/9个图块源", ground_layer != null and ground_layer.tile_set.get_source_count() == 9)
	ck("地图/禁建格非空", (bres.get("blocked") as Dictionary).size() > 1500)
	ck("地图/相机脚本可加载", ResourceLoader.exists("res://scripts/camera_rig.gd"))
	ck("地图/小地图脚本可加载", ResourceLoader.exists("res://scripts/minimap.gd"))
	map_parent.queue_free()

	# 6. 建造系统（Mindustry/RWX 多格占格）
	var BuildScript: GDScript = load("res://scripts/build_system.gd") as GDScript
	var build: Node = BuildScript.new() as Node
	root_node.add_child(build)
	build.blocked = bres.get("blocked", {})
	gs.reset_level()
	var illegal: bool = build.can_place(Vector2i(20, 18), &"jianta")
	ck("建造/道路格不可建", not illegal)
	var illegal_water: bool = build.can_place(Vector2i(5, 5), &"jianta")
	ck("建造/水域格不可建", not illegal_water)
	var legal: bool = build.can_place(Vector2i(16, 8), &"jianta")
	ck("建造/合法格可建", legal)
	var silver_before: int = gs.silver
	var holder := Node2D.new()
	root_node.add_child(holder)
	var tower: Node2D = build.place(Vector2i(16, 8), &"jianta", holder)
	ck("建造/放置成功", tower != null)
	ck("建造/扣银40", gs.silver == silver_before - 40)
	ck("建造/占格9", build.get_occupied_count() == 9)
	ck("建造/重复放置被拒", not build.can_place(Vector2i(5, 3), &"jianta"))
	build.queue_free()
	holder.queue_free()

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
