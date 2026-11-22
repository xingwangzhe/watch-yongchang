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

	# 6. 建造系统（Mindustry/RWX 多格占格）
	var BuildScript: GDScript = load("res://scripts/build_system.gd") as GDScript
	var build: Node = BuildScript.new() as Node
	root_node.add_child(build)
	gs.reset_level()
	var illegal: bool = build.can_place(Vector2i(10, 7), &"jianta")
	ck("建造/道路格不可建", not illegal)
	var legal: bool = build.can_place(Vector2i(5, 3), &"jianta")
	ck("建造/合法格可建", legal)
	var silver_before: int = gs.silver
	var holder := Node2D.new()
	root_node.add_child(holder)
	var tower: Node2D = build.place(Vector2i(5, 3), &"jianta", holder)
	ck("建造/放置成功", tower != null)
	ck("建造/扣银40", gs.silver == silver_before - 40)
	ck("建造/占格9", build.get_occupied_count() == 9)
	ck("建造/重复放置被拒", not build.can_place(Vector2i(5, 3), &"jianta"))
	build.queue_free()
	holder.queue_free()

	_done()

func _done() -> void:
	print("[SUMMARY] PASS=%d FAIL=%d" % [pass_count, fail_count])
	quit(0 if fail_count == 0 else 1)
