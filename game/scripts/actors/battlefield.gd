class_name Battlefield
extends Node2D

signal player_hit(damage: float)
signal enemy_killed(enemy_id: String, world_position: Vector2, elite: bool)
signal boss_spawned(enemy_id: String, max_hp: float)
signal boss_defeated(enemy_id: String)
signal scale_collected(color: String)
signal oil_collected(amount: int)
signal heal_collected(amount: float)
signal xp_collected(amount: float)
signal ally_support(source_id: String, kind: String, amount: float)

const CELL_SIZE := 64.0
const VIEW_HALF := Vector2(720.0, 430.0)
const ENEMY_BATCH_CAPACITY := 512
const ENEMY_SPRITE_BASE_SIZE := 96.0
const PLAYER_SPRITE_SIZE := 96.0
const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const PAPER := Color("#efe1c2")
const GOLD := Color("#e1b35a")

var enemies: Array[Dictionary] = []
var allies: Array[Dictionary] = []
var orbs: Array[Dictionary] = []
var oil_drops: Array[Dictionary] = []
var heal_drops: Array[Dictionary] = []
var scale_drops: Array[Dictionary] = []
var player_shots: Array[Dictionary] = []
var enemy_shots: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var jeff_effects: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var spatial: Dictionary = {}
var player_pos := Vector2.ZERO
var player_facing := Vector2.RIGHT
var player_radius := 18.0
var time := 0.0
var rng := RandomNumberGenerator.new()
var enemy_data: Dictionary = {}
var mercenary_data: Dictionary = {}
var textures: Dictionary = {}
var enemy_sprite_frames: Dictionary = {}
var player_idle_frames: Array[Texture2D] = []
var player_walk_frames: Array[Texture2D] = []
var player_idle_fps := 6.0
var player_walk_fps := 10.0
var enemy_hp_mult := 1.0
var map_layout: MapLayout
var map_renderer: MapRenderer
var map_definition: Dictionary = {}
var attack_fx_data: Dictionary = {}
var fx_animations: Dictionary = {}
var _contact_cd := 0.0
var _dead_count := 0
var _screen_clear_timer := 0.0
var _dragon_phase := 0.0
var _enemy_batches: Dictionary = {}
var _enemy_batch_counts: Dictionary = {}
var _enemy_quad: QuadMesh
var _player_moving := false
var _last_player_pos := Vector2.ZERO
var _flow_timer := 0.0


func setup(seed_value: int = 20261123, map_definition_value: Dictionary = {}) -> void:
	rng.seed = seed_value
	map_definition = map_definition_value
	if map_definition.is_empty():
		var maps := GameData.get_maps()
		map_definition = maps.get("tideland", {}) as Dictionary
		if map_definition.is_empty():
			map_definition = {"layout": {"world_tiles": [120, 84], "start_tile": [60, 42]}}
	var map_key := str(map_definition.get("id", "tideland"))
	_ensure_map_key(map_key)
	map_layout = MapLayout.new()
	map_layout.setup(map_key, map_definition)
	map_renderer = MapRenderer.new()
	map_renderer.name = "MapRenderer"
	add_child(map_renderer)
	map_renderer.build(map_layout, map_definition, seed_value)
	_load_attack_fx()
	player_pos = map_layout.start_pos
	_last_player_pos = player_pos
	map_layout.ensure_flow_field(player_pos)
	_enemy_quad = QuadMesh.new()
	_enemy_quad.size = Vector2.ONE
	enemy_data = GameData.get_enemies()
	mercenary_data = GameData.get_mercenaries()
	for enemy_id in enemy_data.keys():
		var definition: Dictionary = enemy_data[enemy_id]
		var texture_path := str(definition.get("texture", ""))
		var frame_count := maxi(1, int(definition.get("sprite_frames", 1)))
		var frames := _load_sprite_frames(texture_path, frame_count)
		enemy_sprite_frames[enemy_id] = frames
		textures[enemy_id] = frames[0] if not frames.is_empty() else null
	z_index = 0
	set_process(true)


func _ensure_map_key(map_key: String) -> void:
	if map_key.is_empty():
		map_definition["id"] = "tideland"
	else:
		map_definition["id"] = map_key


func set_player_sprites(definition: Dictionary) -> void:
	player_idle_frames = _load_sprite_frames(
		str(definition.get("battle_idle", "")),
		maxi(1, int(definition.get("battle_idle_frames", 1)))
	)
	player_walk_frames = _load_sprite_frames(
		str(definition.get("battle_walk", "")),
		maxi(1, int(definition.get("battle_walk_frames", 1)))
	)
	player_idle_fps = maxf(1.0, float(definition.get("battle_idle_fps", 6.0)))
	player_walk_fps = maxf(1.0, float(definition.get("battle_walk_fps", 10.0)))


func _load_sprite_frames(path: String, frame_count: int) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if path.is_empty():
		return result
	var strip := GameData.texture(path)
	if strip == null:
		return result
	if frame_count <= 1:
		result.append(strip)
		return result
	var image := strip.get_image()
	if image == null or image.get_width() % frame_count != 0:
		result.append(strip)
		return result
	var frame_width := image.get_width() / frame_count
	for index in frame_count:
		var frame_image := image.get_region(
			Rect2i(index * frame_width, 0, frame_width, image.get_height())
		)
		result.append(ImageTexture.create_from_image(frame_image))
	return result


func reset(seed_value: int = 20261123) -> void:
	enemies.clear()
	allies.clear()
	orbs.clear()
	oil_drops.clear()
	heal_drops.clear()
	scale_drops.clear()
	player_shots.clear()
	enemy_shots.clear()
	effects.clear()
	jeff_effects.clear()
	floaters.clear()
	spatial.clear()
	time = 0.0
	_contact_cd = 0.0
	_dead_count = 0
	_player_moving = false
	player_pos = map_layout.start_pos if map_layout != null else Vector2.ZERO
	_last_player_pos = player_pos
	rng.seed = seed_value
	queue_redraw()


func update_world(delta: float, player: Dictionary, enemy_speed_mult: float = 1.0) -> void:
	time += delta
	player_pos = player.get("pos", Vector2.ZERO) as Vector2
	_flow_timer -= delta
	if map_layout != null and _flow_timer <= 0.0:
		_flow_timer = 0.30
		map_layout.ensure_flow_field(player_pos)
	player_facing = player.get("facing", player_facing) as Vector2
	_player_moving = player_pos.distance_squared_to(_last_player_pos) > 0.25
	_last_player_pos = player_pos
	player_radius = float(player.get("radius", 18.0))
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_screen_clear_timer = maxf(0.0, _screen_clear_timer - delta)
	_dragon_phase += delta * 1.7
	_rebuild_spatial()
	_update_allies(delta, player)
	_update_enemies(delta, player, enemy_speed_mult)
	_update_player_shots(delta)
	_update_enemy_shots(delta, player)
	_update_pickups(delta, player)
	_update_effects(delta)
	_cleanup_dead()
	queue_redraw()


func spawn_enemy(enemy_id: String, center: Vector2, elite_color: String = "") -> int:
	if not enemy_data.has(enemy_id):
		return -1
	if enemies.size() >= 460:
		return -1
	var definition: Dictionary = enemy_data[enemy_id] as Dictionary
	var position := center
	if map_layout != null:
		var candidates := map_layout.spawn_candidates(center, 740.0, 1500.0)
		if not candidates.is_empty():
			position = candidates[rng.randi_range(0, candidates.size() - 1)]
	else:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(760.0, 980.0)
		position = center + Vector2(cos(angle), sin(angle)) * distance
	return spawn_enemy_at(enemy_id, position, elite_color)


