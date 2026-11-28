extends GutTest

## 箭塔系统的契约测试：数据定义、运行时实体、可被攻击、增益与重建。
## 这些用例把「塔会自己打人、也会挨打」这条新玩法锁死，防止后续改动回归。

const TEST_SAVE := "user://test_tower_system_save.json"


func before_each() -> void:
	SaveSystem.save_path = TEST_SAVE
	SaveSystem.reset_memory()
	Locale.set_language("zh", false)


func after_each() -> void:
	SaveSystem.save_path = SaveSystem.SAVE_PATH
	_remove_user_file(TEST_SAVE)


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _new_field() -> Battlefield:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(20261124)
	field.set_player_sprites(GameData.get_characters()["wanglu"] as Dictionary)
	return field


func test_tower_definitions_are_complete_and_bilingual() -> void:
	var data := GameData.load_json("res://data/towers.json")
	var defs: Dictionary = data.get("towers", {}) as Dictionary
	assert_eq(defs.size(), 3)
	assert_eq(int(data.get("starting_towers", 0)), 2)
	assert_gte(int(data.get("max_towers", 0)), 3)
	var weapon_art: Dictionary = data.get("weapon_art", {}) as Dictionary
	assert_eq(str(weapon_art.get("source", "")), "pixel-art/renewed_composable/source/weapon_props.png")
	assert_eq(int(weapon_art.get("cell", -1)), 10)
	assert_eq(str(weapon_art.get("item", "")), "nu")
	assert_true(ResourceLoader.exists(str(weapon_art.get("texture", ""))), "generated crossbow component must exist")
	var order := ["watchtower", "arrow_tower", "dragon_tower"]
	for index in defs.size():
		var tower_id: String = order[index]
		assert_true(defs.has(tower_id), "%s must be defined" % tower_id)
		var definition: Dictionary = defs[tower_id] as Dictionary
		assert_eq(str(definition.get("art_source", "")), "pixel-art/overhead_buildings/source/towers_atlas.png")
		assert_eq(int(definition.get("art_cell", -1)), index)
		assert_true(str(definition.get("texture", "")).ends_with("/%s.webp" % tower_id))
		for field in ["name_zh", "name_en", "desc_zh", "desc_en"]:
			assert_gt(str(definition.get(field, "")).length(), 0, "%s missing %s" % [tower_id, field])
		assert_true(ResourceLoader.exists(str(definition.get("texture", ""))), "%s texture missing" % tower_id)
		assert_gt(float(definition.get("hp", 0.0)), 0.0)
		assert_gt(float(definition.get("range", 0.0)), 0.0)
		assert_gt(float(definition.get("damage", 0.0)), 0.0)
		assert_gt(float(definition.get("cooldown", 0.0)), 0.0)
		assert_gt(float(definition.get("radius", 0.0)), 0.0)
		assert_gt(float(definition.get("regen", 0.0)), 0.0, "%s must auto-repair by default" % tower_id)
		if index < order.size() - 1:
			assert_eq(str(definition.get("upgrade_to", "")), order[index + 1])

	# 三档必须逐级变强，否则升阶卡就是负收益
	for index in range(1, order.size()):
		var prev: Dictionary = defs[order[index - 1]] as Dictionary
		var curr: Dictionary = defs[order[index]] as Dictionary
		assert_gt(float(curr["hp"]), float(prev["hp"]))
		assert_gt(float(curr["damage"]), float(prev["damage"]))
		assert_gt(float(curr["range"]), float(prev["range"]))


func test_tower_textures_are_large_and_native_pixel() -> void:
	# 「贴图要大一些」：单张塔贴图边长必须明显大于 128px 的角色帧
	var defs: Dictionary = (GameData.load_json("res://data/towers.json") as Dictionary).get("towers", {}) as Dictionary
	for tower_id in defs.keys():
		var definition: Dictionary = defs[tower_id] as Dictionary
		var texture := load(str(definition.get("texture", ""))) as Texture2D
		assert_not_null(texture, "%s texture failed to load" % tower_id)
		assert_gte(texture.get_width(), 160, "%s sprite must be large" % tower_id)
		assert_gte(texture.get_height(), 160, "%s sprite must be large" % tower_id)
		assert_eq(texture.get_width(), texture.get_height(), "%s sprite must be square" % tower_id)


