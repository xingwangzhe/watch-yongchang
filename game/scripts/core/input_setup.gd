class_name InputSetup
extends RefCounted

## 可改键的动作清单。键位默认值只在这里定义，设置页读同一份数据。
const BINDABLE := {
	"move_left": {"keys": [KEY_A, KEY_LEFT], "mouse": []},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "mouse": []},
	"move_up": {"keys": [KEY_W, KEY_UP], "mouse": []},
	"move_down": {"keys": [KEY_S, KEY_DOWN], "mouse": []},
	"dash": {"keys": [KEY_SPACE], "mouse": []},
	"interact": {"keys": [KEY_E, KEY_ENTER], "mouse": []},
	"attack": {"keys": [], "mouse": [MOUSE_BUTTON_LEFT]},
	"toggle_codex": {"keys": [KEY_C], "mouse": []},
	"toggle_auto_attack": {"keys": [KEY_X], "mouse": []},
}
const ORDER := [
	"move_left", "move_right", "move_up", "move_down",
	"dash", "interact", "attack", "toggle_codex", "toggle_auto_attack",
]


static func ensure_defaults() -> void:
	for action in ORDER:
		_ensure_default_events(action)


static func _ensure_default_events(action: String) -> void:
	var meta: Dictionary = BINDABLE[action]
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in meta["keys"] as Array:
		var event := InputEventKey.new()
		event.physical_keycode = int(key)
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
	for button in meta["mouse"] as Array:
		var event := InputEventMouseButton.new()
		event.button_index = int(button)
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


## 用存档里的 "k:65" / "m:1" token 覆盖按键；缺项或坏项回退默认。
static func apply_bindings(bindings: Dictionary) -> void:
	ensure_defaults()
	for action in ORDER:
		var tokens: Array = bindings.get(action, []) as Array
		if tokens.is_empty():
			continue
		var events := _events_from_tokens(tokens)
		if events.is_empty():
			continue
		InputMap.action_erase_events(action)
		for event in events:
			InputMap.action_add_event(action, event)


static func _events_from_tokens(tokens: Array) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for raw in tokens:
		var token := str(raw)
		if token.begins_with("k:"):
			var key := int(token.substr(2))
			if key <= 0:
				continue
			var event := InputEventKey.new()
			event.physical_keycode = key
			events.append(event)
		elif token.begins_with("m:"):
			var button := int(token.substr(2))
			if button <= 0:
				continue
			var event := InputEventMouseButton.new()
			event.button_index = button
			events.append(event)
	return events


## 把一个输入事件序列化成 token；不支持的设备返回空串。
static func token_from_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code := int(key_event.physical_keycode)
		if code <= 0:
			code = int(key_event.keycode)
		if code <= 0:
			return ""
		return "k:%d" % code
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		return "m:%d" % button_event.button_index
	return ""


## 清空全部自定义键位并恢复默认。
static func reset_to_defaults() -> void:
	for action in ORDER:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		_ensure_default_events(action)


static func describe(action: String) -> String:
	var parts: Array[String] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			var code := int(key_event.physical_keycode)
			if code <= 0:
				code = int(key_event.keycode)
			if code > 0:
				parts.append(OS.get_keycode_string(code))
		elif event is InputEventMouseButton:
			parts.append(mouse_name((event as InputEventMouseButton).button_index))
	if parts.is_empty():
		return "—"
	return " / ".join(parts)


static func mouse_name(button: int) -> String:
	match button:
		MOUSE_BUTTON_LEFT:
			return Locale.t("input.mouse_left")
		MOUSE_BUTTON_RIGHT:
			return Locale.t("input.mouse_right")
		MOUSE_BUTTON_MIDDLE:
			return Locale.t("input.mouse_middle")
		_:
			return Locale.t("input.mouse_other", {"index": button})


## 返回已占用同一 token 的其它动作 id；没有冲突返回空串。
static func conflict_for(action: String, token: String) -> String:
	for other in ORDER:
		if other == action:
			continue
		for existing in tokens_for(other):
			if existing == token:
				return other
	return ""


static func tokens_for(action: String) -> Array[String]:
	var tokens: Array[String] = []
	for event in InputMap.action_get_events(action):
		var token := token_from_event(event)
		if not token.is_empty():
			tokens.append(token)
	return tokens