func spawn_enemy_at(enemy_id: String, position: Vector2, elite_color: String = "") -> int:
	if not enemy_data.has(enemy_id):
		return -1
	if enemies.size() >= 460:
		return -1
	if map_layout != null and not map_layout.is_point_walkable(position, 14.0):
		position = map_layout.find_walkable_position(position, 14.0)
	var definition: Dictionary = enemy_data[enemy_id] as Dictionary
	var is_boss := str(definition.get("behavior", "")) == "boss"
	var is_elite := not elite_color.is_empty() or str(definition.get("behavior", "")) == "elite"
	var hp := float(definition.get("hp", 10.0)) * enemy_hp_mult
	var enemy := {
		"id": enemy_id,
		"pos": position,
		"hp": hp,
		"max_hp": hp,
		"speed": float(definition.get("speed", 70.0)),
		"damage": float(definition.get("damage", 8.0)),
		"radius": float(definition.get("radius", 20.0)),
		"xp": float(definition.get("xp", 1.0)),
		"scale": float(definition.get("scale", 0.66)),
		"behavior": str(definition.get("behavior", "chase")),
		"armor": float(definition.get("armor", 0.0)),
		"attack_range": float(definition.get("attack_range", 0.0)),
		"attack_cooldown": float(definition.get("attack_cooldown", 2.0)),
		"attack_timer": rng.randf_range(0.3, 1.6),
		"projectile_speed": float(definition.get("projectile_speed", 280.0)),
		"charge_cooldown": float(definition.get("charge_cooldown", 4.0)),
		"charge_timer": rng.randf_range(2.0, 5.0),
		"dash_time": 0.0,
		"dash_dir": Vector2.ZERO,
		"knockback": Vector2.ZERO,
		"flash": 0.0,
		"slow_timer": 0.0,
		"slow_factor": 1.0,
		"burn_timer": 0.0,
		"burn_dps": 0.0,
		"stun_timer": 0.0,
		"elite": is_elite,
		"boss": is_boss,
		"scale_color": elite_color,
		"sprite_fps": float(definition.get("sprite_fps", 10.0)),
		"facing_x": -1.0,
		"tex": textures.get(enemy_id, null) as Texture2D,
		"alive": true,
	}
	enemies.append(enemy)
	var key := Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))
	if not spatial.has(key):
		spatial[key] = []
	(spatial[key] as Array).append(enemies.size() - 1)
	if is_boss:
		boss_spawned.emit(enemy_id, hp)
	return enemies.size() - 1


func spawn_ally(mercenary_id: String, position: Vector2) -> bool:
	if not mercenary_data.has(mercenary_id):
		return false
	var definition: Dictionary = mercenary_data[mercenary_id] as Dictionary
	var spawn_position := position
	if map_layout != null:
		spawn_position = map_layout.find_walkable_position(position, 14.0)
	var idle_frames := _load_sprite_frames(
		str(definition.get("battle_idle", "")),
		maxi(1, int(definition.get("battle_idle_frames", 1)))
	)
	var walk_frames := _load_sprite_frames(
		str(definition.get("battle_walk", "")),
		maxi(1, int(definition.get("battle_walk_frames", 1)))
	)
	allies.append({
		"id": mercenary_id,
		"pos": spawn_position,
		"hp": float(definition.get("hp", 70.0)),
		"max_hp": float(definition.get("hp", 70.0)),
		"speed": float(definition.get("speed", 116.0)),
		"damage": float(definition.get("damage", 10.0)),
		"radius": float(definition.get("radius", 17.0)),
		"scale": float(definition.get("scale", 0.62)),
		"attack_kind": str(definition.get("attack_kind", "cone")),
		"attack_range": float(definition.get("attack_range", 130.0)),
		"attack_cooldown": maxf(0.15, float(definition.get("attack_cooldown", 1.0))),
		"attack_timer": rng.randf_range(0.1, 0.5),
		"attack_arc": float(definition.get("attack_arc", 60.0)),
		"projectile_speed": float(definition.get("projectile_speed", 520.0)),
		"pierce": maxi(1, int(definition.get("pierce", 1))),
		"knockback": float(definition.get("knockback", 16.0)),
		"support_heal": float(definition.get("support_heal", 0.0)),
		"rarity": str(definition.get("rarity", "common")),
		"idle_frames": idle_frames,
		"walk_frames": walk_frames,
		"idle_fps": maxf(1.0, float(definition.get("battle_idle_fps", 6.0))),
		"walk_fps": maxf(1.0, float(definition.get("battle_walk_fps", 10.0))),
		"tint": Color(str(definition.get("tint", "#ffffff"))),
		"facing_x": 1.0,
		"moving": false,
	})
	return true


func alive_count() -> int:
	return enemies.size() - _dead_count


func resolve_player_move(from: Vector2, to: Vector2, radius: float = 18.0) -> Vector2:
	if map_layout == null:
		return to
	return map_layout.move_circle(from, to, radius)


func player_spawn_position() -> Vector2:
	return map_layout.start_pos if map_layout != null else Vector2.ZERO


func nearest_enemy(origin: Vector2, max_range: float) -> Dictionary:
	var best_index := -1
	var best_dist := max_range * max_range
	var candidates := query_circle(origin, max_range)
	for index in candidates:
		if index < 0 or index >= enemies.size():
			continue
		var enemy := enemies[index]
		if not bool(enemy.get("alive", false)):
			continue
		var distance := origin.distance_squared_to(enemy["pos"] as Vector2)
		if distance < best_dist:
			best_dist = distance
			best_index = index
	return enemies[best_index] if best_index >= 0 else {}


func query_circle(center: Vector2, radius: float) -> Array[int]:
	var result: Array[int] = []
	var min_cell := Vector2i(
		floori((center.x - radius) / CELL_SIZE),
		floori((center.y - radius) / CELL_SIZE)
	)
	var max_cell := Vector2i(
		floori((center.x + radius) / CELL_SIZE),
		floori((center.y + radius) / CELL_SIZE)
	)
	for gx in range(min_cell.x, max_cell.x + 1):
		for gy in range(min_cell.y, max_cell.y + 1):
			var bucket: Variant = spatial.get(Vector2i(gx, gy), null)
			if bucket is Array:
				for index in bucket:
					result.append(int(index))
	return result


func damage_circle(center: Vector2, radius: float, damage: float, knockback: float = 0.0, color: Color = GOLD) -> int:
	var hits := 0
	for index in query_circle(center, radius):
		if index < 0 or index >= enemies.size():
			continue
		var enemy := enemies[index]
		if not bool(enemy.get("alive", false)):
			continue
		var enemy_pos := enemy["pos"] as Vector2
		if center.distance_to(enemy_pos) > radius + float(enemy["radius"]):
			continue
		var direction := (enemy_pos - center).normalized()
		damage_enemy(index, damage, direction * knockback, color, false)
		hits += 1
	return hits


func damage_cone(center: Vector2, direction: Vector2, radius: float, arc_degrees: float, damage: float, knockback: float = 0.0, color: Color = GOLD) -> int:
	var hits := 0
	var half_arc := deg_to_rad(arc_degrees) * 0.5
	var forward := direction.normalized()
	for index in query_circle(center, radius):
		if index < 0 or index >= enemies.size():
			continue
		var enemy := enemies[index]
		if not bool(enemy.get("alive", false)):
			continue
		var enemy_pos := enemy["pos"] as Vector2
		if center.distance_to(enemy_pos) > radius + float(enemy["radius"]):
			continue
		var to_enemy := (enemy_pos - center).normalized()
		if absf(forward.angle_to(to_enemy)) > half_arc:
			continue
		damage_enemy(index, damage, to_enemy * knockback, color, false)
		hits += 1
	return hits


