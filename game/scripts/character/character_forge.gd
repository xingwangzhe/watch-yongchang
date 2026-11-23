class_name CharacterForge
extends Node2D

signal recipe_changed(recipe: Dictionary)

const DATA_PATH := "res://data/character_templates.json"

var data: Dictionary = {}
var recipe: Dictionary = {}
var frame := 0
var cell_size := 128
var frame_count := 32

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
	frame_count = int(data.get("frame_count", 32))
	return true


func set_recipe(next_recipe: Dictionary) -> void:
	if data.is_empty() and not load_data():
		return
	if not next_recipe.has("skin") or not next_recipe.has("weapon"):
		push_error("character recipe needs skin and weapon")
		return
	recipe = next_recipe.duplicate(true)
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

	var rows := {
		"backgear": str(backgear.get("id", "none")) + "|" + pose_id,
		"body": str(skin["id"]) + "|" + pose_id,
		"outfit": str(outfit["id"]) + "|" + pose_id,
		"headgear": str(headgear.get("id", "none")) + "|" + pose_id,
		"weapon": str(weapon["id"]),
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
		var texture := _texture_for(atlas_key)
		if row < 0 or texture == null:
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
	return str(offhand.get("id", "")) in data.get("offhand_allowed", [])


func _row_index(atlas_key: String, row_key: String) -> int:
	var atlases: Dictionary = data.get("atlases", {})
	if not atlases.has(atlas_key):
		return -1
	var rows: Dictionary = atlases[atlas_key].get("rows", {})
	return int(rows.get(row_key, -1))


func _texture_for(atlas_key: String) -> Texture2D:
	if _textures.has(atlas_key):
		return _textures[atlas_key] as Texture2D
	var atlases: Dictionary = data.get("atlases", {})
	if not atlases.has(atlas_key):
		return null
	var texture := load(str(atlases[atlas_key].get("path", ""))) as Texture2D
	if texture != null:
		_textures[atlas_key] = texture
	return texture


func _update_regions() -> void:
	for entry in _layers:
		var sprite := entry["sprite"] as Sprite2D
		if not is_instance_valid(sprite):
			continue
		sprite.region_rect = Rect2(
			frame * cell_size,
			int(entry["row"]) * cell_size,
			cell_size,
			cell_size
		)