func test_tower_spawns_with_hp_and_can_be_damaged() -> void:
	var field := _new_field()
	var index := field.spawn_tower("watchtower", Vector2(300, 0))
	assert_gte(index, 0)
	assert_eq(field.live_tower_count(), 1)
	var tower: Dictionary = field.towers[index]
	assert_gt(float(tower["hp"]), 0.0)
	assert_eq(float(tower["hp"]), float(tower["max_hp"]))
	field.damage_tower(index, 40.0, -1)
	assert_lt(float(tower["hp"]), float(tower["max_hp"]))
	field.damage_tower(index, 100000.0, -1)
	assert_false(bool(tower["alive"]), "lethal damage must destroy a tower")
	assert_eq(field.live_tower_count(), 0)


func test_tower_auto_fires_at_nearest_enemy() -> void:
	var field := _new_field()
	var tower_pos := Vector2(1952, 1536)
	var tower_index := field.spawn_tower("watchtower", tower_pos)
	field.towers[tower_index]["attack_timer"] = 0.0
	var enemy_index := field.spawn_enemy_at("scout", tower_pos + Vector2(180, 0))
	var enemy: Dictionary = field.enemies[enemy_index]
	enemy["speed"] = 0.0
	field.update_world(1.0 / 60.0, {"pos": Vector2(2500, 1536), "radius": 18.0, "pickup_radius": 0.0})
	assert_gt(field.tower_shots.size(), 0, "tower must launch an arrow at a nearby enemy")
	var shot: Dictionary = field.tower_shots[0]
	assert_gt(float(shot["damage"]), 0.0)
	assert_gt((shot["vel"] as Vector2).x, 0.0, "arrow must fly toward the enemy")
	assert_true((shot["origin"] as Vector2).is_equal_approx(field.towers[tower_index]["pos"] as Vector2))
	assert_eq(str(shot.get("projectile_kind", "")), "crossbow_bolt")
	assert_false(
		shot.has("texture"),
		"tower bolts must use their explicit shaft, head, and fletching silhouette"
	)


func test_tower_projectile_geometry_has_bolt_head_and_two_fletchings() -> void:
	var field := _new_field()
	field._fire_tower_arrow(
		Vector2(100.0, 100.0), Vector2.RIGHT, 640.0, 10.0, 1, Color.WHITE, false
	)
	var shot: Dictionary = field.tower_shots[0]
	assert_eq(str(shot.get("projectile_kind", "")), "crossbow_bolt")
	assert_false(
		shot.has("texture"),
		"projectile must not sample a sword or weapon texture"
	)
	var geometry := field._tower_projectile_geometry(Vector2.ZERO, Vector2.RIGHT)
	assert_eq(str(geometry.get("kind", "")), "crossbow_bolt")
	var shaft_from := geometry["shaft_from"] as Vector2
	var shaft_to := geometry["shaft_to"] as Vector2
	assert_gt(shaft_to.x, shaft_from.x, "bolt shaft must extend toward its arrowhead")
	var head := geometry["head"] as PackedVector2Array
	assert_eq(head.size(), 3, "bolt head must be a complete triangular arrowhead")
	assert_gt(head[0].x, shaft_to.x, "arrowhead tip must lead the shaft")
	var fletchings: Array = geometry["fletchings"] as Array
	assert_eq(fletchings.size(), 2, "bolt tail must have two visible fletchings")
	for fletching in fletchings:
		assert_eq((fletching as PackedVector2Array).size(), 3, "each fletching must be a filled feather shape")


