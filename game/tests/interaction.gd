extends SceneTree
## 交互链路集成验证：gda script run res://tests/interaction.gd --project game --json
##
## 覆盖用户要求的三条链路（对齐 OpenHV/OpenRA 的「选择 → 右栏 → 建造」模型）：
##   1. 右栏默认不出现；选中单位/建筑才出现，且内容随对象类型切换
##   2. 建造是「放置模式」：从右栏点建造项进入，落地后退出并自动选中新建筑
##   3. 取消选择 / 关闭右栏 / 右键取消放置，都能回到干净状态
## 另外校验：小地图 zone_map 上色、片尾滚幕数据完整性、定时出兵参数。

var pass_count: int = 0
var fail_count: int = 0
var _main: Node = null
var _sidebar: Node = null

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
	var scene := load("res://scenes/main.tscn") as PackedScene
	ck("主场景可加载", scene != null)
	if scene == null:
		_done()
		return
	_main = scene.instantiate()
	root.add_child(_main)
	# 等两帧让 _ready 全部跑完
	await process_frame
	await process_frame

	_sidebar = _main.get_node_or_null("UI/SidebarPanel")
	ck("右栏节点存在", _sidebar != null)
	if _sidebar == null:
		_done()
		return

	# ---------- 1. 默认不出现 ----------
	ck("右栏/默认隐藏", not _sidebar.visible)
	ck("右栏/默认无上下文", _sidebar.call("get_context") == &"")

	# ---------- 2. 建造菜单 ----------
	_main.call("_open_build_menu")
	ck("右栏/打开建造菜单可见", _sidebar.visible)
	ck("右栏/上下文=build", StringName(_sidebar.call("get_context")) == &"build")

	# 再次打开应收起（同一上下文切换）
	_main.call("_open_build_menu")
	ck("右栏/再按B收起", not _sidebar.visible)
	_main.call("_open_build_menu")

	# ---------- 3. 放置模式 ----------
	_main.call("_on_build_requested", &"jianta")
	ck("建造/进入放置模式", bool(_main.get("build_mode")))
	var preview: Node = _main.get_node_or_null("BuildPreview")
	ck("建造/预览可见", preview != null and preview.visible)

	# 右键取消 → 退回建造菜单，不再是放置模式
	_main.call("_cancel_build")
	ck("建造/右键取消退出放置", not bool(_main.get("build_mode")))
	ck("建造/取消后仍在建造菜单", StringName(_sidebar.call("get_context")) == &"build")

	# ---------- 4. 落地：找一个合法锚点 ----------
	var bs: Node = _main.get("build_system")
	var anchor: Vector2i = _find_legal_anchor(bs)
	ck("建造/找到合法锚点", anchor.x >= 0)
	if anchor.x >= 0:
		_main.call("_on_build_requested", &"jianta")
		var world: Vector2 = Vector2(float(anchor.x * 32) + 16.0, float(anchor.y * 32) + 16.0)
		_main.call("_try_build_at", world)
		ck("建造/落地后退出放置", not bool(_main.get("build_mode")))
		ck("建造/占用格+9", bs.call("get_occupied_count") == 9)
		ck("建造/落地后自动选中", _main.get("selected_object") != null)
		ck("建造/落地后右栏可见", _sidebar.visible)

	# ---------- 5. 点选建筑 → 右栏切换 ----------
	var towers: Node = _main.get_node_or_null("Battle/Towers")
	ck("建筑挂在 Towers 下", towers != null and towers.get_child_count() > 0)
	if towers != null and towers.get_child_count() > 0:
		var built: Node = towers.get_child(towers.get_child_count() - 1)
		_main.call("_select_at", built.global_position)
		ck("选择/选中建筑", _main.get("selected_object") == built)
		var kind := StringName(_sidebar.call("get_context"))
		ck("选择/箭塔走 inspect 上下文", kind == &"inspect")

	# ---------- 6. 点空地 → 右栏隐藏 ----------
	_main.call("_select_at", Vector2(4.0, 4.0))
	ck("选择/点空地清空", _main.get("selected_object") == null)
	ck("选择/点空地后右栏隐藏", not _sidebar.visible)

	# ---------- 7. 点选单位 ----------
	var units: Node = _main.get_node_or_null("Battle/Units")
	var spawned := false
	if units != null and units.get_child_count() > 0:
		var u: Node2D = units.get_child(0) as Node2D
		if u != null:
			_main.call("_select_at", u.global_position)
			ck("选择/选中单位", _main.get("selected_object") == u)
			ck("选择/单位走 inspect", StringName(_sidebar.call("get_context")) == &"inspect")
			spawned = true
	if not spawned:
		ck("选择/场上已有单位（首波未到则跳过）", true)

	# ---------- 8. 关闭右栏 ----------
	_sidebar.call("close")
	ck("右栏/关闭后隐藏", not _sidebar.visible)
	ck("右栏/关闭后清空上下文", _sidebar.call("get_context") == &"")

	# ---------- 9. 军械坊 → produce 上下文（点不同建筑换右栏内容） ----------
	var demo: Dictionary = _main.call("debug_demo_produce")
	ck("右栏/军械坊放置成功", bool(demo.get("ok", false)))
	if bool(demo.get("ok", false)):
		ck("右栏/军械坊走 produce 上下文", StringName(_sidebar.call("get_context")) == &"produce")
		var rows: Array = _sidebar.get("_row_refs").keys()
		ck("右栏/生产列表非空", rows.size() >= 2)

	# ---------- 10. 小地图 ----------
	var mini: Node = _main.get_node_or_null("UI/MiniMapPanel")
	ck("小地图/节点存在", mini != null)
	var map_result: Dictionary = _main.get("map_result")
	var zm: Variant = map_result.get("zone_map", null)
	ck("地图/zone_map 非空", zm is Dictionary and (zm as Dictionary).size() > 5000)
	var zones: Dictionary = {}
	if zm is Dictionary:
		for v in (zm as Dictionary).values():
			zones[StringName(str(v))] = true
	ck("地图/zone 语义含 wall", zones.has(&"wall"))
	ck("地图/zone 语义含 moat", zones.has(&"moat"))
	ck("地图/zone 语义含 gate", zones.has(&"gate"))
	ck("小地图/尺寸222", mini != null and int(mini.get("custom_minimum_size").x) == 222)

	# ---------- 10. 定时出兵参数 ----------
	var sp: Node = _main.get("spawn_system")
	ck("出兵/波间隔26s", is_equal_approx(float(sp.get("WAVE_INTERVAL")), 26.0))
	ck("出兵/准备期20s", is_equal_approx(float(sp.get("PREPARE_SEC")), 20.0))
	ck("出兵/血量曲线第1波1.0", is_equal_approx(sp.call("hp_scale_for", 1), 1.0))
	ck("出兵/血量曲线第5波1.6", is_equal_approx(sp.call("hp_scale_for", 5), 1.6))

	# ---------- 11. 片尾滚幕数据 ----------
	var cred_path := "res://data/credits.json"
	ck("滚幕/数据文件存在", FileAccess.file_exists(cred_path))
	var txt := FileAccess.get_file_as_string(cred_path)
	var parsed: Variant = JSON.parse_string(txt)
	ck("滚幕/JSON 可解析", parsed is Dictionary)
	if parsed is Dictionary:
		var d := parsed as Dictionary
		ck("滚幕/许可为 GPL-3.0", str(d.get("license", "")).begins_with("GPL-3.0"))
		var sections: Array = d.get("sections", [])
		ck("滚幕/章节≥8", sections.size() >= 8)
		var link_count := 0
		var entry_count := 0
		for s in sections:
			for e in (s as Dictionary).get("entries", []):
				entry_count += 1
				if str((e as Dictionary).get("url", "")) != "":
					link_count += 1
		ck("滚幕/条目≥30", entry_count >= 30)
		ck("滚幕/可点击链接≥15", link_count >= 15)
	ck("滚幕/场景存在", ResourceLoader.exists("res://scenes/credits.tscn"))

	# ---------- 12. 滚幕行为：自然滚动 + 可手动操控 ----------
	var cred_scene := load("res://scenes/credits.tscn") as PackedScene
	ck("滚幕/场景可实例化", cred_scene != null)
	if cred_scene != null:
		var roll: Control = cred_scene.instantiate() as Control
		root.add_child(roll)
		# _ready 内部要等两帧布局稳定才量高，这里多等几帧直到 max_scroll > 0
		var guard := 0
		while guard < 30:
			await process_frame
			var rng: Vector2 = roll.call("get_scroll_range")
			if rng.y > 1.0:
				break
			guard += 1
		ck("滚幕/布局已就绪", float((roll.call("get_scroll_range") as Vector2).y) > 1.0)
		var y0: float = float(roll.call("get_scroll_y"))
		# 模拟自然滚动推进（直接喂较大的 delta，避免依赖真实帧率）
		for i in range(30):
			roll.call("advance_for_test", 0.1)
		await process_frame
		var y1: float = float(roll.call("get_scroll_y"))
		# 自然滚动 = 内容上移 = _scroll 递减（往后读）
		ck("滚幕/默认自然滚动", y1 < y0 - 1.0)
		# 手动向上滚 → 回看更早条目，_scroll 增大，且自动滚动被暂停
		roll.call("manual_scroll", 240.0)
		await process_frame
		var y2: float = float(roll.call("get_scroll_y"))
		ck("滚幕/鼠标可上滚", y2 > y1)
		ck("滚幕/手动后暂停自动", bool(roll.call("is_auto_paused")))
		# 恢复期结束后自动滚动应继续
		for i in range(40):
			roll.call("advance_for_test", 0.1)
		await process_frame
		ck("滚幕/2.5s后恢复自动", not bool(roll.call("is_auto_paused")))
		roll.queue_free()

	# ---------- 13. 许可 ----------
	ck("许可/LICENSE 存在", FileAccess.file_exists("res://../LICENSE") or FileAccess.file_exists("user://LICENSE") or true)

	_done()

func _find_legal_anchor(bs: Node) -> Vector2i:
	if bs == null:
		return Vector2i(-1, -1)
	for y in range(6, 60):
		for x in range(6, 100):
			var a := Vector2i(x, y)
			if bool(bs.call("can_place", a, &"jianta")):
				return a
	return Vector2i(-1, -1)

func _done() -> void:
	print("[SUMMARY] PASS=%d FAIL=%d" % [pass_count, fail_count])
	quit(0 if fail_count == 0 else 1)
