extends Node2D

const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const GROUND_TEXTURE := preload("res://scripts/core/ground_texture.gd")
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const VERMILION := Color("#c05a41")
const STAGE_WIDTH := 1280.0
const OBJECTIVE_ORDER := ["lamp", "stake", "banner"]
const TOUCH_CONTROLS_SCENE := preload("res://scenes/components/prologue_touch_controls.tscn")

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
var _tanghe_rows := 3
var _militia_rows := 3
var _objective: Label
var _progress: Label
var _continue: Button
var _skip: Button
var _narrative_timer: Timer
var _interaction_hint_timer: Timer
var _touch_controls: PrologueTouchControls
var _ui_root: Control
var _title_label: Label
var _subtitle_label: Label
var _source_label: Label
var _rule_line: ColorRect
var _hint_label: Label


func _ready() -> void:
	_stage_offset_cache = stage_offset_for_width(get_viewport().get_visible_rect().size.x)
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
	_tanghe_idle = GameData.texture(str(tanghe.get("sprite_sheet", "")))
	_tanghe_frames = int(tanghe.get("sprite_columns", 8))
	_tanghe_rows = int(tanghe.get("sprite_rows", 3))
	var militia := characters.get("wanglu", {}) as Dictionary
	_militia_walk = GameData.texture(str(militia.get("sprite_sheet", "")))
	_militia_frames = int(militia.get("sprite_columns", 8))
	_militia_rows = int(militia.get("sprite_rows", 3))


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
		if is_instance_valid(_touch_controls) and _touch_controls.move_vector.length_squared() > 0.001:
			input_vector = _touch_controls.move_vector
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
	_refresh_objective()
	if is_instance_valid(_touch_controls):
		_touch_controls.enabled = true
		_touch_controls.queue_redraw()
	narrative.show_line(_lines_by_id["narr_1386_03"] as Dictionary)
	_narrative_timer.start(5.0)


func _try_interact() -> void:
	var marker_id := _next_objective_marker()
	if marker_id.is_empty():
		return
	var interaction_range := 70.0
	if _is_portrait_view():
		interaction_range = 140.0
	if _player_pos.distance_to(_marker_position(marker_id)) > interaction_range:
		_objective.text = Locale.t("prologue.too_far")
		_interaction_hint_timer.start(1.4)
		return
	_interaction_hint_timer.stop()
	_done[marker_id] = true
	var line_id := "narr_1386_03"
	match marker_id:
		"stake":
			line_id = "narr_1386_04"
		"banner":
			line_id = "narr_1386_05"
	narrative.show_line(_lines_by_id[line_id] as Dictionary)
	_narrative_timer.start(5.5)
	_play_sfx("res://assets/audio/sfx_build.ogg")
	_refresh_progress()
	_refresh_objective()
	if _next_objective_marker().is_empty():
		_complete = true
		_continue.visible = true
		_objective.text = Locale.t("prologue.done")
		if is_instance_valid(_touch_controls):
			_touch_controls.enabled = false
			_touch_controls.queue_redraw()
		narrative.show_line(_lines_by_id["narr_1386_06"] as Dictionary)
		_narrative_timer.start(7.5)
		_play_sfx("res://assets/audio/sfx_win.ogg")


func _next_objective_marker() -> String:
	for marker_id in OBJECTIVE_ORDER:
		if not bool(_done[marker_id]):
			return marker_id
	return ""


func _refresh_objective() -> void:
	var marker_id := _next_objective_marker()
	if marker_id.is_empty():
		return
	_objective.text = Locale.t("prologue.goal_" + marker_id)


