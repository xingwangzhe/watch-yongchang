class_name RuntimeLoadout
extends RefCounted

const TEMPLATE_DATA_PATH := "res://data/character_templates.json"
const WEAPONS_DATA_PATH := "res://data/weapons.json"
const ENEMIES_DATA_PATH := "res://data/enemies.json"
const RULES_DATA_PATH := "res://data/runtime_loadout_rules.json"
const GameDataScript = preload("res://scripts/core/data_loader.gd")

const FACTIONS := ["ming", "wokou", "neutral"]
const TIERS := ["normal", "elite", "boss"]
const ROLES := ["infantry", "ranged", "cavalry"]
const KEY_RECIPE_FIELDS := [
	"faction", "skin", "outfit", "headgear", "backgear", "weapon",
	"offhand", "mount", "mount_motion", "pose_variant",
]
const KEY_VISUAL_FIELDS := [
	"palette", "tint", "emblem", "banner", "weapon_skin",
	"mount_skin", "mount_tint",
]

var templates: Dictionary = {}
var weapon_catalog: Dictionary = {}
var enemy_catalog: Dictionary = {}
var rules: Dictionary = {}

var _configured := false
var _by_id: Dictionary = {}
var _outfits: Dictionary = {}
var _headgear: Dictionary = {}
var _backgear: Dictionary = {}
var _mains_all: Dictionary = {}
var _mains_melee: Dictionary = {}
var _mains_ranged: Dictionary = {}
var _offhand_options: Dictionary = {}
var _mounts: Dictionary = {}
var _palettes: Array = []
var _emblems: Dictionary = {}
var _banners: Dictionary = {}
var _weapon_skins: Array = []


static func create_default() -> RuntimeLoadout:
	var loadout := RuntimeLoadout.new()
	if not loadout.load_defaults():
		return null
	return loadout


func load_defaults() -> bool:
	var template_data := GameDataScript.load_json(TEMPLATE_DATA_PATH)
	if template_data.is_empty():
		return false
	var weapon_data := GameDataScript.load_json(WEAPONS_DATA_PATH)
	var enemy_data := GameDataScript.load_json(ENEMIES_DATA_PATH)
	var rules_data := GameDataScript.load_json(RULES_DATA_PATH)
	return configure(template_data, weapon_data, enemy_data, rules_data)


func configure(
	template_data: Dictionary,
	weapon_data: Dictionary = {},
	enemy_data: Dictionary = {},
	rules_data: Dictionary = {}
) -> bool:
	_reset()
	if template_data.is_empty():
		push_error("RuntimeLoadout requires character template data")
		return false
	templates = template_data.duplicate(true)
	weapon_catalog = _unwrap_catalog(weapon_data, "weapons")
	enemy_catalog = _unwrap_catalog(enemy_data, "enemies")
	rules = _deep_merge(_fallback_rules(), rules_data)
	_index_items()
	_build_pools()
	_load_visual_pools()
	if not _catalog_ready():
		push_error("RuntimeLoadout catalog is missing required items")
		return false
	_configured = true
	return true


func is_configured() -> bool:
	return _configured


