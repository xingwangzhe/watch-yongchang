extends GutTest

const RuntimeLoadoutScript = preload("res://scripts/character/runtime_loadout.gd")
const TEMPLATE_DATA_PATH := "res://data/character_templates.json"

var _loadout: RuntimeLoadout
var _templates: Dictionary = {}


func before_each() -> void:
	_loadout = RuntimeLoadoutScript.new()
	assert_true(_loadout.load_defaults(), "runtime loadout data must load")
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(TEMPLATE_DATA_PATH)
	)
	assert_not_null(parsed, "character template data must parse")
	_templates = parsed if parsed is Dictionary else {}


func test_same_seed_and_salt_reproduce_full_loadout() -> void:
	var first := _loadout.generate(
		24680, "ming", "elite", "cavalry", "yongchang", 7
	)
	var second := _loadout.generate(
		24680, "ming", "elite", "cavalry", "yongchang", 7
	)
	assert_false(first.is_empty())
	assert_eq(first, second, "same seed and salts must reproduce byte-for-byte")
	assert_eq(first["visual_key"], second["visual_key"])
	assert_eq(_loadout.validation_errors(first).size(), 0)
	assert_true(first["recipe"].has("mount"))
	assert_true(first["recipe"].has("mount_motion"))
	assert_true(first["recipe"].has("pose_variant"))
	for field in ["palette", "tint", "emblem", "banner", "weapon_skin"]:
		assert_true(first["visual"].has(field), "visual needs %s" % field)
	var wave_keys := {}
	for wave in range(12):
		var variant := _loadout.generate(
			24680, "ming", "elite", "cavalry", "yongchang", wave
		)
		wave_keys[str(variant["visual_key"])] = true
	assert_gt(wave_keys.size(), 1, "wave salt must alter reproducible rolls")


func test_thousand_generated_loadouts_stay_faction_and_offhand_legal() -> void:
	var roles := ["", "infantry", "ranged", "cavalry"]
	var tiers := ["normal", "elite", "boss"]
	for index in 1000:
		var faction := "ming" if index % 2 == 0 else "wokou"
		var tier: String = tiers[index % tiers.size()]
		var role: String = roles[index % roles.size()]
		var result := _loadout.generate(
			50000 + index,
			faction,
			tier,
			role,
			"map_%d" % (index % 5),
			index
		)
		assert_false(result.is_empty(), "iteration %d must produce a loadout" % index)
		if result.is_empty():
			continue
		var errors := _loadout.validation_errors(result)
		assert_eq(errors.size(), 0, "iteration %d errors: %s" % [index, str(errors)])
		_assert_recipe_faction_legal(result)
		_assert_offhand_legal(result)
		assert_eq(str(result["faction"]), faction)
		assert_eq(str(result["tier"]), tier)
		if role.is_empty():
			assert_true(str(result["role"]) in ["infantry", "ranged", "cavalry"])
		else:
			assert_eq(str(result["role"]), role)
		if str(result["role"]) == "cavalry":
			assert_ne(str(result["recipe"]["mount"]), "none")
			assert_ne(str(result["recipe"]["mount_motion"]), "none")
		else:
			assert_eq(str(result["recipe"]["mount"]), "none")


