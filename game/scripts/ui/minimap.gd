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
# 小地图仅 212×144：奇遇点不再把 512×512 SVG 缩到 14px（NEAREST 采样会糊成一团），
# 改为按实际像素用 draw_* 画矢量符号，半径即符号的可绘制范围。
const ENCOUNTER_MARKER_RADIUS := 9.0
const ENCOUNTER_GLYPH_ARM := 4.2
# 深色描边色，统一用于地标/实体/玩家，提升浅色底图上的对比度。
const MARKER_OUTLINE := Color(0.015, 0.025, 0.025, 0.84)

var battlefield: Battlefield
var map_def: Dictionary = {}
var camera: Camera2D
var layout: MapLayout

var _base_texture: Texture2D
var _refresh_accum := 0.0
var _map_rect := Rect2()
var _dot_batch: MultiMesh
var _dot_outline_batch: MultiMesh
var _dot_texture: Texture2D
var _dot_count := 0


func _ready() -> void:
	custom_minimum_size = Vector2(212, 144)
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
	_dot_batch = _create_dot_batch(quad)
	_dot_outline_batch = _create_dot_batch(quad)


func _create_dot_batch(quad: QuadMesh) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_2D
	batch.use_colors = true
	batch.mesh = quad
	batch.instance_count = DOT_CAPACITY
	batch.visible_instance_count = 0
	return batch


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
	var live_text := Locale.t("hud.live_map")
	var live_width := UI_FONT.get_string_size(live_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	# 英文标题（如 "Tidal Flats at Night"）较长，按真实字宽自适应，避免被固定宽度裁切。
	var available := size.x - 18.0 - live_width - 6.0
	var title_size := 13
	while title_size > 9 and UI_FONT.get_string_size(map_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > available:
		title_size -= 1
	var shown_title := map_title
	if UI_FONT.get_string_size(shown_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > available:
		while not shown_title.is_empty() and UI_FONT.get_string_size(shown_title + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > available:
			shown_title = shown_title.substr(0, shown_title.length() - 1)
		shown_title += "…"
	draw_string(UI_FONT, Vector2(9, 17), shown_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(PAPER, 0.94))
	draw_string(
		UI_FONT,
		Vector2(size.x - 9, 17),
		live_text,
		HORIZONTAL_ALIGNMENT_RIGHT,
		-1,
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
			draw_circle(point, 3.4, MARKER_OUTLINE)
			draw_circle(point, 2.6, Color(color, 0.92))
		elif kind == "water_gate":
			draw_rect(Rect2(point - Vector2(3.1, 3.1), Vector2(6.2, 6.2)), MARKER_OUTLINE)
			draw_rect(Rect2(point - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(color, 0.96))
		elif kind == "gate":
			var back := PackedVector2Array([
				point + Vector2(0.0, -4.8),
				point + Vector2(4.8, 0.0),
				point + Vector2(0.0, 4.8),
				point + Vector2(-4.8, 0.0),
			])
			draw_colored_polygon(back, MARKER_OUTLINE)
			var points := PackedVector2Array([
				point + Vector2(0.0, -4.0),
				point + Vector2(4.0, 0.0),
				point + Vector2(0.0, 4.0),
				point + Vector2(-4.0, 0.0),
			])
			draw_colored_polygon(points, Color(color, 0.96))
		else:
			draw_circle(point, 3.8, MARKER_OUTLINE)
			draw_circle(point, 3.0, Color(color, 0.92))


func _draw_encounters() -> void:
	for site in battlefield.encounter_sites:
		var point := world_to_map(site["pos"] as Vector2)
		if not _map_rect.has_point(point):
			continue
		var used := bool(site.get("used", false))
		var good := bool(site.get("good", true))
		var color := Color("#8dde9c") if good else Color("#ef826c")
		# 深色底盘 + 彩色环：可用时环亮，冷却时环暗；色相继续区分增益/危险。
		draw_circle(point + Vector2(0.0, 0.8), ENCOUNTER_MARKER_RADIUS + 1.3, Color(0.0, 0.0, 0.0, 0.72))
		draw_circle(point, ENCOUNTER_MARKER_RADIUS, Color(0.035, 0.052, 0.052, 0.96))
		draw_circle(point, ENCOUNTER_MARKER_RADIUS, Color(color, 0.18 if used else 0.40))
		draw_arc(
			point,
			ENCOUNTER_MARKER_RADIUS - 0.6,
			0.0,
			TAU,
			20,
			Color(color, 0.48 if used else 0.96),
			2.0,
			true
		)
		if used:
			var progress := _encounter_refresh_progress(site)
			if progress > 0.0:
				draw_arc(
					point,
					ENCOUNTER_MARKER_RADIUS - 1.2,
					-PI * 0.5,
					-PI * 0.5 + TAU * progress,
					20,
					Color(GOLD, 0.96),
					2.4,
					true
				)
		# 不再把 512 SVG 缩到 14px：直接按小地图实际像素画矢量字形。
		_draw_encounter_glyph(point, good, used, color)
		if not used:
			_draw_available_beacon(point, color)


func _draw_encounter_glyph(point: Vector2, good: bool, used: bool, color: Color) -> void:
	# 形状区分增益/危险，亮度区分可用/冷却；描边保证在任何底图上都清晰。
	var glyph_color := Color(color.r, color.g, color.b, 1.0 if not used else 0.45)
	var thick := 2.8 if not used else 2.4
	var arm := ENCOUNTER_GLYPH_ARM
	if good:
		# 增益：加粗十字。
		var h_a := point + Vector2(-arm, 0.0)
		var h_b := point + Vector2(arm, 0.0)
		var v_a := point + Vector2(0.0, -arm)
		var v_b := point + Vector2(0.0, arm)
		draw_line(h_a, h_b, MARKER_OUTLINE, thick + 1.6, true)
		draw_line(v_a, v_b, MARKER_OUTLINE, thick + 1.6, true)
		draw_line(h_a, h_b, glyph_color, thick, true)
		draw_line(v_a, v_b, glyph_color, thick, true)
	else:
		# 危险：感叹号（竖杠 + 独立圆点），与十字形状完全不同，不只靠颜色区分。
		var top := point + Vector2(0.0, -arm)
		var bottom := point + Vector2(0.0, 1.2)
		var dot := point + Vector2(0.0, 3.3)
		draw_line(top, bottom, MARKER_OUTLINE, thick + 1.8, true)
		draw_circle(dot, thick * 0.6 + 0.8, MARKER_OUTLINE)
		draw_line(top, bottom, glyph_color, thick, true)
		draw_circle(dot, thick * 0.6, glyph_color)


func _draw_available_beacon(point: Vector2, color: Color) -> void:
	# 可用状态在标记上方加一枚向下的小三角，比原来的一字线更醒目。
	var tip_y := -ENCOUNTER_MARKER_RADIUS - 4.6
	var back := PackedVector2Array([
		point + Vector2(-3.4, tip_y - 3.4),
		point + Vector2(3.4, tip_y - 3.4),
		point + Vector2(0.0, tip_y + 1.0),
	])
	draw_colored_polygon(back, MARKER_OUTLINE)
	var front := PackedVector2Array([
		point + Vector2(-2.6, tip_y - 2.8),
		point + Vector2(2.6, tip_y - 2.8),
		point + Vector2(0.0, tip_y + 0.4),
	])
	draw_colored_polygon(front, Color(color, 0.98))


func _encounter_refresh_progress(site: Dictionary) -> float:
	var total := maxf(0.001, float(site.get("refresh_seconds", 1.0)))
	var remaining := clampf(float(site.get("refresh_remaining", 0.0)), 0.0, total)
	return 1.0 - remaining / total


func _draw_entities() -> void:
	_dot_count = 0
	for enemy in battlefield.enemies:
		if not bool(enemy.get("alive", false)):
			continue
		if bool(enemy.get("boss", false)):
			_append_dot(enemy["pos"] as Vector2, 6.4, Color("#f0a050"))
		elif bool(enemy.get("elite", false)):
			_append_dot(enemy["pos"] as Vector2, 4.0, Color("#e08055"))
		else:
			_append_dot(enemy["pos"] as Vector2, 2.8, Color("#c95a48"))
	for drop in battlefield.oil_drops:
		_append_pickup_point(drop["pos"] as Vector2, Color("#e6a642"), 1.4)
	for drop in battlefield.heal_drops:
		_append_pickup_point(drop["pos"] as Vector2, Color("#88b978"), 1.2)
	for drop in battlefield.scale_drops:
		_append_pickup_point(drop["pos"] as Vector2, battlefield._scale_color(str(drop.get("color", ""))), 1.6)
	_dot_batch.visible_instance_count = _dot_count
	_dot_outline_batch.visible_instance_count = _dot_count
	if _dot_count > 0:
		draw_multimesh(_dot_outline_batch, _dot_texture)
		draw_multimesh(_dot_batch, _dot_texture)


func _append_pickup_point(world_position: Vector2, color: Color, radius: float) -> void:
	var point := world_to_map(world_position)
	if _map_rect.has_point(point):
		_append_dot(world_position, radius * 2.2, Color(color, 0.88))


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
	var outline_size := size + 2.6
	_dot_outline_batch.set_instance_transform_2d(
		_dot_count,
		Transform2D(0.0, Vector2(outline_size, outline_size), 0.0, point)
	)
	_dot_outline_batch.set_instance_color(_dot_count, MARKER_OUTLINE)
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
	draw_circle(point, 5.8, MARKER_OUTLINE)
	draw_circle(point, 4.8, Color("#ffe2a1"))
	draw_line(point, point + facing * 7.2, MARKER_OUTLINE, 3.8, true)
	draw_line(point, point + facing * 7.2, Color("#fff5cf"), 2.2, true)
	draw_arc(point, 7.4, 0.0, TAU, 14, Color(GOLD, 0.72), 1.4, true)


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
