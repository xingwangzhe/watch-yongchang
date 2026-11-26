extends GutTest

## 战斗视觉契约：敌兵尺寸与「正式游玩不得出现辅助线」回归。
## 项目是立即模式渲染，这里用源码静态检查锁死绘制约定。

const BATTLEFIELD_SCRIPT := "res://scripts/actors/battlefield.gd"


func _source() -> String:
	var file := FileAccess.open(BATTLEFIELD_SCRIPT, FileAccess.READ)
	if file == null:
		fail_test("battlefield.gd must be readable")
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func test_enemy_sprites_are_larger_but_below_player() -> void:
	var enemies := GameData.get_enemies()
	var player_size := 96.0
	var base := 96.0
	for enemy_id in enemies.keys():
		var definition: Dictionary = enemies[enemy_id] as Dictionary
		var scale := float(definition.get("scale", 0.0))
		var drawn := base * scale
		if enemy_id == "general" or enemy_id == "daimyo":
			assert_gt(drawn, player_size, "%s elite should be larger than the player" % enemy_id)
			continue
		assert_gte(drawn, 72.0, "%s must stay readable after the Wokou size cut" % enemy_id)
		assert_lt(drawn, player_size, "%s must stay below the player" % enemy_id)
		assert_gte(float(definition.get("radius", 0.0)), 23.0, "%s collision must match its new size" % enemy_id)


func test_no_persistent_guide_arcs_in_formal_battle_draw() -> void:
	# _draw() 保留灯火范围（draw_circle 柔和衰减）与技能 VFX，
	# 但普通拾取物、精英环、友军稀有度环、敌方子弹的常驻辅助弧必须消失。
	var text := _source()
	if text.is_empty():
		return
	# 绘制函数在源码里的顺序不固定，按下一个 func 边界逐段截取。
	var sections := {
		"pickups": "func _draw_pickups()",
		"enemies": "func _draw_enemies()",
		"allies": "func _draw_allies()",
		"projectiles": "func _draw_projectiles()",
		"light": "func _draw_light(",
	}
	var bodies := {}
	for key in sections.keys():
		var start := text.find(str(sections[key]))
		assert_gt(start, 0, "%s draw function must exist" % key)
		if start < 0:
			continue
		var next_start := text.find("func _", start + 1)
		if next_start < 0:
			next_start = text.length()
		bodies[key] = text.substr(start, next_start - start)

	var pickup_section: String = bodies.get("pickups", "")
	var enemy_section: String = bodies.get("enemies", "")
	var ally_section: String = bodies.get("allies", "")
	var proj_section: String = bodies.get("projectiles", "")
	var light_section: String = bodies.get("light", "")
	assert_false(pickup_section.contains("draw_arc"), "pickup halo arcs must be removed")
	assert_false(enemy_section.contains("draw_arc"), "elite/boss threat rings must be removed")
	assert_false(ally_section.contains("draw_arc"), "ally rarity rings must be removed")
	assert_false(proj_section.contains("draw_arc"), "enemy projectile halo arcs must be removed")
	assert_false(proj_section.contains("draw_circle(position, 3.0"), "player projectile dot must be replaced by an arrowhead")
	assert_false(light_section.contains("draw_arc"), "light radius must be a soft gradient, not a guide arc")
	assert_false(text.contains("draw_circle(player_pos + Vector2(0, -30)"), "floating guide dot above player must be removed")


func test_tower_and_arrow_drawing_uses_real_sprites_and_shapes() -> void:
	var text := _source()
	if text.is_empty():
		return
	var tower_start := text.find("func _draw_towers()")
	var shots_start := text.find("func _draw_tower_shots()")
	var effects_start := text.find("func _draw_effects()")
	var health_start := text.find("func _draw_health_bars()")
	assert_gt(tower_start, 0)
	assert_gt(shots_start, tower_start)
	assert_gt(effects_start, shots_start)
	assert_gt(health_start, 0, "non-player units need a dedicated health-bar pass")
	var tower_section := text.substr(tower_start, shots_start - tower_start)
	var shot_section := text.substr(shots_start, effects_start - shots_start)
	var health_end := text.find("func _", health_start + 1)
	if health_end < 0:
		health_end = text.length()
	var health_section := text.substr(health_start, health_end - health_start)
	assert_true(tower_section.contains("draw_texture_rect"), "towers must render their large sprite texture")
	assert_true(health_section.contains("_draw_unit_bar"), "units must draw a compact health bar")
	assert_true(health_section.contains("for enemy in enemies"), "enemies must show health bars")
	assert_true(health_section.contains("for tower in towers"), "towers must show health bars")
	assert_true(health_section.contains("for ally in allies"), "mercenaries must show health bars")
	assert_true(shot_section.contains("draw_colored_polygon"), "tower arrows need a real arrowhead, not a debug line")


func test_combat_vfx_effects_are_still_present() -> void:
	var text := _source()
	if text.is_empty():
		return
	for effect_type in ["slash", "thrust", "aura", "death", "scale_burst", "dragon_sweep"]:
		assert_true(text.contains('"%s"' % effect_type), "%s VFX must be preserved" % effect_type)
	assert_false(text.contains('"orbit"'), "retired shield orbit VFX must not return")