func damage_line(origin: Vector2, direction: Vector2, length: float, width: float, damage: float, knockback: float = 0.0, color: Color = GOLD) -> int:
	var hits := 0
	var forward := direction.normalized()
	for index in query_circle(origin + forward * length * 0.5, length * 0.65 + width):
		if index < 0 or index >= enemies.size():
			continue
		var enemy := enemies[index]
		if not bool(enemy.get("alive", false)):
			continue
		var relative := (enemy["pos"] as Vector2) - origin
		var along := relative.dot(forward)
		if along < -float(enemy["radius"]) or along > length + float(enemy["radius"]):
			continue
		if absf(relative.cross(forward)) > width * 0.5 + float(enemy["radius"]):
			continue
		damage_enemy(index, damage, forward * knockback, color, false)
		hits += 1
	return hits


func apply_slow(center: Vector2, radius: float, factor: float, duration: float) -> int:
	var hits := 0
	for index in query_circle(center, radius):
		if index < 0 or index >= enemies.size():
			continue
		var enemy := enemies[index]
		if not bool(enemy.get("alive", false)):
			continue
		if center.distance_to(enemy["pos"] as Vector2) > radius + float(enemy["radius"]):
			continue
		enemy["slow_timer"] = maxf(float(enemy.get("slow_timer", 0.0)), duration)
		enemy["slow_factor"] = minf(float(enemy.get("slow_factor", 1.0)), clampf(factor, 0.18, 1.0))
		hits += 1
	return hits


func apply_burn(center: Vector2, radius: float, dps: float, duration: float) -> int:
	var hits := 0
	for index in query_circle(center, radius):
		if index < 0 or index >= enemies.size():
			continue
		var enemy := enemies[index]
		if not bool(enemy.get("alive", false)):
			continue
		if center.distance_to(enemy["pos"] as Vector2) > radius + float(enemy["radius"]):
			continue
		enemy["burn_timer"] = maxf(float(enemy.get("burn_timer", 0.0)), duration)
		enemy["burn_dps"] = maxf(float(enemy.get("burn_dps", 0.0)), dps)
		hits += 1
	return hits


func apply_stun(center: Vector2, radius: float, duration: float) -> int:
	var hits := 0
	for index in query_circle(center, radius):
		if index < 0 or index >= enemies.size():
			continue
		var enemy := enemies[index]
		if not bool(enemy.get("alive", false)):
			continue
		if center.distance_to(enemy["pos"] as Vector2) > radius + float(enemy["radius"]):
			continue
		enemy["stun_timer"] = maxf(float(enemy.get("stun_timer", 0.0)), duration)
		hits += 1
	return hits


