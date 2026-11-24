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
signal tower_destroyed(tower_id: String, world_position: Vector2)
signal tower_damaged(tower_id: String, ratio: float)

const CELL_SIZE := 64.0
const VIEW_HALF := Vector2(720.0, 430.0)
const ENEMY_BATCH_CAPACITY := 512
const HEALTH_BAR_INSTANCE_CAPACITY := 3000
const WADE_SPEED_FACTOR := 0.62
const WADE_SPLASH_CAPACITY := 90
const ENEMY_SPRITE_BASE_SIZE := 96.0
const PLAYER_SPRITE_SIZE := 96.0
const TOWER_AGGRO := 360.0
const TOWER_SPRITE_BASE := 168.0
const UI_FONT := preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const PAPER := Color("#efe1c2")
const GOLD := Color("#e1b35a")
const TOWER_REBUILD_DELAY := 26.0

var enemies: Array[Dictionary] = []
var allies: Array[Dictionary] = []
var towers: Array[Dictionary] = []
var tower_shots: Array[Dictionary] = []
var orbs: Array[Dictionary] = []
var oil_drops: Array[Dictionary] = []
var heal_drops: Array[Dictionary] = []
var scale_drops: Array[Dictionary] = []
var player_shots: Array[Dictionary] = []
var enemy_shots: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var jeff_effects: Array[Dictionary] = []
var wade_splashes: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var _free_player_shots: Array[Dictionary] = []
var _free_enemy_shots: Array[Dictionary] = []
var _free_tower_shots: Array[Dictionary] = []
var _free_orbs: Array[Dictionary] = []
var _free_oil_drops: Array[Dictionary] = []
var _free_heal_drops: Array[Dictionary] = []
var _free_scale_drops: Array[Dictionary] = []
var _free_effects: Array[Dictionary] = []
var _free_wade_splashes: Array[Dictionary] = []
var spatial: Dictionary = {}
var player_pos := Vector2.ZERO
var player_facing := Vector2.RIGHT
var player_radius := 18.0
var time := 0.0
var rng := RandomNumberGenerator.new()
var enemy_data: Dictionary = {}
var mercenary_data: Dictionary = {}
var tower_defs: Dictionary = {}
var tower_stats: Dictionary = {}
var tower_textures: Dictionary = {}
var textures: Dictionary = {}
var enemy_sprite_frames: Dictionary = {}
var player_idle_frames: Array[Texture2D] = []
var player_walk_frames: Array[Texture2D] = []
var player_idle_fps := 6.0
var player_walk_fps := 10.0
var enemy_hp_mult := 1.0
var difficulty_hp_mult := 1.0
var difficulty_damage_mult := 1.0
var difficulty_speed_mult := 1.0
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
var _health_bar_batch: MultiMesh
var _health_bar_texture: Texture2D
var _health_bar_count := 0
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
	_health_bar_batch = MultiMesh.new()
	_health_bar_batch.transform_format = MultiMesh.TRANSFORM_2D
	_health_bar_batch.use_colors = true
	_health_bar_batch.mesh = _enemy_quad
	_health_bar_batch.instance_count = HEALTH_BAR_INSTANCE_CAPACITY
	_health_bar_batch.visible_instance_count = 0
	_health_bar_batch.custom_aabb = AABB(Vector3(-2400, -1800, 0), Vector3(4800, 3600, 0))
	var white_pixel := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white_pixel.fill(Color.WHITE)
	_health_bar_texture = ImageTexture.create_from_image(white_pixel)
	enemy_data = GameData.get_enemies()
	mercenary_data = GameData.get_mercenaries()
	_load_towers()
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


# ============================================================ 箭塔（友方工事）
# 箭塔是静态友方实体：自动锁定射程内最近的倭寇、发射箭矢、有独立血量，
# 会被靠近的倭寇围攻摧毁。数值基线来自 data/towers.json，
# 三选一卡牌的 tower_* 增益通过 apply_tower_stats() 统一作用。

func _load_towers() -> void:
	var data := GameData.load_json("res://data/towers.json")
	tower_defs = data.get("towers", {}) as Dictionary
	tower_textures.clear()
	for tower_id in tower_defs.keys():
		var definition: Dictionary = tower_defs[tower_id] as Dictionary
		var texture := GameData.texture(str(definition.get("texture", "")))
		if texture == null:
			push_warning("Missing tower texture: %s" % definition.get("texture", ""))
			continue
		tower_textures[tower_id] = texture


func tower_definition(tower_id: String) -> Dictionary:
	return tower_defs.get(tower_id, {}) as Dictionary


func apply_tower_stats(stats: Dictionary) -> void:
	"""由 run_game._recompute_stats() 推送塔增益；同步缩放既有塔的血量上限。"""
	tower_stats = stats.duplicate(true)
	for tower in towers:
		if not bool(tower.get("alive", true)):
			continue
		var definition := tower_definition(str(tower["id"]))
		var base_hp := float(definition.get("hp", 300.0))
		var new_max := base_hp * float(stats.get("tower_hp_mult", 1.0))
		var ratio := 1.0
		if float(tower["max_hp"]) > 0.0:
			ratio = clampf(float(tower["hp"]) / float(tower["max_hp"]), 0.0, 1.0)
		tower["max_hp"] = new_max
		tower["hp"] = clampf(new_max * ratio, 1.0, new_max)
		tower["radius"] = float(definition.get("radius", 36.0)) * float(stats.get("tower_size_mult", 1.0))
		tower["armor"] = clampf(float(stats.get("tower_armor", 0.0)), 0.0, 0.70)


