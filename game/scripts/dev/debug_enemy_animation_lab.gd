extends "res://scripts/dev/debug_room.gd"

const DEBUG_SEED := 20261128
const ENEMY_IDS := ["scout", "ronin", "shield", "gun", "archer"]

var _battlefield: Battlefield
var _camera: Camera2D
var _enemy_id := "scout"
var _attack_timer := 0.0
var _elapsed := 0.0
var _enemy_index := -1
var _last_enemy_position := Vector2.ZERO
var _has_previous_enemy_position := false
var _enemy_moved_this_frame := false
var _diagnostics_clock := 0.0


func _ready() -> void:
	room_title = "敌人移动帧 / 攻击帧"
	super._ready()
	_camera = Camera2D.new()
	_camera.name = "EnemyFollowCamera"
	add_child(_camera)
	_camera.make_current()
	_load_enemy(0)


func _load_enemy(index: int) -> void:
	_enemy_id = ENEMY_IDS[posmod(index, ENEMY_IDS.size())]
	if is_instance_valid(_battlefield):
		remove_child(_battlefield)
		_battlefield.queue_free()
	_battlefield = Battlefield.new()
	_battlefield.name = "Battlefield"
	add_child(_battlefield)
	_battlefield.setup(DEBUG_SEED)
	_camera.position = _battlefield.player_pos
	_enemy_index = _battlefield.spawn_enemy_at(_enemy_id, _battlefield.player_pos + Vector2(240, 0))
	if _enemy_index < 0:
		push_error("Debug enemy lab could not spawn %s" % _enemy_id)
		return
	_attack_timer = 0.0
	_elapsed = 0.0
	_diagnostics_clock = 0.0
	_has_previous_enemy_position = false
	_enemy_moved_this_frame = false
	_battlefield.enemies[_enemy_index]["attack_timer"] = 0.25
	set_debug_text(_diagnostics())


func _process(delta: float) -> void:
	_elapsed += delta
	_diagnostics_clock -= delta
	_attack_timer -= delta
	_battlefield.update_world(delta, _player_state())
	_battlefield.advance_flow_field(256)
	if _attack_timer <= 0.0 and _enemy_index >= 0 and _enemy_index < _battlefield.enemies.size():
		_attack_timer = 1.2
		var enemy: Dictionary = _battlefield.enemies[_enemy_index]
		var origin: Vector2 = enemy.get("pos", _battlefield.player_pos + Vector2(55, 0))
		_battlefield.play_enemy_attack_fx(_enemy_id, origin, _battlefield.player_pos - origin)
	if _enemy_index >= 0 and _enemy_index < _battlefield.enemies.size():
		var current_enemy: Dictionary = _battlefield.enemies[_enemy_index]
		var current_position: Vector2 = current_enemy.get("pos", Vector2.ZERO)
		_enemy_moved_this_frame = _has_previous_enemy_position and current_position.distance_squared_to(_last_enemy_position) > 0.01
		_last_enemy_position = current_position
		_has_previous_enemy_position = true
	if _diagnostics_clock <= 0.0:
		_diagnostics_clock = 0.12
		set_debug_text(_diagnostics())


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_hub()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			_load_enemy(event.keycode - KEY_1)


func _diagnostics() -> String:
	var definition: Dictionary = _battlefield.enemy_data.get(_enemy_id, {}) as Dictionary
	var frames: Array = _battlefield.enemy_sprite_frames.get(_enemy_id, []) as Array
	var enemy: Dictionary = _battlefield.enemies[_enemy_index] if _enemy_index >= 0 and _enemy_index < _battlefield.enemies.size() else {}
	var frame_index: int = posmod(int(_battlefield.time * maxf(1.0, float(definition.get("sprite_fps", 10)))) + posmod(_enemy_id.hash(), maxi(1, frames.size())), maxi(1, frames.size()))
	var moving := _enemy_moved_this_frame
	return "seed=%d enemy=%s · %s [1-5 switch]\nsheet=%s row=%d/%d cropped_frames=%d\nactual displacement=%s frame=%d/%d attacking=%s · same full person row" % [
		DEBUG_SEED,
		_enemy_id,
		str(definition.get("name_zh", "")),
		str(definition.get("sprite_sheet", "")),
		int(definition.get("sprite_row", -1)),
		int(definition.get("sprite_rows", 0)),
		frames.size(),
		str(moving),
		frame_index,
		frames.size(),
		str(float(enemy.get("attack_until", 0.0)) > _battlefield.time),
	]


func _player_state() -> Dictionary:
	return {"pos": _battlefield.player_pos, "facing": Vector2.LEFT, "radius": 18.0}
