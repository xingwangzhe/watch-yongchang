class_name InputSetup
extends RefCounted


static func ensure_defaults() -> void:
	_ensure("move_left", [KEY_A, KEY_LEFT])
	_ensure("move_right", [KEY_D, KEY_RIGHT])
	_ensure("move_up", [KEY_W, KEY_UP])
	_ensure("move_down", [KEY_S, KEY_DOWN])
	_ensure("dash", [KEY_SPACE])
	_ensure("interact", [KEY_E, KEY_ENTER])
	_ensure("toggle_codex", [KEY_C])


static func _ensure(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
