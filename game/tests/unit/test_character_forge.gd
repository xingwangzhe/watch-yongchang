extends GutTest

const DATA_PATH := "res://data/character_templates.json"
const ForgeScript = preload("res://scripts/character/character_forge.gd")


func _load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	assert_not_null(parsed, "character template data must parse")
	return parsed if parsed is Dictionary else {}


func _data_item(data: Dictionary, group: String, item_id: String) -> Dictionary:
	for entry: Variant in data.get(group, []):
		if entry is Dictionary and str(entry.get("id", "")) == item_id:
			return entry
	return {}


func _gear_factions(data: Dictionary, recipe: Dictionary) -> Array:
	var result: Array = []
	for pair: Array in [
		["outfits", "outfit"], ["headgear", "headgear"], ["backgear", "backgear"],
	]:
		var item := _data_item(data, str(pair[0]), str(recipe.get(pair[1], "")))
		if not item.is_empty():
			result.append(str(item.get("faction", "neutral")))
	var weapon := _data_item(data, "weapons", str(recipe.get("weapon", "")))
	if not weapon.is_empty():
		result.append(str(weapon.get("faction", "neutral")))
	var offhand_id := str(recipe.get("offhand", "none"))
	if offhand_id != "none":
		var offhand := _data_item(data, "weapons", offhand_id)
		if not offhand.is_empty():
			result.append(str(offhand.get("faction", "neutral")))
	return result


func _faction_allowed(_data: Dictionary, item: Dictionary, faction: String) -> bool:
	var item_faction := str(item.get("faction", "neutral"))
	return item_faction == "neutral" or item_faction == faction


func test_character_data_declares_full_ming_loadout() -> void:
	var data := _load_data()
	if data.is_empty():
		return
	assert_eq(int(data["version"]), 4)
	assert_eq(int(data["cell"]), 128)
	assert_eq(int(data["frame_count"]), 48)
	assert_eq(int(data["attack_action_count"]), 5)
	assert_eq((data["weapons"] as Array).size(), 19)
	assert_eq((data["offhand_allowed"] as Array).size(), 7)
	assert_eq((data["pose_variants"] as Array).size(), 22)
	assert_eq((data["combo_families"] as Array).size(), 3)
	assert_eq((data["combo_pairs"] as Dictionary).size(), 42)
	assert_eq(int(data["loadout_count"]), 59)
	assert_eq(int(data["faction_loadout_counts"]["ming"]), 58)
	assert_eq(int(data["faction_loadout_counts"]["wokou"]), 24)
	assert_eq(int(data["faction_combination_counts"]["ming"]), 33408)
	assert_eq(int(data["faction_combination_counts"]["wokou"]), 15360)
	assert_eq(int(data["combination_count"]), 48768)
	var ids := {}
	for weapon: Dictionary in data["weapons"]:
		ids[str(weapon["id"])] = true
		assert_true(str(weapon["faction"]) in ["ming", "wokou", "neutral"])
		assert_true(str(weapon["attack_profile"]).length() > 0)
		var actions: Array = weapon["actions"]
		assert_eq(actions.size(), 5, "%s must bind five named actions" % weapon["id"])
		for index in actions.size():
			var action: Dictionary = actions[index]
			assert_eq(str(action["id"]), "attack_%d" % (index + 1))
			assert_true(str(action["name_zh"]).length() > 0)
			assert_true(str(action["name_en"]).length() > 0)
	for required in [
		"dao", "qiang", "jian", "ji", "fu", "yue", "gou", "cha", "dun", "gong", "nu",
		"langxian", "qijia_dao", "tengpai", "tangpa", "wokou_dao",
	]:
		assert_true(ids.has(required), "missing required weapon: %s" % required)


func test_faction_exclusive_equipment_is_tagged() -> void:
	var data := _load_data()
	if data.is_empty():
		return
	var expected := {
		"weapons": {
			"langxian": "ming", "qijia_dao": "ming", "tengpai": "ming",
			"tangpa": "ming", "wokou_dao": "wokou",
		},
		"outfits": {
			"ming_qijia_armor": "ming", "wokou_domaru": "wokou",
			"wokou_haramaki": "wokou", "common_leather_vest": "neutral",
		},
		"headgear": {
			"wokou_kasa": "wokou", "common_headwrap": "neutral",
		},
	}
	for group: String in expected.keys():
		for item_id: String in expected[group].keys():
			var item := _data_item(data, group, item_id)
			assert_false(item.is_empty(), "missing faction item %s" % item_id)
			assert_eq(
				str(item.get("faction", "")),
				str(expected[group][item_id]),
				"%s faction" % item_id
			)
	for item_id: String in ["langxian", "qijia_dao", "tengpai", "tangpa", "wokou_dao"]:
		assert_true(bool(_data_item(data, "weapons", item_id).get("exclusive", false)))
	for item_id: String in ["ming_qijia_armor", "wokou_domaru", "wokou_haramaki"]:
		assert_true(bool(_data_item(data, "outfits", item_id).get("exclusive", false)))
	assert_true(bool(_data_item(data, "headgear", "wokou_kasa").get("exclusive", false)))


