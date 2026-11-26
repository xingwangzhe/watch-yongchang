extends GutTest

const ForgeScript = preload("res://scripts/character/character_forge.gd")

var _tutorial_seen_before := false


func before_each() -> void:
	_tutorial_seen_before = bool(SaveSystem.data.get("tutorial_seen", false))
	SaveSystem.data["tutorial_seen"] = true


func after_each() -> void:
	SaveSystem.data["tutorial_seen"] = _tutorial_seen_before


func test_mercenary_data_is_ming_valid_and_forge_baked() -> void:
	var mercenaries := GameData.get_mercenaries()
	assert_eq(mercenaries.size(), 10)
	var forge := ForgeScript.new()
	add_child_autofree(forge)
	if not forge.load_data():
		fail_test("character forge data must load")
		return
	for mercenary_id in mercenaries.keys():
		var definition: Dictionary = mercenaries[mercenary_id] as Dictionary
		var recipe: Dictionary = definition.get("character_recipe", {}) as Dictionary
		assert_eq(str(recipe.get("faction", "")), "ming", "%s must be a Ming ally" % mercenary_id)
		assert_true(forge.recipe_faction_valid(recipe), "%s mixes factions" % mercenary_id)
		assert_true(["史实", "制度", "民俗", "演绎"].has(str(definition.get("category", ""))))
		assert_gt(str(definition.get("source_ref", "")).length(), 0)
		assert_gt(int(definition.get("price", 0)), 0)
		assert_true(ResourceLoader.exists(str(definition.get("battle_idle", ""))))
		assert_true(ResourceLoader.exists(str(definition.get("battle_walk", ""))))
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
	for spirit_id in ["wangpei_spirit", "wangde_spirit"]:
		var spirit: Dictionary = mercenaries[spirit_id] as Dictionary
		assert_eq(str(spirit.get("category", "")), "民俗")
		assert_string_contains(str(spirit.get("culture_zh", "")), "香火")
		assert_false(str(spirit.get("culture_zh", "")).contains("复活"))


func test_shop_catalog_offers_weapon_equipment_and_mercenary() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var weapons := [{"id": "saber", "level": 1}]
	var passives := {"gaiters": 1}
	var hired: Array[String] = []
	var offers := ShopCatalog.build_offers(weapons, passives, hired, rng)
	assert_eq(offers.size(), int(ShopCatalog.data().get("max_offers", 12)))
	assert_gte(offers.size(), 9, "the market must fill the screen with many compact cards")
	var families: Array[String] = []
	for offer in offers:
		families.append(str(offer.get("family", "")))
		assert_gt(int(offer.get("price", 0)), 0)
		assert_gt(str(offer.get("title", "")).length(), 0)
		assert_gt(str(offer.get("culture", "")).length(), 0)
		assert_gt(str(offer.get("source_ref", "")).length(), 0)
		assert_false(bool(offer.get("sold", true)))
	assert_true(
		families.has("weapon_new") or families.has("weapon_upgrade"),
		"shop must offer a weapon"
	)
	assert_true(
		families.has("equipment_new") or families.has("equipment_upgrade"),
		"shop must offer equipment"
	)
	assert_true(families.has("mercenary"), "shop must offer a mercenary when slots remain")


func test_shop_reroll_keeps_already_purchased_cards() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	await wait_process_frames(2)
	run.run_coin = 1000
	run._open_shop()
	var bought_index := 0
	run._on_shop_buy(bought_index)
	var bought_id := str(run._current_shop_offers[bought_index].get("option_id", ""))
	var coin_before := int(run.run_coin)
	run._on_shop_reroll()
	assert_true(
		bool(run._current_shop_offers[bought_index].get("sold", false)),
		"reroll must not clear a sold card"
	)
	assert_eq(
		str(run._current_shop_offers[bought_index].get("option_id", "")),
		bought_id,
		"reroll must keep the same purchased card in its slot"
	)
	assert_eq(
		int(run.run_coin),
		coin_before - int(run.shop_data.get("reroll_cost", 25)),
		"reroll still costs coin"
	)
	run._on_shop_closed()


