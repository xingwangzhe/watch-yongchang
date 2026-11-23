extends RefCounted

const SIZE := 512
const BASE := Color("#24291d")
const SPECKS := [
	Color("#1c2118"),
	Color("#2c3222"),
	Color("#363928"),
	Color("#3d3b29"),
	Color("#202a20"),
]
const REEDS := [
	Color("#35452f"),
	Color("#465238"),
	Color("#596044"),
]


static func make(seed_value: int = 9157) -> Texture2D:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(BASE)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(9000):
		var color: Color = SPECKS[rng.randi_range(0, SPECKS.size() - 1)]
		var x := rng.randi_range(0, SIZE - 1)
		var y := rng.randi_range(0, SIZE - 1)
		image.set_pixel(x, y, color)
		if i % 7 == 0:
			image.set_pixel((x + 1) % SIZE, y, color)
		if i % 11 == 0:
			image.set_pixel(x, (y + 1) % SIZE, color)
	for i in range(620):
		var color: Color = REEDS[rng.randi_range(0, REEDS.size() - 1)]
		var x := rng.randi_range(0, SIZE - 1)
		var y := rng.randi_range(3, SIZE - 1)
		var height := rng.randi_range(2, 5)
		for step in range(height):
			image.set_pixel(x, y - step, color)
		if i % 3 == 0:
			image.set_pixel((x + 1) % SIZE, y - 1, color)
	return ImageTexture.create_from_image(image)