func test_tower_arrow_actually_damages_enemy() -> void:
	var field := _new_field()
	var tower_pos := Vector2(1952, 1536)
	var tower_index := field.spawn_tower("watchtower", tower_pos)
	field.towers[tower_index]["attack_timer"] = 0.0
	var enemy_index := field.spawn_enemy_at("scout", tower_pos + Vector2(150, 0))
	var enemy: Dictionary = field.enemies[enemy_index]
	enemy["speed"] = 0.0
	var before_hp := float(enemy["hp"])
	var player := {"pos": Vector2(2500, 1536), "radius": 18.0, "pickup_radius": 0.0}
	for _frame in range(45):
		field.update_world(1.0 / 60.0, player)
		if float(enemy["hp"]) < before_hp:
			break
	assert_lt(float(enemy["hp"]), before_hp, "arrow must really hit and damage the enemy")


func test_tower_kills_award_xp_immediately_without_pickup() -> void:
	var field := _new_field()
	var tower_pos := Vector2(1952, 1536)
	var tower_index := field.spawn_tower("watchtower", tower_pos)
	var tower: Dictionary = field.towers[tower_index]
	tower["attack_timer"] = 0.0
	tower["cooldown"] = 0.10
	tower["damage"] = 9999.0
	var enemy_index := field.spawn_enemy_at("scout", tower_pos + Vector2(170, 0))
	field.enemies[enemy_index]["speed"] = 0.0
	var killed: Array[bool] = [false]
	var collected: Array[float] = []
	field.enemy_killed.connect(func(_id: String, _pos: Vector2, _elite: bool) -> void: killed[0] = true)
	field.xp_awarded.connect(func(amount: float) -> void: collected.append(amount))
	var far_player := {"pos": Vector2(2600, 1536), "radius": 18.0, "pickup_radius": 0.0}
	for _frame in range(90):
		field.update_world(1.0 / 60.0, far_player)
		if killed[0]:
			break
	assert_true(killed[0], "tower must kill the stationary scout")
	assert_eq(collected.size(), 1, "tower kill must award XP on the kill frame")
	assert_gt(float(collected[0]), 0.001, "immediate XP award must be positive")
	assert_false(tower.has("xp"), "towers must not bank experience")


func test_tower_arrow_passes_through_buildings() -> void:
	var field := _new_field()
	var tower_pos := Vector2(1952, 1536)
	field.spawn_tower("watchtower", tower_pos)
	var enemy_pos := tower_pos + Vector2(260, 0)
	var enemy_index := field.spawn_enemy_at("shield", enemy_pos)
	var enemy: Dictionary = field.enemies[enemy_index]
	enemy["speed"] = 0.0
	enemy["hp"] = 1000.0
	enemy["max_hp"] = 1000.0
	field.map_layout.mark_solid_rect(Rect2i(64, 44, 1, 9))
	var before_hp := float(enemy["hp"])
	var player := {"pos": Vector2(2600, 1536), "radius": 18.0, "pickup_radius": 0.0}
	for _frame in range(90):
		field.update_world(1.0 / 60.0, player)
		if float(enemy["hp"]) < before_hp:
			break
	assert_lt(
		float(enemy["hp"]),
		before_hp,
		"friendly tower arrows must ignore building collision"
	)


func test_tower_burst_continues_during_main_cooldown() -> void:
	var field := _new_field()
	field.apply_tower_stats({"tower_burst_shots": 3})
	var tower_pos := Vector2(1952, 1536)
	var tower_index := field.spawn_tower("watchtower", tower_pos)
	field.towers[tower_index]["attack_timer"] = 0.0
	var enemy_index := field.spawn_enemy_at("scout", tower_pos + Vector2(180, 0))
	field.enemies[enemy_index]["speed"] = 0.0
	field.enemies[enemy_index]["hp"] = 100000.0
	field.enemies[enemy_index]["max_hp"] = 100000.0
	var player := {"pos": Vector2(2500, 1536), "radius": 18.0, "pickup_radius": 0.0}
	field.update_world(1.0 / 60.0, player)
	assert_eq(field.tower_shots.size(), 1)
	assert_gt(float(field.towers[tower_index]["attack_timer"]), 0.0)
	for _frame in range(8):
		field.update_world(1.0 / 60.0, player)
	assert_eq(field.tower_shots.size(), 2, "burst must fire while the main volley is cooling down")


