extends Node
## 数据层：一次性加载 res://data/*.json 并按 id 建索引，运行时只读。

var units: Dictionary = {}
var towers: Dictionary = {}
var buildings: Dictionary = {}
var levels: Dictionary = {}
var unit_list: Array[Dictionary] = []
var tower_list: Array[Dictionary] = []
var level_list: Array[Dictionary] = []

func _ready() -> void:
	load_all()

func load_all() -> bool:
	unit_list = _load_array("res://data/units.json")
	tower_list = _load_array("res://data/towers.json")
	buildings = _load_map("res://data/buildings.json")
	level_list = _load_array("res://data/levels.json")
	units.clear(); towers.clear(); levels.clear()
	for row in unit_list:
		var id := str(row.get("id", ""))
		if id != "": units[id] = row
	for row in tower_list:
		var id := str(row.get("id", ""))
		if id != "": towers[id] = row
	for row in level_list:
		var id := str(row.get("id", ""))
		if id != "": levels[id] = row
	print("[DATA] units=%d towers=%d buildings=%d levels=%d loaded=true" % [
		units.size(), towers.size(), buildings.size(), levels.size()])
	return units.size() > 0 and towers.size() > 0

func _load_array(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[DATA] open failed: %s" % path)
		return out
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Array:
		for item in parsed:
			if item is Dictionary: out.append(item)
	return out

func _load_map(path: String) -> Dictionary:
	var out: Dictionary = {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return out
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Array:
		for item in parsed:
			if item is Dictionary:
				out[str(item.get("id", ""))] = item
	return out

func get_unit(id: String) -> Dictionary:
	return units.get(id, {})

func get_tower(id: String) -> Dictionary:
	return towers.get(id, {})