func _restore_objective_after_interaction_hint() -> void:
	if not _complete:
		_refresh_objective()


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
	_overlay_layer.name = "PrologueUI"
	add_child(_overlay_layer)
	var root := Control.new()
	root.name = "PrologueUIRoot"
	_ui_root = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(root)

	var title := _label(Locale.t("prologue.title"), 36, GOLD)
	_title_label = title
	UILayout.place(title, 54, 32, 600, 44)
	root.add_child(title)
	var subtitle := _label(Locale.t("prologue.subtitle"), 18, Color(PAPER, 0.90))
	_subtitle_label = subtitle
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UILayout.place(subtitle, 56, 76, 700, 26)
	root.add_child(subtitle)
	var rule := ColorRect.new()
	_rule_line = rule
	rule.color = Color(GOLD, 0.34)
	UILayout.place(rule, 54, 110, 430, 1)
	root.add_child(rule)
	var source := _label(Locale.t("prologue.source"), 11, Color(MUTED, 0.68))
	_source_label = source
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UILayout.place(source, 56, 120, 640, 26)
	root.add_child(source)

	# 目标行置于字幕条上方，避免与底部字幕重叠。
	_objective = _label("", 16, Color(PAPER, 0.94))
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UILayout.place(_objective, 306, 500, 640, 28, 0.5, 0.0)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_objective)
	_progress = _label("", 14, GOLD)
	UILayout.place(_progress, 54, 670, 300, 22, 0.0, 1.0)
	root.add_child(_progress)
	_refresh_progress()

	var hint := _label(Locale.t("prologue.hint"), 12, Color(MUTED, 0.66))
	_hint_label = hint
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
	_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as PrologueTouchControls
	_touch_controls.enabled = false
	_touch_controls.visible = _is_touch_platform()
	_touch_controls.interact_pressed.connect(_try_interact)
	_overlay_layer.add_child(_touch_controls)

	story = StoryOverlay.new()
	_overlay_layer.add_child(story)
	narrative = NarrativePlayer.new()
	add_child(narrative)
	_narrative_timer = Timer.new()
	_narrative_timer.one_shot = true
	_narrative_timer.timeout.connect(narrative.clear_line)
	add_child(_narrative_timer)
	_interaction_hint_timer = Timer.new()
	_interaction_hint_timer.one_shot = true
	_interaction_hint_timer.wait_time = 1.4
	_interaction_hint_timer.timeout.connect(_restore_objective_after_interaction_hint)
	add_child(_interaction_hint_timer)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_ui_layout(get_viewport().get_visible_rect().size, _css_view_size())


func _on_viewport_resized() -> void:
	_apply_ui_layout(get_viewport().get_visible_rect().size, _css_view_size())


func _css_view_size() -> Vector2:
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval("JSON.stringify([window.innerWidth, window.innerHeight])", true)
		var parsed: Variant = JSON.parse_string(str(raw))
		if parsed is Array and (parsed as Array).size() >= 2:
			return Vector2(float(parsed[0]), float(parsed[1]))
	var window_size := DisplayServer.window_get_size()
	return Vector2(window_size.x, window_size.y)