func generate(
	seed_value: int,
	faction: String,
	tier: String = "normal",
	role: String = "",
	map_salt: String = "",
	wave_salt: int = 0
) -> Dictionary:
	if not _configured:
		push_error("RuntimeLoadout.generate called before configure")
		return {}
	faction = faction.to_lower()
	tier = tier.to_lower()
	role = role.to_lower()
	if role == "auto":
		role = ""
	if faction not in FACTIONS:
		push_error("RuntimeLoadout unknown faction: %s" % faction)
		return {}
	if tier not in TIERS:
		push_error("RuntimeLoadout unknown tier: %s" % tier)
		return {}
	if not role.is_empty() and role not in ROLES:
		push_error("RuntimeLoadout unknown role: %s" % role)
		return {}
	if _mains_all.get(faction, []).is_empty():
		push_error("RuntimeLoadout faction has no legal main weapon: %s" % faction)
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(seed_value, faction, tier, role, map_salt, wave_salt)
	var actual_role := role
	if actual_role.is_empty():
		actual_role = _pick_role(faction, tier, rng)
	if actual_role == "cavalry" and _mount_choice_count(faction) <= 0:
		push_error("RuntimeLoadout faction has no legal mount: %s" % faction)
		return {}

	var attack_class := _pick_attack_class(faction, actual_role, tier, rng)
	var weapon_pool := _weapon_pool_for(faction, actual_role, attack_class)
	if weapon_pool.is_empty():
		push_error(
			"RuntimeLoadout has no weapon for faction=%s role=%s class=%s"
			% [faction, actual_role, attack_class]
		)
		return {}

	var weapon := _pick_gear(weapon_pool, faction, tier, rng)
	if weapon.is_empty():
		return {}
	var weapon_id := str(weapon.get("id", ""))
	var offhand_id := "none"
	var offhands: Array = _offhand_options.get(_pair_key(faction, weapon_id), [])
	var offhand_chance := float(_tier_config(tier).get("offhand_chance", 0.62))
	if str(weapon.get("grip", "")) == "one_hand" and not offhands.is_empty():
		if rng.randf() < offhand_chance:
			offhand_id = str(_pick_gear(offhands, faction, tier, rng).get("id", "none"))
	var pose_variant := _pose_variant_for(weapon, offhand_id)

	var selected_mount := {}
	var mount_motion := "none"
	var mount_pose_variant := "none"
	if actual_role == "cavalry":
		selected_mount = _pick_visual(_mounts.get(faction, []), tier, rng)
		if selected_mount.is_empty():
			return {}
		var motions := _string_array(selected_mount.get("motions", ["walk"]))
		if motions.is_empty():
			motions = ["walk"]
		mount_motion = str(motions[rng.randi_range(0, motions.size() - 1)])
		mount_pose_variant = "cavalry_%s_%s" % [pose_variant, mount_motion]

	var palette := _pick_visual(_palettes, tier, rng)
	var emblem := _pick_visual(_emblems.get(faction, []), tier, rng)
	var banner := _pick_visual(_banners.get(faction, []), tier, rng)
	var weapon_skin := _pick_visual(_weapon_skins, tier, rng)
	if palette.is_empty() or emblem.is_empty() or banner.is_empty() or weapon_skin.is_empty():
		push_error("RuntimeLoadout visual pool is incomplete")
		return {}

	var mount_id := str(selected_mount.get("id", "none"))
	var mount_skin := str(selected_mount.get("skin", mount_id))
	var mount_tint := str(selected_mount.get("tint", "#ffffff"))
	var recipe := {
		"faction": faction,
		"skin": _pick_uniform(_by_id["skins"].values(), rng).get("id", ""),
		"outfit": _pick_gear(_outfits[faction], faction, tier, rng).get("id", ""),
		"headgear": _pick_gear(_headgear[faction], faction, tier, rng).get("id", ""),
		"backgear": _pick_gear(_backgear[faction], faction, tier, rng).get("id", ""),
		"weapon": weapon_id,
		"offhand": offhand_id,
		"mount": mount_id,
		"mount_motion": mount_motion,
		"mount_pose_variant": mount_pose_variant,
		"pose_variant": pose_variant,
	}
	if str(recipe["skin"]).is_empty() or str(recipe["outfit"]).is_empty():
		return {}
	if str(recipe["headgear"]).is_empty() or str(recipe["backgear"]).is_empty():
		return {}

	var visual := {
		"palette": str(palette.get("id", "")),
		"tint": str(palette.get("tint", "#ffffff")),
		"emblem": str(emblem.get("id", "none")),
		"banner": str(banner.get("id", "none")),
		"weapon_skin": str(weapon_skin.get("id", "plain")),
		"mount_skin": mount_skin,
		"mount_tint": mount_tint,
	}
	var rarity := _pick_rarity(tier, rng)
	var action_id := ""
	var actions: Array = weapon.get("actions", [])
	if not actions.is_empty():
		var action: Dictionary = actions[rng.randi_range(0, actions.size() - 1)]
		action_id = str(action.get("id", ""))
	var gameplay_weapon := _gameplay_weapon_for(weapon)
	var tags := [
		"faction:%s" % faction,
		"tier:%s" % tier,
		"rarity:%s" % rarity,
		"role:%s" % actual_role,
		"attack_class:%s" % attack_class,
	]
	if actual_role == "cavalry":
		tags.append("mounted")

	var result := {
		"seed": seed_value,
		"faction": faction,
		"tier": tier,
		"rarity": rarity,
		"role": actual_role,
		"attack_class": attack_class,
		"salt": {"map": map_salt, "wave": wave_salt},
		"recipe": recipe,
		"visual": visual,
		"gameplay": {
			"weapon": gameplay_weapon,
			"attack_profile": str(weapon.get("attack_profile", "")),
			"action_id": action_id,
		},
		"requires_mount_atlas": actual_role == "cavalry",
		"tags": tags,
	}
	result["visual_key"] = visual_key(result)
	result["cache_bucket"] = cache_bucket(result)
	return result