func test_tower_twin_lanes_fire_concurrently_with_new_volley() -> void:
	var field := _new_field()
	field.apply_tower_stats({"tower_burst_shots": 2, "tower_burst_lanes": 1})
	var tower_pos := Vector2(1952, 1536)
	var tower_index := field.spawn_tower("watchtower", tower_pos)
	var tower: Dictionary = field.towers[tower_index]
	assert_eq((tower["burst_lanes"] as Array).size(), 2)
	tower["attack_timer"] = 0.0
	tower["cooldown"] = 0.12
	var enemy_index := field.spawn_enemy_at("scout", tower_pos + Vector2(180, 0))
	field.enemies[enemy_index]["speed"] = 0.0
	field.enemies[enemy_index]["hp"] = 100000.0
	field.enemies[enemy_index]["max_hp"] = 100000.0
	var player := {"pos": Vector2(2500, 1536), "radius": 18.0, "pickup_radius": 0.0}
	field.update_world(1.0 / 60.0, player)
	for _frame in range(6):
		field.update_world(1.0 / 60.0, player)
	var before := field.tower_shots.size()
	tower["attack_timer"] = 0.0
	field.update_world(1.0 / 60.0, player)
	assert_eq(field.tower_shots.size() - before, 3, "one new volley and two independent bursts must fire in the same frame")
	var lanes: Array = tower["burst_lanes"] as Array
	assert_eq(int(lanes[0]["remaining"]), 1)
	assert_eq(int(lanes[1]["remaining"]), 1)


func test_tower_body_blocks_enemies_and_stops_facing_jitter() -> void:
	var field := _new_field()
	var tower_pos := Vector2(1952, 1536)
	var tower_index := field.spawn_tower("watchtower", tower_pos)
	field.towers[tower_index]["attack_timer"] = 999.0
	var enemy_index := field.spawn_enemy_at("scout", tower_pos + Vector2(150, 0))
	field.enemies[enemy_index]["speed"] = 90.0
	var player := {"pos": Vector2(2500, 1536), "radius": 18.0, "pickup_radius": 0.0}
	var flips := 0
	var last_facing := float(field.enemies[enemy_index]["facing_x"])
	for _frame in range(150):
		field.update_world(1.0 / 60.0, player)
		var facing := float(field.enemies[enemy_index]["facing_x"])
		if not is_equal_approx(facing, last_facing):
			flips += 1
			last_facing = facing
	var enemy_pos := field.enemies[enemy_index]["pos"] as Vector2
	assert_gte(enemy_pos.distance_to(tower_pos), 75.0, "enemy must be pushed outside the tower body")
	assert_lte(flips, 2, "enemy facing must not oscillate against the tower")


func test_tower_damage_applies_armor_and_heals_ratio() -> void:
	var field := _new_field()
	var index := field.spawn_tower("watchtower", Vector2(1952, 1536))
	field.apply_tower_stats({"tower_armor": 0.5, "tower_hp_mult": 2.0})
	var tower: Dictionary = field.towers[index]
	assert_eq(float(tower["max_hp"]), 6800.0, "watchtower base HP is 3400 after the x10 tower-only pass")
	assert_eq(float(tower["armor"]), 0.5)
	field.damage_tower(index, 100.0, -1)
	assert_almost_eq(float(tower["max_hp"]) - float(tower["hp"]), 50.0, 0.001, "armor must halve incoming damage")


