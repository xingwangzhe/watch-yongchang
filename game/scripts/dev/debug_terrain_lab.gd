extends "res://scripts/dev/debug_room.gd"

const MAP_IDS := ["tideland", "crossstreet", "watergate"]
const DEBUG_SEED := 20261128

var _map_index := 0
var _renderer: MapRenderer
var _layout: MapLayout
var _camera: Camera2D


func _ready() -> void:
	room_title = "地表 / 河岸 / 建筑"
	super._ready()
	_camera = Camera2D.new()
	_camera.name = "DebugCamera"
	add_child(_camera)
	_camera.make_current()
	_show_map(0)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_hub()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_show_map(0)
		elif event.keycode == KEY_2:
			_show_map(1)
		elif event.keycode == KEY_3:
			_show_map(2)
		elif event.keycode == KEY_LEFT:
			_show_map(_map_index - 1)
		elif event.keycode == KEY_RIGHT:
			_show_map(_map_index + 1)


func _show_map(index: int) -> void:
	_map_index = posmod(index, MAP_IDS.size())
	var map_id: String = MAP_IDS[_map_index]
	var definition: Dictionary = GameData.get_maps().get(map_id, {}) as Dictionary
	if definition.is_empty():
		push_error("Debug terrain lab missing map %s" % map_id)
		return
	if is_instance_valid(_renderer):
		_renderer.queue_free()
	_layout = MapLayout.new()
	_layout.setup(map_id, definition)
	_renderer = MapRenderer.new()
	_renderer.name = "MapRenderer_%s" % map_id
	add_child(_renderer)
	_renderer.build(_layout, definition, DEBUG_SEED)
	_camera.position = _layout.start_pos
	_camera.zoom = Vector2(0.75, 0.75)
	set_debug_text("map=%s seed=%d 1/2/3 切换地图 · ←/→ 轮换\n可通行区域=%d 修复=%d" % [map_id, DEBUG_SEED, int(_layout.connectivity_report().get("blocked", -1)), _layout.last_repair_count])