func generate_for_enemy(
	enemy_id: String,
	seed_value: int,
	map_salt: String = "",
	wave_salt: int = 0,
	role_override: String = ""
) -> Dictionary:
	if not _configured:
		push_error("RuntimeLoadout.generate_for_enemy called before configure")
		return {}
	if not enemy_catalog.has(enemy_id):
		push_error("RuntimeLoadout unknown enemy: %s" % enemy_id)
		return {}
	var definition: Dictionary = enemy_catalog[enemy_id]
	var character_recipe: Dictionary = definition.get("character_recipe", {})
	var faction := str(character_recipe.get("faction", ""))
	if faction.is_empty():
		push_error("RuntimeLoadout enemy has no faction: %s" % enemy_id)
		return {}
	var behavior := str(definition.get("behavior", "chase"))
	var tier := "normal"
	if behavior == "elite":
		tier = "elite"
	elif behavior == "boss":
		tier = "boss"
	var role := role_override
	if role.is_empty():
		if behavior == "ranged":
			role = "ranged"
		elif behavior == "support":
			role = "infantry"
	var mixed_seed := seed_value ^ _stable_hash32("enemy:%s" % enemy_id)
	return generate(mixed_seed, faction, tier, role, map_salt, wave_salt)


func validation_errors(loadout: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if loadout.is_empty():
		errors.append("loadout is empty")
		return errors
	var recipe: Dictionary = loadout.get("recipe", {})
	if recipe.is_empty():
		errors.append("recipe is missing")
		return errors
	var expected := str(loadout.get("faction", recipe.get("faction", "")))
	errors.append_array(validate_recipe(recipe, expected))
	var role := str(loadout.get("role", ""))
	if role not in ROLES:
		errors.append("unknown role: %s" % role)
	var tier := str(loadout.get("tier", ""))
	if tier not in TIERS:
		errors.append("unknown tier: %s" % tier)
	var attack_class := str(loadout.get("attack_class", ""))
	if attack_class not in ["melee", "ranged"]:
		errors.append("unknown attack class: %s" % attack_class)
	var weapon := _lookup_item("weapons", str(recipe.get("weapon", "")))
	var expected_class := "ranged" if str(weapon.get("grip", "")) == "ranged" else "melee"
	if attack_class != expected_class:
		errors.append("attack class does not match weapon grip")
	var mount := str(recipe.get("mount", "none"))
	if role == "cavalry":
		if mount == "none":
			errors.append("cavalry loadout has no mount")
		if str(recipe.get("mount_motion", "none")) == "none":
			errors.append("cavalry loadout has no mount motion")
	elif mount != "none":
		errors.append("ground loadout cannot have a mount")
	var visual: Dictionary = loadout.get("visual", {})
	for field in ["palette", "tint", "emblem", "banner", "weapon_skin"]:
		if not visual.has(field):
			errors.append("visual field missing: %s" % field)
	var key := str(loadout.get("visual_key", ""))
	if key.is_empty() or key != visual_key(loadout):
		errors.append("visual key is missing or stale")
	var bucket := int(loadout.get("cache_bucket", -1))
	if bucket < 0 or bucket >= 64:
		errors.append("cache bucket is outside 0..63")
	return errors


func validate_recipe(recipe: Dictionary, expected_faction: String = "") -> Array[String]:
	var errors: Array[String] = []
	var faction := str(recipe.get("faction", ""))
	if faction not in FACTIONS:
		errors.append("unknown faction: %s" % faction)
	if not expected_faction.is_empty() and faction != expected_faction:
		errors.append("recipe faction does not match loadout faction")
	for pair: Array in [
		["outfits", "outfit"],
		["headgear", "headgear"],
		["backgear", "backgear"],
		["weapons", "weapon"],
	]:
		var item_id := str(recipe.get(str(pair[1]), ""))
		var item := _lookup_item(str(pair[0]), item_id)
		if item.is_empty():
			errors.append("unknown %s: %s" % [pair[1], item_id])
		elif not _faction_allows(item, faction):
			errors.append("%s mixes faction: %s" % [pair[1], item_id])
	var skin := _lookup_item("skins", str(recipe.get("skin", "")))
	if skin.is_empty():
		errors.append("unknown skin: %s" % str(recipe.get("skin", "")))
	var weapon := _lookup_item("weapons", str(recipe.get("weapon", "")))
	if not weapon.is_empty() and str(weapon.get("slot", "")) != "main":
		errors.append("weapon is not a main-slot item")
	var offhand_id := str(recipe.get("offhand", "none"))
	if offhand_id != "none":
		var offhand := _lookup_item("weapons", offhand_id)
		if offhand.is_empty():
			errors.append("unknown offhand: %s" % offhand_id)
		else:
			if str(weapon.get("grip", "")) != "one_hand":
				errors.append("offhand requires a one-handed main weapon")
			if not _faction_allows(offhand, faction):
				errors.append("offhand mixes faction: %s" % offhand_id)
			if offhand_id not in templates.get("offhand_allowed", []):
				errors.append("offhand is not allowed: %s" % offhand_id)
			var weapon_id := str(weapon.get("id", ""))
			if not _combo_pairs().has("%s+%s" % [weapon_id, offhand_id]):
				errors.append("offhand has no combo pose: %s" % offhand_id)
	var expected_pose := _pose_variant_for(weapon, offhand_id)
	if str(recipe.get("pose_variant", "")) != expected_pose:
		errors.append("pose variant does not match weapon loadout")
	var mount_id := str(recipe.get("mount", "none"))
	if mount_id != "none":
		if _mount_by_id(faction, mount_id).is_empty():
			errors.append("unknown or mixed-faction mount: %s" % mount_id)
		if str(recipe.get("mount_motion", "none")) == "none":
			errors.append("mounted recipe has no mount motion")
	return errors


func visual_key(loadout: Dictionary) -> String:
	var recipe: Dictionary = loadout.get("recipe", loadout)
	var visual: Dictionary = loadout.get("visual", {})
	var parts: Array[String] = ["runtime-loadout-v1"]
	for field in KEY_RECIPE_FIELDS:
		parts.append("r.%s=%s" % [field, str(recipe.get(field, ""))])
	for field in KEY_VISUAL_FIELDS:
		parts.append("v.%s=%s" % [field, str(visual.get(field, ""))])
	return "|".join(parts)


func cache_bucket(loadout: Dictionary, bucket_count: int = 64) -> int:
	return _stable_hash32(visual_key(loadout)) % maxi(1, bucket_count)


func gear_combination_count(faction: String) -> int:
	if faction not in FACTIONS or not _configured:
		return 0
	return (
		_by_id.get("skins", {}).size()
		* _outfits.get(faction, []).size()
		* _headgear.get(faction, []).size()
		* _backgear.get(faction, []).size()
		* _all_weapon_variants(faction).size()
	)


func recipe_combination_count(faction: String, role: String = "") -> int:
	if faction not in FACTIONS or not _configured:
		return 0
	if role == "auto":
		role = ""
	if not role.is_empty() and role not in ROLES:
		return 0
	var base: int = (
		_by_id.get("skins", {}).size()
		* _outfits.get(faction, []).size()
		* _headgear.get(faction, []).size()
		* _backgear.get(faction, []).size()
	)
	var variants := _variants_for_role(faction, role)
	if variants.is_empty():
		return 0
	var role_factor := 1
	if role == "cavalry":
		role_factor = _mount_choice_count(faction)
	elif role.is_empty():
		role_factor = 1 + _mount_choice_count(faction)
	return base * variants.size() * role_factor


func visual_combination_count(faction: String) -> int:
	if faction not in FACTIONS or not _configured:
		return 0
	return (
		_palettes.size()
		* _emblems.get(faction, []).size()
		* _banners.get(faction, []).size()
		* _weapon_skins.size()
	)


func combination_count(
	faction: String,
	role: String = "",
	include_visuals: bool = true
) -> int:
	var count := recipe_combination_count(faction, role)
	if include_visuals:
		count *= visual_combination_count(faction)
	return count


func total_combination_count(include_visuals: bool = true) -> int:
	var total := 0
	for faction in FACTIONS:
		total += combination_count(faction, "", include_visuals)
	return total


func enumerate_gear_loadouts(faction: String, limit: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if faction not in FACTIONS or not _configured:
		return result
	var skins: Array = _by_id.get("skins", {}).values()
	var variants := _all_weapon_variants(faction)
	for skin: Dictionary in skins:
		for outfit: Dictionary in _outfits.get(faction, []):
			for headgear: Dictionary in _headgear.get(faction, []):
				for backgear: Dictionary in _backgear.get(faction, []):
					for variant: Dictionary in variants:
						var weapon: Dictionary = variant["weapon"]
						result.append({
							"faction": faction,
							"skin": str(skin.get("id", "")),
							"outfit": str(outfit.get("id", "")),
							"headgear": str(headgear.get("id", "")),
							"backgear": str(backgear.get("id", "")),
							"weapon": str(weapon.get("id", "")),
							"offhand": str(variant["offhand"]),
							"mount": "none",
							"mount_motion": "none",
							"mount_pose_variant": "none",
							"pose_variant": str(variant["pose_variant"]),
						})
						if limit > 0 and result.size() >= limit:
							return result
	return result


func _reset() -> void:
	_configured = false
	templates.clear()
	weapon_catalog.clear()
	enemy_catalog.clear()
	rules.clear()
	_by_id.clear()
	_outfits.clear()
	_headgear.clear()
	_backgear.clear()
	_mains_all.clear()
	_mains_melee.clear()
	_mains_ranged.clear()
	_offhand_options.clear()
	_mounts.clear()
	_palettes.clear()
	_emblems.clear()
	_banners.clear()
	_weapon_skins.clear()


func _unwrap_catalog(source: Dictionary, key: String) -> Dictionary:
	if source.is_empty():
		return {}
	if source.get(key) is Dictionary:
		return (source[key] as Dictionary).duplicate(true)
	return source.duplicate(true)


func _index_items() -> void:
	for group in ["skins", "outfits", "headgear", "backgear", "weapons"]:
		var group_index := {}
		for entry: Variant in templates.get(group, []):
			if entry is Dictionary and not str(entry.get("id", "")).is_empty():
				group_index[str(entry["id"])] = entry
		_by_id[group] = group_index


func _build_pools() -> void:
	for faction in FACTIONS:
		_outfits[faction] = _filter_items(templates.get("outfits", []), faction)
		_headgear[faction] = _filter_items(templates.get("headgear", []), faction)
		_backgear[faction] = _filter_items(templates.get("backgear", []), faction)
		var all_mains: Array = []
		var melee: Array = []
		var ranged: Array = []
		for entry: Variant in templates.get("weapons", []):
			if not (entry is Dictionary):
				continue
			var weapon: Dictionary = entry
			if str(weapon.get("slot", "")) != "main":
				continue
			if not _faction_allows(weapon, faction):
				continue
			all_mains.append(weapon)
			if str(weapon.get("grip", "")) == "ranged":
				ranged.append(weapon)
			else:
				melee.append(weapon)
		_mains_all[faction] = all_mains
		_mains_melee[faction] = melee
		_mains_ranged[faction] = ranged
		for weapon: Dictionary in all_mains:
			_offhand_options[_pair_key(faction, str(weapon.get("id", "")))] = (
				_build_offhand_options(weapon, faction)
			)
		_mounts[faction] = _filter_visual_entries(
			(rules.get("mounts", {}) as Dictionary).get(faction, []),
			faction
		)


func _load_visual_pools() -> void:
	var visuals: Dictionary = rules.get("visuals", {})
	_palettes = _filter_visual_entries(visuals.get("palettes", []), "neutral")
	_weapon_skins = _filter_visual_entries(visuals.get("weapon_skins", []), "neutral")
	var emblem_pools: Dictionary = visuals.get("emblems", {})
	var banner_pools: Dictionary = visuals.get("banners", {})
	for faction in FACTIONS:
		_emblems[faction] = _filter_visual_entries(
			emblem_pools.get(faction, emblem_pools.get("neutral", [])),
			faction
		)
		_banners[faction] = _filter_visual_entries(
			banner_pools.get(faction, banner_pools.get("neutral", [])),
			faction
		)


func _catalog_ready() -> bool:
	if _by_id.get("skins", {}).is_empty():
		return false
	if _palettes.is_empty() or _weapon_skins.is_empty():
		return false
	for faction in FACTIONS:
		if _emblems.get(faction, []).is_empty() or _banners.get(faction, []).is_empty():
			return false
	return true


func _filter_items(raw: Variant, faction: String) -> Array:
	var filtered: Array = []
	if not (raw is Array):
		return filtered
	for entry: Variant in raw:
		if not (entry is Dictionary):
			continue
		if _faction_allows(entry, faction):
			filtered.append(entry)
	return filtered


func _filter_visual_entries(raw: Variant, faction: String) -> Array:
	var filtered: Array = []
	if not (raw is Array):
		return filtered
	for entry: Variant in raw:
		var item := _coerce_visual_entry(entry)
		if item.is_empty():
			continue
		if _faction_allows(item, faction):
			filtered.append(item)
	return filtered


func _coerce_visual_entry(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		if str(raw.get("id", "")).is_empty():
			return {}
		return raw
	if raw is String and not str(raw).is_empty():
		return {"id": str(raw), "rarity": "common", "faction": "neutral"}
	return {}


func _faction_allows(entry: Dictionary, faction: String) -> bool:
	var item_faction := str(entry.get("faction", "neutral"))
	if faction == "neutral":
		return item_faction == "neutral"
	return item_faction == "neutral" or item_faction == faction


func _build_offhand_options(main_weapon: Dictionary, faction: String) -> Array:
	var options: Array = []
	if str(main_weapon.get("grip", "")) != "one_hand":
		return options
	var main_id := str(main_weapon.get("id", ""))
	for raw_id: Variant in templates.get("offhand_allowed", []):
		var offhand_id := str(raw_id)
		var offhand := _lookup_item("weapons", offhand_id)
		if offhand.is_empty() or not _faction_allows(offhand, faction):
			continue
		if str(offhand.get("grip", "")) not in ["one_hand", "offhand"]:
			continue
		if not _combo_pairs().has("%s+%s" % [main_id, offhand_id]):
			continue
		options.append(offhand)
	return options


func _pick_role(faction: String, tier: String, rng: RandomNumberGenerator) -> String:
	var role_weights: Dictionary = _tier_config(tier).get("role_weights", {})
	var candidates: Array[String] = []
	var weights: Array[float] = []
	for role in ROLES:
		if _role_available(faction, role):
			candidates.append(role)
			weights.append(float(role_weights.get(role, 1.0)))
	if candidates.is_empty():
		return "infantry"
	return _weighted_string_pick(candidates, weights, rng)


func _role_available(faction: String, role: String) -> bool:
	if role == "infantry":
		return not _mains_melee.get(faction, []).is_empty()
	if role == "ranged":
		return not _mains_ranged.get(faction, []).is_empty()
	if role == "cavalry":
		return (
			not _mains_all.get(faction, []).is_empty()
			and _mount_choice_count(faction) > 0
		)
	return false


func _pick_attack_class(
	faction: String,
	role: String,
	tier: String,
	rng: RandomNumberGenerator
) -> String:
	if role == "infantry":
		return "melee"
	if role == "ranged":
		return "ranged"
	var melee_available: bool = not _mains_melee.get(faction, []).is_empty()
	var ranged_available: bool = not _mains_ranged.get(faction, []).is_empty()
	if not melee_available:
		return "ranged"
	if not ranged_available:
		return "melee"
	var config := _tier_config(tier)
	var weights := [
		float(config.get("cavalry_melee_weight", 68.0)),
		float(config.get("cavalry_ranged_weight", 32.0)),
	]
	return _weighted_string_pick(["melee", "ranged"], weights, rng)


func _weapon_pool_for(faction: String, role: String, attack_class: String) -> Array:
	if role == "infantry" or (role == "" and attack_class == "melee"):
		return _mains_melee.get(faction, [])
	if role == "ranged" or (role == "" and attack_class == "ranged"):
		return _mains_ranged.get(faction, [])
	if attack_class == "ranged":
		return _mains_ranged.get(faction, [])
	return _mains_melee.get(faction, [])


func _pick_gear(
	items: Array,
	faction: String,
	tier: String,
	rng: RandomNumberGenerator
) -> Dictionary:
	if items.is_empty():
		return {}
	var exclusive_multiplier := float(
		_tier_config(tier).get("exclusive_multiplier", 1.0)
	)
	var total := 0.0
	for raw: Variant in items:
		if raw is Dictionary:
			total += _gear_weight(raw, faction, exclusive_multiplier)
	if total <= 0.0:
		return items[0] if items[0] is Dictionary else {}
	var roll := rng.randf_range(0.0, total)
	for raw: Variant in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw
		roll -= _gear_weight(item, faction, exclusive_multiplier)
		if roll <= 0.0:
			return item
	return items[-1] if items[-1] is Dictionary else {}


func _gear_weight(item: Dictionary, faction: String, exclusive_multiplier: float) -> float:
	var weight := 1.0
	if bool(item.get("exclusive", false)):
		weight *= exclusive_multiplier
	if faction != "neutral" and str(item.get("faction", "neutral")) == faction:
		weight *= 1.08
	return maxf(weight, 0.0001)


func _pick_visual(
	items: Array,
	tier: String,
	rng: RandomNumberGenerator
) -> Dictionary:
	if items.is_empty():
		return {}
	var rarity_weights: Dictionary = _tier_config(tier).get(
		"visual_rarity_weights",
		{}
	)
	var total := 0.0
	for raw: Variant in items:
		if raw is Dictionary:
			total += _visual_weight(raw, rarity_weights)
	if total <= 0.0:
		return items[0] if items[0] is Dictionary else {}
	var roll := rng.randf_range(0.0, total)
	for raw: Variant in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw
		roll -= _visual_weight(item, rarity_weights)
		if roll <= 0.0:
			return item
	return items[-1] if items[-1] is Dictionary else {}


func _visual_weight(item: Dictionary, rarity_weights: Dictionary) -> float:
	var rarity := str(item.get("rarity", "common"))
	return maxf(float(rarity_weights.get(rarity, 1.0)), 0.0001)


func _pick_uniform(items: Array, rng: RandomNumberGenerator) -> Dictionary:
	if items.is_empty():
		return {}
	return items[rng.randi_range(0, items.size() - 1)] as Dictionary


func _pick_rarity(tier: String, rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = _tier_config(tier).get("rarity_weights", {})
	var names: Array[String] = []
	var values: Array[float] = []
	for rarity in ["common", "veteran", "elite", "boss"]:
		var weight := float(weights.get(rarity, 0.0))
		if weight > 0.0:
			names.append(rarity)
			values.append(weight)
	if names.is_empty():
		return "common"
	return _weighted_string_pick(names, values, rng)


func _weighted_string_pick(
	names: Array,
	weights: Array,
	rng: RandomNumberGenerator
) -> String:
	var total := 0.0
	for weight: Variant in weights:
		total += maxf(float(weight), 0.0)
	if total <= 0.0:
		return str(names[0])
	var roll := rng.randf_range(0.0, total)
	for index in names.size():
		roll -= maxf(float(weights[index]), 0.0)
		if roll <= 0.0:
			return str(names[index])
	return str(names[-1])


func _mount_choice_count(faction: String) -> int:
	var count := 0
	for raw: Variant in _mounts.get(faction, []):
		if not (raw is Dictionary):
			continue
		var motions := _string_array((raw as Dictionary).get("motions", ["walk"]))
		count += maxi(1, motions.size())
	return count


func _all_weapon_variants(faction: String) -> Array[Dictionary]:
	var variants: Array[Dictionary] = []
	for weapon: Dictionary in _mains_all.get(faction, []):
		variants.append({
			"weapon": weapon,
			"offhand": "none",
			"pose_variant": _pose_variant_for(weapon, "none"),
			"attack_class": (
				"ranged" if str(weapon.get("grip", "")) == "ranged" else "melee"
			),
		})
		if str(weapon.get("grip", "")) != "one_hand":
			continue
		var options: Array = _offhand_options.get(
			_pair_key(faction, str(weapon.get("id", ""))),
			[]
		)
		for offhand: Dictionary in options:
			var offhand_id := str(offhand.get("id", "none"))
			variants.append({
				"weapon": weapon,
				"offhand": offhand_id,
				"pose_variant": _pose_variant_for(weapon, offhand_id),
				"attack_class": (
					"ranged" if str(weapon.get("grip", "")) == "ranged" else "melee"
				),
			})
	return variants


func _variants_for_role(faction: String, role: String) -> Array[Dictionary]:
	var variants: Array[Dictionary] = []
	for variant: Dictionary in _all_weapon_variants(faction):
		if role == "infantry" and str(variant["attack_class"]) != "melee":
			continue
		if role == "ranged" and str(variant["attack_class"]) != "ranged":
			continue
		variants.append(variant)
	return variants


func _pose_variant_for(weapon: Dictionary, offhand_id: String) -> String:
	var weapon_id := str(weapon.get("id", ""))
	if weapon_id.is_empty():
		return ""
	if offhand_id == "none":
		return weapon_id
	var family := str(_combo_pairs().get("%s+%s" % [weapon_id, offhand_id], ""))
	if family.is_empty():
		return weapon_id
	return "combo_%s" % family


func _combo_pairs() -> Dictionary:
	var pairs: Variant = templates.get("combo_pairs", {})
	return pairs if pairs is Dictionary else {}


func _lookup_item(group: String, item_id: String) -> Dictionary:
	var group_index: Dictionary = _by_id.get(group, {})
	var item: Variant = group_index.get(item_id, {})
	return item if item is Dictionary else {}


func _mount_by_id(faction: String, mount_id: String) -> Dictionary:
	for raw: Variant in _mounts.get(faction, []):
		if raw is Dictionary and str(raw.get("id", "")) == mount_id:
			return raw
	return {}


func _gameplay_weapon_for(weapon: Dictionary) -> String:
	var weapon_id := str(weapon.get("id", ""))
	var mapping: Dictionary = rules.get("weapon_gameplay_map", {})
	var mapped := str(mapping.get(weapon_id, ""))
	if mapped.is_empty() or weapon_catalog.is_empty():
		return mapped
	return mapped if weapon_catalog.has(mapped) else ""


func _tier_config(tier: String) -> Dictionary:
	var tiers: Dictionary = rules.get("tiers", {})
	var config: Variant = tiers.get(tier, {})
	return config if config is Dictionary else {}


func _pair_key(faction: String, weapon_id: String) -> String:
	return "%s|%s" % [faction, weapon_id]


func _string_array(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (raw is Array):
		return result
	for value: Variant in raw:
		if not str(value).is_empty():
			result.append(str(value))
	return result


func _mix_seed(
	seed_value: int,
	faction: String,
	tier: String,
	role: String,
	map_salt: String,
	wave_salt: int
) -> int:
	var text := "%d|%s|%s|%s|%s|%d" % [
		seed_value, faction, tier, role, map_salt, wave_salt,
	]
	var mixed := _stable_hash32(text)
	return mixed if mixed != 0 else 0x9E3779B9


func _stable_hash32(text: String) -> int:
	var hash := 2166136261
	for byte in text.to_utf8_buffer():
		hash = hash ^ int(byte)
		hash = (hash * 16777619) & 0xFFFFFFFF
	return hash


func _deep_merge(base: Dictionary, override: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	for key: Variant in override.keys():
		var value: Variant = override[key]
		if merged.get(key) is Dictionary and value is Dictionary:
			merged[key] = _deep_merge(merged[key] as Dictionary, value as Dictionary)
		else:
			merged[key] = value
	return merged


func _fallback_rules() -> Dictionary:
	return {
		"version": 1,
		"weapon_gameplay_map": {},
		"tiers": {
			"normal": {
				"exclusive_multiplier": 0.32,
				"offhand_chance": 0.58,
				"role_weights": {"infantry": 55.0, "ranged": 30.0, "cavalry": 15.0},
				"cavalry_melee_weight": 68.0,
				"cavalry_ranged_weight": 32.0,
				"rarity_weights": {
					"common": 72.0, "veteran": 24.0, "elite": 4.0, "boss": 0.01,
				},
				"visual_rarity_weights": {
					"common": 78.0, "veteran": 19.0, "elite": 2.9, "boss": 0.1,
				},
			},
			"elite": {
				"exclusive_multiplier": 1.55,
				"offhand_chance": 0.72,
				"role_weights": {"infantry": 35.0, "ranged": 30.0, "cavalry": 35.0},
				"cavalry_melee_weight": 62.0,
				"cavalry_ranged_weight": 38.0,
				"rarity_weights": {
					"common": 0.0, "veteran": 48.0, "elite": 48.0, "boss": 4.0,
				},
				"visual_rarity_weights": {
					"common": 18.0, "veteran": 48.0, "elite": 29.0, "boss": 5.0,
				},
			},
			"boss": {
				"exclusive_multiplier": 2.65,
				"offhand_chance": 0.86,
				"role_weights": {"infantry": 22.0, "ranged": 28.0, "cavalry": 50.0},
				"cavalry_melee_weight": 58.0,
				"cavalry_ranged_weight": 42.0,
				"rarity_weights": {
					"common": 0.0, "veteran": 0.0, "elite": 60.0, "boss": 40.0,
				},
				"visual_rarity_weights": {
					"common": 3.0, "veteran": 16.0, "elite": 50.0, "boss": 31.0,
				},
			},
		},
		"mounts": {
			"ming": [_fallback_mount("ming_fallback_horse", "#8b4f33", "common")],
			"wokou": [_fallback_mount("wokou_fallback_horse", "#3e3a35", "common")],
			"neutral": [_fallback_mount("neutral_fallback_horse", "#786b55", "common")],
		},
		"visuals": {
			"palettes": [
				{"id": "field", "rarity": "common", "tint": "#b9af96"},
			],
			"emblems": {
				"ming": [_fallback_visual("none")],
				"wokou": [_fallback_visual("none")],
				"neutral": [_fallback_visual("none")],
			},
			"banners": {
				"ming": [_fallback_visual("none")],
				"wokou": [_fallback_visual("none")],
				"neutral": [_fallback_visual("none")],
			},
			"weapon_skins": [_fallback_visual("plain")],
		},
	}


func _fallback_mount(mount_id: String, tint: String, rarity: String) -> Dictionary:
	return {
		"id": mount_id,
		"rarity": rarity,
		"tint": tint,
		"motions": ["walk", "trot"],
	}


func _fallback_visual(visual_id: String) -> Dictionary:
	return {"id": visual_id, "rarity": "common", "faction": "neutral"}
