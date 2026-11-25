extends Node2D

const FIXED_STEP := 1.0 / 60.0
const MAX_LEVEL := 30
const BASE_VIEW := Vector2(1280.0, 720.0)
const ATTACK_BUFFER_DURATION := 0.18
const HUD_REFRESH_INTERVAL := 0.10
const MAX_CATCHUP_STEPS_NATIVE := 6
const MAX_CATCHUP_STEPS_WEB := 2
const FLOW_CELLS_PER_FRAME_WEB := 320
const FLOW_CELLS_PER_FRAME_NATIVE := 384
const GAMEPLAY_CURSOR_PATH := "res://assets/ui/watch_cursor.webp"
const GAMEPLAY_CURSOR_HOTSPOT := Vector2(3, 0)
const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.woff2")
const PANEL_TEXTURE := preload("res://assets/ui/panel_dark.webp")
const ICON_KATANA := "res://assets/icons/game_icons/wpn_katana.svg"
const ICON_BOW := "res://assets/icons/game_icons/wpn_bow.svg"
const ICON_DRAGON := "res://assets/icons/game_icons/wpn_dragon_lantern.svg"
const ICON_OIL := "res://assets/icons/game_icons/ui_lantern.svg"
const SFX_HIT := preload("res://assets/audio/sfx_hit.ogg")
const SFX_FIRE := preload("res://assets/audio/sfx_fire.ogg")
const SFX_WAVE := preload("res://assets/audio/sfx_wave.ogg")
const SFX_WIN := preload("res://assets/audio/sfx_win.ogg")
const SFX_LOSE := preload("res://assets/audio/sfx_lose.ogg")
const SFX_ALARM := preload("res://assets/audio/sfx_alarm.ogg")
const SFX_PICKUP := preload("res://assets/audio/sfx_pickup.ogg")
const SFX_EVENT := preload("res://assets/audio/sfx_event.ogg")
const SFX_ENEMY_HIT := preload("res://assets/audio/sfx_enemy_hit.ogg")
const SFX_ENEMY_KILL := preload("res://assets/audio/sfx_enemy_kill.ogg")
const SFX_ELITE_KILL := preload("res://assets/audio/sfx_elite_kill.ogg")
const SFX_LEVEL_UP := preload("res://assets/audio/sfx_level_up.ogg")
const SFX_DASH := preload("res://assets/audio/sfx_dash.ogg")
const SFX_BOSS := preload("res://assets/audio/sfx_boss.ogg")
const PAPER := Color("#efe1c2")
const MUTED := Color("#baa98a")
const GOLD := Color("#e1b35a")
const VERMILION := Color("#c05a41")
const GDA_CALLABLE := ["debug_prepare_capture"]
const TOWER_SLOTS := [
	Vector2(-250, -120), Vector2(250, -120), Vector2(-300, 150),
	Vector2(300, 150), Vector2(0, -290), Vector2(-390, 20), Vector2(390, 20),
	Vector2(-180, 290), Vector2(180, 290),
]

var battlefield: Battlefield
var camera: Camera2D
var hud: RunHUD
var touch_controls: TouchControls
var narrative: NarrativePlayer
var story: StoryOverlay
var tutorial_overlay: TutorialOverlay
var level_up_overlay: LevelUpOverlay
var shop_overlay: ShopOverlay
var overlay_layer: CanvasLayer
var pause_overlay: Control
var result_overlay: Control
var codex_overlay: Control
var result_title: Label
var result_body: Label
var result_stats: Label
var result_unlocks: Label

var weapon_defs: Dictionary = {}
var passive_defs: Dictionary = {}
var enemy_defs: Dictionary = {}
var mercenary_defs: Dictionary = {}
var shop_data: Dictionary = {}
var character_def: Dictionary = {}
var map_def: Dictionary = {}
var map_id := "tideland"
var wave_data: Dictionary = {}
var narrative_data: Dictionary = {}
var _lines_by_id: Dictionary = {}
var _phase_list: Array = []
var _scale_events: Array = []
var _event_lines: Array = []

var player: Dictionary = {}
var weapons: Array[Dictionary] = []
var passives: Dictionary = {}
var card_levels: Dictionary = {}
var used_events: Dictionary = {}
var event_stat_bonuses: Dictionary = {}
var active_skills: Dictionary = {}
var skill_timers: Dictionary = {}
var scales: Array[String] = []
var elapsed := 0.0
var duration := 960.0
var boss_second := 930.0
var _difficulty_curve: Dictionary = {}
var xp := 0.0
var xp_need := 15.0
var level := 1
var kills := 0
var merit := 0
var run_coin := 0
var oil_tick := 30.0
var _dash_cd := 0.0
var _dash_timer := 0.0
var _dash_dir := Vector2.RIGHT
var _dash_buff := 0.0
var _invuln := 0.0
var _last_move := Vector2.RIGHT
var _aim_direction := Vector2.RIGHT
var _attack_held := false
var _attack_buffer := 0.0
var _auto_attack := false
var _mouse_screen_pos := Vector2.ZERO
var _has_mouse_screen_pos := false
var _move_trail_timer := 0.0
var _event_enemy_speed_mult := 1.0
var _accum := 0.0
var _spawn_accum := 0.0
var _hud_refresh_accum := 0.0
var _web_perf_probe := false
var _web_perf_timer := 0.0
var _last_steps := 0
var _last_step_usec := 0
var _last_world_usec := 0
var _last_hud_usec := 0
var _last_flow_usec := 0
var _event_line_index := 0
var _scale_event_index := 0
var _boss_spawned := false
var _boss_defeated := false
var _boss_warned := false
var _paused := true
var _game_over := false
var _victory_started := false
var _story_mode := "intro"
var _pending_levels := 0
var _next_shop_time := 120.0
var _shop_open := false
var _current_shop_offers: Array[Dictionary] = []
var mercenaries: Array[String] = []
var _current_upgrade_options: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _towers_built := 0
var _narrative_timer: Timer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _kill_sfx_cd := 0.0
var _wade_sfx_cd := 0.0
var _pickup_sfx_cd := 0.0
var _result_recorded := false
var _run_start_merit := 0
var _run_started := false
var _tutorial_first_run := false
var _gameplay_cursor: Texture2D
var _gameplay_cursor_active := false


func _ready() -> void:
	InputSetup.ensure_defaults()
	_rng.seed = 20261123
	_run_start_merit = int(SaveSystem.data.get("total_merit", 0))
	_load_data()
	_build_world()
	_build_ui()
	_setup_player()
	AudioBus.play_battle_bgm()
	_schedule_intro()
	_enable_web_perf_probe()


func _process(delta: float) -> void:
	_sync_gameplay_cursor()
	if _paused or _game_over:
		return
	var max_steps := max_catchup_steps()
	_accum = minf(_accum + delta, FIXED_STEP * float(max_steps))
	var steps := 0
	while _accum >= FIXED_STEP and steps < max_steps:
		_step(FIXED_STEP)
		_accum -= FIXED_STEP
		steps += 1
	_last_steps = steps
	var flow_started := Time.get_ticks_usec()
	var flow_cells := (
		FLOW_CELLS_PER_FRAME_WEB
		if GameSettings.is_web_platform()
		else FLOW_CELLS_PER_FRAME_NATIVE
	)
	battlefield.advance_flow_field(flow_cells)
	_last_flow_usec = Time.get_ticks_usec() - flow_started
	_update_camera(delta)
	_hud_refresh_accum += delta
	if _hud_refresh_accum >= HUD_REFRESH_INTERVAL:
		_hud_refresh_accum = 0.0
		var hud_started := Time.get_ticks_usec()
		hud.update_hud(_hud_state())
		_last_hud_usec = Time.get_ticks_usec() - hud_started
	_publish_web_perf(delta)


func max_catchup_steps() -> int:
	return MAX_CATCHUP_STEPS_WEB if GameSettings.is_web_platform() else MAX_CATCHUP_STEPS_NATIVE


func _enable_web_perf_probe() -> void:
	if not OS.has_feature("web"):
		return
	_web_perf_probe = bool(JavaScriptBridge.eval(
		"new URLSearchParams(location.search).has('perf')",
		true
	))


func _publish_web_perf(delta: float) -> void:
	if not _web_perf_probe:
		return
	_web_perf_timer -= delta
	if _web_perf_timer > 0.0:
		return
	_web_perf_timer = 1.0
	var payload := {
		"fps": Engine.get_frames_per_second(),
		"steps": _last_steps,
		"max_steps": max_catchup_steps(),
		"step_ms": snappedf(float(_last_step_usec) / 1000.0, 0.01),
		"world_ms": snappedf(float(_last_world_usec) / 1000.0, 0.01),
		"flow_ms": snappedf(float(_last_flow_usec) / 1000.0, 0.01),
		"hud_ms": snappedf(float(_last_hud_usec) / 1000.0, 0.01),
		"enemies": battlefield.alive_count(),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"elapsed": snappedf(elapsed, 0.1),
	}
	JavaScriptBridge.eval("window.__watchPerf = %s;" % JSON.stringify(payload), true)


func _unhandled_input(event: InputEvent) -> void:
	if _game_over or _shop_open:
		return
	if is_instance_valid(codex_overlay):
		return
	if is_instance_valid(tutorial_overlay) and tutorial_overlay.visible:
		return
	if story.visible or level_up_overlay.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_set_pause(not _paused)
		get_viewport().set_input_as_handled()
		return
	if not _gameplay_input_allowed():
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		_mouse_screen_pos = mouse_button.position
		_has_mouse_screen_pos = true
	elif event is InputEventMouseMotion:
		_mouse_screen_pos = (event as InputEventMouseMotion).position
		_has_mouse_screen_pos = true
	if event.is_action_pressed("toggle_auto_attack") and not (event is InputEventKey and (event as InputEventKey).echo):
		_auto_attack = not _auto_attack
		_release_attack()
		hud.update_hud(_hud_state())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("attack") and not (event is InputEventKey and (event as InputEventKey).echo):
		_attack_buffer = ATTACK_BUFFER_DURATION
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_codex"):
		_open_codex()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("dash"):
		_try_dash()
		get_viewport().set_input_as_handled()


func _gameplay_input_allowed() -> bool:
	if not _run_started or _paused or _game_over or _shop_open:
		return false
	if is_instance_valid(story) and story.visible:
		return false
	if is_instance_valid(tutorial_overlay) and tutorial_overlay.visible:
		return false
	if is_instance_valid(level_up_overlay) and level_up_overlay.visible:
		return false
	if is_instance_valid(codex_overlay):
		return false
	if is_instance_valid(pause_overlay) and pause_overlay.visible:
		return false
	if is_instance_valid(result_overlay) and result_overlay.visible:
		return false
	return true


func _open_codex() -> void:
	AudioBus.play_confirm()
	_paused = true
	_release_attack()
	codex_overlay = (load("res://scenes/codex.tscn") as PackedScene).instantiate()
	codex_overlay.embedded = true
	codex_overlay.z_index = 80
	overlay_layer.add_child(codex_overlay)
	codex_overlay.closed.connect(_close_codex)
	_sync_gameplay_cursor()


func _close_codex() -> void:
	codex_overlay = null
	_paused = _game_over
	_sync_gameplay_cursor()


func _load_data() -> void:
	weapon_defs = GameData.get_weapons()
	passive_defs = GameData.get_passives()
	enemy_defs = GameData.get_enemies()
	mercenary_defs = GameData.get_mercenaries()
	shop_data = GameData.get_shop()
	var characters := GameData.get_characters()
	var selected_character := str(SaveSystem.data.get("selected_character", "wanglu"))
	if not characters.has(selected_character):
		selected_character = "wanglu"
	character_def = characters.get(selected_character, {}) as Dictionary
	var maps := GameData.get_maps()
	var selected_map := str(SaveSystem.data.get("selected_map", "tideland"))
	if not maps.has(selected_map):
		selected_map = "tideland"
	map_id = selected_map
	map_def = (maps.get(selected_map, {}) as Dictionary).duplicate(true)
	map_def["id"] = map_id
	wave_data = GameData.load_json("res://data/waves.json")
	narrative_data = GameData.load_json("res://data/narrative.json")
	duration = float(wave_data.get("duration_seconds", 960.0))
	boss_second = float(wave_data.get("boss_second", 930.0))
	_phase_list = wave_data.get("phases", []) as Array
	_difficulty_curve = wave_data.get("difficulty", {}) as Dictionary
	_scale_events = wave_data.get("scale_events", []) as Array
	_event_lines = wave_data.get("event_lines", []) as Array
	_next_shop_time = float(shop_data.get("interval_seconds", 120.0))
	for section in ["prologue", "main_intro", "field_notes", "epilogue"]:
		for line in narrative_data.get(section, []) as Array:
			if line is Dictionary:
				_lines_by_id[str(line.get("id", ""))] = line