func test_runtime_samples_cover_weapons_roles_mounts_and_visuals() -> void:
	var keys := {}
	var weapons := {}
	var roles := {}
	var attack_classes := {}
	var mounts := {}
	var palettes := {}
	var weapon_skins := {}
	var forced_roles := ["", "cavalry", "ranged", "infantry"]
	var tiers := ["normal", "elite", "boss"]
	for index in 1000:
		var faction := "ming" if index % 2 == 0 else "wokou"
		var role: String = forced_roles[index % forced_roles.size()]
		var result := _loadout.generate(
			90000 + index,
			faction,
			tiers[index % tiers.size()],
			role,
			"coverage",
			int(index / 9)
		)
		assert_false(result.is_empty())
		if result.is_empty():
			continue
		keys[str(result["visual_key"])] = true
		weapons[str(result["recipe"]["weapon"])] = true
		roles[str(result["role"])] = true
		attack_classes[str(result["attack_class"])] = true
		mounts[str(result["recipe"]["mount"])] = true
		palettes[str(result["visual"]["palette"])] = true
		weapon_skins[str(result["visual"]["weapon_skin"])] = true
	assert_gt(keys.size(), 900, "1000 samples must not collapse into dead presets")
	assert_gt(weapons.size(), 12, "runtime output must cover the legal weapon pool")
	assert_true(roles.has("infantry"))
	assert_true(roles.has("ranged"))
	assert_true(roles.has("cavalry"))
	assert_true(attack_classes.has("melee"))
	assert_true(attack_classes.has("ranged"))
	assert_gt(mounts.size(), 7, "mounted samples need varied horse appearance")
	assert_gt(palettes.size(), 4)
	assert_gt(weapon_skins.size(), 4)


func test_elite_and_boss_keep_tier_labels_and_raise_exclusive_gear() -> void:
	var normal_exclusive := 0
	var boss_exclusive := 0
	var allowed_rarities := {
		"elite": ["veteran", "elite", "boss"],
		"boss": ["elite", "boss"],
	}
	for index in 200:
		var elite := _loadout.generate(
			120000 + index, "wokou", "elite", "", "tier", index
		)
		var boss := _loadout.generate(
			120000 + index, "wokou", "boss", "", "tier", index
		)
		var normal := _loadout.generate(
			120000 + index, "wokou", "normal", "", "tier", index
		)
		assert_false(elite.is_empty())
		assert_false(boss.is_empty())
		assert_false(normal.is_empty())
		if elite.is_empty() or boss.is_empty() or normal.is_empty():
			continue
		assert_eq(str(elite["tier"]), "elite")
		assert_eq(str(boss["tier"]), "boss")
		assert_true((elite["tags"] as Array).has("tier:elite"))
		assert_true((boss["tags"] as Array).has("tier:boss"))
		assert_true(str(elite["rarity"]) in allowed_rarities["elite"])
		assert_true(str(boss["rarity"]) in allowed_rarities["boss"])
		assert_eq(_loadout.validation_errors(elite).size(), 0)
		assert_eq(_loadout.validation_errors(boss).size(), 0)
		normal_exclusive += _exclusive_gear_count(normal)
		boss_exclusive += _exclusive_gear_count(boss)
	assert_gt(
		boss_exclusive,
		normal_exclusive,
		"boss weighting must materially raise exclusive gear without illegal mixes"
	)


func test_visual_key_and_cache_bucket_are_canonical() -> void:
	var result := _loadout.generate(
		314159, "ming", "boss", "cavalry", "keys", 42
	)
	assert_false(result.is_empty())
	if result.is_empty():
		return
	var key := _loadout.visual_key(result)
	assert_eq(key, str(result["visual_key"]))
	var clone := {
		"recipe": (result["recipe"] as Dictionary).duplicate(true),
		"visual": (result["visual"] as Dictionary).duplicate(true),
	}
	assert_eq(_loadout.visual_key(clone), key)
	assert_eq(_loadout.cache_bucket(clone), int(result["cache_bucket"]))
	var bucket := _loadout.cache_bucket(result, 16)
	assert_true(bucket >= 0)
	assert_lt(bucket, 16)
	var changed: Dictionary = clone.duplicate(true)
	var changed_visual: Dictionary = changed["visual"]
	changed_visual["weapon_skin"] = "different_skin"
	assert_ne(_loadout.visual_key(changed), key)
	var reordered_visual := {}
	for field in ["mount_tint", "mount_skin", "weapon_skin", "banner", "emblem", "tint", "palette"]:
		reordered_visual[field] = result["visual"][field]
	var reordered_recipe := {}
	for field in [
		"pose_variant", "mount_motion", "mount", "offhand", "weapon",
		"backgear", "headgear", "outfit", "skin", "faction",
	]:
		reordered_recipe[field] = result["recipe"][field]
	var reordered := {"recipe": reordered_recipe, "visual": reordered_visual}
	assert_eq(_loadout.visual_key(reordered), key, "key must not depend on dict order")


