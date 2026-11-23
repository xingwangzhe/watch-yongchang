extends GutTest

const DATA_PATH := "res://data/character_templates.json"
const ForgeScript = preload("res://scripts/character/character_forge.gd")


func _load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	assert_not_null(parsed, "character template data must parse")
	return parsed if parsed is Dictionary else {}


func test_character_data_declares_full_ming_loadout() -> void:
	var data := _load_data()
	if data.is_empty():
		return
	assert_eq(int(data["version"]), 3)
	assert_eq(int(data["cell"]), 128)
	assert_eq(int(data["frame_count"]), 48)
	assert_eq(int(data["attack_action_count"]), 5)
	assert_eq((data["weapons"] as Array).size(), 14, "twelve melee/ranged plus shield and crossbow")
	assert_eq((data["offhand_allowed"] as Array).size(), 6)
	assert_eq((data["pose_variants"] as Array).size(), 17)
	assert_eq((data["combo_families"] as Array).size(), 3)
	assert_eq((data["combo_pairs"] as Dictionary).size(), 30)
	assert_eq(int(data["loadout_count"]), 43)
	assert_eq(int(data["combination_count"]), 90816)
	var ids := {}
	for weapon: Dictionary in data["weapons"]:
		ids[str(weapon["id"])] = true
		assert_true(str(weapon["attack_profile"]).length() > 0)
		var actions: Array = weapon["actions"]
		assert_eq(actions.size(), 5, "%s must bind five named actions" % weapon["id"])
		for index in actions.size():
			var action: Dictionary = actions[index]
			assert_eq(str(action["id"]), "attack_%d" % (index + 1))
			assert_true(str(action["name_zh"]).length() > 0)
			assert_true(str(action["name_en"]).length() > 0)
	for required in ["dao", "qiang", "jian", "ji", "fu", "yue", "gou", "cha", "dun", "gong", "nu"]:
		assert_true(ids.has(required), "missing required weapon: %s" % required)


func test_combo_families_are_bound_to_pair_keys() -> void:
	var data := _load_data()
	if data.is_empty():
		return
	var pairs: Dictionary = data["combo_pairs"]
	assert_eq(str(pairs["dao+dao"]), "same")
	assert_eq(str(pairs["dao+jian"]), "mixed")
	assert_eq(str(pairs["jian+dao"]), "mixed")
	assert_eq(str(pairs["dao+dun"]), "shield")
	assert_eq(str(pairs["longdeng+lingqi"]), "mixed")
	var action_names := {}
	for family in ["same", "mixed", "shield"]:
		var actions: Array = data["combo_actions"][family]
		assert_eq(actions.size(), 5)
		action_names[str(actions[0]["name_zh"])] = true
	assert_eq(action_names.size(), 3, "same/mixed/shield combos need distinct attacks")


func test_character_atlases_match_rows() -> void:
	var data := _load_data()
	if data.is_empty():
		return
	var cell := int(data["cell"])
	var columns := int(data["columns"])
	for key: String in ["body", "outfit", "headgear", "backgear", "weapon", "offhand"]:
		var atlas: Dictionary = data["atlases"][key]
		var texture := load(str(atlas["path"])) as Texture2D
		assert_not_null(texture, "%s atlas must load" % key)
		if texture == null:
			continue
		var rows: Dictionary = atlas["rows"]
		var row_count := 0
		for row: Variant in rows.values():
			assert_true(int(row) >= 0, "%s row cannot be negative" % key)
			row_count = maxi(row_count, int(row) + 1)
		assert_eq(texture.get_width(), columns * cell, "%s width" % key)
		assert_eq(texture.get_height(), row_count * cell, "%s height" % key)


func test_every_grip_keeps_both_arms_front() -> void:
	var data := _load_data()
	if data.is_empty():
		return
	var rules: Dictionary = data["arm_layer_rules"]
	assert_eq(str(data["arm_layer_policy"]), "all_arms_front")
	assert_eq(str(rules["two_hand"]), "both_front")
	assert_eq(str(rules["ranged"]), "both_front")
	assert_eq(str(rules["one_hand"]), "both_front")
	assert_eq(str(rules["offhand"]), "both_front")
	for weapon: Dictionary in data["weapons"]:
		assert_eq(str(weapon["arm_layer"]), "both_front", "%s arm layering" % weapon["id"])


