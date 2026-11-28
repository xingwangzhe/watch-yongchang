extends GutTest

const DEBUG_SCENES := [
	"res://scenes/debug/debug_hub.tscn",
	"res://scenes/debug/terrain_lab.tscn",
	"res://scenes/debug/enemy_animation_lab.tscn",
	"res://scenes/debug/attack_feedback_lab.tscn",
	"res://scenes/debug/shop_lab.tscn",
	"res://scenes/components/battle_debug_panel.tscn",
]


func test_debug_rooms_are_independently_loadable_scenes() -> void:
	for scene_path in DEBUG_SCENES:
		assert_true(ResourceLoader.exists(scene_path), "missing debug room %s" % scene_path)
		assert_not_null(load(scene_path), "debug room failed to load %s" % scene_path)


func test_enemy_debug_room_uses_same_cropped_person_frames_for_walk_and_attack() -> void:
	var battlefield := Battlefield.new()
	add_child_autofree(battlefield)
	battlefield.setup(20261128)
	var enemy_index := battlefield.spawn_enemy_at("scout", battlefield.player_pos + Vector2(120, 0))
	assert_gte(enemy_index, 0)
	var walk_frames: Array = battlefield.enemy_sprite_frames.get("scout", []) as Array
	var enemy: Dictionary = battlefield.enemies[enemy_index]
	var attack_frames: Array = enemy.get("attack_frames", []) as Array
	assert_eq(walk_frames.size(), 8)
	assert_eq(attack_frames, walk_frames, "attack pose must keep this enemy's own full-character atlas row")
	for frame in walk_frames:
		assert_eq((frame as Texture2D).get_size(), Vector2(128, 128))
	var initial_position: Vector2 = enemy.get("pos", Vector2.ZERO)
	var player_state := {"pos": battlefield.player_pos, "facing": Vector2.LEFT, "radius": 18.0}
	for frame_index in 60:
		battlefield.update_world(1.0 / 60.0, player_state)
		battlefield.advance_flow_field(256)
	var moved_enemy: Dictionary = battlefield.enemies[enemy_index]
	assert_gt((moved_enemy.get("pos", Vector2.ZERO) as Vector2).distance_to(initial_position), 4.0, "enemy row must animate on an actually moving enemy")