func _build_world() -> void:
	battlefield = Battlefield.new()
	battlefield.name = "Battlefield"
	add_child(battlefield)
	battlefield.setup(20261123, map_def)
	battlefield.player_hit.connect(_on_player_hit)
	battlefield.enemy_killed.connect(_on_enemy_killed)
	battlefield.xp_collected.connect(_on_xp_collected)
	battlefield.oil_collected.connect(_on_oil_collected)
	battlefield.heal_collected.connect(_on_heal_collected)
	battlefield.scale_collected.connect(_on_scale_collected)
	battlefield.boss_spawned.connect(_on_boss_spawned)
	battlefield.boss_defeated.connect(_on_boss_defeated)
	battlefield.tower_destroyed.connect(_on_tower_destroyed)
	battlefield.tower_damaged.connect(_on_tower_damaged)
	battlefield.ally_support.connect(_on_ally_support)

	camera = Camera2D.new()
	camera.name = "RunCamera"
	camera.position_smoothing_enabled = false
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(battlefield.map_layout.world_size.x)
	camera.limit_bottom = int(battlefield.map_layout.world_size.y)
	add_child(camera)
	camera.make_current()
	# 反馈系统的 Trauma 震动写入 camera.offset（不干扰平滑跟随与画布坐标）
	FeedbackManager.bind_camera(camera)


func _build_ui() -> void:
	hud = RunHUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.bind_world(battlefield, map_def, camera)
	touch_controls = TouchControls.new()
	hud.add_child(touch_controls)
	touch_controls.dash_requested.connect(_on_touch_dash_requested)
	narrative = NarrativePlayer.new()
	narrative.name = "Narrative"
	add_child(narrative)
	overlay_layer = CanvasLayer.new()
	overlay_layer.name = "Overlays"
	overlay_layer.layer = 7
	add_child(overlay_layer)
	story = StoryOverlay.new()
	overlay_layer.add_child(story)
	story.finished.connect(_on_story_finished)
	tutorial_overlay = TutorialOverlay.new()
	tutorial_overlay.z_index = 65
	overlay_layer.add_child(tutorial_overlay)
	tutorial_overlay.closed.connect(_on_tutorial_closed)
	level_up_overlay = LevelUpOverlay.new()
	overlay_layer.add_child(level_up_overlay)
	level_up_overlay.chosen.connect(_on_upgrade_chosen)
	shop_overlay = ShopOverlay.new()
	overlay_layer.add_child(shop_overlay)
	shop_overlay.buy_requested.connect(_on_shop_buy)
	shop_overlay.reroll_requested.connect(_on_shop_reroll)
	shop_overlay.closed.connect(_on_shop_closed)
	_build_pause_overlay()
	_build_result_overlay()
	_narrative_timer = Timer.new()
	_narrative_timer.one_shot = true
	_narrative_timer.timeout.connect(narrative.clear_line)
	add_child(_narrative_timer)
	for i in range(8):
		var sfx := AudioStreamPlayer.new()
		sfx.bus = "Master"
		add_child(sfx)
		_sfx_players.append(sfx)


func _setup_player() -> void:
	var start_weapon := str(character_def.get("starting_weapon", "saber"))
	var start_passive := str(character_def.get("starting_passive", "gaiters"))
	var spawn_position := battlefield.player_spawn_position()
	player = {
		"pos": spawn_position,
		"radius": 18.0,
		"hp": float(character_def.get("hp", 100.0)),
		"max_hp": float(character_def.get("hp", 100.0)),
		"base_max_hp": float(character_def.get("hp", 100.0)),
		"base_speed": float(character_def.get("speed", 154.0)),
		"speed": float(character_def.get("speed", 154.0)),
		"base_pickup": float(character_def.get("pickup_radius", 88.0)),
		"pickup_radius": float(character_def.get("pickup_radius", 88.0)),
		"base_oil_max": int(character_def.get("oil_max", 6)),
		"oil_max": int(character_def.get("oil_max", 6)),
		"oil": int(character_def.get("oil_max", 6)),
		"damage_mult": 1.0,
		"speed_mult": 1.0,
		"pickup_mult": 1.0,
		"area_mult": 1.0,
		"cooldown_mult": 1.0,
		"armor": 0.0,
		"crit": 0.05,
		"xp_mult": 1.0,
		"regen": 0.0,
		"revive": 0,
		"shield": 0.0,
		"shield_max": 0.0,
		"shield_regen": 0.0,
		"thorns": 0.0,
		"lifesteal": 0.0,
		"dodge": 0.0,
		"execute_below": 0.0,
		"luck": 0.0,
		"gold_mult": 1.0,
		"light_mult": 1.0,
		"projectile_speed_mult": 1.0,
		"knockback_mult": 1.0,
		"wade_bonus": 0.0,
		"dash_cd_mult": 1.0,
		"skill_cd_mult": 1.0,
		"dark": false,
		"light_radius": 232.0 * float(map_def.get("light_scale", 1.0)),
		"facing": Vector2.RIGHT,
	}
	_add_weapon(start_weapon)
	passives[start_passive] = 1
	run_coin = int(shop_data.get("starting_coin", 0))
	_recompute_stats()
	battlefield.set_player_sprites(character_def)
	battlefield.set_meta("player_tint", Color(str(character_def.get("tint", "#ffffff"))))
	battlefield.set_meta("ground_tint", Color(str(map_def.get("ground_tint", "#ebf0d0"))))
	battlefield.set_meta("light_radius", float(player["light_radius"]))
	battlefield.enemy_hp_mult = float(map_def.get("enemy_hp_mult", 1.0))
	_sync_towers()
	xp_need = _xp_need_for_level(1)
	camera.position = player["pos"] as Vector2
	hud.update_hud(_hud_state())
	SaveSystem.autosave({"last_mode": "run"})


func _sync_towers() -> void:
	"""按 player.tower_count 补齐箭塔：开局布两座，后续靠三选一「增筑」扩到上限。"""
	if battlefield == null or player.is_empty():
		return
	var desired := mini(int(player.get("tower_count", 2)), TOWER_SLOTS.size())
	if desired <= _towers_built:
		return
	var center := player["pos"] as Vector2
	while _towers_built < desired:
		var offset: Vector2 = TOWER_SLOTS[_towers_built]
		battlefield.spawn_tower("watchtower", center + offset)
		_towers_built += 1


func _on_tower_destroyed(tower_id: String, _world_position: Vector2) -> void:
	var definition := battlefield.tower_definition(tower_id)
	var label := GameData.loc(definition, "name")
	if label.is_empty():
		label = Locale.t("tower.destroyed_fallback")
	hud.show_banner(Locale.t("tower.destroyed"), label, 2.6)
	_play_sfx(SFX_ALARM, 0.86, 0.72)


func _on_tower_damaged(_tower_id: String, _ratio: float) -> void:
	# 塔受击的即时反馈交给 FeedbackManager 的火花与震动，
	# 这里不叠加 UI，避免 HUD 抖动。
	pass


func _schedule_intro() -> void:
	_story_mode = "intro"
	_paused = true
	_release_attack()
	# 叙事重写：首次守夜播 4 句开场钩子；重玩仅播王陆自白 1 句，避免重复阅读打断游玩。
	var intro: Array = []
	if bool(SaveSystem.data.get("intro_seen", false)):
		var quick: Variant = _lines_by_id.get("narr_1559_02")
		if quick != null:
			intro.append(quick)
	else:
		intro = narrative_data.get("main_intro", []) as Array
	story.start(intro, Locale.t("story.main_heading"))


func _on_story_finished() -> void:
	if _story_mode == "intro":
		SaveSystem.data["intro_seen"] = true
		SaveSystem.autosave({"intro_seen": true})
		if not bool(SaveSystem.data.get("tutorial_seen", false)):
			_open_tutorial(true)
		else:
			_start_gameplay()
	elif _story_mode == "epilogue":
		_show_result(true)


func _open_tutorial(first_run: bool) -> void:
	if _game_over:
		return
	_paused = true
	_release_attack()
	pause_overlay.visible = false
	_tutorial_first_run = first_run
	tutorial_overlay.open(first_run)
	_sync_gameplay_cursor()


func _on_tutorial_closed(_skipped: bool) -> void:
	SaveSystem.complete_tutorial()
	if _tutorial_first_run:
		_tutorial_first_run = false
		_start_gameplay()
	else:
		_set_pause(true)
	_sync_gameplay_cursor()


func _start_gameplay() -> void:
	_run_started = true
	_paused = false
	pause_overlay.visible = false
	var preset := GameData.loc(character_def, "preset_name")
	var character_line := str(character_def.get("era", "1559"))
	if not preset.is_empty():
		character_line += " · " + preset
	character_line += " · " + GameData.loc(character_def, "name")
	hud.update_hud(_hud_state())
	hud.show_banner(
		GameData.loc(map_def, "name"),
		character_line,
		3.4
	)
	_play_sfx(SFX_WAVE)
	_sync_gameplay_cursor()


func _step(delta: float) -> void:
	var step_started := Time.get_ticks_usec()
	elapsed += delta
	_update_player(delta)
	_update_oil(delta)
	_update_weapons(delta)
	_update_skills(delta)
	battlefield.set_meta("light_radius", float(player["light_radius"]))
	battlefield.set_difficulty(elapsed / maxf(1.0, duration), _difficulty_curve)
	var map_speed := float(map_def.get("enemy_speed_mult", 1.0))
	var world_started := Time.get_ticks_usec()
	battlefield.update_world(
		delta,
		player,
		(1.20 if bool(player["dark"]) else 1.0) * map_speed * _event_enemy_speed_mult
	)
	_last_world_usec = Time.get_ticks_usec() - world_started
	_update_spawning(delta)
	_update_timeline_events()
	_update_boss_state()
	if elapsed >= duration and not _victory_started:
		_begin_victory()
	elif not _victory_started:
		_maybe_open_shop()
	_last_step_usec = Time.get_ticks_usec() - step_started


