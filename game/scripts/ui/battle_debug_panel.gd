extends CanvasLayer
## 可单独启停的战斗诊断面板，仅在 Debug 构建可见。

@onready var _panel: Control = $Panel
@onready var _frame: Label = $Panel/Rows/Frame
@onready var _simulation: Label = $Panel/Rows/Simulation
@onready var _work: Label = $Panel/Rows/Work
@onready var _render: Label = $Panel/Rows/Render


func _ready() -> void:
	_panel.visible = OS.is_debug_build()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_F3:
		return
	_panel.visible = not _panel.visible
	get_viewport().set_input_as_handled()


func update_metrics(metrics: Dictionary) -> void:
	if not OS.is_debug_build():
		return
	_frame.text = "FPS %d | frame %.2f ms" % [int(metrics.get("fps", 0)), float(metrics.get("frame_ms", 0.0))]
	_simulation.text = "steps %d/%d | enemies %d" % [int(metrics.get("steps", 0)), int(metrics.get("max_steps", 0)), int(metrics.get("enemies", 0))]
	_work.text = "world %.2f ms | flow %.2f ms | HUD %.2f ms" % [float(metrics.get("world_ms", 0.0)), float(metrics.get("flow_ms", 0.0)), float(metrics.get("hud_ms", 0.0))]
	_render.text = "draw %d | objects %d | elapsed %.1f s" % [int(metrics.get("draw_calls", 0)), int(metrics.get("objects", 0)), float(metrics.get("elapsed", 0.0))]
