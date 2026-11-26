extends Node2D

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const GROUND_TEXTURE := preload("res://scripts/core/ground_texture.gd")
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const VERMILION := Color("#c05a41")
const STAGE_WIDTH := 1280.0

var story: StoryOverlay
var narrative: NarrativePlayer
var _overlay_layer: CanvasLayer
var _narrative_data: Dictionary = {}
var _lines_by_id: Dictionary = {}
var _player_pos := Vector2(640.0, 480.0)
var _stage_offset_cache := 0.0
var _last_move := Vector2.RIGHT
var _active := false
var _complete := false
var _done := {"lamp": false, "stake": false, "banner": false}
var _time := 0.0
var _ground: Texture2D
var _tanghe_idle: Texture2D
var _militia_walk: Texture2D
var _tanghe_frames := 1
var _militia_frames := 1
var _objective: Label
var _progress: Label
var _continue: Button
var _skip: Button
var _narrative_timer: Timer


func _ready() -> void:
	_stage_offset_cache = stage_offset_for_width(get_viewport_rect().size.x)
	_player_pos = Vector2(_stage_offset_cache + STAGE_WIDTH * 0.5, 480.0)
	_ground = GROUND_TEXTURE.make(1386)
	_load_forge_actors()
	InputSetup.ensure_defaults()
	_narrative_data = GameData.load_json("res://data/narrative.json")
	for section in ["prologue", "main_intro"]:
		for line in _narrative_data.get(section, []) as Array:
			if line is Dictionary:
				_lines_by_id[str(line.get("id", ""))] = line
	_build_ui()
	var intro: Array = []
	var prologue_lines := _narrative_data.get("prologue", []) as Array
	for i in range(mini(2, prologue_lines.size())):
		intro.append(prologue_lines[i])
	story.start(intro, Locale.t("prologue.title"))
	story.finished.connect(_on_intro_finished)
	_play_sfx("res://assets/audio/sfx_wave.ogg")


func _load_forge_actors() -> void:
	var characters := GameData.get_characters()
	var tanghe := characters.get("tanghe", {}) as Dictionary
	_tanghe_idle = GameData.texture(str(tanghe.get("battle_idle", "")))
	_tanghe_frames = maxi(1, int(tanghe.get("battle_idle_frames", 1)))
	var militia := characters.get("wanglu", {}) as Dictionary
	_militia_walk = GameData.texture(str(militia.get("battle_walk", "")))
	_militia_frames = maxi(1, int(militia.get("battle_walk_frames", 1)))