func test_shop_purchases_weapon_equipment_and_mercenary_and_resumes() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	await wait_process_frames(2)
	run.run_coin = 1000
	run._open_shop()
	assert_true(run._shop_open)
	assert_true(run._paused)
	var weapon_index := _find_family(run._current_shop_offers, ["weapon_new", "weapon_upgrade"])
	var equipment_index := _find_family(run._current_shop_offers, ["equipment_new", "equipment_upgrade"])
	var mercenary_index := _find_family(run._current_shop_offers, ["mercenary"])
	assert_gte(weapon_index, 0)
	assert_gte(equipment_index, 0)
	assert_gte(mercenary_index, 0)
	var coin_before: int = int(run.run_coin)
	var passives_before: int = int(run.passives.size())
	run._on_shop_buy(weapon_index)
	run._on_shop_buy(equipment_index)
	run._on_shop_buy(mercenary_index)
	assert_lt(run.run_coin, coin_before)
	assert_true(bool(run._current_shop_offers[weapon_index].get("sold", false)))
	assert_true(bool(run._current_shop_offers[equipment_index].get("sold", false)))
	assert_true(bool(run._current_shop_offers[mercenary_index].get("sold", false)))
	assert_gte(run.passives.size(), passives_before)
	assert_eq(run.mercenaries.size(), 1)
	assert_eq(run.battlefield.allies.size(), 1)
	run._on_shop_closed()
	assert_false(run._shop_open)
	assert_false(run._paused)
	assert_gt(run._next_shop_time, run.elapsed)


func test_shop_rejects_purchase_without_coin_and_enforces_mercenary_cap() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	await wait_process_frames(2)
	run.run_coin = 0
	run._open_shop()
	run._on_shop_buy(0)
	assert_eq(run.run_coin, 0)
	assert_false(bool(run._current_shop_offers[0].get("sold", true)))
	run._on_shop_closed()

	run.run_coin = 9999
	assert_true(run._hire_mercenary("yishi_spear"))
	assert_true(run._hire_mercenary("yishi_archer"))
	assert_true(run._hire_mercenary("tengpai_militia"))
	assert_false(run._hire_mercenary("bird_gunner"))
	assert_eq(run.mercenaries.size(), 3)
	assert_eq(run.battlefield.allies.size(), 3)


func test_mercenary_ai_attacks_nearby_enemies() -> void:
	var field := Battlefield.new()
	add_child_autofree(field)
	field.setup(42)
	assert_true(field.spawn_ally("yishi_spear", Vector2(40, 0)))
	var enemy_index := field.spawn_enemy_at("scout", Vector2(100, 0))
	assert_gte(enemy_index, 0)
	field.update_world(0.8, {
		"pos": Vector2.ZERO,
		"radius": 18.0,
		"pickup_radius": 0.0,
	}, 0.0)
	assert_eq(field.alive_count(), 0, "a spear ally must damage the nearby scout")


func test_shop_opens_after_interval_only_when_not_upgrading() -> void:
	var run := (load("res://scenes/run.tscn") as PackedScene).instantiate()
	add_child_autofree(run)
	await wait_process_frames(3)
	run.story._skip_all()
	await wait_process_frames(2)
	run.elapsed = run._next_shop_time
	run._pending_levels = 1
	run._maybe_open_shop()
	assert_false(run._shop_open, "levelling must take priority over the shop")
	run._pending_levels = 0
	run._maybe_open_shop()
	assert_true(run._shop_open)
	assert_true(run._paused)
	run._on_shop_closed()


func _find_family(offers: Array[Dictionary], families: Array) -> int:
	for i in range(offers.size()):
		if families.has(str(offers[i].get("family", ""))):
			return i
	return -1
