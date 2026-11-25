extends GutTest

const TEST_SAVE := "user://test_game_core_save.json"
const ForgeScript = preload("res://scripts/character/character_forge.gd")


func before_each() -> void:
	SaveSystem.save_path = TEST_SAVE
	SaveSystem.reset_memory()
	Locale.set_language("zh", false)


func after_each() -> void:
	SaveSystem.save_path = SaveSystem.SAVE_PATH
	_remove_user_file(TEST_SAVE)


func test_gameplay_data_is_complete_and_bilingual() -> void:
	var weapons := GameData.get_weapons()
	var passives := GameData.get_passives()
	var enemies := GameData.get_enemies()
	assert_eq(weapons.size(), 7)
	assert_false(weapons.has("shield"), "shields must be defensive equipment, never a player weapon")
	assert_gte(passives.size(), 8)
	assert_gte(enemies.size(), 6)
	for weapon_id in weapons.keys():
		var definition: Dictionary = weapons[weapon_id]
		assert_true(definition.has("name_zh"))
		assert_true(definition.has("name_en"))
		assert_true(definition.has("type"))
		assert_true(float(definition.get("damage", 0.0)) > 0.0)
	for enemy_id in enemies.keys():
		var definition: Dictionary = enemies[enemy_id]
		assert_true(ResourceLoader.exists(str(definition.get("texture", ""))), "missing enemy texture: %s" % enemy_id)
		assert_false(
			str(definition.get("texture", "")).contains("/static.png"),
			"%s still points at a retired static unit sheet" % enemy_id
		)
		assert_true(float(definition.get("hp", 0.0)) > 0.0)


func test_enemy_art_is_baked_from_faction_valid_forge_recipes() -> void:
	var forge := ForgeScript.new()
	add_child_autofree(forge)
	if not forge.load_data():
		fail_test("character forge data must load")
		return
	var enemies := GameData.get_enemies()
	for enemy_id in enemies.keys():
		var definition: Dictionary = enemies[enemy_id]
		var recipe: Dictionary = definition.get("character_recipe", {}) as Dictionary
		assert_false(recipe.is_empty(), "%s needs a forge recipe" % enemy_id)
		assert_eq(str(recipe.get("faction", "")), "wokou", "%s must be Wokou" % enemy_id)
		assert_true(forge.recipe_faction_valid(recipe), "%s mixes factions" % enemy_id)
		forge.set_recipe(recipe)
		assert_eq(forge.current_faction(), "wokou")
		assert_gte(forge.layer_count(), 5, "%s must keep body and gear layers" % enemy_id)
		assert_true(forge.layer_rows().has("body"), "%s needs the naked body base" % enemy_id)
		assert_true(forge.layer_rows().has("outfit"), "%s needs an outfit layer" % enemy_id)
		assert_true(forge.layer_rows().has("weapon"), "%s needs a weapon layer" % enemy_id)
		var strip := load(str(definition.get("texture", ""))) as Texture2D
		assert_not_null(strip, "%s walk strip must load" % enemy_id)
		if strip != null:
			assert_eq(
				strip.get_width(),
				int(definition.get("sprite_frames", 0)) * int(forge.data.get("cell", 128)),
				"%s walk strip width" % enemy_id
			)
			assert_eq(strip.get_height(), int(forge.data.get("cell", 128)))


func test_player_battle_art_uses_forge_recipes_and_baked_strips() -> void:
	var forge := ForgeScript.new()
	add_child_autofree(forge)
	if not forge.load_data():
		fail_test("character forge data must load")
		return
	var characters := GameData.get_characters()
	for character_id in characters.keys():
		var definition: Dictionary = characters[character_id]
		var recipe: Dictionary = definition.get("character_recipe", {}) as Dictionary
		assert_false(recipe.is_empty(), "%s needs a battle recipe" % character_id)
		assert_eq(str(recipe.get("faction", "")), "ming", "%s must be Ming" % character_id)
		assert_true(forge.recipe_faction_valid(recipe), "%s mixes factions" % character_id)
		forge.set_recipe(recipe)
		assert_eq(forge.current_faction(), "ming")
		assert_true(forge.layer_rows().has("body"), "%s needs the naked body base" % character_id)
		for path_key in ["battle_idle", "battle_walk"]:
			var path := str(definition.get(path_key, ""))
			assert_true(ResourceLoader.exists(path), "%s %s missing" % [character_id, path_key])
			assert_false(path.contains("/static.png"), "%s still uses an old static sheet" % character_id)
		var idle := load(str(definition.get("battle_idle", ""))) as Texture2D
		var walk := load(str(definition.get("battle_walk", ""))) as Texture2D
		assert_not_null(idle)
		assert_not_null(walk)
		if idle != null and walk != null:
			var cell := int(forge.data.get("cell", 128))
			assert_eq(idle.get_width(), int(definition.get("battle_idle_frames", 0)) * cell)
			assert_eq(walk.get_width(), int(definition.get("battle_walk_frames", 0)) * cell)
			assert_eq(idle.get_height(), cell)
			assert_eq(walk.get_height(), cell)


