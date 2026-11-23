extends Node

signal language_changed(code: String)

const LANGUAGE_CODES := ["zh", "en"]
const TABLE_DIR := "res://data/i18n"

var current: String = "zh"
var _tables: Dictionary = {}


func _ready() -> void:
	for code in LANGUAGE_CODES:
		_tables[code] = _load_table(code)
	set_language(GameSettings.language, false)


func set_language(code: String, persist: bool = true) -> void:
	if not _tables.has(code):
		code = "zh"
	var did_change := current != code
	current = code
	if persist:
		GameSettings.set_language(code)
	if did_change:
		language_changed.emit(code)


func toggle_language() -> void:
	set_language("en" if current == "zh" else "zh")


func t(key: String, args: Dictionary = {}) -> String:
	var table: Dictionary = _tables.get(current, {})
	var fallback: Dictionary = _tables.get("zh", {})
	var value: Variant = table.get(key, fallback.get(key, key))
	if value is String and not args.is_empty():
		return (value as String).format(args)
	return str(value)


func language_name(code: String = "") -> String:
	var target := current if code.is_empty() else code
	return "中文" if target == "zh" else "English"


func table(code: String) -> Dictionary:
	return _tables.get(code, {})


func _load_table(code: String) -> Dictionary:
	var path := "%s/%s.json" % [TABLE_DIR, code]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing language table: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Invalid language table: %s" % path)
	return {}
