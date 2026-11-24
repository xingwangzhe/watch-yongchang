class_name ShopCatalog
extends RefCounted

const MAX_WEAPONS := 6
const MAX_WEAPON_LEVEL := 5

static var _shop_data: Dictionary = {}


static func data() -> Dictionary:
	if _shop_data.is_empty():
		_shop_data = GameData.get_shop()
	return _shop_data


static func build_offers(
	weapons: Array,
	passives: Dictionary,
	mercenaries: Array[String],
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var weapon_pool := _weapon_pool(weapons)
	var equipment_pool := _equipment_pool(passives)
	var mercenary_pool := _mercenary_pool(mercenaries)
	var offers: Array[Dictionary] = []

	_take_random(offers, weapon_pool, rng)
	_take_random(offers, equipment_pool, rng)
	if not mercenary_pool.is_empty() and mercenaries.size() < int(data().get("max_mercenaries", 3)):
		_take_random(offers, mercenary_pool, rng)
	else:
		_take_random(offers, equipment_pool, rng)
		if offers.size() < 2:
			_take_random(offers, weapon_pool, rng)

	var leftovers: Array[Dictionary] = []
	leftovers.append_array(weapon_pool)
	leftovers.append_array(equipment_pool)
	leftovers.append_array(mercenary_pool)
	while offers.size() < int(data().get("max_offers", 3)) and not leftovers.is_empty():
		_take_random(offers, leftovers, rng)
	while offers.size() < int(data().get("max_offers", 3)):
		offers.append(_supply_offer("supply_heal" if offers.size() % 2 == 0 else "supply_oil"))
	return offers


static func _weapon_pool(weapons: Array) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var definitions := GameData.get_weapons()
	var prices: Dictionary = data().get("weapon_prices", {}) as Dictionary
	for weapon_id in definitions.keys():
		var definition: Dictionary = definitions[weapon_id] as Dictionary
		var current := _weapon_level(weapons, str(weapon_id))
		if current >= MAX_WEAPON_LEVEL:
			continue
		if current == 0 and weapons.size() >= MAX_WEAPONS:
			continue
		var price_data: Dictionary = prices.get(weapon_id, {}) as Dictionary
		var price := 0
		var family := "weapon_new"
		var level := 1
		if current == 0:
			price = int(price_data.get("new", 70))
		else:
			family = "weapon_upgrade"
			level = current + 1
			price = int(price_data.get("upgrade", 55)) + maxi(0, current - 1) * 8
		var rarity := _price_rarity(price)
		var prefix := Locale.t("shop.kind.weapon_new" if current == 0 else "shop.kind.weapon_upgrade")
		pool.append({
			"family": family,
			"option_id": str(weapon_id),
			"weapon_id": str(weapon_id),
			"level": level,
			"max_level": MAX_WEAPON_LEVEL,
			"title": GameData.loc(definition, "name"),
			"description": "%s\n%s" % [prefix, GameData.loc(definition, "description")],
			"culture": GameData.loc(definition, "culture"),
			"effect_summary": GameData.loc(definition, "description"),
			"kind_label": Locale.t("shop.kind.weapon"),
			"rarity": rarity,
			"rarity_label": UpgradeCatalog.rarity_label(rarity),
			"category": str((data().get("category_by_kind", {}) as Dictionary).get("weapon", "制度")),
			"source_ref": str(data().get("source_ref", "design/游戏设计文档-GDD.md")),
			"icon": str(definition.get("icon", "")),
			"price": price,
			"sold": false,
		})
	return pool


static func _equipment_pool(passives: Dictionary) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var definitions := GameData.get_passives()
	var prices: Dictionary = data().get("equipment_prices", {}) as Dictionary
	for passive_id in definitions.keys():
		var definition: Dictionary = definitions[passive_id] as Dictionary
		var current := int(passives.get(passive_id, 0))
		var max_level := int(definition.get("max_level", 5))
		if current >= max_level:
			continue
		var family := "equipment_new" if current == 0 else "equipment_upgrade"
		var level := current + 1
		var price := int(prices.get(passive_id, 50)) + current * 10
		var rarity := "legendary" if passive_id == "family_letter" else _price_rarity(price)
		var effect := UpgradeCatalog.format_effect(
			str(definition.get("stat", "")),
			float(definition.get("amount", 0.0))
		)
		if effect.is_empty():
			effect = GameData.loc(definition, "description")
		pool.append({
			"family": family,
			"option_id": str(passive_id),
			"passive_id": str(passive_id),
			"level": level,
			"max_level": max_level,
			"title": GameData.loc(definition, "name"),
			"description": "%s\n%s" % [
				Locale.t("shop.kind.equipment_new" if current == 0 else "shop.kind.equipment_upgrade"),
				GameData.loc(definition, "description"),
			],
			"culture": GameData.loc(definition, "culture"),
			"effect_summary": effect,
			"kind_label": Locale.t("shop.kind.equipment"),
			"rarity": rarity,
			"rarity_label": UpgradeCatalog.rarity_label(rarity),
			"category": str((data().get("category_by_kind", {}) as Dictionary).get("equipment", "民俗")),
			"source_ref": str(data().get("source_ref", "design/游戏设计文档-GDD.md")),
			"icon": str(definition.get("icon", "")),
			"price": price,
			"sold": false,
		})
	return pool


static func _mercenary_pool(mercenaries: Array[String]) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var definitions := GameData.get_mercenaries()
	for mercenary_id in definitions.keys():
		if mercenaries.has(str(mercenary_id)):
			continue
		var definition: Dictionary = definitions[mercenary_id] as Dictionary
		var rarity := str(definition.get("rarity", "uncommon"))
		var role := GameData.loc(definition, "role")
		var note := GameData.loc(definition, "shop_note")
		pool.append({
			"family": "mercenary",
			"option_id": str(mercenary_id),
			"mercenary_id": str(mercenary_id),
			"level": 1,
			"max_level": 1,
			"title": GameData.loc(definition, "name"),
			"description": "%s · %s\n%s" % [
				role,
				Locale.t("shop.kind.mercenary"),
				GameData.loc(definition, "description"),
			],
			"culture": GameData.loc(definition, "culture"),
			"effect_summary": note if not note.is_empty() else role,
			"kind_label": Locale.t("shop.kind.mercenary"),
			"rarity": rarity,
			"rarity_label": UpgradeCatalog.rarity_label(rarity),
			"category": str(definition.get("category", "演绎")),
			"source_ref": str(definition.get("source_ref", "")),
			"icon": str(definition.get("icon", "")),
			"price": int(definition.get("price", 90)),
			"sold": false,
		})
	return pool


static func _supply_offer(supply_id: String) -> Dictionary:
	var heal := supply_id == "supply_heal"
	return {
		"family": supply_id,
		"option_id": supply_id,
		"supply_id": supply_id,
		"level": 1,
		"max_level": 1,
		"title": Locale.t("shop.supply_heal" if heal else "shop.supply_oil"),
		"description": Locale.t("shop.supply_heal_desc" if heal else "shop.supply_oil_desc"),
		"culture": Locale.t("shop.supply_culture"),
		"effect_summary": Locale.t("shop.supply_heal_effect" if heal else "shop.supply_oil_effect"),
		"kind_label": Locale.t("shop.kind.supply"),
		"rarity": "common",
		"rarity_label": UpgradeCatalog.rarity_label("common"),
		"category": "民俗",
		"source_ref": str(data().get("source_ref", "design/游戏设计文档-GDD.md")),
		"icon": "res://assets/icons/game_icons/ui_lantern.svg",
		"price": 35 if heal else 28,
		"sold": false,
	}


static func _take_random(
	target: Array[Dictionary],
	pool: Array[Dictionary],
	rng: RandomNumberGenerator
) -> void:
	if pool.is_empty():
		return
	var index := rng.randi_range(0, pool.size() - 1)
	target.append(pool[index])
	pool.remove_at(index)


static func _weapon_level(weapons: Array, weapon_id: String) -> int:
	for weapon in weapons:
		if weapon is Dictionary and str((weapon as Dictionary).get("id", "")) == weapon_id:
			return int((weapon as Dictionary).get("level", 1))
	return 0


static func _price_rarity(price: int) -> String:
	if price >= 140:
		return "legendary"
	if price >= 92:
		return "rare"
	if price >= 70:
		return "uncommon"
	return "common"
