class_name GameData
extends RefCounted

static var _cache: Dictionary = {}


static func load_json(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path] as Dictionary
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing data file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid JSON object: %s" % path)
		return {}
	_cache[path] = parsed
	return parsed as Dictionary


static func loc(entry: Dictionary, field: String) -> String:
	var code := Locale.current
	var localized_key := "%s_%s" % [field, code]
	if entry.has(localized_key):
		return str(entry[localized_key])
	var zh_key := "%s_zh" % field
	if entry.has(zh_key):
		return str(entry[zh_key])
	if entry.has(field):
		return str(entry[field])
	return ""


static func texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	return resource as Texture2D


static func get_weapons() -> Dictionary:
	return load_json("res://data/weapons.json").get("weapons", {}) as Dictionary


static func get_passives() -> Dictionary:
	return load_json("res://data/weapons.json").get("passives", {}) as Dictionary


static func get_enemies() -> Dictionary:
	return load_json("res://data/enemies.json").get("enemies", {}) as Dictionary


static func get_characters() -> Dictionary:
	return load_json("res://data/characters.json").get("characters", {}) as Dictionary


static func get_maps() -> Dictionary:
	return load_json("res://data/maps.json").get("maps", {}) as Dictionary


static func get_shop() -> Dictionary:
	return load_json("res://data/shop.json")


static func get_mercenaries() -> Dictionary:
	return load_json("res://data/mercenaries.json").get("mercenaries", {}) as Dictionary