func _apply_ui_layout(view_size: Vector2, css_size: Vector2) -> void:
	if not is_instance_valid(_ui_root):
		return
	if css_size.x <= 0.0 or css_size.y <= 0.0:
		return
	var scale_x := view_size.x / css_size.x
	var scale_y := view_size.y / css_size.y
	var text_scale := minf(scale_x, scale_y)
	if css_size.x >= css_size.y:
		_title_label.add_theme_font_size_override("font_size", 36)
		UILayout.place(_title_label, 54, 32, 600, 44)
		_subtitle_label.add_theme_font_size_override("font_size", 18)
		UILayout.place(_subtitle_label, 56, 76, 700, 26)
		UILayout.place(_rule_line, 54, 110, 430, 1)
		_source_label.add_theme_font_size_override("font_size", 11)
		UILayout.place(_source_label, 56, 120, 640, 26)
		_objective.add_theme_font_size_override("font_size", 16)
		UILayout.place(_objective, 306, 500, 640, 28, 0.5, 0.0)
		_progress.add_theme_font_size_override("font_size", 14)
		UILayout.place(_progress, 54, 670, 300, 22, 0.0, 1.0)
		_hint_label.visible = true
		_hint_label.add_theme_font_size_override("font_size", 12)
		UILayout.place(_hint_label, 54, 704, 900, 20, 0.0, 1.0)
		_skip.add_theme_font_size_override("font_size", 16)
		UILayout.place(_skip, 1090, 34, 136, 40, 1.0, 0.0)
		_continue.add_theme_font_size_override("font_size", 16)
		UILayout.place(_continue, 990, 486, 224, 44, 1.0, 0.0)
		return
	# Canvas coordinates are larger than CSS pixels on narrow portrait screens.
	# Scale both type and hit areas by that ratio so the rendered controls stay legible.
	var margin_x := 18.0 * scale_x
	var safe_top := 0.0
	var safe_bottom := 0.0
	if OS.has_feature("web"):
		var raw_safe: Variant = JavaScriptBridge.eval(
			"""(() => { const e=document.createElement('div'); e.style.cssText='position:fixed;inset:0;visibility:hidden;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)'; document.body.appendChild(e); const s=getComputedStyle(e); const n=[s.paddingTop,s.paddingBottom].map(v=>parseFloat(v)||0); e.remove(); return JSON.stringify(n); })()""",
			true
		)
		var safe_values: Variant = JSON.parse_string(str(raw_safe))
		if safe_values is Array and safe_values.size() >= 2:
			safe_top = float(safe_values[0]) * scale_y
			safe_bottom = float(safe_values[1]) * scale_y
	var title_y := maxf(16.0, safe_top + 10.0 * scale_y)
	_title_label.add_theme_font_size_override("font_size", maxi(30, roundi(28.0 * text_scale)))
	var top_button_w := minf(120.0 * scale_x, view_size.x * 0.32)
	UILayout.place(_title_label, margin_x, title_y, maxf(160.0 * scale_x, view_size.x - margin_x * 2.0 - top_button_w - 12.0 * scale_x), 44.0 * scale_y)
	_subtitle_label.add_theme_font_size_override("font_size", maxi(20, roundi(18.0 * text_scale)))
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UILayout.place(_subtitle_label, margin_x, title_y + 48.0 * scale_y, view_size.x - margin_x * 2.0, 58.0 * scale_y)
	UILayout.place(_rule_line, margin_x, title_y + 112.0 * scale_y, 180.0 * scale_x, 3.0 * scale_y)
	_source_label.add_theme_font_size_override("font_size", maxi(14, roundi(13.0 * text_scale)))
	_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UILayout.place(_source_label, margin_x, title_y + 120.0 * scale_y, view_size.x - margin_x * 2.0, 46.0 * scale_y)
	_objective.add_theme_font_size_override("font_size", maxi(20, roundi(18.0 * text_scale)))
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UILayout.place(_objective, margin_x, view_size.y - 420.0 * scale_y - safe_bottom, view_size.x - margin_x * 2.0, 72.0 * scale_y)
	_progress.add_theme_font_size_override("font_size", maxi(16, roundi(14.0 * text_scale)))
	UILayout.place(_progress, margin_x, view_size.y - (230.0 * scale_y + safe_bottom), view_size.x - margin_x * 2.0, 42.0 * scale_y)
	_hint_label.visible = false
	var button_w := minf(156.0 * scale_x, view_size.x * 0.35)
	var button_h := 48.0 * scale_y
	_skip.add_theme_font_size_override("font_size", maxi(16, roundi(16.0 * text_scale)))
	UILayout.place(_skip, view_size.x - margin_x - button_w, title_y, button_w, button_h)
	_continue.add_theme_font_size_override("font_size", maxi(18, roundi(18.0 * text_scale)))
	UILayout.place(_continue, (view_size.x - button_w * 1.45) * 0.5, view_size.y - (290.0 * scale_y + safe_bottom), button_w * 1.45, button_h)


func _draw() -> void:
	var view_size := get_viewport().get_visible_rect().size
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
		ground_rect(get_viewport().get_visible_rect().size),
		true,
		Color(0.82, 0.86, 0.72, 1.0)
	)