func test_no_preset_mixes_ming_and_wokou_gear() -> void:
	var data := _load_data()
	if data.is_empty():
		return
	for recipe_name: String in data["recipes"].keys():
		var recipe: Dictionary = data["recipes"][recipe_name]
		var declared := str(recipe.get("faction", ""))
		assert_true(declared in ["ming", "wokou", "neutral"], "%s faction" % recipe_name)
		var factions := {}
		for faction: String in _gear_factions(data, recipe):
			if faction != "neutral":
				factions[faction] = true
		assert_true(factions.size() <= 1, "%s mixes factions: %s" % [recipe_name, factions])
		if declared == "neutral":
			assert_eq(factions.size(), 0, "%s neutral preset uses exclusive gear" % recipe_name)
		elif declared == "ming":
			assert_false(factions.has("wokou"), "%s Ming preset uses Wokou gear" % recipe_name)
		elif declared == "wokou":
			assert_false(factions.has("ming"), "%s Wokou preset uses Ming gear" % recipe_name)


func test_combo_families_are_bound_to_pair_keys() -> void:
	var data := _load_data()
	if data.is_empty():
		return
	var pairs: Dictionary = data["combo_pairs"]
	assert_eq(str(pairs["dao+dao"]), "same")
	assert_eq(str(pairs["dao+jian"]), "mixed")
	assert_eq(str(pairs["jian+dao"]), "mixed")
	assert_eq(str(pairs["dao+dun"]), "shield")
	assert_eq(str(pairs["qijia_dao+tengpai"]), "shield")
	assert_eq(str(pairs["longdeng+lingqi"]), "mixed")
	for pair_key: String in pairs.keys():
		assert_ne(str(data["combo_pair_factions"][pair_key]), "mixed")
		assert_false(pair_key.begins_with("wokou_dao+"), "Wokou saber is two-handed")
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
		var rows: Dictionary = atlas["rows"]
		var row_count := 0
		for row: Variant in rows.values():
			assert_true(int(row) >= 0, "%s row cannot be negative" % key)
			row_count = maxi(row_count, int(row) + 1)
		var pages: Array = atlas.get("pages", [])
		assert_false(pages.is_empty(), "%s atlas needs pages" % key)
		var covered := {}
		for page: Dictionary in pages:
			var texture := load(str(page["path"])) as Texture2D
			assert_not_null(texture, "%s page must load: %s" % [key, page["path"]])
			if texture == null:
				continue
			var offset := int(page["row_offset"])
			var count := int(page["row_count"])
			assert_eq(texture.get_width(), columns * cell, "%s width" % key)
			assert_eq(texture.get_height(), count * cell, "%s page height" % key)
			assert_true(texture.get_height() <= 16384, "%s page exceeds 2D texture height" % key)
			for local_row in count:
				covered[offset + local_row] = true
		assert_eq(covered.size(), row_count, "%s pages must cover every row" % key)


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
	mixed["faction"] = "ming"
	mixed["outfit"] = "common_leather_vest"
	mixed["headgear"] = "common_headwrap"
	mixed["backgear"] = "none"
	mixed["offhand"] = "longdeng"
	forge.set_recipe(mixed)
	assert_eq(forge.current_pose_variant(), "combo_mixed")
	assert_eq(forge.current_weapon_row_key(), "dao+longdeng")
	assert_eq(int(forge.layer_rows()["weapon"]), int(weapon_rows["dao+longdeng"]))