func nearest_enemies(origin: Vector2, max_range: float, count: int) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for index in query_circle(origin, max_range):
		if index < 0 or index >= enemies.size():
			continue
		var enemy := enemies[index]
		if not bool(enemy.get("alive", false)):
			continue
		var distance := origin.distance_squared_to(enemy["pos"] as Vector2)
		if distance <= max_range * max_range:
			candidates.append({"enemy": enemy, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var result: Array[Dictionary] = []
	for entry in candidates.slice(0, maxi(1, count)):
		result.append(entry["enemy"] as Dictionary)
	return result


func magnet_all() -> void:
	for orb in orbs:
		orb["magnet"] = true
	for drop in oil_drops:
		drop["magnet"] = true
	for drop in heal_drops:
		drop["magnet"] = true
	for drop in scale_drops:
		drop["magnet"] = true
	add_effect({
		"type": "aura",
		"pos": player_pos,
		"ttl": 0.55,
		"max_ttl": 0.55,
		"radius": 540.0,
		"color": Color("#d8b45f"),
	})


func damage_enemy(index: int, damage: float, impulse: Vector2, color: Color = GOLD, critical: bool = false, show_fx: bool = true) -> void:
	if index < 0 or index >= enemies.size():
		return
	var enemy := enemies[index]
	if not bool(enemy.get("alive", false)):
		return
	var armor := clampf(float(enemy.get("armor", 0.0)), 0.0, 0.75)
	var final_damage := maxf(1.0, damage * (1.0 - armor))
	enemy["hp"] = float(enemy["hp"]) - final_damage

	# 分层反馈：闪白 + 击退 + 伤害数字 + 音效 + 火花 + 震动，全部走 FeedbackManager 对象池。
	# HitData 复用，命中热路径零节点分配。
	var is_heavy := bool(enemy.get("boss", false)) or bool(enemy.get("elite", false))
	var hit := FeedbackManager.acquire_hit_data()
	hit.position = enemy["pos"] as Vector2
	hit.impulse = impulse
	hit.damage = final_damage
	hit.critical = critical
	hit.weight = 2 if is_heavy else (1 if critical else 0)
	hit.target = enemy
	hit.color = color
	hit.kind = "boss" if bool(enemy.get("boss", false)) else ("kill" if float(enemy["hp"]) <= 0.0 else "normal")
	hit.suppress_fx = not show_fx
	FeedbackManager.on_hit(hit)

	if show_fx and (
		critical
		or is_heavy
		or rng.randf() < 0.58
	):
		var impact_kind := "critical" if critical else "normal"
		if is_heavy:
			impact_kind = "heavy"
		elif float(enemy.get("armor", 0.0)) >= 0.22 and rng.randf() < 0.28:
			impact_kind = "armored"
		play_impact_fx(enemy["pos"] as Vector2, impact_kind, clampf(float(enemy["radius"]) / 20.0, 0.75, 1.4))
	if float(enemy["hp"]) <= 0.0:
		_kill_enemy(index)


func fire_player_projectile(origin: Vector2, direction: Vector2, speed: float, damage: float, pierce: int, color: Color = GOLD) -> void:
	player_shots.append({
		"pos": origin,
		"vel": direction.normalized() * speed,
		"damage": damage,
		"pierce": pierce,
		"ttl": 1.7,
		"hit": [],
		"color": color,
	})


func _load_attack_fx() -> void:
	attack_fx_data = GameData.load_json("res://data/attack_fx.json")
	fx_animations.clear()
	for animation_id in (attack_fx_data.get("animations", {}) as Dictionary).keys():
		var source: Dictionary = attack_fx_data["animations"][animation_id] as Dictionary
		var texture := GameData.texture(str(source.get("texture", "")))
		if texture == null:
			push_warning("Missing Jeff FX texture: %s" % source.get("texture", ""))
			continue
		var animation := source.duplicate(true)
		animation["texture_res"] = texture
		var durations: Array = animation.get("durations", []) as Array
		var fps := maxf(1.0, float(animation.get("fps", 20.0)))
		var starts: Array[float] = []
		var total := 0.0
		for duration in durations:
			starts.append(total)
			total += maxf(0.0, float(duration)) / fps
		animation["starts"] = starts
		animation["duration_seconds"] = total
		fx_animations[animation_id] = animation


func play_player_attack_fx(weapon_id: String, origin: Vector2, direction: Vector2, evolved: bool = false) -> void:
	var profiles: Dictionary = attack_fx_data.get("player_weapons", {}) as Dictionary
	if not profiles.has(weapon_id):
		return
	var profile: Dictionary = profiles[weapon_id] as Dictionary
	var animation_id := str(profile.get("evolved" if evolved else "primary", ""))
	if not fx_animations.has(animation_id):
		animation_id = str(profile.get("primary", ""))
	if animation_id.is_empty():
		return
	var aim := direction.normalized() if direction.length_squared() > 0.001 else player_facing.normalized()
	if aim.length_squared() <= 0.001:
		aim = Vector2.RIGHT
	var offset := float(profile.get("offset", 0.0))
	var scale_value := float(profile.get("evolved_scale" if evolved else "scale", 1.0))
	_play_jeff_fx(animation_id, origin + aim * offset, {
		"rotation": aim.angle() if bool(profile.get("rotate", true)) else 0.0,
		"scale": scale_value,
	})
	if evolved and profile.has("evolved_accent"):
		_play_jeff_fx(str(profile["evolved_accent"]), origin, {
			"scale": float(profile.get("accent_scale", 0.75)),
		})


func play_enemy_attack_fx(enemy_id: String, origin: Vector2, direction: Vector2) -> void:
	var profiles: Dictionary = attack_fx_data.get("enemy_attacks", {}) as Dictionary
	if not profiles.has(enemy_id):
		return
	var profile: Dictionary = profiles[enemy_id] as Dictionary
	var animation_id := str(profile.get("muzzle", ""))
	if not fx_animations.has(animation_id):
		return
	var aim := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	_play_jeff_fx(animation_id, origin + aim * float(profile.get("offset", 0.0)), {
		"rotation": aim.angle() if bool(profile.get("rotate", true)) else 0.0,
		"scale": float(profile.get("scale", 1.0)),
	})


func play_ally_attack_fx(mercenary_id: String, origin: Vector2, direction: Vector2) -> void:
	var profiles: Dictionary = attack_fx_data.get("ally_attacks", {}) as Dictionary
	if not profiles.has(mercenary_id):
		return
	var profile: Dictionary = profiles[mercenary_id] as Dictionary
	var animation_id := str(profile.get("muzzle", ""))
	if not fx_animations.has(animation_id):
		return
	var aim := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	_play_jeff_fx(animation_id, origin + aim * float(profile.get("offset", 0.0)), {
		"rotation": aim.angle() if bool(profile.get("rotate", true)) else 0.0,
		"scale": float(profile.get("scale", 1.0)),
		"flip_h": aim.x < 0.0 and not bool(profile.get("rotate", true)),
		"color": Color(str(profile.get("color", "#ffffff"))),
	})


func play_enemy_impact_fx(enemy_id: String, position: Vector2, critical: bool = false) -> void:
	var profiles: Dictionary = attack_fx_data.get("enemy_attacks", {}) as Dictionary
	var profile: Dictionary = profiles.get(enemy_id, {}) as Dictionary
	var kind := "critical" if critical else str(profile.get("impact", "normal"))
	play_impact_fx(position, kind)


func play_impact_fx(position: Vector2, kind: String = "normal", scale_mult: float = 1.0) -> void:
	var impacts: Dictionary = attack_fx_data.get("impacts", {}) as Dictionary
	if not impacts.has(kind):
		kind = "normal"
	if not impacts.has(kind):
		return
	var profile: Dictionary = impacts[kind] as Dictionary
	var animation_id := str(profile.get("animation", ""))
	if not fx_animations.has(animation_id):
		return
	_play_jeff_fx(animation_id, position, {
		"scale": float(profile.get("scale", 1.0)) * scale_mult,
	})


func _play_jeff_fx(animation_id: String, position: Vector2, options: Dictionary = {}) -> void:
	if not fx_animations.has(animation_id):
		return
	var animation: Dictionary = fx_animations[animation_id] as Dictionary
	if jeff_effects.size() >= 180:
		jeff_effects.pop_front()
	jeff_effects.append({
		"animation_id": animation_id,
		"pos": position,
		"age": -float(options.get("delay", 0.0)),
		"duration": float(animation.get("duration_seconds", 0.5)),
		"rotation": float(options.get("rotation", 0.0)),
		"scale": maxf(0.05, float(options.get("scale", 1.0))),
		"flip_h": bool(options.get("flip_h", false)),
		"color": options.get("color", Color.WHITE) as Color,
	})


func add_effect(effect: Dictionary) -> void:
	if effects.size() >= 240:
		effects.pop_front()
	effects.append(effect)


func spawn_oil(position: Vector2, amount: int = 2) -> void:
	oil_drops.append({"pos": position, "amount": amount, "phase": rng.randf_range(0.0, TAU)})


func spawn_heal(position: Vector2, amount: float = 9.0) -> void:
	heal_drops.append({"pos": position, "amount": amount, "phase": rng.randf_range(0.0, TAU)})


func spawn_scale(position: Vector2, color: String) -> void:
	scale_drops.append({"pos": position, "color": color, "phase": rng.randf_range(0.0, TAU)})


func trigger_five_dragon(center: Vector2) -> void:
	_screen_clear_timer = 3.2
	for color in [Color("#d65342"), Color("#d8b64d"), Color("#4c8fbf"), Color("#5b9b61"), Color("#34313e")]:
		add_effect({
			"type": "dragon_sweep",
			"pos": center,
			"ttl": 2.8,
			"max_ttl": 2.8,
			"color": color,
			"offset": rng.randf_range(-260.0, 260.0),
		})
	for index in range(enemies.size()):
		if bool(enemies[index].get("alive", false)):
			damage_enemy(index, 999999.0, Vector2.ZERO, GOLD, true)
	for index in range(enemy_shots.size()):
		enemy_shots[index]["ttl"] = 0.0


func clear_all_effects() -> void:
	effects.clear()
	jeff_effects.clear()
	floaters.clear()


func _rebuild_spatial() -> void:
	spatial.clear()
	for index in range(enemies.size()):
		if not bool(enemies[index].get("alive", false)):
			continue
		var position := enemies[index]["pos"] as Vector2
		var key := Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))
		if not spatial.has(key):
			spatial[key] = []
		(spatial[key] as Array).append(index)


func _update_allies(delta: float, player: Dictionary) -> void:
	var player_pos := player.get("pos", Vector2.ZERO) as Vector2
	for ally in allies:
		ally["attack_timer"] = float(ally["attack_timer"]) - delta
		var position := ally["pos"] as Vector2
		var target := nearest_enemy(position, 520.0)
		var movement := Vector2.ZERO
		var facing := float(ally.get("facing_x", 1.0))
		if not target.is_empty():
			var target_pos := target["pos"] as Vector2
			var to_target := target_pos - position
			var target_distance := maxf(0.001, to_target.length())
			var direction := to_target / target_distance
			facing = signf(direction.x) if absf(direction.x) > 0.01 else facing
			var can_engage := position.distance_to(player_pos) < 390.0
			if can_engage and target_distance <= float(ally["attack_range"]) + float(target["radius"]):
				if float(ally["attack_timer"]) <= 0.0:
					_ally_attack(ally, target, direction)
					ally["attack_timer"] = float(ally["attack_cooldown"]) * rng.randf_range(0.92, 1.08)
			elif can_engage and target_distance > float(ally["attack_range"]) * 0.72:
				movement = direction
		var follow := player_pos - position
		var follow_distance := follow.length()
		if follow_distance > 236.0:
			movement = follow.normalized()
		elif follow_distance < 64.0 and target.is_empty():
			movement = -follow.normalized() * 0.4 if follow_distance > 0.01 else Vector2.ZERO
		if movement.length_squared() > 0.001:
			movement = movement.normalized()
			var previous := position
			position += movement * float(ally["speed"]) * delta
			if map_layout != null:
				position = map_layout.move_circle(
					previous,
					position,
					clampf(float(ally["radius"]) * 0.68, 8.0, 22.0)
				)
			ally["facing_x"] = signf(movement.x) if absf(movement.x) > 0.01 else facing
		else:
			ally["facing_x"] = facing
		ally["pos"] = position
		ally["moving"] = movement.length_squared() > 0.001


