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
	assert_eq(int(data["version"]), 2)
	assert_eq(int(data["cell"]), 128)
	assert_eq(int(data["frame_count"]), 32)
	assert_eq((data["weapons"] as Array).size(), 14, "twelve melee/ranged plus shield and crossbow")
	assert_eq((data["offhand_allowed"] as Array).size(), 4)
	var ids := {}
	for weapon: Dictionary in data["weapons"]:
		ids[str(weapon["id"])] = true
		assert_true(str(weapon["attack_profile"]).length() > 0)
	for required in ["dao", "qiang", "jian", "ji", "fu", "yue", "gou", "cha", "dun", "gong", "nu"]:
		assert_true(ids.has(required), "missing required weapon: %s" % required)


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


func test_two_handed_and_ranged_keep_both_arms_front() -> void:
	var data := _load_data()
	if data.is_empty():
		return
	var rules: Dictionary = data["arm_layer_rules"]
	assert_eq(str(rules["two_hand"]), "both_front")
	assert_eq(str(rules["ranged"]), "both_front")
	assert_eq(str(rules["one_hand"]), "far_back_near_front")
	for weapon: Dictionary in data["weapons"]:
		var grip := str(weapon["grip"])
		var expected := "both_front" if grip in ["two_hand", "ranged"] else "far_back_near_front"
		assert_eq(str(weapon["arm_layer"]), expected, "%s arm layering" % weapon["id"])


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
	forge.set_frame(21)
	for child in forge.get_children():
		if child is Sprite2D:
			assert_eq(child.region_rect.position.x, 21 * 128)
			assert_eq(child.region_rect.size, Vector2(128, 128))


func test_preview_scene_instantiates_four_recipes() -> void:
	var scene := load("res://scenes/character_forge_preview.tscn") as PackedScene
	assert_not_null(scene, "character forge preview must load")
	if scene == null:
		return
	var preview := scene.instantiate()
	add_child_autofree(preview)
	await wait_process_frames(2)
	assert_eq((preview.get("forges") as Array).size(), 4)
