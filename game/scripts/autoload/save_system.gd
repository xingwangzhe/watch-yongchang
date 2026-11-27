extends Node

signal saved

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 2

var save_path: String = SAVE_PATH
var data: Dictionary = {}


func _ready() -> void:
	reset_memory()
	load_game()


func reset_memory() -> void:
	data = default_data()


func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"runs": 0,
		"last_run_seed": 0,
		"runs_won": 0,
		"best_merit": 0,
		"total_merit": 0,
		"best_kills": 0,
		"best_time": 0.0,
		"prologue_seen": false,
		"intro_seen": false,
		"tutorial_seen": false,
		"last_mode": "menu",
		"last_saved_unix": 0,
		"last_saved_local": "",
		"selected_character": "wanglu",
		"selected_map": "tideland",
		"unlocked_characters": ["wanglu"],
		"unlocked_maps": ["tideland"],
		"settings": {},
	}


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var loaded := load_from(save_path)
	if loaded.is_empty():
		return false
	data = loaded
	return true


func load_from(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var merged := default_data()
	merged.merge(parsed, true)
	merged["total_merit"] = maxi(
		int(merged.get("total_merit", 0)),
		int(merged.get("best_merit", 0))
	)
	return merged


func write_to(path: String, payload: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	return OK


func autosave(extra: Dictionary = {}) -> void:
	if not extra.is_empty():
		data.merge(extra, true)
	data["version"] = SAVE_VERSION
	data["last_saved_unix"] = int(Time.get_unix_time_from_system())
	data["last_saved_local"] = _local_timestamp()
	data["settings"] = GameSettings.to_dict()
	var error := write_to(save_path, data)
	if error != OK:
		push_warning("Autosave failed with error %d: %s" % [error, save_path])
		return
	saved.emit()


func begin_run() -> int:
	var runs := int(data.get("runs", 0)) + 1
	var seed := make_run_seed(
		runs,
		int(Time.get_unix_time_from_system() * 1_000_000.0),
		Time.get_ticks_usec(),
		int(data.get("last_run_seed", 0))
	)
	autosave({"runs": runs, "last_mode": "run", "last_run_seed": seed})
	return seed


static func make_run_seed(run_number: int, wall_usec: int, monotonic_usec: int, previous_seed: int = 0) -> int:
	var seed := _hash_seed_material("run:%d:%d:%d" % [run_number, wall_usec, monotonic_usec])
	if seed == previous_seed:
		seed = seed % 0x7FFFFFFF + 1
	return seed


static func derive_seed(run_seed: int, purpose: String) -> int:
	return _hash_seed_material("%d:%s" % [run_seed, purpose])


static func _hash_seed_material(material: String) -> int:
	# FNV-1a over UTF-8 bytes keeps run and purpose seeds stable across launches.
	var value := 2166136261
	for byte in material.to_utf8_buffer():
		value = int((value ^ int(byte)) * 16777619) & 0x7FFFFFFF
	return maxi(1, value)


func complete_tutorial() -> void:
	data["tutorial_seen"] = true
	autosave({"tutorial_seen": true})


func record_run(merit: int, kills: int, victory: bool, elapsed: float) -> void:
	data["runs_won"] = int(data.get("runs_won", 0)) + (1 if victory else 0)
	data["total_merit"] = int(data.get("total_merit", 0)) + maxi(0, merit)
	data["best_merit"] = maxi(int(data.get("best_merit", 0)), merit)
	data["best_kills"] = maxi(int(data.get("best_kills", 0)), kills)
	data["best_time"] = maxf(float(data.get("best_time", 0.0)), elapsed)


func has_progress() -> bool:
	return int(data.get("runs", 0)) > 0


func last_saved_text() -> String:
	var stamp := str(data.get("last_saved_local", ""))
	if stamp.length() < 16:
		return ""
	return stamp.substr(11, 5)


func _local_timestamp() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d" % [
		int(now.get("year", 0)),
		int(now.get("month", 0)),
		int(now.get("day", 0)),
		int(now.get("hour", 0)),
		int(now.get("minute", 0)),
	]