func _ally_attack(ally: Dictionary, target: Dictionary, direction: Vector2) -> void:
	var position := ally["pos"] as Vector2
	var damage := float(ally["damage"])
	var kind := str(ally["attack_kind"])
	var color := Color("#9fd0bd")
	play_ally_attack_fx(str(ally["id"]), position, direction)
	match kind:
		"projectile":
			fire_player_projectile(
				position + direction * 16.0,
				direction,
				float(ally["projectile_speed"]),
				damage,
				int(ally["pierce"]),
				color
			)
		"cone":
			damage_cone(
				position,
				direction,
				float(ally["attack_range"]),
				float(ally["attack_arc"]),
				damage,
				float(ally["knockback"]),
				color
			)
		"support":
			damage_circle(
				position,
				float(ally["attack_range"]),
				damage,
				float(ally["knockback"]),
				Color("#e0b85f")
			)
			if float(ally.get("support_heal", 0.0)) > 0.0:
				ally_support.emit(str(ally["id"]), "heal", float(ally["support_heal"]))
			add_effect({
				"type": "aura",
				"pos": position,
				"ttl": 0.56,
				"max_ttl": 0.56,
				"radius": float(ally["attack_range"]),
				"color": Color("#e0b85f"),
			})
		_:
			damage_circle(
				position,
				float(ally["attack_range"]),
				damage,
				float(ally["knockback"]),
				color
			)


func _update_enemies(delta: float, player: Dictionary, speed_mult: float) -> void:
	var target := player.get("pos", Vector2.ZERO) as Vector2
	var dark_speed := 1.0
	for index in range(enemies.size()):
		var enemy := enemies[index]
		if not bool(enemy.get("alive", false)):
			continue
		enemy["flash"] = maxf(0.0, float(enemy["flash"]) - delta)
		enemy["attack_timer"] = float(enemy["attack_timer"]) - delta
		enemy["charge_timer"] = float(enemy["charge_timer"]) - delta
		enemy["slow_timer"] = maxf(0.0, float(enemy.get("slow_timer", 0.0)) - delta)
		enemy["stun_timer"] = maxf(0.0, float(enemy.get("stun_timer", 0.0)) - delta)
		if float(enemy.get("burn_timer", 0.0)) > 0.0:
			enemy["burn_timer"] = maxf(0.0, float(enemy["burn_timer"]) - delta)
			damage_enemy(
				index,
				float(enemy.get("burn_dps", 0.0)) * delta,
				Vector2.ZERO,
				Color("#e07845"),
				false,
				false
			)
			if not bool(enemy.get("alive", false)):
				continue
		var position := enemy["pos"] as Vector2
		var to_player := target - position
		var distance := maxf(0.001, to_player.length())
		var direction := to_player / distance
		var behavior := str(enemy["behavior"])
		var movement := Vector2.ZERO
		var navigation := direction
		if map_layout != null:
			navigation = map_layout.navigation_direction(position, target)
		if behavior == "ranged":
			if distance > float(enemy["attack_range"]) * 0.82:
				movement = navigation
			elif float(enemy["attack_timer"]) <= 0.0:
				play_enemy_attack_fx(str(enemy["id"]), position, direction)
				_fire_enemy_shot(position, direction, float(enemy["damage"]), float(enemy["projectile_speed"]))
				enemy["attack_timer"] = float(enemy["attack_cooldown"])
		elif behavior == "support":
			if distance > 250.0:
				movement = navigation
			dark_speed = 1.0
		else:
			movement = navigation
		if behavior == "elite" or behavior == "boss":
			if float(enemy["dash_time"]) > 0.0:
				enemy["dash_time"] = maxf(0.0, float(enemy["dash_time"]) - delta)
				movement = (enemy["dash_dir"] as Vector2) * (3.4 if behavior == "boss" else 2.8)
			elif float(enemy["charge_timer"]) <= 0.0 and distance < 520.0:
				play_enemy_attack_fx(str(enemy["id"]), position, navigation)
				enemy["dash_time"] = 0.34 if behavior == "boss" else 0.26
				enemy["dash_dir"] = navigation
				enemy["charge_timer"] = float(enemy["charge_cooldown"])
		if float(enemy.get("stun_timer", 0.0)) > 0.0:
			movement = Vector2.ZERO
		var slow_factor := float(enemy.get("slow_factor", 1.0)) if float(enemy.get("slow_timer", 0.0)) > 0.0 else 1.0
		var speed := float(enemy["speed"]) * speed_mult * dark_speed * slow_factor
		var previous_position := position
		position += movement * speed * delta
		if absf(movement.x) > 0.01:
			enemy["facing_x"] = signf(movement.x)
		elif absf(direction.x) > 0.01:
			enemy["facing_x"] = signf(direction.x)
		var knockback := enemy["knockback"] as Vector2
		position += knockback * delta
		enemy["knockback"] = knockback.move_toward(Vector2.ZERO, 520.0 * delta)
		if map_layout != null:
			position = map_layout.move_circle(
				previous_position,
				position,
				clampf(float(enemy["radius"]) * 0.72, 9.0, 26.0)
			)
		enemy["pos"] = position
		if distance < player_radius + float(enemy["radius"]) and _contact_cd <= 0.0:
			play_enemy_attack_fx(str(enemy["id"]), position, direction)
			player_hit.emit(float(enemy["damage"]))
			_contact_cd = 0.70
		if position.distance_squared_to(target) > 2100.0 * 2100.0:
			enemy["alive"] = false
		if _screen_clear_timer > 0.0:
			enemy["speed"] = float(enemy["speed"])


func _fire_enemy_shot(origin: Vector2, direction: Vector2, damage: float, speed: float) -> void:
	enemy_shots.append({
		"pos": origin,
		"vel": direction * speed,
		"damage": damage,
		"ttl": 3.2,
	})


func _update_player_shots(delta: float) -> void:
	for shot in player_shots:
		if float(shot["ttl"]) <= 0.0:
			continue
		shot["ttl"] = float(shot["ttl"]) - delta
		var previous_position := shot["pos"] as Vector2
		var position := previous_position + (shot["vel"] as Vector2) * delta
		if map_layout != null and map_layout.is_segment_wall_blocked(previous_position, position, 3.0):
			shot["ttl"] = 0.0
			continue
		shot["pos"] = position
		var hit_list: Array = shot["hit"] as Array
		for index in query_circle(position, 34.0):
			if hit_list.has(index):
				continue
			if index < 0 or index >= enemies.size():
				continue
			var enemy := enemies[index]
			if not bool(enemy.get("alive", false)):
				continue
			var enemy_pos := enemy["pos"] as Vector2
			if position.distance_to(enemy_pos) > 24.0 + float(enemy["radius"]):
				continue
			hit_list.append(index)
			var direction := (shot["vel"] as Vector2).normalized()
			damage_enemy(index, float(shot["damage"]), direction * 12.0, shot["color"] as Color, false)
			shot["pierce"] = int(shot["pierce"]) - 1
			if int(shot["pierce"]) <= 0:
				shot["ttl"] = 0.0
				break


func _update_enemy_shots(delta: float, player: Dictionary) -> void:
	var target := player.get("pos", Vector2.ZERO) as Vector2
	for shot in enemy_shots:
		if float(shot["ttl"]) <= 0.0:
			continue
		shot["ttl"] = float(shot["ttl"]) - delta
		var previous_position := shot["pos"] as Vector2
		var position := previous_position + (shot["vel"] as Vector2) * delta
		if map_layout != null and map_layout.is_segment_wall_blocked(previous_position, position, 3.0):
			shot["ttl"] = 0.0
			continue
		shot["pos"] = position
		if position.distance_to(target) < player_radius + 9.0:
			player_hit.emit(float(shot["damage"]))
			shot["ttl"] = 0.0