func spawn_tower(tower_id: String, position: Vector2) -> int:
	if not tower_defs.has(tower_id):
		return -1
	var definition: Dictionary = tower_defs[tower_id] as Dictionary
	var spawn_position := position
	if map_layout != null:
		spawn_position = map_layout.find_walkable_position(position, 20.0)
	var max_hp := float(definition.get("hp", 300.0)) * float(tower_stats.get("tower_hp_mult", 1.0))
	var tower := {
		"id": tower_id,
		"pos": spawn_position,
		"hp": max_hp,
		"max_hp": max_hp,
		"radius": float(definition.get("radius", 36.0)) * float(tower_stats.get("tower_size_mult", 1.0)),
		"range": float(definition.get("range", 420.0)),
		"damage": float(definition.get("damage", 20.0)),
		"cooldown": float(definition.get("cooldown", 1.2)),
		"attack_timer": rng.randf_range(0.1, 0.7),
		"pierce": int(definition.get("pierce", 1)),
		"projectile_speed": float(definition.get("projectile_speed", 640.0)),
		"arrow_color": Color(str(definition.get("arrow_color", "#efe0b4"))),
		"sprite_scale": float(definition.get("sprite_scale", 1.0)),
		"armor": clampf(float(tower_stats.get("tower_armor", 0.0)), 0.0, 0.70),
		"base_regen": float(definition.get("regen", 0.0)),
		"aim_angle": 0.0,
		"aim_dir": Vector2.RIGHT,
		"recoil": 0.0,
		"muzzle": 0.0,
		"flash": 0.0,
		"hit_cd": 0.0,
		"heat": 0.0,
		"alive": true,
		"rebuild_timer": 0.0,
		"tex": tower_textures.get(tower_id, null) as Texture2D,
	}
	towers.append(tower)
	return towers.size() - 1


func live_tower_count() -> int:
	var total := 0
	for tower in towers:
		if bool(tower.get("alive", false)):
			total += 1
	return total


func tower_summary() -> Array[Dictionary]:
	"""给 HUD 用的轻量快照，避免 UI 侧直接摸实体池。"""
	var views: Array[Dictionary] = []
	for tower in towers:
		if not bool(tower.get("alive", false)):
			continue
		var definition := tower_definition(str(tower["id"]))
		views.append({
			"id": str(tower["id"]),
			"name": str(definition.get("name_zh", "")),
			"hp": float(tower["hp"]),
			"max_hp": float(tower["max_hp"]),
		})
	return views


func upgrade_tower(index: int, next_id: String, heal_ratio: float = 0.45) -> bool:
	if index < 0 or index >= towers.size():
		return false
	if not tower_defs.has(next_id):
		return false
	var tower := towers[index]
	if not bool(tower.get("alive", false)):
		return false
	var definition := tower_definition(next_id)
	tower["id"] = next_id
	tower["tex"] = tower_textures.get(next_id, tower.get("tex", null)) as Texture2D
	tower["sprite_scale"] = float(definition.get("sprite_scale", 1.0))
	tower["radius"] = float(definition.get("radius", 36.0)) * float(tower_stats.get("tower_size_mult", 1.0))
	tower["range"] = float(definition.get("range", 420.0))
	tower["damage"] = float(definition.get("damage", 20.0))
	tower["cooldown"] = float(definition.get("cooldown", 1.2))
	tower["pierce"] = int(definition.get("pierce", 1))
	tower["projectile_speed"] = float(definition.get("projectile_speed", 640.0))
	tower["base_regen"] = float(definition.get("regen", 0.0))
	var new_max := float(definition.get("hp", 300.0)) * float(tower_stats.get("tower_hp_mult", 1.0))
	tower["max_hp"] = maxf(new_max, float(tower["max_hp"]))
	tower["hp"] = clampf(float(tower["hp"]) + new_max * heal_ratio, 1.0, float(tower["max_hp"]))
	add_effect({
		"type": "aura", "pos": tower["pos"], "ttl": 0.7, "max_ttl": 0.7,
		"radius": 96.0, "color": Color("#f0c363"),
	})
	return true


func _update_towers(delta: float) -> void:
	if towers.is_empty():
		return
	var range_mult := float(tower_stats.get("tower_range_mult", 1.0))
	var damage_mult := float(tower_stats.get("tower_damage_mult", 1.0))
	var rate_mult := clampf(float(tower_stats.get("tower_fire_rate", 1.0)), 0.30, 1.0)
	var regen := float(tower_stats.get("tower_regen", 0.0))
	var volley := int(tower_stats.get("tower_volley", 0))
	var pierce_bonus := int(tower_stats.get("tower_pierce", 0))
	var crit_chance := clampf(float(tower_stats.get("tower_crit", 0.0)), 0.0, 1.0)
	var arrow_speed_mult := float(tower_stats.get("tower_arrow_speed", 1.0))
	var overcharge := clampf(float(tower_stats.get("tower_overcharge", 0.0)), 0.0, 0.55)
	var rebuild_bonus := float(tower_stats.get("tower_rebuild", 0.0))
	for tower in towers:
		if not bool(tower.get("alive", false)):
			continue
		tower["flash"] = maxf(0.0, float(tower["flash"]) - delta)
		tower["hit_cd"] = maxf(0.0, float(tower["hit_cd"]) - delta)
		tower["recoil"] = maxf(0.0, float(tower.get("recoil", 0.0)) - delta * 7.0)
		tower["muzzle"] = maxf(0.0, float(tower.get("muzzle", 0.0)) - delta)
		var tower_regen := regen + float(tower.get("base_regen", 0.0))
		if tower_regen > 0.0 and float(tower["hp"]) < float(tower["max_hp"]):
			tower["hp"] = minf(float(tower["max_hp"]), float(tower["hp"]) + tower_regen * delta)
		tower["attack_timer"] = float(tower["attack_timer"]) - delta
		tower["heat"] = maxf(0.0, float(tower["heat"]) - delta * 1.6)
		var position := tower["pos"] as Vector2
		var size := TOWER_SPRITE_BASE * float(tower.get("sprite_scale", 1.0))
		var pivot := position + Vector2(0.0, -size * 0.30)
		var effective_range := float(tower["range"]) * range_mult
		var target := nearest_enemy(position, effective_range)
		if target.is_empty():
			continue
		# 弓弩持续转向当前目标，先转到位再放箭，避免箭从塔心凭空冒出。
		var target_pos := target["pos"] as Vector2
		var aim_vector := target_pos - pivot
		var desired_angle := aim_vector.angle()
		var aim_angle := lerp_angle(float(tower["aim_angle"]), desired_angle, minf(1.0, delta * 12.0))
		tower["aim_angle"] = aim_angle
		tower["aim_dir"] = Vector2.from_angle(aim_angle)
		if float(tower["attack_timer"]) > 0.0:
			continue
		if absf(angle_difference(aim_angle, desired_angle)) > 0.32:
			continue
		tower["heat"] = minf(1.0, float(tower["heat"]) + 0.34)
		var spread := 1.0 + overcharge * float(tower["heat"])
		var shots := 1 + volley
		var base_damage := float(tower["damage"]) * damage_mult
		var travel := aim_vector.length() / maxf(1.0, float(tower["projectile_speed"]) * arrow_speed_mult)
		var enemy_speed := float(target.get("speed", 0.0))
		var lead := target_pos - aim_vector.normalized() * enemy_speed * travel * 0.85
		var aim_dir: Vector2 = tower["aim_dir"]
		var bow_origin: Vector2 = pivot + aim_dir * (size * 0.18)
		# 塔基挨着墙体时，弩口可能伸进实心格；此时退回塔身再射出，保证箭真的能出手。
		if map_layout != null and map_layout.is_segment_wall_blocked(pivot, bow_origin, 3.0):
			bow_origin = position
		for shot_index in range(shots):
			var aim: Vector2 = lead - bow_origin
			if shots > 1:
				var jitter := (float(shot_index) - float(shots - 1) * 0.5) * 0.09
				aim = aim.rotated(jitter)
			var damage := base_damage
			var critical := false
			if crit_chance > 0.0 and rng.randf() < crit_chance:
				damage *= 1.8
				critical = true
			_fire_tower_arrow(
				bow_origin,
				aim.normalized(),
				float(tower["projectile_speed"]) * arrow_speed_mult,
				damage,
				int(tower["pierce"]) + pierce_bonus,
				tower["arrow_color"] as Color,
				critical,
				position
			)
		tower["recoil"] = 1.0
		tower["muzzle"] = 0.10
		tower["attack_timer"] = maxf(0.08, float(tower["cooldown"]) * rate_mult / spread)


