class_name FeedbackConfig
extends Resource
## 打击反馈的全部可调参数。策划可在 Inspector 调整，或另存为 .tres。
## 修改后调用 FeedbackManager.reload_config() 生效（池容量变更会重建池）。

@export var enabled: bool = true

@export_group("1 受击闪白")
@export var flash_enabled: bool = true
@export_range(0.02, 0.30, 0.005) var flash_duration: float = 0.09
@export_range(0.02, 0.30, 0.005) var flash_heavy_duration: float = 0.14
@export var flash_color: Color = Color(1.8, 1.8, 1.8, 1.0)

@export_group("2 伤害数字")
@export var number_enabled: bool = true
@export_range(8, 200, 1) var number_max: int = 70
@export_range(0.2, 2.0, 0.05) var number_lifetime: float = 0.72
@export_range(10.0, 120.0, 1.0) var number_rise_speed: float = 34.0
@export_range(8, 40, 1) var number_font_size: int = 15
@export_range(8, 60, 1) var number_crit_font_size: int = 22
@export var number_crit_color: Color = Color("#e1b35a")
@export_range(0, 100, 1) var number_show_chance: int = 30

@export_group("3 音效池")
@export var sfx_enabled: bool = true
@export_range(1, 24, 1) var sfx_hit_voices: int = 8
@export_range(1, 16, 1) var sfx_thud_voices: int = 4
@export_range(0.0, 0.30, 0.01) var sfx_pitch_jitter: float = 0.12
@export_range(0.0, 1.0, 0.01) var sfx_hit_volume: float = 0.55
@export_range(0.0, 1.0, 0.01) var sfx_thud_volume: float = 0.42

@export_group("4 击退")
@export var knockback_enabled: bool = true
@export_range(0.0, 3.0, 0.05) var knockback_light_scale: float = 1.0
@export_range(0.0, 3.0, 0.05) var knockback_heavy_scale: float = 1.15

@export_group("5 粒子火花")
@export var spark_enabled: bool = true
@export_range(16, 512, 8) var spark_max: int = 160
@export_range(0, 16, 1) var spark_per_hit: int = 5
@export_range(1, 16, 1) var spark_heavy_per_hit: int = 10
@export_range(0.05, 0.60, 0.01) var spark_lifetime: float = 0.22
@export_range(40.0, 600.0, 10.0) var spark_speed: float = 180.0
@export_range(0.0, PI, 0.05) var spark_spread: float = 0.9
@export var spark_color: Color = Color("#e1b35a")

@export_group("6 相机震动 Trauma")
@export var shake_enabled: bool = true
@export_range(0.0, 0.30, 0.005) var shake_light_trauma: float = 0.035
@export_range(0.0, 0.60, 0.005) var shake_heavy_trauma: float = 0.16
@export_range(0.5, 6.0, 0.1) var shake_decay: float = 1.8
@export_range(0.0, 24.0, 0.5) var shake_offset_max: float = 8.0
@export_range(1.0, 60.0, 1.0) var shake_noise_frequency: float = 18.0

@export_group("7 Hitstop 默认关闭")
@export var hitstop_enabled: bool = false
@export_range(0.0, 0.03, 0.001) var hitstop_heavy_duration: float = 0.0
@export_range(0.0, 0.03, 0.001) var hitstop_boss_duration: float = 0.018

@export_group("8 冲击环与镜头微缩")
@export var pop_enabled: bool = true
@export var pop_color: Color = Color(0.95, 0.78, 0.42, 0.72)
@export var zoom_enabled: bool = true
@export_range(1.0, 1.15, 0.01) var zoom_heavy_amount: float = 1.04
@export_range(2.0, 24.0, 0.5) var zoom_recovery_speed: float = 10.0

var shake_strength: float = 1.0