func _update_pickups(delta: float, player: Dictionary) -> void:
	var target := player.get("pos", Vector2.ZERO) as Vector2
	var pickup_radius := float(player.get("pickup_radius", 88.0))
	for orb in orbs:
		if bool(orb.get("taken", false)):
			continue
		var position := orb["pos"] as Vector2
		var distance := position.distance_to(target)
		if bool(orb.get("magnet", false)) or distance < pickup_radius:
			position = position.move_toward(target, maxf(260.0, 540.0 - distance))
			orb["pos"] = position
		if position.distance_to(target) < 22.0:
			orb["taken"] = true
			xp_collected.emit(float(orb["value"]))
	_update_drop_array(oil_drops, target, pickup_radius, delta, func(drop: Dictionary) -> void:
		oil_collected.emit(int(drop.get("amount", 2)))
	)
	_update_drop_array(heal_drops, target, pickup_radius, delta, func(drop: Dictionary) -> void:
		heal_collected.emit(float(drop.get("amount", 9.0)))
	)
	_update_drop_array(scale_drops, target, pickup_radius, delta, func(drop: Dictionary) -> void:
		add_effect({
			"type": "scale_burst",
			"pos": drop["pos"],
			"ttl": 0.5,
			"max_ttl": 0.5,
			"color": _scale_color(str(drop["color"])),
		})
		scale_collected.emit(str(drop["color"]))
	)
	for index in range(orbs.size() - 1, -1, -1):
		if bool(orbs[index].get("taken", false)):
			orbs.remove_at(index)


func _update_drop_array(drops: Array[Dictionary], target: Vector2, pickup_radius: float, delta: float, on_take: Callable) -> void:
	for index in range(drops.size() - 1, -1, -1):
		var drop := drops[index]
		var position := drop["pos"] as Vector2
		var distance := position.distance_to(target)
		if bool(drop.get("magnet", false)) or distance < pickup_radius:
			position = position.move_toward(target, maxf(240.0, 520.0 - distance))
			drop["pos"] = position
		if position.distance_to(target) < 24.0:
			on_take.call(drop)
			drops.remove_at(index)


func _update_effects(delta: float) -> void:
	for effect in effects:
		effect["ttl"] = float(effect["ttl"]) - delta
	for effect in jeff_effects:
		effect["age"] = float(effect["age"]) + delta
	for index in range(effects.size() - 1, -1, -1):
		if float(effects[index]["ttl"]) <= 0.0:
			effects.remove_at(index)
	for index in range(jeff_effects.size() - 1, -1, -1):
		if float(jeff_effects[index]["age"]) > float(jeff_effects[index]["duration"]):
			jeff_effects.remove_at(index)
	for floater in floaters:
		floater["ttl"] = float(floater["ttl"]) - delta
		floater["pos"] = (floater["pos"] as Vector2) + Vector2(0.0, -42.0) * delta
	for index in range(floaters.size() - 1, -1, -1):
		if float(floaters[index]["ttl"]) <= 0.0:
			floaters.remove_at(index)
	for index in range(player_shots.size() - 1, -1, -1):
		if float(player_shots[index]["ttl"]) <= 0.0:
			player_shots.remove_at(index)
	for index in range(enemy_shots.size() - 1, -1, -1):
		if float(enemy_shots[index]["ttl"]) <= 0.0:
			enemy_shots.remove_at(index)


func _cleanup_dead() -> void:
	var removed := 0
	for index in range(enemies.size() - 1, -1, -1):
		if bool(enemies[index].get("alive", false)):
			continue
		enemies.remove_at(index)
		removed += 1
	_dead_count = 0
	if removed > 0:
		_rebuild_spatial()


func _kill_enemy(index: int) -> void:
	var enemy := enemies[index]
	if not bool(enemy.get("alive", false)):
		return
	enemy["alive"] = false
	_dead_count += 1
	var position := enemy["pos"] as Vector2
	var xp_value := float(enemy.get("xp", 1.0))
	var orb_count := 1 if xp_value <= 8.0 else 2
	for i in range(orb_count):
		var offset := Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-18.0, 18.0))
		orbs.append({
			"pos": position + offset,
			"value": maxf(1.0, xp_value / float(orb_count)),
			"taken": false,
		})
	if rng.randf() < 0.045:
		spawn_oil(position, 1)
	if bool(enemy.get("elite", false)) or bool(enemy.get("boss", false)):
		spawn_heal(position, 22.0 if bool(enemy.get("boss", false)) else 14.0)
	elif rng.randf() < 0.045:
		spawn_heal(position, 9.0)
	if not str(enemy.get("scale_color", "")).is_empty():
		spawn_scale(position, str(enemy["scale_color"]))
	add_effect({
		"type": "death",
		"pos": position,
		"ttl": 0.42,
		"max_ttl": 0.42,
		"color": Color("#b35d43"),
		"radius": float(enemy.get("radius", 20.0)) * 1.6,
	})
	enemy_killed.emit(str(enemy["id"]), position, bool(enemy.get("elite", false)))
	if bool(enemy.get("boss", false)):
		boss_defeated.emit(str(enemy["id"]))


func _add_floater(_position: Vector2, _text: String, _color: Color, _critical: bool) -> void:
	# 伤害数字已统一由 FeedbackManager 池管理并经 FeedbackManager.draw(self) 绘制。
	# 保留此签名仅为兼容旧调用，不再产生任何副作用。
	pass


func _scale_color(color_name: String) -> Color:
	match color_name:
		"red":
			return Color("#d65342")
		"yellow":
			return Color("#d8b64d")
		"blue":
			return Color("#4c8fbf")
		"green":
			return Color("#5b9b61")
		"black":
			return Color("#34313e")
		_:
			return GOLD


func _draw() -> void:
	var center := player_pos
	if map_layout == null:
		draw_rect(Rect2(center - VIEW_HALF, VIEW_HALF * 2.0), Color("#111a19"))
	_draw_light(center)
	_draw_pickups()
	_draw_enemies()
	_draw_allies()
	_draw_player()
	_draw_projectiles()
	_draw_jeff_fx()
	_draw_effects()
	FeedbackManager.draw(self)
	_draw_dragons()

func _draw_light(center: Vector2) -> void:
	var light_radius := float(get_meta("light_radius", 225.0))
	draw_circle(center, light_radius + 70.0, Color(0.95, 0.62, 0.22, 0.035))
	draw_circle(center, light_radius + 32.0, Color(0.98, 0.72, 0.28, 0.045))
	draw_arc(center, light_radius, 0.0, TAU, 64, Color(0.98, 0.72, 0.28, 0.18), 2.0, true)


