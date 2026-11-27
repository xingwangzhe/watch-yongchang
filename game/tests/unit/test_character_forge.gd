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
	assert_false(data.has("atlases"), "character recipes no longer reference composited sprite layers")
	assert_false(data.has("layer_order"), "runtime must not assemble character body layers")
	assert_false(data.has("pose_variants"), "attack poses come from complete-character frames")
	assert_eq((data["weapons"] as Array).size(), 19)
	assert_eq((data["offhand_allowed"] as Array).size(), 7)
	assert_eq((data["combo_families"] as Array).size(), 3)
	assert_eq((data["combo_pairs"] as Dictionary).size(), 42)
	assert_eq(int(data["loadout_count"]), 59)
	assert_eq(int(data["faction_loadout_counts"]["ming"]), 58)
	assert_eq(int(data["faction_loadout_counts"]["wokou"]), 24)
	assert_eq(int(data["faction_combination_counts"]["ming"]), 59392)
	assert_eq(int(data["faction_combination_counts"]["wokou"]), 15360)
	assert_eq(int(data["combination_count"]), 74752)
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


func test_runtime_rejects_ming_wokou_mixes() -> void:
	var forge := ForgeScript.new()
	add_child_autofree(forge)
	if not forge.load_data():
		fail_test("character forge data must load")
		return
	var data: Dictionary = forge.data
	forge.set_recipe(data["recipes"]["hero"])
	var weapon_before := forge.current_weapon_id()
	var recipe_before := forge.recipe.duplicate(true)
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
	assert_eq(forge.recipe, recipe_before)
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
	assert_eq(forge.current_weapon_id(), "wokou_dao")


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