func _fire_tower_arrow(origin: Vector2, direction: Vector2, speed: float, damage: float, pierce: int, color: Color, critical: bool, tower_origin: Vector2 = Vector2.ZERO) -> void:
	if tower_shots.size() > 220:
		return
	var shot := _take_pooled(_free_tower_shots)
	var hit_list: Array = shot.get("hit", []) as Array
	if not hit_list is Array:
		hit_list = []
	hit_list.clear()
	shot["pos"] = origin
	shot["vel"] = direction * speed
	shot["damage"] = damage
	shot["pierce"] = maxi(1, pierce)
	shot["ttl"] = 1.5
	shot["hit"] = hit_list
	shot["color"] = color
	shot["critical"] = critical
	shot["burn"] = float(tower_stats.get("tower_burn", 0.0))
	shot["slow"] = float(tower_stats.get("tower_slow", 0.0))
	shot["knockback"] = float(tower_stats.get("tower_knockback", 0.0))
	shot["splash"] = float(tower_stats.get("tower_splash", 0.0))
	shot["chain"] = int(tower_stats.get("tower_chain", 0))
	shot["execute"] = float(tower_stats.get("tower_execute", 0.0))
	shot["lifesteal"] = float(tower_stats.get("tower_lifesteal", 0.0))
	shot["marksman"] = float(tower_stats.get("tower_marksman", 0.0))
	shot["origin"] = tower_origin
	tower_shots.append(shot)


func _update_tower_shots(delta: float) -> void:
	if tower_shots.is_empty():
		return
	for shot in tower_shots:
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
		for index in query_circle(position, 38.0):
			if hit_list.has(index) or index < 0 or index >= enemies.size():
				continue
			var enemy := enemies[index]
			if not bool(enemy.get("alive", false)):
				continue
			var enemy_pos := enemy["pos"] as Vector2
			if position.distance_to(enemy_pos) > 22.0 + float(enemy["radius"]):
				continue
			hit_list.append(index)
			var direction := (shot["vel"] as Vector2).normalized()
			var damage := float(shot["damage"])
			# 神射：距离越远伤害越高
			var marksman := float(shot.get("marksman", 0.0))
			if marksman > 0.0:
				var travelled := (shot["origin"] as Vector2).distance_to(enemy_pos)
				damage *= 1.0 + marksman * clampf(travelled / 420.0, 0.0, 1.0)
			# 破甲：残血直接斩杀
			var execute := float(shot.get("execute", 0.0))
			if execute > 0.0 and float(enemy["hp"]) <= float(enemy["max_hp"]) * execute:
				damage = maxf(damage, float(enemy["hp"]) + 1.0)
			damage_enemy(index, damage, direction * float(shot.get("knockback", 0.0)), shot["color"] as Color, bool(shot["critical"]))
			var burn := float(shot.get("burn", 0.0))
			if burn > 0.0:
				enemy["burn_timer"] = maxf(float(enemy.get("burn_timer", 0.0)), 2.4)
				enemy["burn_dps"] = maxf(float(enemy.get("burn_dps", 0.0)), burn)
			var slow := float(shot.get("slow", 0.0))
			if slow > 0.0:
				enemy["slow_timer"] = maxf(float(enemy.get("slow_timer", 0.0)), 1.8)
				enemy["slow_factor"] = minf(float(enemy.get("slow_factor", 1.0)), clampf(1.0 - slow, 0.25, 1.0))
			var splash := float(shot.get("splash", 0.0))
			if splash > 0.0:
				damage_circle(enemy_pos, splash, damage * 0.45, 0.0, shot["color"] as Color)
			var lifesteal := float(shot.get("lifesteal", 0.0))
			if lifesteal > 0.0:
				ally_support.emit("tower", "heal", damage * lifesteal)
			var chain := int(shot.get("chain", 0))
			if chain > 0:
				_chain_tower_arrow(enemy_pos, index, damage * 0.6, chain, shot["color"] as Color)
			shot["pierce"] = int(shot["pierce"]) - 1
			if int(shot["pierce"]) <= 0:
				shot["ttl"] = 0.0
				break


