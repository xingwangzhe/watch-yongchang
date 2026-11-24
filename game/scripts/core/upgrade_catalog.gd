class_name UpgradeCatalog
extends RefCounted

const DATA_PATH := "res://data/upgrades.json"
const FAMILY_COLORS := {
	"weapon_upgrade": Color("#d8a548"),
	"weapon_new": Color("#d8a548"),
	"equipment_new": Color("#7fb7a8"),
	"equipment_upgrade": Color("#7fb7a8"),
	"mercenary": Color("#d9a95f"),
	"supply_heal": Color("#9bc27e"),
	"supply_oil": Color("#d8b45f"),
	"evolve": Color("#f0c363"),
	"passive_new": Color("#7fb7a8"),
	"passive_upgrade": Color("#7fb7a8"),
	"attribute": Color("#79a9bf"),
	"skill": Color("#c05a41"),
	"event": Color("#9b7fbf"),
	"tower": Color("#c9a04e"),
	"supply": Color("#baa98a"),
}
const RARITY_WEIGHT := {
	"common": 10.0,
	"uncommon": 6.0,
	"rare": 3.0,
	"legendary": 1.0,
}
const RARITY_LABEL := {
	"common": "寻常",
	"uncommon": "精良",
	"rare": "珍稀",
	"legendary": "传世",
}
const RARITY_LABEL_EN := {
	"common": "Common",
	"uncommon": "Uncommon",
	"rare": "Rare",
	"legendary": "Legendary",
}
const STAT_PERCENT := [
	"damage_mult", "speed_mult", "pickup_mult", "area_mult", "xp_mult",
	"max_hp_mult", "projectile_speed_mult", "gold_mult", "light_mult",
	"cooldown_mult", "dash_cd_mult", "knockback_mult", "armor", "crit",
	"dodge", "luck", "wade_speed",
]
const STAT_FLAT := [
	"max_hp_flat", "shield_max", "shield_regen", "regen", "revive",
	"oil_max", "thorns", "lifesteal", "execute_below",
]
const STAT_INT := [
	"revive", "oil_max", "tower_pierce", "tower_volley", "tower_burst_shots",
	"tower_burst_lanes", "tower_chain", "tower_count", "tower_tier",
]
const EVENT_STATS := [
	"event_hp_pct", "event_merit", "event_oil", "event_full_heal",
	"event_spawn_elite", "event_spawn_wave", "event_enemy_speed",
]

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(DATA_PATH)
	return _cache


static func family_data(family: String) -> Dictionary:
	return data().get(family, {}) as Dictionary


static func all_cards() -> Dictionary:
	var cards: Dictionary = {}
	for family in ["attributes", "skills", "events", "towers"]:
		for card_id in family_data(family).keys():
			var definition: Dictionary = family_data(family)[card_id] as Dictionary
			var copy := definition.duplicate(true)
			copy["family"] = family.trim_suffix("s")
			cards[str(card_id)] = copy
	return cards


static func total_card_count() -> int:
	return (
		family_data("attributes").size()
		+ family_data("skills").size()
		+ family_data("events").size()
		+ family_data("towers").size()
	)


static func total_offer_count() -> int:
	var total := 0
	for family in ["attributes", "skills", "events", "towers"]:
		for definition in family_data(family).values():
			total += int((definition as Dictionary).get("max_level", 1))
	return total


