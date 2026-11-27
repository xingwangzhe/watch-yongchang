extends "res://scripts/dev/debug_room.gd"

const DEBUG_SEED := 20261128
const WEAPON_ID := "saber"

var _battlefield: Battlefield
var _camera: Camera2D
var _attack_clock := 0.0
var _weapons: Dictionary = {}


func _ready() -> void:
	room_title = "玩家攻击反馈 / 攻击范围"
	super._ready()
	_battlefield = Battlefield.new()
	_battlefield.name = "Battlefield"
	add_child(_battlefield)
	_battlefield.setup(DEBUG_SEED)
	_camera = Camera2D.new()
	_camera.name = "PlayerFollowCamera"
	_camera.position = _battlefield.player_pos
	add_child(_camera)
	_camera.make_current()
	_weapons = GameData.load_json("res://data/weapons.json").get("weapons", {}) as Dictionary
	var target := _battlefield.player_pos + Vector2(82.0, 0.0)
	_battlefield.spawn_enemy_at("scout", target)
	var overlay := DebugAttackRangeOverlay.new()
	overlay.name = "AttackRangeOverlay"
	overlay.origin = _battlefield.player_pos
	overlay.radius = float(_weapon().get("range", 0))
	overlay.arc_degrees = float(_weapon().get("arc_degrees", 0))
	overlay.z_index = 10
	_battlefield.add_child(overlay)
	set_debug_text("seed=%d weapon=%s range=%d arc=%s°\nLooping real attack effect; hit resolution uses Battlefield.damage_cone" % [DEBUG_SEED, WEAPON_ID, int(_weapon().get("range", 0)), str(_weapon().get("arc_degrees", 0))])


func _process(delta: float) -> void:
	_battlefield.update_world(delta, {"pos": _battlefield.player_pos, "facing": Vector2.RIGHT, "radius": 18.0}, 0.0)
	_battlefield.advance_flow_field(256)
	_attack_clock -= delta
	if _attack_clock <= 0.0:
		_attack_clock = 0.72
		_battlefield.play_player_attack_fx(WEAPON_ID, _battlefield.player_pos, Vector2.RIGHT)
		_battlefield.damage_cone(
			_battlefield.player_pos,
			Vector2.RIGHT,
			float(_weapon().get("range", 0)),
			float(_weapon().get("arc_degrees", 0)),
			float(_weapon().get("damage", 0)),
			float(_weapon().get("knockback", 0))
		)


func _weapon() -> Dictionary:
	return _weapons.get(WEAPON_ID, {}) as Dictionary


class DebugAttackRangeOverlay extends Node2D:
	var origin := Vector2.ZERO
	var radius := 126.0
	var arc_degrees := 118.0

	func _draw() -> void:
		var half_arc := deg_to_rad(arc_degrees * 0.5)
		draw_arc(origin, radius, -half_arc, half_arc, 64, Color(1.0, 0.76, 0.28, 0.75), 2.0, true)
		draw_line(origin, origin + Vector2.RIGHT.rotated(-half_arc) * radius, Color(1.0, 0.76, 0.28, 0.55), 1.0, true)
		draw_line(origin, origin + Vector2.RIGHT.rotated(half_arc) * radius, Color(1.0, 0.76, 0.28, 0.55), 1.0, true)
