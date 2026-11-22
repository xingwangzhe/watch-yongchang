extends Node
## 资源层：按路径缓存贴图，代码动态构建 SpriteFrames（避免手写复杂 .tres）。

var _textures: Dictionary = {}
var _frames: Dictionary = {}

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
	sf.add_animation("run")
	sf.set_animation_speed("run", 10.0)
	sf.set_animation_loop("run", true)
	for i in range(1, 5):
		sf.add_frame("run", get_texture("%s/run/frame_%02d.png" % [base, i]))
	sf.add_animation("attack")
	sf.set_animation_speed("attack", 12.0)
	sf.set_animation_loop("attack", false)
	for i in range(1, 5):
		sf.add_frame("attack", get_texture("%s/attack/frame_%02d.png" % [base, i]))
	sf.add_animation("static")
	sf.set_animation_speed("static", 1.0)
	sf.add_frame("static", get_texture("%s/static.png" % base))
	_frames[unit_id] = sf
	return sf

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
	for uid in ["xiangyong", "gongshou", "longdeng"]:
		get_frames(uid)
	for bid in ["junxiefang", "jianta", "fenghuotai"]:
		get_texture("res://assets/buildings/%s/static.png" % bid)