func _draw_pickups() -> void:
	for orb in orbs:
		var position := orb["pos"] as Vector2
		draw_circle(position, 7.0, Color(0.94, 0.70, 0.27, 0.16))
		draw_circle(position, 3.5, Color(0.98, 0.83, 0.44, 0.96))
		draw_arc(position, 8.0, 0.0, TAU, 12, Color(0.98, 0.82, 0.38, 0.38), 1.0, true)
	for drop in oil_drops:
		var position := drop["pos"] as Vector2
		draw_circle(position, 11.0, Color(0.92, 0.64, 0.22, 0.20))
		draw_rect(Rect2(position - Vector2(5, 8), Vector2(10, 16)), Color("#d5a242"))
		draw_rect(Rect2(position - Vector2(3, 5), Vector2(6, 5)), Color("#f0d078"))
	for drop in heal_drops:
		var position := drop["pos"] as Vector2
		var bob := sin(time * 5.0 + float(drop["phase"])) * 2.0
		draw_circle(position + Vector2(0, bob), 10.0, Color(0.24, 0.42, 0.24, 0.24))
		draw_rect(Rect2(position + Vector2(-7, -2 + bob), Vector2(14, 4)), Color("#9bc27e"))
		draw_rect(Rect2(position + Vector2(-2, -7 + bob), Vector2(4, 14)), Color("#9bc27e"))
	for scale in scale_drops:
		var position := scale["pos"] as Vector2
		var color := _scale_color(str(scale["color"]))
		var bob := sin(time * 4.0 + float(scale["phase"])) * 4.0
		draw_circle(position + Vector2(0, bob), 13.0, Color(color, 0.18))
		draw_circle(position + Vector2(0, bob), 7.0, color)
		draw_arc(position + Vector2(0, bob), 13.0, 0.0, TAU, 16, Color(color, 0.70), 2.0, true)


func _draw_enemies() -> void:
	if not bool(get_meta("draw_enemies", true)):
		return
	var groups: Dictionary = {}
	var decorations: Array[Dictionary] = []
	for enemy in enemies:
		if not bool(enemy.get("alive", false)):
			continue
		var position := enemy["pos"] as Vector2
		if absf(position.x - player_pos.x) > VIEW_HALF.x + 120.0:
			continue
		if absf(position.y - player_pos.y) > VIEW_HALF.y + 120.0:
			continue
		var batch_id := str(enemy.get("id", ""))
		if not groups.has(batch_id):
			groups[batch_id] = []
		(groups[batch_id] as Array).append(enemy)
		if bool(enemy.get("elite", false)) or bool(enemy.get("boss", false)):
			decorations.append(enemy)
	for batch_id in groups.keys():
		_draw_enemy_batch(str(batch_id), groups[batch_id] as Array, true)
	for batch_id in groups.keys():
		_draw_enemy_batch(str(batch_id), groups[batch_id] as Array, false)
	for enemy in decorations:
		var position := enemy["pos"] as Vector2
		var radius := float(enemy["radius"])
		var ring_color := Color(GOLD, 0.64)
		if not str(enemy.get("scale_color", "")).is_empty():
			ring_color = Color(_scale_color(str(enemy["scale_color"])), 0.72)
		draw_arc(position, radius + 7.0, 0.0, TAU, 20, ring_color, 2.0, true)
		if float(enemy["hp"]) < float(enemy["max_hp"]) and bool(enemy.get("boss", false)):
			var width := 96.0
			var ratio := clampf(float(enemy["hp"]) / float(enemy["max_hp"]), 0.0, 1.0)
			draw_rect(Rect2(position + Vector2(-width * 0.5, -64), Vector2(width, 5)), Color(0.03, 0.03, 0.03, 0.8))
			draw_rect(Rect2(position + Vector2(-width * 0.5, -64), Vector2(width * ratio, 5)), Color("#c4573d"))


func _draw_enemy_batch(batch_id: String, batch: Array, shadow: bool) -> void:
	var first_enemy := batch[0] as Dictionary
	var enemy_id := str(first_enemy.get("id", ""))
	var frames: Array = enemy_sprite_frames.get(enemy_id, []) as Array
	var frame_index := 0
	if not frames.is_empty():
		frame_index = posmod(
			int(time * maxf(1.0, float(first_enemy.get("sprite_fps", 10.0))))
				+ posmod(enemy_id.hash(), frames.size()),
			frames.size()
		)
	var tex := (
		frames[frame_index] as Texture2D
		if not frames.is_empty()
		else first_enemy.get("tex", null) as Texture2D
	)
	if tex == null:
		for enemy in batch:
			draw_circle(enemy["pos"] as Vector2, float(enemy["radius"]), Color("#9b4d40"))
		return
	var cache_key := "%s:%s" % [batch_id, "shadow" if shadow else "body"]
	var multimesh: MultiMesh
	if _enemy_batches.has(cache_key):
		multimesh = _enemy_batches[cache_key] as MultiMesh
	else:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.use_colors = true
		multimesh.mesh = _enemy_quad
		multimesh.instance_count = ENEMY_BATCH_CAPACITY
		multimesh.custom_aabb = AABB(Vector3(-2400, -1800, 0), Vector3(4800, 3600, 0))
		for i in range(ENEMY_BATCH_CAPACITY):
			multimesh.set_instance_transform_2d(i, Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO))
		_enemy_batches[cache_key] = multimesh
	var previous_count := int(_enemy_batch_counts.get(cache_key, 0))
	for i in range(batch.size()):
		var enemy: Dictionary = batch[i]
		var position := enemy["pos"] as Vector2
		var radius := float(enemy["radius"])
		var size := ENEMY_SPRITE_BASE_SIZE * float(enemy["scale"])
		var color := Color.WHITE
		if shadow:
			position += Vector2(0, radius * 0.7)
			size = radius * 1.5
			color = Color(0.0, 0.0, 0.0, 0.22)
		else:
			position -= Vector2(0, size * 0.16)
			if str(enemy["id"]) == "banner":
				color = Color(1.0, 0.72, 0.68, 1.0)
			if bool(enemy.get("elite", false)):
				color = Color(1.0, 0.88, 0.58, 1.0)
			if bool(enemy.get("boss", false)):
				color = Color(1.0, 0.72, 0.58, 1.0)
			if float(enemy["flash"]) > 0.0:
				color = FeedbackManager.config.flash_color
		var facing_x := 1.0
		if not shadow and float(enemy.get("facing_x", -1.0)) < 0.0:
			facing_x = -1.0
		var xform := _enemy_instance_transform(position, size, shadow, facing_x)
		multimesh.set_instance_transform_2d(i, xform)
		multimesh.set_instance_color(i, color)
	for i in range(batch.size(), previous_count):
		multimesh.set_instance_transform_2d(i, Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO))
	_enemy_batch_counts[cache_key] = batch.size()
	draw_multimesh(multimesh, tex)


func _enemy_instance_transform(position: Vector2, size: float, _shadow: bool, facing_x: float = 1.0) -> Transform2D:
	return Transform2D(0.0, Vector2(size * signf(facing_x), -size), 0.0, position)


