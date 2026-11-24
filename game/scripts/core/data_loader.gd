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


static func source_label(entry: Dictionary) -> String:
	var reference := str(entry.get("source_ref", ""))
	var topic := "%s %s %s %s" % [
		str(entry.get("card_id", entry.get("option_id", entry.get("id", "")))),
		str(entry.get("family", "")),
		str(entry.get("culture_zh", entry.get("culture", ""))),
		str(entry.get("name_zh", entry.get("title", ""))),
	]
	var dragon_lantern := (
		topic.contains("龙灯")
		or topic.contains("五色纸")
		or topic.contains("dragon")
		or topic.contains("colored_paper")
	)
	var chinese := Locale.current != "en"
	var names: Array[String] = []
	if dragon_lantern:
		_append_source_name(
			names,
			"清《永嘉县志·岁时》" if chinese else "Qing Yongjia County Gazetteer · Seasonal Customs"
		)
	if reference.contains("永昌堡-十三进士与抗倭纪略"):
		_append_source_name(
			names,
			"《永昌堡：十三进士与抗倭纪略》" if chinese else "Yongchang Fort: Thirteen Jinshi and the Anti-Wokou Chronicle"
		)
	if reference.contains("抵御倭患第一人"):
		_append_source_name(
			names,
			"《汤和信俗·抵御倭患》" if chinese else "Tang He Tradition: Defender Against the Wokou"
		)
	if reference.contains("意绘抗倭英雄汤和"):
		_append_source_name(
			names,
			"《意绘抗倭英雄汤和》" if chinese else "The Illustrated Tale of Tang He"
		)
	if reference.contains("汤和庙基地介绍"):
		_append_source_name(
			names,
			"宁村汤和庙 · 汤和信俗" if chinese else "Ningcun Tang He Temple · Tang He tradition"
		)
	if reference.contains("拼字龙灯邀您"):
		_append_source_name(
			names,
			"宁村拼字龙灯" if chinese else "Ningcun dragon-lantern tradition"
		)
	if reference.contains("堡与汤和关系索引"):
		if dragon_lantern:
			_append_source_name(names, "《汤和信俗》" if chinese else "Tang He tradition")
		else:
			_append_source_name(
				names,
				"《永昌堡：十三进士与抗倭纪略》" if chinese else "Yongchang Fort: Thirteen Jinshi and the Anti-Wokou Chronicle"
			)
			_append_source_name(names, "《汤和信俗》" if chinese else "Tang He tradition")
	var dramatization := "守夜演绎" if chinese else "A dramatised night watch"
	var dramatized := (
		str(entry.get("category", "")) == "演绎"
		or reference.contains("演绎")
		or reference.contains("虚构")
		or reference.contains("游戏")
		or reference.contains("玩法设计")
	)
	if names.is_empty() and not dramatized and not reference.contains("design/"):
		_append_source_name(names, "永昌地方文献" if chinese else "Yongchang local records")
	if dramatized or names.is_empty():
		_append_source_name(names, dramatization)
	return " · ".join(names)


static func _append_source_name(names: Array[String], source_name: String) -> void:
	if not names.has(source_name):
		names.append(source_name)


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