func _update_player(delta: float) -> void:
	if not _gameplay_input_allowed():
		_attack_held = false
		return
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_dash_timer = maxf(0.0, _dash_timer - delta)
	_dash_buff = maxf(0.0, _dash_buff - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_attack_buffer = maxf(0.0, _attack_buffer - delta)
	_kill_sfx_cd = maxf(0.0, _kill_sfx_cd - delta)
	_pickup_sfx_cd = maxf(0.0, _pickup_sfx_cd - delta)
	if float(player.get("regen", 0.0)) > 0.0 and float(player["hp"]) > 0.0:
		player["hp"] = minf(
			float(player["max_hp"]),
			float(player["hp"]) + float(player["regen"]) * delta
		)
	if float(player.get("shield_regen", 0.0)) > 0.0 and float(player.get("shield_max", 0.0)) > 0.0:
		player["shield"] = minf(
			float(player["shield_max"]),
			float(player.get("shield", 0.0)) + float(player["shield_regen"]) * delta
		)
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_instance_valid(touch_controls):
		input_vector = (input_vector + touch_controls.move_vector).limit_length(1.0)
	_attack_held = not _auto_attack and Input.is_action_pressed("attack")
	var mouse_world := get_global_mouse_position()
	if _has_mouse_screen_pos:
		mouse_world = get_viewport().get_canvas_transform().affine_inverse() * _mouse_screen_pos
	var aim_vector := mouse_world - (player["pos"] as Vector2)
	if aim_vector.length_squared() > 16.0:
		_aim_direction = aim_vector.normalized()
	if _auto_attack:
		var target := battlefield.nearest_enemy_any(player["pos"] as Vector2)
		if not target.is_empty():
			var target_direction := (target["pos"] as Vector2) - (player["pos"] as Vector2)
			if target_direction.length_squared() > 4.0:
				_aim_direction = target_direction.normalized()
	battlefield.player_aim = _aim_direction
	if input_vector.length_squared() > 0.001:
		_last_move = input_vector.normalized()
	if input_vector.length_squared() > 0.001 and _dash_timer <= 0.0:
		_move_trail_timer -= delta
		if _move_trail_timer <= 0.0:
			_move_trail_timer = 0.16
			battlefield.add_effect({
				"type": "aura",
				"pos": (player["pos"] as Vector2) - _last_move * 12.0,
				"ttl": 0.42,
				"max_ttl": 0.42,
				"radius": 11.0,
				"color": Color(0.86, 0.66, 0.31, 0.34),
			})
	var move_boost := 1.18 if _dash_buff > 0.0 else 1.0
	var previous_position := player["pos"] as Vector2
	var desired_position := previous_position
	var wade_factor := battlefield.wade_speed_factor(previous_position, float(player.get("wade_bonus", 0.0)))
	if _dash_timer > 0.0:
		desired_position += _dash_dir * float(player["speed"]) * 3.5 * delta
	else:
		desired_position += input_vector * float(player["speed"]) * move_boost * wade_factor * delta
		if wade_factor < 1.0 and input_vector.length_squared() > 0.001:
			_wade_sfx_cd -= delta
			if _wade_sfx_cd <= 0.0:
				_wade_sfx_cd = 0.11
				battlefield.spawn_wade_splash(previous_position, 1.0)
	player["pos"] = battlefield.resolve_player_move(previous_position, desired_position, float(player["radius"]))
	if _auto_attack or _attack_held or _attack_buffer > 0.0:
		player["facing"] = _aim_direction
	elif input_vector.length_squared() > 0.001:
		player["facing"] = input_vector.normalized()
	var dark := int(player["oil"]) <= 0
	player["dark"] = dark
	var ratio := float(player["oil"]) / maxf(1.0, float(player["oil_max"]))
	var map_light_scale := float(map_def.get("light_scale", 1.0))
	if dark:
		player["light_radius"] = 120.0 * map_light_scale * float(player["light_mult"])
		player["pickup_radius"] = float(player["base_pickup"]) * float(player["pickup_mult"]) * 0.82
		player["crit"] = float(player.get("base_crit", 0.05)) + float(player.get("passive_crit", 0.0)) + 0.15
	else:
		player["light_radius"] = lerpf(132.0, 252.0, ratio) * map_light_scale * float(player["light_mult"])
		player["pickup_radius"] = float(player["base_pickup"]) * float(player["pickup_mult"])
		player["crit"] = float(player.get("base_crit", 0.05)) + float(player.get("passive_crit", 0.0))


func _try_dash() -> void:
	if _dash_cd > 0.0:
		return
	_dash_cd = 3.0 * float(player.get("dash_cd_mult", 1.0))
	_dash_timer = 0.18
	_dash_buff = 0.55
	_invuln = 0.26
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_instance_valid(touch_controls):
		input_vector = (input_vector + touch_controls.move_vector).limit_length(1.0)
	_dash_dir = input_vector.normalized() if input_vector.length_squared() > 0.001 else _last_move
	_play_sfx(SFX_DASH, _rng.randf_range(1.18, 1.32), 0.62)
	for i in range(5):
		battlefield.add_effect({
			"type": "aura",
			"pos": (player["pos"] as Vector2) - _dash_dir * float(i) * 18.0,
			"ttl": 0.30 + float(i) * 0.03,
			"max_ttl": 0.30 + float(i) * 0.03,
			"radius": 54.0 - float(i) * 6.0,
			"color": Color(0.85, 0.65, 0.28, 0.72 - float(i) * 0.11),
		})


func _on_touch_dash_requested() -> void:
	if _paused or _game_over or _shop_open or story.visible or tutorial_overlay.visible or level_up_overlay.visible:
		return
	_try_dash()


func _update_oil(delta: float) -> void:
	oil_tick -= delta
	if oil_tick > 0.0:
		return
	oil_tick = float(map_def.get("oil_interval", 30.0))
	if int(player["oil"]) > 0:
		player["oil"] = int(player["oil"]) - 1
		if int(player["oil"]) == 0:
			hud.show_banner(Locale.t("banner.dark"), Locale.t("banner.dark_sub"), 3.2)
			_play_sfx(SFX_ALARM, 0.92, 0.72)


func _update_skills(delta: float) -> void:
	for behavior in active_skills.keys():
		var level := int(active_skills[behavior])
		if behavior in ["shield", "thorns", "lifesteal", "dash", "aura"]:
			continue
		var timer := float(skill_timers.get(behavior, 0.0)) - delta
		if timer > 0.0:
			skill_timers[behavior] = timer
			continue
		skill_timers[behavior] = _skill_cooldown(str(behavior), level)
		_cast_skill(str(behavior), level)


func _skill_cooldown(behavior: String, level: int) -> float:
	var base := {
		"volley": 2.4,
		"nova": 3.6,
		"slow": 3.8,
		"burn": 3.6,
		"stun": 5.2,
		"chain": 4.2,
		"heal": 6.4,
		"magnet": 7.0,
	}.get(behavior, 4.0) as float
	return maxf(0.9,
		base
		* (1.0 - 0.05 * float(level - 1))
		* float(player["cooldown_mult"])
		* float(player.get("skill_cd_mult", 1.0))
	)


func _cast_skill(behavior: String, level: int) -> void:
	var origin := player["pos"] as Vector2
	var area := float(player["area_mult"])
	match behavior:
		"volley":
			var targets := battlefield.nearest_enemies(origin, 660.0, 2 + int(level / 2))
			for target in targets:
				var direction := ((target["pos"] as Vector2) - origin).normalized()
				battlefield.fire_player_projectile(
					origin,
					direction,
					610.0 * float(player["projectile_speed_mult"]),
					(8.0 + 4.0 * float(level)) * float(player["damage_mult"]),
					1 + int(level / 3),
					Color("#f0d58d")
				)
			battlefield.add_effect({
				"type": "thrust",
				"pos": origin,
				"ttl": 0.16,
				"max_ttl": 0.16,
				"direction": _last_move,
				"length": 110.0,
				"color": Color("#f0d58d"),
			})
			_play_sfx(SFX_FIRE)
		"nova":
			var radius := (118.0 + 18.0 * float(level)) * area
			battlefield.damage_circle(
				origin,
				radius,
				(11.0 + 7.0 * float(level)) * float(player["damage_mult"]),
				24.0,
				Color("#e8b05a")
			)
			battlefield.add_effect({
				"type": "aura",
				"pos": origin,
				"ttl": 0.42,
				"max_ttl": 0.42,
				"radius": radius,
				"color": Color("#e8b05a"),
			})
			_play_sfx(SFX_ENEMY_HIT, 1.08, 0.72)
		"slow":
			var radius := (150.0 + 16.0 * float(level)) * area
			battlefield.apply_slow(origin, radius, 0.60 - 0.035 * float(level), 2.2)
			battlefield.add_effect({
				"type": "aura",
				"pos": origin,
				"ttl": 0.55,
				"max_ttl": 0.55,
				"radius": radius,
				"color": Color("#6ba6b8"),
			})
			_play_sfx(SFX_WAVE, 1.28, 0.58)
		"burn":
			var radius := (126.0 + 15.0 * float(level)) * area
			battlefield.apply_burn(
				origin,
				radius,
				(4.0 + 2.0 * float(level)) * float(player["damage_mult"]),
				3.0
			)
			battlefield.add_effect({
				"type": "aura",
				"pos": origin,
				"ttl": 0.60,
				"max_ttl": 0.60,
				"radius": radius,
				"color": Color("#dd6b3f"),
			})
			_play_sfx(SFX_FIRE)
		"stun":
			var radius := (132.0 + 15.0 * float(level)) * area
			battlefield.apply_stun(origin, radius, 0.42 + 0.12 * float(level))
			battlefield.add_effect({
				"type": "aura",
				"pos": origin,
				"ttl": 0.46,
				"max_ttl": 0.46,
				"radius": radius,
				"color": Color("#c9b06b"),
			})
			_play_sfx(SFX_WAVE)
		"chain":
			var targets := battlefield.nearest_enemies(origin, 620.0, 3 + int(level / 2))
			var previous := origin
			for target in targets:
				var target_pos := target["pos"] as Vector2
				var direction := (target_pos - previous).normalized()
				battlefield.damage_line(
					previous,
					direction,
					previous.distance_to(target_pos),
					26.0,
					(13.0 + 6.0 * float(level)) * float(player["damage_mult"]),
					8.0,
					Color("#9fc7d6")
				)
				battlefield.add_effect({
					"type": "thrust",
					"pos": previous,
					"ttl": 0.20,
					"max_ttl": 0.20,
					"direction": direction,
					"length": previous.distance_to(target_pos),
					"color": Color("#9fc7d6"),
				})
				previous = target_pos
			_play_sfx(SFX_FIRE)
		"heal":
			player["hp"] = minf(
				float(player["max_hp"]),
				float(player["hp"]) + float(player["max_hp"]) * (0.03 + 0.01 * float(level))
			)
			battlefield.add_effect({
				"type": "aura",
				"pos": origin,
				"ttl": 0.55,
				"max_ttl": 0.55,
				"radius": 58.0,
				"color": Color("#8fbd8b"),
			})
			_play_sfx(SFX_PICKUP, 0.82, 0.88)
		"magnet":
			battlefield.magnet_all()
			_play_sfx(SFX_EVENT, 1.18, 0.62)


func _update_weapons(delta: float) -> void:
	if not _gameplay_input_allowed():
		return
	var wants_attack := _auto_attack or _attack_held or _attack_buffer > 0.0
	var buffered_click := _attack_buffer > 0.0 and not _attack_held and not _auto_attack
	var fired_any := false
	for weapon in weapons:
		weapon["timer"] = float(weapon["timer"]) - delta
		if not wants_attack:
			continue
		if float(weapon["timer"]) > 0.0:
			continue
		var fired := _fire_weapon(weapon)
		fired_any = fired_any or fired
		weapon["timer"] = _weapon_cooldown(weapon) if fired else 0.10
	if buffered_click and fired_any:
		_attack_buffer = 0.0


func _fire_weapon(weapon: Dictionary) -> bool:
	var definition: Dictionary = weapon["definition"] as Dictionary
	var weapon_type := str(definition.get("type", "melee_arc"))
	var origin := player["pos"] as Vector2
	var radius := float(definition.get("range", 120.0)) * float(player["area_mult"])
	var base_damage := _weapon_damage(weapon)
	var target := battlefield.nearest_enemy(origin, maxf(radius, 520.0))
	var roll := _damage_roll(base_damage)
	var damage := float(roll[0])
	var critical := bool(roll[1])
	var direction := _aim_direction.normalized()
	if direction.length_squared() <= 0.001:
		var facing := player.get("facing", Vector2.RIGHT) as Vector2
		direction = Vector2.RIGHT if facing.x >= 0.0 else Vector2.LEFT
	if not target.is_empty() and float(player.get("execute_below", 0.0)) > 0.0:
		var target_max := maxf(1.0, float(target.get("max_hp", 1.0)))
		if float(target.get("hp", 0.0)) / target_max <= float(player["execute_below"]):
			damage *= 1.65
	match weapon_type:
		"melee_arc":
			var arc := 360.0 if bool(weapon["evolved"]) else float(definition.get("arc_degrees", 118.0))
			battlefield.damage_cone(
				origin,
				direction,
				radius,
				arc,
				damage,
				float(definition.get("knockback", 20.0)),
				GOLD
			)
			battlefield.add_effect({
				"type": "slash",
				"pos": origin,
				"ttl": 0.23,
				"max_ttl": 0.23,
				"radius": radius,
				"angle": direction.angle(),
				"arc": deg_to_rad(arc),
				"color": Color("#f0c363"),
			})
			battlefield.play_player_attack_fx(str(weapon["id"]), origin, direction, bool(weapon["evolved"]))
			_play_sfx(SFX_ENEMY_HIT, 0.96, 0.68)
			return true
		"line_thrust":
			var directions := [direction]
			if bool(weapon["evolved"]):
				directions = [direction.rotated(deg_to_rad(-18.0)), direction, direction.rotated(deg_to_rad(18.0))]
			for dir in directions:
				battlefield.damage_line(
					origin,
					dir,
					radius,
					float(definition.get("width", 38.0)),
					damage,
					float(definition.get("knockback", 36.0)),
					Color("#e8ca7b")
				)
				battlefield.add_effect({
					"type": "thrust",
					"pos": origin,
					"ttl": 0.18,
					"max_ttl": 0.18,
					"direction": dir,
					"length": radius,
					"color": Color("#f0d58d"),
				})
			battlefield.play_player_attack_fx(str(weapon["id"]), origin, direction, bool(weapon["evolved"]))
			_play_sfx(SFX_HIT)
			return true
		"projectile":
			var count := int(definition.get("projectiles", 1)) + int((int(weapon["level"]) - 1) / 2)
			var pierce := int(definition.get("pierce", 1))
			if bool(weapon["evolved"]):
				count = maxi(count, 3)
				pierce += 1
			var spread := deg_to_rad(8.0 if bool(weapon["evolved"]) else 5.0)
			for i in range(count):
				var offset := 0.0
				if count > 1:
					offset = (float(i) - float(count - 1) * 0.5) * spread
				battlefield.fire_player_projectile(
					origin,
					direction.rotated(offset),
					float(definition.get("projectile_speed", 560.0)) * float(player["projectile_speed_mult"]),
					damage,
					pierce,
					Color("#f4dc94")
				)
			battlefield.play_player_attack_fx(str(weapon["id"]), origin, direction, bool(weapon["evolved"]))
			_play_sfx(SFX_FIRE)
			return true
		"shotgun":
			var pellets := int(definition.get("pellets", 3)) + int((int(weapon["level"]) - 1) / 3)
			if bool(weapon["evolved"]):
				pellets += 3
			for i in range(pellets):
				var offset := deg_to_rad(float(definition.get("spread_degrees", 28.0)) * (float(i) / maxf(1.0, float(pellets - 1)) - 0.5))
				battlefield.fire_player_projectile(
					origin,
					direction.rotated(offset),
					float(definition.get("projectile_speed", 720.0)) * float(player["projectile_speed_mult"]),
					damage,
					int(definition.get("pierce", 1)),
					Color("#f3bd6a")
				)
			battlefield.add_effect({
				"type": "thrust",
				"pos": origin,
				"ttl": 0.12,
				"max_ttl": 0.12,
				"direction": direction,
				"length": 74.0,
				"color": Color("#f0a957"),
			})
			battlefield.play_player_attack_fx(str(weapon["id"]), origin, direction, bool(weapon["evolved"]))
			_play_sfx(SFX_FIRE)
			return true
		"aura":
			battlefield.damage_circle(origin, radius, damage, 4.0, Color("#e9a85b"))
			battlefield.add_effect({
				"type": "aura",
				"pos": origin,
				"ttl": 0.34,
				"max_ttl": 0.34,
				"radius": radius,
				"color": Color("#e8a452"),
			})
			if bool(weapon["evolved"]) and int(weapon.get("cycle", 0)) % 5 == 0:
				battlefield.damage_circle(origin, 340.0, damage * 1.8, 20.0, Color("#d65b45"))
				battlefield.add_effect({
					"type": "aura",
					"pos": origin,
					"ttl": 0.5,
					"max_ttl": 0.5,
					"radius": 340.0,
					"color": Color("#d65b45"),
				})
			weapon["cycle"] = int(weapon.get("cycle", 0)) + 1
			battlefield.play_player_attack_fx(str(weapon["id"]), origin, direction, bool(weapon["evolved"]))
			_play_sfx(SFX_FIRE)
			return true
	return false


func _add_weapon(weapon_id: String) -> void:
	if weapons.size() >= 6 or not weapon_defs.has(weapon_id):
		return
	weapons.append({
		"id": weapon_id,
		"level": 1,
		"timer": 0.0,
		"evolved": false,
		"cycle": 0,
		"definition": weapon_defs[weapon_id],
	})


func _weapon_damage(weapon: Dictionary) -> float:
	var definition: Dictionary = weapon["definition"] as Dictionary
	var base := float(definition.get("damage", 10.0))
	var level_scale := 1.0 + 0.20 * float(int(weapon["level"]) - 1)
	var evolved_scale := 1.55 if bool(weapon["evolved"]) else 1.0
	return base * level_scale * evolved_scale * float(player["damage_mult"])


func _weapon_cooldown(weapon: Dictionary) -> float:
	var definition: Dictionary = weapon["definition"] as Dictionary
	var base := float(definition.get("cooldown", 0.8))
	var level_scale := pow(0.92, float(int(weapon["level"]) - 1))
	var evolved_scale := 0.82 if bool(weapon["evolved"]) else 1.0
	return maxf(0.12, base * level_scale * evolved_scale * float(player["cooldown_mult"]))


func _damage_roll(base_damage: float) -> Array:
	var critical := _rng.randf() < float(player["crit"])
	return [base_damage * (1.8 if critical else 1.0), critical]


func _recompute_stats() -> void:
	if player.is_empty():
		return
	var stats := {
		"damage_mult": 1.0,
		"speed_mult": 1.0,
		"pickup_mult": 1.0,
		"area_mult": 1.0,
		"cooldown_mult": 1.0,
		"skill_cd_mult": 1.0,
		"dash_cd_mult": 1.0,
		"armor": 0.0,
		"crit": 0.0,
		"xp_mult": 1.0,
		"oil_max": 0.0,
		"regen": 0.0,
		"revive": 0.0,
		"max_hp_mult": 1.0,
		"max_hp_flat": 0.0,
		"shield_max": 0.0,
		"shield_regen": 0.0,
		"thorns": 0.0,
		"lifesteal": 0.0,
		"dodge": 0.0,
		"execute_below": 0.0,
		"luck": 0.0,
		"gold_mult": 1.0,
		"light_mult": 1.0,
		"projectile_speed_mult": 1.0,
		"knockback_mult": 1.0,
		"wade_speed": 0.0,
		# ---- 箭塔增益（tower_* 独立命名空间，整体推给 Battlefield）----
		"tower_damage_mult": 1.0,
		"tower_range_mult": 1.0,
		"tower_hp_mult": 1.0,
		"tower_arrow_speed": 1.0,
		"tower_size_mult": 1.0,
		"tower_fire_rate": 1.0,
		"tower_taunt": 1.0,
		"tower_rebuild_hp": 0.60,
		"tower_pierce": 0.0,
		"tower_volley": 0.0,
		"tower_burst_shots": 0.0,
		"tower_burst_lanes": 0.0,
		"tower_armor": 0.0,
		"tower_regen": 0.0,
		"tower_crit": 0.0,
		"tower_chain": 0.0,
		"tower_splash": 0.0,
		"tower_burn": 0.0,
		"tower_slow": 0.0,
		"tower_knockback": 0.0,
		"tower_execute": 0.0,
		"tower_marksman": 0.0,
		"tower_overcharge": 0.0,
		"tower_rebuild": 0.0,
		"tower_thorns": 0.0,
		"tower_lifesteal": 0.0,
		"tower_count": 2.0,
		"tower_xp_gain": 0.0,
		"tower_gold_gain": 0.0,
	}
	for passive_id in passives.keys():
		if not passive_defs.has(passive_id):
			continue
		var definition: Dictionary = passive_defs[passive_id] as Dictionary
		var passive_level := int(passives[passive_id])
		var amount := float(definition.get("amount", 0.0))
		match str(definition.get("stat", "")):
			"damage_mult":
				stats["damage_mult"] = float(stats["damage_mult"]) * (1.0 + amount * passive_level)
			"speed_mult":
				stats["speed_mult"] = float(stats["speed_mult"]) * (1.0 + amount * passive_level)
			"pickup_mult":
				stats["pickup_mult"] = float(stats["pickup_mult"]) * (1.0 + amount * passive_level)
			"area_mult":
				stats["area_mult"] = float(stats["area_mult"]) * (1.0 + amount * passive_level)
			"armor":
				stats["armor"] = float(stats["armor"]) + amount * passive_level
			"oil_max":
				stats["oil_max"] = float(stats["oil_max"]) + amount * passive_level
			"crit":
				stats["crit"] = float(stats["crit"]) + amount * passive_level
			"xp_mult":
				stats["xp_mult"] = float(stats["xp_mult"]) * (1.0 + amount * passive_level)
			"regen":
				stats["regen"] = float(stats["regen"]) + amount * passive_level
			"revive":
				stats["revive"] = float(stats["revive"]) + amount * passive_level
			"bell":
				stats["area_mult"] = float(stats["area_mult"]) * (1.0 + 0.07 * passive_level)
				stats["cooldown_mult"] = float(stats["cooldown_mult"]) * (1.0 - 0.03 * passive_level)
	var cards := UpgradeCatalog.all_cards()
	for card_id in card_levels.keys():
		if not cards.has(card_id):
			continue
		var definition: Dictionary = cards[card_id] as Dictionary
		var card_level := int(card_levels[card_id])
		for effect in definition.get("effects", []) as Array:
			if not effect is Dictionary:
				continue
			var stat := str((effect as Dictionary).get("stat", ""))
			if stat.begins_with("skill_"):
				continue
			_add_stat(stats, stat, float((effect as Dictionary).get("amount", 0.0)) * float(card_level))
	for stat in event_stat_bonuses.keys():
		_add_stat(stats, str(stat), float(event_stat_bonuses[stat]))
	for mercenary_id in mercenaries:
		var mercenary: Dictionary = mercenary_defs.get(mercenary_id, {}) as Dictionary
		var bonuses: Dictionary = mercenary.get("party_bonus", {}) as Dictionary
		for stat in bonuses.keys():
			_add_stat(stats, str(stat), float(bonuses[stat]))
	active_skills.clear()
	for card_id in card_levels.keys():
		if not cards.has(card_id):
			continue
		var definition: Dictionary = cards[card_id] as Dictionary
		if str(definition.get("family", "")) != "skill":
			continue
		for effect in definition.get("effects", []) as Array:
			if not effect is Dictionary:
				continue
			var stat := str((effect as Dictionary).get("stat", ""))
			if not stat.begins_with("skill_"):
				continue
			var behavior := stat.trim_prefix("skill_")
			active_skills[behavior] = maxi(
				int(active_skills.get(behavior, 0)),
				int(card_levels[card_id])
			)
			if not skill_timers.has(behavior):
				skill_timers[behavior] = 0.45
	var old_oil_max := int(player.get("oil_max", 6))
	var old_max_hp := float(player.get("max_hp", player["base_max_hp"]))
	var old_shield_max := float(player.get("shield_max", 0.0))
	player["damage_mult"] = float(stats["damage_mult"])
	player["speed_mult"] = float(stats["speed_mult"])
	player["pickup_mult"] = float(stats["pickup_mult"])
	player["area_mult"] = float(stats["area_mult"])
	player["cooldown_mult"] = clampf(float(stats["cooldown_mult"]), 0.35, 1.8)
	player["skill_cd_mult"] = clampf(float(stats["skill_cd_mult"]), 0.35, 1.8)
	player["dash_cd_mult"] = clampf(float(stats["dash_cd_mult"]), 0.35, 1.8)
	player["armor"] = clampf(float(stats["armor"]), 0.0, 0.60)
	player["passive_crit"] = float(stats["crit"])
	player["base_crit"] = 0.05
	player["xp_mult"] = float(stats["xp_mult"])
	player["regen"] = float(stats["regen"])
	player["revive"] = int(stats["revive"])
	player["max_hp_mult"] = float(stats["max_hp_mult"])
	player["max_hp_flat"] = float(stats["max_hp_flat"])
	player["max_hp"] = maxf(
		1.0,
		float(player["base_max_hp"]) * float(stats["max_hp_mult"]) + float(stats["max_hp_flat"])
	)
	if float(player["max_hp"]) > old_max_hp:
		player["hp"] = float(player["hp"]) + float(player["max_hp"]) - old_max_hp
	player["hp"] = clampf(float(player["hp"]), 1.0, float(player["max_hp"]))
	player["shield_max"] = maxf(0.0, float(stats["shield_max"]))
	if float(player["shield_max"]) > old_shield_max:
		player["shield"] = float(player.get("shield", 0.0)) + float(player["shield_max"]) - old_shield_max
	player["shield"] = clampf(float(player.get("shield", 0.0)), 0.0, float(player["shield_max"]))
	player["shield_regen"] = float(stats["shield_regen"])
	player["thorns"] = float(stats["thorns"])
	player["lifesteal"] = float(stats["lifesteal"])
	player["dodge"] = clampf(float(stats["dodge"]), 0.0, 0.55)
	player["execute_below"] = clampf(float(stats["execute_below"]), 0.0, 0.40)
	player["luck"] = float(stats["luck"])
	player["gold_mult"] = float(stats["gold_mult"])
	player["light_mult"] = float(stats["light_mult"])
	player["projectile_speed_mult"] = float(stats["projectile_speed_mult"])
	player["knockback_mult"] = float(stats["knockback_mult"])
	player["wade_bonus"] = clampf(float(stats["wade_speed"]), 0.0, 0.55)
	player["speed"] = float(player["base_speed"]) * float(stats["speed_mult"])
	player["oil_max"] = int(player["base_oil_max"]) + int(stats["oil_max"])
	if int(player["oil_max"]) > old_oil_max:
		player["oil"] = int(player["oil"]) + int(player["oil_max"]) - old_oil_max
	player["oil"] = clampi(int(player["oil"]), 0, int(player["oil_max"]))
	# 箭塔增益整体下发；Battlefield 负责同步既有塔的血量上限与护甲
	var tower_stats := {}
	for key in stats.keys():
		if str(key).begins_with("tower_"):
			tower_stats[str(key)] = stats[key]
	player["tower_count"] = int(maxf(0.0, float(stats["tower_count"])))
	player["tower_taunt"] = float(stats["tower_taunt"])
	if battlefield != null:
		battlefield.apply_tower_stats(tower_stats)


func _add_stat(stats: Dictionary, stat: String, amount: float) -> void:
	match stat:
		"damage_mult", "speed_mult", "pickup_mult", "area_mult", "xp_mult", \
		"max_hp_mult", "projectile_speed_mult", "gold_mult", "light_mult", \
		"knockback_mult", "cooldown_mult", "dash_cd_mult", "skill_cd_mult", \
		"tower_damage_mult", "tower_range_mult", "tower_hp_mult", "tower_arrow_speed", \
		"tower_size_mult", "tower_fire_rate", "tower_taunt":
			stats[stat] = float(stats.get(stat, 1.0)) * (1.0 + amount)
		"armor", "crit", "regen", "max_hp_flat", "shield_max", "shield_regen", \
		"thorns", "lifesteal", "dodge", "execute_below", "luck", "oil_max", "revive", \
		"wade_speed", \
		"tower_rebuild_hp", "tower_pierce", "tower_volley", "tower_burst_shots", \
		"tower_burst_lanes", "tower_armor", "tower_regen", \
		"tower_crit", "tower_chain", "tower_splash", "tower_burn", "tower_slow", \
		"tower_knockback", "tower_execute", "tower_marksman", "tower_overcharge", \
		"tower_rebuild", "tower_thorns", "tower_lifesteal", "tower_count", \
		"tower_xp_gain", "tower_gold_gain":
			stats[stat] = float(stats.get(stat, 0.0)) + amount


func _update_spawning(delta: float) -> void:
	var phase := _phase_at(elapsed)
	if phase.is_empty():
		return
	var rate := float(phase.get("rate", 3.0)) * float(map_def.get("spawn_rate_mult", 1.0))
	_spawn_accum += rate * delta
	while _spawn_accum >= 1.0:
		_spawn_accum -= 1.0
		if battlefield.alive_count() >= 460:
			break
		var enemy_id := _pick_weighted(phase.get("mix", []) as Array)
		if not enemy_id.is_empty():
			battlefield.spawn_enemy(enemy_id, player["pos"] as Vector2)
	if not _boss_spawned and elapsed >= boss_second:
		_boss_spawned = true
		battlefield.spawn_enemy_at("daimyo", (player["pos"] as Vector2) + Vector2(520, 80))
		_boss_warned = true
		hud.show_banner(Locale.t("banner.boss"), Locale.t("banner.boss_sub"), 4.0)
		_play_sfx(SFX_BOSS, 1.0, 0.92)
	while _scale_event_index < _scale_events.size():
		var event := _scale_events[_scale_event_index] as Dictionary
		if elapsed < float(event.get("t", 0.0)):
			break
		battlefield.spawn_enemy(str(event.get("enemy", "general")), player["pos"] as Vector2, str(event.get("color", "red")))
		_scale_event_index += 1


func _update_timeline_events() -> void:
	while _event_line_index < _event_lines.size():
		var event := _event_lines[_event_line_index] as Dictionary
		if elapsed < float(event.get("t", 0.0)):
			break
		var line_id := str(event.get("key", ""))
		if _lines_by_id.has(line_id):
			narrative.show_line(_lines_by_id[line_id] as Dictionary)
			_narrative_timer.start(6.2)
			_play_sfx(SFX_EVENT, 1.0, 0.48)
		_event_line_index += 1


func _update_boss_state() -> void:
	if not _boss_spawned or _boss_defeated:
		return
	var boss := _active_boss()
	if boss.is_empty():
		_boss_defeated = true


func _active_boss() -> Dictionary:
	for enemy in battlefield.enemies:
		if bool(enemy.get("boss", false)) and bool(enemy.get("alive", false)):
			return enemy
	return {}


func _phase_at(second: float) -> Dictionary:
	for phase in _phase_list:
		if phase is Dictionary and second >= float(phase.get("start", 0.0)) and second < float(phase.get("end", 0.0)):
			return phase
	return {}


func _pick_weighted(mix: Array) -> String:
	var total := 0.0
	for entry in mix:
		total += float((entry as Dictionary).get("weight", 1.0))
	if total <= 0.0:
		return ""
	var roll := _rng.randf_range(0.0, total)
	var current := 0.0
	for entry in mix:
		current += float((entry as Dictionary).get("weight", 1.0))
		if roll <= current:
			return str((entry as Dictionary).get("id", ""))
	return str((mix.back() as Dictionary).get("id", ""))


func _on_player_hit(raw_damage: float) -> void:
	if _invuln > 0.0 or _game_over:
		return
	if _rng.randf() < float(player.get("dodge", 0.0)):
		_invuln = 0.18
		battlefield.play_impact_fx(player["pos"] as Vector2, "armored", 0.85)
		battlefield.add_effect({
			"type": "aura",
			"pos": player["pos"],
			"ttl": 0.24,
			"max_ttl": 0.24,
			"radius": 40.0,
			"color": Color(0.72, 0.84, 0.78, 0.52),
		})
		return
	var damage := maxf(1.0, raw_damage * (1.0 - float(player["armor"])))
	var shield := float(player.get("shield", 0.0))
	if shield > 0.0:
		var absorbed := minf(shield, damage)
		player["shield"] = shield - absorbed
		damage -= absorbed
		battlefield.play_impact_fx(player["pos"] as Vector2, "armored", 1.1)
		battlefield.add_effect({
			"type": "aura",
			"pos": player["pos"],
			"ttl": 0.22,
			"max_ttl": 0.22,
			"radius": 34.0,
			"color": Color(0.86, 0.72, 0.35, 0.55),
		})
	if damage <= 0.0:
		_invuln = 0.10
		return
	player["hp"] = float(player["hp"]) - damage
	_invuln = 0.65
	battlefield.play_impact_fx(
		player["pos"] as Vector2,
		"heavy" if raw_damage >= 18.0 else "normal",
		0.9 if raw_damage >= 18.0 else 0.65
	)
	_play_sfx(SFX_HIT, 0.82, 0.88)
	if float(player.get("thorns", 0.0)) > 0.0:
		battlefield.damage_circle(
			player["pos"] as Vector2,
			118.0,
			float(player["thorns"]),
			30.0,
			Color("#d86a4a")
		)
	if float(player["hp"]) <= 0.0:
		if int(player.get("revive", 0)) > 0:
			player["revive"] = int(player["revive"]) - 1
			player["hp"] = float(player["max_hp"]) * 0.5
			_invuln = 2.0
			hud.show_banner(Locale.t("banner.revive"), Locale.t("banner.revive_sub"), 3.0)
			_play_sfx(SFX_WIN)
		else:
			player["hp"] = 0.0
			_begin_defeat()


func _on_enemy_killed(enemy_id: String, _world_position: Vector2, elite: bool) -> void:
	kills += 1
	var definition: Dictionary = enemy_defs.get(enemy_id, {}) as Dictionary
	var xp_value := float(definition.get("xp", 1.0))
	merit += int(
		maxf(1.0, xp_value * (3.0 if elite else 1.0))
		* float(player.get("gold_mult", 1.0))
	)
	var coin_gain := maxi(
		int(shop_data.get("minimum_kill_coin", 1)),
		int(round(xp_value * float(shop_data.get("coin_per_xp", 0.55))))
	)
	if elite:
		coin_gain = int(round(float(coin_gain) * float(shop_data.get("elite_coin_mult", 2.0))))
	run_coin += maxi(1, int(round(float(coin_gain) * float(player.get("gold_mult", 1.0)))))
	if float(player.get("lifesteal", 0.0)) > 0.0:
		player["hp"] = minf(
			float(player["max_hp"]),
			float(player["hp"]) + float(player["lifesteal"])
		)
	if elite:
		hud.show_banner(Locale.t("banner.elite"), Locale.t("banner.elite_sub"), 1.8)
		_play_sfx(SFX_ELITE_KILL, _rng.randf_range(0.94, 1.04), 0.78)
	elif _kill_sfx_cd <= 0.0:
		_play_sfx(SFX_ENEMY_KILL, _rng.randf_range(0.90, 1.10), 0.42)
		_kill_sfx_cd = 0.055


func _on_xp_collected(amount: float) -> void:
	var multiplier := float(player["xp_mult"]) * (1.5 if bool(player["dark"]) else 1.0)
	_add_xp(amount * multiplier)
	if _pickup_sfx_cd <= 0.0:
		_play_sfx(SFX_PICKUP, _rng.randf_range(1.12, 1.24), 0.34)
		_pickup_sfx_cd = 0.10


func _add_xp(amount: float) -> void:
	if level >= MAX_LEVEL:
		xp = 0.0
		return
	xp += amount
	while xp >= xp_need and level < MAX_LEVEL:
		xp -= xp_need
		level += 1
		_pending_levels += 1
		xp_need = _xp_need_for_level(level)
	if level >= MAX_LEVEL:
		xp = 0.0
	if _pending_levels > 0 and not _paused and not _game_over:
		_show_level_up()


func _xp_need_for_level(current_level: int) -> float:
	return 5.0 + 4.0 * float(current_level) + 0.35 * float(current_level * current_level)


func _show_level_up() -> void:
	_paused = true
	_release_attack()
	_play_sfx(SFX_LEVEL_UP, 1.0, 0.86)
	if is_instance_valid(touch_controls):
		touch_controls.release_all()
	_current_upgrade_options = _build_upgrade_options()
	level_up_overlay.show_options(_current_upgrade_options, level, {
		"pool": _upgrade_pool_count(),
		"taken": card_levels.size() + passives.size() + weapons.size(),
	})
	_sync_gameplay_cursor()


func _upgrade_pool_count() -> int:
	var total := UpgradeCatalog.total_offer_count()
	for weapon_id in weapon_defs.keys():
		var current := 0
		for weapon in weapons:
			if str(weapon["id"]) == str(weapon_id):
				current = int(weapon["level"])
				break
		total += maxi(0, 5 - current)
		if current >= 5:
			total += 1
	for passive_id in passive_defs.keys():
		var max_level := int((passive_defs[passive_id] as Dictionary).get("max_level", 5))
		total += maxi(0, max_level - int(passives.get(passive_id, 0)))
	total += 2
	return maxi(0, total)


func _build_upgrade_options() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for weapon in weapons:
		var definition: Dictionary = weapon["definition"] as Dictionary
		var weapon_id := str(weapon["id"])
		var weapon_icon := str(definition.get("icon", ""))
		var weapon_culture := GameData.loc(definition, "culture")
		if bool(weapon["evolved"]):
			continue
		if int(weapon["level"]) >= 5:
			var passive_id := str(definition.get("evolve_passive", ""))
			if not passive_id.is_empty() and int(passives.get(passive_id, 0)) >= 3:
				pool.append(UpgradeCatalog.make_external_option(
					"evolve",
					weapon_id,
					GameData.loc(definition, "evolve_name"),
					GameData.loc(definition, "evolve_description"),
					weapon_culture,
					weapon_icon,
					5,
					5,
					Locale.t("upgrade.kind.evolve"),
					"rare",
					{"weapon_id": weapon_id, "effect_summary": Locale.t("upgrade.evolve_effect")}
				))
		elif int(weapon["level"]) < 5:
			pool.append(UpgradeCatalog.make_external_option(
				"weapon_upgrade",
				weapon_id,
				GameData.loc(definition, "name"),
				"%s  Lv %d → %d\n%s" % [
					Locale.t("upgrade.weapon"),
					int(weapon["level"]),
					int(weapon["level"]) + 1,
					GameData.loc(definition, "description"),
				],
				weapon_culture,
				weapon_icon,
				int(weapon["level"]) + 1,
				5,
				Locale.t("upgrade.kind.weapon"),
				"common",
				{
					"weapon_id": weapon_id,
					"effect_summary": GameData.loc(definition, "description"),
				}
			))
	if weapons.size() < 6:
		for weapon_id in weapon_defs.keys():
			if _has_weapon(str(weapon_id)):
				continue
			var definition: Dictionary = weapon_defs[weapon_id] as Dictionary
			pool.append(UpgradeCatalog.make_external_option(
				"weapon_new",
				str(weapon_id),
				GameData.loc(definition, "name"),
				"%s\n%s" % [Locale.t("upgrade.new_weapon"), GameData.loc(definition, "description")],
				GameData.loc(definition, "culture"),
				str(definition.get("icon", "")),
				1,
				5,
				Locale.t("upgrade.kind.new_weapon"),
				"uncommon",
				{
					"weapon_id": str(weapon_id),
					"effect_summary": GameData.loc(definition, "description"),
				}
			))
	for passive_id in passive_defs.keys():
		var definition: Dictionary = passive_defs[passive_id] as Dictionary
		var current := int(passives.get(passive_id, 0))
		if current >= int(definition.get("max_level", 5)):
			continue
		var is_new := current == 0
		var passive_icon := str(definition.get("icon", ""))
		if passive_icon.is_empty():
			passive_icon = ICON_DRAGON if str(passive_id) == "colored_paper" else ICON_KATANA
		pool.append(UpgradeCatalog.make_external_option(
			"passive_new" if is_new else "passive_upgrade",
			str(passive_id),
			GameData.loc(definition, "name"),
			"%s\n%s" % [
				Locale.t("upgrade.passive_new" if is_new else "upgrade.passive"),
				GameData.loc(definition, "description"),
			],
			GameData.loc(definition, "culture"),
			passive_icon,
			current + 1,
			int(definition.get("max_level", 5)),
			Locale.t("upgrade.kind.passive"),
			"uncommon",
			{
				"passive_id": str(passive_id),
				"effect_summary": GameData.loc(definition, "description"),
			}
		))
	pool.append_array(UpgradeCatalog.build_card_pool(
		card_levels,
		used_events,
		float(player.get("luck", 0.0))
	))
	pool.append(UpgradeCatalog.make_external_option(
		"heal",
		"supply_heal",
		Locale.t("upgrade.heal"),
		Locale.t("upgrade.heal_desc"),
		Locale.t("upgrade.heal_culture"),
		ICON_OIL,
		1,
		1,
		Locale.t("upgrade.kind.supply"),
		"common",
		{"supply_id": "heal", "effect_summary": Locale.t("upgrade.heal_desc")}
	))
	pool.append(UpgradeCatalog.make_external_option(
		"oil",
		"supply_oil",
		Locale.t("upgrade.oil"),
		Locale.t("upgrade.oil_desc"),
		Locale.t("upgrade.oil_culture"),
		ICON_OIL,
		1,
		1,
		Locale.t("upgrade.kind.supply"),
		"common",
		{"supply_id": "oil", "effect_summary": Locale.t("upgrade.oil_desc")}
	))
	return UpgradeCatalog.pick_three(pool, _rng)


func _on_upgrade_chosen(index: int) -> void:
	if not level_up_overlay.can_choose(index):
		return
	AudioBus.play_confirm()
	var option := _current_upgrade_options[index]
	match str(option.get("family", "")):
		"weapon_upgrade", "evolve":
			var weapon_id := str(option.get("weapon_id", ""))
			for weapon in weapons:
				if str(weapon["id"]) != weapon_id:
					continue
				if str(option.get("family", "")) == "evolve":
					weapon["evolved"] = true
				else:
					weapon["level"] = int(weapon["level"]) + 1
				break
		"weapon_new":
			_add_weapon(str(option.get("weapon_id", "")))
		"passive_new":
			passives[str(option.get("passive_id", ""))] = 1
		"passive_upgrade":
			var passive_id := str(option.get("passive_id", ""))
			passives[passive_id] = int(passives.get(passive_id, 0)) + 1
		"attribute", "skill", "tower":
			_apply_card(option)
		"event":
			_apply_event(option)
		"heal":
			player["hp"] = minf(float(player["max_hp"]), float(player["hp"]) + float(player["max_hp"]) * 0.35)
		"oil":
			player["oil"] = mini(int(player["oil_max"]), int(player["oil"]) + 3)
	_recompute_stats()
	_apply_tower_tier_upgrade(option)
	_sync_towers()
	player["hp"] = minf(float(player["max_hp"]), float(player["hp"]) + float(player["max_hp"]) * 0.08)
	_pending_levels = maxi(0, _pending_levels - 1)
	level_up_overlay.hide_options()
	if _pending_levels > 0:
		_show_level_up()
	else:
		_paused = false
	_sync_gameplay_cursor()


func _apply_tower_tier_upgrade(option: Dictionary) -> void:
	"""「箭塔升阶」卡：把所有望楼推进一档（望楼→箭楼→龙首箭楼）。"""
	var definition: Dictionary = option.get("definition", {}) as Dictionary
	var tier_gain := 0
	for effect in definition.get("effects", []) as Array:
		if not effect is Dictionary:
			continue
		if str((effect as Dictionary).get("stat", "")) == "tower_tier":
			tier_gain += int((effect as Dictionary).get("amount", 0.0))
	if tier_gain <= 0 or battlefield == null:
		return
	var order := ["watchtower", "arrow_tower", "dragon_tower"]
	var upgraded := 0
	for index in range(battlefield.towers.size()):
		var tower: Dictionary = battlefield.towers[index]
		if not bool(tower.get("alive", false)):
			continue
		var current_tier := order.find(str(tower["id"]))
		if current_tier < 0 or current_tier >= order.size() - 1:
			continue
		var next_id: String = order[mini(order.size() - 1, current_tier + tier_gain)]
		if battlefield.upgrade_tower(index, next_id):
			upgraded += 1
	if upgraded > 0:
		_play_sfx(SFX_LEVEL_UP, 0.8, 0.66)


func _maybe_open_shop() -> void:
	if _shop_open or _game_over or _victory_started:
		return
	if elapsed < _next_shop_time:
		return
	if _pending_levels > 0:
		return
	if not is_instance_valid(story) or story.visible:
		return
	if is_instance_valid(level_up_overlay) and level_up_overlay.visible:
		return
	if is_instance_valid(tutorial_overlay) and tutorial_overlay.visible:
		return
	_open_shop()


func _open_shop() -> void:
	if _shop_open:
		return
	_shop_open = true
	_paused = true
	_release_attack()
	if is_instance_valid(touch_controls):
		touch_controls.release_all()
	_current_shop_offers = ShopCatalog.build_offers(weapons, passives, mercenaries, _rng)
	shop_overlay.show_shop(
		_current_shop_offers,
		run_coin,
		int(shop_data.get("reroll_cost", 25)),
		_shop_mercenary_info()
	)
	AudioBus.play_confirm()
	_sync_gameplay_cursor()


func _on_shop_buy(index: int) -> void:
	if not _shop_open or index < 0 or index >= _current_shop_offers.size():
		return
	var offer := _current_shop_offers[index]
	if bool(offer.get("sold", false)):
		return
	var price := int(offer.get("price", 0))
	if run_coin < price:
		shop_overlay.show_message(Locale.t("shop.not_enough"), true)
		_play_sfx(SFX_EVENT, 0.72, 0.55)
		return
	if not _apply_shop_offer(offer):
		shop_overlay.show_message(Locale.t("shop.unavailable"), true)
		return
	run_coin -= price
	offer["sold"] = true
	_current_shop_offers[index] = offer
	_recompute_stats()
	shop_overlay.refresh(
		_current_shop_offers,
		run_coin,
		int(shop_data.get("reroll_cost", 25)),
		_shop_mercenary_info()
	)
	shop_overlay.show_message(Locale.t("shop.bought", {"name": str(offer.get("title", ""))}))
	hud.update_hud(_hud_state())
	AudioBus.play_confirm()


func _apply_shop_offer(offer: Dictionary) -> bool:
	match str(offer.get("family", "")):
		"weapon_new":
			var weapon_id := str(offer.get("weapon_id", ""))
			if _has_weapon(weapon_id) or weapons.size() >= 6:
				return false
			_add_weapon(weapon_id)
			return _has_weapon(weapon_id)
		"weapon_upgrade":
			var weapon_id := str(offer.get("weapon_id", ""))
			for weapon in weapons:
				if str(weapon["id"]) != weapon_id:
					continue
				if int(weapon["level"]) >= 5:
					return false
				weapon["level"] = int(weapon["level"]) + 1
				return true
			return false
		"equipment_new", "equipment_upgrade":
			var passive_id := str(offer.get("passive_id", ""))
			if not passive_defs.has(passive_id):
				return false
			var definition: Dictionary = passive_defs[passive_id] as Dictionary
			if int(passives.get(passive_id, 0)) >= int(definition.get("max_level", 5)):
				return false
			passives[passive_id] = int(passives.get(passive_id, 0)) + 1
			return true
		"mercenary":
			return _hire_mercenary(str(offer.get("mercenary_id", "")))
		"supply_heal":
			player["hp"] = minf(
				float(player["max_hp"]),
				float(player["hp"]) + float(player["max_hp"]) * 0.32
			)
			return true
		"supply_oil":
			player["oil"] = mini(int(player["oil_max"]), int(player["oil"]) + 3)
			return true
	return false


func _hire_mercenary(mercenary_id: String) -> bool:
	if mercenary_id.is_empty() or not mercenary_defs.has(mercenary_id):
		return false
	if mercenaries.has(mercenary_id):
		return false
	if mercenaries.size() >= int(shop_data.get("max_mercenaries", 3)):
		return false
	var angle := TAU * float(mercenaries.size()) / float(maxi(1, int(shop_data.get("max_mercenaries", 3))))
	var spawn_position := (player["pos"] as Vector2) + Vector2(cos(angle), sin(angle)) * 54.0
	if not battlefield.spawn_ally(mercenary_id, spawn_position):
		return false
	mercenaries.append(mercenary_id)
	_recompute_stats()
	var definition: Dictionary = mercenary_defs[mercenary_id] as Dictionary
	hud.show_banner(
		Locale.t("shop.mercenary_joined", {"name": GameData.loc(definition, "name")}),
		GameData.loc(definition, "role"),
		2.6
	)
	_play_sfx(SFX_EVENT, 1.10, 0.64)
	return true


func _on_shop_reroll() -> void:
	if not _shop_open:
		return
	var cost := int(shop_data.get("reroll_cost", 25))
	if run_coin < cost:
		shop_overlay.show_message(Locale.t("shop.not_enough"), true)
		return
	run_coin -= cost
	_current_shop_offers = ShopCatalog.build_offers(weapons, passives, mercenaries, _rng)
	shop_overlay.refresh(
		_current_shop_offers,
		run_coin,
		cost,
		_shop_mercenary_info()
	)
	shop_overlay.show_message(Locale.t("shop.rerolled"))
	hud.update_hud(_hud_state())
	AudioBus.play_confirm()


func _on_shop_closed() -> void:
	if not _shop_open:
		return
	_shop_open = false
	_next_shop_time = elapsed + float(shop_data.get("interval_seconds", 120.0))
	shop_overlay.visible = false
	if not _game_over and not _victory_started:
		_paused = false
	_sync_gameplay_cursor()


func _shop_mercenary_info() -> Dictionary:
	var names: Array[String] = []
	for mercenary_id in mercenaries:
		var definition: Dictionary = mercenary_defs.get(mercenary_id, {}) as Dictionary
		if not definition.is_empty():
			names.append(GameData.loc(definition, "name"))
	return {
		"count": mercenaries.size(),
		"max": int(shop_data.get("max_mercenaries", 3)),
		"names": " · ".join(names),
	}


func _on_ally_support(_source_id: String, kind: String, amount: float) -> void:
	if kind == "heal":
		player["hp"] = minf(float(player["max_hp"]), float(player["hp"]) + amount)


func _apply_card(option: Dictionary) -> void:
	var card_id := str(option.get("card_id", ""))
	if card_id.is_empty():
		return
	card_levels[card_id] = int(option.get("level", 1))
	_recompute_stats()
	if str(option.get("family", "")) == "skill":
		hud.show_banner(
			str(option.get("title", "")),
			str(option.get("culture", "")),
			2.4
		)


func _apply_event(option: Dictionary) -> void:
	var card_id := str(option.get("card_id", ""))
	var definition: Dictionary = option.get("definition", {}) as Dictionary
	used_events[card_id] = true
	var hp_pct := 0.0
	var full_heal := false
	var oil_delta := 0
	var merit_delta := 0
	var spawn_elite := 0
	var spawn_wave := 0
	for effect in definition.get("effects", []) as Array:
		if not effect is Dictionary:
			continue
		var stat := str((effect as Dictionary).get("stat", ""))
		var amount := float((effect as Dictionary).get("amount", 0.0))
		match stat:
			"event_hp_pct":
				hp_pct += amount
			"event_full_heal":
				full_heal = true
			"event_oil":
				oil_delta += int(amount)
			"event_merit":
				merit_delta += int(amount)
			"event_spawn_elite":
				spawn_elite += int(amount)
			"event_spawn_wave":
				spawn_wave += int(amount)
			"event_enemy_speed":
				_event_enemy_speed_mult += amount
			_:
				event_stat_bonuses[stat] = float(event_stat_bonuses.get(stat, 0.0)) + amount
	_recompute_stats()
	if full_heal:
		player["hp"] = float(player["max_hp"])
	if not is_zero_approx(hp_pct):
		player["hp"] = clampf(
			float(player["hp"]) + float(player["max_hp"]) * hp_pct,
			1.0,
			float(player["max_hp"])
		)
	if oil_delta != 0:
		player["oil"] = clampi(int(player["oil"]) + oil_delta, 0, int(player["oil_max"]))
	if merit_delta != 0:
		merit += merit_delta
	var origin := player["pos"] as Vector2
	for i in range(spawn_elite):
		battlefield.spawn_enemy("general", origin, "red")
	for i in range(spawn_wave):
		battlefield.spawn_enemy("scout", origin)
	_show_event_line(option)
	hud.show_banner(str(option.get("title", "")), str(option.get("effect_summary", "")), 2.8)
	_play_sfx(SFX_EVENT, 0.88, 0.78)


func _show_event_line(option: Dictionary) -> void:
	var culture := str(option.get("culture", ""))
	if culture.is_empty():
		return
	narrative.show_line({
		"speaker_zh": Locale.t("event.speaker"),
		"speaker_en": Locale.t("event.speaker"),
		"zh": culture,
		"en": culture,
		"category": str(option.get("category", "演绎")),
		"source_ref": str(option.get("source_ref", "")),
	})
	_narrative_timer.start(5.8)


func _has_weapon(weapon_id: String) -> bool:
	for weapon in weapons:
		if str(weapon["id"]) == weapon_id:
			return true
	return false


func _on_oil_collected(amount: int) -> void:
	player["oil"] = mini(int(player["oil_max"]), int(player["oil"]) + amount)
	hud.show_banner(Locale.t("banner.oil"), "", 1.2)
	_play_sfx(SFX_PICKUP, 1.05, 0.70)


func _on_heal_collected(amount: float) -> void:
	player["hp"] = minf(float(player["max_hp"]), float(player["hp"]) + amount)
	_play_sfx(SFX_PICKUP, 0.82, 0.72)


func _on_scale_collected(color: String) -> void:
	if scales.has(color):
		return
	scales.append(color)
	hud.show_banner(Locale.t("banner.scale", {"count": scales.size()}), "", 1.8)
	_play_sfx(SFX_PICKUP, 1.34, 0.76)
	if scales.size() >= 5:
		var names := {
			"red": "红",
			"yellow": "黄",
			"blue": "蓝",
			"green": "绿",
			"black": "黑",
		}
		battlefield.trigger_five_dragon(player["pos"] as Vector2)
		hud.show_banner(Locale.t("banner.five_dragon"), Locale.t("banner.five_dragon_sub"), 4.2)
		merit += 500
		_add_xp(180.0)
		_play_sfx(SFX_WIN)


func _on_boss_spawned(_enemy_id: String, _max_hp: float) -> void:
	_boss_spawned = true


func _on_boss_defeated(_enemy_id: String) -> void:
	_boss_defeated = true
	hud.show_banner(Locale.t("banner.boss_down"), Locale.t("banner.boss_down_sub"), 4.0)
	merit += 2000
	run_coin += int(shop_data.get("boss_coin", 120))
	_add_xp(260.0)
	_play_sfx(SFX_ELITE_KILL, 0.72, 0.92)
	_play_sfx(SFX_WIN)


func _begin_victory() -> void:
	if _victory_started:
		return
	_victory_started = true
	_paused = true
	_release_attack()
	_story_mode = "epilogue"
	narrative.clear_line()
	battlefield.clear_all_effects()
	story.start(narrative_data.get("epilogue", []) as Array, Locale.t("story.epilogue_heading"))
	_play_sfx(SFX_WIN)


func _begin_defeat() -> void:
	if _game_over:
		return
	_game_over = true
	_paused = true
	_release_attack()
	narrative.clear_line()
	_play_sfx(SFX_LOSE)
	_show_result(false)


func _show_result(victory: bool) -> void:
	if result_overlay.visible:
		return
	_game_over = true
	_paused = true
	_release_attack()
	result_title.text = Locale.t("result.victory" if victory else "result.defeat")
	result_body.text = Locale.t("result.victory_body" if victory else "result.defeat_body")
	result_stats.text = Locale.t("result.stats", {
		"time": _clock_text(elapsed),
		"kills": kills,
		"merit": merit,
		"level": level,
		"scales": scales.size(),
	})
	var unlocks := _new_unlocks(_run_start_merit, _run_start_merit + merit)
	result_unlocks.text = Locale.t("result.unlocks", {
		"unlocks": " · ".join(unlocks),
	}) if not unlocks.is_empty() else Locale.t("result.no_unlocks")
	result_overlay.visible = true
	SaveSystem.record_run(merit, kills, victory, elapsed)
	_result_recorded = true
	SaveSystem.data["run_scales"] = scales.size()
	SaveSystem.autosave({"last_mode": "result"})
	_sync_gameplay_cursor()


func _new_unlocks(before: int, after: int) -> Array[String]:
	var unlocked: Array[String] = []
	var characters := GameData.get_characters()
	for character_id in ["amei", "ashi", "achong", "agong", "aqi"]:
		var entry := characters.get(character_id, {}) as Dictionary
		var threshold := int(entry.get("unlock_merit", 0))
		if threshold > before and threshold <= after:
			unlocked.append(GameData.loc(entry, "preset_name"))
	var maps := GameData.get_maps()
	for map_id in ["watergate", "crossstreet"]:
		var entry := maps.get(map_id, {}) as Dictionary
		var threshold := int(entry.get("unlock_merit", 0))
		if threshold > before and threshold <= after:
			unlocked.append(GameData.loc(entry, "name"))
	return unlocked


func _set_pause(paused: bool) -> void:
	if _game_over:
		return
	_paused = paused
	if paused:
		_release_attack()
	pause_overlay.visible = paused
	if paused:
		var stats := pause_overlay.find_child("PauseStats", true, false) as Label
		if stats != null:
			stats.text = Locale.t("pause.stats", {
				"time": _clock_text(elapsed),
				"kills": kills,
				"level": level,
				"weapons": weapons.size(),
				"passives": passives.size(),
			})
		var resume := pause_overlay.find_child("ResumeButton", true, false) as Button
		if resume != null:
			resume.grab_focus()
	_sync_gameplay_cursor()


func _release_attack() -> void:
	_attack_held = false
	_attack_buffer = 0.0


func _gameplay_cursor_should_show() -> bool:
	return _gameplay_input_allowed()


func _sync_gameplay_cursor() -> void:
	_set_gameplay_cursor(_gameplay_cursor_should_show())


func _set_gameplay_cursor(active: bool) -> void:
	if DisplayServer.get_name() == "headless":
		active = false
	if active == _gameplay_cursor_active:
		return
	if active:
		if _gameplay_cursor == null:
			_gameplay_cursor = load(GAMEPLAY_CURSOR_PATH) as Texture2D
		if _gameplay_cursor == null:
			push_warning("Gameplay cursor is missing: %s" % GAMEPLAY_CURSOR_PATH)
			return
		Input.set_custom_mouse_cursor(
			_gameplay_cursor,
			Input.CURSOR_ARROW,
			GAMEPLAY_CURSOR_HOTSPOT
		)
	else:
		Input.set_custom_mouse_cursor(null)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_gameplay_cursor_active = active


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_attack()
		_set_gameplay_cursor(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_sync_gameplay_cursor()


func _exit_tree() -> void:
	_set_gameplay_cursor(false)


func _update_camera(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	var target := player["pos"] as Vector2
	var blend := 1.0 - exp(-12.0 * delta)
	camera.position = camera.position.lerp(target, clampf(blend, 0.0, 1.0))
	if camera.position.distance_squared_to(target) > 320.0 * 320.0:
		camera.position = target


func debug_prepare_capture(mode: String, page: int = 0) -> Dictionary:
	story.visible = false
	tutorial_overlay.visible = false
	_tutorial_first_run = false
	_run_started = true
	level_up_overlay.hide_options()
	shop_overlay.visible = false
	_shop_open = false
	narrative.clear_line()
	if is_instance_valid(_narrative_timer):
		_narrative_timer.stop()
	_game_over = false
	_victory_started = false
	_paused = false
	_event_line_index = _event_lines.size()
	_scale_event_index = _scale_events.size()
	elapsed = maxf(elapsed, 480.0)
	_next_shop_time = elapsed + 99999.0
	var capture_center := battlefield.player_spawn_position()
	player["pos"] = capture_center
	player["hp"] = float(player["max_hp"])
	if card_levels.is_empty():
		card_levels = {
			"lantern_nova": 3,
			"tide_slow": 2,
			"iron_scale": 3,
		}
		_recompute_stats()
	player["shield_max"] = 45.0
	player["shield"] = 45.0
	run_coin = maxi(run_coin, 999)
	camera.position = capture_center
	battlefield.player_pos = capture_center
	battlefield.clear_all_effects()
	if mode == "aim":
		battlefield.enemies.clear()
		battlefield.allies.clear()
		battlefield.towers.clear()
		_paused = true
		_auto_attack = false
		_aim_direction = Vector2(0.8, -0.6).normalized()
		battlefield.player_aim = _aim_direction
		battlefield.queue_redraw()
		hud.update_hud(_hud_state())
		_set_gameplay_cursor(false)
		return {"mode": mode, "enemies": battlefield.enemies.size()}
	var ring_ids := ["scout", "ronin", "archer", "shield", "gun", "banner", "general"]
	for i in range(44):
		var angle := TAU * float(i) / 44.0
		var radius := 150.0 + float(i % 7) * 26.0
		var position := capture_center + Vector2(cos(angle), sin(angle)) * radius
		var enemy_id: String = str(ring_ids[i % ring_ids.size()])
		battlefield.spawn_enemy_at(enemy_id, position, "red" if enemy_id == "general" else "")
	# 箭塔展示：三档各一座，验证贴图、血条与围攻逻辑
	if mode == "tower" or mode == "fx":
		var tower_spots := [
			Vector2(-230, -60), Vector2(230, -60), Vector2(0, 210),
		]
		for i in range(tower_spots.size()):
			var tower_id: String = ["watchtower", "arrow_tower", "dragon_tower"][i]
			battlefield.spawn_tower(tower_id, capture_center + (tower_spots[i] as Vector2))
		_towers_built = battlefield.towers.size()
	if mode == "tutorial":
		_paused = true
		_release_attack()
		_set_gameplay_cursor(false)
		tutorial_overlay.open(true)
		tutorial_overlay._go_page(clampi(page, 0, TutorialOverlay.PAGE_COUNT - 1))
		return {"mode": mode, "tutorial_visible": tutorial_overlay.visible}
	if mode == "tower":
		# 战斗验收照：不放 7 条展示弧，只看实际战斗画面
		return {"mode": mode, "towers": battlefield.live_tower_count(), "enemies": battlefield.enemies.size()}
	for i in range(7):
		var angle := TAU * float(i) / 7.0
		battlefield.add_effect({
			"type": "slash",
			"pos": capture_center,
			"ttl": 1.4,
			"max_ttl": 1.4,
			"radius": 168.0 + float(i) * 20.0,
			"angle": angle,
			"arc": 1.3,
			"color": Color(0.94, 0.74, 0.35, 0.55),
		})
	if mode == "shop":
		if mercenaries.is_empty():
			_hire_mercenary("yishi_spear")
			_hire_mercenary("wangpei_spirit")
		_open_shop()
	elif mode == "mercenary":
		if mercenaries.is_empty():
			_hire_mercenary("yishi_spear")
			_hire_mercenary("qijia_guest")
			_hire_mercenary("wangpei_spirit")
		var ally_center := player["pos"] as Vector2
		for i in range(12):
			var angle := TAU * float(i) / 12.0
			battlefield.spawn_enemy_at(
				["scout", "ronin", "archer", "shield"][i % 4],
				ally_center + Vector2(cos(angle), sin(angle)) * 150.0
			)
		hud.show_banner(Locale.t("capture.mercenary_title"), Locale.t("capture.mercenary_sub"), 8.0)
	elif mode == "choice":
		_paused = true
		var showcase: Array[Dictionary] = []
		var cards := UpgradeCatalog.build_card_pool(card_levels, used_events, 0.8)
		for family in ["attribute", "skill", "event"]:
			for option in cards:
				if str(option.get("family", "")) == family:
					showcase.append(option)
					break
		if showcase.size() < 3:
			showcase = _build_upgrade_options()
		_current_upgrade_options = showcase
		level_up_overlay.show_options(showcase, maxi(level, 12), {
			"pool": _upgrade_pool_count(),
			"taken": card_levels.size() + passives.size() + weapons.size(),
		})
	elif mode == "fx":
		_paused = true
		var weapon_ids := ["saber", "spear", "bow", "musket", "dragon_lantern", "cannon", "banner"]
		for i in range(weapon_ids.size()):
			var angle := TAU * float(i) / float(weapon_ids.size())
			var direction := Vector2(cos(angle), sin(angle))
			battlefield.play_player_attack_fx(
				str(weapon_ids[i]),
				capture_center + direction * 76.0,
				direction,
				i % 2 == 1
			)
		var enemy_ids := ["scout", "ronin", "archer", "shield", "gun", "banner", "general", "daimyo"]
		for i in range(enemy_ids.size()):
			var angle := TAU * (float(i) + 0.5) / float(enemy_ids.size())
			var direction := Vector2(cos(angle), sin(angle))
			battlefield.play_enemy_attack_fx(
				str(enemy_ids[i]),
				capture_center + direction * 142.0,
				direction
			)
		var ally_ids := [
			"yishi_spear",
			"yishi_archer",
			"tengpai_militia",
			"bird_gunner",
			"standard_bearer",
			"qijia_guest",
			"wangpei_spirit",
			"wangde_spirit",
		]
		for i in range(ally_ids.size()):
			var angle := TAU * float(i) / float(ally_ids.size())
			var direction := Vector2(cos(angle), sin(angle))
			battlefield.play_ally_attack_fx(
				str(ally_ids[i]),
				capture_center + direction * 214.0,
				direction
			)
		battlefield.play_impact_fx(capture_center + Vector2(0, -150), "critical", 1.2)
		battlefield.play_impact_fx(capture_center + Vector2(150, 0), "armored", 1.0)
		battlefield.play_impact_fx(capture_center + Vector2(-150, 0), "heavy", 1.0)
		battlefield.update_world(0.0, player, 0.0)
		battlefield.queue_redraw()
	else:
		_cast_skill("slow", 2)
		_cast_skill("burn", 2)
		_cast_skill("stun", 2)
		_cast_skill("chain", 2)
		if mode == "touch" and is_instance_valid(touch_controls):
			touch_controls.force_visible = true
			touch_controls.visible = true
			touch_controls.set_process_input(true)
			touch_controls.move_vector = Vector2(0.72, -0.26)
			touch_controls.queue_redraw()
		hud.show_banner(Locale.t("capture.combat_title"), Locale.t("capture.combat_sub"), 8.0)
	hud.update_hud(_hud_state())
	_sync_gameplay_cursor()
	return {
		"mode": mode,
		"enemies": battlefield.alive_count(),
		"options": _current_upgrade_options.size(),
		"player_hp": player["hp"],
		"pool": _upgrade_pool_count(),
	}


func _hud_state() -> Dictionary:
	var weapon_views: Array[Dictionary] = []
	for weapon in weapons:
		var definition: Dictionary = weapon["definition"] as Dictionary
		weapon_views.append({
			"id": weapon["id"],
			"name": GameData.loc(definition, "evolve_name") if bool(weapon["evolved"]) else GameData.loc(definition, "name"),
			"icon": str(definition.get("icon", "")),
			"level": int(weapon["level"]),
			"max_level": 5,
			"evolved": bool(weapon["evolved"]),
		})
	var passive_parts: Array[String] = []
	for passive_id in passives.keys():
		if passive_defs.has(passive_id):
			var definition: Dictionary = passive_defs[passive_id] as Dictionary
			passive_parts.append("%s %d" % [GameData.loc(definition, "name"), int(passives[passive_id])])
	var boss := _active_boss()
	var boss_name := ""
	var boss_hp := 0.0
	var boss_max := 1.0
	if not boss.is_empty():
		boss_name = GameData.loc(enemy_defs.get(str(boss["id"]), {}) as Dictionary, "name")
		boss_hp = float(boss["hp"])
		boss_max = float(boss["max_hp"])
	return {
		"hp": player.get("hp", 0.0),
		"max_hp": player.get("max_hp", 100.0),
		"shield": player.get("shield", 0.0),
		"xp": xp,
		"xp_need": xp_need,
		"level": level,
		"kills": kills,
		"merit": merit,
		"coin": run_coin,
		"elapsed": elapsed,
		"duration": duration,
		"oil": player.get("oil", 0),
		"oil_max": player.get("oil_max", 6),
		"dark": bool(player.get("dark", false)),
		"weapons": weapon_views,
		"passives": passives,
		"passive_summary": " · ".join(passive_parts),
		"mercenary_summary": _shop_mercenary_info().get("names", ""),
		"mercenary_count": mercenaries.size(),
		"mercenary_max": int(shop_data.get("max_mercenaries", 3)),
		"skills": active_skills.size(),
		"cards": card_levels.size(),
		"auto_attack": _auto_attack,
		"attack_mode": Locale.t("hud.attack_auto" if _auto_attack else "hud.attack_manual"),
		"attack_toggle": Locale.t("hud.attack_toggle", {"key": InputSetup.describe("toggle_auto_attack")}),
		"move_hint": Locale.t("hud.move_hint"),
		"scales": scales,
		"boss_active": not boss.is_empty(),
		"boss_name": boss_name,
		"boss_hp": boss_hp,
		"boss_max_hp": boss_max,
		"build_label": Locale.t("hud.build", {"weapons": weapons.size(), "passives": passives.size()}),
	}


func _build_pause_overlay() -> void:
	pause_overlay = Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.z_index = 60
	pause_overlay.visible = false
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.add_child(pause_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.006, 0.010, 0.012, 0.82)
	pause_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	UILayout.place(panel, 390, 125, 500, 470, 0.5, 0.5)
	panel.add_theme_stylebox_override("panel", _panel_texture_box())
	pause_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := _label(Locale.t("pause.title"), 36, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.30)
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)
	var stats := _label("", 15, Color(PAPER, 0.86))
	stats.name = "PauseStats"
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.custom_minimum_size = Vector2(0, 86)
	column.add_child(stats)
	var resume := _small_button(Locale.t("pause.resume"), true)
	resume.name = "ResumeButton"
	resume.pressed.connect(func() -> void: _set_pause(false))
	column.add_child(resume)
	var tutorial := _small_button(Locale.t("pause.tutorial"), false)
	tutorial.name = "PauseTutorialButton"
	tutorial.pressed.connect(func() -> void: _open_tutorial(false))
	column.add_child(tutorial)
	var restart := _small_button(Locale.t("pause.restart"), false)
	restart.name = "RestartButton"
	restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
	column.add_child(restart)
	var back := _small_button(Locale.t("pause.back"), false)
	back.name = "PauseBackButton"
	back.pressed.connect(_return_to_menu)
	column.add_child(back)
	var hint := _label(Locale.t("pause.hint"), 12, Color(MUTED, 0.56))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _build_result_overlay() -> void:
	result_overlay = Control.new()
	result_overlay.name = "ResultOverlay"
	result_overlay.z_index = 70
	result_overlay.visible = false
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.add_child(result_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.006, 0.010, 0.012, 0.89)
	result_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	UILayout.place(panel, 344, 100, 592, 520, 0.5, 0.5)
	panel.add_theme_stylebox_override("panel", _panel_texture_box())
	result_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	panel.add_child(column)
	result_title = _label("", 48, GOLD)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(result_title)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.32)
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)
	result_body = _label("", 19, PAPER)
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_body.custom_minimum_size = Vector2(0, 112)
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(result_body)
	result_stats = _label("", 16, Color(MUTED, 0.9))
	result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_stats.custom_minimum_size = Vector2(0, 64)
	column.add_child(result_stats)
	result_unlocks = _label("", 15, Color(GOLD, 0.92))
	result_unlocks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_unlocks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_unlocks.custom_minimum_size = Vector2(0, 48)
	column.add_child(result_unlocks)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	column.add_child(action_row)
	var codex := _small_button(Locale.t("codex.open"), false)
	codex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codex.pressed.connect(_open_codex)
	action_row.add_child(codex)
	var retry := _small_button(Locale.t("result.retry"), true)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(func() -> void: get_tree().reload_current_scene())
	action_row.add_child(retry)
	var back := _small_button(Locale.t("result.back"), false)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_return_to_menu)
	action_row.add_child(back)


