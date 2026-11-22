extends Node
## 资源层：按路径缓存贴图，代码动态构建 SpriteFrames（避免手写复杂 .tres）。

var _textures: Dictionary = {}
var _frames: Dictionary = {}

const UNIT_IDS: Array[String] = [
	"xiangyong", "gongshou", "longdeng",
	"wokou_scout", "wokou_ronin", "wokou_shield", "wokou_gun", "wokou_chief",
]

func get_texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var tex := load(path) as Texture2D
	_textures[path] = tex
	return tex

func get_frames(unit_id: String) -> SpriteFrames:
	if _frames.has(unit_id):
		return _frames[unit_id]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var base := "res://assets/units/%s" % unit_id
	var run_paths := _frame_paths(base, "run")
	var attack_paths := _frame_paths(base, "attack")
	sf.add_animation("run")
	sf.set_animation_speed("run", 10.0)
	sf.set_animation_loop("run", true)
	for path in run_paths:
		sf.add_frame("run", get_texture(path))
	sf.add_animation("attack")
	sf.set_animation_speed("attack", 12.0)
	sf.set_animation_loop("attack", false)
	for path in attack_paths:
		sf.add_frame("attack", get_texture(path))
	sf.add_animation("static")
	sf.set_animation_speed("static", 1.0)
	var static_path := "%s/static.png" % base
	if ResourceLoader.exists(static_path):
		sf.add_frame("static", get_texture(static_path))
	elif not run_paths.is_empty():
		sf.add_frame("static", get_texture(run_paths[0]))
	_frames[unit_id] = sf
	return sf

func _frame_paths(base: String, anim: String) -> Array[String]:
	var dir_path := "%s/%s" % [base, anim]
	var out: Array[String] = []
	var names := DirAccess.get_files_at(dir_path)
	names.sort()
	for name in names:
		if name.begins_with("frame_") and name.ends_with(".png"):
			out.append("%s/%s" % [dir_path, name])
	return out

## 建筑动画帧：res://assets/buildings/{id}/{anim}/frame_01..04.png，动画名 default，6fps 循环。
## 缓存 key 用 "b:" 前缀与单位帧隔离，避免同类 id 冲突。
func get_building_frames(building_id: String, anim: String) -> SpriteFrames:
	var key := "b:" + building_id + ":" + anim
	if _frames.has(key):
		return _frames[key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("default")
	sf.set_animation_speed("default", 6.0)
	sf.set_animation_loop("default", true)
	var base := "res://assets/buildings/%s/%s" % [building_id, anim]
	for i in range(1, 5):
		sf.add_frame("default", get_texture("%s/frame_%02d.png" % [base, i]))
	_frames[key] = sf
	return sf

func preload_level(_level_id: String) -> void:
	for uid in UNIT_IDS:
		get_frames(uid)
	for bid in ["junxiefang", "jianta", "fenghuotai"]:
		get_texture("res://assets/buildings/%s/static.png" % bid)
