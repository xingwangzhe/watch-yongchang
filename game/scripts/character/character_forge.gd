class_name CharacterForge
extends Node2D

signal recipe_changed(recipe: Dictionary)

const DATA_PATH := "res://data/character_templates.json"
const FACTION_IDS := ["ming", "wokou", "neutral"]

var data: Dictionary = {}
var recipe: Dictionary = {}
var frame := 0
var cell_size := 128
var frame_count := 48

var _layers: Array[Dictionary] = []
var _textures: Dictionary = {}


func _ready() -> void:
	if data.is_empty():
		load_data()
	if recipe.is_empty() and not data.is_empty():
		set_recipe(data["recipes"]["hero"])


func load_data(path: String = DATA_PATH) -> bool:
	if not FileAccess.file_exists(path):
		push_error("character forge data missing: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or not (parsed is Dictionary):
		push_error("character forge data is not valid JSON: %s" % path)
		return false
	data = parsed
	cell_size = int(data.get("cell", 128))
	frame_count = int(data.get("frame_count", 48))
	return true


func set_recipe(next_recipe: Dictionary) -> void:
	if data.is_empty() and not load_data():
		return
	if not next_recipe.has("skin") or not next_recipe.has("weapon"):
		push_error("character recipe needs skin and weapon")
		return
	if not recipe_faction_valid(next_recipe):
		push_warning("character recipe mixes Ming and Wokou gear: %s" % str(next_recipe))
		return
	recipe = next_recipe.duplicate(true)
	if not recipe.has("faction"):
		recipe["faction"] = gear_faction(recipe)
	var weapon := _find_item("weapons", str(recipe.get("weapon", "")))
	var offhand := _find_item("weapons", str(recipe.get("offhand", "none")))
	if not _offhand_allowed(weapon, offhand):
		recipe["offhand"] = "none"
	_rebuild_layers()
	recipe_changed.emit(recipe.duplicate(true))


func set_frame(next_frame: int) -> void:
	frame = posmod(next_frame, maxi(1, frame_count))
	_update_regions()


func frame_for_clip(clip: String, elapsed: float) -> int:
	var clips: Dictionary = data.get("clips", {})
	if not clips.has(clip):
		return 0
	var clip_data: Dictionary = clips[clip]
	var start := int(clip_data.get("start", 0))
	var count := maxi(1, int(clip_data.get("count", 1)))
	var fps := maxf(0.1, float(clip_data.get("fps", 8)))
	return start + posmod(int(elapsed * fps), count)


func layer_count() -> int:
	return _layers.size()


func layer_rows() -> Dictionary:
	var rows := {}
	for entry in _layers:
		rows[str(entry["name"])] = int(entry["row"])
	return rows


func current_weapon_id() -> String:
	return str(recipe.get("weapon", ""))


func current_offhand_id() -> String:
	return str(recipe.get("offhand", "none"))


func current_faction() -> String:
	return str(recipe.get("faction", "neutral"))


func current_pose_variant() -> String:
	if data.is_empty():
		return ""
	var weapon := _find_item("weapons", str(recipe.get("weapon", "")))
	var offhand := _find_item("weapons", str(recipe.get("offhand", "none")))
	if not _offhand_allowed(weapon, offhand):
		offhand = {}
	return _pose_variant(weapon, offhand)


func current_weapon_row_key() -> String:
	if data.is_empty():
		return ""
	var weapon := _find_item("weapons", str(recipe.get("weapon", "")))
	var offhand := _find_item("weapons", str(recipe.get("offhand", "none")))
	if weapon.is_empty():
		return ""
	if not _offhand_allowed(weapon, offhand):
		return str(weapon.get("id", ""))
	return str(weapon.get("id", "")) + "+" + str(offhand.get("id", ""))


func combo_family_for(main_id: String, offhand_id: String) -> String:
	if offhand_id == "none" or data.is_empty():
		return ""
	var pairs: Dictionary = data.get("combo_pairs", {})
	return str(pairs.get(main_id + "+" + offhand_id, ""))


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


func _faction_candidates(group: String, faction: String) -> Array:
	var all: Array = data.get(group, [])
	if group == "skins":
		return all
	var filtered: Array = []
	for entry: Variant in all:
		if not (entry is Dictionary):
			continue
		if _faction_allows(entry, faction):
			filtered.append(entry)
	return filtered


func _faction_allows(entry: Dictionary, faction: String) -> bool:
	var item_faction := _item_faction(entry)
	return item_faction == "neutral" or item_faction == faction


func _item_faction(entry: Dictionary) -> String:
	if entry.is_empty():
		return "neutral"
	return str(entry.get("faction", "neutral"))


func _factions_compatible(first: Dictionary, second: Dictionary) -> bool:
	var factions := {}
	for item: Dictionary in [first, second]:
		var item_faction := _item_faction(item)
		if item_faction != "neutral":
			factions[item_faction] = true
	return factions.size() <= 1


func _recipe_items(candidate: Dictionary) -> Array:
	var entries: Array = []
	var outfit := _find_item("outfits", str(candidate.get("outfit", "")))
	entries.append(outfit)
	var headgear := _find_item("headgear", str(candidate.get("headgear", "")))
	entries.append(headgear)
	var backgear := _find_item("backgear", str(candidate.get("backgear", "")))
	entries.append(backgear)
	var weapon := _find_item("weapons", str(candidate.get("weapon", "")))
	entries.append(weapon)
	var offhand_id := str(candidate.get("offhand", "none"))
	if offhand_id != "none":
		entries.append(_find_item("weapons", offhand_id))
	return entries


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


func _pose_variant(weapon: Dictionary, offhand: Dictionary) -> String:
	var main_id := str(weapon.get("id", ""))
	if offhand.is_empty():
		return main_id
	var family := combo_family_for(main_id, str(offhand.get("id", "")))
	if family.is_empty():
		family = "mixed"
	return "combo_" + family


func _rebuild_layers() -> void:
	for entry in _layers:
		var sprite := entry["sprite"] as Sprite2D
		if is_instance_valid(sprite):
			sprite.free()
	_layers.clear()

	var skin := _find_item("skins", str(recipe.get("skin", "")))
	var outfit := _find_item("outfits", str(recipe.get("outfit", "")))
	var headgear := _find_item("headgear", str(recipe.get("headgear", "")))
	var backgear := _find_item("backgear", str(recipe.get("backgear", "")))
	var weapon := _find_item("weapons", str(recipe.get("weapon", "")))
	if skin.is_empty() or outfit.is_empty() or weapon.is_empty():
		return
	var pose_id := str(weapon["id"])
	var offhand_id := str(recipe.get("offhand", "none"))
	var offhand := _find_item("weapons", offhand_id)
	if not _offhand_allowed(weapon, offhand):
		offhand_id = "none"
		offhand = {}
	var variant := _pose_variant(weapon, offhand)

	var rows := {
		"backgear": str(backgear.get("id", "none")) + "|" + pose_id,
		"body": str(skin["id"]) + "|" + variant,
		"outfit": str(outfit["id"]) + "|" + variant,
		"headgear": str(headgear.get("id", "none")) + "|" + pose_id,
		"weapon": current_weapon_row_key(),
	}
	if not offhand.is_empty():
		rows["offhand"] = pose_id + "|" + offhand_id

	var index := 0
	for layer_name: String in data.get("layer_order", []):
		if layer_name == "offhand" and not rows.has("offhand"):
			continue
		var atlas_key := layer_name
		var row_key := str(rows.get(layer_name, ""))
		var row := _row_index(atlas_key, row_key)
		var page := _page_for_row(atlas_key, row)
		if row < 0 or page.is_empty():
			continue
		var texture := _texture_for(str(page["path"]))
		if texture == null:
			continue
		var sprite := Sprite2D.new()
		sprite.name = "Layer_%s" % layer_name
		sprite.texture = texture
		sprite.centered = true
		sprite.region_enabled = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = index
		add_child(sprite)
		_layers.append({
			"name": layer_name,
			"sprite": sprite,
			"row": row,
			"local_row": int(page["local_row"]),
		})
		index += 1
	_update_regions()


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


func _row_index(atlas_key: String, row_key: String) -> int:
	var atlases: Dictionary = data.get("atlases", {})
	if not atlases.has(atlas_key):
		return -1
	var rows: Dictionary = atlases[atlas_key].get("rows", {})
	return int(rows.get(row_key, -1))


func _page_for_row(atlas_key: String, row: int) -> Dictionary:
	var atlases: Dictionary = data.get("atlases", {})
	if not atlases.has(atlas_key):
		return {}
	var atlas: Dictionary = atlases[atlas_key]
	var pages: Array = atlas.get("pages", [])
	if pages.is_empty():
		return {"path": str(atlas.get("path", "")), "local_row": row}
	for page: Dictionary in pages:
		var offset := int(page.get("row_offset", 0))
		var count := int(page.get("row_count", 0))
		if row >= offset and row < offset + count:
			return {"path": str(page.get("path", "")), "local_row": row - offset}
	return {}


func _texture_for(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path] as Texture2D
	var texture := load(path) as Texture2D
	if texture != null:
		_textures[path] = texture
	return texture


func _update_regions() -> void:
	for entry in _layers:
		var sprite := entry["sprite"] as Sprite2D
		if not is_instance_valid(sprite):
			continue
		sprite.region_rect = Rect2(
			frame * cell_size,
			int(entry["local_row"]) * cell_size,
			cell_size,
			cell_size
		)
