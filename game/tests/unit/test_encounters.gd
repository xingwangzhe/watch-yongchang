extends GutTest


func test_every_map_has_outer_good_and_bad_encounter_sites() -> void:
	var data := GameData.get_encounters()
	var events: Dictionary = data.get("events", {}) as Dictionary
	var sites: Dictionary = data.get("sites", {}) as Dictionary
	assert_gte(events.size(), 6)
	for map_id in ["tideland", "watergate", "crossstreet"]:
		var entries: Array = sites.get(map_id, []) as Array
		assert_gte(entries.size(), 4, "%s needs explorable encounter points" % map_id)
		var has_good := false
		var has_bad := false
		for entry in entries:
			var site := entry as Dictionary
			var event_id := str(site.get("event", ""))
			assert_true(events.has(event_id), "%s references missing event %s" % [map_id, event_id])
			var event: Dictionary = events[event_id] as Dictionary
			var icon := str(event.get("icon", ""))
			assert_true(ResourceLoader.exists(icon), "%s encounter icon missing: %s" % [event_id, icon])
			assert_gt(str(event.get("title_zh", "")).length(), 0)
			assert_gt(str(event.get("title_en", "")).length(), 0)
			assert_gt(str(event.get("description_zh", "")).length(), 0)
			has_good = has_good or bool(event.get("good", false))
			has_bad = has_bad or not bool(event.get("good", true))
		assert_true(has_good, "%s needs at least one beneficial encounter" % map_id)
		assert_true(has_bad, "%s needs at least one risky encounter" % map_id)
	for event_id in events:
		var event: Dictionary = events[event_id] as Dictionary
		assert_true(
			["史实", "制度", "民俗", "演绎"].has(str(event.get("category", ""))),
			"%s must identify its cultural category" % event_id
		)
		assert_gt(
			str(event.get("source_ref", "")).strip_edges().length(),
			0,
			"%s must cite its cultural/design source" % event_id
		)


func test_encounter_sites_are_walkable_peripheral_and_refresh_after_cooldown() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(77)
	assert_gte(field.encounter_sites.size(), 4)
	for site in field.encounter_sites:
		assert_true(field.map_layout.is_point_walkable(site["pos"] as Vector2, 18.0))
		assert_true(
			field.map_layout.is_position_reachable_from(
				field.map_layout.start_pos,
				site["pos"] as Vector2
			),
			"encounter point %s must be reachable from the player spawn" % site["event_id"]
		)
		assert_gt(
			(site["pos"] as Vector2).distance_to(field.map_layout.start_pos),
			520.0,
			"encounter points must pull the player away from the central tower"
		)
		assert_gte(float(site.get("refresh_seconds", 0.0)), 20.0)
	var triggered: Array[int] = []
	var refreshed: Array[int] = []
	field.encounter_triggered.connect(func(index: int) -> void: triggered.append(index))
	field.encounter_refreshed.connect(func(index: int) -> void: refreshed.append(index))
	var site_pos: Vector2 = field.encounter_sites[0]["pos"]
	field.tick_encounters(1.0 / 60.0, site_pos)
	field.tick_encounters(1.0 / 60.0, site_pos)
	assert_eq(triggered, [0], "an encounter point must not retrigger while the player stays inside")
	assert_true(bool(field.encounter_sites[0].get("used", false)))
	field.tick_encounters(
		float(field.encounter_sites[0]["refresh_seconds"]) + 0.1,
		site_pos
	)
	assert_eq(refreshed, [0], "the site must announce when it becomes available again")
	assert_false(bool(field.encounter_sites[0].get("used", false)))
	assert_false(bool(field.encounter_sites[0].get("rearmed", true)))
	field.tick_encounters(0.1, site_pos)
	assert_eq(triggered, [0], "a refreshed site must wait until the player leaves its radius")
	field.tick_encounters(0.1, site_pos + Vector2(200.0, 0.0))
	assert_true(bool(field.encounter_sites[0].get("rearmed", false)))
	field.tick_encounters(0.1, site_pos)
	assert_eq(triggered, [0, 0], "leaving and returning must arm the same site again")