func test_combination_counts_match_character_forge_and_include_visuals() -> void:
	assert_eq(_loadout.gear_combination_count("ming"), 59392)
	assert_eq(_loadout.gear_combination_count("wokou"), 15360)
	assert_eq(_loadout.gear_combination_count("neutral"), 368)
	assert_eq(_loadout.gear_combination_count("ming") + _loadout.gear_combination_count("wokou"), 74752)
	assert_eq(_loadout.recipe_combination_count("ming"), 772096)
	assert_eq(_loadout.recipe_combination_count("wokou"), 199680)
	assert_eq(_loadout.recipe_combination_count("neutral"), 2576)
	assert_eq(_loadout.combination_count("ming"), 555909120)
	assert_eq(_loadout.combination_count("wokou"), 143769600)
	assert_eq(_loadout.combination_count("neutral"), 1112832)
	assert_eq(_loadout.total_combination_count(), 700791552)
	assert_gt(
		_loadout.combination_count("ming"),
		_loadout.gear_combination_count("ming"),
		"mounts and visuals must expand beyond the static forge count"
	)
	var sample := _loadout.enumerate_gear_loadouts("ming", 257)
	assert_eq(sample.size(), 257)
	var unique := {}
	for recipe: Dictionary in sample:
		var identity := "%s|%s|%s|%s|%s|%s" % [
			recipe["skin"],
			recipe["outfit"],
			recipe["headgear"],
			recipe["backgear"],
			recipe["weapon"],
			recipe["offhand"],
		]
		unique[identity] = true
		assert_eq(
			_loadout.validate_recipe(recipe, "ming").size(),
			0,
			"enumerated recipe must be legal: %s" % str(recipe)
		)
	assert_eq(unique.size(), sample.size(), "enumeration must not emit duplicates")


func test_minimal_injected_catalog_works_without_data_loader() -> void:
	var injected := RuntimeLoadoutScript.new()
	assert_true(injected.configure(_minimal_templates()))
	for index in 120:
		var result := injected.generate(
			index, "ming", "elite", "infantry", "injected", index
		)
		assert_false(result.is_empty())
		if result.is_empty():
			continue
		assert_eq(str(result["faction"]), "ming")
		assert_eq(str(result["attack_class"]), "melee")
		assert_eq(injected.validation_errors(result).size(), 0)
	var ranged := injected.generate(9, "ming", "normal", "ranged")
	assert_false(ranged.is_empty())
	if not ranged.is_empty():
		assert_eq(str(ranged["attack_class"]), "ranged")
		assert_eq(str(ranged["recipe"]["weapon"]), "ming_bow")
	assert_eq(injected.gear_combination_count("ming"), 3)


func test_enemy_catalog_drives_elite_boss_and_ranged_roles() -> void:
	var gunner := _loadout.generate_for_enemy("gun", 1234, "enemy")
	var elite := _loadout.generate_for_enemy("general", 1234, "enemy")
	var boss := _loadout.generate_for_enemy("daimyo", 1234, "enemy")
	assert_false(gunner.is_empty())
	assert_false(elite.is_empty())
	assert_false(boss.is_empty())
	if gunner.is_empty() or elite.is_empty() or boss.is_empty():
		return
	assert_eq(str(gunner["tier"]), "normal")
	assert_eq(str(gunner["role"]), "ranged")
	assert_eq(str(gunner["attack_class"]), "ranged")
	assert_eq(str(elite["tier"]), "elite")
	assert_eq(str(boss["tier"]), "boss")
	for result: Dictionary in [gunner, elite, boss]:
		assert_eq(_loadout.validation_errors(result).size(), 0)
	assert_eq(
		_loadout.generate_for_enemy("gun", 1234, "enemy"),
		gunner,
		"enemy profile derivation must be deterministic"
	)


