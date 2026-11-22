extends Node
## 场景导航：集中管理主菜单/战斗/设置之间的切换，避免各界面硬编码路径。

const SCENE_MAIN_MENU: String = "res://scenes/main_menu.tscn"
const SCENE_BATTLE: String = "res://scenes/main.tscn"
const SCENE_SETTINGS: String = "res://scenes/settings.tscn"

var settings_return_scene: String = SCENE_MAIN_MENU

func goto_main_menu() -> void:
	_change(SCENE_MAIN_MENU)

func goto_battle() -> void:
	_change(SCENE_BATTLE)

func goto_settings(from_scene: String = SCENE_MAIN_MENU) -> void:
	settings_return_scene = from_scene
	_change(SCENE_SETTINGS)

func return_from_settings() -> void:
	_change(settings_return_scene)

func restart_battle() -> void:
	_change(SCENE_BATTLE)

func quit_game() -> void:
	get_tree().quit()

func _change(path: String) -> void:
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("[FLOW] scene change failed path=%s err=%d" % [path, err])
	else:
		print("[FLOW] -> %s" % path)

func get_debug_snapshot() -> Dictionary:
	return {
		"settings_return": settings_return_scene,
		"current_scene": get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "",
	}

const GDA_CALLABLE := ["get_debug_snapshot"]