static func build_card_pool(
	card_levels: Dictionary,
	used_events: Dictionary,
	luck: float
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for family in ["attributes", "skills", "events", "towers"]:
		var family_name := str(family)
		var singular := family_name.trim_suffix("s")
		for card_id in family_data(family_name).keys():
			var definition: Dictionary = family_data(family_name)[card_id] as Dictionary
			var current := int(card_levels.get(card_id, 0))
			var max_level := int(definition.get("max_level", 1))
			if current >= max_level:
				continue
			if singular == "event" and used_events.has(card_id):
				continue
			pool.append(make_option(singular, str(card_id), definition, current + 1, luck))
	return pool


static func make_option(
	family: String,
	card_id: String,
	definition: Dictionary,
	level: int,
	luck: float = 0.0
) -> Dictionary:
	var rarity := str(definition.get("rarity", "common"))
	var weight := float(RARITY_WEIGHT.get(rarity, 10.0))
	var rarity_rank := float(
		{"common": 0.0, "uncommon": 1.0, "rare": 2.0, "legendary": 3.0}.get(rarity, 0.0)
	)
	weight *= 1.0 + maxf(0.0, luck) * rarity_rank * 0.55
	if family == "event":
		weight *= 0.62
	var kind_key := "upgrade.kind.%s" % family
	return {
		"family": family,
		"card_id": card_id,
		"level": level,
		"max_level": int(definition.get("max_level", 1)),
		"title": GameData.loc(definition, "name"),
		"description": GameData.loc(definition, "desc"),
		"culture": GameData.loc(definition, "culture"),
		"effect_summary": effect_summary(definition, level),
		"kind_label": Locale.t(kind_key),
		"rarity": rarity,
		"rarity_label": rarity_label(rarity),
		"category": str(definition.get("category", "演绎")),
		"source_ref": str(definition.get("source_ref", "")),
		"icon": str(definition.get("icon", "")),
		"weight": weight,
		"definition": definition,
	}


static func make_external_option(
	family: String,
	option_id: String,
	title: String,
	description: String,
	culture: String,
	icon: String,
	level: int,
	max_level: int,
	kind_label: String,
	rarity: String = "common",
	extra: Dictionary = {}
) -> Dictionary:
	var option := {
		"family": family,
		"card_id": option_id,
		"level": level,
		"max_level": max_level,
		"title": title,
		"description": description,
		"culture": culture,
		"effect_summary": "",
		"kind_label": kind_label,
		"rarity": rarity,
		"rarity_label": rarity_label(rarity),
		"category": "",
		"source_ref": "",
		"icon": icon,
		"weight": float(RARITY_WEIGHT.get(rarity, 10.0)),
	}
	for key in extra.keys():
		option[key] = extra[key]
	return option


static func rarity_label(rarity: String) -> String:
	if Locale.current == "en":
		return str(RARITY_LABEL_EN.get(rarity, RARITY_LABEL_EN["common"]))
	return str(RARITY_LABEL.get(rarity, RARITY_LABEL["common"]))


static func family_color(family: String) -> Color:
	return FAMILY_COLORS.get(family, Color("#baa98a")) as Color


static func effect_summary(definition: Dictionary, level: int) -> String:
	var parts: Array[String] = []
	for effect in definition.get("effects", []) as Array:
		if not effect is Dictionary:
			continue
		var stat := str((effect as Dictionary).get("stat", ""))
		var amount := float((effect as Dictionary).get("amount", 0.0)) * float(level)
		var text := format_effect(stat, amount)
		if not text.is_empty():
			parts.append(text)
	return " · ".join(parts)


static func format_effect(stat: String, amount: float) -> String:
	if stat.begins_with("skill_"):
		return Locale.t("skill.%s" % stat.trim_prefix("skill_"))
	if EVENT_STATS.has(stat):
		return _format_event(stat, amount)
	var label := Locale.t("stat.%s" % stat)
	if label == "stat.%s" % stat:
		return ""
	if STAT_PERCENT.has(stat):
		return "%s %+.0f%%" % [label, amount * 100.0]
	if STAT_INT.has(stat):
		return "%s %+d" % [label, int(round(amount))]
	if stat == "regen" or stat == "shield_regen":
		return "%s %+.2f/s" % [label, amount]
	return "%s %+.1f" % [label, amount]


static func _format_event(stat: String, amount: float) -> String:
	match stat:
		"event_hp_pct":
			return Locale.t("event.hp", {"value": "%+.0f%%" % (amount * 100.0)})
		"event_merit":
			return Locale.t("event.merit", {"value": "%+.0f" % amount})
		"event_oil":
			return Locale.t("event.oil", {"value": "%+.0f" % amount})
		"event_full_heal":
			return Locale.t("event.full_heal")
		"event_spawn_elite":
			return Locale.t("event.spawn_elite", {"value": "%d" % int(amount)})
		"event_spawn_wave":
			return Locale.t("event.spawn_wave", {"value": "%d" % int(amount)})
		"event_enemy_speed":
			return Locale.t("event.enemy_speed", {"value": "%+.0f%%" % (amount * 100.0)})
	return ""


static func pick_three(pool: Array[Dictionary], rng: RandomNumberGenerator) -> Array[Dictionary]:
	if pool.size() <= 3:
		return pool.duplicate()
	var remaining := pool.duplicate()
	var picked: Array[Dictionary] = []
	_pick_from_families(remaining, picked, rng, [
		"weapon_upgrade", "weapon_new", "evolve", "attribute", "skill", "passive_new", "passive_upgrade",
	])
	_pick_from_families(remaining, picked, rng, ["tower"])
	_pick_from_families(remaining, picked, rng, ["attribute", "skill", "tower", "passive_new", "passive_upgrade", "event"])
	_pick_from_families(remaining, picked, rng, [
		"attribute", "skill", "tower", "event", "passive_new", "passive_upgrade", "weapon_upgrade", "supply",
	])
	while picked.size() < 3 and not remaining.is_empty():
		_pick_weighted(remaining, picked, rng)
	return picked


static func _pick_from_families(
	remaining: Array[Dictionary],
	picked: Array[Dictionary],
	rng: RandomNumberGenerator,
	families: Array
) -> void:
	if picked.size() >= 3:
		return
	var candidates: Array[Dictionary] = []
	for option in remaining:
		if families.has(str(option.get("family", ""))):
			candidates.append(option)
	if candidates.is_empty():
		return
	_pick_weighted(candidates, picked, rng)
	var chosen_id := str(picked.back().get("card_id", ""))
	for i in range(remaining.size() - 1, -1, -1):
		if str(remaining[i].get("card_id", "")) == chosen_id:
			remaining.remove_at(i)
			break


static func _pick_weighted(
	candidates: Array[Dictionary],
	picked: Array[Dictionary],
	rng: RandomNumberGenerator
) -> void:
	var total := 0.0
	for option in candidates:
		total += maxf(0.01, float(option.get("weight", 1.0)))
	var roll := rng.randf_range(0.0, total)
	var current := 0.0
	for option in candidates:
		current += maxf(0.01, float(option.get("weight", 1.0)))
		if roll <= current:
			picked.append(option)
			return
	picked.append(candidates.back())