func test_roster_and_maps_are_complete_and_historically_bounded() -> void:
	var characters := GameData.get_characters()
	var maps := GameData.get_maps()
	var weapons := GameData.get_weapons()
	var passives := GameData.get_passives()
	assert_eq(characters.size(), 7)
	assert_eq(maps.size(), 3)
	var selectable := 0
	for character_id in characters.keys():
		var character: Dictionary = characters[character_id]
		assert_true(character.has("name_zh"))
		assert_true(character.has("name_en"))
		assert_true(weapons.has(str(character.get("starting_weapon", ""))))
		assert_true(passives.has(str(character.get("starting_passive", ""))))
		assert_false(character.has("texture"), "%s must not keep a retired portrait path" % character_id)
		if bool(character.get("selectable", false)):
			selectable += 1
			assert_string_contains(str(character.get("note_zh", "")), "王陆")
	assert_eq(selectable, 6, "the 1559 screen must expose six Wang Lu watch posts")
	assert_false(bool((characters["tanghe"] as Dictionary).get("selectable", true)))
	for character_id in ["wanglu", "amei", "ashi", "achong", "agong", "aqi"]:
		var character: Dictionary = characters[character_id]
		assert_eq(str(character.get("name_zh", "")), "王陆")
		assert_gt(str(character.get("preset_name_zh", "")).length(), 0)
		assert_string_contains(str(character.get("battle_idle", "")), "/forge/players/")
	assert_false(characters.has("wangpei"))
	assert_false(characters.has("wangde"))
	for map_id in maps.keys():
		var map: Dictionary = maps[map_id]
		assert_true(map.has("name_zh"))
		assert_true(map.has("name_en"))
		assert_true(float(map.get("enemy_speed_mult", 0.0)) > 0.0)
		assert_true(float(map.get("spawn_rate_mult", 0.0)) > 0.0)
		assert_true(float(map.get("oil_interval", 0.0)) > 0.0)


func test_character_data_has_no_retired_static_sheets() -> void:
	var raw := FileAccess.get_file_as_string("res://data/characters.json")
	assert_false(raw.contains("assets/units/xiangyong/static.png"))
	assert_false(raw.contains("assets/units/jinshi/static.png"))


func test_waves_reach_boss_and_dawn() -> void:
	var waves := GameData.load_json("res://data/waves.json")
	assert_eq(float(waves.get("duration_seconds", 0.0)), 960.0)
	assert_eq(float(waves.get("boss_second", 0.0)), 930.0)
	var phases: Array = waves.get("phases", [])
	assert_gte(phases.size(), 8)
	assert_eq((waves.get("scale_events", []) as Array).size(), 5)


func test_battlefield_spatial_hash_damage_and_pickups() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(42)
	assert_eq((field.enemy_sprite_frames["scout"] as Array).size(), 8)
	field.set_player_sprites(GameData.get_characters()["wanglu"] as Dictionary)
	assert_eq(field.player_idle_frames.size(), 4)
	assert_eq(field.player_walk_frames.size(), 8)
	var index := field.spawn_enemy_at("scout", Vector2(40, 0))
	assert_eq(index, 0)
	assert_eq(field.alive_count(), 1)
	var hits := field.damage_circle(Vector2.ZERO, 80.0, 100.0, 10.0)
	assert_eq(hits, 1)
	assert_eq(field.orbs.size(), 1, "kills must leave experience pickups")
	field.update_world(1.0 / 60.0, {
		"pos": Vector2(500, 0),
		"radius": 18.0,
		"pickup_radius": 0.0,
	})
	assert_eq(field.alive_count(), 0, "lethal damage must clear the enemy")
	assert_eq(field.orbs.size(), 1, "kills must leave experience pickups")


