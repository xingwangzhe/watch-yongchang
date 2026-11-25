extends SceneTree

func _init() -> void:
	var text := FileAccess.get_file_as_string("res://data/maps.json")
	var data = JSON.parse_string(text)
	var maps: Dictionary = data.get("maps", data) if data is Dictionary else {}
	for map_id in ["tideland", "watergate", "crossstreet"]:
		var definition: Dictionary = maps.get(map_id, {}) as Dictionary
		if definition.is_empty():
			continue
		var layout := MapLayout.new()
		layout.setup(map_id, definition)
		layout.finalize()
		var base := layout.start_pos
		var frame_times: Array[int] = []
		var frame_count := 0
		for i in range(8):
			var target := Vector2(
				fposmod(base.x + float(i % 4) * 96.0 + 16.0, layout.world_size.x - 64.0) + 32.0,
				fposmod(base.y + float(i / 4) * 96.0 + 16.0, layout.world_size.y - 64.0) + 32.0
			)
			layout.request_flow_field(target)
			for budget in range(256):
				var started := Time.get_ticks_usec()
				var done := layout.advance_flow_field()
				frame_times.append(Time.get_ticks_usec() - started)
				frame_count += 1
				if done:
					break
		frame_times.sort()
		var total := 0
		for value in frame_times:
			total += value
		print("[flow-async] %s tiles=%s frames=%d avg_ms=%.3f p95_ms=%.3f max_ms=%.3f" % [
			map_id,
			str(layout.world_tiles),
			frame_count,
			float(total) / 1000.0 / float(frame_times.size()),
			float(frame_times[int(float(frame_times.size() - 1) * 0.95)]) / 1000.0,
			float(frame_times[frame_times.size() - 1]) / 1000.0,
		])
	quit()
