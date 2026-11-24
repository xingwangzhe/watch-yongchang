extends SceneTree

const STEP := 1.0 / 60.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveSystem.data["tutorial_seen"] = true
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	root.add_child(run)
	await process_frame
	run.story._skip_all()
	Input.action_press("attack")
	if OS.has_environment("WATCH_BALANCE_FLAT"):
		run._difficulty_curve = {}
	var steps := int(run.duration / STEP)
	var max_steps := steps + int(120.0 / STEP)
	var last_report := -1
	var victory := "unfinished"
	for step in range(max_steps):
		var t := float(step) * STEP
		_drive(run, t)
		run._step(STEP)
		while run.level_up_overlay.visible:
			run.level_up_overlay._unlock_at_msec = Time.get_ticks_msec() - 1
			run.level_up_overlay._process(0.0)
			run._on_upgrade_chosen(_choose_upgrade(run))
		if run._shop_open:
			for index in range(run._current_shop_offers.size()):
				var offer: Dictionary = run._current_shop_offers[index]
				if not bool(offer.get("sold", false)) and int(offer.get("price", 0)) <= run.run_coin:
					run._on_shop_buy(index)
					break
			run._on_shop_closed()
		if run.story.visible:
			run.story._skip_all()
		if run.result_overlay.visible or run._game_over:
			victory = "victory" if bool(run._victory_started) else "defeat"
			break
		var minute := int(t / 60.0)
		if minute != last_report:
			last_report = minute
			print("[balance] t=%02d:%02d hp=%d/%d level=%d kills=%d merit=%d enemies=%d weapons=%d scales=%d boss=%s/%s" % [
				minute,
				int(t) % 60,
				int(run.player["hp"]),
				int(run.player["max_hp"]),
				run.level,
				run.kills,
				run.merit,
				run.battlefield.alive_count(),
				run.weapons.size(),
				run.scales.size(),
				run._boss_spawned,
				run._boss_defeated,
			])
	print("[balance] result=%s elapsed=%.1f kills=%d merit=%d level=%d weapons=%d scales=%d" % [
		victory,
		run.elapsed,
		run.kills,
		run.merit,
		run.level,
		run.weapons.size(),
		run.scales.size(),
	])
	Input.action_release("attack")
	quit(0 if victory == "victory" else 1)


func _drive(run: Node, t: float) -> void:
	var pos: Vector2 = run.player["pos"]
	var target: Dictionary = run.battlefield.nearest_enemy(pos, 720.0)
	if not target.is_empty():
		run._mouse_screen_pos = run.get_viewport().get_canvas_transform() * (target["pos"] as Vector2)
		run._has_mouse_screen_pos = true
	var away := Vector2.ZERO
	var crowd := 0
	for enemy in run.battlefield.enemies:
		if not bool(enemy.get("alive", false)):
			continue
		var offset := pos - (enemy["pos"] as Vector2)
		var distance := offset.length()
		if distance < 0.001 or distance > 260.0:
			continue
		away += offset / distance * (1.0 - distance / 260.0)
		if distance < 105.0:
			crowd += 1
	var pickup := Vector2.ZERO
	var pickup_distance := 280.0
	for orb in run.battlefield.orbs:
		var offset := (orb["pos"] as Vector2) - pos
		var distance := offset.length()
		if distance > 0.001 and distance < pickup_distance:
			pickup_distance = distance
			pickup = offset / distance * 1.8
	var center: Vector2 = run.battlefield.player_spawn_position()
	var from_center := pos - center
	var tangent := Vector2(-from_center.y, from_center.x)
	if tangent.length_squared() < 1.0:
		tangent = Vector2(cos(t), sin(t))
	tangent = tangent.normalized()
	var desired := tangent * (0.72 + sin(t * 0.31) * 0.16) + away * 1.45 + pickup
	if from_center.length() > 520.0:
		desired += -from_center.normalized() * 1.8
	if desired.length_squared() < 0.01:
		desired = tangent
	desired = desired.normalized()
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if desired.x > 0.18:
		Input.action_press("move_right", desired.x)
	elif desired.x < -0.18:
		Input.action_press("move_left", -desired.x)
	if desired.y > 0.18:
		Input.action_press("move_down", desired.y)
	elif desired.y < -0.18:
		Input.action_press("move_up", -desired.y)
	if crowd >= 2 and float(run._dash_cd) <= 0.0:
		run._try_dash()


func _choose_upgrade(run: Node) -> int:
	var options: Array = run._current_upgrade_options
	var best := 0
	var best_score := -1
	for index in range(options.size()):
		var option: Dictionary = options[index] as Dictionary
		var score := 0
		match str(option.get("family", "")):
			"evolve":
				score = 100
			"weapon_upgrade":
				score = 80
			"weapon_new":
				score = 84 if run.weapons.size() < 3 else (66 if run.weapons.size() < 6 else 20)
			"passive_upgrade":
				score = 62
			"passive_new":
				score = 52
			"heal":
				score = 96 if float(run.player["hp"]) < float(run.player["max_hp"]) * 0.62 else 10
			"oil":
				score = 85 if int(run.player["oil"]) <= 1 else 12
		var passive_id := str(option.get("passive_id", ""))
		if passive_id == "medicine":
			score += 18 if float(run.player["hp"]) < float(run.player["max_hp"]) * 0.65 else 6
		elif passive_id == "family_letter":
			score += 10
		if score > best_score:
			best_score = score
			best = index
	return best