func test_difficulty_curve_eases_in_and_clamps_at_dawn() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	var curve := (GameData.load_json("res://data/waves.json").get("difficulty", {}) as Dictionary)
	assert_false(curve.is_empty())
	field.set_difficulty(0.5, curve)
	assert_almost_eq(field.difficulty_hp_mult, 1.1125, 0.0001)
	assert_almost_eq(field.difficulty_damage_mult, 1.05, 0.0001)
	assert_almost_eq(field.difficulty_speed_mult, 1.02, 0.0001)
	field.set_difficulty(2.0, curve)
	assert_eq(field.difficulty_hp_mult, 1.45)
	assert_eq(field.difficulty_damage_mult, 1.2)
	assert_eq(field.difficulty_speed_mult, 1.08)
	field.set_difficulty(-1.0, curve)
	assert_eq(field.difficulty_hp_mult, 1.0)
	assert_eq(field.difficulty_damage_mult, 1.0)
	assert_eq(field.difficulty_speed_mult, 1.0)


func test_high_frequency_battle_objects_reuse_pooled_dictionaries() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(77)
	field.set_player_sprites(GameData.get_characters()["wanglu"] as Dictionary)

	var first_shots: Array[Dictionary] = []
	for index in range(96):
		field.fire_player_projectile(Vector2(100 + index, 100), Vector2.RIGHT, 400.0, 1.0, 1)
	for shot in field.player_shots:
		shot["ttl"] = 0.0
		first_shots.append(shot)
	field._update_effects(0.02)
	assert_eq(field.player_shots.size(), 0)
	for index in range(96):
		field.fire_player_projectile(Vector2(100 + index, 100), Vector2.RIGHT, 400.0, 1.0, 1)
	var reused_shots := 0
	for shot in field.player_shots:
		for previous in first_shots:
			if is_same(shot, previous):
				reused_shots += 1
				break
	assert_gte(reused_shots, 90, "projectiles must be recycled instead of reallocated every shot")

	var first_orbs: Array[Dictionary] = []
	for index in range(6):
		var enemy_index := field.spawn_enemy_at("scout", Vector2(600 + index * 8, 600))
		field.damage_enemy(enemy_index, 99999.0, Vector2.ZERO, Color.WHITE, false, false)
	for orb in field.orbs:
		first_orbs.append(orb)
		orb["taken"] = true
	field._update_pickups(0.02, {"pos": Vector2(600, 600), "radius": 18.0, "pickup_radius": 30.0})
	assert_eq(field.orbs.size(), 0)
	for index in range(6):
		var enemy_index := field.spawn_enemy_at("scout", Vector2(600 + index * 8, 600))
		field.damage_enemy(enemy_index, 99999.0, Vector2.ZERO, Color.WHITE, false, false)
	var reused_orbs := 0
	for orb in field.orbs:
		for previous in first_orbs:
			if is_same(orb, previous):
				reused_orbs += 1
				break
	assert_gte(reused_orbs, 4, "experience orbs must be recycled from the pool")


func test_enemy_rendering_is_multimesh_batched() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/actors/battlefield.gd")
	assert_true(source.contains("MultiMesh.new()"), "enemy rendering must use MultiMesh batching")
	assert_true(source.contains("ENEMY_BATCH_CAPACITY"), "enemy batches need a fixed capacity")
	assert_true(
		source.contains("multimesh.visible_instance_count = batch.size()"),
		"enemy batches must skip unused instances"
	)
	assert_false(source.contains("PackedScene.instantiate"), "enemies must not be node instances")


func test_health_bars_keep_all_layers_in_one_multimesh_batch() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/actors/battlefield.gd")
	var unit_bar := source.get_slice("func _draw_unit_bar", 1).get_slice("func _append_health_bar_rect", 0)
	assert_true(source.contains("draw_multimesh(_health_bar_batch, _health_bar_texture)"))
	assert_true(source.contains("_health_bar_batch.visible_instance_count = _health_bar_count"))
	assert_false(unit_bar.contains("draw_rect"), "unit bars must not issue per-unit canvas draw calls")
	assert_eq(unit_bar.count("_append_health_bar_rect("), 6, "background, fill and four borders must all stay")


func test_pickups_and_projectiles_use_multimesh_batches() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/actors/battlefield.gd")
	assert_true(source.contains("draw_multimesh(_orb_glow_batch, _orb_circle_texture)"))
	assert_true(source.contains("draw_multimesh(_orb_core_batch, _orb_circle_texture)"))
	assert_true(source.contains("draw_multimesh(_player_shot_batch, _player_shot_texture)"))
	assert_true(source.contains("draw_multimesh(_enemy_shot_glow_batch, _orb_circle_texture)"))
	assert_true(source.contains("draw_multimesh(_enemy_shot_core_batch, _orb_circle_texture)"))
	var pickup_body := source.get_slice("func _draw_pickups", 1).get_slice("for drop in oil_drops", 0)
	assert_false(pickup_body.contains("draw_circle"), "experience orbs must not issue per-orb draw calls")
	var projectile_body := source.get_slice("func _draw_projectiles", 1).get_slice("func _draw_jeff_fx", 0)
	assert_false(projectile_body.contains("draw_circle(position"), "projectiles must not issue per-shot draw calls")


