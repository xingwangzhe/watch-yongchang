extends GutTest


func test_weapon_icons_use_the_registered_game_icons_set() -> void:
	var weapons := GameData.get_weapons()
	var expected := {
		"saber": "wpn_saber.svg",
		"spear": "card_spears.svg",
		"bow": "card_pocket_bow.svg",
		"musket": "wpn_musket.svg",
		"cannon": "wpn_cannon.svg",
		"banner": "card_tower_flag.svg",
	}
	for weapon_id in expected:
		var definition: Dictionary = weapons[weapon_id] as Dictionary
		var icon_path := str(definition.get("icon", ""))
		assert_true(icon_path.begins_with("res://assets/icons/game_icons/"))
		assert_eq(icon_path.get_file(), str(expected[weapon_id]))
		assert_not_null(load(icon_path) as Texture2D, "%s icon must load" % weapon_id)
		assert_false(definition.has("icon_source"), "runtime weapons must not point to generated icon crops")