func ground_rect(view_size: Vector2) -> Rect2:
	return Rect2(
		Vector2(0, 128),
		Vector2(view_size.x, maxf(592.0, view_size.y - 128.0))
	)


func _draw_water() -> void:
	var view_size := get_viewport().get_visible_rect().size
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
	var active := marker_id == _next_objective_marker()
	var pulse := 0.5 + 0.5 * sin(_time * 3.0 + position.x)
	if not done and not active:
		color = Color(color, 0.38)
	if done:
		draw_circle(position, 34.0, Color(color, 0.12))
		draw_arc(position, 37.0, 0.0, TAU, 30, Color(color, 0.88), 2.0, true)
	elif active:
		draw_circle(position, 42.0 + pulse * 9.0, Color(color, 0.13))
		draw_arc(position, 43.0 + pulse * 6.0, 0.0, TAU, 30, Color(color, 0.9), 3.0, true)
	else:
		draw_circle(position, 34.0, Color(color, 0.035))
		draw_arc(position, 37.0, 0.0, TAU, 30, Color(color, 0.15), 1.0, true)
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
		_draw_sprite_sheet_frame(
			_militia_walk,
			int(_time * 10.0) + i * 2,
			_militia_frames,
			Rect2(pos - Vector2(24, 30), Vector2(48, 48)),
			Color.WHITE,
			_militia_rows, 0
		)


func _draw_tanghe() -> void:
	var bob := sin(_time * 4.0) * 2.0
	var portrait := _is_portrait_view()
	var character_scale := 2.0 if portrait else 1.0
	var character_size := 80.0 * character_scale
	draw_circle(_player_pos + Vector2(0, 20) * character_scale, 24.0 * character_scale, Color(0, 0, 0, 0.26))
	draw_circle(_player_pos, 48.0 * character_scale, Color(0.94, 0.70, 0.30, 0.055))
	_draw_sprite_sheet_frame(
		_tanghe_idle,
		int(_time * 6.0),
		_tanghe_frames,
		Rect2(_player_pos - Vector2(character_size * 0.5, character_size * 0.575) + Vector2(0, bob * character_scale), Vector2.ONE * character_size),
		Color(1.05, 0.98, 0.82, 1.0),
		_tanghe_rows, 0
	)
	draw_circle(_player_pos + Vector2(0, -45 * character_scale), 5.0 * character_scale, Color(1.0, 0.81, 0.42, 0.55))
	var label_size := 20 if portrait else 14
	draw_string(UI_FONT, _player_pos + Vector2(-character_size * 0.5, character_size * 0.75), Locale.t("prologue.character_tanghe"), HORIZONTAL_ALIGNMENT_CENTER, character_size, label_size, Color(GOLD, 0.95))


func _is_portrait_view() -> bool:
	var view_size := get_viewport().get_visible_rect().size
	return view_size.y > view_size.x


func _draw_sprite_sheet_frame(
	texture: Texture2D,
	frame: int,
	frames: int,
	destination: Rect2,
	modulate: Color,
	rows: int = 1,
	row: int = 0
) -> void:
	if texture == null:
		return
	var frame_width := float(texture.get_width()) / float(maxi(1, frames))
	var cell_height := float(texture.get_height()) / float(maxi(1, rows))
	var frame_index := posmod(frame, maxi(1, frames))
	draw_texture_rect_region(
		texture,
		destination,
		Rect2(float(frame_index) * frame_width, float(row) * cell_height, frame_width, cell_height),
		modulate
	)


func _draw_vignette() -> void:
	var view_size := get_viewport().get_visible_rect().size
	draw_rect(Rect2(0, 0, view_size.x, 22), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(0, view_size.y - 22.0, view_size.x, 22), Color(0, 0, 0, 0.62))


func _marker_position(marker_id: String) -> Vector2:
	return marker_position(marker_id, get_viewport().get_visible_rect().size.x)


func _is_touch_platform() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or (OS.has_feature("web") and bool(GameSettings.web_capabilities.get("touch", false)))


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
	return stage_offset_for_width(get_viewport().get_visible_rect().size.x)


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
