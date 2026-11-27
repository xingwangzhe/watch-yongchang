class_name CharacterForge
extends Node2D

## Recipe validation and random legal equipment selection only.
## Character appearance is rendered from complete sprite-sheet frames.

const DATA_PATH := "res://data/character_templates.json"
const FACTION_IDS := ["ming", "wokou", "neutral"]

signal recipe_changed(recipe: Dictionary)

var data: Dictionary = {}
var recipe: Dictionary = {}


func set_recipe(candidate: Dictionary) -> void:
	if data.is_empty() and not load_data():
		return
	if not recipe_faction_valid(candidate):
		return
	recipe = candidate.duplicate(true)
	if not recipe.has("faction"):
		recipe["faction"] = gear_faction(recipe)
	var weapon := _find_item("weapons", str(recipe.get("weapon", "")))
	var offhand := _find_item("weapons", str(recipe.get("offhand", "none")))
	if not _offhand_allowed(weapon, offhand):
		recipe["offhand"] = "none"
	recipe_changed.emit(recipe.duplicate(true))


func current_weapon_id() -> String:
	return str(recipe.get("weapon", ""))


func current_offhand_id() -> String:
	return str(recipe.get("offhand", "none"))


func current_faction() -> String:
	return str(recipe.get("faction", "neutral"))


func current_pose_variant() -> String:
	var main_id := current_weapon_id()
	if current_offhand_id() == "none":
		return main_id
	var family := combo_family_for(main_id, current_offhand_id())
	return "combo_" + (family if not family.is_empty() else "mixed")


func combo_family_for(main_id: String, offhand_id: String) -> String:
	if offhand_id == "none" or data.is_empty():
		return ""
	return str((data.get("combo_pairs", {}) as Dictionary).get(main_id + "+" + offhand_id, ""))


func load_data(path: String = DATA_PATH) -> bool:
	if not FileAccess.file_exists(path):
		push_error("character forge data missing: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("character forge data is not valid JSON: %s" % path)
		return false
	data = parsed
	return true


func random_recipe(seed: int, faction: String = "ming") -> Dictionary:
	if data.is_empty() and not load_data():
		return {}
	if faction not in FACTION_IDS:
		push_error("unknown character faction: %s" % faction)
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var skins := _faction_candidates("skins", faction)
	var outfits := _faction_candidates("outfits", faction)
	var headgear := _faction_candidates("headgear", faction)
	var backgear := _faction_candidates("backgear", faction)
	var mains: Array = []
	for entry: Variant in _faction_candidates("weapons", faction):
		if entry is Dictionary and str(entry.get("slot", "")) == "main":
			mains.append(entry)
	if skins.is_empty() or outfits.is_empty() or headgear.is_empty() or backgear.is_empty() or mains.is_empty():
		return {}
	var weapon: Dictionary = mains[rng.randi_range(0, mains.size() - 1)]
	var offhand := "none"
	if str(weapon.get("grip", "")) == "one_hand" and rng.randf() < 0.62:
		var candidates: Array = []
		for entry: Variant in data.get("offhand_allowed", []):
			var candidate := _find_item("weapons", str(entry))
			if _faction_allows(candidate, faction) and _offhand_allowed(weapon, candidate):
				candidates.append(candidate)
		if not candidates.is_empty():
			offhand = str(candidates[rng.randi_range(0, candidates.size() - 1)]["id"])
	return {
		"faction": faction,
		"skin": str(skins[rng.randi_range(0, skins.size() - 1)]["id"]),
		"outfit": str(outfits[rng.randi_range(0, outfits.size() - 1)]["id"]),
		"headgear": str(headgear[rng.randi_range(0, headgear.size() - 1)]["id"]),
		"backgear": str(backgear[rng.randi_range(0, backgear.size() - 1)]["id"]),
		"weapon": str(weapon.get("id", "")),
		"offhand": offhand,
	}


func recipe_faction_valid(candidate: Dictionary) -> bool:
	var actual := gear_faction(candidate)
	if actual == "mixed":
		return false
	var declared := str(candidate.get("faction", ""))
	if declared.is_empty():
		return true
	if declared not in FACTION_IDS:
		return false
	for item: Variant in _recipe_items(candidate):
		if not (item is Dictionary):
			continue
		var item_faction := _item_faction(item)
		if declared == "neutral" and item_faction != "neutral":
			return false
		if declared == "ming" and item_faction == "wokou":
			return false
		if declared == "wokou" and item_faction == "ming":
			return false
	return true


func gear_faction(candidate: Dictionary) -> String:
	var factions := {}
	for item: Variant in _recipe_items(candidate):
		if not (item is Dictionary):
			continue
		var item_faction := _item_faction(item)
		if item_faction != "neutral":
			factions[item_faction] = true
	if factions.size() > 1:
		return "mixed"
	if factions.is_empty():
		return "neutral"
	return str(factions.keys()[0])


func _recipe_items(candidate: Dictionary) -> Array:
	var entries: Array = []
	entries.append(_find_item("outfits", str(candidate.get("outfit", ""))))
	entries.append(_find_item("headgear", str(candidate.get("headgear", ""))))
	entries.append(_find_item("backgear", str(candidate.get("backgear", ""))))
	var weapon := _find_item("weapons", str(candidate.get("weapon", "")))
	entries.append(weapon)
	var offhand_id := str(candidate.get("offhand", "none"))
	if offhand_id != "none":
		entries.append(_find_item("weapons", offhand_id))
	return entries


func _find_item(group: String, item_id: String) -> Dictionary:
	for entry: Variant in data.get(group, []):
		if entry is Dictionary and str(entry.get("id", "")) == item_id:
			return entry
	return {}


func _offhand_allowed(weapon: Dictionary, offhand: Dictionary) -> bool:
	if offhand.is_empty() or str(weapon.get("grip", "")) != "one_hand":
		return false
	if not _factions_compatible(weapon, offhand):
		return false
	return str(offhand.get("id", "")) in data.get("offhand_allowed", [])


func _faction_candidates(group: String, faction: String) -> Array:
	var all: Array = data.get(group, [])
	if group == "skins":
		return all
	var filtered: Array = []
	for entry: Variant in all:
		if entry is Dictionary and _faction_allows(entry, faction):
			filtered.append(entry)
	return filtered


func _faction_allows(entry: Dictionary, faction: String) -> bool:
	var item_faction := _item_faction(entry)
	return item_faction == "neutral" or item_faction == faction


func _item_faction(entry: Dictionary) -> String:
	return "neutral" if entry.is_empty() else str(entry.get("faction", "neutral"))


func _factions_compatible(first: Dictionary, second: Dictionary) -> bool:
	var factions := {}
	for item: Dictionary in [first, second]:
		var item_faction := _item_faction(item)
		if item_faction != "neutral":
			factions[item_faction] = true
	return factions.size() <= 1