func _draw_player() -> void:
	draw_circle(player_pos + Vector2(0, 15), 21.0, Color(0.0, 0.0, 0.0, 0.28))
	var tint := get_meta("player_tint", Color.WHITE) as Color
	var frames := player_walk_frames if _player_moving else player_idle_frames
	if frames.is_empty():
		frames = player_walk_frames if not player_walk_frames.is_empty() else player_idle_frames
	if not frames.is_empty():
		var fps := player_walk_fps if _player_moving else player_idle_fps
		var frame_index := posmod(int(time * fps), frames.size())
		var draw_size := Vector2.ONE * PLAYER_SPRITE_SIZE
		var body_bob := sin(time * 10.0) * 1.2 if _player_moving else sin(time * 2.0) * 0.5
		var flip_x := -1.0 if player_facing.x < -0.01 else 1.0
		draw_set_transform(player_pos + Vector2(0, body_bob), 0.0, Vector2(flip_x, 1.0))
		var rect := Rect2(
			Vector2(-PLAYER_SPRITE_SIZE * 0.5, -PLAYER_SPRITE_SIZE * 0.79),
			draw_size
		)
		draw_texture_rect(frames[frame_index], rect, false, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(player_pos, 22.0, Color("#d8b45a"))
	draw_circle(player_pos + Vector2(0, -30), 5.0, Color(1.0, 0.78, 0.34, 0.48))


func _draw_allies() -> void:
	for ally in allies:
		var position := ally["pos"] as Vector2
		var scale_value := float(ally.get("scale", 0.62))
		var size := PLAYER_SPRITE_SIZE * scale_value
		draw_circle(position + Vector2(0, size * 0.16), size * 0.28, Color(0.0, 0.0, 0.0, 0.25))
		if str(ally.get("rarity", "common")) in ["rare", "legendary"]:
			var ring_color := Color("#79a9bf") if str(ally["rarity"]) == "rare" else Color("#d9a95f")
			draw_arc(position + Vector2(0, 2), size * 0.38, 0.0, TAU, 18, Color(ring_color, 0.42), 1.5, true)
		var frames: Array = (
			ally["walk_frames"] as Array
			if bool(ally.get("moving", false))
			else ally["idle_frames"] as Array
		)
		if frames.is_empty():
			frames = ally["walk_frames"] as Array
		if frames.is_empty():
			draw_circle(position, float(ally["radius"]), Color("#6f9f8f"))
			continue
		var fps := float(ally["walk_fps"]) if bool(ally.get("moving", false)) else float(ally["idle_fps"])
		var frame_index := posmod(
			int(time * fps) + str(ally["id"]).hash(),
			frames.size()
		)
		var flip_x := -1.0 if float(ally.get("facing_x", 1.0)) < 0.0 else 1.0
		draw_set_transform(position, 0.0, Vector2(flip_x, 1.0))
		draw_texture_rect(
			frames[frame_index] as Texture2D,
			Rect2(Vector2(-size * 0.5, -size * 0.79), Vector2(size, size)),
			false,
			ally.get("tint", Color.WHITE) as Color
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_projectiles() -> void:
	for shot in player_shots:
		var position := shot["pos"] as Vector2
		var direction := (shot["vel"] as Vector2).normalized()
		draw_line(position - direction * 9.0, position + direction * 9.0, shot["color"] as Color, 2.0, true)
		draw_circle(position, 3.0, Color(1.0, 0.92, 0.62, 0.85))
	for shot in enemy_shots:
		var position := shot["pos"] as Vector2
		draw_circle(position, 4.5, Color("#d65b45"))
		draw_arc(position, 7.0, 0.0, TAU, 10, Color(0.9, 0.34, 0.24, 0.45), 1.0, true)


func _draw_jeff_fx() -> void:
	for effect in jeff_effects:
		var age := float(effect["age"])
		if age < 0.0:
			continue
		var animation: Dictionary = fx_animations.get(str(effect["animation_id"]), {}) as Dictionary
		if animation.is_empty():
			continue
		var durations: Array = animation.get("durations", []) as Array
		var starts: Array = animation.get("starts", []) as Array
		var frame_index := 0
		for index in range(starts.size()):
			if age >= float(starts[index]):
				frame_index = index
		var rects: Array = animation.get("rects", []) as Array
		if rects.is_empty():
			continue
		frame_index = mini(frame_index, rects.size() - 1)
		@warning_ignore("integer_division")
		var frame_rect: Array = rects[frame_index] as Array
		var source_rect := Rect2(
			float(frame_rect[0]),
			float(frame_rect[1]),
			float(frame_rect[2]),
			float(frame_rect[3])
		)
		var pivot_data: Array = animation.get("pivot", [0.0, 0.0]) as Array
		var pivot := Vector2(
			float(pivot_data[0]) if pivot_data.size() > 0 else 0.0,
			float(pivot_data[1]) if pivot_data.size() > 1 else 0.0
		)
		var scale_value := float(effect["scale"])
		var flip_x := -1.0 if bool(effect.get("flip_h", false)) else 1.0
		var color := effect.get("color", Color.WHITE) as Color
		draw_set_transform(
			effect["pos"] as Vector2,
			float(effect["rotation"]),
			Vector2(scale_value * flip_x, scale_value)
		)
		draw_texture_rect_region(
			animation["texture_res"] as Texture2D,
			Rect2(-pivot, source_rect.size),
			source_rect,
			color
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if durations.is_empty():
			continue


func _draw_effects() -> void:
	for effect in effects:
		var ttl := float(effect["ttl"])
		var max_ttl := maxf(0.001, float(effect["max_ttl"]))
		var progress := 1.0 - clampf(ttl / max_ttl, 0.0, 1.0)
		var color := effect.get("color", GOLD) as Color
		var position := effect["pos"] as Vector2
		match str(effect["type"]):
			"slash":
				var radius := float(effect.get("radius", 100.0))
				var center_angle := float(effect.get("angle", 0.0))
				var arc := float(effect.get("arc", 2.0))
				draw_arc(
					position,
					radius * (0.78 + progress * 0.22),
					center_angle - arc * 0.5,
					center_angle + arc * 0.5,
					22,
					Color(color, 1.0 - progress),
					7.0 * (1.0 - progress) + 1.0,
					true
				)
			"thrust":
				var direction := effect.get("direction", Vector2.RIGHT) as Vector2
				var length := float(effect.get("length", 160.0))
				var alpha := 1.0 - progress
				draw_line(position, position + direction * length, Color(color, alpha), 8.0 * alpha + 1.0, true)
			"aura":
				var radius := float(effect.get("radius", 95.0))
				draw_circle(position, radius, Color(color, 0.05 * (1.0 - progress)))
				draw_arc(position, radius, 0.0, TAU, 32, Color(color, 0.45 * (1.0 - progress)), 3.0, true)
			"death":
				var radius := float(effect.get("radius", 28.0))
				draw_circle(position, radius * progress, Color(color, 0.24 * (1.0 - progress)))
			"scale_burst":
				draw_circle(position, 30.0 * progress, Color(color, 0.35 * (1.0 - progress)))
				draw_arc(position, 34.0 * progress, 0.0, TAU, 20, Color(color, 0.8 * (1.0 - progress)), 2.0, true)
			"orbit":
				var radius := float(effect.get("radius", 75.0))
				var angle := float(effect.get("angle", 0.0))
				var orbit_pos := position + Vector2(cos(angle), sin(angle)) * radius
				draw_circle(orbit_pos, 12.0, Color(color, 0.26))
				draw_arc(orbit_pos, 15.0, 0.0, TAU, 16, Color(color, 0.86), 3.0, true)
			"dragon_sweep":
				var offset := float(effect.get("offset", 0.0))
				var wave_x := position.x - 900.0 + progress * 1800.0
				draw_line(
					Vector2(wave_x, position.y - 360.0 + offset),
					Vector2(wave_x + 80.0, position.y + 360.0 + offset),
					Color(color, 0.36 * (1.0 - progress)),
					28.0,
					true
				)


func _draw_floaters() -> void:
	for floater in floaters:
		var alpha := clampf(float(floater["ttl"]) / float(floater["max_ttl"]), 0.0, 1.0)
		var size := 20 if bool(floater.get("critical", false)) else 15
		var color := floater["color"] as Color
		draw_string(
			UI_FONT,
			floater["pos"] as Vector2,
			str(floater["text"]),
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			size,
			Color(color, alpha)
		)


func _draw_dragons() -> void:
	if _screen_clear_timer <= 0.0:
		return
	var colors := [Color("#d65342"), Color("#d8b64d"), Color("#4c8fbf"), Color("#5b9b61"), Color("#34313e")]
	for i in range(colors.size()):
		var phase := _dragon_phase + float(i) * 1.25
		var offset := Vector2(sin(phase * 1.3) * 340.0, cos(phase) * 220.0)
		var head := player_pos + offset
		draw_circle(head, 18.0, Color(colors[i], 0.30))
		draw_arc(head, 24.0, phase, phase + PI * 1.5, 18, colors[i], 5.0, true)
