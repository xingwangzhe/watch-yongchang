class_name EnemyAtlasBatch
extends Node2D

const ATLAS_SHADER := preload("res://shaders/enemy_variant_atlas.gdshader")
const CAPACITY := 512
const ENEMY_SIZE := 96.0

var manifest: Dictionary = {}
var texture: Texture2D
var shadow_batch: MultiMeshInstance2D
var body_batch: MultiMeshInstance2D


func setup(atlas_manifest: Dictionary, atlas_texture: Texture2D) -> void:
	manifest = atlas_manifest
	texture = atlas_texture
	z_index = -1
	shadow_batch = _make_batch(-1)
	body_batch = _make_batch(0)
	add_child(shadow_batch)
	add_child(body_batch)


func _make_batch(local_z: int) -> MultiMeshInstance2D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_2D
	instances.use_colors = true
	instances.use_custom_data = true
	instances.mesh = quad
	instances.instance_count = CAPACITY
	instances.visible_instance_count = 0
	instances.custom_aabb = AABB(Vector3(-2400, -1800, 0), Vector3(4800, 3600, 0))
	var node := MultiMeshInstance2D.new()
	node.multimesh = instances
	node.texture = texture
	var material := ShaderMaterial.new()
	material.shader = ATLAS_SHADER
	node.material = material
	node.z_index = local_z
	return node


func update_enemies(enemies: Array[Dictionary], elapsed: float) -> void:
	if body_batch == null or shadow_batch == null or texture == null:
		return
	var entries: Dictionary = manifest.get("variants", {}) as Dictionary
	var cell_size := int(manifest.get("cell_size", 128))
	var columns := maxi(1, int(manifest.get("columns", 1)))
	var atlas_size := Vector2(
		cell_size * columns,
		cell_size * maxi(1, int(manifest.get("rows", 1)))
	)
	var shadow_mesh := shadow_batch.multimesh
	var body_mesh := body_batch.multimesh
	var count := mini(enemies.size(), CAPACITY)
	for i in range(count):
		var enemy := enemies[i]
		var draw_id := str(enemy.get("draw_id", enemy.get("id", "")))
		var entry: Dictionary = entries.get(draw_id, {}) as Dictionary
		var frame_count := maxi(1, int(entry.get("frames", 1)))
		var frame := posmod(
			int(elapsed * maxf(1.0, float(enemy.get("sprite_fps", entry.get("fps", 10.0)))))
				+ posmod(draw_id.hash(), frame_count),
			frame_count
		)
		var cell := int(entry.get("first_cell", -1)) + frame
		if cell < 0:
			continue
		var cell_x := cell % columns
		@warning_ignore("integer_division")
		var cell_y := cell / columns
		var uv_origin := Vector2(float(cell_x * cell_size), float(cell_y * cell_size)) / atlas_size
		var uv_size := Vector2(float(cell_size), float(cell_size)) / atlas_size
		var uv := Color(uv_origin.x, uv_origin.y, uv_size.x, uv_size.y)
		body_mesh.set_instance_custom_data(i, uv)
		shadow_mesh.set_instance_custom_data(i, uv)
		var position := enemy["pos"] as Vector2
		var radius := float(enemy["radius"])
		var size := ENEMY_SIZE * float(enemy["scale"])
		var facing := -1.0 if float(enemy.get("facing_x", 1.0)) < 0.0 else 1.0
		body_mesh.set_instance_transform_2d(
			i,
			Transform2D(0.0, Vector2(size * facing, -size), 0.0, position - Vector2(0.0, size * 0.16))
		)
		var tint := Color.WHITE.lerp(enemy.get("runtime_tint", Color.WHITE) as Color, 0.42)
		if str(enemy.get("id", "")) == "banner":
			tint = tint.lerp(Color(1.0, 0.72, 0.68, 1.0), 0.30)
		if bool(enemy.get("elite", false)):
			tint = tint.lerp(Color(1.0, 0.88, 0.58, 1.0), 0.24)
		if bool(enemy.get("boss", false)):
			tint = tint.lerp(Color(1.0, 0.72, 0.58, 1.0), 0.30)
		if float(enemy.get("flash", 0.0)) > 0.0:
			tint = FeedbackManager.config.flash_color
		body_mesh.set_instance_color(i, tint)
		shadow_mesh.set_instance_transform_2d(
			i,
			Transform2D(0.0, Vector2(radius * 1.5, -radius * 1.5), 0.0, position + Vector2(0.0, radius * 0.7))
		)
		shadow_mesh.set_instance_color(i, Color(0.0, 0.0, 0.0, 0.22))
	body_mesh.visible_instance_count = count
	shadow_mesh.visible_instance_count = count
	shadow_batch.visible = count > 0
	body_batch.visible = count > 0
	visible = count > 0
