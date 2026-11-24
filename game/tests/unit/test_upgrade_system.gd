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
			assert_true(icon_path.begins_with("res://assets/icons/game_icons/"))
			assert_true(ResourceLoader.exists(icon_path), "%s icon is missing: %s" % [card_id, icon_path])
	assert_eq(total, 140, "the three-choice catalog must expose 140 authored cards (110 base + 30 tower)")


func test_catalog_offer_count_exceeds_reference_build_scopes() -> void:
	assert_eq(UpgradeCatalog.total_card_count(), 140)
	assert_gte(
		UpgradeCatalog.total_offer_count(),
		149,
		"card levels must exceed Brotato's 64 upgrades plus the VS passive scope"
	)
	var pool := UpgradeCatalog.build_card_pool({}, {}, 0.8)
	assert_eq(pool.size(), 140, "a fresh run must see every one of the authored cards")
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
	assert_eq(field.damage_circle(Vector2(24, 0), 24.0, 99999.0, 0.0), 1)
	assert_eq(field.orbs.size(), 1)
	field.magnet_all()
	assert_true(bool(field.orbs[0].get("magnet", false)))


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


func test_touch_controls_use_lantern_patrol_language() -> void:
	var controls := TouchControls.new()
	controls.force_visible = true
	add_child_autofree(controls)
	await wait_process_frames(2)
	assert_true(controls.visible)
	assert_eq(controls._patrol_label.text, Locale.t("touch.patrol"))
	assert_eq(controls._dash_label.text, Locale.t("touch.dash"))
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
