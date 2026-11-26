class_name RunMinimap
extends Control

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const INK := Color(0.018, 0.028, 0.031, 0.94)
const PAPER := Color("#efe1c2")
const GOLD := Color("#e1b35a")
const MUTED := Color("#baa98a")
const DOT_CAPACITY := 2048
const WEB_REFRESH_INTERVAL := 0.20
const NATIVE_REFRESH_INTERVAL := 0.075

var battlefield: Battlefield
var map_def: Dictionary = {}
var camera: Camera2D
var layout: MapLayout

var _base_texture: Texture2D
var _refresh_accum := 0.0
var _map_rect := Rect2()
var _dot_batch: MultiMesh
var _dot_texture: Texture2D
var _dot_count := 0


func _ready() -> void:
	custom_minimum_size = Vector2(200, 128)
	if size.x < 2.0 or size.y < 2.0:
		size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_dot_batch()
	set_process(true)


func bind(field: Battlefield, definition: Dictionary, run_camera: Camera2D) -> void:
	battlefield = field
	map_def = definition
	camera = run_camera
	layout = field.map_layout if field != null else null
	_base_texture = layout.minimap_texture if layout != null else null
	queue_redraw()


func _process(delta: float) -> void:
	if battlefield == null or layout == null:
		return
	_refresh_accum += delta
	if _refresh_accum >= refresh_interval():
		_refresh_accum = 0.0
		queue_redraw()


func refresh_interval() -> float:
	return WEB_REFRESH_INTERVAL if GameSettings.is_web_platform() else NATIVE_REFRESH_INTERVAL


func _build_dot_batch() -> void:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_dot_texture = ImageTexture.create_from_image(image)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_dot_batch = MultiMesh.new()
	_dot_batch.transform_format = MultiMesh.TRANSFORM_2D
	_dot_batch.use_colors = true
	_dot_batch.mesh = quad
	_dot_batch.instance_count = DOT_CAPACITY
	_dot_batch.visible_instance_count = 0


func _draw() -> void:
	_draw_panel()
	if layout == null or battlefield == null:
		return
	_map_rect = _calculate_map_rect()
	if _base_texture != null:
		draw_texture_rect(_base_texture, _map_rect, false, Color.WHITE)
	draw_rect(_map_rect, Color(GOLD, 0.24), false, 1.0)
	_draw_landmarks()
	_draw_encounters()
	_draw_entities()
	_draw_camera_window()
	_draw_player()
	_draw_compass()


func _draw_panel() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	draw_rect(Rect2(Vector2.ZERO, size), Color(GOLD, 0.34), false, 1.0)
	draw_line(Vector2(8, 23), Vector2(size.x - 8, 23), Color(GOLD, 0.34), 1.0)
	var map_title := GameData.loc(map_def, "name")
	if map_title.is_empty():
		map_title = Locale.t("hud.minimap")
	draw_string(UI_FONT, Vector2(9, 17), map_title, HORIZONTAL_ALIGNMENT_LEFT, 180, 13, Color(PAPER, 0.94))
	draw_string(
		UI_FONT,
		Vector2(size.x - 46, 17),
		Locale.t("hud.live_map"),
		HORIZONTAL_ALIGNMENT_RIGHT,
		38,
		10,
		Color(MUTED, 0.72)
	)


func _calculate_map_rect() -> Rect2:
	var frame := Rect2(9, 29, size.x - 18, size.y - 38)
	var world := layout.world_size
	if world.x <= 0.0 or world.y <= 0.0:
		return frame
	var scale := minf(frame.size.x / world.x, frame.size.y / world.y)
	var map_size := world * scale
	return Rect2(frame.position + (frame.size - map_size) * 0.5, map_size)


func world_to_map(position: Vector2) -> Vector2:
	if layout == null or layout.world_size.x <= 0.0 or layout.world_size.y <= 0.0:
		return _map_rect.position
	return _map_rect.position + (position / layout.world_size) * _map_rect.size