func _chain_tower_arrow(origin: Vector2, skip_index: int, damage: float, jumps: int, color: Color) -> void:
	var current := origin
	var visited: Array[int] = [skip_index]
	for i in range(jumps):
		var best := -1
		var best_dist := 190.0 * 190.0
		for index in query_circle(current, 190.0):
			if visited.has(index) or index < 0 or index >= enemies.size():
				continue
			var enemy := enemies[index]
			if not bool(enemy.get("alive", false)):
				continue
			var dist := current.distance_squared_to(enemy["pos"] as Vector2)
			if dist < best_dist:
				best_dist = dist
				best = index
		if best < 0:
			return
		visited.append(best)
		var next_pos := enemies[best]["pos"] as Vector2
		add_effect({
			"type": "thrust", "pos": current, "ttl": 0.18, "max_ttl": 0.18,
			"direction": (next_pos - current).normalized(),
			"length": current.distance_to(next_pos), "color": color,
		})
		damage_enemy(best, damage, Vector2.ZERO, color, false)
		current = next_pos
		damage *= 0.8


func damage_tower(index: int, damage: float, attacker_index: int = -1) -> void:
	if index < 0 or index >= towers.size():
		return
	var tower := towers[index]
	if not bool(tower.get("alive", false)):
		return
	var armor := clampf(float(tower.get("armor", 0.0)), 0.0, 0.70)
	var final_damage := maxf(1.0, damage * (1.0 - armor))
	tower["hp"] = float(tower["hp"]) - final_damage
	tower["flash"] = 0.16
	tower_damaged.emit(str(tower["id"]), clampf(float(tower["hp"]) / maxf(1.0, float(tower["max_hp"])), 0.0, 1.0))
	# 荆棘墙：塔受击反弹伤害给攻击者
	var thorns := float(tower_stats.get("tower_thorns", 0.0))
	if thorns > 0.0 and attacker_index >= 0:
		damage_enemy(attacker_index, final_damage * thorns, Vector2.ZERO, Color("#d9a95f"), false)
	if float(tower["hp"]) <= 0.0:
		_destroy_tower(index)


func _destroy_tower(index: int) -> void:
	var tower := towers[index]
	if not bool(tower.get("alive", false)):
		return
	tower["alive"] = false
	tower["hp"] = 0.0
	var position := tower["pos"] as Vector2
	add_effect({
		"type": "death", "pos": position, "ttl": 0.85, "max_ttl": 0.85,
		"radius": 96.0, "color": Color("#c4573d"),
	})
	add_effect({
		"type": "aura", "pos": position, "ttl": 0.6, "max_ttl": 0.6,
		"radius": 140.0, "color": Color("#e07845"),
	})
	tower_destroyed.emit(str(tower["id"]), position)
	# 重建：由「修造」类增益解锁，倒计时后原地复起，血量按比例
	var rebuild := float(tower_stats.get("tower_rebuild", 0.0))
	if rebuild > 0.0:
		tower["rebuild_timer"] = TOWER_REBUILD_DELAY * clampf(1.0 - rebuild, 0.25, 1.0)
	else:
		tower["rebuild_timer"] = -1.0


func _revive_towers(delta: float) -> void:
	for tower in towers:
		if bool(tower.get("alive", false)):
			continue
		var timer := float(tower.get("rebuild_timer", -1.0))
		if timer < 0.0:
			continue
		timer -= delta
		tower["rebuild_timer"] = timer
		if timer > 0.0:
			continue
		tower["alive"] = true
		tower["hp"] = float(tower["max_hp"]) * clampf(float(tower_stats.get("tower_rebuild_hp", 0.6)), 0.2, 1.0)
		tower["attack_timer"] = 0.5
		add_effect({
			"type": "aura", "pos": tower["pos"], "ttl": 0.8, "max_ttl": 0.8,
			"radius": 110.0, "color": Color("#9bc27e"),
		})


func _nearest_tower_index(origin: Vector2, max_range: float) -> int:
	var best := -1
	var best_dist := max_range
	for index in range(towers.size()):
		var tower := towers[index]
		if not bool(tower.get("alive", false)):
			continue
		var dist := origin.distance_to(tower["pos"] as Vector2) - float(tower["radius"])
		if dist < best_dist:
			best_dist = dist
			best = index
	return best


func reset(seed_value: int = 20261123) -> void:
	enemies.clear()
	allies.clear()
	towers.clear()
	tower_shots.clear()
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
	_update_towers(delta)
	_revive_towers(delta)
	_update_allies(delta, player)
	_update_enemies(delta, player, enemy_speed_mult)
	_update_player_shots(delta)
	_update_tower_shots(delta)
	_update_enemy_shots(delta, player)
	_update_pickups(delta, player)
	_update_effects(delta)
	_update_wade_splashes(delta)
	_cleanup_dead()
	queue_redraw()


## 涉水减速：水面且非桥面时生效；wade_bonus 为玩家“涉水”卡牌的减免。
func wade_speed_factor(position: Vector2, wade_bonus: float = 0.0) -> float:
	if map_layout == null or not map_layout.is_wade_position(position):
		return 1.0
	return lerpf(WADE_SPEED_FACTOR, 1.0, clampf(wade_bonus, 0.0, 1.0))


## 涉水水花：每帧最多补少量实例，数据数组复用，不建节点。
func spawn_wade_splash(position: Vector2, size: float = 1.0) -> void:
	if wade_splashes.size() >= WADE_SPLASH_CAPACITY:
		return
	var splash := _take_pooled(_free_wade_splashes)
	if splash.is_empty():
		splash = {}
	else:
		splash.clear()
	splash["pos"] = position + Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-2.0, 4.0))
	splash["ttl"] = 0.42
	splash["max_ttl"] = 0.42
	splash["size"] = maxf(0.6, size)
	wade_splashes.append(splash)