func _return_to_menu() -> void:
	_set_gameplay_cursor(false)
	if not _result_recorded:
		SaveSystem.record_run(merit, kills, false, elapsed)
	SaveSystem.autosave({"last_mode": "menu"})
	AudioBus.resume_bgm()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _play_sfx(stream: AudioStream, pitch_scale: float = 1.0, volume_scale: float = 1.0) -> void:
	if stream == null or DisplayServer.get_name() == "headless" or _sfx_players.is_empty():
		return
	var player_node := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	player_node.stream = stream
	player_node.pitch_scale = pitch_scale
	var volume := clampf(GameSettings.sfx_volume * volume_scale, 0.0, 1.0)
	player_node.volume_db = -80.0 if volume <= 0.001 else linear_to_db(volume)
	player_node.play()


func _clock_text(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d" % [int(total / 60), total % 60]


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _small_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", PAPER)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(GOLD, 0.14 if primary else 0.05)
	box.border_color = Color(GOLD, 0.68 if primary else 0.25)
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


func _panel_texture_box() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = PANEL_TEXTURE
	box.texture_margin_left = 28.0
	box.texture_margin_top = 28.0
	box.texture_margin_right = 28.0
	box.texture_margin_bottom = 28.0
	box.content_margin_left = 34.0
	box.content_margin_right = 34.0
	box.content_margin_top = 28.0
	box.content_margin_bottom = 24.0
	return box
