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


func test_encounter_sites_are_walkable_peripheral_and_trigger_once() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(77)
	assert_gte(field.encounter_sites.size(), 4)
	for site in field.encounter_sites:
		assert_true(field.map_layout.is_point_walkable(site["pos"] as Vector2, 18.0))
		assert_gt(
			(site["pos"] as Vector2).distance_to(field.map_layout.start_pos),
			520.0,
			"encounter points must pull the player away from the central tower"
		)
	var triggered: Array[int] = []
	field.encounter_triggered.connect(func(index: int) -> void: triggered.append(index))
	var site_pos: Vector2 = field.encounter_sites[0]["pos"]
	field.update_world(1.0 / 60.0, {
		"pos": site_pos,
		"radius": 18.0,
		"pickup_radius": 0.0,
	})
	field.update_world(1.0 / 60.0, {
		"pos": site_pos,
		"radius": 18.0,
		"pickup_radius": 0.0,
	})
	assert_eq(triggered, [0], "an encounter point must fire exactly once per run")
	assert_true(bool(field.encounter_sites[0].get("used", false)))