func test_runtime_rejects_ming_wokou_mixes() -> void:
	var forge := ForgeScript.new()
	add_child_autofree(forge)
	if not forge.load_data():
		fail_test("character forge data must load")
		return
	var data: Dictionary = forge.data
	forge.set_recipe(data["recipes"]["hero"])
	var weapon_before := forge.current_weapon_id()
	var layers_before := forge.layer_count()
	var mixed := {
		"faction": "wokou",
		"skin": "tan",
		"outfit": "wokou_domaru",
		"headgear": "wokou_kasa",
		"backgear": "none",
		"weapon": "qijia_dao",
		"offhand": "none",
	}
	forge.set_recipe(mixed)
	assert_eq(forge.current_weapon_id(), weapon_before, "rejected recipe must not replace hero")
	assert_eq(forge.layer_count(), layers_before)
	assert_eq(forge.current_faction(), "ming")


func test_wokou_saber_is_two_handed_without_offhand() -> void:
	var forge := ForgeScript.new()
	add_child_autofree(forge)
	if not forge.load_data():
		fail_test("character forge data must load")
		return
	var recipe: Dictionary = (forge.data["recipes"]["wokou_swordsman_domaru"] as Dictionary).duplicate(true)
	recipe["offhand"] = "dun"
	forge.set_recipe(recipe)
	assert_eq(forge.current_offhand_id(), "none")
	assert_eq(forge.current_weapon_row_key(), "wokou_dao")
	assert_false(forge.layer_rows().has("offhand"))


func test_paged_outfit_rows_select_the_local_page_row() -> void:
	var forge := ForgeScript.new()
	add_child_autofree(forge)
	if not forge.load_data():
		fail_test("character forge data must load")
		return
	forge.set_recipe(forge.data["recipes"]["common_villager"])
	var row := int(forge.layer_rows()["outfit"])
	assert_eq(row, 341, "common leather vest uses the last outfit page")
	var pages: Array = forge.data["atlases"]["outfit"]["pages"]
	var local_row := -1
	for page: Dictionary in pages:
		var offset := int(page["row_offset"])
		if row >= offset and row < offset + int(page["row_count"]):
			local_row = row - offset
			break
	assert_true(local_row >= 0)
	var layer := forge.get_node_or_null("Layer_outfit") as Sprite2D
	assert_not_null(layer)
	if layer != null:
		assert_eq(int(layer.region_rect.position.y), local_row * 128)


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


func test_preview_scene_instantiates_faction_recipes() -> void:
	var scene := load("res://scenes/character_forge_preview.tscn") as PackedScene
	assert_not_null(scene, "character forge preview must load")
	if scene == null:
		return
	var preview := scene.instantiate()
	add_child_autofree(preview)
	await wait_process_frames(2)
	assert_eq((preview.get("forges") as Array).size(), 10)


func test_runtime_random_recipe_is_deterministic() -> void:
	var forge := ForgeScript.new()
	add_child_autofree(forge)
	if not forge.load_data():
		fail_test("character forge data must load")
		return
	var first: Dictionary = forge.random_recipe(24680, "ming")
	var second: Dictionary = forge.random_recipe(24680, "ming")
	assert_eq(first, second)
	assert_eq(str(first["faction"]), "ming")
	assert_true(first.has("skin"))
	assert_true(first.has("weapon"))
	var default_recipe: Dictionary = forge.random_recipe(24680)
	assert_eq(default_recipe, first, "default random roster is Ming")
	assert_eq(forge.combo_family_for("dao", "dao"), "same")
	assert_eq(forge.combo_family_for("dao", "jian"), "mixed")
	assert_eq(forge.combo_family_for("dao", "dun"), "shield")
	assert_eq(forge.combo_family_for("dao", "none"), "")


func test_runtime_random_recipes_respect_factions() -> void:
	var forge := ForgeScript.new()
	add_child_autofree(forge)
	if not forge.load_data():
		fail_test("character forge data must load")
		return
	var expected := {
		"ming": {"mains": 16, "offhands": 7},
		"wokou": {"mains": 12, "offhands": 4},
		"neutral": {"mains": 11, "offhands": 4},
	}
	for faction: String in expected.keys():
		var mains := {}
		var offhands := {}
		var combos := {}
		for index in 1024:
			var recipe: Dictionary = forge.random_recipe(17000 + index, faction)
			assert_eq(str(recipe["faction"]), faction)
			mains[str(recipe["weapon"])] = true
			for pair: Array in [
				["outfits", "outfit"], ["headgear", "headgear"], ["backgear", "backgear"],
			]:
				var item := _data_item(forge.data, str(pair[0]), str(recipe[pair[1]]))
				var item_faction := str(item.get("faction", "neutral"))
				assert_true(
					item_faction == "neutral" or item_faction == faction,
					"%s random recipe uses %s gear" % [faction, item_faction]
				)
			var main := _data_item(forge.data, "weapons", str(recipe["weapon"]))
			var main_faction := str(main.get("faction", "neutral"))
			assert_true(main_faction == "neutral" or main_faction == faction)
			var offhand := str(recipe["offhand"])
			if offhand != "none":
				var offhand_item := _data_item(forge.data, "weapons", offhand)
				var offhand_faction := str(offhand_item.get("faction", "neutral"))
				assert_true(offhand_faction == "neutral" or offhand_faction == faction)
				offhands[offhand] = true
				combos[forge.combo_family_for(str(recipe["weapon"]), offhand)] = true
		assert_eq(mains.size(), int(expected[faction]["mains"]), "%s main coverage" % faction)
		assert_eq(offhands.size(), int(expected[faction]["offhands"]), "%s offhand coverage" % faction)
		assert_eq(combos.size(), 3, "%s combo-family coverage" % faction)


