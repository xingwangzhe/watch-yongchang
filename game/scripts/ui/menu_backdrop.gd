extends Control

const SKY_TOP := Color("#050b12")
const SKY_MID := Color("#10212c")
const SKY_LOW := Color("#081116")
const MOON := Color("#f4e4bd")
const WALL := Color("#10191b")
const WALL_LIGHT := Color("#1a2628")
const GOLD := Color("#d8a548")
const LANTERN := Color("#e9893f")

var _time := 0.0
var _stars: Array[Vector3] = []
var _embers: Array[Vector4] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 1558
	for index in 54:
		_stars.append(Vector3(
			rng.randf_range(20.0, 1260.0),
			rng.randf_range(18.0, 360.0),
			rng.randf_range(0.0, TAU)
		))
	for index in 26:
		_embers.append(Vector4(
			rng.randf_range(24.0, 1256.0),
			rng.randf_range(280.0, 700.0),
			rng.randf_range(0.35, 1.15),
			rng.randf_range(0.0, TAU)
		))
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := maxf(size.x, 1280.0)
	var h := maxf(size.y, 720.0)
	_draw_sky(w, h)
	_draw_stars()
	_draw_moon()
	_draw_ridges(w, h)
	_draw_wall(w, h)
	_draw_tower()
	_draw_lantern(Vector2(52.0, 138.0), 1.0)
	_draw_embers()
	_draw_reeds(w, h)
	_draw_edge_shade(w, h)


func _draw_sky(w: float, h: float) -> void:
	var bands := 28
	for index in bands:
		var t := float(index) / float(bands - 1)
		draw_rect(Rect2(0.0, h * t, w, h / float(bands) + 1.0), _sky_color(t))


func _sky_color(t: float) -> Color:
	if t < 0.56:
		return SKY_TOP.lerp(SKY_MID, t / 0.56)
	return SKY_MID.lerp(SKY_LOW, (t - 0.56) / 0.44)


func _draw_stars() -> void:
	for star in _stars:
		var pulse := 0.5 + 0.5 * sin(_time * 1.15 + star.z)
		var alpha := 0.16 + pulse * 0.42
		draw_circle(Vector2(star.x, star.y), 1.0 + pulse * 0.8, Color(0.92, 0.88, 0.74, alpha))


func _draw_moon() -> void:
	var center := Vector2(696.0, 132.0)
	for step in 9:
		var radius := 132.0 - float(step) * 9.0
		draw_circle(center, radius, Color(MOON, 0.012 + float(step) * 0.004))
	draw_circle(center, 46.0, Color(MOON, 0.96))
	draw_circle(center, 46.0, Color(0.92, 0.82, 0.58, 0.12), false, 2.0, true)
	draw_circle(center + Vector2(-12.0, -8.0), 7.0, Color(0.72, 0.62, 0.45, 0.12))
	draw_circle(center + Vector2(14.0, 12.0), 4.5, Color(0.72, 0.62, 0.45, 0.10))
	draw_circle(center + Vector2(3.0, 25.0), 3.0, Color(0.72, 0.62, 0.45, 0.08))
	draw_rect(Rect2(570.0, 158.0, 250.0, 8.0), Color(0.03, 0.08, 0.11, 0.32))
	draw_rect(Rect2(620.0, 184.0, 190.0, 5.0), Color(0.03, 0.08, 0.11, 0.22))


func _draw_ridges(w: float, h: float) -> void:
	var far := PackedVector2Array([
		Vector2(-20.0, 520.0),
		Vector2(110.0, 408.0),
		Vector2(236.0, 462.0),
		Vector2(370.0, 356.0),
		Vector2(514.0, 450.0),
		Vector2(646.0, 392.0),
		Vector2(790.0, 472.0),
		Vector2(928.0, 408.0),
		Vector2(1082.0, 468.0),
		Vector2(1222.0, 392.0),
		Vector2(w + 20.0, 512.0),
		Vector2(w + 20.0, h),
		Vector2(-20.0, h),
	])
	draw_colored_polygon(far, Color(0.035, 0.075, 0.095))
	var near := PackedVector2Array([
		Vector2(-20.0, 566.0),
		Vector2(150.0, 486.0),
		Vector2(292.0, 532.0),
		Vector2(448.0, 468.0),
		Vector2(596.0, 540.0),
		Vector2(754.0, 478.0),
		Vector2(930.0, 548.0),
		Vector2(1100.0, 476.0),
		Vector2(1298.0, 542.0),
		Vector2(1298.0, h),
		Vector2(-20.0, h),
	])
	draw_colored_polygon(near, Color(0.028, 0.055, 0.065))


