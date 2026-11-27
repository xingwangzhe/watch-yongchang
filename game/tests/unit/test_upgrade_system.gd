extends GutTest


func before_each() -> void:
	Locale.set_language("zh", false)


func test_upgrade_cards_are_bilingual_sourced_and_decorated() -> void:
	var data := UpgradeCatalog.data()
	var total := 0
	for family in ["attributes", "skills", "events", "towers"]:
		var entries: Dictionary = data.get(family, {}) as Dictionary
		assert_gt(entries.size(), 0, "%s must not be empty" % family)
		for card_id in entries.keys():
			total += 1
			var card: Dictionary = entries[card_id] as Dictionary
			for field in ["name_zh", "name_en", "desc_zh", "desc_en", "culture_zh", "culture_en"]:
				assert_gt(str(card.get(field, "")).length(), 0, "%s missing %s" % [card_id, field])
			assert_true(
				["史实", "制度", "民俗", "演绎", "工事"].has(str(card.get("category", ""))),
				"%s has an invalid source category" % card_id
			)
			assert_gt(str(card.get("source_ref", "")).length(), 0, "%s needs a source" % card_id)
			assert_true(int(card.get("max_level", 0)) >= 1, "%s needs a level cap" % card_id)
			assert_gt((card.get("effects", []) as Array).size(), 0, "%s needs effects" % card_id)
			var icon_path := str(card.get("icon", ""))
			assert_true(
				icon_path.begins_with("res://assets/icons/game_icons/")
				or icon_path.begins_with("res://assets/icons/game_icons/"),
				"%s icon must use a registered runtime icon source" % card_id
			)
			assert_true(ResourceLoader.exists(icon_path), "%s icon is missing: %s" % [card_id, icon_path])
	assert_eq(total, 143, "the three-choice catalog must expose 143 authored cards")
	assert_eq(UpgradeCatalog.family_data("attributes").size(), 51)
	assert_eq(UpgradeCatalog.family_data("skills").size(), 38)
	assert_eq(UpgradeCatalog.family_data("events").size(), 22)
	assert_eq(UpgradeCatalog.family_data("towers").size(), 32)


func test_catalog_offer_count_exceeds_reference_build_scopes() -> void:
	assert_eq(UpgradeCatalog.total_card_count(), 143)
	assert_eq(UpgradeCatalog.total_offer_count(), 580)
	assert_gte(
		UpgradeCatalog.total_offer_count(),
		151,
		"card levels must exceed Brotato's 64 upgrades plus the VS passive scope"
	)
	var pool := UpgradeCatalog.build_card_pool({}, {}, 0.8)
	assert_eq(pool.size(), 143, "a fresh run must see every one of the authored cards")
	var families := {}
	for option in pool:
		families[str(option.get("family", ""))] = true
	assert_true(families.has("attribute"))
	assert_true(families.has("skill"))
	assert_true(families.has("event"))
	assert_true(families.has("tower"))


