extends Control

const BACKDROP := preload("res://assets/ui/menu_backdrop.png")
const CLOUDS := preload("res://assets/ui/menu_clouds.png")
const WAVES := preload("res://assets/ui/menu_waves.png")
const BOAT := preload("res://assets/ui/menu_boat.png")
const BEACON := preload("res://assets/ui/menu_beacon.png")

const MOON_CENTER := Vector2(618.0, 132.0)
const BOAT_POSITIONS := [
	Vector2(92.0, 430.0),
	Vector2(142.0, 492.0),
	Vector2(1250.0, 460.0),
]
const BEACON_POSITION := Vector2(1172.0, 260.0)
const LANTERN_GLOWS := [
	Vector2(166.0, 461.0),
	Vector2(1084.0, 462.0),
	Vector2(930.0, 544.0),
	Vector2(322.0, 551.0),
	Vector2(1180.0, 335.0),
]

var _time := 0.0
var _stars: Array[Vector3] = []
var _embers: Array[Vector4] = []
var _mist: Array[Vector4] = []
var _moon_shimmer: Array[Vector4] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 1558
	for index in 42:
		_stars.append(Vector3(
			rng.randf_range(12.0, 1268.0),
			rng.randf_range(18.0, 312.0),
			rng.randf_range(0.0, TAU)
		))
	for index in 28:
		_embers.append(Vector4(
			rng.randf_range(36.0, 1244.0),
			rng.randf_range(330.0, 690.0),
			rng.randf_range(0.45, 1.25),
			rng.randf_range(0.0, TAU)
		))
	for index in 18:
		_mist.append(Vector4(
			rng.randf_range(-80.0, 1280.0),
			rng.randf_range(492.0, 650.0),
			rng.randf_range(0.45, 1.3),
			rng.randf_range(0.0, TAU)
		))
	for index in 34:
		var y := rng.randf_range(382.0, 594.0)
		var spread := 12.0 + (y - 382.0) * 0.16
		_moon_shimmer.append(Vector4(
			rng.randf_range(-spread, spread),
			y,
			rng.randf_range(5.0, 22.0),
			rng.randf_range(0.0, TAU)
		))
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := maxf(size.x, 1280.0)
	var h := maxf(size.y, 720.0)
	var drift := Vector2(sin(_time * 0.035) * 5.0, cos(_time * 0.025) * 2.5)
	draw_texture_rect(BACKDROP, Rect2(-8.0 + drift.x, -5.0 + drift.y, w + 16.0, h + 10.0), false)
	_draw_clouds(drift)
	_draw_waves(drift)
	_draw_moon_shimmer(drift)
	_draw_boats(drift)
	_draw_beacon(drift)
	_draw_moon_haze(drift)
	_draw_twinkle(drift)
	_draw_lantern_flicker(drift)
	_draw_mist(w)
	_draw_embers()
	_draw_edge_shade(w, h)


func _draw_clouds(drift: Vector2) -> void:
	var scroll := fmod(_time * 7.5, 1280.0)
	var y := drift.y
	draw_texture_rect(CLOUDS, Rect2(-scroll + drift.x, y, 1280.0, 360.0), false)
	draw_texture_rect(CLOUDS, Rect2(1280.0 - scroll + drift.x, y, 1280.0, 360.0), false)


func _draw_waves(drift: Vector2) -> void:
	var scroll := fmod(_time * 18.0, 1280.0)
	var y := 368.0 + sin(_time * 0.42) * 2.0 + drift.y
	draw_texture_rect(WAVES, Rect2(-scroll + drift.x, y, 1280.0, 240.0), false)
	draw_texture_rect(WAVES, Rect2(1280.0 - scroll + drift.x, y, 1280.0, 240.0), false)


