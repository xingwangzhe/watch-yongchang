extends CanvasLayer
## HUD：资源条、波次提示、文化事件横幅、终局面板与重开。

@onready var title_label: Label = $TopBar/TopMargin/TopRow/TitleLabel
@onready var wave_label: Label = $TopBar/TopMargin/TopRow/WaveLabel
@onready var grain_label: Label = $TopBar/TopMargin/TopRow/GrainLabel
@onready var silver_label: Label = $TopBar/TopMargin/TopRow/SilverLabel
@onready var ammo_label: Label = $TopBar/TopMargin/TopRow/AmmoLabel
@onready var keep_label: Label = $TopBar/TopMargin/TopRow/KeepLabel
@onready var wave_toast: Label = $WaveToast
@onready var event_banner: PanelContainer = $EventBanner
@onready var banner_text: Label = $EventBanner/BannerMargin/BannerText
@onready var end_panel: PanelContainer = $EndPanel
@onready var end_title: Label = $EndPanel/EndMargin/EndVBox/EndTitle
@onready var end_summary: Label = $EndPanel/EndMargin/EndVBox/EndSummary
@onready var restart_button: Button = $EndPanel/EndMargin/EndVBox/RestartButton

var _banner_tween: Tween

func _ready() -> void:
	var font := load("res://assets/fonts/LXGWWenKai-Regular.ttf") as Font
	for node in [title_label, wave_label, grain_label, silver_label, ammo_label,
			keep_label, wave_toast, banner_text, end_title, end_summary, restart_button]:
		if node != null:
			node.add_theme_font_override("font", font)
	event_banner.visible = false
	end_panel.visible = false
	restart_button.pressed.connect(func(): get_tree().reload_current_scene())
	EventBus.wave_started.connect(_on_wave)
	EventBus.culture_event.connect(_on_culture)
	EventBus.result_decided.connect(_on_result)

func update_stats(grain: int, silver: int, ammo: int, keep: int, wave: int) -> void:
	wave_label.text = "波次 %d/3" % wave
	grain_label.text = "粮 %d" % grain
	silver_label.text = "银 %d" % silver
	ammo_label.text = "弹 %d" % ammo
	keep_label.text = "主堡 %d" % keep
	if wave > 0:
		wave_toast.text = "第 %d 波来袭" % wave
		wave_toast.visible = true

func _on_wave(wave: int, _count: int) -> void:
	wave_toast.text = "第 %d 波来袭" % wave
	wave_toast.visible = true

func _on_culture(_card: StringName, desc: String) -> void:
	banner_text.text = desc
	event_banner.visible = true
	event_banner.modulate.a = 0.0
	if _banner_tween != null and _banner_tween.is_running():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(event_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(2.5)
	_banner_tween.tween_property(event_banner, "modulate:a", 0.0, 0.35)
	_banner_tween.tween_callback(func(): event_banner.visible = false)

func _on_result(win: bool, _reason: String) -> void:
	end_title.text = "守住永昌" if win else "永昌失守"
	end_summary.text = "波次 %d/3" % GameState.wave_index
	end_panel.visible = true
	restart_button.grab_focus()