func test_every_declared_combination_has_atlas_rows() -> void:
	var data := _load_data()
	if data.is_empty():
		return
	var body_rows: Dictionary = data["atlases"]["body"]["rows"]
	var outfit_rows: Dictionary = data["atlases"]["outfit"]["rows"]
	var head_rows: Dictionary = data["atlases"]["headgear"]["rows"]
	var back_rows: Dictionary = data["atlases"]["backgear"]["rows"]
	var weapon_rows: Dictionary = data["atlases"]["weapon"]["rows"]
	var offhand_rows: Dictionary = data["atlases"]["offhand"]["rows"]
	var allowed: Array = data["offhand_allowed"]
	var pairs: Dictionary = data["combo_pairs"]
	var failures: Array[String] = []
	var count := 0
	for faction: String in ["ming", "wokou"]:
		var outfits: Array = []
		var headgear: Array = []
		var backgear: Array = []
		var mains: Array = []
		var offhands: Array = []
		for item: Dictionary in data["outfits"]:
			if _faction_allowed(data, item, faction):
				outfits.append(item)
		for item: Dictionary in data["headgear"]:
			if _faction_allowed(data, item, faction):
				headgear.append(item)
		for item: Dictionary in data["backgear"]:
			if _faction_allowed(data, item, faction):
				backgear.append(item)
		for item: Dictionary in data["weapons"]:
			if str(item["slot"]) == "main" and _faction_allowed(data, item, faction):
				mains.append(item)
		for offhand_id: String in allowed:
			var offhand_item := _data_item(data, "weapons", offhand_id)
			if _faction_allowed(data, offhand_item, faction):
				offhands.append(offhand_item)
		for skin: Dictionary in data["skins"]:
			for outfit: Dictionary in outfits:
				for headgear_item: Dictionary in headgear:
					for backgear_item: Dictionary in backgear:
						for weapon: Dictionary in mains:
							var options: Array = ["none"]
							if str(weapon["grip"]) == "one_hand":
								for offhand_item: Dictionary in offhands:
									var pair_key := str(weapon["id"]) + "+" + str(offhand_item["id"])
									if pairs.has(pair_key):
										options.append(str(offhand_item["id"]))
							for offhand_value: String in options:
								var offhand := str(offhand_value)
								var variant := str(weapon["id"])
								var weapon_key := str(weapon["id"])
								if offhand != "none":
									variant = "combo_" + str(pairs[weapon_key + "+" + offhand])
									weapon_key += "+" + offhand
								count += 1
								if not body_rows.has(str(skin["id"]) + "|" + variant):
									failures.append("body " + variant)
								if not outfit_rows.has(str(outfit["id"]) + "|" + variant):
									failures.append("outfit " + variant)
								if not head_rows.has(str(headgear_item["id"]) + "|" + str(weapon["id"])):
									failures.append("headgear " + str(weapon["id"]))
								if not back_rows.has(str(backgear_item["id"]) + "|" + str(weapon["id"])):
									failures.append("backgear " + str(weapon["id"]))
								if not weapon_rows.has(weapon_key):
									failures.append("weapon " + weapon_key)
								if offhand != "none" and not offhand_rows.has(str(weapon["id"]) + "|" + offhand):
									failures.append("offhand " + str(weapon["id"]) + "|" + offhand)
								if failures.size() > 12:
									break
	assert_eq(count, int(data["combination_count"]))
	assert_eq(failures.size(), 0, "missing atlas rows: %s" % str(failures))