func _update_wade_splashes(delta: float) -> void:
	for splash in wade_splashes:
		splash["ttl"] = float(splash["ttl"]) - delta
	for index in range(wade_splashes.size() - 1, -1, -1):
		if float(wade_splashes[index]["ttl"]) <= 0.0:
			_return_pooled(_free_wade_splashes, _swap_remove_at(wade_splashes, index))


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
	var hp := float(definition.get("hp", 10.0)) * enemy_hp_mult * difficulty_hp_mult
	var enemy := {
		"id": enemy_id,
		"pos": position,
		"hp": hp,
		"max_hp": hp,
		"speed": float(definition.get("speed", 70.0)) * difficulty_speed_mult,
		"damage": float(definition.get("damage", 8.0)) * difficulty_damage_mult,
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


func set_difficulty(progress: float, curve: Dictionary) -> void:
	var t := clampf(progress, 0.0, 1.0)
	# 前段平缓、后段加速：避免开局就压血，又在黎明前形成真正的压力。
	var eased := t * t
	difficulty_hp_mult = lerpf(float(curve.get("hp_start", 1.0)), float(curve.get("hp_end", 1.0)), eased)
	difficulty_damage_mult = lerpf(float(curve.get("damage_start", 1.0)), float(curve.get("damage_end", 1.0)), eased)
	difficulty_speed_mult = lerpf(float(curve.get("speed_start", 1.0)), float(curve.get("speed_end", 1.0)), eased)


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


func _take_pooled(free: Array[Dictionary]) -> Dictionary:
	if free.is_empty():
		return {}
	return free.pop_back()


func _return_pooled(free: Array[Dictionary], item: Dictionary) -> void:
	if free.size() >= 512:
		return
	free.append(item)


func _swap_remove_at(items: Array, index: int) -> Dictionary:
	var last := items.size() - 1
	var item := items[index] as Dictionary
	if index != last:
		items[index] = items[last]
	items.resize(last)
	return item


func fire_player_projectile(origin: Vector2, direction: Vector2, speed: float, damage: float, pierce: int, color: Color = GOLD) -> void:
	var shot := _take_pooled(_free_player_shots)
	var hit_list: Array = shot.get("hit", []) as Array
	if not hit_list is Array:
		hit_list = []
	hit_list.clear()
	shot["pos"] = origin
	shot["vel"] = direction.normalized() * speed
	shot["damage"] = damage
	shot["pierce"] = pierce
	shot["ttl"] = 1.7
	shot["hit"] = hit_list
	shot["color"] = color
	player_shots.append(shot)


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
		_return_pooled(_free_effects, effects.pop_front())
	var stored := _take_pooled(_free_effects)
	if stored.is_empty():
		stored = {}
	else:
		stored.clear()
	for key in effect.keys():
		stored[key] = effect[key]
	effects.append(stored)


func spawn_oil(position: Vector2, amount: int = 2) -> void:
	var drop := _take_pooled(_free_oil_drops)
	drop["pos"] = position
	drop["amount"] = amount
	drop["phase"] = rng.randf_range(0.0, TAU)
	drop["magnet"] = false
	oil_drops.append(drop)


func spawn_heal(position: Vector2, amount: float = 9.0) -> void:
	var drop := _take_pooled(_free_heal_drops)
	drop["pos"] = position
	drop["amount"] = amount
	drop["phase"] = rng.randf_range(0.0, TAU)
	drop["magnet"] = false
	heal_drops.append(drop)


func spawn_scale(position: Vector2, color: String) -> void:
	var drop := _take_pooled(_free_scale_drops)
	drop["pos"] = position
	drop["color"] = color
	drop["phase"] = rng.randf_range(0.0, TAU)
	drop["magnet"] = false
	scale_drops.append(drop)


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
			var ally_speed := float(ally["speed"])
			if map_layout != null:
				ally_speed *= wade_speed_factor(position)
			position += movement * ally_speed * delta
			if ally_speed < float(ally["speed"]) * 0.99 and rng.randf() < 0.18:
				spawn_wade_splash(position, 0.8)
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
	var player_pos_target := player.get("pos", Vector2.ZERO) as Vector2
	var dark_speed := 1.0
	var aggro := TOWER_AGGRO * float(tower_stats.get("tower_taunt", 1.0))
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
		# 目标选择：最近的活塔若严格近于玩家，则改为围攻箭塔。
		# 这样箭塔能替玩家吸收压力，但不会让杂兵完全无视玩家。
		var target := player_pos_target
		var siege_index := -1
		var player_distance := position.distance_to(player_pos_target)
		if not towers.is_empty():
			var tower_index := _nearest_tower_index(position, aggro)
			if tower_index >= 0:
				var tower_distance := position.distance_to(towers[tower_index]["pos"] as Vector2)
				if tower_distance < player_distance:
					siege_index = tower_index
					target = towers[tower_index]["pos"] as Vector2
		var to_target := target - position
		var distance := maxf(0.001, to_target.length())
		var direction := to_target / distance
		var behavior := str(enemy["behavior"])
		var movement := Vector2.ZERO
		var navigation := direction
		if siege_index >= 0:
			# 塔在前方近处时不走流场（流场只指向玩家），直线压上并贴塔。
			navigation = direction
			if map_layout != null and distance > 90.0:
				navigation = direction
		elif map_layout != null:
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
		if map_layout != null:
			speed *= wade_speed_factor(position)
		var previous_position := position
		position += movement * speed * delta
		if speed < float(enemy["speed"]) * speed_mult * dark_speed * slow_factor * 0.99 \
				and movement.length_squared() > 0.01:
			if rng.randf() < 0.16:
				spawn_wade_splash(position, clampf(float(enemy["radius"]) / 18.0, 0.7, 1.8))
		# 朝向滞回：只有横向分量足够明确时才翻面，避免贴塔/贴人时逐帧左右抖。
		var horizontal := absf(movement.x) if movement.length_squared() > 0.0001 else absf(direction.x)
		if horizontal >= 0.30:
			enemy["facing_x"] = signf(movement.x if absf(movement.x) > 0.01 else direction.x)
		var knockback := enemy["knockback"] as Vector2
		position += knockback * delta
		enemy["knockback"] = knockback.move_toward(Vector2.ZERO, 520.0 * delta)
		if map_layout != null:
			position = map_layout.move_circle(
				previous_position,
				position,
				clampf(float(enemy["radius"]) * 0.72, 9.0, 26.0)
			)
		# 箭塔是实体：把敌兵挡在塔基外，避免走进塔身里原地翻转。
		position = _resolve_tower_collision(position, clampf(float(enemy["radius"]) * 0.72, 9.0, 26.0))
		enemy["pos"] = position
		if siege_index >= 0 and siege_index < towers.size():
			# 逼近到塔基座就动手拆塔
			var tower := towers[siege_index]
			if bool(tower.get("alive", false)):
				var tower_pos := tower["pos"] as Vector2
				var reach := float(tower["radius"]) * 1.45 + float(enemy["radius"]) + 16.0
				if position.distance_to(tower_pos) <= reach and float(tower.get("hit_cd", 0.0)) <= 0.0:
					play_enemy_attack_fx(str(enemy["id"]), tower_pos, direction)
					damage_tower(siege_index, float(enemy["damage"]), index)
					tower["hit_cd"] = 0.62
		elif distance < player_radius + float(enemy["radius"]) and _contact_cd <= 0.0:
			play_enemy_attack_fx(str(enemy["id"]), position, direction)
			player_hit.emit(float(enemy["damage"]))
			_contact_cd = 0.70
		if position.distance_squared_to(player_pos_target) > 2100.0 * 2100.0:
			enemy["alive"] = false
		if _screen_clear_timer > 0.0:
			enemy["speed"] = float(enemy["speed"])


func _resolve_tower_collision(position: Vector2, body_radius: float) -> Vector2:
	if towers.is_empty():
		return position
	for tower in towers:
		if not bool(tower.get("alive", false)):
			continue
		var tower_pos := tower["pos"] as Vector2
		var minimum := float(tower["radius"]) * 1.45 + body_radius + 10.0
		var offset := position - tower_pos
		var distance := offset.length()
		if distance >= minimum:
			continue
		if distance < 0.001:
			offset = Vector2.DOWN
			distance = 1.0
		position = tower_pos + offset / distance * minimum
	return position


func _fire_enemy_shot(origin: Vector2, direction: Vector2, damage: float, speed: float) -> void:
	var shot := _take_pooled(_free_enemy_shots)
	shot["pos"] = origin
	shot["vel"] = direction * speed
	shot["damage"] = damage
	shot["ttl"] = 3.2
	enemy_shots.append(shot)


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
		# 箭塔同样会吃流矢：先判塔，再判玩家。
		var tower_hit := false
		for tower_index in range(towers.size()):
			var tower := towers[tower_index]
			if not bool(tower.get("alive", false)):
				continue
			if position.distance_to(tower["pos"] as Vector2) < float(tower["radius"]) + 9.0:
				damage_tower(tower_index, float(shot["damage"]))
				shot["ttl"] = 0.0
				tower_hit = true
				break
		if tower_hit:
			continue
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
	_update_drop_array(oil_drops, target, pickup_radius, delta, _free_oil_drops, func(drop: Dictionary) -> void:
		oil_collected.emit(int(drop.get("amount", 2)))
	)
	_update_drop_array(heal_drops, target, pickup_radius, delta, _free_heal_drops, func(drop: Dictionary) -> void:
		heal_collected.emit(float(drop.get("amount", 9.0)))
	)
	_update_drop_array(scale_drops, target, pickup_radius, delta, _free_scale_drops, func(drop: Dictionary) -> void:
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
			_return_pooled(_free_orbs, _swap_remove_at(orbs, index))


func _update_drop_array(drops: Array[Dictionary], target: Vector2, pickup_radius: float, delta: float, free_list: Array[Dictionary], on_take: Callable) -> void:
	for index in range(drops.size() - 1, -1, -1):
		var drop := drops[index]
		var position := drop["pos"] as Vector2
		var distance := position.distance_to(target)
		if bool(drop.get("magnet", false)) or distance < pickup_radius:
			position = position.move_toward(target, maxf(240.0, 520.0 - distance))
			drop["pos"] = position
		if position.distance_to(target) < 24.0:
			on_take.call(drop)
			_return_pooled(free_list, _swap_remove_at(drops, index))


func _update_effects(delta: float) -> void:
	for effect in effects:
		effect["ttl"] = float(effect["ttl"]) - delta
	for effect in jeff_effects:
		effect["age"] = float(effect["age"]) + delta
	for index in range(effects.size() - 1, -1, -1):
		if float(effects[index]["ttl"]) <= 0.0:
			_return_pooled(_free_effects, _swap_remove_at(effects, index))
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
			_return_pooled(_free_player_shots, _swap_remove_at(player_shots, index))
	for index in range(enemy_shots.size() - 1, -1, -1):
		if float(enemy_shots[index]["ttl"]) <= 0.0:
			_return_pooled(_free_enemy_shots, _swap_remove_at(enemy_shots, index))
	for index in range(tower_shots.size() - 1, -1, -1):
		if float(tower_shots[index]["ttl"]) <= 0.0:
			_return_pooled(_free_tower_shots, _swap_remove_at(tower_shots, index))


func _cleanup_dead() -> void:
	var removed := 0
	for index in range(enemies.size() - 1, -1, -1):
		if bool(enemies[index].get("alive", false)):
			continue
		enemies.remove_at(index)
		removed += 1
	# 未解锁重建的塔：残骸保留片刻后彻底移除
	for index in range(towers.size() - 1, -1, -1):
		var tower := towers[index]
		if bool(tower.get("alive", false)):
			continue
		if float(tower.get("rebuild_timer", -1.0)) < -1.0:
			towers.remove_at(index)
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
		var orb := _take_pooled(_free_orbs)
		orb["pos"] = position + offset
		orb["value"] = maxf(1.0, xp_value / float(orb_count))
		orb["taken"] = false
		orb["magnet"] = false
		orbs.append(orb)
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
	_draw_towers()
	_draw_pickups()
	_draw_enemies()
	_draw_allies()
	_draw_player()
	_draw_health_bars()
	_draw_wade_splashes()
	_draw_projectiles()
	_draw_tower_shots()
	_draw_jeff_fx()
	_draw_effects()
	FeedbackManager.draw(self)
	_draw_dragons()

func _draw_towers() -> void:
	if towers.is_empty():
		return
	for tower in towers:
		var position := tower["pos"] as Vector2
		var alive := bool(tower.get("alive", false))
		if absf(position.x - player_pos.x) > VIEW_HALF.x + 220.0:
			continue
		if absf(position.y - player_pos.y) > VIEW_HALF.y + 260.0:
			continue
		var size := TOWER_SPRITE_BASE * float(tower.get("sprite_scale", 1.0))
		# 落地阴影
		draw_circle(position + Vector2(0, size * 0.28), size * 0.34, Color(0.0, 0.0, 0.0, 0.26))
		var tex := tower.get("tex", null) as Texture2D
		if not alive:
			# 残骸：压暗 + 半高
			if tex != null:
				draw_set_transform(position, 0.0, Vector2(1.0, 0.42))
				draw_texture_rect(
					tex,
					Rect2(Vector2(-size * 0.5, -size * 0.79), Vector2(size, size)),
					false,
					Color(0.30, 0.24, 0.22, 0.85)
				)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		if tex != null:
			var tint := Color.WHITE
			if float(tower["flash"]) > 0.0:
				tint = FeedbackManager.config.flash_color
			draw_set_transform(position, 0.0, Vector2(1.0, 1.0))
			draw_texture_rect(
				tex,
				Rect2(Vector2(-size * 0.5, -size * 0.79), Vector2(size, size)),
				false,
				tint
			)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_rect(
				Rect2(position - Vector2(size * 0.5, size * 0.9), Vector2(size, size)),
				Color("#6d5a42")
			)
		_draw_tower_weapon(tower, position + Vector2(0.0, -size * 0.30), size)
		# 血条统一在 _draw_health_bars() 中绘制，避免与敌兵/佣兵血条层叠错位。


func _draw_tower_weapon(tower: Dictionary, pivot: Vector2, size: float) -> void:
	var angle := float(tower.get("aim_angle", -PI * 0.5))
	var aim_dir := tower.get("aim_dir", Vector2.UP) as Vector2
	var recoil := clampf(float(tower.get("recoil", 0.0)), 0.0, 1.0)
	var kick := pivot - aim_dir * (size * 0.035 * recoil)
	# 先压住贴图里的静态小弩，再画可旋转的弩身，避免出现两把弩。
	draw_circle(pivot, size * 0.082, Color(0.16, 0.12, 0.09, 0.92))
	draw_circle(pivot, size * 0.062, Color("#6d563d"))
	var pulse := 0.82 + recoil * 0.05
	draw_set_transform(kick, angle, Vector2(pulse, pulse))
	var wood := Color("#8a6a45")
	var wood_light := Color("#b18a58")
	var metal := Color("#cfd6cf")
	# 弩臂：中段木托 + 前方横向弩弓 + 弦
	draw_rect(Rect2(Vector2(-size * 0.035, -size * 0.018), Vector2(size * 0.20, size * 0.036)), wood)
	draw_rect(Rect2(Vector2(-size * 0.035, -size * 0.018), Vector2(size * 0.20, size * 0.012)), wood_light)
	var limb_root := Vector2(size * 0.135, 0.0)
	var limb_top := Vector2(size * 0.195, -size * 0.095)
	var limb_bottom := Vector2(size * 0.195, size * 0.095)
	draw_line(limb_root, limb_top, wood, 3.0)
	draw_line(limb_root, limb_bottom, wood, 3.0)
	draw_line(limb_top, limb_bottom, Color(0.86, 0.82, 0.66, 0.85), 1.0)
	# 已上弦的箭
	draw_line(Vector2(-size * 0.01, 0.0), Vector2(size * 0.235, 0.0), metal, 2.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(size * 0.235, 0.0),
			Vector2(size * 0.205, -size * 0.028),
			Vector2(size * 0.205, size * 0.028),
		]),
		Color("#f4e7c2")
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var muzzle := clampf(float(tower.get("muzzle", 0.0)) / 0.10, 0.0, 1.0)
	if muzzle > 0.0:
		var tip := kick + aim_dir * (size * 0.21)
		draw_circle(tip, size * 0.035 * muzzle + 3.0, Color(1.0, 0.86, 0.48, 0.55 * muzzle))
		draw_circle(tip, size * 0.016 * muzzle + 1.5, Color(1.0, 0.97, 0.84, 0.9 * muzzle))


func _draw_tower_shots() -> void:
	if tower_shots.is_empty():
		return
	for shot in tower_shots:
		var position := shot["pos"] as Vector2
		var vel := shot["vel"] as Vector2
		var direction := vel.normalized()
		var color := shot["color"] as Color
		var critical := bool(shot.get("critical", false))
		var side := Vector2(-direction.y, direction.x)
		var shaft := 24.0 if not critical else 28.0
		# 飞行拖尾：三节递减，让高速箭矢的轨迹看得见。
		for trail_index in range(3):
			var back := position - direction * (8.0 + float(trail_index) * 9.0)
			draw_line(back, back - direction * 7.0, Color(color, 0.20 - float(trail_index) * 0.055), 2.0, true)
		# 箭矢按真实形状绘制（杆 + 箭头 + 尾羽），不用长线条冒充。
		var tail := position - direction * shaft
		draw_line(tail, position, color, 2.6 if critical else 2.0, true)
		var head := position + direction * 9.0
		draw_colored_polygon(
			PackedVector2Array([head, position - direction * 1.0 + side * 4.0, position - direction * 1.0 - side * 4.0]),
			color
		)
		draw_line(tail, tail - direction * 6.0 + side * 3.5, Color(color, 0.8), 1.4, true)
		draw_line(tail, tail - direction * 6.0 - side * 3.5, Color(color, 0.8), 1.4, true)
		if critical:
			draw_circle(position, 10.0, Color(1.0, 0.84, 0.42, 0.16))


func _draw_light(center: Vector2) -> void:
	# 灯火范围用多层柔和衰减表现，保留「照到哪」的判断依据，
	# 但不再画一道生硬的辅助圆弧线。
	var light_radius := float(get_meta("light_radius", 225.0))
	draw_circle(center, light_radius + 90.0, Color(0.95, 0.62, 0.22, 0.030))
	draw_circle(center, light_radius + 58.0, Color(0.96, 0.66, 0.24, 0.034))
	draw_circle(center, light_radius + 30.0, Color(0.98, 0.72, 0.28, 0.040))
	draw_circle(center, light_radius + 10.0, Color(0.99, 0.78, 0.34, 0.046))


func _draw_pickups() -> void:
	for orb in orbs:
		var position := orb["pos"] as Vector2
		draw_circle(position, 7.0, Color(0.94, 0.70, 0.27, 0.16))
		draw_circle(position, 3.5, Color(0.98, 0.83, 0.44, 0.96))
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


func _draw_enemies() -> void:
	if not bool(get_meta("draw_enemies", true)):
		return
	var groups: Dictionary = {}
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
	for batch_id in groups.keys():
		_draw_enemy_batch(str(batch_id), groups[batch_id] as Array, true)
	for batch_id in groups.keys():
		_draw_enemy_batch(str(batch_id), groups[batch_id] as Array, false)


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


func _draw_health_bars() -> void:
	# 除玩家外的所有单位都带血条；背景、填色和细边框共享一次批量绘制。
	_health_bar_count = 0
	for enemy in enemies:
		if not bool(enemy.get("alive", false)):
			continue
		var position := enemy["pos"] as Vector2
		if absf(position.x - player_pos.x) > VIEW_HALF.x + 80.0:
			continue
		if absf(position.y - player_pos.y) > VIEW_HALF.y + 80.0:
			continue
		var is_boss := bool(enemy.get("boss", false))
		var is_elite := bool(enemy.get("elite", false))
		var size := ENEMY_SPRITE_BASE_SIZE * float(enemy.get("scale", 1.0))
		var width := 96.0 if is_boss else (46.0 if is_elite else maxf(20.0, float(enemy["radius"]) * 0.92))
		var height := 6.0 if is_boss else (4.0 if is_elite else 3.0)
		var top := position + Vector2(-width * 0.5, -size * 0.92)
		_draw_unit_bar(top, width, height, float(enemy["hp"]), float(enemy["max_hp"]))
	for tower in towers:
		if not bool(tower.get("alive", false)):
			continue
		var position := tower["pos"] as Vector2
		var size := TOWER_SPRITE_BASE * float(tower.get("sprite_scale", 1.0))
		var width := size * 0.62
		_draw_unit_bar(
			position + Vector2(-width * 0.5, -size * 0.94),
			width,
			5.0,
			float(tower["hp"]),
			float(tower["max_hp"])
		)
	for ally in allies:
		var position := ally["pos"] as Vector2
		var size := PLAYER_SPRITE_SIZE * float(ally.get("scale", 0.62))
		var width := maxf(22.0, size * 0.52)
		_draw_unit_bar(
			position + Vector2(-width * 0.5, -size * 0.86),
			width,
			3.0,
			float(ally["hp"]),
			float(ally["max_hp"])
		)
	_health_bar_batch.visible_instance_count = _health_bar_count
	if _health_bar_count > 0:
		draw_multimesh(_health_bar_batch, _health_bar_texture)


func _draw_unit_bar(top_left: Vector2, width: float, height: float, hp: float, max_hp: float) -> void:
	var ratio := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	_append_health_bar_rect(Rect2(top_left, Vector2(width, height)), Color(0.02, 0.025, 0.025, 0.72))
	var color := Color("#8fbf6e")
	if ratio < 0.30:
		color = Color("#c4573d")
	elif ratio < 0.64:
		color = Color("#d8b45f")
	_append_health_bar_rect(Rect2(top_left, Vector2(maxf(1.0, width * ratio), height)), color)
	var border := Color(0.0, 0.0, 0.0, 0.35)
	_append_health_bar_rect(Rect2(top_left, Vector2(width, 1.0)), border)
	_append_health_bar_rect(Rect2(top_left + Vector2(0.0, height - 1.0), Vector2(width, 1.0)), border)
	_append_health_bar_rect(Rect2(top_left + Vector2(0.0, 1.0), Vector2(1.0, height - 2.0)), border)
	_append_health_bar_rect(Rect2(top_left + Vector2(width - 1.0, 1.0), Vector2(1.0, height - 2.0)), border)


func _append_health_bar_rect(rect: Rect2, color: Color) -> void:
	var xform := Transform2D(0.0, rect.size, 0.0, rect.get_center())
	_health_bar_batch.set_instance_transform_2d(_health_bar_count, xform)
	_health_bar_batch.set_instance_color(_health_bar_count, color)
	_health_bar_count += 1


func _draw_wade_splashes() -> void:
	if wade_splashes.is_empty():
		return
	for splash in wade_splashes:
		var progress := 1.0 - clampf(float(splash["ttl"]) / maxf(0.001, float(splash["max_ttl"])), 0.0, 1.0)
		var pos := splash["pos"] as Vector2
		var radius := (5.0 + progress * 15.0) * float(splash["size"])
		var alpha := 0.55 * (1.0 - progress)
		draw_arc(pos, radius, 0.0, TAU, 14, Color(0.78, 0.92, 0.95, alpha), 1.8, true)
		for index in range(3):
			var angle := float(index) * TAU / 3.0 + progress * 1.8
			var droplet := pos + Vector2(cos(angle), sin(angle) * 0.62) * radius * 0.72
			draw_circle(droplet, 1.6 * float(splash["size"]), Color(0.92, 0.98, 1.0, alpha * 1.2))


func _draw_allies() -> void:
	for ally in allies:
		var position := ally["pos"] as Vector2
		var scale_value := float(ally.get("scale", 0.62))
		var size := PLAYER_SPRITE_SIZE * scale_value
		draw_circle(position + Vector2(0, size * 0.16), size * 0.28, Color(0.0, 0.0, 0.0, 0.25))
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
		var color := shot["color"] as Color
		var side := Vector2(-direction.y, direction.x)
		# 弹丸本体：短杆 + 弹头，不画贯穿式辅助线
		draw_line(position - direction * 6.0, position, color, 2.5, true)
		draw_colored_polygon(
			PackedVector2Array([
				position + direction * 5.0,
				position + side * 3.0,
				position - side * 3.0,
			]),
			color
		)
	for shot in enemy_shots:
		var position := shot["pos"] as Vector2
		draw_circle(position, 4.5, Color("#d65b45"))
		draw_circle(position, 2.0, Color("#ffd9a8"))


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