func test_tower_upgrade_promotes_tier() -> void:
	var field := _new_field()
	var index := field.spawn_tower("watchtower", Vector2(1952, 1536))
	var before_hp := float(field.towers[index]["max_hp"])
	assert_true(field.upgrade_tower(index, "arrow_tower"))
	assert_eq(str(field.towers[index]["id"]), "arrow_tower")
	assert_gt(float(field.towers[index]["max_hp"]), before_hp)
	assert_false(field.upgrade_tower(index, "nonexistent_tower"))


func test_enemies_siege_tower_instead_of_player_when_closer() -> void:
	var field := _new_field()
	var tower_pos := Vector2(1952, 1536)
	var tower_index := field.spawn_tower("watchtower", tower_pos)
	field.towers[tower_index]["attack_timer"] = 999.0  # 隔离：本测试只看敌人行为
	var enemy_index := field.spawn_enemy_at("scout", tower_pos + Vector2(60, 0))
	var enemy: Dictionary = field.enemies[enemy_index]
	enemy["speed"] = 0.0
	# 玩家远在 1200 之外，塔近在 60 处；敌人应把塔当目标并造成伤害
	field.update_world(1.0 / 60.0, {"pos": Vector2(2500, 1536), "radius": 18.0, "pickup_radius": 0.0})
	assert_lt(float(field.towers[tower_index]["hp"]), float(field.towers[tower_index]["max_hp"]), "enemy must attack the nearby tower")


func test_enemy_shots_can_destroy_tower() -> void:
	var field := _new_field()
	var tower_pos := Vector2(1952, 1536)
	var index := field.spawn_tower("watchtower", tower_pos)
	var actual_pos := field.towers[index]["pos"] as Vector2
	field.enemy_shots.append({
		"pos": actual_pos, "vel": Vector2.ZERO, "damage": 100000.0, "ttl": 2.0,
	})
	field.update_world(1.0 / 60.0, {"pos": Vector2(2500, 1536), "radius": 18.0, "pickup_radius": 0.0})
	assert_false(bool(field.towers[index]["alive"]), "enemy projectiles must be able to hit towers")


func test_tower_cards_drive_every_tower_stat() -> void:
	var data := GameData.load_json("res://data/upgrades.json")
	var cards: Dictionary = data.get("towers", {}) as Dictionary
	assert_eq(cards.size(), 32)
	assert_true(cards.has("tower_repeating_rack"))
	assert_true(cards.has("tower_twin_trigger"))
	var used_stats := {}
	for card_id in cards.keys():
		var card: Dictionary = cards[card_id] as Dictionary
		assert_gt(str(card.get("name_zh", "")).length(), 0)
		assert_gt(str(card.get("name_en", "")).length(), 0)
		assert_gt(str(card.get("desc_zh", "")).length(), 0)
		assert_gt(str(card.get("culture_zh", "")).length(), 0)
		assert_gt(int(card.get("max_level", 0)), 0)
		assert_true(ResourceLoader.exists(str(card.get("icon", ""))), "%s icon missing" % card_id)
		for effect in card.get("effects", []) as Array:
			var stat := str((effect as Dictionary).get("stat", ""))
			if card_id == "tower_gleanings":
				assert_eq(stat, "xp_mult", "tower gleanings now boosts direct kill XP")
			else:
				assert_true(stat.begins_with("tower_"), "%s must use a tower_* stat" % card_id)
			used_stats[stat] = true
	assert_gt(used_stats.size(), 20, "tower cards must cover a wide stat surface")


func test_tower_aggro_can_be_retargeted_by_card() -> void:
	var field := _new_field()
	assert_almost_eq(field.TOWER_AGGRO, 360.0, 0.001)
	var tower_pos := Vector2(1952, 1536)
	var tower_index := field.spawn_tower("watchtower", tower_pos)
	var probe := tower_pos + Vector2(400, 0)
	assert_eq(field._nearest_tower_index(probe, field.TOWER_AGGRO), -1, "default aggro must not reach 400px")
	field.apply_tower_stats({"tower_taunt": 2.0})
	assert_eq(field._nearest_tower_index(probe, field.TOWER_AGGRO * 2.0), tower_index, "taunt card must extend siege aggro")