func _process(delta: float) -> void:
	_time += delta
	var stage_offset := _stage_offset_x()
	if not is_equal_approx(stage_offset, _stage_offset_cache):
		_player_pos.x = shift_player_x_for_view_change(
			_player_pos.x,
			_stage_offset_cache + STAGE_WIDTH,
			stage_offset + STAGE_WIDTH
		)
		_stage_offset_cache = stage_offset
		_player_pos.x = clampf(
			_player_pos.x,
			stage_offset + 70.0,
			stage_offset + STAGE_WIDTH - 70.0
		)
	if _active and not story.visible and not _complete:
		var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_vector.length_squared() > 0.001:
			_last_move = input_vector.normalized()
			_player_pos += input_vector * 150.0 * delta
			var offset := _stage_offset_x()
			_player_pos.x = clampf(_player_pos.x, offset + 70.0, offset + STAGE_WIDTH - 70.0)
			_player_pos.y = clampf(_player_pos.y, 150.0, 630.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if story.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_finish_prologue()
		get_viewport().set_input_as_handled()
		return
	if _complete and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		_finish_prologue()
		get_viewport().set_input_as_handled()
		return
	if not _active:
		return
	if event.is_action_pressed("interact"):
		_try_interact()
		get_viewport().set_input_as_handled()


func _on_intro_finished() -> void:
	_active = true
	_objective.text = Locale.t("prologue.objective")
	narrative.show_line(_lines_by_id["narr_1386_03"] as Dictionary)
	_narrative_timer.start(5.0)


func _try_interact() -> void:
	for marker_id in ["lamp", "stake", "banner"]:
		if bool(_done[marker_id]):
			continue
		if _player_pos.distance_to(_marker_position(marker_id)) > 70.0:
			continue
		_done[marker_id] = true
		var line_id := "narr_1386_03"
		var banner := Locale.t("prologue.lamp")
		match marker_id:
			"stake":
				line_id = "narr_1386_04"
				banner = Locale.t("prologue.stake")
			"banner":
				line_id = "narr_1386_05"
				banner = Locale.t("prologue.banner")
		narrative.show_line(_lines_by_id[line_id] as Dictionary)
		_narrative_timer.start(5.5)
		_play_sfx("res://assets/audio/sfx_build.ogg")
		_refresh_progress()
		if bool(_done["lamp"]) and bool(_done["stake"]) and bool(_done["banner"]):
			_complete = true
			_continue.visible = true
			_objective.text = Locale.t("prologue.done")
			narrative.show_line(_lines_by_id["narr_1386_06"] as Dictionary)
			_narrative_timer.start(7.5)
			_play_sfx("res://assets/audio/sfx_win.ogg")
		return


func _refresh_progress() -> void:
	var done := 0
	for value in _done.values():
		if bool(value):
			done += 1
	_progress.text = Locale.t("prologue.progress", {"done": done})


func _finish_prologue() -> void:
	SaveSystem.data["prologue_seen"] = true
	SaveSystem.autosave({"last_mode": "select", "prologue_seen": true})
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")


func _build_ui() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 7
	add_child(_overlay_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(root)

	var title := _label(Locale.t("prologue.title"), 36, GOLD)
	UILayout.place(title, 54, 32, 600, 44)
	root.add_child(title)
	var subtitle := _label(Locale.t("prologue.subtitle"), 18, Color(PAPER, 0.90))
	UILayout.place(subtitle, 56, 76, 700, 26)
	root.add_child(subtitle)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.34)
	UILayout.place(rule, 54, 110, 430, 1)
	root.add_child(rule)
	var source := _label(Locale.t("prologue.source"), 11, Color(MUTED, 0.68))
	UILayout.place(source, 56, 120, 640, 26)
	root.add_child(source)

	# 目标行置于字幕条上方，避免与底部字幕重叠。
	_objective = _label("", 16, Color(PAPER, 0.94))
	UILayout.place(_objective, 306, 500, 640, 28, 0.5, 0.0)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_objective)
	_progress = _label("", 14, GOLD)
	UILayout.place(_progress, 54, 670, 300, 22, 0.0, 1.0)
	root.add_child(_progress)
	_refresh_progress()

	var hint := _label(Locale.t("prologue.hint"), 12, Color(MUTED, 0.66))
	UILayout.place(hint, 54, 704, 900, 20, 0.0, 1.0)
	root.add_child(hint)
	_skip = _button(Locale.t("prologue.skip"), false)
	UILayout.place(_skip, 1090, 34, 136, 40, 1.0, 0.0)
	_skip.pressed.connect(_finish_prologue)
	root.add_child(_skip)

	_continue = _button(Locale.t("prologue.enter"), true)
	UILayout.place(_continue, 990, 486, 224, 44, 1.0, 0.0)
	_continue.visible = false
	_continue.pressed.connect(_finish_prologue)
	root.add_child(_continue)

	story = StoryOverlay.new()
	_overlay_layer.add_child(story)
	narrative = NarrativePlayer.new()
	add_child(narrative)
	_narrative_timer = Timer.new()
	_narrative_timer.one_shot = true
	_narrative_timer.timeout.connect(narrative.clear_line)
	add_child(_narrative_timer)


func _draw() -> void:
	var view_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view_size), Color("#0b1517"))
	_draw_ground()
	_draw_water()
	_draw_fort_outline()
	_draw_marker("lamp", _marker_position("lamp"), Color("#e2b85c"))
	_draw_marker("stake", _marker_position("stake"), Color("#b99660"))
	_draw_marker("banner", _marker_position("banner"), Color("#b54f3d"))
	_draw_militia()
	_draw_tanghe()
	_draw_vignette()