func test_all_weapon_pose_rows_exist() -> void:
	var data := _load_data()
	if data.is_empty():
		return
	var loops := {
		"body": data["skins"],
		"outfit": data["outfits"],
		"headgear": data["headgear"],
		"backgear": data["backgear"],
	}
	for weapon: Dictionary in data["weapons"]:
		var pose_id := str(weapon["id"])
		for atlas_key: String in loops.keys():
			var rows: Dictionary = data["atlases"][atlas_key]["rows"]
			for item: Dictionary in loops[atlas_key]:
				var key := str(item["id"]) + "|" + pose_id
				assert_true(rows.has(key), "%s missing %s" % [atlas_key, key])


func test_every_combo_pair_has_weapon_and_offhand_rows() -> void:
	var data := _load_data()
	if data.is_empty():
		return
	var weapon_rows: Dictionary = data["atlases"]["weapon"]["rows"]
	var offhand_rows: Dictionary = data["atlases"]["offhand"]["rows"]
	for pair_key in data["combo_pairs"].keys():
		var key := str(pair_key)
		var split := key.split("+")
		assert_eq(split.size(), 2)
		assert_true(weapon_rows.has(key), "missing combo weapon row %s" % key)
		assert_true(
			offhand_rows.has("%s|%s" % [split[0], split[1]]),
			"missing combo offhand row %s" % key
		)


func test_hero_recipe_builds_six_layers() -> void:
	var forge := ForgeScript.new()
	add_child_autofree(forge)
	if not forge.load_data():
		fail_test("character forge data must load")
		return
	var data: Dictionary = forge.data
	forge.set_recipe(data["recipes"]["hero"])
	await wait_process_frames(1)
	assert_eq(forge.layer_count(), 6, "backgear/body/outfit/headgear/offhand/weapon")
	var rows: Dictionary = forge.layer_rows()
	assert_true(rows.has("offhand"))
	assert_true(rows.has("weapon"))
	assert_eq(forge.current_weapon_id(), "dao")
	assert_eq(forge.current_offhand_id(), "dun")
	assert_eq(forge.current_pose_variant(), "combo_shield")
	assert_eq(forge.current_weapon_row_key(), "dao+dun")
	assert_eq(
		int(rows["weapon"]),
		int(data["atlases"]["weapon"]["rows"]["dao+dun"]),
		"dual-wield main hand must use the pair-specific weapon row"
	)
	forge.set_frame(21)
	for child in forge.get_children():
		if child is Sprite2D:
			assert_eq(int(child.region_rect.position.x), 21 * 128)
			assert_eq(child.region_rect.size, Vector2(128, 128))


func test_single_and_dual_recipes_switch_weapon_rows() -> void:
	var forge := ForgeScript.new()
	add_child_autofree(forge)
	if not forge.load_data():
		fail_test("character forge data must load")
		return
	var data: Dictionary = forge.data
	var weapon_rows: Dictionary = data["atlases"]["weapon"]["rows"]
	var single: Dictionary = (data["recipes"]["wokou_raider"] as Dictionary).duplicate(true)
	single["offhand"] = "none"
	forge.set_recipe(single)
	assert_eq(forge.current_weapon_row_key(), "dao")
	assert_eq(int(forge.layer_rows()["weapon"]), int(weapon_rows["dao"]))
	var twin: Dictionary = single.duplicate(true)
	twin["offhand"] = "dao"
	forge.set_recipe(twin)
	assert_eq(forge.current_pose_variant(), "combo_same")
	assert_eq(forge.current_weapon_row_key(), "dao+dao")
	assert_eq(int(forge.layer_rows()["weapon"]), int(weapon_rows["dao+dao"]))
	var mixed: Dictionary = single.duplicate(true)
	mixed["offhand"] = "longdeng"
	forge.set_recipe(mixed)
	assert_eq(forge.current_pose_variant(), "combo_mixed")
	assert_eq(forge.current_weapon_row_key(), "dao+longdeng")
	assert_eq(int(forge.layer_rows()["weapon"]), int(weapon_rows["dao+longdeng"]))


func test_all_attack_clips_cover_five_actions() -> void:
	var data := _load_data()
	if data.is_empty():
		return
	var clips: Dictionary = data["clips"]
	var expected_start := 12
	for action in [1, 2, 3, 4, 5]:
		var clip: Dictionary = clips["attack_%d" % action]
		assert_eq(int(clip["start"]), expected_start)
		assert_eq(int(clip["count"]), 6)
		expected_start += 6


func test_preview_scene_instantiates_eight_recipes() -> void:
	var scene := load("res://scenes/character_forge_preview.tscn") as PackedScene
	assert_not_null(scene, "character forge preview must load")
	if scene == null:
		return
	var preview := scene.instantiate()
	add_child_autofree(preview)
	await wait_process_frames(2)
	assert_eq((preview.get("forges") as Array).size(), 8)