func _draw_landmarks() -> void:
	for landmark in layout.landmark_entries():
		var cell: Vector2i = landmark.get("cell", Vector2i.ZERO) as Vector2i
		var point := world_to_map((Vector2(cell) + Vector2(0.5, 0.5)) * MapLayout.TILE_SIZE)
		var color: Color = landmark.get("color", GOLD) as Color
		var kind := str(landmark.get("kind", "place"))
		if kind == "water":
			draw_circle(point, 1.8, Color(color, 0.82))
		elif kind == "water_gate":
			draw_rect(Rect2(point - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(color, 0.90))
		elif kind == "gate":
			var points := PackedVector2Array([
				point + Vector2(0.0, -3.2),
				point + Vector2(3.2, 0.0),
				point + Vector2(0.0, 3.2),
				point + Vector2(-3.2, 0.0),
			])
			draw_colored_polygon(points, Color(color, 0.94))
		else:
			draw_circle(point, 2.2, Color(color, 0.82))


func _draw_encounters() -> void:
	for site in battlefield.encounter_sites:
		var point := world_to_map(site["pos"] as Vector2)
		if not _map_rect.has_point(point):
			continue
		var used := bool(site.get("used", false))
		var good := bool(site.get("good", true))
		var color := Color("#78c78b") if good else Color("#d06a54")
		if used:
			color = Color(0.52, 0.50, 0.44, 0.62)
		var texture := site.get("texture", null) as Texture2D
		if texture != null:
			var icon_size := 9.0 if not used else 6.0
			draw_texture_rect(
				texture,
				Rect2(point - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size),
				false,
				Color(1.0, 1.0, 1.0, 0.92 if not used else 0.45)
			)
		else:
			draw_circle(point, 2.4 if not used else 1.6, Color(color, 0.82))
		if not used:
			var diamond := PackedVector2Array([
				point + Vector2(0.0, -5.2),
				point + Vector2(5.2, 0.0),
				point + Vector2(0.0, 5.2),
				point + Vector2(-5.2, 0.0),
				point + Vector2(0.0, -5.2),
			])
			draw_polyline(diamond, Color(color, 0.90), 1.0, true)


func _draw_entities() -> void:
	_dot_count = 0
	for enemy in battlefield.enemies:
		if not bool(enemy.get("alive", false)):
			continue
		if bool(enemy.get("boss", false)):
			_append_dot(enemy["pos"] as Vector2, 6.0, Color("#f0a050"))
		elif bool(enemy.get("elite", false)):
			_append_dot(enemy["pos"] as Vector2, 3.6, Color("#e08055"))
		else:
			_append_dot(enemy["pos"] as Vector2, 2.2, Color("#c95a48"))
	for orb in battlefield.orbs:
		_append_pickup_point(orb["pos"] as Vector2, Color("#e8c45f"), 1.0)
	for drop in battlefield.oil_drops:
		_append_pickup_point(drop["pos"] as Vector2, Color("#e6a642"), 1.4)
	for drop in battlefield.heal_drops:
		_append_pickup_point(drop["pos"] as Vector2, Color("#88b978"), 1.2)
	for drop in battlefield.scale_drops:
		_append_pickup_point(drop["pos"] as Vector2, battlefield._scale_color(str(drop.get("color", ""))), 1.6)
	_dot_batch.visible_instance_count = _dot_count
	if _dot_count > 0:
		draw_multimesh(_dot_batch, _dot_texture)


func _append_pickup_point(world_position: Vector2, color: Color, radius: float) -> void:
	var point := world_to_map(world_position)
	if _map_rect.has_point(point):
		_append_dot(world_position, radius * 2.0, Color(color, 0.78))


func _append_dot(world_position: Vector2, size: float, color: Color) -> void:
	if _dot_count >= DOT_CAPACITY:
		return
	var point := world_to_map(world_position)
	if not _map_rect.has_point(point):
		return
	_dot_batch.set_instance_transform_2d(
		_dot_count,
		Transform2D(0.0, Vector2(size, size), 0.0, point)
	)
	_dot_batch.set_instance_color(_dot_count, color)
	_dot_count += 1


func _draw_camera_window() -> void:
	if camera == null:
		return
	var half_view := camera_half_view(get_viewport_rect().size, camera.zoom)
	var top_left := world_to_map(camera.position - half_view)
	var bottom_right := world_to_map(camera.position + half_view)
	draw_rect(
		Rect2(top_left, bottom_right - top_left),
		Color(0.92, 0.82, 0.54, 0.46),
		false,
		1.0
	)


func camera_half_view(view_size: Vector2, camera_zoom: Vector2 = Vector2.ONE) -> Vector2:
	return Vector2(
		view_size.x / maxf(0.01, camera_zoom.x * 2.0),
		view_size.y / maxf(0.01, camera_zoom.y * 2.0)
	)


func _draw_player() -> void:
	var point := world_to_map(battlefield.player_pos)
	var facing := battlefield.player_facing.normalized()
	if facing.length_squared() <= 0.001:
		facing = Vector2.RIGHT
	draw_circle(point, 3.2, Color("#ffe2a1"))
	draw_line(point, point + facing * 6.0, Color("#fff5cf"), 1.8, true)
	draw_arc(point, 5.2, 0.0, TAU, 12, Color(GOLD, 0.56), 1.0, true)


func _draw_compass() -> void:
	var center := Vector2(_map_rect.end.x - 10, _map_rect.position.y + 10)
	draw_circle(center, 6.5, Color(0.03, 0.05, 0.05, 0.64))
	draw_line(center, center + Vector2(0, -4.5), Color(GOLD, 0.88), 1.2, true)
	draw_string(
		UI_FONT,
		center + Vector2(-3.5, 5.0),
		Locale.t("hud.north"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		8,
		Color(PAPER, 0.82)
	)