func _draw_ground() -> void:
	if _ground == null:
		return
	draw_texture_rect(
		_ground,
		ground_rect(get_viewport_rect().size),
		true,
		Color(0.82, 0.86, 0.72, 1.0)
	)


func ground_rect(view_size: Vector2) -> Rect2:
	return Rect2(
		Vector2(0, 128),
		Vector2(view_size.x, maxf(592.0, view_size.y - 128.0))
	)


func _draw_water() -> void:
	var view_size := get_viewport_rect().size
	draw_rect(water_rect(view_size), Color("#15313a"))
	for i in range(16):
		var y := float(i) * 9.0 + sin(_time * 1.2 + i) * 2.5
		draw_line(Vector2(0, y + 10), Vector2(view_size.x, y + 4), Color(0.30, 0.50, 0.50, 0.11), 1.0)
	draw_line(Vector2(0, 133), Vector2(view_size.x, 128), Color("#7e8068"), 5.0)
	for i in range(24):
		var x := float(i) * 56.0 + fmod(_time * 9.0 + i * 13.0, view_size.x)
		draw_line(Vector2(x, 31), Vector2(view_size.x - 100.0, 31), Color(0.72, 0.65, 0.45, 0.16), 1.0)


func water_rect(view_size: Vector2) -> Rect2:
	return Rect2(0, 0, view_size.x, 136)


func _draw_fort_outline() -> void:
	if not bool(_done["stake"]):
		return
	var color := Color(0.90, 0.74, 0.42, 0.48)
	var offset := _stage_offset_x()
	var points := [
		Vector2(748 + offset, 310), Vector2(1148 + offset, 310),
		Vector2(1148 + offset, 590), Vector2(748 + offset, 590),
		Vector2(748 + offset, 310),
	]
	for i in range(points.size() - 1):
		draw_dashed_line(points[i], points[i + 1], color, 2.0, 8.0)
	for i in range(8):
		var x := 748.0 + offset + float(i) * 50.0
		draw_line(Vector2(x, 310), Vector2(x, 298), color, 2.0)


func _draw_marker(marker_id: String, position: Vector2, color: Color) -> void:
	var done := bool(_done[marker_id])
	var pulse := 0.5 + 0.5 * sin(_time * 3.0 + position.x)
	if done:
		draw_circle(position, 34.0, Color(color, 0.12))
		draw_arc(position, 37.0, 0.0, TAU, 30, Color(color, 0.88), 2.0, true)
	else:
		draw_circle(position, 38.0 + pulse * 8.0, Color(color, 0.07))
		draw_arc(position, 40.0 + pulse * 5.0, 0.0, TAU, 30, Color(color, 0.32), 1.0, true)
	match marker_id:
		"lamp":
			draw_rect(Rect2(position + Vector2(-12, 5), Vector2(24, 31)), Color("#776b50"))
			draw_rect(Rect2(position + Vector2(-16, 33), Vector2(32, 5)), Color("#5f5845"))
			draw_circle(position + Vector2(0, -4), 13.0 if done else 9.0, color)
			draw_circle(position + Vector2(0, -4), 21.0 if done else 13.0, Color(color, 0.16))
		"stake":
			draw_rect(Rect2(position - Vector2(3, 31), Vector2(6, 58)), Color("#806344"))
			draw_line(position - Vector2(20, 22), position + Vector2(20, 22), color, 4.0)
			draw_line(position - Vector2(18, 22), position + Vector2(18, 31), Color(color, 0.55), 2.0)
		"banner":
			draw_line(position - Vector2(5, 46), position + Vector2(5, 46), Color("#7d6044"), 5.0)
			var wave := sin(_time * 3.7) * 5.0
			var flag := PackedVector2Array([
				position + Vector2(5, -42),
				position + Vector2(72, -30 + wave),
				position + Vector2(58, 4 + wave),
				position + Vector2(5, -2),
			])
			draw_colored_polygon(flag, Color(color, 0.82 if done else 0.44))