func test_three_choice_pick_is_unique_and_uses_seeded_luck() -> void:
	var pool := UpgradeCatalog.build_card_pool({}, {}, 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261123
	var picked := UpgradeCatalog.pick_three(pool, rng)
	assert_eq(picked.size(), 3)
	var seen := {}
	for option in picked:
		seen[str(option.get("card_id", ""))] = true
		assert_gt(str(option.get("title", "")).length(), 0)
		assert_gt(str(option.get("culture", "")).length(), 0)
		assert_gt(str(option.get("effect_summary", "")).length(), 0)
	assert_eq(seen.size(), 3, "three-choice draws must not duplicate a card")


func test_event_cards_expose_settlement_text() -> void:
	var events := UpgradeCatalog.family_data("events")
	for event_id in events.keys():
		var definition: Dictionary = events[event_id] as Dictionary
		var option := UpgradeCatalog.make_option("event", str(event_id), definition, 1, 0.8)
		assert_eq(str(option.get("kind_label", "")), Locale.t("upgrade.kind.event"))
		assert_gt(str(option.get("effect_summary", "")).length(), 0, event_id)
		assert_true(ResourceLoader.exists(str(option.get("icon", ""))))


func test_each_run_gets_one_seeded_optional_jinshi_blessing() -> void:
	var options := UpgradeCatalog.build_run_card_pool({}, {}, 0.0, 20261127)
	var blessing: Dictionary = {}
	for option in options:
		if str(option.get("card_id", "")) == "jinshi_blessing":
			blessing = option
	assert_false(blessing.is_empty(), "a fresh run must include its optional blessing in the upgrade pool")
	assert_eq(blessing.get("family"), "event")
	assert_eq(blessing.get("category"), "演绎")
	assert_true(str(blessing.get("source_ref", "")).begins_with("《永昌堡：十三进士与抗倭纪略》"))
	assert_eq(blessing.get("title"), UpgradeCatalog.make_jinshi_blessing_option(20261127).get("title"))
	assert_eq((blessing.get("definition", {}) as Dictionary).get("effects", [])[0].get("amount"), 0.05)
	assert_eq(options.size(), 144, "the run-specific blessing is outside the 143 authored catalog")

	var used := {"jinshi_blessing": true}
	var spent_options := UpgradeCatalog.build_run_card_pool({}, used, 0.0, 20261127)
	assert_eq(spent_options.size(), 143, "the blessing must leave the pool after it is chosen")
	for option in spent_options:
		assert_ne(str(option.get("card_id", "")), "jinshi_blessing")

	var blessings: Array = GameData.load_json("res://data/jinshi_blessings.json").get("blessings", []) as Array
	assert_eq(blessings.size(), 13)
	var observed_titles := {}
	for seed in range(1, 100):
		var seeded_option := UpgradeCatalog.make_jinshi_blessing_option(seed)
		assert_gt(str(seeded_option.get("title", "")).length(), 0)
		observed_titles[str(seeded_option.get("title", ""))] = true
	assert_gt(observed_titles.size(), 1, "different run seeds should select different scholars")


func test_battlefield_applies_slow_burn_stun_and_soul_magnet() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(42)
	field.spawn_enemy_at("scout", Vector2(24, 0))
	assert_eq(field.apply_slow(Vector2.ZERO, 90.0, 0.5, 2.0), 1)
	assert_eq(field.apply_stun(Vector2.ZERO, 90.0, 0.8), 1)
	assert_eq(field.apply_burn(Vector2.ZERO, 90.0, 9.0, 2.0), 1)
	var enemy: Dictionary = field.enemies[0]
	assert_almost_eq(float(enemy.get("slow_timer", 0.0)), 2.0, 0.01)
	assert_almost_eq(float(enemy.get("stun_timer", 0.0)), 0.8, 0.01)
	assert_almost_eq(float(enemy.get("burn_dps", 0.0)), 9.0, 0.01)
	var hp_before := float(enemy.get("hp", 0.0))
	field.update_world(0.5, {
		"pos": Vector2(900, 0),
		"radius": 18.0,
		"pickup_radius": 0.0,
	})
	assert_lt(float(enemy.get("hp", 0.0)), hp_before, "burn damage must tick during world updates")
	var xp_received: Array[float] = []
	field.xp_awarded.connect(func(amount: float) -> void: xp_received.append(amount))
	assert_eq(field.damage_circle(Vector2(24, 0), 24.0, 99999.0, 0.0), 1)
	assert_eq(xp_received.size(), 1, "enemy death must award XP immediately")
	assert_gt(xp_received[0], 0.0)
	field.magnet_all()
	assert_false(
		FileAccess.get_file_as_string("res://scripts/actors/battlefield.gd").contains("orbs"),
		"XP must not create collectible orbs"
	)


func test_enemy_batch_flips_y_to_match_canvas_texture_uv() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	var body := field._enemy_instance_transform(Vector2(24, 36), 64.0, false)
	var shadow := field._enemy_instance_transform(Vector2(24, 36), 64.0, true)
	assert_eq(body.origin, Vector2(24, 36))
	assert_lt(body.y.y, 0.0, "enemy body must flip Y to stay upright in CanvasItem batches")
	assert_lt(shadow.y.y, 0.0, "enemy shadow must follow the same flipped texture orientation")


func test_level_up_overlay_renders_three_cultural_cards() -> void:
	var pool := UpgradeCatalog.build_card_pool({}, {}, 0.8)
	var options: Array[Dictionary] = []
	for family in ["attribute", "skill", "event"]:
		for option in pool:
			if str(option.get("family", "")) == family:
				options.append(option)
				break
	var overlay := LevelUpOverlay.new()
	add_child_autofree(overlay)
	await wait_process_frames(2)
	overlay.show_options(options, 12, {"pool": UpgradeCatalog.total_offer_count(), "taken": 0})
	await wait_process_frames(2)
	assert_true(overlay.visible)
	for i in range(3):
		var card: Button = overlay.find_child("UpgradeCard%d" % (i + 1), true, false)
		assert_not_null(card)
		assert_true(card.visible)
		assert_gt((card.find_child("CardTitle", true, false) as Label).text.length(), 0)
		assert_gt((card.find_child("CardCulture", true, false) as Label).text.length(), 0)
		assert_gt((card.find_child("CardEffect", true, false) as Label).text.length(), 0)
		assert_not_null((card.find_child("CardIcon", true, false) as TextureRect).texture)


func test_level_up_blocks_mouse_and_number_input_for_point_two_seconds() -> void:
	var options: Array[Dictionary] = []
	var pool := UpgradeCatalog.build_card_pool({}, {}, 0.8)
	for family in ["attribute", "skill", "event"]:
		for option in pool:
			if str(option.get("family", "")) == family:
				options.append(option)
				break
	var overlay := LevelUpOverlay.new()
	add_child_autofree(overlay)
	await wait_process_frames(2)
	var selected: Array[int] = []
	overlay.chosen.connect(func(index: int) -> void: selected.append(index))
	overlay.show_options(options, 12)

	assert_true(overlay.is_locked())
	assert_false(overlay.can_choose(0))
	assert_true(overlay._hint.visible)
	assert_string_contains(str(overlay._hint.text), "选择锁定")
	assert_true(str(overlay._hint.text).contains("0.") or str(overlay._hint.text).contains("1.0"))
	for i in range(3):
		var card := overlay.find_child("UpgradeCard%d" % (i + 1), true, false) as Button
		assert_true(card.disabled, "every card must be disabled during the lock")
		card.pressed.emit()
		overlay._choose(i)
		overlay._unhandled_input(_number_key_event(KEY_1 + i))
		assert_true(overlay.get_viewport().is_input_handled(), "number input must be consumed while locked")
	assert_eq(selected.size(), 0, "mouse and 1/2/3 input must not choose during the lock")

	await wait_seconds(0.25)
	assert_false(overlay.is_locked())
	assert_true(overlay.can_choose(0))
	assert_eq(str(overlay._hint.text), Locale.t("levelup.hint", {"pool": options.size()}))
	for i in range(3):
		var card := overlay.find_child("UpgradeCard%d" % (i + 1), true, false) as Button
		assert_false(card.disabled)
	overlay._unhandled_input(_number_key_event(KEY_2))
	assert_eq(selected, [1], "number selection must work after the 0.2 second lock")

	overlay.hide_options()
	assert_false(overlay.is_locked())
	overlay.show_options(options, 13)
	assert_true(overlay.is_locked(), "re-showing options must restart the input lock")
	overlay._choose(0)
	assert_eq(selected, [1], "direct selection must also respect a restarted lock")


func test_upgrade_card_children_do_not_block_full_card_click_area() -> void:
	var overlay := LevelUpOverlay.new()
	add_child_autofree(overlay)
	await wait_process_frames(2)
	var pool := UpgradeCatalog.build_card_pool({}, {}, 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261127
	var options := UpgradeCatalog.pick_three(pool, rng)
	overlay.show_options(options, 1)
	await wait_seconds(0.25)
	for i in range(3):
		var card := overlay.find_child("UpgradeCard%d" % (i + 1), true, false) as Button
		assert_not_null(card)
		assert_eq(card.mouse_filter, Control.MOUSE_FILTER_STOP, "the full card must receive pointer input")
		for child in card.find_children("*", "Control", true, false):
			assert_eq(
				(child as Control).mouse_filter,
				Control.MOUSE_FILTER_IGNORE,
				"card content must pass mouse and touch input through to the full-card Button"
			)


func test_touch_controls_use_lantern_patrol_language() -> void:
	var controls := TouchControls.new()
	controls.force_visible = true
	add_child_autofree(controls)
	await wait_process_frames(2)
	assert_true(controls.visible)
	assert_eq(controls._patrol_label.text, Locale.t("touch.patrol"))
	assert_eq(controls._dash_label.text, Locale.t("touch.dash"))
	assert_eq(controls._attack_label.text, Locale.t("touch.attack"))
	assert_eq(controls._auto_label.text, Locale.t("touch.auto"))
	controls._update_joystick(controls._joystick_center + Vector2(31, 0))
	assert_gt(controls.move_vector.length(), 0.0)
	controls.release_all()
	assert_eq(controls.move_vector, Vector2.ZERO)


func test_run_applies_attribute_and_event_cards() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	var attribute_defs := UpgradeCatalog.family_data("attributes")
	var attribute_id := str(attribute_defs.keys()[0])
	var attribute_option := UpgradeCatalog.make_option(
		"attribute",
		attribute_id,
		attribute_defs[attribute_id] as Dictionary,
		1
	)
	var old_damage := float(run.player.get("damage_mult", 1.0))
	run._apply_card(attribute_option)
	assert_true(run.card_levels.has(attribute_id))
	assert_true(float(run.player.get("damage_mult", 1.0)) >= old_damage)

	var event_defs := UpgradeCatalog.family_data("events")
	var event_id := "smugglers_cache"
	var event_option := UpgradeCatalog.make_option(
		"event",
		event_id,
		event_defs[event_id] as Dictionary,
		1
	)
	var old_merit: int = int(run.merit)
	run._apply_event(event_option)
	assert_true(run.used_events.has(event_id))
	assert_eq(run.merit, old_merit + 200)
	assert_gt(run.battlefield.alive_count(), 0, "event elites must enter the battlefield")


func _number_key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event



func test_touch_attack_and_auto_buttons_emit_actions() -> void:
	var controls := TouchControls.new()
	controls.force_visible = true
	add_child_autofree(controls)
	await wait_process_frames(2)
	# GDScript lambda captures local scalars by value; use a reference type so
	# signal handlers can mutate the counter observed by the test.
	var hits := {"attack": 0, "release": 0, "auto": 0}
	controls.attack_pressed.connect(func() -> void: hits.attack += 1)
	controls.attack_released.connect(func() -> void: hits.release += 1)
	controls.auto_toggle_requested.connect(func() -> void: hits.auto += 1)
	var press := InputEventScreenTouch.new()
	press.index = 3
	press.pressed = true
	press.position = controls._attack_center
	controls._input(press)
	assert_eq(hits.attack, 1)
	var release := InputEventScreenTouch.new()
	release.index = 3
	release.pressed = false
	release.position = controls._attack_center
	controls._input(release)
	assert_eq(hits.release, 1)
	var auto_press := InputEventScreenTouch.new()
	auto_press.index = 4
	auto_press.pressed = true
	auto_press.position = controls._auto_center
	controls._input(auto_press)
	assert_eq(hits.auto, 1)
	assert_true(controls.auto_active)
	controls.release_all()