func _draw_wall(w: float, h: float) -> void:
	draw_rect(Rect2(0.0, 552.0, w, h - 552.0), WALL)
	for x in range(-16, int(w) + 64, 64):
		draw_rect(Rect2(float(x), 526.0, 38.0, 28.0), WALL_LIGHT)
	draw_rect(Rect2(0.0, 550.0, w, 2.0), Color(0.35, 0.25, 0.13, 0.22))
	for brick in range(0, 10):
		var y := 576.0 + float(brick) * 16.0
		draw_line(Vector2(0.0, y), Vector2(w, y), Color(0.10, 0.15, 0.16, 0.44), 1.0)
	for x in range(32, int(w), 96):
		draw_line(
			Vector2(float(x) + (float((x / 96) % 2) * 26.0), 552.0),
			Vector2(float(x) + (float((x / 96) % 2) * 26.0), h),
			Color(0.10, 0.15, 0.16, 0.24),
			1.0
		)
	draw_rect(Rect2(0.0, 700.0, w, h - 700.0), Color(0.025, 0.045, 0.048, 0.92))


func _draw_tower() -> void:
	draw_rect(Rect2(592.0, 438.0, 108.0, 114.0), Color("#141f21"))
	draw_rect(Rect2(584.0, 430.0, 124.0, 10.0), Color("#1e2b2d"))
	var roof := PackedVector2Array([
		Vector2(554.0, 434.0),
		Vector2(646.0, 372.0),
		Vector2(738.0, 434.0),
		Vector2(718.0, 440.0),
		Vector2(646.0, 394.0),
		Vector2(574.0, 440.0),
	])
	draw_colored_polygon(roof, Color("#101a1c"))
	draw_line(Vector2(554.0, 434.0), Vector2(738.0, 434.0), Color(0.62, 0.42, 0.18, 0.30), 2.0)
	draw_rect(Rect2(632.0, 474.0, 28.0, 38.0), Color(0.80, 0.45, 0.16, 0.20))
	draw_circle(Vector2(646.0, 493.0), 11.0, Color(0.96, 0.60, 0.24, 0.55))
	draw_circle(Vector2(646.0, 493.0), 34.0, Color(0.96, 0.55, 0.20, 0.035))
	draw_line(Vector2(646.0, 372.0), Vector2(646.0, 350.0), Color(0.45, 0.32, 0.18, 0.55), 2.0)
	draw_circle(Vector2(646.0, 348.0), 3.0, Color(0.88, 0.64, 0.28, 0.7))


func _draw_lantern(center: Vector2, scale: float) -> void:
	draw_line(Vector2(center.x, 0.0), Vector2(center.x, center.y - 42.0), Color(0.20, 0.16, 0.11, 0.85), 2.0)
	for step in 6:
		var radius := (54.0 - float(step) * 7.0) * scale
		draw_circle(center, radius, Color(LANTERN, 0.018 + float(step) * 0.010))
	draw_rect(Rect2(center.x - 14.0, center.y - 23.0, 28.0, 6.0), Color("#7d3b1d"))
	draw_circle(center, 20.0 * scale, Color("#d46f32"))
	draw_circle(center + Vector2(-5.0, -4.0), 10.0 * scale, Color(0.98, 0.70, 0.34, 0.42))
	draw_rect(Rect2(center.x - 12.0, center.y + 17.0, 24.0, 5.0), Color("#6f341c"))
	draw_line(Vector2(center.x, center.y + 22.0), Vector2(center.x, center.y + 38.0), Color("#b86932"), 2.0)
	draw_circle(Vector2(center.x, center.y + 40.0), 2.2, Color("#d8a548"))


func _draw_embers() -> void:
	for ember in _embers:
		var rise := fmod(_time * 13.0 * ember.z + ember.y, 460.0)
		var x := ember.x + sin(_time * 0.55 + ember.w) * 12.0
		var y := 700.0 - rise
		var alpha := 0.10 + 0.24 * (0.5 + 0.5 * sin(_time * 2.2 + ember.w))
		draw_circle(Vector2(x, y), 1.1 + ember.z * 0.7, Color(0.92, 0.58, 0.24, alpha))


func _draw_reeds(w: float, h: float) -> void:
	for index in 9:
		var base_x := 18.0 + float(index) * 11.0
		var top := Vector2(base_x + sin(float(index)) * 18.0, h - 78.0 - float(index % 4) * 10.0)
		draw_line(Vector2(base_x, h), top, Color(0.04, 0.07, 0.07, 0.85), 2.0)
	for index in 7:
		var base_x := w - 22.0 - float(index) * 11.0
		var top := Vector2(base_x + cos(float(index)) * 16.0, h - 72.0 - float(index % 3) * 12.0)
		draw_line(Vector2(base_x, h), top, Color(0.04, 0.07, 0.07, 0.85), 2.0)


func _draw_edge_shade(w: float, h: float) -> void:
	draw_rect(Rect2(0.0, 0.0, w, 36.0), Color(0.0, 0.0, 0.0, 0.20))
	draw_rect(Rect2(0.0, h - 32.0, w, 32.0), Color(0.0, 0.0, 0.0, 0.30))
	draw_rect(Rect2(0.0, 0.0, 18.0, h), Color(0.0, 0.0, 0.0, 0.18))
	draw_rect(Rect2(w - 18.0, 0.0, 18.0, h), Color(0.0, 0.0, 0.0, 0.18))