func _draw_militia() -> void:
	if not bool(_done["banner"]):
		return
	var offset := _stage_offset_x()
	var positions: Array[Vector2] = [
		Vector2(420 + offset, 548),
		Vector2(474 + offset, 574),
		Vector2(540 + offset, 552),
		Vector2(602 + offset, 584),
	]
	for i in range(positions.size()):
		var pos: Vector2 = positions[i] + Vector2(0, sin(_time * 2.0 + i) * 2.0)
		draw_circle(pos + Vector2(0, 18), 15.0, Color(0, 0, 0, 0.20))
		_draw_forge_frame(
			_militia_walk,
			int(_time * 10.0) + i * 2,
			_militia_frames,
			Rect2(pos - Vector2(24, 30), Vector2(48, 48)),
			Color.WHITE
		)


func _draw_tanghe() -> void:
	var bob := sin(_time * 4.0) * 2.0
	draw_circle(_player_pos + Vector2(0, 20), 24.0, Color(0, 0, 0, 0.26))
	draw_circle(_player_pos, 48.0, Color(0.94, 0.70, 0.30, 0.055))
	_draw_forge_frame(
		_tanghe_idle,
		int(_time * 6.0),
		_tanghe_frames,
		Rect2(_player_pos - Vector2(40, 46) + Vector2(0, bob), Vector2(80, 80)),
		Color(1.05, 0.98, 0.82, 1.0)
	)
	draw_circle(_player_pos + Vector2(0, -45), 5.0, Color(1.0, 0.81, 0.42, 0.55))
	draw_string(UI_FONT, _player_pos + Vector2(-40, 60), Locale.t("prologue.character_tanghe"), HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color(GOLD, 0.85))


func _draw_forge_frame(
	texture: Texture2D,
	frame: int,
	frames: int,
	destination: Rect2,
	modulate: Color
) -> void:
	if texture == null:
		return
	var frame_width := float(texture.get_width()) / float(maxi(1, frames))
	var cell_height := float(texture.get_height())
	var frame_index := posmod(frame, maxi(1, frames))
	draw_texture_rect_region(
		texture,
		destination,
		Rect2(float(frame_index) * frame_width, 0.0, frame_width, cell_height),
		modulate
	)


func _draw_vignette() -> void:
	var view_size := get_viewport_rect().size
	draw_rect(Rect2(0, 0, view_size.x, 22), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(0, view_size.y - 22.0, view_size.x, 22), Color(0, 0, 0, 0.62))


func _marker_position(marker_id: String) -> Vector2:
	return marker_position(marker_id, get_viewport_rect().size.x)


func marker_position(marker_id: String, view_width: float) -> Vector2:
	var offset := stage_offset_for_width(view_width)
	match marker_id:
		"lamp":
			return Vector2(886.0 + offset, 218)
		"stake":
			return Vector2(1058.0 + offset, 410)
		"banner":
			return Vector2(504.0 + offset, 486)
	return Vector2.ZERO


func _stage_offset_x() -> float:
	return stage_offset_for_width(get_viewport_rect().size.x)


func stage_offset_for_width(view_width: float) -> float:
	return maxf(0.0, (view_width - STAGE_WIDTH) * 0.5)


func shift_player_x_for_view_change(player_x: float, previous_width: float, current_width: float) -> float:
	return player_x + stage_offset_for_width(current_width) - stage_offset_for_width(previous_width)


func _play_sfx(path: String) -> void:
	if DisplayServer.get_name() == "headless" or not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path) as AudioStream
	player.volume_db = -80.0 if GameSettings.sfx_volume <= 0.001 else linear_to_db(GameSettings.sfx_volume)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", PAPER)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(GOLD, 0.15 if primary else 0.06)
	box.border_color = Color(GOLD, 0.70 if primary else 0.30)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	button.add_theme_stylebox_override("normal", box)
	return button