func _draw_moon_shimmer(drift: Vector2) -> void:
	for index in _moon_shimmer.size():
		var shimmer: Vector4 = _moon_shimmer[index]
		var pulse := 0.5 + 0.5 * sin(_time * 2.1 + shimmer.w)
		var x := MOON_CENTER.x + drift.x + shimmer.x + sin(_time * 0.7 + shimmer.w) * 4.0
		var alpha := 0.035 + pulse * 0.13
		draw_rect(
			Rect2(x, shimmer.y + drift.y, shimmer.z, 2.0),
			Color(0.95, 0.83, 0.57, alpha)
		)


func _draw_boats(drift: Vector2) -> void:
	for index in BOAT_POSITIONS.size():
		var anchor: Vector2 = BOAT_POSITIONS[index]
		var bob := sin(_time * 0.9 + float(index) * 1.7) * 2.2
		draw_texture_rect(
			BOAT,
			Rect2(anchor.x - 48.0 + drift.x, anchor.y - 68.0 + bob + drift.y, 96.0, 96.0),
			false
		)


func _draw_beacon(drift: Vector2) -> void:
	var frame := int(_time * 9.0) % 6
	var source := Rect2(float(frame) * 96.0, 0.0, 96.0, 96.0)
	draw_texture_rect_region(
		BEACON,
		Rect2(BEACON_POSITION + drift, Vector2(96.0, 96.0)),
		source
	)


func _draw_moon_haze(drift: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 0.32)
	var center := MOON_CENTER + drift
	for step in 5:
		var radius := 70.0 + float(step) * 13.0 + pulse * 2.0
		draw_circle(center, radius, Color(0.96, 0.84, 0.60, 0.008 + float(step) * 0.003))


func _draw_twinkle(drift: Vector2) -> void:
	for star in _stars:
		var pulse := 0.5 + 0.5 * sin(_time * 0.9 + star.z)
		var alpha := 0.04 + pulse * 0.22
		draw_circle(Vector2(star.x, star.y) + drift, 0.8 + pulse * 0.6, Color(0.93, 0.88, 0.72, alpha))


func _draw_lantern_flicker(drift: Vector2) -> void:
	for index in LANTERN_GLOWS.size():
		var center: Vector2 = LANTERN_GLOWS[index] + drift
		var flicker := 0.82 + 0.18 * sin(_time * 3.7 + float(index) * 1.7)
		draw_circle(center, 28.0 * flicker, Color(0.96, 0.55, 0.20, 0.025))
		draw_circle(center, 12.0 * flicker, Color(0.98, 0.67, 0.26, 0.030))
	draw_circle(Vector2(1180.0, 335.0) + drift, 44.0 + sin(_time * 2.1) * 3.0, Color(0.94, 0.46, 0.16, 0.018))


func _draw_mist(w: float) -> void:
	for puff in _mist:
		var x := fmod(puff.x + _time * 5.5 * puff.z + w + 120.0, w + 160.0) - 80.0
		var y := puff.y + sin(_time * 0.24 + puff.w) * 4.0
		var width := 74.0 + puff.z * 58.0
		draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, width, Color(0.56, 0.70, 0.67, 0.012 + puff.z * 0.008))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_embers() -> void:
	for ember in _embers:
		var rise := fmod(_time * 15.0 * ember.z + ember.y, 410.0)
		var x := ember.x + sin(_time * 0.6 + ember.w) * 14.0
		var y := 690.0 - rise
		var alpha := 0.04 + 0.17 * (0.5 + 0.5 * sin(_time * 2.4 + ember.w))
		draw_circle(Vector2(x, y), 0.9 + ember.z * 0.65, Color(0.94, 0.57, 0.23, alpha))


func _draw_edge_shade(w: float, h: float) -> void:
	draw_rect(Rect2(0.0, 0.0, w, 30.0), Color(0.0, 0.0, 0.0, 0.10))
	draw_rect(Rect2(0.0, h - 26.0, w, 26.0), Color(0.0, 0.0, 0.0, 0.14))
	draw_rect(Rect2(0.0, 0.0, 12.0, h), Color(0.0, 0.0, 0.0, 0.10))
	draw_rect(Rect2(w - 12.0, 0.0, 12.0, h), Color(0.0, 0.0, 0.0, 0.10))