func _assert_recipe_faction_legal(loadout: Dictionary) -> void:
	var recipe: Dictionary = loadout["recipe"]
	var declared := str(loadout["faction"])
	for pair: Array in [
		["outfits", "outfit"],
		["headgear", "headgear"],
		["backgear", "backgear"],
		["weapons", "weapon"],
	]:
		var item := _template_item(str(pair[0]), str(recipe[pair[1]]))
		assert_false(item.is_empty(), "missing template item %s" % recipe[pair[1]])
		var faction := str(item.get("faction", "neutral"))
		assert_true(
			faction == "neutral" or faction == declared,
			"recipe uses %s item %s" % [faction, recipe[pair[1]]]
		)
	var offhand := str(recipe.get("offhand", "none"))
	if offhand != "none":
		var offhand_item := _template_item("weapons", offhand)
		assert_false(offhand_item.is_empty())
		var offhand_faction := str(offhand_item.get("faction", "neutral"))
		assert_true(offhand_faction == "neutral" or offhand_faction == declared)


func _assert_offhand_legal(loadout: Dictionary) -> void:
	var recipe: Dictionary = loadout["recipe"]
	var offhand := str(recipe.get("offhand", "none"))
	if offhand == "none":
		return
	var main_id := str(recipe["weapon"])
	var allowed: Array = _templates.get("offhand_allowed", [])
	var pairs: Dictionary = _templates.get("combo_pairs", {})
	assert_true(offhand in allowed, "offhand must be in offhand_allowed")
	assert_true(
		pairs.has("%s+%s" % [main_id, offhand]),
		"offhand needs an authored combo pose"
	)


func _exclusive_gear_count(loadout: Dictionary) -> int:
	var recipe: Dictionary = loadout["recipe"]
	var count := 0
	for pair: Array in [
		["outfits", "outfit"],
		["headgear", "headgear"],
		["backgear", "backgear"],
		["weapons", "weapon"],
	]:
		if bool(_template_item(str(pair[0]), str(recipe[pair[1]])).get("exclusive", false)):
			count += 1
	var offhand := str(recipe.get("offhand", "none"))
	if offhand != "none":
		if bool(_template_item("weapons", offhand).get("exclusive", false)):
			count += 1
	return count


func _template_item(group: String, item_id: String) -> Dictionary:
	for entry: Variant in _templates.get(group, []):
		if entry is Dictionary and str(entry.get("id", "")) == item_id:
			return entry
	return {}


func _minimal_templates() -> Dictionary:
	return {
		"skins": [{"id": "skin_a"}],
		"outfits": [
			{"id": "ming_coat", "faction": "ming"},
			{"id": "wokou_coat", "faction": "wokou"},
		],
		"headgear": [
			{"id": "ming_hat", "faction": "ming"},
			{"id": "wokou_hat", "faction": "wokou"},
		],
		"backgear": [
			{"id": "none", "faction": "neutral"},
			{"id": "wokou_cloak", "faction": "wokou"},
		],
		"weapons": [
			{
				"id": "ming_blade",
				"faction": "ming",
				"slot": "main",
				"grip": "one_hand",
				"attack_profile": "saber_diagonal",
				"actions": [{"id": "attack_1"}],
			},
			{
				"id": "ming_guard",
				"faction": "ming",
				"slot": "offhand",
				"grip": "offhand",
			},
			{
				"id": "ming_bow",
				"faction": "ming",
				"slot": "main",
				"grip": "ranged",
				"attack_profile": "bow",
				"actions": [{"id": "attack_1"}],
			},
			{
				"id": "wokou_blade",
				"faction": "wokou",
				"slot": "main",
				"grip": "two_hand",
				"attack_profile": "saber_diagonal",
				"actions": [{"id": "attack_1"}],
			},
		],
		"offhand_allowed": ["ming_guard"],
		"combo_pairs": {"ming_blade+ming_guard": "shield"},
		"recipes": {},
	}