func test_narrative_lines_have_categories_and_sources() -> void:
	var narrative := GameData.load_json("res://data/narrative.json")
	var count := 0
	for section in ["prologue", "main_intro", "field_notes", "epilogue"]:
		for line in narrative.get(section, []) as Array:
			count += 1
			assert_true(line is Dictionary)
			assert_true(["史实", "制度", "民俗", "演绎"].has(str(line.get("category", ""))))
			assert_gt(str(line.get("source_ref", "")).length(), 0)
			assert_gt(str(line.get("zh", "")).length(), 0)
			assert_gt(str(line.get("en", "")).length(), 0)
	assert_gte(count, 12)
	var voice := GameData.load_json("res://data/voice_lines.json")
	assert_eq(str(voice.get("engine", "")), "MOSS-TTS-Nano")
	assert_false(bool(voice.get("audio_enabled", true)), "unverified generated voice must stay disabled")
	assert_eq(str(voice.get("distribution", "")), "subtitles_only")
	assert_eq(str((voice.get("rights", {}) as Dictionary).get("generated_audio_status", "")), "unverified")
	var voice_lines: Dictionary = voice.get("lines", {}) as Dictionary
	assert_eq(voice_lines.size(), 9, "subtitle metadata must retain all nine narrative lines")
	for line_id in voice_lines.keys():
		var entry: Dictionary = voice_lines[line_id]
		assert_true(["Xiaoyu", "Lingyu", "Junhao"].has(str(entry.get("voice", ""))))
		assert_eq(str(entry.get("audio", "")), "", "%s must not ship voice audio" % line_id)
		assert_eq(str(entry.get("audio_en", "")), "", "%s must not ship English voice audio" % line_id)
		assert_true(["史实", "制度", "民俗", "演绎"].has(str(entry.get("category", ""))))
		assert_gt(str(entry.get("source_ref", "")).length(), 0)
	var voice_dir := DirAccess.open("res://assets/audio/voice")
	if voice_dir != null:
		for file_name in voice_dir.get_files():
			assert_false(file_name.get_extension().to_lower() == "ogg", "removed voice asset remains: %s" % file_name)


func test_voice_player_falls_back_to_bilingual_subtitle_timing() -> void:
	var line := {"id": "narr_1559_01", "zh": "灯火不灭，永昌不夜。", "en": "Keep the watchfires burning."}
	var player := VoiceLinePlayer.new()
	add_child_autofree(player)
	Locale.set_language("zh", false)
	var zh_duration := player.play_line(line)
	assert_almost_eq(zh_duration, maxf(2.2, float(str(line["zh"]).length()) / 4.35), 0.001)
	assert_null(player._audio.stream, "disabled voice must not load or play an audio stream")
	assert_gt(player._timer.time_left, 0.0)
	Locale.set_language("en", false)
	var en_duration := player.play_line(line)
	assert_almost_eq(en_duration, maxf(2.2, float(str(line["en"]).length()) / 4.35), 0.001)
	assert_null(player._audio.stream)
	player.stop_line()
	Locale.set_language("zh", false)
	var source := FileAccess.get_file_as_string("res://scripts/core/voice_line_player.gd")
	assert_true(source.contains('bool(_voice_data.get("audio_enabled", false))'), "voice playback must be manifest-gated")


func test_codex_separates_tanghe_from_yongchang_claims() -> void:
	var codex := GameData.load_json("res://data/codex.json")
	assert_string_contains(str(codex.get("bridge", {}).get("body_zh", "")), "王德")
	assert_string_contains(str(codex.get("bridge", {}).get("body_zh", "")), "宁村")
	assert_string_contains(str(codex.get("do_not_claim_zh", "")), "东瓯王庙")
	assert_string_contains(str(codex.get("do_not_claim_zh", "")), "1559")
	var timeline: Array = codex.get("timeline", [])
	assert_eq(timeline.size(), 6)
	assert_eq(str((timeline[0] as Dictionary).get("year", "")), "1386")
	assert_eq(str((timeline[1] as Dictionary).get("year", "")), "1387")


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
